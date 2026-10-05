<#
    .SYNOPSIS
    Enable or disable drain mode on this AVD session host

    .DESCRIPTION
    Switches drain mode for this Azure Virtual Desktop session host, whichever host pool of the tenant it belongs to. With drain mode on, the host accepts no new sessions, for example before maintenance; existing sessions stay connected. With drain mode off, the host takes new sessions again.

    .PARAMETER DeviceName
    Name of the AVD session host. Set by the portal from the selected device.

    .PARAMETER DrainMode
    Whether the host should stop accepting new sessions (drain mode on) or take new sessions again (drain mode off).

    .PARAMETER SubscriptionIds
    Azure subscriptions that hold the AVD host pools. Taken from the tenant setting AVD.SubscriptionIds.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "DeviceName": {
                "Hide": true
            },
            "DrainMode": {
                "DisplayName": "Drain mode",
                "DefaultValue": false,
                "SelectSimple": {
                    "On - stop accepting new sessions": true,
                    "Off - accept new sessions again": false
                }
            },
            "SubscriptionIds": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Az.DesktopVirtualization"; ModuleVersion = "6.0.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceName,
    [Parameter(Mandatory = $true)]
    [bool] $DrainMode,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "AVD.SubscriptionIds" } )]
    [string[]] $SubscriptionIds,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
##
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

#endregion

########################################################
#region     Connect Part
##
########################################################

if (-not $SubscriptionIds -or $SubscriptionIds.Count -eq 0) {
    "## SubscriptionIds is not set! Please set the SubscriptionIds in the runbook customization."
    throw "SubscriptionIds is not set!"
}

$BackupVerbosePreference = $VerbosePreference

try {
    $VerbosePreference = "SilentlyContinue"
    Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
    $VerbosePreference = $BackupVerbosePreference
    # Check if Az connection is active
    Get-AzContext -ErrorAction Stop | Out-Null
}
catch {
    Start-Sleep -Seconds 5
    try {
        $VerbosePreference = "SilentlyContinue"
        Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
        $VerbosePreference = $BackupVerbosePreference
        # Check if Az connection is active
        Get-AzContext -ErrorAction Stop | Out-Null
    }
    catch {
        "## Failed to connect to Azure: $($_.Exception.Message)"
        throw
    }
}

#endregion

########################################################
#region     Execution Part
##
########################################################

$MatchingSessionHosts = @()

# Function to set Drain Mode for a Session Host
function Set-DrainMode {
    param(
        [Parameter(Mandatory = $true)]
        [string] $HostPoolName,
        [Parameter(Mandatory = $true)]
        [string] $SessionHostName,
        [Parameter(Mandatory = $true)]
        [string] $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string] $SubscriptionId,
        [Parameter(Mandatory = $true)]
        [bool] $AllowSession
    )
    $mode = if ($AllowSession) { $true } else { $false }
    Update-AzWvdSessionHost -HostPoolName $HostPoolName `
        -Name $SessionHostName `
        -ResourceGroupName $ResourceGroupName `
        -SubscriptionId $SubscriptionId `
        -AllowNewSession:$mode `
        -Force -ErrorAction Stop | Out-Null
    Start-Sleep -Seconds 10
    $action = if ($AllowSession) { "Disabled" } else { "Enabled" }
    "## $($action) Drain Mode for Session Host $($SessionHost.Name) in Subscription $($SubscriptionId)"
}

"## Cycling through Subscriptions"
foreach ($SubId in $SubscriptionIds) {
    try {
        $IsSubSet = $true
        Set-AzContext -Subscription $SubId -ErrorAction Stop | Out-Null
        "## Set context for Subscription '$SubId'"
    }
    catch {
        $IsSubSet = $false
        "## Failed to set context for Subscription '$SubId': $($_.Exception.Message)"
    }
    if ($IsSubSet) {
        # Get all hostpools
        $Hostpools = Get-AzWvdHostPool
        # Get the session hosts for each pool and create a custom object for each
        $SessionHosts = foreach ($Hostpool in $Hostpools) {
            Get-AzWvdSessionHost -HostPoolName $Hostpool.Name -ResourceGroupName $Hostpool.ResourceGroupName | ForEach-Object {
                [PSCustomObject]@{
                    Name              = ($_.Name -split "/")[-1]
                    HostPoolName      = $Hostpool.Name
                    ResourceGroupName = $Hostpool.ResourceGroupName
                    OriginalObject    = $_
                }
            }
        }

        # Find the session host that matches the provided DeviceName
        $MatchingSessionHosts = $SessionHosts | Where-Object { $_.Name -eq $DeviceName }
        if (-not $MatchingSessionHosts) {
            "## Session Host '$($SessionHost.Name)' not found in Subscription '$SubId'"
        }
        else {
            foreach ($SessionHost in $MatchingSessionHosts) {
                # If DrainMode is enabled, update the session host to disable new sessions
                if ($DrainMode) {
                    Set-DrainMode -HostPoolName $SessionHost.HostPoolName -SessionHostName $SessionHost.Name -ResourceGroupName $SessionHost.ResourceGroupName -SubscriptionId $SubId -AllowSession $false
                }
                else {
                    Set-DrainMode -HostPoolName $SessionHost.HostPoolName -SessionHostName $SessionHost.Name -ResourceGroupName $SessionHost.ResourceGroupName -SubscriptionId $SubId -AllowSession $true
                }
            }
        }
    }
}

Disconnect-AzAccount | Out-Null
<#
    .SYNOPSIS
    Sets Drainmode on true or false for a specific AVD Session Host.

    .DESCRIPTION
    This Runbooks looks through all AVD Hostpools of a tenant and sets the DrainMode for a specific Session Host.
    The SubscriptionId value must be defined in the runbooks customization.

    .PARAMETER DeviceName
    The name of the AVD Session Host device for which to toggle drain mode. Hidden in UI.

    .PARAMETER DrainMode
    Boolean value to enable or disable Drain Mode. Set to true to enable Drain Mode (prevent new sessions), false to disable it (allow new sessions). Default is false.

    .PARAMETER SubscriptionIds
    Array of Azure subscription IDs where the AVD Session Host resources are located. Retrieved from AVD.SubscriptionIds setting (Customization). Hidden in UI.

    .PARAMETER CallerName
    The name of the user executing the runbook. Used for auditing purposes. Hidden in UI.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "DeviceName": {
                "Hide": true
            },
            "DrainMode": {
                "DisplayName": "Drain Mode",
                "DefaultValue": "false",
                "Type": "bool",
                "Description": "Set to true to enable Drain Mode, false to disable it."
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Az.DesktopVirtualization"; ModuleVersion = "5.4.1" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.1.1" }

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

$Version = "1.0.0"
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
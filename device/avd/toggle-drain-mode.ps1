<#
  .SYNOPSIS
  Sets Drainmode on true or false for a specific AVD Session Host.

  .DESCRIPTION
  This Runbooks looks through all AVD Hostpools of a tenant and sets the DrainMode for a specific Session Host.
  The SubscriptionId value must be defined in the runbooks customization.

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "DeviceId": {
                "Hide": true
            },
            "DrainMode": {
                "Hide": true
                "DefaultValue": "false"
            },
            "SubscriptionIds": {
                "Hide": true
                "DefaultValue": [ "00000000-0000-0000-0000-000000000000" ]
            },
            "CallerName": {
                "Hide": true
            },
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }
#Requires -Modules @{ModuleName = "Az.DesktopVirtualization"; ModuleVersion = "5.4.1" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.1.1" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [Parameter(Mandatory = $true)]
    [bool] $DrainMode,
    [Parameter(Mandatory = $true)]
    [string[]] $SubscriptionIds,
    # CallerName is tracked purely for auditing purposes
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

if ($SubscriptionIds -contains "00000000-0000-0000-0000-000000000000") {
    Write-Error "SubscriptionIds is not set! Please set the SubscriptionIds in the runbook customization."
    throw "SubscriptionIds is not set!"
}

try {
    Connect-AzAccount -Identity -ErrorAction Stop
}
catch {
    Write-RjRbLog -Message "Failed to connect to Azure: $($_.Exception.Message)" -Error
    throw
}

#endregion

########################################################
#region     Execution Part
##
########################################################

$SubscriptionIds = @("06c17688-db5c-4ee3-a93c-84a629d1ebab", "3961220d-6be2-40e5-8d8f-d12e3a191503")
$Hostname = "vmapopdweuwrea2"
$DrainMode = $false

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
        -Force -ErrorAction Stop
    Start-Sleep -Seconds 10
    $action = if ($AllowSession) { "Disabled" } else { "Enabled" }
    Write-RjRbLog -Message "$action Drain Mode for Session Host '$($SessionHost.Name)' in Subscription '$SubscriptionId'" -Verbose
}

foreach ($SubId in $SubscriptionIds) {
    try {
        $IsSubSet = $true
        Set-AzContext -SubscriptionId $SubId -ErrorAction Stop
    }
    catch {
        $IsSubSet = $false
        Write-RjRbLog -Message "Failed to set context for Subscription '$SubId': $($_.Exception.Message)" -ErrorAction Continue
    }
    if ($IsSubSet) {
        # get all hostpools
        $Hostpools = Get-AzWvdHostPool
        # get the session hosts for each pool and create a custom object for each
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

        # find the session host that matches the provided hostname
        $MatchingSessionHosts = $SessionHosts | Where-Object { $_.VirtualMachineID -eq $DeviceId }
        foreach ($SessionHost in $MatchingSessionHosts) {
            if (-not $SessionHost) {
                Write-RjRbLog -Message "Session Host '$($SessionHost.Name)' not found in Subscription '$SubId'" -ErrorAction Continue
            }
            else {
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
<#
    .SYNOPSIS
    Reboots a specific AVD Session Host.

    .DESCRIPTION
    This Runbook reboots a specific AVD Session Host. If Users are signed in, they will be disconnected. In any case, Drain Mode will be enabled and the Session Host will be restarted.
    If the SessionHost is not running, it will be started. Once the Session Host is running, Drain Mode is disabled again.

    .PARAMETER DeviceName
    The name of the AVD Session Host device to restart. Hidden in UI.

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
            "SubscriptionIds": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            },
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Az.DesktopVirtualization"; ModuleVersion = "5.4.1" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.1.1" }
#Requires -Modules @{ModuleName = "Az.Compute"; ModuleVersion = "5.1.1" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceName,
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

# Loop through each SubscriptionId
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
                    VirtualMachineID  = $_.virtualMachineId
                    OriginalObject    = $_
                }
            }
        }

        # Find all session hosts that match the provided DeviceName
        $MatchingSessionHosts = $SessionHosts | Where-Object { $_.Name -eq $DeviceName }
        if (-not $MatchingSessionHosts) {
            "## Session Host '$($SessionHost.Name)' not found in Subscription '$SubId'"
        }
        else {
            foreach ($SessionHost in $MatchingSessionHosts) {
                # Check if the session host is already in Drain Mode
                "## Processing Session Host '$($SessionHost.Name)' with ID '$($SessionHost.VirtualMachineID)' in Subscription '$SubId'"
                $vms = Get-AzVM -Status | Where-Object { ($_.Name -eq $SessionHost.Name) -and ($_.VmId -eq $SessionHost.VirtualMachineID) } -ErrorAction Stop
                foreach ($vm in $vms) {
                    # If the VM is not running, start it and set Drain Mode to allow new sessions
                    if ($vm.PowerState -ne "VM running") {
                        "## Session Host '$($SessionHost.Name)' is not running. Starting"
                        $result = Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -ErrorAction Stop
                        if ($result.Status -eq "Succeeded") {
                            "## Successfully started Session Host '$($SessionHost.Name)' in Subscription '$SubId'. Disabling Drain Mode..."
                            Set-DrainMode -HostPoolName $SessionHost.HostPoolName -SessionHostName $SessionHost.Name -ResourceGroupName $SessionHost.ResourceGroupName -SubscriptionId $SubId -AllowSession $true
                        }
                        else {
                            "## Failed to start Session Host '$($SessionHost.Name)' in Subscription '$SubId'."
                        }
                    }
                    else {
                        # Retrieve active user sessions.
                        $UserSessions = Get-AzWvdUserSession -ResourceGroupName $SessionHost.ResourceGroupName -HostPoolName $SessionHost.HostPoolName -SessionHostName $SessionHost.Name
                        # Ensure drain mode is enabled prior to restart.
                        if ($SessionHost.OriginalObject.AllowNewSession -eq $false) {
                            "## Session Host '$($SessionHost.Name)' is already in Drain Mode in Subscription '$SubId'"
                        }
                        else {
                            Set-DrainMode -HostPoolName $SessionHost.HostPoolName -SessionHostName $SessionHost.Name -ResourceGroupName $SessionHost.ResourceGroupName -SubscriptionId $SubId -AllowSession $false
                        }
                        # If there are user sessions, force sign them out.
                        if ($UserSessions) {
                            "## User sessions found on Session Host '$($SessionHost.Name)' in Subscription '$SubId'. Forcing sign-out of users."
                            foreach ($UserSession in $UserSessions) {
                                "## Forcing sign-out of user '$($UserSession.UserPrincipalName)' on Session Host '$($SessionHost.Name)' in Subscription '$SubId'."
                                $Id = ($UserSession.Id -split "/")[-1]
                                Remove-AzWvdUserSession -ResourceGroupName $SessionHost.ResourceGroupName -HostPoolName $SessionHost.HostPoolName -SessionHostName $SessionHost.Name -Id $Id -Force -ErrorAction Stop
                            }
                        }
                        # Restart the session host
                        "## Restarting Session Host '$($SessionHost.Name)' in Subscription '$SubId'..."
                        $result = Restart-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -ErrorAction Stop
                        if ($result.Status -eq "Succeeded") {
                            "## Successfully restarted Session Host '$($SessionHost.Name)' in Subscription '$SubId'."
                            Set-DrainMode -HostPoolName $SessionHost.HostPoolName -SessionHostName $SessionHost.Name -ResourceGroupName $SessionHost.ResourceGroupName -SubscriptionId $SubId -AllowSession $true
                        }
                        else {
                            "## Failed to restart Session Host '$($SessionHost.Name)' in Subscription '$SubId'."
                        }
                    }
                }
            }
        }
    }
}

Disconnect-AzAccount | Out-Null
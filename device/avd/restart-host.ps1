<#
  .SYNOPSIS
  Sets Drainmode on true or false for a specific AVD Session Host.

  .DESCRIPTION
  This Runbook looks through all AVD Hostpools of a tenant and sets the DrainMode for a specific Session Host.
  The SubscriptionId value must be defined in the runbooks customization.

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "DeviceId": {
                "Hide": true
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
#Requires -Modules @{ModuleName = "Az.Compute"; ModuleVersion = "5.1.1" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
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

# loop through each SubscriptionId
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
                    VirtualMachineID  = $_.VirtualMachineId
                    OriginalObject    = $_
                }
            }
        }

        # find all session hosts that match the provided hostname
        $MatchingSessionHosts = $SessionHosts | Where-Object { $_.VirtualMachineID -eq $DeviceId }
        foreach ($SessionHost in $MatchingSessionHosts) {
            # Check if the session host is already in Drain Mode
            Write-RjRbLog -Message "Processing Session Host '$($SessionHost.Name)' with ID '$($SessionHost.VirtualMachineID)' in Subscription '$SubId'" -Verbose

            $vms = Get-AzVM -Status | Where-Object { ($_.Name -eq $SessionHost.Name) -and ($_.VmId -eq $SessionHost.VirtualMachineID) } -ErrorAction Stop
            foreach ($vm in $vms) {
                if ($vm.PowerState -ne "VM running") {
                    Write-RjRbLog -Message "Session Host '$($SessionHost.Name)' is not running. Starting" -Verbose
                    $result = Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -ErrorAction Stop
                    if ($result.Status -eq "Succeeded") {
                        Write-RjRbLog -Message "Successfully started Session Host '$($SessionHost.Name)' in Subscription '$SubId'. Disabling Drain Mode..." -Verbose
                        Set-DrainMode -HostPoolName $SessionHost.HostPoolName -SessionHostName $SessionHost.Name -ResourceGroupName $SessionHost.ResourceGroupName -SubscriptionId $SubId -AllowSession $true
                    }
                    else {
                        Write-RjRbLog -Message "Failed to start Session Host '$($SessionHost.Name)' in Subscription '$SubId'." -Verbose
                    }
                }
                else {
                    $UserSessions = Get-AzWvdUserSession -ResourceGroupName $SessionHost.ResourceGroupName -HostPoolName $SessionHost.HostPoolName -SessionHostName $SessionHost.Name
                    
                    if ($SessionHost.OriginalObject.AllowNewSession -eq $false) {
                        Write-RjRbLog -Message "Session Host '$($SessionHost.Name)' is already in Drain Mode in Subscription '$SubId'" -Verbose
                    }
                    else {
                        Set-DrainMode -HostPoolName $SessionHost.HostPoolName -SessionHostName $SessionHost.Name -ResourceGroupName $SessionHost.ResourceGroupName -SubscriptionId $SubId -AllowSession $false
                    }
                    if ($UserSessions) {
                        Write-RjRbLog -Message "User sessions found on Session Host '$($SessionHost.Name)' in Subscription '$SubId'. Forcing sign-out of users." -Verbose
                        foreach ($UserSession in $UserSessions) {
                            Write-RjRbLog -Message "Forcing sign-out of user '$($UserSession.UserPrincipalName)' on Session Host '$($SessionHost.Name)' in Subscription '$SubId'" -Verbose
                            $Id = ($UserSession.Id -split "/")[-1]
                            Remove-AzWvdUserSession -ResourceGroupName $SessionHost.ResourceGroupName -HostPoolName $SessionHost.HostPoolName -SessionHostName $SessionHost.Name -Id $Id -Force -ErrorAction Stop
                        }
                    }
                    # Restart the session host
                    Write-RjRbLog -Message "Restarting Session Host '$($SessionHost.Name)' in Subscription '$SubId'..." -Verbose
                    $result = Restart-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -ErrorAction Stop
                    if ($result.Status -eq "Succeeded") {
                        Write-RjRbLog -Message "Successfully restarted Session Host '$($SessionHost.Name)' in Subscription '$SubId'." -Verbose
                        Set-DrainMode -HostPoolName $SessionHost.HostPoolName -SessionHostName $SessionHost.Name -ResourceGroupName $SessionHost.ResourceGroupName -SubscriptionId $SubId -AllowSession $true
                    }
                    else {
                        Write-RjRbLog -Message "Failed to restart Session Host '$($SessionHost.Name)' in Subscription '$SubId' after waiting $elapsed seconds." -Verbose
                    }
                }
            }
        }
    }   
}
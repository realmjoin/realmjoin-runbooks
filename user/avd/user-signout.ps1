<#
  .SYNOPSIS
  Removes (Signs Out) a specific User from their AVD Session.

  .DESCRIPTION
  This Runbooks looks for active User Sessions in all AVD Hostpools of a tenant and removes forces a Sign-Out of the user.
  The SubscriptionIds value must be defined in the runbooks customization.

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
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

param(
    [Parameter(Mandatory = $true)]
    [string] $UserName,
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
        # get the session hosts for each pool
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

        $UserSessions = foreach ($SessionHost in $SessionHosts) {
            Get-AzWvdUserSession -ResourceGroupName $SessionHost.ResourceGroupName -HostPoolName $SessionHost.HostPoolName | Where-Object { $_.UserPrincipalName -eq $UserName }     
        }

        # sign out the user if a session exists
        if ($UserSessions) {
            $UserSessions | Remove-AzWvdUserSession -Force
            Write-Output "User $UserName signed out"
        }
        else {
            Write-Output "No Session found"
        }
    }  

}
<#
  .SYNOPSIS
  Removes (Signs Out) a specific User from their AVD Session.

  .DESCRIPTION
  This Runbooks looks for active User Sessions in all AVD Hostpools of a tenant and removes forces a Sign-Out of the user.
  The SubscriptionIds value must be defined in the runbooks customization.

  .PARAMETER UserName
  The username (UPN) of the user to sign out from their AVD session. Hidden in UI.

  .PARAMETER SubscriptionIds
  Array of Azure subscription IDs where the AVD resources are located. Retrieved from AVD.SubscriptionIds setting (Customization). Hidden in UI.

  .PARAMETER CallerName
  The name of the user executing the runbook. Used for auditing purposes. Hidden in UI.

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "Az.DesktopVirtualization"; ModuleVersion = "5.4.1" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.1.1" }

param(
    [Parameter(Mandatory = $true)]
    [string] $UserName,
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

foreach ($SubId in $SubscriptionIds) {
    "## Working through Subscription $($SubId)"
    try {
        $IsSubSet = $true
        Set-AzContext -SubscriptionId $SubId -ErrorAction Stop | Out-Null
    }
    catch {
        $IsSubSet = $false
        "## Failed to set context for Subscription $($SubId) Error: $($_.Exception.Message)"
    }
    if ($IsSubSet) {
        # Get all hostpools
        $Hostpools = Get-AzWvdHostPool
        # Get the session hosts for each pool
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

        # Get user sessions for the specified user
        $UserSessions = foreach ($SessionHost in $SessionHosts) {
            Get-AzWvdUserSession -ResourceGroupName $SessionHost.ResourceGroupName -HostPoolName $SessionHost.HostPoolName | Where-Object { $_.UserPrincipalName -eq $UserName }
        }

        # Sign out the user if a session exists
        if ($UserSessions) {
            $UserSessions | Remove-AzWvdUserSession -Force
            "## Signing out User $($UserName) in Subscription $($SubId) - $($SessionHost.HostPoolName) - $($SessionHost.Name)"
        }
        else {
            "## No Session found for User $($UserName) in Subscription $($SubId)."
        }
    }
}

Disconnect-AzAccount | Out-Null
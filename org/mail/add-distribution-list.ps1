<#
  .SYNOPSIS
  Create a classic distribution group.

  .DESCRIPTION
  Create a classic distribution group.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)] 
    [string] $Alias,
    [string] $GroupName,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Group owner" -Filter "userType eq 'Member'" } )]
    [string] $Owner,
    [ValidateScript( { Use-RJInterface -DisplayName "Can receive external mail" } )]
    [bool] $AllowExternalSenders = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Desired email address" } )]
    [string] $PrimarySMTPAddress 
)

try {
    $script:Alias = ([mailaddress]"$Alias@demo.com").user 
} catch {
    "## $Alias is not a valid alias." 
}

if (-not $GroupName) {
    $GroupName = $Alias
}

try {
    Connect-RjRbExchangeOnline

    $invokeParams = @{
        RequireSenderAuthenticationEnabled  = (-not $AllowExternalSenders)
        Alias = $Alias
        Name = $GroupName 
        Type = "Distribution"
        MemberDepartRestriction = "Closed"
        MemberJoinRestriction = "Closed"
    }

    if ($Owner) {
        $invokeParams += @{ 
            ManagedBy = $Owner 
            CopyOwnerToMember = $true
        }
    }

    if ($PrimarySMTPAddress) {
        $invokeParams += @{ 
            PrimarySMTPAddress = $PrimarySMTPAddress
        }
    }

    # Create the group
    New-DistributionGroup @invokeParams | Out-Null

    "## Distribution Group '$GroupName' has been created."
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
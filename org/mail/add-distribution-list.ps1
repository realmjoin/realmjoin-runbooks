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

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "Alias": {
                "DisplayName": "Alias of the Distribution List. Shorter, more concise name for the distribution list. \nExample: "MarketingTeam@company.com" could have an alias "MKTG@company.com" for convenience."
            },
            "GroupName": {
                "DisplayName": "Group Name as displayed in the address book of your mailing system for easier searching."
            },
            "Owner": {
                "DisplayName": "Group Owner that will manage the members of the Distribution List (add, remove, etc.)."
            },
            "PrimarySMTPAddress": {
                "DisplayName": "Primary email address of the Distribution List that will be used to send emails from."
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)] 
    [string] $Alias,
    [string] $GroupName,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Group owner" -Filter "userType eq 'Member'" } )]
    [string] $Owner,
    [ValidateScript( { Use-RJInterface -DisplayName "Desired email address" } )]
    [string] $PrimarySMTPAddress,
    [ValidateScript( { Use-RJInterface -DisplayName "Create as Roomlist" } )]
    [bool] $Roomlist = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Can receive external mail" } )]
    [bool] $AllowExternalSenders = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName 
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

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
        RoomList = $Roomlist
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
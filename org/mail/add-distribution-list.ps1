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
  MS Graph (API):
  -Oranization.Read.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "Alias": {
                "DisplayName": "Alias: A shorter, more concise name for the Distribution List that is usually the first part of the email address (in front of the \"@\" sign). \nExample: \"MarketingTeam@company.com\" could have an alias \"MKTG\" for convenience."
            },
            "GroupName": {
                "DisplayName": "Group Name: As displayed in the address book of your mailing system for easier searching."
            },
            "Owner": {
                "DisplayName": "Group Owner: User that will manage the members of the Distribution List (add, remove, etc.)."
            },
            "PrimarySMTPAddress": {
                "DisplayName": "Desired email address: Primary email address of the Distribution List that will be used to send emails from. If left unfilled will use the default domain as a primary SMTP address."
            },
            "Roomlist": {
                "DisplayName": "Create as Roomlist"
            },
            "AllowExternalSenders": {
                "DisplayName": "Can receive external mail"
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)] 
    [string] $Alias,
    [string] $PrimarySMTPAddress,
    [string] $GroupName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Group owner" -Filter "userType eq 'Member'" } )]
    [string] $Owner,
    [bool] $Roomlist = $false,
    [bool] $AllowExternalSenders = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName 
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

try {
    $script:Alias = ([mailaddress]"$Alias@demo.com").user 
}
catch {
    "## $Alias is not a valid alias." 
}

if (-not $GroupName) {
    $GroupName = $Alias
}

try {
    Connect-RjRbExchangeOnline

    $invokeParams = @{
        RequireSenderAuthenticationEnabled = (-not $AllowExternalSenders)
        Alias                              = $Alias
        Name                               = $GroupName 
        Type                               = "Distribution"
        MemberDepartRestriction            = "Closed"
        MemberJoinRestriction              = "Closed"
        RoomList                           = $Roomlist
    }

    if ($Owner) {
        $invokeParams += @{ 
            ManagedBy         = $Owner 
            CopyOwnerToMember = $true
        }
    }

    if ($PrimarySMTPAddress) {
        $invokeParams += @{ 
            PrimarySMTPAddress = $PrimarySMTPAddress
        }
    }
    else {
        Connect-RjRbGraph
        $verifiedDomains = Invoke-RjRbRestMethodGraph -Resource "/organization" -OdSelect "verifiedDomains"
        foreach ($verifiedDomain in $verifiedDomains.verifiedDomains) {
            if ($verifiedDomain.isDefault -eq 'true') {
                $defaultDomain = $verifiedDomain
            }
        }
        $DesiredPrimarySMTPAddress = $Alias + "@" + $defaultDomain.name
        $invokeParams += @{ 
            PrimarySMTPAddress = $DesiredPrimarySMTPAddress
        }
    }

    # Create the group
    New-DistributionGroup @invokeParams | Out-Null

    "## Distribution Group '$GroupName' has been created."
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
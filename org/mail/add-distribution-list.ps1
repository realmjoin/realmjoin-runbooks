<#
    .SYNOPSIS
    Create a classic Exchange Online distribution group

    .DESCRIPTION
    Creates a classic distribution group in Exchange Online, optionally as a room list, with an owner, or open to external senders. Without an email address the alias at the default domain of the tenant is used.

    .PARAMETER Alias
    Short name that becomes the part of the email address in front of the @ sign, for example MKTG for the marketing team.

    .PARAMETER PrimarySMTPAddress
    Address the group sends and receives with. Leave empty to use the alias at the default domain.

    .PARAMETER GroupName
    Name shown in the address book. Leave empty to use the alias.

    .PARAMETER Owner
    User who manages the members of the group. Leave empty for none.

    .PARAMETER Roomlist
    Creates the group as a room list, so its rooms can be picked together in the Outlook room finder.

    .PARAMETER AllowExternalSenders
    Lets people outside the organization send email to the group.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "Alias": {
                "DisplayName": "Alias"
            },
            "GroupName": {
                "DisplayName": "Group name"
            },
            "Owner": {
                "DisplayName": "Group owner"
            },
            "PrimarySMTPAddress": {
                "DisplayName": "Email address"
            },
            "Roomlist": {
                "DisplayName": "Create as a room list?"
            },
            "AllowExternalSenders": {
                "DisplayName": "Allow external senders?"
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

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

$Version = "1.0.1"
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
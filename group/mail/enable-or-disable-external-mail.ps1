<#
    .SYNOPSIS
    Enable or disable external parties to send emails to a Microsoft 365 group

    .DESCRIPTION
    This runbook configures whether external senders are allowed to email a Microsoft 365 group.
    It uses Exchange Online to enable or disable the RequireSenderAuthenticationEnabled setting.
    You can also query the current state without making changes.

    .PARAMETER GroupId
    Object ID of the Microsoft 365 group.

    .PARAMETER Action
    "Enable External Mail" (final value: 0), "Disable External Mail" (final value: 1) or "Query current state only" (final value: 2) can be selected as action to perform. If set to 0, the runbook will allow external senders to email the group. If set to 1, it will block external senders from emailing the group. If set to 2, it will return whether external mailing is currently enabled or disabled for the group without making any changes.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .NOTES
    Setting this via Microsoft Graph is broken as of 2021-06-28.
    Attribute: allowExternalSenders.
    See https://docs.microsoft.com/en-us/graph/known-issues#setting-the-allowexternalsenders-property.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Action": {
                "DisplayName": "Choose action",
                "SelectSimple": {
                    "Enable External Mail": 0,
                    "Disable External Mail": 1,
                    "Query current state only": 2
                }
            },
            "GroupId": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.7.2" }
#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group } )]
    [String] $GroupId,
    [int] $Action = 0,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

try {
    $ProgressPreference = "SilentlyContinue"

    Connect-RjRbExchangeOnline

    # "Checking"  if group is universal group
    $group = Get-UnifiedGroup -Identity $GroupId -ErrorAction SilentlyContinue
    if (-not $group) {
        throw "`'$GroupId`' is not a unified (O365) group. Can not proceed."
    }

    if ($Action -eq 1) {
        # "Disable external mailing for $GroupId"
        try {
            Set-UnifiedGroup -Identity $GroupId -RequireSenderAuthenticationEnabled $true
        }
        catch {
            throw "Couldn't disable external mailing! `r`n $_"
        }
        "## External mailing successfully disabled for '$($group.displayName)'"
    }

    if ($Action -eq 0) {
        # "Enabling external mailing for $GroupId"
        try {
            Set-UnifiedGroup -Identity $GroupId -RequireSenderAuthenticationEnabled $false
        }
        catch {
            throw "Couldn't enable external mailing! `r`n $_"
        }
        "## External mailing successfully enabled for '$($group.displayName)'"
    }

    if ($Action -eq 2) {
        "## External Mailing for group '$($group.displayName)' is enabled: $( -not (Get-UnifiedGroup -Identity $GroupId).RequireSenderAuthenticationEnabled)"
    }
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}


<#
    .SYNOPSIS
    Allow or block external senders for this Microsoft 365 group

    .DESCRIPTION
    Controls whether people outside the organization can send email to this Microsoft 365 group. The current setting can also be shown without changing it.

    .PARAMETER GroupId
    Object ID of the group the runbook acts on. Set by the portal from the selected group.

    .PARAMETER Action
    Allow lets external senders email the group. Block limits it to internal senders. Query only shows the current state.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Action": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Allow external senders": 0,
                    "Block external senders": 1,
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

#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }
#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

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

$Version = "1.0.1"
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


<#
    .SYNOPSIS
    Show or hide a group in the address book

    .DESCRIPTION
    This runbook shows or hides a Microsoft 365 group or a distribution group from address lists.
    You can also query the current visibility state without making changes.

    .PARAMETER GroupName
    The identity of the target group (name, alias, or other Exchange identity value).

    .PARAMETER Action
    "Show Group in Address Book" (final value: 0), "Hide Group from Address Book" (final value: 1) or "Query current state only" (final value: 2) can be selected as action to perform. If set to 0, the runbook will make the group visible in address lists. If set to 1, it will hide the group from address lists. If set to 2, it will return whether the group is currently hidden from address lists without making any changes.

    .PARAMETER CallerName
    Caller name for auditing purposes

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Action": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Show Group in Address Book": 0,
                    "Hide Group from Address Book": 1,
                    "Query current state only": 2
                }
            },
            "GroupName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }
#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param
(
    [Parameter(Mandatory = $true)]
    [String] $GroupName,
    [int] $Action = 1,
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

    $group = Get-UnifiedGroup -Identity $GroupName -ErrorAction SilentlyContinue
    $groupType = 0

    # "Checking"  if group is universal or distribution group
    if (-not $group) {
        $group = Get-DistributionGroup -Identity $GroupName -ErrorAction SilentlyContinue
        $groupType = 1
        if (-not $group) {
            "## `'$GroupName`' is not a unified (O365)- or distribution group."
            ""
            throw ("Group not found.")
        }
    }

    if ($Action -le 1) {
        try {
            if ($Action -eq 0) {
                if ($groupType -eq 0) {
                    Set-UnifiedGroup -Identity $GroupName -HiddenFromAddressListsEnabled $false
                }
                else {
                    Set-DistributionGroup -Identity $GroupName -HiddenFromAddressListsEnabled $false
                }
                "## '$GroupName' successfully made visible."
            }
            if ($Action -eq 1) {
                if ($groupType -eq 0) {
                    Set-UnifiedGroup -Identity $GroupName -HiddenFromAddressListsEnabled $true
                }
                else {
                    Set-DistributionGroup -Identity $GroupName -HiddenFromAddressListsEnabled $true
                }
                "## '$GroupName' successfully hidden."
            }
        }
        catch {
            throw "Couldn't modify '$GroupName'"
        }
    }
    else {
        "## '$GroupName' is currently hidden: $($group.HiddenFromAddressListsEnabled)"
    }
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}


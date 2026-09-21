<#
    .SYNOPSIS
    Show or hide this group in the address book

    .DESCRIPTION
    Shows this Microsoft 365 or distribution group in the address lists or hides it from them. A hidden group still receives email at its address; it just does not appear in the address book. Query only shows the current state without changing anything.

    .PARAMETER GroupName
    Identity of the group in Exchange Online, such as its name or alias. Set by the portal from the selected group.

    .PARAMETER Action
    Show lists the group in the address book, Hide removes it from the lists, Query only shows the current state.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Action": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Show group in address book": 0,
                    "Hide group from address book": 1,
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
#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

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

$Version = "1.0.1"
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


<#
    .SYNOPSIS
    Remove a group. For Microsoft 365 groups, also the associated resources (Teams, SharePoint site) will be removed.

    .DESCRIPTION
    This runbook deletes the specified group, which for Microsoft 365 groups means, that it also deletes the associated resources such as the Teams Team and the SharePoint Site.

    .PARAMETER GroupId
    Object ID of the group to delete.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "GroupId": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [string] $GroupId,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# Check if group exists already
$group = Invoke-RjRbRestMethodGraph -resource "/groups/$GroupId" -erroraction SilentlyContinue
if (-not $group) {
    throw "GroupId '$GroupId' does not exist."
}

try {
    Invoke-RjRbRestMethodGraph -Method DELETE -resource "/groups/$GroupId" | Out-Null
}
catch {
    "## Could not delete group. Maybe missing permissions?"
    ""
    "## Make sure, the following Graph API permission is present:"
    "## - Group.ReadWrite.All (API)"
    ""
    $_
    throw ("Deleting group failed.")
}

"## Group '$($group.displayName)' (ID: $GroupId) successfully deleted."

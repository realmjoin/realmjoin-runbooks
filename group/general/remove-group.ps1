<#
    .SYNOPSIS
    Delete this group and its Microsoft 365 resources

    .DESCRIPTION
    Deletes this group. For a Microsoft 365 group this also removes the Teams team and the SharePoint site that belong to it, including their content. The group and its content can be restored from the deleted groups for 30 days, after that they are gone.

    .PARAMETER GroupId
    Object ID of the group the runbook acts on. Set by the portal from the selected group.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [string] $GroupId,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
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

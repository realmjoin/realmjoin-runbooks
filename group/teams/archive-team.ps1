<#
    .SYNOPSIS
    Archive the team of this group

    .DESCRIPTION
    Archives the Microsoft Teams team that belongs to this Microsoft 365 group. Members can still read the team's content, but nobody can post in its channels until the team is unarchived; files in the SharePoint site stay editable. Use it to retire an inactive team without losing its content. The group must be provisioned as a team.

    .PARAMETER GroupID
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
    [String] $GroupID,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$group = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID" -OdSelect "displayName,resourceProvisioningOptions"

"## Trying to archive '$($group.displayName)'..."

# "## Check if group is a team"
if (-not ($group.resourceProvisioningOptions -contains "Team")) {
    "## Group '$($group.displayName)' is not a team!"
    throw ("not a team")
}

# "## already archived?"
$team = Invoke-RjRbRestMethodGraph -Resource "/teams/$GroupID"
if ($team.isArchived) {
    "## Team '$($group.displayName)' is already archived"
    exit
}

"## Archiving team"
try {
    Invoke-RjRbRestMethodGraph -Resource "/teams/$GroupID/archive" -Method Post | Out-Null
}
catch {
    ""
    "## Triggered archival of team '$($group.displayName)' "
}

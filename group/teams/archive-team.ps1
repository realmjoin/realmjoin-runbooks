<#
  .SYNOPSIS
  Archive a team.

  .DESCRIPTION
  Decomission an inactive team while preserving its contents for review.

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
    [String] $GroupID,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
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

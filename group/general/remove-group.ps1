# Permissions (according to https://docs.microsoft.com/en-us/graph/api/group-post-groups?view=graph-rest-1.0 )
# MS Graph: Group.Create, Team.Create

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

<#
  .SYNOPSIS
  Removes a group, incl. SharePoint site and Team.

  .DESCRIPTION
  Removes a group, incl. SharePoint site and Team.

#>

param(
    [Parameter(Mandatory = $true)]
    [string] $GroupId
)

Connect-RjRbGraph

# Check if group exists already
$group = Invoke-RjRbRestMethodGraph -resource "/groups/$GroupId" -erroraction SilentlyContinue
if (-not $group) {
    throw "Group '$GroupId' does not exist."
}

Invoke-RjRbRestMethodGraph -Method DELETE -resource "/groups/$GroupId" | Out-Null

"Group $GroupId successfully deleted."

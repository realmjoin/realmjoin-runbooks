<#
  .SYNOPSIS
  Report groups that have license assignment errors

  .DESCRIPTION
  Report groups that have license assignment errors

  .NOTES
  Permissions (MS Graph, API)
  - GroupMember.Read.All
  - Group.Read.All

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph

# Query for license assignment errors
$result = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "hasMembersWithLicenseErrors eq true"

if (-not $result) {
    "## No groups with license assignment errors were found."
} else {
    "## The following groups have license assignment errors:"
    $result | ForEach-Object {
        "Group: '" + $_.displayName + "', ObjectId: " + $_.id
    }
}
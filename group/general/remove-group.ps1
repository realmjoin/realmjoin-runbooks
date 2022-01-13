<#
  .SYNOPSIS
  Removes a group, incl. SharePoint site and Teams team.

  .DESCRIPTION
  Removes a group, incl. SharePoint site and Teams team.

  .NOTES
  MS Graph (API): 
  - Group.ReadWrite.All 

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Group" } )]
    [string] $GroupId,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

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

<#
  .SYNOPSIS
  Change a group's visibility

  .DESCRIPTION
  Change a group's visibility

  .NOTES
  Permissions: 
  MS Graph (API)
  - Group.ReadWrite.All
  - Directory.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "Public": {
                "DisplayName": "Set Group visibility",
                "SelectSimple": {
                    "Make group private": false,
                    "Make group public": true
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Group" } )]
    [String] $GroupID,
    [bool] $Public = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph

# "Find the group object " 
$targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId" -ErrorAction SilentlyContinue
if (-not $targetGroup) {
    throw ("Group $GroupId not found.")
}

$body = @{}
    
if ($Public) {
    $body.Add("visibility","Public")
    "## Setting the group '$($targetGroup.mailNickname)' to 'Public' visibility."
}
else {
    $body.Add("visibility","Private")
    "## Setting the group '$($targetGroup.mailNickname)'' to 'Private' visibility."
}

Invoke-RjRbRestMethodGraph -Method PATCH -resource "/groups/$($targetGroup.id)" -body $body | Out-Null


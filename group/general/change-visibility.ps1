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
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.2" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Group" } )]
    [String] $GroupID,
    [bool] $Public = $false
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
}
else {
    $body.Add("visibility","Private")
}

Invoke-RjRbRestMethodGraph -Method PATCH -resource "/groups/$($targetGroup.id)" -body $body | Out-Null


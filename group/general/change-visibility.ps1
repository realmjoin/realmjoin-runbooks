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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [String] $GroupID,
    [bool] $Public = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# "Find the group object " 
$targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId" -ErrorAction SilentlyContinue
if (-not $targetGroup) {
    throw ("Group $GroupId not found.")
}

$body = @{}
    
if ($Public) {
    $body.Add("visibility", "Public")
    "## Setting the group '$($targetGroup.mailNickname)' to 'Public' visibility."
}
else {
    $body.Add("visibility", "Private")
    "## Setting the group '$($targetGroup.mailNickname)'' to 'Private' visibility."
}

Invoke-RjRbRestMethodGraph -Method PATCH -resource "/groups/$($targetGroup.id)" -body $body | Out-Null


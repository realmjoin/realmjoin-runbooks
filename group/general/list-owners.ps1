<#
  .SYNOPSIS
  List all owners of an Office 365 group.

  .DESCRIPTION
  List all owners of an Office 365 group.

  .NOTES
  Permissions: 
  MS Graph (API)
  - Group.Read.All

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
    [String] $GroupID,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph

$owners = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/owners" -ErrorAction SilentlyContinue

if ($owners) {
    $owners | Format-Table -AutoSize -Property "displayName","userPrincipalName" | Out-String
} else {
    "## No owners found (or no access)."
}
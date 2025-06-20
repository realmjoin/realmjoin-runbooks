<#
  .SYNOPSIS
  List all owners of an Office 365 group.

  .DESCRIPTION
  List all owners of an Office 365 group.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }

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

$group = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID" -ErrorAction SilentlyContinue
if ($group) {
    "## Listing all owners of group '$($group.displayName)'"
}
else {
    "## Group '$GroupID' not found"
    throw ("Group not found")
}

$owners = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/owners" -ErrorAction SilentlyContinue -FollowPaging

if ($owners) {
    $owners | Format-Table -AutoSize -Property "displayName", "userPrincipalName" | Out-String
}
else {
    "## No owners found (or no access)."
}
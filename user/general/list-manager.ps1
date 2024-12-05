<#
  .SYNOPSIS
  List manager information for this user.

  .DESCRIPTION
  List manager information for the specified user.

  .NOTES
  Permissions
   MS Graph (API): 
   - User.Read.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName":{
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
    [String] $UserName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$User = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName"
$Manager = Invoke-RjRbRestMethodGraph -Resource "/users/$($User.id)/manager"

"## Listing manager information for '$($User.UserPrincipalName)':"
if ($Manager) {
    "## Manager: '$($Manager.displayName)'"
    "## Manager Email: '$($Manager.mail)'"
    "## Manager Job Title: '$($Manager.jobTitle)'"
    "## Manager Phone: '$($Manager.businessPhones[0])'"
    "## Manager Mobile: '$($Manager.mobilePhone)'"
}
else {
    "No manager information found for this user."
}

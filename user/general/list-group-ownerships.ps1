<#
  .SYNOPSIS
  List group ownerships for this user.

  .DESCRIPTION
  List group ownerships for this user.

  .NOTES
  Permissions
   MS Graph (API): 
   - User.Read.All
   - Group.Read.All

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.1" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

$User = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName"
$OwnedGroups = Invoke-RjRbRestMethodGraph -Resource "/users/$($User.id)/ownedObjects/microsoft.graph.group/"

"## Listing group ownerships for '$($User.UserPrincipalName)':"
if($OwnedGroups){
    foreach ($OwnedGroup in $OwnedGroups){
        "## Group '$($OwnedGroup.displayName)' with id '$($OwnedGroup.id)'"
    }
}
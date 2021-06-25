#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

<#
  .SYNOPSIS
  Add/remove owners to/from an Office 365 group.

  .DESCRIPTION
  Add/remove owners to/from an Office 365 group.
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Group" } )]
    [String] $GroupID,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserId,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this owner" } )]
    [bool] $remove = $false
)

Connect-RjRbGraph

# "Find the user object " 
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users/$UserId" -ErrorAction SilentlyContinue
if (-not $targetUser) {
    throw ("User $UserId not found.")
}

# "Is user owner of the the group?" 
if (Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/owners/$UserID" -ErrorAction SilentlyContinue) {
    if ($remove) {
        Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/owners/$UserId/`$ref" -Method Delete -Body $body | Out-Null
        "$($targetUser.UserPrincipalName) is removed from $GroupID owners"
    }
    else {    
        "User $($targetUser.UserPrincipalName) is already an owner of $GroupID. No action taken."
    }
}
else {
    if ($remove) {
        "User $($targetUser.UserPrincipalName) is not an owner of $GroupID. No action taken."
    }
    else {
        $body = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
        }
        Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/owners/`$ref" -Method Post -Body $body | Out-Null
        "$($targetUser.UserPrincipalName) is added to $GroupID owners."    
    }
}


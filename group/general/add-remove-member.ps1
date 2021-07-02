<#
  .SYNOPSIS
  Add/remove users to/from a group membership.

  .DESCRIPTION
  Add/remove users to/from a group membership.
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Group" } )]
    [String] $GroupId,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserId,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this member" } )]
    [bool] $remove = $false
)

Connect-RjRbGraph

# "Find the user object " 
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users/$UserId" -ErrorAction SilentlyContinue
if (-not $targetUser) {
    throw ("User $UserId not found.")
}

# "Is user member of the the group?" 
if (Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId/members/$UserID" -ErrorAction SilentlyContinue) {
    if ($remove) {
        Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId/members/$UserId/`$ref" -Method Delete -Body $body | Out-Null
        "$($targetUser.UserPrincipalName) is removed from $GroupId members."
    }
    else {    
        "User $($targetUser.userPrincipalName) is already a member of $GroupId. No action taken."
    }
}
else {
    if ($remove) {
        "User $($targetUser.userPrincipalName) is not a member of $GroupId. No action taken."
    }
    else {
        $body = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
        }
        Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId/members/`$ref" -Method Post -Body $body | Out-Null
        "$($targetUser.UserPrincipalName) is added to $GroupId members."    
    }
}


# This runbook will add/remove users via to/from a group membership.

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

param(
    [Parameter(Mandatory = $true)]
    [String] $GroupID,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User } )]
    [String] $UserId,
    [bool] $remove = $false
)

Connect-RjRbGraph

# "Find the user object " 
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users/$UserId" -ErrorAction SilentlyContinue
if (-not $targetUser) {
    throw ("User $UserId not found.")
}

# "Is user member of the the group?" 
if (Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/$UserID" -ErrorAction SilentlyContinue) {
    if ($remove) {
        Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/$UserId/`$ref" -Method Delete -Body $body | Out-Null
        "$($targetUser.UserPrincipalName) is removed from $GroupID"
    }
    else {    
        "User is already a member. No action taken."
    }
}
else {
    if ($remove) {
        "User is not a member. No action taken."
    }
    else {
        $body = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
        }
        Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/`$ref" -Method Post -Body $body | Out-Null
        "$($targetUser.UserPrincipalName) is added to $GroupID"    
    }
}


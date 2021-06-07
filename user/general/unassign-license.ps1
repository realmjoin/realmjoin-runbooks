# This runbook will remove a license from a user via removing a group membership.
#
# This runbook will use the "AzureRunAsConnection" to connect to AzureAD. Please make sure, enough API-permissions are given to this service principal.
#
# Permissions:
#  AzureAD Roles
#   - User administrator

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group } )]
    [String] $GroupID_License
)

Connect-RjRbGraph

# Licensing group prefix
$groupPrefix = "LIC_"

# "Find select group from Object ID " + $GroupID_License
$group = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID_License"
if (-not $group.displayName.startswith($groupPrefix)) {
    throw "'$($group.displayName)' is not a license assignment group. Will not proceed."
}

# "Find the user object " + $UserName) 
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter "userPrincipalName eq '$UserName'" -ErrorAction SilentlyContinue
if ($null -eq $targetUser) {
    throw ("User $UserName not found.")
}

# "Is user member of the the group?"
$members = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID_License/members" -ErrorAction SilentlyContinue
if ($members.id -contains $targetUser.id) {
    "Removing license."
    Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID_License/members/$($targetUser.id)/`$ref" -Method Delete | Out-Null
}
else {
    "License is not assigned. Doing nothing."
    
}

"'$($group.displayName)' is unassigned from '$UserName'"


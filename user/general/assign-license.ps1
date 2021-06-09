# This runbook will assign a license to a user via group membership.
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions:
#  AzureAD Roles
#   - User administrator

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }

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
if (-not $targetUser) {
    throw ("User $UserName not found.")
}

# "Is user member of the the group?" 
$members = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID_License/members" -ErrorAction SilentlyContinue
if ($members.id -contains $targetUser.id) {
    Write-Output "License is already assigned. No action taken."
}
else {
    "Assigning license"
    $body = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($targetUser.id)"
    }

    Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID_License/members/`$ref" -Method Post -Body $body | Out-Null
}

"'$($group.displayName)' is assigned to '$UserName'"

# This runbook will assign a license to a user via group membership.
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions:
#  AzureAD Roles
#   - User administrator

#Requires -Modules MEMPSToolkit, RealmJoin.RunbookHelper

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group } )]
    [String] $GroupID_License,
    [Parameter(Mandatory = $true)]
    [String] $OrganizationID
)

$ErrorActionPreference = "Stop"

#region module check
$neededModule = "MEMPSToolkit"

if (-not (Get-Module -ListAvailable $neededModule)) {
    throw ($neededModule + " is not available and can not be installed automatically. Please check.")
}
else {
    Import-Module $neededModule
    # "Module " + $neededModule + " is available."
}
#endregion

#region authentication
# Automation credentials
$automationCredsName = "realmjoin-automation-cred"

# "Connect to Graph API..."
$token = Get-AzAutomationCredLoginToken -tenant $OrganizationID -automationCredName $automationCredsName
#endregion

# Licensing group prefix
$groupPrefix = "LIC_"

# "Find select group from Object ID " + $GroupID_License
$group = Get-AADGroupById -groupId $GroupID_License -authToken $token
if (-not $group.displayName.startswith($groupPrefix)) {
    throw "`'$($group.displayName)`' is not a license assignment group. Will not proceed."
}

# "Find the user object " + $UserName) 
$targetUser = get-AADUserByUPN -userName $UserName -authToken $token
if ($null -eq $targetUser) {
    throw ("User $UserName not found.")
}

# "Is user member of the the group?" 
$members = Get-AADGroupMembers -groupID $GroupID_License -authToken $token
if ($members.id -contains $targetUser.id) {
    Write-Output "License is already assigned. No action taken."
}
else {
    "Assigning license"
    Add-AADGroupMember -groupID $GroupID_License -userID $targetUser.id -authToken $token | Out-Null
}

"`'$($group.displayName)`' is assigned to `'$UserName`'"




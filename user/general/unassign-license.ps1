# This runbook will remove a license from a user via removing a group membership.
#
# This runbook will use the "AzureRunAsConnection" to connect to AzureAD. Please make sure, enough API-permissions are given to this service principal.

#Requires -Module MEMPSToolkit, RealmJoin.RunbookHelper

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    ## FIXME Picker not working!
    #[ValidateScript( { Use-RJInterface -Type Graph -Entity Group } )]
    [String] $UI_GroupID_License,
    [Parameter(Mandatory = $true)]
    [String] $OrganizationID
)

#region module check
$neededModule = "MEMPSToolkit"

if (-not (Get-Module -ListAvailable $neededModule)) {
    throw ($neededModule + " is not available and can not be installed automatically. Please check.")
}
else {
    Import-Module $neededModule
    Write-Output ("Module " + $neededModule + " is available.")
}
#endregion

# Licensing group prefix
$groupPrefix = "LIC_"

# Automation credentials
$automationCredsName = "realmjoin-automation-cred"

Write-Output "Connect to Graph API..."
$token = Get-AzAutomationCredLoginToken -tenant $OrganizationID -automationCredName $automationCredsName

write-output ("Find selected group from Object ID " + $UI_GroupID_License)
$group = Get-AADGroupById -groupId $UI_GroupID_License -authToken $token
if (-not $group.displayName.startswith($groupPrefix)) {
    throw "Please select a licensing group."
}

write-output ("Find the user object " + $UserName) 
$targetUser = get-AADUserByUPN -userName $UserName -authToken $token
if ($null -eq $targetUser) {
    throw ("User " + $UserName + " not found.")
}

write-output ("Is user member of the the group?")
$members = Get-AADGroupMembers -groupID $UI_GroupID_License -authToken $token
if ($members.id -contains $targetUser.id) {
    Write-Output "Removing license."
    Remove-AADGroupMember -groupID $UI_GroupID_License -userID $targetUser.id -authToken $token
}
else {
    Write-Output "License is not assigned. Doing nothing."
    
}

Write-Output ($group.displayName + " is unassigned from " + $UserName)


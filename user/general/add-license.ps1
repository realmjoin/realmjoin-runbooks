# This runbook will block access of a user and revoke all current sessions (AzureAD tokens)
#
# This runbook will use the "AzureRunAsConnection" to connect to AzureAD. Please make sure, enough API-permissions are given to this service principal.
# Permissions:
# - AzureAD Role: User administrator

# Required modules. Will be honored by Azure Automation.
using module MEMPSToolkit

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [String] $UI_GroupID_License
)

# Licensing group prefix
$groupPrefix = "LIC_"

$connectionName = "AzureRunAsConnection"

Write-Output "Get Azure Automation Connection..."
$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

Write-Output "Connect to Graph API..."
$token = Get-AzAutomationCredLoginToken -tenant $servicePrincipalConnection.TenantId -automationCredName $automationCredsName

write-output ("Find select group from Object ID " + $UI_GroupID_License)
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
    Write-Output "License is already assigned. No action taken."
} else {
    Write-Output "Assigning license"
    Add-AADGroupMember -groupID $UI_GroupID_License -userID $targetUser.id -authToken $token
}




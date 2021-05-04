# This runbook is intended to orchestrate the different steps to temporarily offboard a user. This can be cases like parental leaves or sabaticals. 

#Requires -Modules AzureAD, RealmJoin.RunbookHelper

param (
    [String] $UserName
)

Write-Output "Getting Process configuration"
$processConfigURL = Get-AutomationVariable -name "SettingsSourceUserLeaverTemporary" -ErrorAction SilentlyContinue
$webResult = Invoke-WebRequest -UseBasicParsing -Uri $processConfigURL
$processConfig = $webResult.Content | ConvertFrom-Json    

#region Authentication
$connectionName = "AzureRunAsConnection"

# Get the connection "AzureRunAsConnection "
$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

write-output "Authenticate to AzureAD with AzureRunAsConnection..." 
try {
    Connect-AzureAD -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint -ApplicationId $servicePrincipalConnection.ApplicationId -TenantId $servicePrincipalConnection.TenantId | Out-Null
}
catch {
    Write-Error $_.Exception
    throw "AzureAD login failed"
}
#endregion

#region Get User object
write-output ("Find the user object " + $UserName) 
$targetUser = Get-AzureADUser -ObjectId $UserName -ErrorAction SilentlyContinue
if ($null -eq $targetUser) {
    throw ("User " + $UserName + " not found.")
}
#endregion

#region Disable user
if ($processConfig.disableUser) {
    Write-Output "Block user sign in"
    Set-AzureADUser -ObjectId $targetUser.ObjectId -AccountEnabled $false
}
#endregion

#region Export / Backup group and DL memberships
if ($processConfig.exportGroupMemberships) {

}
#endregion

#region Change license (group membership)
if ($processConfig.changeLicenses) {

}
#endregion

#region grant other user access to mailbox
if ($processConfig.grantAccessToMailbox) {

}
#endregion

#region out of office message
if ($processConfig.setOutOfOffice) {

}
#endregion

#region remove teams / M365 group ownerships?
## Assumption: Self healing process - either team is active or not. Team members will ask for help if needed.
#endregion

#region remove MFA methods
if ($processConfig.removeMFAMethods) {
    
}
#endregion

#region remove other (security) groups
#endregion

#region de-associate client
#endregion

#region wipe client
#endregion

#region finishing
Write-Output "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false
#endregion
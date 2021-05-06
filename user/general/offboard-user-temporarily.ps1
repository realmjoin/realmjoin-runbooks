# This runbook is intended to orchestrate the different steps to temporarily offboard a user. This can be cases like parental leaves or sabaticals. 

# If you store a users group memberships, you will need to have access

#Requires -Modules AzureAD, RealmJoin.RunbookHelper, Az.Storage

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
# Get list of group and role memberships. Write to file, as Set-AzStorageBlobContent needs a file to upload.
Get-AzureADUserMembership -ObjectId $UserName -All $true > "memberships.txt"
# Connect to / create Azure Storage Account
if ($processConfig.exportGroupMemberships) {
    $AzAAResourceGroup = Get-AutomationVariable -name "AzAAResourceGroup" -ErrorAction Stop
    $storAccount = Get-AzStorageAccount -ResourceGroupName $AzAAResourceGroup -Name $processConfig.exportStorAccountName -ErrorAction SilentlyContinue
    if (-not $storAccount) {
        $storAccount = New-AzStorageAccount -ResourceGroupName $AzAAResourceGroup -Name $processConfig.exportStorAccountName -ErrorAction Stop
    }
    $keys = Get-AzStorageAccountKey -ResourceGroupName $AzAAResourceGroup -Name $processConfig.exportStorAccountName
    $context = New-AzStorageContext -StorageAccountName $processConfig.exportStorAccountName -StorageAccountKey $keys[0].Value
    $container = Get-AzStorageContainer -Name $processConfig.exportStorContainerGroupmembershipExports -Context $context -ErrorAction SilentlyContinue
    if (-not $container) {
        $container = New-AzStorageContainer -Name $processConfig.exportStorContainerGroupmembershipExports -Context $context -ErrorAction Stop
    }
}
# Upload list. This might overwrite older versions.
Set-AzStorageBlobContent -File "memberships.txt" -Container $container -Blob $UserName -Context $context -Force
#endregion

#region Change license (group membership)
if ($processConfig.changeLicenses) {

}
#endregion

#region grant other user access to mailbox
if ($processConfig.grantAccessToMailbox) {

}
#endregion

#region hide mailbox in adresslist
if ($processConfig.hideFromAddresslist) {

}

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
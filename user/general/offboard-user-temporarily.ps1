# This runbook is intended to orchestrate the different steps to temporarily offboard a user. This can be cases like parental leaves or sabaticals. 

#Requires -Modules AzureAD, RealmJoin.RunbookHelper, Az.Storage

param (
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [String] $OrganizationID
)

Write-Output "Getting Process configuration URL"
$processConfigURL = Get-AutomationVariable -name "SettingsSourceUserLeaverTemporary" -ErrorAction Stop
Write-Output "Process Config URL is $($processConfigURL)"
Write-Output "Getting Process configuration"
$webResult = Invoke-WebRequest -UseBasicParsing -Uri $processConfigURL -ErrorAction Stop
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
write-output ("Finding the user object " + $UserName) 
$targetUser = Get-AzureADUser -ObjectId $UserName -ErrorAction SilentlyContinue
if ($null -eq $targetUser) {
    throw ("User " + $UserName + " not found.")
}
#endregion

#region Disable user
if ($processConfig.disableUser) {
    Write-Output "Blocking user sign in for $UserName"
    Set-AzureADUser -ObjectId $targetUser.ObjectId -AccountEnabled $false
}
#endregion

#region Export / Backup group and DL memberships
write-output "Getting list of group and role memberships for user $UserName." 
# Write to file, as Set-AzStorageBlobContent needs a file to upload.
$memberships = Get-AzureADUserMembership -ObjectId $targetUser.ObjectId -All $true
$memberships | Select-Object -Property "DisplayName","ObjectId" | ConvertTo-Json > memberships.txt
#Write-Output "Connectint to Azure Storage Account"
if ($processConfig.exportGroupMemberships) {
    #FIXME - Which subscription to use? Variable?
    Connect-AzAccount `
            -ServicePrincipal `
            -Tenant $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null
    $AzAAResourceGroup = Get-AutomationVariable -name "AzAAResourceGroup" -ErrorAction Stop
    $storAccount = Get-AzStorageAccount -ResourceGroupName $AzAAResourceGroup -Name $processConfig.exportStorAccountName -ErrorAction SilentlyContinue
    if (-not $storAccount) {
        Write-Output "Creating Azure Storage Account $($processConfig.exportStorAccountName)"
        ##FIXME: convert to variable? Needs to be unique per env. 
        $storAccount = New-AzStorageAccount -ResourceGroupName $AzAAResourceGroup -Name $processConfig.exportStorAccountName -Location $processConfig.exportStorAccountLocation -SkuName $processConfig.exportStorAccountSKU -ErrorAction Stop
    }
    $keys = Get-AzStorageAccountKey -ResourceGroupName $AzAAResourceGroup -Name $processConfig.exportStorAccountName
    $context = New-AzStorageContext -StorageAccountName $processConfig.exportStorAccountName -StorageAccountKey $keys[0].Value
    $container = Get-AzStorageContainer -Name $processConfig.exportStorContainerGroupMembershipExports -Context $context -ErrorAction SilentlyContinue
    if (-not $container) {
        Write-Output "Creating Azure Storage Account Container $($processConfig.exportStorContainerGroupmembershipExports)"
        $container = New-AzStorageContainer -Name $processConfig.exportStorContainerGroupmembershipExports -Context $context -ErrorAction Stop
    }
}
Write-Output "Uploading list of memberships. This might overwrite older versions."
Set-AzStorageBlobContent -File "memberships.txt" -Container $processConfig.exportStorContainerGroupmembershipExports -Blob $UserName -Context $context -Force -ErrorAction Stop | Out-Null
Disconnect-AzAccount -Confirm:$false
#endregion

#region Change license (group membership)
if ($processConfig.changeLicenses) {
    # Add new licensing group, if not already assigned
    $processConfig.licenseGroupsToAdd | ForEach-Object {
        $group =  Get-AzureADGroup -Filter "DisplayName eq `'$_`'" 
        Write-Output "Adding License group $_ to user $UserName"
        Add-AzureADGroupMember -RefObjectId $targetUser.ObjectID -ObjectId $group.ObjectID -ErrorAction Continue
    }

    # Remove all other known licensing groups
    $groups = Get-AzureADUserMembership -ObjectId $targetUser.ObjectId
    $groups | Where-Object { $_.DisplayName.startswith($processConfig.licenseGroupsToRemovePrefix)} | ForEach-Object {
        if (-not $processConfig.licenseGroupsToAdd.contains($_.DisplayName)) {
            Write-Output "Removing license group $($_.DisplayName) from $UserName"
            Remove-AzureADGroupMember -MemberId $targetUser.ObjectId -ObjectId $_.ObjectID -ErrorAction Continue
        }
    }
}
#endregion

#region grant other user access to mailbox
if ($processConfig.grantAccessToMailbox) {
##TODO
}
#endregion

#region hide mailbox in adresslist
if ($processConfig.hideFromAddresslist) {
##TODO
}

#region out of office message
if ($processConfig.setOutOfOffice) {
##TODO
}
#endregion

#region remove teams / M365 group ownerships?
## Assumption: Self healing process - either team is active or not. Team members will ask for help if needed.
#endregion

#region remove MFA methods
if ($processConfig.removeMFAMethods) {
##TODO    
}
#endregion

#region remove other (security) groups
##TODO
#endregion

#region de-associate client
##TODO
#endregion

#region wipe client
##TODO
#endregion

#region finishing
Write-Output "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false

Write-Output "Temporary offboarding of $($UserName) successful."
#endregion
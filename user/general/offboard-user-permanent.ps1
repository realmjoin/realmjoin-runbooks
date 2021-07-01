<#
  .SYNOPSIS
  Permanently offboard a user.

  .DESCRIPTION
  Permanently offboard a user.
  
#>

#Requires -Modules AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }, Az.Storage

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName
)

# Connect Azure AD
Connect-RjRbAzureAD

#region configuration import
#"Getting Process configuration"
$processConfigRaw = Get-AutomationVariable -name "SettingsOrgUserLeaverPerm" -ErrorAction SilentlyContinue
if (-not $processConfigRaw) {
    ## production default
    # $processConfigURL = "https://raw.githubusercontent.com/realmjoin/realmjoin-runbooks/production/setup/defaults/settings.json"
    ## staging default
    $processConfigURL = "https://raw.githubusercontent.com/realmjoin/realmjoin-runbooks/master/setup/defaults/settings.json"
    $webResult = Invoke-WebRequest -UseBasicParsing -Uri $processConfigURL 
    $processConfigRaw = $webResult.Content 
}
# Write-RjRbDebug "Process Config URL is $($processConfigURL)"

# "Getting Process configuration"
$processConfig = $processConfigRaw | ConvertFrom-Json
#endregion


#region Get User object
"Finding the user object $UserName"
# AzureAD Module is broken in regards to ErrorAction.
$ErrorActionPreference = "SilentlyContinue"
$targetUser = Get-AzureADUser -ObjectId $UserName
if (-not $targetUser) {
    throw ("User " + $UserName + " not found.")
}
# AzureAD Module is broken in regards to ErrorAction.
$ErrorActionPreference = "Stop"
#endregion

#region Disable user
if ($processConfig.disableUser) {
    "Blocking user sign in for $UserName"
    Set-AzureADUser -ObjectId $targetUser.ObjectId -AccountEnabled $false
}
#endregion

#region Export / Backup group and DL memberships
# "Getting list of group and role memberships for user $UserName." 
# Write to file, as Set-AzStorageBlobContent needs a file to upload.
$memberships = Get-AzureADUserMembership -ObjectId $targetUser.ObjectId -All $true
$memberships | Select-Object -Property "DisplayName", "ObjectId" | ConvertTo-Json > memberships.txt
# "Connectint to Azure Storage Account"
if ($processConfig.exportGroupMemberships) {
    # "Connecting to Az module..."
    Connect-RjRbAzAccount
    # Get Resource group and storage account
    $AzAAResourceGroup = $processConfig.exportResourceGroupName
    $storAccount = Get-AzStorageAccount -ResourceGroupName $AzAAResourceGroup -Name $processConfig.exportStorAccountName -ErrorAction SilentlyContinue
    if (-not $storAccount) {
        "Creating Azure Storage Account $($processConfig.exportStorAccountName)"
        $storAccount = New-AzStorageAccount -ResourceGroupName $AzAAResourceGroup -Name $processConfig.exportStorAccountName -Location $processConfig.exportStorAccountLocation -SkuName $processConfig.exportStorAccountSKU 
    }
    $keys = Get-AzStorageAccountKey -ResourceGroupName $AzAAResourceGroup -Name $processConfig.exportStorAccountName
    $context = New-AzStorageContext -StorageAccountName $processConfig.exportStorAccountName -StorageAccountKey $keys[0].Value
    $container = Get-AzStorageContainer -Name $processConfig.exportStorContainerGroupMembershipExports -Context $context -ErrorAction SilentlyContinue
    if (-not $container) {
        "Creating Azure Storage Account Container $($processConfig.exportStorContainerGroupmembershipExports)"
        $container = New-AzStorageContainer -Name $processConfig.exportStorContainerGroupmembershipExports -Context $context 
    }
}
"Uploading list of memberships. This might overwrite older versions."
Set-AzStorageBlobContent -File "memberships.txt" -Container $processConfig.exportStorContainerGroupmembershipExports -Blob $UserName -Context $context -Force | Out-Null
Disconnect-AzAccount -Confirm:$false | Out-Null
#endregion

#region delete user
if ($processConfig.deleteUser) {
    "Deleting User Object $UserName"
    Remove-AzureADUser -ObjectId $targetUser.ObjectId
    Disconnect-AzureAD -Confirm:$false | Out-Null
    "Offboarding of $($UserName) successful."
    # Script ends here
    exit
}
#endregion

#region Change license (group membership)
if ($processConfig.changeLicenses) {
    # Add new licensing group, if not already assigned
    $processConfig.licenseGroupsToAdd | ForEach-Object {
        $group = Get-AzureADGroup -Filter "DisplayName eq `'$_`'" 
        "Adding License group $_ to user $UserName"
        # AzureAD is broken in regards to ErrorAction...
        $ErrorActionPreference = "Continue"
        Add-AzureADGroupMember -RefObjectId $targetUser.ObjectID -ObjectId $group.ObjectID
        $ErrorActionPreference = "Stop"
    }

    # Remove all other known licensing groups
    $groups = Get-AzureADUserMembership -ObjectId $targetUser.ObjectId
    $groups | Where-Object { $_.DisplayName.startswith($processConfig.licenseGroupsToRemovePrefix) } | ForEach-Object {
        if (-not $processConfig.licenseGroupsToAdd.contains($_.DisplayName)) {
            "Removing license group $($_.DisplayName) from $UserName"
            # AzureAD is broken in regards to ErrorAction...
            $ErrorActionPreference = "Continue"
            Remove-AzureADGroupMember -MemberId $targetUser.ObjectId -ObjectId $_.ObjectID
            $ErrorActionPreference = "Stop"
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

# "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false | Out-Null

"Offboarding of $($UserName) successful."

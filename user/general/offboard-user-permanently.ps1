<#
  .SYNOPSIS
  Permanently offboard a user.

  .DESCRIPTION
  Permanently offboard a user.

  .NOTES
  Permissions
  AzureAD Roles
  - User administrator
  Azure IaaS: "Contributor" access on subscription or resource group used for the export
  
  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            }
        }
    }

  .EXAMPLE
  Full Runbook Customizing Example:
  {
    "Settings": {
        "OffboardUserPermanently": {
            "deleteUser": true,
            "disableUser": false,
            "revokeAccess": true,
            "exportResourceGroupName": "rjtestrunbooks01",
            "exportStorAccountName": "rjrbexports01",
            "exportStorAccountLocation": "West Europe",
            "exportStorAccountSKU": "Standard_LRS",
            "exportStorContainerGroupMembershipExports": "user-leaver-groupmemberships",
            "exportGroupMemberships": true,
            "changeLicenses": true,
            "licenseGroupsToAdd": "LIC_M365_E1",
            "licenseGroupsToRemovePrefix": "LIC_M365",
            "grantAccessToMailbox": true,
            "hideFromAddresslist": true,
            "setOutOfOffice": true,
            "removeMFAMethods": true,
            "secGroupsToRemove": ""
        }
    },
    "Runbooks": {
        "rjgit-user_general_offboard-user-permanently": {
            "ParameterList": [
                {
                    "Name": "disableUser",
                    "Hide": true
                },
                {
                    "Name": "deleteUser",
                    "Hide": true
                },
                {
                    "Name": "revokeAccess",
                    "Hide": true
                },
                {
                    "Name": "exportGroupMemberships",
                    "Hide": true
                },
                {
                    "Name": "exportResourceGroupName",
                    "Hide": true
                },
                {
                    "Name": "exportStorAccountName",
                    "Hide": true
                },
                {
                    "Name": "exportStorAccountLocation",
                    "Hide": true
                },
                {
                    "Name": "exportStorAccountSKU",
                    "Hide": true
                },
                {
                    "Name": "exportStorContainerGroupMembershipExports",
                    "Hide": true
                },
                {
                    "DisplayName": "Change Assigned Licenses",
                    "DisplayBefore": "LicenseGroupToAdd",
                    "Select": {
                        "Options": [
                            {
                                "Display": "Reduce the users licenses",
                                "Customization": {
                                    "Default": {
                                        "ChangeLicenses": true
                                    }
                                }
                            },
                            {
                                "Display": "Do not change assigned licenses",
                                "Customization": {
                                    "Default": {
                                        "ChangeLicenses": false
                                    },
                                    "Hide": [
                                        "LicenseGroupToAdd",
                                        "GroupsToRemovePrefix"
                                    ]
                                }
                            }
                        ],
                        
                    },
                    "Default": "Do not change assigned licenses"
                }, {
                    "Name": "ChangeLicenses",
                    "Hide": true
                }
            ]
        }
    }
}
#>

#Requires -Modules AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, Az.Storage

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.deleteUser" } )]
    [bool] $DeleteUser = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.disableUser" } )]
    [bool] $DisableUser = $false,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.revokaAccess" } )]
    [bool] $RevokeAccess = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.exportResourceGroupName" } )]
    [String] $exportResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.exportStorAccountName" } )]
    [String] $exportStorAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.exportStorAccountLocation" } )]
    [String] $exportStorAccountLocation,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.exportStorAccountSKU" } )]
    [String] $exportStorAccountSKU,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.exportStorContainerGroupMembershipExports" } )]
    [String] $exportStorContainerGroupMembershipExports,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.exportGroupMemberships" -DisplayName "Create a backup of the user's group memberships" } )]
    [bool] $exportGroupMemberships = $false,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.changeLicenses" } )]
    [bool] $ChangeLicenses = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.licenseGroupsToAdd" } )]
    [string] $LicenseGroupToAdd = "LIC_M365_E1",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.licenseGroupsToRemovePrefix" } )]
    [String] $GroupsToRemovePrefix = "LIC_M365"

    ## Still TODO...
    #[ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.grantAccessToMailbox" } )]
    #[bool] $grantAccessToMailbox = $true,
    #[ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.hideFromAddresslist" } )]
    #[bool] $hideFromAddresslist = $true,
    #[ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.setOutOfOffice" } )]
    #[bool] $setOutOfOffice = $true,
    #[ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.removeMFAMethods" } )]
    #[bool] $removeMFAMethods = $true,
    #[ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.secGroupsToRemove" } )]
    #[String] $GroupsToRemove = ""
)

# Sanity checks
if ($exportGroupMemberships -and ((-not $exportResourceGroupName) -or (-not $exportStorAccountName) -or (-not $exportStorAccountLocation) -or (-not $exportStorAccountSKU))) {
    "## To export group memberships, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    ""
    "## Configure the following attributes:"
    "## - OffboardUserPermanently.exportResourceGroupName"
    "## - OffboardUserPermanently.exportStorAccountName"
    "## - OffboardUserPermanently.exportStorAccountLocation"
    "## - OffboardUserPermanently.exportStorAccountSKU"
    ""
    "## Disabling Group Membership Backup/Export."
    $exportGroupMemberships = $false
    ""
}

# Connect Azure AD
Connect-RjRbAzureAD

"## Finding the user object $UserName"
# AzureAD Module is broken in regards to ErrorAction.
$ErrorActionPreference = "SilentlyContinue"
$targetUser = Get-AzureADUser -ObjectId $UserName
if (-not $targetUser) {
    throw ("User " + $UserName + " not found.")
}
# AzureAD Module is broken in regards to ErrorAction.
$ErrorActionPreference = "Stop"

if ($DisableUser) {
    "Blocking user sign in for $UserName"
    Set-AzureADUser -ObjectId $targetUser.ObjectId -AccountEnabled $false | Out-Null
}

if ($RevokeAccess) {
    "Revoke all refresh tokens"
    Revoke-AzureADUserAllRefreshToken -ObjectId $targetUser.ObjectId | Out-Null
}

# "Getting list of group and role memberships for user $UserName." 
# Write to file, as Set-AzStorageBlobContent needs a file to upload.
$memberships = Get-AzureADUserMembership -ObjectId $targetUser.ObjectId -All $true
$memberships | Select-Object -Property "DisplayName", "ObjectId" | ConvertTo-Json > memberships.txt
# "Connectint to Azure Storage Account"
if ($exportGroupMemberships) {
    # "Connecting to Az module..."
    Connect-RjRbAzAccount
    # Get Resource group and storage account
    $storAccount = Get-AzStorageAccount -ResourceGroupName $exportResourceGroupName -Name $exportStorAccountName -ErrorAction SilentlyContinue
    if (-not $storAccount) {
        "## Creating Azure Storage Account $($exportStorAccountName)"
        $storAccount = New-AzStorageAccount -ResourceGroupName $exportResourceGroupName -Name $exportStorAccountName -Location $exportStorAccountLocation -SkuName $exportStorAccountSKU 
    }
    $keys = Get-AzStorageAccountKey -ResourceGroupName $exportResourceGroupName -Name $exportStorAccountName
    $context = New-AzStorageContext -StorageAccountName $exportStorAccountName -StorageAccountKey $keys[0].Value
    $container = Get-AzStorageContainer -Name $exportStorContainerGroupMembershipExports -Context $context -ErrorAction SilentlyContinue
    if (-not $container) {
        "## Creating Azure Storage Account Container $($exportStorContainerGroupmembershipExports)"
        $container = New-AzStorageContainer -Name $exportStorContainerGroupmembershipExports -Context $context 
    }

    "## Uploading list of memberships. This might overwrite older versions."
    Set-AzStorageBlobContent -File "memberships.txt" -Container $exportStorContainerGroupmembershipExports -Blob $UserName -Context $context -Force | Out-Null
    Disconnect-AzAccount -Confirm:$false | Out-Null
}

if ($DeleteUser) {
    "## Deleting User Object $UserName"
    Remove-AzureADUser -ObjectId $targetUser.ObjectId
    "## Offboarding of $($UserName) successful."
    # Script ends here
    Disconnect-AzureAD -Confirm:$false | Out-Null
    exit
}

if ($ChangeLicenses) {
    # Add new licensing group, if not already assigned
    if ($LicenseGroupToAdd) {
        $group = Get-AzureADGroup -Filter "DisplayName eq `'$LicenseGroupToAdd`'" 
        "## Adding License group $LicenseGroupToAdd to user $UserName"
        # AzureAD is broken in regards to ErrorAction...
        $ErrorActionPreference = "Continue"
        Add-AzureADGroupMember -RefObjectId $targetUser.ObjectID -ObjectId $group.ObjectID
        $ErrorActionPreference = "Stop"
    }

    # Remove all other known licensing groups
    $groups = Get-AzureADUserMembership -ObjectId $targetUser.ObjectId
    $groups | Where-Object { $_.DisplayName.startswith($licenseGroupsToRemovePrefix) } | ForEach-Object {
        if ($LicenseGroupToAdd -ne $_.DisplayName) {
            "## Removing license group $($_.DisplayName) from $UserName"
            # AzureAD is broken in regards to ErrorAction...
            $ErrorActionPreference = "Continue"
            Remove-AzureADGroupMember -MemberId $targetUser.ObjectId -ObjectId $_.ObjectID
            $ErrorActionPreference = "Stop"
        }
    }
}

if ($grantAccessToMailbox) {
    ##TODO
}

if ($hideFromAddresslist) {
    ##TODO
}

if ($setOutOfOffice) {
    ##TODO
}

# Team Owner?
## Assumption: Self healing process - either team is active or not. Team members will ask for help if needed.

if ($removeMFAMethods) {
    ##TODO    
}

# de-associate client
##TODO

# wipe client
##TODO

# "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false | Out-Null

"## Offboarding of $($UserName) successful."

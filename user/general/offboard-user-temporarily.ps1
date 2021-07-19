<#
  .SYNOPSIS
  Temporarily offboard a user.

  .DESCRIPTION
  Temporarily offboard a user in cases like parental leaves or sabaticals.
  
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
  Full RJ Runbook Customizing Sample:
    {
        "Settings": {
            "OffboardUserTemporarily": {
                "disableUser": true,
                "revokeAccess": true,
                "exportResourceGroupName": "rjtestrunbooks-01",
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
            "rjgit-user_general_offboard-user-temporarily": {
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
                            ]
                            
                        },
                        "Default": "Reduce the users licenses"
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
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.disableUser" } )]
    [bool] $DisableUser = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.revokaAccess" } )]
    [bool] $RevokeAccess = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.exportResourceGroupName" } )]
    [String] $exportResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.exportStorAccountName" } )]
    [String] $exportStorAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.exportStorAccountLocation" } )]
    [String] $exportStorAccountLocation,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.exportStorAccountSKU" } )]
    [String] $exportStorAccountSKU,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.exportStorContainerGroupMembershipExports" } )]
    [String] $exportStorContainerGroupMembershipExports,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.exportGroupMemberships" -DisplayName "Create a backup of the user's group memberships"} )]
    [bool] $exportGroupMemberships = $false,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.changeLicenses" } )]
    [bool] $ChangeLicenses = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.licenseGroupsToAdd" } )]
    [string] $LicenseGroupToAdd = "LIC_M365_E1",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.licenseGroupsToRemovePrefix" } )]
    [String] $GroupsToRemovePrefix = "LIC_M365"

)

# Sanity checks
if ($exportGroupMemberships -and ((-not $exportResourceGroupName) -or (-not $exportStorAccountName))) {
    throw "To export group memberships, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
}

# Connect Azure AD
Connect-RjRbAzureAD

"Finding the user object $UserName"
# AzureAD Module is broken in regards to ErrorAction.
$ErrorActionPreference = "SilentlyContinue"
$targetUser = Get-AzureADUser -ObjectId $UserName
if (-not $targetUser) {
    throw ("User " + $UserName + " not found.")
}
$ErrorActionPreference = "Stop"

if ($DisableUser) {
    "Blocking user sign in for $UserName"
    Set-AzureADUser -ObjectId $targetUser.ObjectId -AccountEnabled $false
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
        "Creating Azure Storage Account $($exportStorAccountName)"
        $storAccount = New-AzStorageAccount -ResourceGroupName $exportResourceGroupName -Name $exportStorAccountName -Location $exportStorAccountLocation -SkuName $exportStorAccountSKU 
    }
    $keys = Get-AzStorageAccountKey -ResourceGroupName $exportResourceGroupName -Name $exportStorAccountName
    $context = New-AzStorageContext -StorageAccountName $exportStorAccountName -StorageAccountKey $keys[0].Value
    $container = Get-AzStorageContainer -Name $exportStorContainerGroupMembershipExports -Context $context -ErrorAction SilentlyContinue
    if (-not $container) {
        "Creating Azure Storage Account Container $($exportStorContainerGroupmembershipExports)"
        $container = New-AzStorageContainer -Name $exportStorContainerGroupmembershipExports -Context $context 
    }
}
"Uploading list of memberships. This might overwrite older versions."
Set-AzStorageBlobContent -File "memberships.txt" -Container $exportStorContainerGroupmembershipExports -Blob $UserName -Context $context -Force | Out-Null
Disconnect-AzAccount -Confirm:$false | Out-Null

if ($ChangeLicenses) {
    # Add new licensing group, if not already assigned
    if ($LicenseGroupToAdd) {
        $group = Get-AzureADGroup -Filter "DisplayName eq `'$LicenseGroupToAdd`'" 
        "Adding License group $LicenseGroupToAdd to user $UserName"
        # AzureAD is broken in regards to ErrorAction...
        $ErrorActionPreference = "Continue"
        Add-AzureADGroupMember -RefObjectId $targetUser.ObjectID -ObjectId $group.ObjectID
        $ErrorActionPreference = "Stop"
    }

    # Remove all other known licensing groups
    $groups = Get-AzureADUserMembership -ObjectId $targetUser.ObjectId
    $groups | Where-Object { $_.DisplayName.startswith($licenseGroupsToRemovePrefix) } | ForEach-Object {
        if ($LicenseGroupToAdd -ne $_.DisplayName) {
            "Removing license group $($_.DisplayName) from $UserName"
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

## remove teams / M365 group ownerships?
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

"Temporary offboarding of $($UserName) successful."

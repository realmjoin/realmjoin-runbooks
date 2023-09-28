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

  .PARAMETER ReplacementOwnerName
  Who will take over group ownership if the offboarded user is the last remaining group owner? Will only be used if needed.

  .Parameter ChangeGroupsSelector
  "Change" and "Remove all" will both honour "groupToAdd"

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "DeleteUser": {
                "Select": {
                    "Options": [
                        {
                            "Display": "Delete user object",
                            "Value": true,
                            "Customization": {
                                "Hide": [
                                    "ChangeLicensesSelector",
                                    "ChangeGroupsSelector",
                                    "DisableUser",
                                    "GroupToAdd",
                                    "GroupsToRemovePrefix"
                                ]
                            }
                        },
                        {
                            "Display": "Keep the user object",
                            "Value": false
                        }
                    ]
                }
            },
            "exportGroupMemberships": {
                "Hide": true,
            },
            "exportResourceGroupName": {
                "Hide": true
            },
            "exportStorAccountName": {
                "Hide": true
            },
            "exportStorAccountLocation": {
                "Hide": true
            },
            "exportStorAccountSKU": {
                "Hide": true
            },
            "exportStorContainerGroupMembershipExports": {
                "Hide": true
            },
            "ChangeLicensesSelector": {
                "DisplayName": "Change directly assigned licenses",
                "Select": {
                    "Options": [
                        {
                            "Display": "Do not change assigned licenses",
                            "Value": 0
                        },
                        {
                            "Display": "Remove all directly assigned licenses",
                            "Value": 2
                        }
                    ]
                }
            },
            "ChangeGroupsSelector": {
                "DisplayName": "Change assigned groups",
                "Select": {
                    "Options": [
                        {
                            "Display": "Do not change assigned groups",
                            "Value": 0,
                        },
                        {
                            "Display": "Change the user's groups.",
                            "Value": 1
                        },
                        {
                            "Display": "Remove all groups",
                            "Value": 2,
                        }    
                    ]
                }
            },
            "RevokeGroupOwnership": {
                "DisplayName": "Handle group ownerships",
                "Select": {
                    "Options": [
                        {
                            "Display": "User will remain owner / Do not change",
                            "Value": false,
                        },
                        {
                            "Display": "Remove/Replace this user's group ownerships",
                            "Value": true
                        }
                    ]
                }
            },
            "ManagerAsReplacementOwner": {
                "Description": "Fetch the user's manager from AzureAD as replacing owner. This takes precedence over manually specifying a replacement owner."
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
            "exportResourceGroupName": "rj-test-runbooks-01",
            "exportStorAccountName": "jrbexports01",
            "exportStorAccountLocation": "West Europe",
            "exportStorAccountSKU": "Standard_LRS",
            "exportStorContainerGroupMembershipExports": "user-leaver-groupmemberships",
            "exportGroupMemberships": true,
            "licensesMode": 0, // "false": Do nothing, "true": remove all directly assigned licenses
            "groupsMode": 0, // 0: Do nothing, 1: Change, 2: Remove all
            "groupToAdd": "",
            "groupsToRemovePrefix": ""
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
                    "Name": "revokeAccess",
                    "Hide": true
                },
                {
                    "Name": "ChangeLicensesSelector",
                    "Hide": true
                },
                {
                    "Name": "ChangeGroupsSelector",
                    "Hide": true
                },
                {
                    "Name": "GroupToAdd",
                    "Hide": true
                },
                {
                    "Name": "GroupsToRemovePrefix",
                    "Hide": true
                },
                {
                    "Name": "CallerName",
                    "Hide": true
                }
            ]
        }
    }
}

  .INPUTS
  RunbookCustomization: {
        "Parameters": {            
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }, Az.Storage, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.deleteUser" } )]
    [bool] $DeleteUser = $false,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.disableUser" } )]
    [bool] $DisableUser = $true,
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
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.licensesMode" } )]
    [int] $ChangeLicensesSelector = 0,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.groupsMode" } )]
    [int] $ChangeGroupsSelector = 0,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.groupToAdd" -DisplayName "Group to add or keep" } )]
    [string] $GroupToAdd,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.groupsToRemovePrefix" -DisplayName "Remove groups starting with this prefix" } )]
    [String] $GroupsToRemovePrefix,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.revokeGroupOwnership" -DisplayName "Remove/Replace this user's group ownerships" })]
    [bool] $RevokeGroupOwnership = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Grant ownership of the user's resources to the user's manager?" } )]
    [bool] $ManagerAsReplacementOwner = $true,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Who should step in as group/resource owner?" } )]
    [String] $ReplacementOwnerName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

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

Connect-RjRbGraph
Connect-RjRbExchangeOnline

"## Trying to permanently offboard user '$UserName'"

Write-RjRbLog "Finding the user object '$UserName'"
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName"
if (-not $targetUser) {
    throw ("User '$UserName' not found.")
}

if ($DisableUser) {
    "## Blocking user sign in for '$UserName'"
    $body = @{ accountEnabled = $false }
    Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)" -Method Patch -Body $body | Out-Null
}

if ($RevokeAccess) {
    "## Revoke all refresh tokens"
    $body = @{ }
    Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/revokeSignInSessions" -Method Post -Body $body | Out-Null
}

Write-RjRbLog "Getting list of group memberships for user '$UserName'." 
# Write to file, as Set-AzStorageBlobContent needs a file to upload.
$membershipIds = Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/getMemberGroups" -Method Post -Body @{ securityEnabledOnly = $false }
$memberships = $membershipIds | ForEach-Object {
    Invoke-RjRbRestMethodGraph -Resource "/groups/$_"
}
$memberships | Select-Object -Property "displayName", "id" | ConvertTo-Json > memberships.txt

# "Connectint to Azure Storage Account"
if ($exportGroupMemberships) {
    Write-RjRbLog "Connecting to Azure Storage Account"
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
        "## Creating Azure Storage Account Container '$exportStorContainerGroupmembershipExports'"
        $container = New-AzStorageContainer -Name $exportStorContainerGroupmembershipExports -Context $context 
    }

    "## Uploading list of memberships. This might overwrite older versions."
    Set-AzStorageBlobContent -File "memberships.txt" -Container $exportStorContainerGroupmembershipExports -Blob $UserName -Context $context -Force | Out-Null
    Disconnect-AzAccount -Confirm:$false | Out-Null
}

if ($ManagerAsReplacementOwner) {
    $manager = Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/manager" -ErrorAction SilentlyContinue
    if ($manager) {
        $ReplacementOwner = $manager
        $ReplacementOwnerName = $manager.userPrincipalName
    }
}


# Remove user from group owners UNLESS the group would have no remaining (or replacing) owner
if ($RevokeGroupOwnership) {
    $OwnedGroups = Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/ownedObjects/microsoft.graph.group/"
    if ($OwnedGroups) {
        foreach ($OwnedGroup in $OwnedGroups) {
            $owners = Invoke-RjRbRestMethodGraph -Resource "/groups/$($OwnedGroup.id)/owners"
            if (([array]$owners).Count -eq 1) {
                "## '$UserName' is the last remaining owner of group '$($OwnedGroup.displayName)'"
                if ($ReplacementOwnerName -and -not $ReplacementOwner) {
                    $ReplacementOwner = Invoke-RjRbRestMethodGraph -Resource "/users/$ReplacementOwnerName" -ErrorAction SilentlyContinue
                }
                if ($ReplacementOwner) {
                    $ReplacementBodyString = "https://graph.microsoft.com/v1.0/users/$($ReplacementOwner.id)"
                    $ReplacementBody = @{"@odata.id" = $ReplacementBodyString }
                    Invoke-RjRbRestMethodGraph -Resource "/groups/$($OwnedGroup.id)/owners/`$ref" -Body $ReplacementBody
                    Invoke-RjRbRestMethodGraph -Resource "/groups/$($OwnedGroup.id)/owners/$($targetUser.id)/`$ref" -Method Delete
                    "## Changed ownership of group '$($OwnedGroup.displayName)' to '$($ReplacementOwner.userPrincipalName)'"
                }
                else {
                    if ($ReplacementOwnerName) {
                        "## Replacement Owner '$ReplacementOwnerName' not found."
                    }
                    else {
                        "## No Replacement Owner given."
                    }
                    "## Skipping ownership change for group '$($OwnedGroup.displayName)'." 
                    "## Please verify owners of group '$($OwnedGroup.displayName)' manually!"
                }
            }
            else {
                Invoke-RjRbRestMethodGraph -Resource "/groups/$($OwnedGroup.id)/owners/$($targetUser.id)/`$ref" -Method Delete
                "## Revoked Ownership of group '$($OwnedGroup.displayName)'"
            }
            
        }
    }
}

if ($DeleteUser) {
    if (($ChangeGroupsSelector -ne 0) -or ($ChangeLicensesSelector -ne 0)) {
        "## Skipping license/group modifications as User object will be deleted."
    }

    "## Deleting User Object $UserName"
    Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)" -Method Delete | Out-Null
    "## Offboarding of $($UserName) successful."
    # Script ends here
    exit
}

if ($ChangeGroupsSelector -ne 0) {
    # Add new licensing group, if not already assigned
    if ($GroupToAdd -and ($memberships.DisplayName -notcontains $GroupToAdd)) {
        $group = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$GroupToAdd'" 
        if (([array]$group).count -eq 1) {
            "## Adding group '$GroupToAdd' to user $UserName"
            $body = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($targetUser.id)"
            }
            Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members/`$ref" -Method Post -Body $body | Out-Null
        }
        else {
            "## Could not resove group name '$GroupToAdd', skipping..."
        }
    }
    

    # Search groups by prefix
    if (($ChangeGroupsSelector -eq 1) -and $GroupsToRemovePrefix) {
        $groupsToRemove = $memberships  | Where-Object { $_.displayName.startswith($GroupsToRemovePrefix) } 
    }

    # Choose all groups
    if ($ChangeGroupsSelector -eq 2) {
        $groupsToRemove = $memberships 
    }

    # Remove group memberships
    $groupsToRemove | ForEach-Object {
        if ($GroupToAdd -ne $_.DisplayName) {
            if ($_.groupTypes -contains "DynamicMembership") {
                "## Group '$($_.DisplayName)' is a dynamic group - skipping."
            }
            else {
                "## Removing group '$($_.DisplayName)' from $UserName"
                if (($_.GroupTypes -contains "Unified") -or (-not $_.MailEnabled)) {
                    # group is AAD group            
                    try {
                        Invoke-RjRbRestMethodGraph -Resource "/groups/$($_.id)/members/$($targetUser.id)/`$ref" -Method Delete | Out-Null
                    }
                    catch {
                        "## ... group removal failed. Please check."
                    }                
                }
                else {
                    # Handle Exchange Distr. Lists etc.
                    if ($_.mail) {
                        try {
                            Remove-DistributionGroupMember -Identity $_.mail -Member $UserName -BypassSecurityGroupManagerCheck -Confirm:$false
                        }
                        catch {
                            "## ... group removal failed. Please check."
                        }   
                    }
                    else {
                        "## ... failed - '$($_.DisplayName)' is neither an AAD group, nor has an eMail-Address"
                    }           
                }
            
            }
        }
    }
}

if ($ChangeLicensesSelector -ne 0) {
    $assignments = Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)" -OdSelect "licenseAssignmentStates"

    # Remove all directly assigned licenses
    if ($ChangeLicensesSelector -eq 2) {
        $licsToRemove = @()
        $assignments.licenseAssignmentStates | Where-Object { $null -eq $_.assignedByGroup } | ForEach-Object {
            $licsToRemove += $_.skuId
        }
        if ($licsToRemove.Count -gt 0) {
            $body = @{
                "addLicenses"    = @()
                "removeLicenses" = $licsToRemove
            }
            "## Removing license assignments $licsToRemove"
            try {
                Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/assignLicense" -Method Post -Body $body | Out-Null
            }
            catch {
                "## ... removing licenses failed. Please check."
            }
        }
    }
}

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

"## Offboarding of $($UserName) successful."
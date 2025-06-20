<#
  .SYNOPSIS
  Temporarily offboard a user.

  .DESCRIPTION
  Temporarily offboard a user in cases like parental leaves or sabaticals.

  .Parameter ChangeGroupsSelector
  "Change" and "Remove all" will both honour "groupToAdd"

  .PARAMETER ReplacementOwnerName
  Who will take over group ownership if the offboarded user is the last remaining group owner? Will only be used if needed.

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
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
                            "Display": "Change the user's groups",
                            "Value": 1
                        },
                        {
                            "Display": "Remove all groups",
                            "Value": 2
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
                            "Value": false
                        },
                        {
                            "Display": "Remove/Replace this user's group ownerships",
                            "Value": true
                        }
                    ]
                }
            },
        }
    }

  .EXAMPLE
  Full RJ Runbook Customizing Sample:
  {
    "Settings": {
        "OffboardUserTemporarily": {
            "disableUser": true,
            "revokeAccess": true,
            "exportGroupMemberships": false,
            "exportResourceGroupName": "rj-test-runbooks-01",
            "exportStorAccountName": "rjrbexports01",
            "exportStorAccountLocation": "West Europe",
            "exportStorAccountSKU": "Standard_LRS",
            "exportStorContainerGroupMembershipExports": "user-leaver-groupmemberships",
            "licensesMode": 2, // "false": Do nothing, "true": remove all directly assigned licenses
            "groupsMode": 1, // 0: Do nothing, 1: Change, 2: Remove all
            "groupToAdd": "LIC_M365_E1",
            "groupsToRemovePrefix": "LIC_"
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }, Az.Storage, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.revokeAccess" } )]
    [bool] $RevokeAccess = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.disableUser" } )]
    [bool] $DisableUser = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.exportResourceGroupName" } )]
    [String] $exportResourceGroupName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.exportStorAccountName" } )]
    [String] $exportStorAccountName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.exportStorAccountLocation" } )]
    [String] $exportStorAccountLocation,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.exportStorAccountSKU" } )]
    [String] $exportStorAccountSKU,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.exportStorContainerGroupMembershipExports" } )]
    [String] $exportStorContainerGroupMembershipExports,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.exportGroupMemberships" -DisplayName "Create a backup of the user's group memberships" } )]
    [bool] $exportGroupMemberships = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.licensesMode" } )]
    [int] $ChangeLicensesSelector = 0,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.groupsMode" } )]
    [int] $ChangeGroupsSelector = 0,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.groupToAdd" -DisplayName "Group to add or keep" } )]
    [string] $GroupToAdd,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.groupsToRemovePrefix" -DisplayName "Remove groups starting with this prefix" } )]
    [String] $GroupsToRemovePrefix,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.revokeGroupOwnership" -DisplayName "Remove/Replace this user's group ownerships" } )]
    [bool] $RevokeGroupOwnership = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserTemporarily.ReplacementOwnerName" -DisplayName "Who should step in as group owner?" } )]
    [String] $ReplacementOwnerName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Sanity checks
if ($exportGroupMemberships -and ((-not $exportResourceGroupName) -or (-not $exportStorAccountName) -or (-not $exportStorAccountLocation) -or (-not $exportStorAccountSKU))) {
    "## To export group memberships, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    ""
    "## Configure the following attributes:"
    "## - OffboardUserTemporarily.exportResourceGroupName"
    "## - OffboardUserTemporarily.exportStorAccountName"
    "## - OffboardUserTemporarily.exportStorAccountLocation"
    "## - OffboardUserTemporarily.exportStorAccountSKU"
    ""
    "## Disabling Group Membership Backup/Export."
    $exportGroupMemberships = $false
    ""
}

Connect-RjRbGraph
Connect-RjRbExchangeOnline

"## Trying to temporarily offboard user '$UserName'"

"## Finding the user object $UserName"
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName"

if (-not $targetUser) {
    throw ("User " + $UserName + " not found.")
}

if ($DisableUser) {
    "## Blocking user sign in for $UserName"
    $body = @{ accountEnabled = $false }
    Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)" -Method Patch -Body $body | Out-Null
}

if ($RevokeAccess) {
    "## Revoke all refresh tokens"
    $body = @{ }
    Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/revokeSignInSessions" -Method Post -Body $body | Out-Null
}

Write-RjRbLog "Getting list of group and role memberships for user '$UserName'."
# Write to file, as Set-AzStorageBlobContent needs a file to upload.
$membershipIds = Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/getMemberGroups" -Method Post -Body @{ securityEnabledOnly = $false } -FollowPaging
$memberships = $membershipIds | ForEach-Object {
    Invoke-RjRbRestMethodGraph -Resource "/groups/$_"
}
$memberships | Select-Object -Property "displayName", "id" | ConvertTo-Json > memberships.txt

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

# Remove user from group owners UNLESS the group would have no remaining (or replacing) owner
if ($RevokeGroupOwnership) {
    $OwnedGroups = Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)/ownedObjects/microsoft.graph.group/" -FollowPaging
    if ($OwnedGroups) {
        foreach ($OwnedGroup in $OwnedGroups) {
            $owners = Invoke-RjRbRestMethodGraph -Resource "/groups/$($OwnedGroup.id)/owners" -FollowPaging
            if (([array]$owners).Count -eq 1) {
                "## '$UserName' is the last remaining owner of group '$($OwnedGroup.displayName)'"
                $ReplacementOwner = $null
                if ($ReplacementOwnerName) {
                    $ReplacementOwner = Invoke-RjRbRestMethodGraph -Resource "/users/$ReplacementOwnerName" -ErrorAction SilentlyContinue
                }
                if ($ReplacementOwner) {
                    $ReplacementBodyString = "https://graph.microsoft.com/v1.0/users/$($ReplacementOwner.id)"
                    $ReplacementBody = @{"@odata.id" = $ReplacementBodyString }
                    Invoke-RjRbRestMethodGraph -Resource "/groups/$($OwnedGroup.id)/owners/`$ref" -Body $ReplacementBody | Out-Null
                    Invoke-RjRbRestMethodGraph -Resource "/groups/$($OwnedGroup.id)/owners/$($targetUser.id)/`$ref" -Method Delete | Out-Null
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
            "## Could not resolve group name '$GroupToAdd', skipping..."
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


Disconnect-ExchangeOnline -Confirm:$false | Out-Null

"## Temporary offboarding of $($UserName) successful."

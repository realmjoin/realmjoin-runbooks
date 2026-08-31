<#
	.SYNOPSIS
	Permanently offboard a user

	.DESCRIPTION
	Permanently offboards a user by revoking access, disabling or deleting the account, adjusting group and license assignments, and optionally exporting memberships. Optionally removes or replaces group ownerships when required and replaces the user as manager of direct reports and as sponsor of (guest) users.

	.PARAMETER UserName
	User principal name of the target user.

	.PARAMETER UserTypeSelector
	Controls which user types this runbook may be run against: all users, member users only or guest users only. The run aborts before any change if the selected user does not match. To enforce the restriction, configure it as a tenant setting and hide the parameter via RunbookCustomization - otherwise operators can change it in the runbook form.

	.PARAMETER DeleteUser
	"Delete user object" (final value: $true) or "Keep the user object" (final value: $false) can be selected as action to perform. If set to true, the user object will be deleted. If set to false, the user object will be kept but access will be revoked and sign-in will be blocked.

	.PARAMETER DisableUser
	If set to true, disables the user account for sign-in.

	.PARAMETER RevokeAccess
	If set to true, revokes the user's refresh tokens and active sessions.

	.PARAMETER exportResourceGroupName
	Azure Resource Group name for exporting data to storage.

	.PARAMETER exportStorAccountName
	Azure Storage Account name for exporting data to storage.

	.PARAMETER exportStorAccountLocation
	Azure region used when creating the Storage Account.

	.PARAMETER exportStorAccountSKU
	SKU name used when creating the Storage Account.

	.PARAMETER exportStorContainerGroupMembershipExports
	Container name used for group membership exports.

	.PARAMETER exportGroupMemberships
	If set to true, exports the user's current group memberships to Azure Storage.

	.PARAMETER ChangeLicensesSelector
	Controls how directly assigned licenses should be handled.

    .Parameter ChangeGroupsSelector
    "Change" and "Remove all" will both honour "groupToAdd"

	.PARAMETER GroupToAdd
	Group that should be added or kept when group changes are enabled.

	.PARAMETER GroupsToRemovePrefix
	Prefix used to remove groups matching a naming convention.

	.PARAMETER RevokeGroupOwnership
	"Remove/Replace this user's group ownerships" (final value: $true) or "User will remain owner / Do not change" (final value: $false) can be selected as action to perform. If set to true, the runbook will attempt to remove the user from group ownerships. If the user is the last owner of a group, it will attempt to assign a replacement owner; if that fails, it will skip ownership change for that group and log it for manual follow-up.

	.PARAMETER ManagerAsReplacementOwner
	If set to true, uses the user's manager as replacement owner where applicable.

	.PARAMETER ReplacementOwnerName
	User who will take over group or resource ownership if required.

	.PARAMETER ReplaceManagerReferences
	If set to true, all direct reports of the offboarded user get the replacement person assigned as their new manager. Without a resolvable replacement, affected users are only listed for manual follow-up.

	.PARAMETER ReplaceSponsorReferences
	If set to true, the offboarded user is replaced by the replacement person wherever they are set as sponsor (typically on guest users). Without a resolvable replacement, affected users are only listed for manual follow-up. Sponsorships that the user only holds through a group membership are left untouched, as they remain valid after the offboarding. As Graph offers no reverse lookup for sponsors, this option scans all users of the tenant.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"UserName": {
				"Hide": true
			},
			"UserTypeSelector": {
				"DisplayName": "Restrict to a user type",
				"Select": {
					"Options": [
						{
							"Display": "Allow all user types (Members and Guests)",
							"Value": 0
						},
						{
							"Display": "Members only",
							"Value": 1
						},
						{
							"Display": "Guests only",
							"Value": 2
						}
					]
				}
			},
			"CallerName": {
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
				"Hide": true
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
							"Value": 0
						},
						{
							"Display": "Change the user's groups.",
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
			"ManagerAsReplacementOwner": {
				"Description": "Fetch the user's manager from AzureAD as replacing owner/manager/sponsor. This takes precedence over manually specifying a replacement owner."
			},
			"ReplaceManagerReferences": {
				"DisplayName": "Handle manager references",
				"Select": {
					"Options": [
						{
							"Display": "Keep this user as manager of their direct reports",
							"Value": false
						},
						{
							"Display": "Set the replacement as manager of the direct reports",
							"Value": true
						}
					]
				}
			},
			"ReplaceSponsorReferences": {
				"DisplayName": "Handle sponsor references",
				"Select": {
					"Options": [
						{
							"Display": "Keep this user as sponsor",
							"Value": false
						},
						{
							"Display": "Replace this user as sponsor of (guest) users",
							"Value": true
						}
					]
				}
			}
		}
	}

    .EXAMPLE
    Full Runbook Customizing Example:
    {
        "Settings": {
            "OffboardUserPermanently": {
                "userTypeRestriction": 0, // 0: Allow all user types, 1: Members only, 2: Guests only
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
                "groupsToRemovePrefix": "",
                "replaceManagerReferences": true,
                "replaceSponsorReferences": true
            }
        },
        "Runbooks": {
            "rjgit-user_general_offboard-user-permanently": {
                "ParameterList": [
                    {
                        "Name": "UserTypeSelector",
                        "Hide": true
                    },
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
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ ModuleName = "Az.Storage"; ModuleVersion = "9.7.2" }
#Requires -Modules @{ ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.userTypeRestriction" } )]
    [int] $UserTypeSelector = 0,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.deleteUser" } )]
    [bool] $DeleteUser = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.disableUser" } )]
    [bool] $DisableUser = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.revokaAccess" } )]
    [bool] $RevokeAccess = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.exportResourceGroupName" } )]
    [String] $exportResourceGroupName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.exportStorAccountName" } )]
    [String] $exportStorAccountName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.exportStorAccountLocation" } )]
    [String] $exportStorAccountLocation,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.exportStorAccountSKU" } )]
    [String] $exportStorAccountSKU,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.exportStorContainerGroupMembershipExports" } )]
    [String] $exportStorContainerGroupMembershipExports,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.exportGroupMemberships" -DisplayName "Create a backup of the user's group memberships" } )]
    [bool] $exportGroupMemberships = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.licensesMode" } )]
    [int] $ChangeLicensesSelector = 0,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.groupsMode" } )]
    [int] $ChangeGroupsSelector = 0,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.groupToAdd" -DisplayName "Group to add or keep" } )]
    [string] $GroupToAdd,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.groupsToRemovePrefix" -DisplayName "Remove groups starting with this prefix" } )]
    [String] $GroupsToRemovePrefix,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.revokeGroupOwnership" -DisplayName "Remove/Replace this user's group ownerships" })]
    [bool] $RevokeGroupOwnership = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Grant ownership of the user's resources to the user's manager?" } )]
    [bool] $ManagerAsReplacementOwner = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Who should step in as group/resource owner?" } )]
    [String] $ReplacementOwnerName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.replaceManagerReferences" -DisplayName "Set the replacement as manager of this user's direct reports" } )]
    [bool] $ReplaceManagerReferences = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OffboardUserPermanently.replaceSponsorReferences" -DisplayName "Replace this user as sponsor of (guest) users" } )]
    [bool] $ReplaceSponsorReferences = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

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

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/applications".

        .EXAMPLE
        PS C:\> $allApps = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/applications"
    #>
    param(
        [string]$Uri
    )

    $allResults = @()
    $nextLink = $Uri

    do {
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        if ($response.value) {
            $allResults += $response.value
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $allResults
}

Write-RjRbLog "Connecting to Microsoft Graph"
try {
    $VerbosePreference = "SilentlyContinue"
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    $VerbosePreference = "Continue"
}
catch {
    throw "Connecting to Microsoft Graph failed."
}
Connect-RjRbExchangeOnline

"## Trying to permanently offboard user '$UserName'"

Write-RjRbLog "Finding the user object '$UserName'"
$targetUser = $null
# Escape the UPN: guest accounts contain "#EXT#", and an unescaped "#" would start a URL fragment.
try { $targetUser = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($UserName))" -ErrorAction Stop }
catch { Write-RjRbLog "Lookup of user '$UserName' failed: $_" }
if (-not $targetUser) {
    throw ("User '$UserName' not found.")
}

if ($UserTypeSelector -ne 0) {
    $allowedUserType = switch ($UserTypeSelector) {
        1 { "Member" }
        2 { "Guest" }
        default { throw ("Invalid value '$UserTypeSelector' for UserTypeSelector. Allowed values: 0 (all user types), 1 (members only), 2 (guests only).") }
    }
    $targetUserType = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)?`$select=id,userType").userType
    # userType is not populated on some (typically older on-prem synced) member accounts
    if (-not $targetUserType) {
        $targetUserType = "Member"
    }
    if ($targetUserType -ne $allowedUserType) {
        "## User '$UserName' is of type '$targetUserType'. This runbook is restricted to $allowedUserType users."
        throw ("User type '$targetUserType' does not match the configured restriction '$allowedUserType'. Aborting.")
    }
}

if ($DisableUser) {
    "## Blocking user sign in for '$UserName'"
    $body = @{ accountEnabled = $false }
    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)" -Body ($body | ConvertTo-Json -Depth 5) -ContentType "application/json" | Out-Null
}

if ($RevokeAccess) {
    "## Revoke all refresh tokens"
    $body = @{ }
    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)/revokeSignInSessions" -Body ($body | ConvertTo-Json -Depth 5) -ContentType "application/json" | Out-Null
}

Write-RjRbLog "Getting list of group memberships for user '$UserName'."
# Write to file, as Set-AzStorageBlobContent needs a file to upload.
$membershipIds = @()
$memberGroupsBody = @{ securityEnabledOnly = $false } | ConvertTo-Json
$memberGroupsUri = "https://graph.microsoft.com/v1.0/users/$($targetUser.id)/getMemberGroups"
do {
    $response = Invoke-MgGraphRequest -Method POST -Uri $memberGroupsUri -Body $memberGroupsBody -ContentType "application/json"
    $membershipIds += $response.value
    $memberGroupsUri = $response.'@odata.nextLink'
} while ($memberGroupsUri)
$memberships = $membershipIds | ForEach-Object {
    Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$_"
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
    $manager = $null
    # Graph answers with 404 when no manager is set - a normal case, not an error.
    try { $manager = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)/manager" -ErrorAction Stop }
    catch { Write-RjRbLog "No manager set for '$UserName'." }
    if ($manager) {
        $ReplacementOwner = $manager
        $ReplacementOwnerName = $manager.userPrincipalName
    }
}
if ((-not $ReplacementOwner) -and $ReplacementOwnerName) {
    $ReplacementOwner = $null
    try { $ReplacementOwner = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($ReplacementOwnerName))" -ErrorAction Stop }
    catch { Write-RjRbLog "Replacement owner '$ReplacementOwnerName' could not be resolved." }
}


# Remove user from group owners UNLESS the group would have no remaining (or replacing) owner
if ($RevokeGroupOwnership) {
    $OwnedGroups = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)/ownedObjects/microsoft.graph.group"
    if ($OwnedGroups) {
        foreach ($OwnedGroup in $OwnedGroups) {
            $owners = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$($OwnedGroup.id)/owners"
            if (([array]$owners).Count -eq 1) {
                "## '$UserName' is the last remaining owner of group '$($OwnedGroup.displayName)'"
                if ($ReplacementOwner) {
                    $ReplacementBodyString = "https://graph.microsoft.com/v1.0/users/$($ReplacementOwner.id)"
                    $ReplacementBody = @{"@odata.id" = $ReplacementBodyString }
                    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$($OwnedGroup.id)/owners/`$ref" -Body ($ReplacementBody | ConvertTo-Json -Depth 5) -ContentType "application/json" | Out-Null
                    Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/groups/$($OwnedGroup.id)/owners/$($targetUser.id)/`$ref" | Out-Null
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
                Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/groups/$($OwnedGroup.id)/owners/$($targetUser.id)/`$ref" | Out-Null
                "## Revoked Ownership of group '$($OwnedGroup.displayName)'"
            }

        }
    }
}

# Set the replacement as manager for the user's direct reports
if ($ReplaceManagerReferences) {
    $directReports = $null
    try {
        $directReports = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)/directReports/microsoft.graph.user?`$select=id,displayName,userPrincipalName"
    }
    catch {
        "## Could not read the direct reports of '$UserName'. Please assign new managers manually!"
    }
    foreach ($report in $directReports) {
        if (-not $ReplacementOwner) {
            "## '$UserName' is the manager of '$($report.userPrincipalName)'"
            "## No replacement available. Please assign a new manager manually!"
            continue
        }
        if ($report.id -eq $ReplacementOwner.id) {
            "## Skipping '$($report.userPrincipalName)' - a user can not be their own manager. Please verify manually!"
            continue
        }
        $ReplacementBody = @{"@odata.id" = "https://graph.microsoft.com/v1.0/users/$($ReplacementOwner.id)" }
        try {
            Invoke-MgGraphRequest -Method PUT -Uri "https://graph.microsoft.com/v1.0/users/$($report.id)/manager/`$ref" -Body ($ReplacementBody | ConvertTo-Json -Depth 5) -ContentType "application/json" | Out-Null
            "## Changed manager of '$($report.userPrincipalName)' to '$($ReplacementOwner.userPrincipalName)'"
        }
        catch {
            "## Changing manager of '$($report.userPrincipalName)' failed. Please verify manually!"
        }
    }
}

# Replace the user wherever they are listed as sponsor (typically on guest users)
if ($ReplaceSponsorReferences) {
    # Graph offers no reverse lookup for sponsors, so all users are scanned with their sponsors expanded.
    # Do not add advanced query options (ConsistencyLevel/$count/$search) here - they are incompatible with $expand.
    $sponsoredUsers = $null
    try {
        $allUsersWithSponsors = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users?`$select=id,displayName,userPrincipalName,userType&`$expand=sponsors(`$select=id)&`$top=999"
        $sponsoredUsers = [array]($allUsersWithSponsors | Where-Object { $_.sponsors.id -contains $targetUser.id })
        # $expand returns at most 20 related objects and offers no paging inside the expansion,
        # so users at that limit are re-checked directly to avoid missing a sponsorship.
        $atExpandLimit = $allUsersWithSponsors | Where-Object { (([array]$_.sponsors).Count -ge 20) -and ($_.sponsors.id -notcontains $targetUser.id) }
        foreach ($candidate in $atExpandLimit) {
            $allSponsors = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users/$($candidate.id)/sponsors?`$select=id"
            if ($allSponsors.id -contains $targetUser.id) {
                $candidate | Add-Member -NotePropertyName "sponsors" -NotePropertyValue $allSponsors -Force
                $sponsoredUsers += $candidate
            }
        }
    }
    catch {
        "## Could not determine which users are sponsored by '$UserName'. Please verify sponsors manually!"
    }
    foreach ($sponsoredUser in $sponsoredUsers) {
        if (-not $ReplacementOwner) {
            "## '$UserName' is a sponsor of '$($sponsoredUser.userPrincipalName)'"
            "## No replacement available. Please verify sponsors manually!"
            continue
        }
        if ($sponsoredUser.id -eq $ReplacementOwner.id) {
            "## Skipping '$($sponsoredUser.userPrincipalName)' - a user can not be their own sponsor. Please verify manually!"
            continue
        }
        try {
            if ($sponsoredUser.sponsors.id -notcontains $ReplacementOwner.id) {
                $ReplacementBody = @{"@odata.id" = "https://graph.microsoft.com/v1.0/users/$($ReplacementOwner.id)" }
                Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($sponsoredUser.id)/sponsors/`$ref" -Body ($ReplacementBody | ConvertTo-Json -Depth 5) -ContentType "application/json" | Out-Null
            }
            # The trailing /$ref is essential - without it Graph would delete the sponsor's user object.
            Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/users/$($sponsoredUser.id)/sponsors/$($targetUser.id)/`$ref" | Out-Null
            "## Changed sponsor of '$($sponsoredUser.userPrincipalName)' to '$($ReplacementOwner.userPrincipalName)'"
        }
        catch {
            "## Changing sponsor of '$($sponsoredUser.userPrincipalName)' failed. Please verify manually!"
        }
    }
}

if ($DeleteUser) {
    if (($ChangeGroupsSelector -ne 0) -or ($ChangeLicensesSelector -ne 0)) {
        "## Skipping license/group modifications as User object will be deleted."
    }

    "## Deleting User Object $UserName"
    Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)" | Out-Null
    "## Offboarding of $($UserName) successful."
    # Script ends here
    exit
}

if ($ChangeGroupsSelector -ne 0) {
    # Add new licensing group, if not already assigned
    if ($GroupToAdd -and ($memberships.DisplayName -notcontains $GroupToAdd)) {
        # Group names can contain spaces and other characters that need encoding in the query string.
        $groupFilter = [uri]::EscapeDataString("displayName eq '$GroupToAdd'")
        $group = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=$groupFilter").value
        if (([array]$group).count -eq 1) {
            "## Adding group '$GroupToAdd' to user $UserName"
            $body = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($targetUser.id)"
            }
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$($group.id)/members/`$ref" -Body ($body | ConvertTo-Json -Depth 5) -ContentType "application/json" | Out-Null
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
            elseif ($_.isAssignableToRoles) {
                # this would require RoleManagement.ReadWrite.Directory permission and "Privileged Role Administrator" Role for RJ
                "## Skipping role group '$($_.displayName)'"
                "## - Role assignable groups can not be managed via RJ - Privileged Role Management permission required"
            }
            elseif ($_.onPremisesSyncEnabled) {
                "## Skipping on-premises group '$($_.displayName)'"
                "## - please remove manually"
            }
            else {
                "## Removing group '$($_.DisplayName)' from $UserName"
                if (($_.GroupTypes -contains "Unified") -or (-not $_.MailEnabled)) {
                    # group is AAD group
                    try {
                        Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/groups/$($_.id)/members/$($targetUser.id)/`$ref" | Out-Null
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
    $assignments = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)?`$select=licenseAssignmentStates"

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
                Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)/assignLicense" -Body ($body | ConvertTo-Json -Depth 5) -ContentType "application/json" | Out-Null
            }
            catch {
                "## ... removing licenses failed. Please check."
            }
        }
    }
}

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

"## Offboarding of $($UserName) successful."
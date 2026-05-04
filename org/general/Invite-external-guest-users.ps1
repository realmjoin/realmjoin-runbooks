<#
	.SYNOPSIS
	Invite external guest users to the organization

	.DESCRIPTION
	This runbook invites an external user as a guest user in Microsoft Entra ID.
	Optional profile properties such as given name, surname, company name, usage location, and manager can be set after the invitation is accepted.
	The invited user can optionally be added to a specified group.

	.NOTES
	Common Use Cases:
	- Basic guest invite: provide only the email address and display name; all profile and group parameters can be left blank
	- Full onboarding: supply all optional fields to set profile properties, assign a manager, and add to a group in a single run

	Parameter Interactions:
	- Profile properties (givenName, surname, companyName, usageLocation) are applied only when non-empty; omitting them skips the PATCH call entirely
	- Manager assignment and group membership each require their respective parameters; both are silently skipped when not provided

	.PARAMETER InvitedUserEmail
	Email address of the guest user to invite.

	.PARAMETER InvitedUserDisplayName
	Display name of the guest user.

	.PARAMETER GroupId
	The object ID of the group to add the guest user to. If not specified, the user will not be added to any group.

	.PARAMETER GivenName
	Given name (first name) of the guest user.

	.PARAMETER Surname
	Surname (last name) of the guest user.

	.PARAMETER CompanyName
	Company name of the guest user.

	.PARAMETER ManagerName
	Manager to assign to the guest user. Select a user from the directory.

	.PARAMETER UsageLocation
	ISO 3166-1 alpha-2 country code for the usage location of the guest user (e.g. "US", "DE").

	.PARAMETER CallerName
	Caller name for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"InvitedUserEmail": {
				"DisplayName": "Invitee email address",
				"Mandatory": true
			},
			"InvitedUserDisplayName": {
				"DisplayName": "Invitee display name",
				"Mandatory": true
			},
			"GroupId": {
				"Hide": true,
				"DefaultValue": ""
			},
			"GivenName": {
				"DisplayName": "Given name (optional)"
			},
			"Surname": {
				"DisplayName": "Surname (optional)"
			},
			"CompanyName": {
				"DisplayName": "Company name (optional)"
			},
			"ManagerName": {
				"DisplayName": "Manager (optional)"
			},
			"UsageLocation": {
				"DisplayName": "Usage location - ISO country code (optional)"
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1" }

param(
    [Parameter(Mandatory = $true)]
    [string]$InvitedUserEmail,

    [Parameter(Mandatory = $false)]
    [string]$InvitedUserDisplayName,

    [Parameter(Mandatory = $false)]
    [string]$GroupId = "",

    [Parameter(Mandatory = $false)]
    [string]$GivenName = "",

    [Parameter(Mandatory = $false)]
    [string]$Surname = "",

    [Parameter(Mandatory = $false)]
    [string]$CompanyName = "",

    [Parameter(Mandatory = $false)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Manager" } )]
    [string]$ManagerName = "",

    [Parameter(Mandatory = $false)]
    [string]$UsageLocation = "",

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "2.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "InvitedUserEmail: $InvitedUserEmail" -Verbose
Write-RjRbLog -Message "InvitedUserDisplayName: $InvitedUserDisplayName" -Verbose
Write-RjRbLog -Message "GroupId: $GroupId" -Verbose
Write-RjRbLog -Message "GivenName: $GivenName" -Verbose
Write-RjRbLog -Message "Surname: $Surname" -Verbose
Write-RjRbLog -Message "CompanyName: $CompanyName" -Verbose
Write-RjRbLog -Message "ManagerName: $ManagerName" -Verbose
Write-RjRbLog -Message "UsageLocation: $UsageLocation" -Verbose

#endregion

########################################################
#region     Parameter Validation
########################################################

if ($InvitedUserEmail -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
    Write-Error "Invalid email format for InvitedUserEmail: '$InvitedUserEmail'" -ErrorAction Continue
    throw "Invalid email format for InvitedUserEmail: '$InvitedUserEmail'"
}

if ([string]::IsNullOrWhiteSpace($InvitedUserDisplayName) -and -not [string]::IsNullOrWhiteSpace($Surname) -and -not [string]::IsNullOrWhiteSpace($GivenName)) {
    $InvitedUserDisplayName = "$Surname, $GivenName"
    Write-RjRbLog -Message "InvitedUserDisplayName derived from Surname/GivenName: '$InvitedUserDisplayName'" -Verbose
}

#endregion

########################################################
#region     Connect Part
########################################################

try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

# Check if a guest user with the same email already exists
$existingUsersResult = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users?`$filter=mail eq '$InvitedUserEmail'&`$select=id,displayName,mail,userType" -ErrorAction Stop
$existingUser = $existingUsersResult.value | Select-Object -First 1

if ($existingUser) {
    Write-RjRbLog -Message "WARNING: A user with email '$InvitedUserEmail' already exists in the tenant."
    Write-Output ""
    Write-Output "Existing user found"
    Write-Output "---------------------"
    Write-Output "  User ID:      $($existingUser.id)"
    Write-Output "  Display Name: $($existingUser.displayName)"
    Write-Output "  Mail:         $($existingUser.mail)"
    Write-Output "  User Type:    $($existingUser.userType)"
    Write-Output ""
    Write-Output "WARNING: A user with this email already exists. The invitation will still proceed."
}
else {
    Write-Output "No existing user found with email '$InvitedUserEmail'. Proceeding with invitation."
}

# If GroupId is provided, verify the group exists
if (-not [string]::IsNullOrEmpty($GroupId)) {
    try {
        $preflightGroup = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId" -ErrorAction Stop
        Write-Output "Target group verified: '$($preflightGroup.displayName)' ($GroupId)"
    }
    catch {
        Write-Error "Group with ID '$GroupId' does not exist or is not accessible: $($_.Exception.Message)" -ErrorAction Continue
        throw "Group '$GroupId' not found. Verify the GroupId is correct."
    }
}

#endregion

########################################################
#region     Main Part
########################################################

# Retrieve tenant ID for invite redirect URL
$orgResult = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization" -ErrorAction Stop
$tenantId = $orgResult.value | Select-Object -First 1 | Select-Object -ExpandProperty id
if (-not $tenantId) {
    Write-Error "Failed to retrieve tenant ID." -ErrorAction Continue
    throw "Failed to retrieve tenant ID."
}
$inviteRedirectUrl = "https://myapplications.microsoft.com/?tenantid=$tenantId"

# Step 1: Send invitation
Write-Output ""
Write-Output "Invite Guest User"
Write-Output "---------------------"
Write-Output "Inviting guest user: $InvitedUserDisplayName ($InvitedUserEmail)"

$invitationBody = @{
    invitedUserEmailAddress = $InvitedUserEmail
    invitedUserDisplayName  = $InvitedUserDisplayName
    inviteRedirectUrl       = $inviteRedirectUrl
    sendInvitationMessage   = $true
}

try {
    $invitationResponse = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/invitations" -Body ($invitationBody | ConvertTo-Json -Depth 5) -ContentType "application/json" -ErrorAction Stop
    $invitedUserId = $invitationResponse.invitedUser.id
    Write-Output "Guest user successfully invited. User ID: $invitedUserId"
    # Allow time for the user object to replicate in Entra ID
    Start-Sleep -Seconds 5
}
catch {
    Write-Error "Error inviting guest user: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

# Step 2: Set optional profile properties via PATCH
$profilePatch = @{}
if (-not [string]::IsNullOrEmpty($GivenName)) {
    $profilePatch["givenName"] = $GivenName
}
if (-not [string]::IsNullOrEmpty($Surname)) {
    $profilePatch["surname"] = $Surname
}
if (-not [string]::IsNullOrEmpty($CompanyName)) {
    $profilePatch["companyName"] = $CompanyName
}
if (-not [string]::IsNullOrEmpty($UsageLocation)) {
    $profilePatch["usageLocation"] = $UsageLocation
}

if ($profilePatch.Count -gt 0) {
    Write-Output ""
    Write-Output "Set Profile Properties"
    Write-Output "---------------------"
    try {
        Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/users/$invitedUserId" -Body ($profilePatch | ConvertTo-Json -Depth 5) -ContentType "application/json" -ErrorAction Stop
        Write-Output "Profile properties updated: $($profilePatch.Keys -join ', ')"
    }
    catch {
        Write-Error "Failed to update profile properties for user '$invitedUserId': $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
}

# Step 3: Assign manager if provided
if (-not [string]::IsNullOrEmpty($ManagerName)) {
    Write-Output ""
    Write-Output "Assign Manager"
    Write-Output "---------------------"
    try {
        $managerBody = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/users/$ManagerName"
        }
        Invoke-MgGraphRequest -Method PUT -Uri "https://graph.microsoft.com/v1.0/users/$invitedUserId/manager/`$ref" -Body ($managerBody | ConvertTo-Json -Depth 5) -ContentType "application/json" -ErrorAction Stop
        Write-Output "Manager '$ManagerName' assigned to guest user."
    }
    catch {
        Write-Error "Failed to assign manager '$ManagerName' to user '$invitedUserId': $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
}

# Step 4: Add user to group if specified
if (-not [string]::IsNullOrEmpty($GroupId)) {
    Write-Output ""
    Write-Output "Add User to Group"
    Write-Output "---------------------"

    try {
        $memberBody = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$invitedUserId"
        }
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId/members/`$ref" -Body ($memberBody | ConvertTo-Json -Depth 5) -ContentType "application/json" -ErrorAction Stop
        Write-Output "User successfully added to group '$($preflightGroup.displayName)'"

        # Step 5: Verify group membership
        Write-Output ""
        Write-Output "Verify Group Membership"
        Write-Output "---------------------"
        Start-Sleep -Seconds 3
        $userGroupsResult = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$invitedUserId/memberOf" -ErrorAction Stop
        $assignedGroup = $userGroupsResult.value | Where-Object { $_.id -eq $GroupId }
        if ($assignedGroup) {
            Write-Output "Group membership successfully verified."
        }
        else {
            Write-Output "Group assignment may take a few minutes to propagate."
        }
    }
    catch {
        Write-Error "Error adding user to group '$GroupId': $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
}
else {
    Write-Output ""
    Write-Output "No group specified for assignment."
}

# Summary
Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "  Email:        $InvitedUserEmail"
Write-Output "  Display Name: $InvitedUserDisplayName"
Write-Output "  User ID:      $invitedUserId"
if (-not [string]::IsNullOrEmpty($GivenName)) { Write-Output "  Given Name:   $GivenName" }
if (-not [string]::IsNullOrEmpty($Surname)) { Write-Output "  Surname:      $Surname" }
if (-not [string]::IsNullOrEmpty($CompanyName)) { Write-Output "  Company:      $CompanyName" }
if (-not [string]::IsNullOrEmpty($UsageLocation)) { Write-Output "  Usage Loc.:   $UsageLocation" }
if (-not [string]::IsNullOrEmpty($ManagerName)) { Write-Output "  Manager:      $ManagerName" }
Write-Output "  Group:        $(if ([string]::IsNullOrEmpty($GroupId)) { 'None' } else { "$($preflightGroup.displayName) ($GroupId)" })"

#endregion

########################################################
#region     Cleanup
########################################################

Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion
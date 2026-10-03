<#
	.SYNOPSIS
	Invite an external person as a guest user

	.DESCRIPTION
	Sends a Microsoft Entra ID guest invitation to an external email address. Optionally the guest is added to a group, and profile details such as name, company, usage location, manager and sponsor are set on the guest account right away. The invitation email and the landing page can be customized.

	.PARAMETER InvitedUserEmail
	Email address of the person to invite.

	.PARAMETER InvitedUserDisplayName
	Name shown for the guest in the directory.

	.PARAMETER GroupId
	Group the guest is added to. Preset in the runbook customization; empty means none.

	.PARAMETER GivenName
	First name of the guest.

	.PARAMETER Surname
	Last name of the guest.

	.PARAMETER CompanyName
	Company the guest works for.

	.PARAMETER ManagerName
	User who becomes the guest's manager.

	.PARAMETER SponsorName
	User recorded as the guest's sponsor.

	.PARAMETER CustomizeInvitation
	Shows fields for an own invitation message and redirect URL.

	.PARAMETER InvitationMessage
	Text included in the invitation email.

	.PARAMETER InviteRedirectUrl
	Page the guest lands on after accepting, for example a SharePoint site.

	.PARAMETER UsageLocation
	Two-letter country code, for example US or DE, needed before licenses can be assigned.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"ParameterList": [
			{
				"Name": "InvitedUserEmail",
				"DisplayName": "Invitee email address",
				"Mandatory": true
			},
			{
				"Name": "InvitedUserDisplayName",
				"DisplayName": "Invitee display name",
				"Mandatory": true
			},
			{
				"Name": "GroupId",
				"Hide": true,
				"DefaultValue": ""
			},
			{
				"Name": "GivenName",
				"DisplayName": "Given name"
			},
			{
				"Name": "Surname",
				"DisplayName": "Surname"
			},
			{
				"Name": "CompanyName",
				"DisplayName": "Company name"
			},
			{
				"Name": "ManagerName",
				"DisplayName": "Manager"
			},
			{
				"Name": "SponsorName",
				"DisplayName": "Sponsor"
			},
			{
				"Name": "CustomizeInvitation",
				"DisplayName": "Customize the invitation?",
				"Select": {
					"Options": [
						{
							"Display": "Yes, customize message and redirect",
							"ParameterValue": true
						},
						{
							"Display": "No, use the defaults",
							"ParameterValue": false,
							"Customization": {
								"Hide": [
									"InvitationMessage",
									"InviteRedirectUrl"
								]
							}
						}
					],
					"ShowValue": false
				},
				"DefaultValue": false
			},
			{
				"Name": "InvitationMessage",
				"DisplayName": "Invitation message"
			},
			{
				"Name": "InviteRedirectUrl",
				"DisplayName": "Redirect URL"
			},
			{
				"Name": "UsageLocation",
				"DisplayName": "Usage location"
			},
			{
				"Name": "CallerName",
				"Hide": true
			}
		]
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

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
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Sponsor" } )]
    [string]$SponsorName = "",

    [Parameter(Mandatory = $false)]
    [bool]$CustomizeInvitation = $false,

    [Parameter(Mandatory = $false)]
    [string]$InvitationMessage = "",

    [Parameter(Mandatory = $false)]
    [string]$InviteRedirectUrl = "",

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

$Version = "2.0.3"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "InvitedUserEmail: $InvitedUserEmail" -Verbose
Write-RjRbLog -Message "InvitedUserDisplayName: $InvitedUserDisplayName" -Verbose
Write-RjRbLog -Message "GroupId: $GroupId" -Verbose
Write-RjRbLog -Message "GivenName: $GivenName" -Verbose
Write-RjRbLog -Message "Surname: $Surname" -Verbose
Write-RjRbLog -Message "CompanyName: $CompanyName" -Verbose
Write-RjRbLog -Message "ManagerName: $ManagerName" -Verbose
Write-RjRbLog -Message "SponsorName: $SponsorName" -Verbose
Write-RjRbLog -Message "CustomizeInvitation: $CustomizeInvitation" -Verbose
Write-RjRbLog -Message "InvitationMessage: $InvitationMessage" -Verbose
Write-RjRbLog -Message "InviteRedirectUrl: $InviteRedirectUrl" -Verbose
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

# Determine invite redirect URL
if ($CustomizeInvitation -and -not [string]::IsNullOrEmpty($InviteRedirectUrl)) {
    $effectiveRedirectUrl = $InviteRedirectUrl
}
else {
    $orgResult = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization" -ErrorAction Stop
    $tenantId = $orgResult.value | Select-Object -First 1 | Select-Object -ExpandProperty id
    if (-not $tenantId) {
        Write-Error "Failed to retrieve tenant ID." -ErrorAction Continue
        throw "Failed to retrieve tenant ID."
    }
    $effectiveRedirectUrl = "https://myapplications.microsoft.com/?tenantid=$tenantId"
}

# Step 1: Send invitation
Write-Output ""
Write-Output "Invite Guest User"
Write-Output "---------------------"
Write-Output "Inviting guest user: $InvitedUserDisplayName ($InvitedUserEmail)"

$invitationBody = @{
    invitedUserEmailAddress = $InvitedUserEmail
    invitedUserDisplayName  = $InvitedUserDisplayName
    inviteRedirectUrl       = $effectiveRedirectUrl
    sendInvitationMessage   = $true
}

if ($CustomizeInvitation -and -not [string]::IsNullOrEmpty($InvitationMessage)) {
    $invitationBody["invitedUserMessageInfo"] = @{
        customizedMessageBody = $InvitationMessage
    }
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

# Step 4: Assign sponsor if provided
if (-not [string]::IsNullOrEmpty($SponsorName)) {
    Write-Output ""
    Write-Output "Assign Sponsor"
    Write-Output "---------------------"
    try {
        $sponsorBody = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/users/$SponsorName"
        }
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$invitedUserId/sponsors/`$ref" -Body ($sponsorBody | ConvertTo-Json -Depth 5) -ContentType "application/json" -ErrorAction Stop
        Write-Output "Sponsor '$SponsorName' assigned to guest user."
    }
    catch {
        Write-Error "Failed to assign sponsor '$SponsorName' to user '$invitedUserId': $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
}

# Step 5: Add user to group if specified
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

        # Step 6: Verify group membership
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

# Resolve UPN for Manager and Sponsor for display purposes
$managerUpn = ""
if (-not [string]::IsNullOrEmpty($ManagerName)) {
    try {
        $managerUser = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$ManagerName" -ErrorAction Stop
        $managerUpn = $managerUser.userPrincipalName
    }
    catch {
        $managerUpn = $ManagerName
    }
}
$sponsorUpn = ""
if (-not [string]::IsNullOrEmpty($SponsorName)) {
    try {
        $sponsorUser = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$SponsorName" -ErrorAction Stop
        $sponsorUpn = $sponsorUser.userPrincipalName
    }
    catch {
        $sponsorUpn = $SponsorName
    }
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
if (-not [string]::IsNullOrEmpty($ManagerName)) { Write-Output "  Manager:      $managerUpn" }
if (-not [string]::IsNullOrEmpty($SponsorName)) { Write-Output "  Sponsor:      $sponsorUpn" }
if ($CustomizeInvitation -and -not [string]::IsNullOrEmpty($InvitationMessage)) { Write-Output "  Message:      $InvitationMessage" }
if ($CustomizeInvitation -and -not [string]::IsNullOrEmpty($InviteRedirectUrl)) { Write-Output "  Redirect URL: $InviteRedirectUrl" }
Write-Output "  Group:        $(if ([string]::IsNullOrEmpty($GroupId)) { 'None' } else { "$($preflightGroup.displayName) ($GroupId)" })"

#endregion

########################################################
#region     Cleanup
########################################################

Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion
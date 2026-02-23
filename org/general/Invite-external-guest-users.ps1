<#
	.SYNOPSIS
	Invite external guest users to the organization

	.DESCRIPTION
	This runbook invites an external user as a guest user in Microsoft Entra ID.
	It can optionally add the invited user to a specified group.

	.PARAMETER InvitedUserEmail
	Email address of the guest user to invite.

	.PARAMETER InvitedUserDisplayName
	Display name of the guest user.

    .PARAMETER GroupId
    The object ID of the group to add the guest user to.
    If not specified, the user will not be added to any group.

	.PARAMETER CallerName
	Caller name for auditing purposes.

    .NOTES
    You need to setup proper RunbookCustomization in the RealmJoin Portal to use this script.
    An example would be looking like this:
    "rjgit-org_general_invite-external-guest-users": {
        "Parameters": {
            "InvitedUserEmail": {
                "DisplayName": "Invitee's email address",
                "Mandatory": true
            },
            "InvitedUserDisplayName": {
                "DisplayName": "Invitee's display name",
                "Mandatory": true
            },
            "CallerName": {
                "Hide": true
            },
            "GroupId": {
                "Hide": true,
                "DefaultValue": "00000000-0000-0000-0000-000000000000"
            }
        }
    }



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
			"CallerName": {
				"Hide": true
			},
			"GroupId": {
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

    [Parameter(Mandatory = $true)]
    [string]$InvitedUserDisplayName,

    [Parameter(Mandatory = $false)]
    [string]$GroupId = "",

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName

)

########################################################
#region     RJ Log Part
##
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "InvitedUserEmail: $InvitedUserEmail" -Verbose
Write-RjRbLog -Message "InvitedUserDisplayName: $InvitedUserDisplayName" -Verbose
Write-RjRbLog -Message "GroupId: $GroupId" -Verbose

#endregion

####################################################################
#region Validate Parameters
####################################################################
# Validate if the InvitedUserEmail is a valid email format
if (-not $InvitedUserEmail -or $InvitedUserEmail -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
    Write-Error "Invalid email format for InvitedUserEmail: '$($InvitedUserEmail)'"
    exit 1
}


####################################################################
#region Connect to Microsoft Graph
####################################################################

try {
    Write-Verbose "Connecting to Microsoft Graph..."
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    Write-Verbose "Successfully connected to Microsoft Graph."
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    throw
}

#endregion

####################################################################
#region Prepare Invitation Parameters
####################################################################

# Build the invitation URL
$tenantId = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization" | Select-Object -ExpandProperty value | Select-Object -First 1 | Select-Object -ExpandProperty id
if (-not $tenantId) {
    Write-Error "Failed to retrieve tenant ID."
    exit 1
}
$InviteRedirectUrl = "https://myapplications.microsoft.com/?tenantid=$($tenantId)"

[bool]$SendInvitationMessage = $true

#endregion

####################################################################
#region Invite Guest User and Add to Group
####################################################################

# Step 1: Invite guest user
Write-Output "Inviting guest user: $($InvitedUserDisplayName) ($($InvitedUserEmail))"

$invitationBody = @{
    invitedUserEmailAddress = $InvitedUserEmail
    invitedUserDisplayName = $InvitedUserDisplayName
    inviteRedirectUrl = $InviteRedirectUrl
    sendInvitationMessage = $SendInvitationMessage
}

try {
    $invitationResponse = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/invitations" -Body ($invitationBody | ConvertTo-Json) -ContentType "application/json"

    $invitedUserId = $invitationResponse.invitedUser.id
    Write-Output "Guest user successfully invited. User ID: $($invitedUserId)"

    # Wait for user to be available in Azure AD
    Start-Sleep -Seconds 5
}
catch {
    Write-Error "Error inviting guest user: $($_.Exception.Message)"
    exit 1
}

# Step 2: Add user to group (if specified)
if ($GroupId) {
    Write-Output "Validating Group ID..."

    try {
        # Check if group exists
        $group = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId" -ErrorAction Stop
        Write-Output "Adding user to group: $($group.displayName) - ID: $($GroupId)"

        # Add user to group
        $memberBody = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($invitedUserId)"
        }

        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId/members/`$ref" -Body ($memberBody | ConvertTo-Json) -ContentType "application/json"

        Write-Output "User successfully added to group '$($group.displayName)'"

        # Step 3: Verify group membership
        Write-Output "Verifying group membership for invited user..."

        Start-Sleep -Seconds 3
        $userGroups = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$($invitedUserId)/memberOf"

        $assignedGroup = $userGroups.value | Where-Object { $_.id -eq $GroupId }
        if ($assignedGroup) {
            Write-Output "Group membership successfully verified."
        } else {
            Write-Output "Group assignment may take a few minutes to appear"
        }
    }
    catch {
        Write-Error "Error adding user to group $($GroupId): $($_.Exception.Message)"
    }
} else {
    Write-Output "No group specified for assignment"
}
#endregion

####################################################################
#region Output Summary
####################################################################
# Output summary
Write-Output ""
Write-Output "=== Summary ==="
Write-Output "Invited User:"
Write-Output "  Email: $InvitedUserEmail"
Write-Output "  Display Name: $InvitedUserDisplayName"
Write-Output "  User ID: $invitedUserId"
Write-Output "Group Assigned: $(if ([string]::IsNullOrEmpty($GroupId)) { 'None' } else { "$($group.displayName) - $GroupId" })"
Write-Output "Invitation Sent: $SendInvitationMessage"

#endregion
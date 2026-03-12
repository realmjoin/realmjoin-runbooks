<#
	.SYNOPSIS
	Create a Viva Engage (Yammer) community

	.DESCRIPTION
	This runbook creates a Viva Engage community via the Yammer REST API using a stored developer token.
	It can optionally assign owners and remove the initial API user from the resulting Microsoft 365 group.

	.PARAMETER CommunityName
	Name of the community to create. Maximum length is 264 characters.

	.PARAMETER CommunityPrivate
	If set to true, the community is created as private.

	.PARAMETER CommunityShowInDirectory
	If set to true, the community is visible in the directory.

	.PARAMETER CommunityOwners
	Comma-separated list of owner UPNs to add to the community.

	.PARAMETER removeCreatorFromGroup
	If set to true, removes the initial API user from the group when at least one other owner exists.

	.PARAMETER CallerName
	Caller name for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"CallerName": {
				"Hide": true
			},
			"removeCreatorFromGroup": {
				"DisplayName": "Remove initial API user/owner from group"
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [string]$CommunityName = "Sample Community",
    [bool]$CommunityPrivate = $false,
    [bool]$CommunityShowInDirectory = $true,
    [string]$CommunityOwners = "",
    [bool]$removeCreatorFromGroup = $true,
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# "Authenticate" to Yammer
#viva engage / yammer dev token - Create one at: https://www.yammer.com/client_applications/
#TODO: Needs to come from configuration of the runbook and needs to be secure as this is confidential information
#Get a dev token from your tenant: https://learn.microsoft.com/en-us/rest/api/yammer/app-registration -> create the dev token and this is the bearer token .·´¯`(>▂<)´¯`·.
try {
    $appSecret = Get-AutomationPSCredential -Name 'yammer-app-secret'
    $authToken = $appSecret.GetNetworkCredential().Password
}
catch {
    "## Could not get credentials from Azure Automation. Please create a credential named 'yammer-app-secret' with the Yammer dev token as the password. Exiting..."
    throw "No credentials"
}

# Authenticate to Azure AD
Connect-RjRbGraph

# Prepare API call to create group
$scriptUserAgent = "RJRB-Posh-VivaEngage/1.0"
$apiBaseUri = "https://www.yammer.com/api/v1/";
$apiCreateGroupUri = $apiBaseUri + "groups.json?name={name}&private={private}&show_in_directory={show_in_directory}";
$apiGroupMembershipUri = $apiBaseUri + "group_memberships.json";
$apiContentType = "application/json; charset=utf-8";

#insert param into URI
$apiGroupRequestUri = $apiCreateGroupUri.Replace("{name}", $CommunityName)
$apiGroupRequestUri = $apiGroupRequestUri.Replace("{private}", $communityPrivate.toString().ToLower())
$apiGroupRequestUri = $apiGroupRequestUri.Replace("{show_in_directory}", $CommunityShowInDirectory.toString().ToLower())

try {
    # Create Yammer Auth Header
    #$apiCreateGroupResponse = Invoke-RestMethod -Method Post -Uri $apiGroupRequestUri -Authentication Bearer -Token $authToken -UserAgent $scriptUserAgent -ContentType $apiContentType
    ## IRM in PS5 does not offer "-Authentication". Will use a header.
    $headers = @{
        Authorization = "Bearer $authToken"
    }

    #create group
    $apiCreateGroupResponse = Invoke-RestMethod -Method Post -Uri $apiGroupRequestUri -Headers $headers -UserAgent $scriptUserAgent -ContentType $apiContentType
    "## Group '$($apiCreateGroupResponse.name)' created."

    #use mail nick name to get group from AAD and then add owner
    $mailnickname = $apiCreateGroupResponse.name;
    $aadGroup = Invoke-RjRbRestMethodGraph -Method Get -Resource "/groups" -OdFilter "mailNickname eq '$mailnickname'"
    [int]$retryCount = 0
    while (($null -eq $aadGroup) -and ($retryCount -lt 10)) {
        "## Group not available in Azure AD yet. Waiting 10 seconds and retrying."
        Start-Sleep -Seconds 10
        $retryCount++
        $aadGroup = Invoke-RjRbRestMethodGraph -Method Get -Resource "/groups" -OdFilter "mailNickname eq '$mailnickname'"
    }
    if ($null -eq $aadGroup) {
        "## Could not find group in Azure AD. Exiting..."
        throw "AzureAD Group creation failed"
    }
    "## Group '$($aadGroup.DisplayName)' found in Azure AD."
}
catch {
    "## Could not create group - Exiting..."
    $_
    throw "Group creation failed"
}

if ($CommunityOwners) {
    try {
        $currentOwners = Invoke-RjRbRestMethodGraph -Resource "/groups/$($aadGroup.id)/owners" -ErrorAction SilentlyContinue
        # Parse owners
        $paramCommunityOwnersArray = @()
        $CommunityOwners.Split(',') | ForEach-Object {
            $targetUser = Invoke-RjRbRestMethodGraph -Resource "/users/$_" -ErrorAction SilentlyContinue
            if ($targetUser) {
                if ($removeCreatorFromGroup -and ($currentOwners.userPrincipalName -contains $targetUser.userPrincipalName)) {
                    "## Community Creator '$($targetUser.userPrincipalName)' appointed as owner. Will not remove API user..."
                    $removeCreatorFromGroup = $false
                }
                elseif ($paramCommunityOwnersArray.userPrincipalName -notcontains $targetUser.userPrincipalName) {
                    $paramCommunityOwnersArray += $targetUser
                }
            }
        }
        $paramCommunityOwnersArray | ForEach-Object {
            $targetUser = $_
            $body = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($targetUser.id)"
            }

            Invoke-RjRbRestMethodGraph -Resource "/groups/$($aadGroup.id)/owners/`$ref" -Method Post -Body $body | Out-Null
            "## '$($targetUser.userPrincipalName)' is added to '$($aadGroup.DisplayName)' owners."

            # Owners also have to be members
            Invoke-RjRbRestMethodGraph -Resource "/groups/$($aadGroup.id)/members/`$ref" -Method Post -Body $body | Out-Null
            "## '$($targetUser.userPrincipalName)' is added to '$($aadGroup.DisplayName)' members."
        }
    }
    catch {
        "## Could not add owners to group. Exiting..."
        $_
        throw "Group owner assignment failed"
    }

    if ($removeCreatorFromGroup) {
        #remove api user from group. Will only work if there is at least one other owner!
        $retryCount = 0
        $requestFailed = $true
        while ($requestFailed -and ($retryCount -lt 10)) {
            $requestFailed = $false
            try {
                $result = Invoke-RestMethod -Method delete -Headers $headers -Uri ($apiGroupMembershipUri + '?group_id=' + $apiCreateGroupResponse.id + '&user_id=' + $apiCreateGroupResponse.creator_id) -UserAgent $scriptUserAgent
                $result = $null
            }
            catch {
                "## Could not remove API user from group. Waiting 10 seconds and retrying."
                $requestFailed = $true
                $retryCount++
                Start-Sleep -Seconds 10
            }
        }
        if ($requestFailed) {
            "## Could not remove API user from group. Exiting..."
            $_
            throw "Could not remove API user from group"
        }
        else {
            "## Removed API user from group."
        }
    }
}
else {
    "## No owners specified. Skipping owner assignment/removal."
}

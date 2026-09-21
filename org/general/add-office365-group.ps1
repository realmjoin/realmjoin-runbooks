<#
	.SYNOPSIS
	Create a Microsoft 365 group, optionally with a team

	.DESCRIPTION
	Creates a Microsoft 365 group with its SharePoint site and, on request, turns it into a Microsoft Teams team. Visibility, mail and security settings and up to two owners can be set. A team without an owner gets the caller as owner.

	.PARAMETER MailNickname
	Alias of the group, used for its email address and SharePoint URL.

	.PARAMETER DisplayName
	Name shown for the group. Leave empty to use the mail nickname.

	.PARAMETER CreateTeam
	Creates only the group with its SharePoint site, or also a Microsoft Teams team on top of it.

	.PARAMETER Private
	Public groups can be found and joined by anyone in the organization, private groups only by their members.

	.PARAMETER MailEnabled
	Gives the group a mailbox and email address.

	.PARAMETER SecurityEnabled
	Lets the group be used for permissions and access assignments.

	.PARAMETER Owner
	Owner of the group. Leave empty for none; a team then gets the caller as owner.

	.PARAMETER Owner2
	Additional owner. Leave empty for none.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"MailNickname": {
				"DisplayName": "Mail nickname"
			},
			"MailEnabled": {
				"DisplayName": "Mail-enabled?"
			},
			"SecurityEnabled": {
				"DisplayName": "Security-enabled?"
			},
			"CreateTeam": {
				"DisplayName": "Create a Teams team?",
				"SelectSimple": {
					"Only the group with its SharePoint site": false,
					"Also a Microsoft Teams team": true
				}
			},
			"Private": {
				"DisplayName": "Visibility",
				"SelectSimple": {
					"Public": false,
					"Private": true
				}
			},
			"CallerName": {
				"Hide": true
			},
			"DisplayName": {
				"DisplayName": "Display name"
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [string] $MailNickname,
    [string] $DisplayName,
    [bool] $CreateTeam = $false,
    #[ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Group is private" } )]
    [bool] $Private = $false,
    #[ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Group is mail-enabled" } )]
    [bool] $MailEnabled = $false,
    #[ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Group is security-enabled" } )]
    [bool] $SecurityEnabled = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Owner" -Filter "userType eq 'Member'" } )]
    [string] $Owner,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Second owner" -Filter "userType eq 'Member'" } )]
    [string] $Owner2,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

# How long to wait in seconds for a group to propagate to the Teams service
[int]$teamsTimer = 75

# Input Validations - from user feedback.
if ($MailNickname.GetEnumerator() -contains " ") {
    throw "MailNickname may not contain Whitespaces."
}

Connect-RjRbGraph

# Check if group exists already
$group = Invoke-RjRbRestMethodGraph -resource "/groups" -OdFilter "mailNickname eq '$MailNickname'" -erroraction SilentlyContinue
if ($group) {
    throw "Group $MailNickname already exists."
}

if (-not $DisplayName) {
    $DisplayName = $MailNickname
}

$groupDescription = @{
    mailNickname    = $mailNickName
    displayName     = $displayName
    securityEnabled = $securityEnabled
    mailEnabled     = $mailEnabled
    groupTypes      = @(
        "Unified"
    )
}

if ($Private) {
    $groupDescription["visibility"] = "Private"
}
else {
    $groupDescription["visibility"] = "Public"
}

if ($CreateTeam) {
    $groupDescription["resourceProvisioningOptions"] = [array]("Team")

    # A team needs an owner
    if (-not $Owner) {
        $Owner = $CallerName
    }
}

if ($Owner) {
    $OwnerObj = Invoke-RjRbRestMethodGraph -Resource "/users/$Owner"
    if ($OwnerObj) {
        $groupDescription["owners@odata.bind"] += [array]("https://graph.microsoft.com/v1.0/users/$($OwnerObj.id)")
        $groupDescription["members@odata.bind"] += [array]("https://graph.microsoft.com/v1.0/users/$($OwnerObj.id)")
    }
    else {
        "## User '$Owner' not found. Skipping setting this owner."
    }
}
if ($Owner2 -and ($Owner -ne $Owner2)) {
    $Owner2Obj = Invoke-RjRbRestMethodGraph -Resource "/users/$Owner2"
    if ($Owner2Obj) {
        $groupDescription["owners@odata.bind"] += [array]("https://graph.microsoft.com/v1.0/users/$($Owner2Obj.id)")
        $groupDescription["members@odata.bind"] += [array]("https://graph.microsoft.com/v1.0/users/$($Owner2Obj.id)")
    }
    else {
        "## User '$Owner2' not found. Skipping setting this owner."
    }
}


"## Creating group '$MailNickname'"
$groupObj = Invoke-RjRbRestMethodGraph -Method POST -resource "/groups" -body $groupDescription

if ($CreateTeam) {
    $teamDescription = @{
        "template@odata.bind" = "https://graph.microsoft.com/v1.0/teamsTemplates('standard')"
        "group@odata.bind"    = "https://graph.microsoft.com/v1.0/groups('$($groupObj.id)')"
    }

    [int]$tries = 0
    [bool]$success = $false
    while (-not $success -and $tries -le 8) {
        $success = $true
        $tries++

        "## Waiting/Sleeping to allow data propagation..."
        # a new group needs some time to propagate...
        Start-Sleep -Seconds $teamsTimer

        try {
            "## Triggering Team creation"
            Invoke-RjRbRestMethodGraph -Method POST -Resource "/teams" -Body $teamDescription | Out-Null
        }
        catch {
            "## ... too early. Try again."
            $success = $false
        }
    }
    if (-not $success) {
        "## Timeout on Team creation. The group has been created, but could not be promoted to a Team."
        ""
        throw ("timeout")
    }
}

""
"## Group '$MailNickname' successfully created."

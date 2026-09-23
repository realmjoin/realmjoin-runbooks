<#
	.SYNOPSIS
	Add this user to a predefined set of groups

	.DESCRIPTION
	Adds this user to one or more Entra ID groups. The groups come from a template that an administrator defines in the runbook customization, so the person running it picks a template instead of individual groups.

	.PARAMETER UserId
	Object ID of the user the runbook acts on. Set by the portal from the selected user.

	.PARAMETER GroupsTemplate
	Template that decides which groups the user joins. The available templates are set up in the runbook customization.

	.PARAMETER GroupsString
	Groups to add the user to, separated by commas. Usually filled in by the selected template.

	.PARAMETER UseDisplaynames
	Whether the group list contains display names instead of object IDs. Preset in the runbook customization.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"UserId": {
				"Hide": true
			},
			"GroupsTemplate": {
				"DisplayName": "Group template"
			},
			"GroupsString": {
				"DisplayName": "Groups"
			},
			"CallerName": {
				"Hide": true
			},
			"UseDisplaynames": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

# Suppress false positive from PSScriptAnalyzer - GroupsTemplate is used to populate GroupsString via RJ Portal Customization
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "GroupsTemplate")]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserId,
    # GroupsTemplate is not used directly, but is used to populate the GroupsString parameter via RJ Portal Customization
    [string] $GroupsTemplate,
    [Parameter(Mandatory = $true)]
    [string] $GroupsString,
    # $UseDisplayname = $false: GroupsString contains Group object ids, $true: GroupsString contains Group displayNames
    [bool] $UseDisplaynames = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

if (-not $GroupsString) {
    "## Please prepare Groups Templates before using this runbook."
    "## See this runbooks source for an example."
    throw("No GroupsString provided")
}

$GroupNames = $GroupsString.Split(',')

$AADGroups = @()
if ($UseDisplaynames) {
    foreach ($GroupName in $GroupNames) {
        $targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$GroupName'"
        if (-not $targetGroup) {
            "## Group with name '$GroupName' not found in Azure AD."
            throw("Group not found");
        }
        if ($targetGroup.count -gt 1) {
            "## Multiple groups with name '$GroupName' found in Azure AD."
            "## Recommendation: Use Group object ids instead of displayNames."
            throw("Group not unique")
        }
        if ($AADGroups.id -notcontains $targetGroup.Id) {
            $AADGroups += $targetGroup
        }
    }
}
else {
    foreach ($GroupId in $GroupNames) {
        $targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId" -ErrorAction SilentlyContinue
        if (-not $targetGroup) {
            "## Group with ID '$GroupId' not found in Azure AD."
            throw("Group not found");
        }
        if ($AADGroups.id -notcontains $targetGroup.Id) {
            $AADGroups += $targetGroup
        }
    }
}

foreach ($AADGroup in $AADGroups) {
    $AADGroupMembers = @()
    $AADGroupMembers += (Invoke-RjRbRestMethodGraph -Resource "/groups/$($AADGroup.Id)/members" -OdSelect "Id" -FollowPaging).id
    [array] $bindings = @()
    if ((-not $AADGroupMembers) -or (($AADGroupMembers.count -eq 1) -and ($AADGroupMembers -ne $UserId)) -or (($AADGroupMembers.count -gt 1) -and ($AADgroupMembers -notcontains $UserId))) {
        $bindingString = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
        $bindings += $bindingString
    }
    else {
        "## User is already member of '$($AADGroup.displayName)'. Skipping."
    }

    if ($bindings) {
        $GroupJson = @{"members@odata.bind" = $bindings }
        Invoke-RjRbRestMethodGraph -Resource "/groups/$($AADGroup.Id)" -Method Patch -Body $GroupJson | Out-Null
        "## Added user to group '$($AADGroup.displayName)'"
    }
}
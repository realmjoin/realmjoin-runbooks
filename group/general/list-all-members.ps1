<#
	.SYNOPSIS
	List all members of this group, nested groups included

	.DESCRIPTION
	Lists every member of this Entra ID group, both direct members and those who belong through nested groups. The result is a CSV-formatted list with the user principal name, whether the membership is direct, and the group path. A path like "Primary, Secondary" means the user is in Primary through the nested group Secondary.

	.PARAMETER GroupId
	Object ID of the group the runbook acts on. Set by the portal from the selected group.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"GroupId": {
				"Hide": true
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param(
    [Parameter(Mandatory=$true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Group" } )]
    [string]$GroupId,

    # CallerName is tracked purely for auditing purposes
    [string] $CallerName
)

########################################################
#region     function declaration
##
########################################################
function Get-GroupMembership {
    param (
        [string]$GroupObjectId,
        [string]$ParentGroupPath = ""
    )

    $report = @()

    # Get the group object
    $group = Invoke-MGGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$GroupObjectId"
    $CurrentGroupPath = if ($ParentGroupPath) { "$ParentGroupPath;$($group.DisplayName)" } else { $group.DisplayName }

    # Get the members of the group
    $members = @()
    $uri = "https://graph.microsoft.com/v1.0/groups/$GroupObjectId/members"
    do {
        $response = Invoke-MGGraphRequest -Method GET -Uri $uri
        $members += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)

    # Process the members - if a member is a user, add it to the report, if it's a group, call the function recursively
    foreach ($member in $members) {
        if ($member."@odata.type" -eq "#microsoft.graph.user") {
            $DirectMemberStatus = if ($ParentGroupPath) { "No" } else { "Yes" }
            $report += [PSCustomObject]@{
                UPN          = $member.UserPrincipalName
                DirectMember = $DirectMemberStatus
                GroupPath    = $CurrentGroupPath
            }
        }
        elseif ($member."@odata.type" -eq "#microsoft.graph.group") {
            $report += Get-GroupMembership -GroupObjectId $($member.id) -ParentGroupPath $CurrentGroupPath
        }
    }

    return $report
}

#endregion

########################################################
#region     RJ Log Part
##
########################################################

# Add Caller in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

# Add Version in Verbose output
$Version = "1.0.3"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "GroupObjectId: $GroupId" -Verbose
Write-RjRbLog -Message "CallerName: $CallerName" -Verbose

#endregion

########################################################
#region     Connect Part
##
########################################################

# Initiate Graph Session
Write-Output "Initiate MGGraph Session..."
try {
    $VerbosePreference = "SilentlyContinue"
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    $VerbosePreference = "Continue"
}
catch {
    Write-Error "MGGraph Connect failed - stopping script"
    Exit
}

#endregion

########################################################
#region     Main Part
##
########################################################

Write-Output "Getting group membership (also indirect memberships based on nested groups) for group with ObjectId:"
Write-Output "'$GroupId'..."
$report = Get-GroupMembership -GroupObjectId $GroupId

# Output the report
Write-Output ""
Write-Output "Result:"
Write-Output "UPN,DirectMember,GroupPath"
$report | ForEach-Object {
    Write-Output "$($_.UPN),$($_.DirectMember),$($_.GroupPath)"
}
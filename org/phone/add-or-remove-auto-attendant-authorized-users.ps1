<#
	.SYNOPSIS
	Add or remove authorized users of a Teams auto attendant

	.DESCRIPTION
	Adds the selected users to the authorized users of an auto attendant or removes them. Authorized users can change the auto attendant settings in the Teams app; Microsoft allows 15 of them per auto attendant. The Teams voice applications policy they need for that can be assigned or removed in the same run. Details on the checks and options are in the runbook documentation (docs.realmjoin.com).

	.PARAMETER AutoAttendantName
	Exact name of the auto attendant as it is shown in the Teams admin center. Upper and lower case do not matter.

	.PARAMETER UserIds
	Users that are added to or removed from the list of authorized users. Several users can be picked at once; each one needs to be enabled for Teams Phone.

	.PARAMETER Remove
	Add users as authorized users puts them on the authorized user list of the auto attendant. Remove users as authorized users takes them off it again.

	.PARAMETER VoiceApplicationsPolicyAction
	Leave the policy unchanged touches no policy. Assign a voice applications policy grants the policy entered under "Policy name". Remove the voice applications policy resets a per-user assignment when the users are taken off the list.

	.PARAMETER VoiceApplicationsPolicyName
	Voice applications policy to grant, named exactly as in the Teams admin center. Only used with "Assign a voice applications policy".

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"AutoAttendantName": {
				"DisplayName": "Auto attendant name"
			},
			"Remove": {
				"DisplayName": "Action",
				"SelectSimple": {
					"Add users as authorized users": false,
					"Remove users as authorized users": true
				}
			},
			"VoiceApplicationsPolicyAction": {
				"DisplayName": "Voice applications policy",
				"Select": {
					"Options": [
						{
							"Display": "Leave the policy unchanged",
							"ParameterValue": "None",
							"Customization": {
								"Hide": [
									"VoiceApplicationsPolicyName"
								]
							}
						},
						{
							"Display": "Assign a voice applications policy",
							"ParameterValue": "Assign",
							"Customization": {
								"Show": [
									"VoiceApplicationsPolicyName"
								],
								"Mandatory": [
									"VoiceApplicationsPolicyName"
								]
							}
						},
						{
							"Display": "Remove the voice applications policy",
							"ParameterValue": "Remove",
							"Customization": {
								"Hide": [
									"VoiceApplicationsPolicyName"
								]
							}
						}
					],
					"ShowValue": false
				}
			},
			"VoiceApplicationsPolicyName": {
				"DisplayName": "Policy name"
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "7.9.0" }

# Suppress false positive from PSScriptAnalyzer - $tmp is used to suppress unwanted output from Connect-MicrosoftTeams
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "tmp")]
param(
    [Parameter(Mandatory = $true)]
    [string]$AutoAttendantName,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Users" -Filter "userType eq 'Member'" } )]
    [string[]]$UserIds,
    [bool]$Remove = $false,
    [ValidateSet("None", "Assign", "Remove")]
    [string]$VoiceApplicationsPolicyAction = "None",
    [string]$VoiceApplicationsPolicyName = "",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "AutoAttendantName: $AutoAttendantName" -Verbose
Write-RjRbLog -Message "UserIds: $($UserIds -join ', ')" -Verbose
Write-RjRbLog -Message "Remove: $Remove" -Verbose
Write-RjRbLog -Message "VoiceApplicationsPolicyAction: $VoiceApplicationsPolicyAction" -Verbose
Write-RjRbLog -Message "VoiceApplicationsPolicyName: $VoiceApplicationsPolicyName" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

$attendantName = ""
if ($null -ne $AutoAttendantName) {
    $attendantName = $AutoAttendantName.Trim()
}
if ([string]::IsNullOrWhiteSpace($attendantName)) {
    Write-Error -Message "No auto attendant name was submitted. Enter the name of the auto attendant exactly as it is shown in the Teams admin center." -ErrorAction Continue
    throw "No auto attendant name was submitted."
}

# The portal delivers Entra ID object IDs, but a user principal name is accepted as well
$requestedUserIds = @()
foreach ($rawUserId in $UserIds) {
    if ($null -eq $rawUserId) {
        continue
    }
    $trimmedUserId = ([string]$rawUserId).Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedUserId)) {
        continue
    }
    if ($requestedUserIds -notcontains $trimmedUserId) {
        $requestedUserIds += $trimmedUserId
    }
}

if ($requestedUserIds.Count -eq 0) {
    Write-Error -Message "No user was submitted. Select at least one user." -ErrorAction Continue
    throw "No user was submitted."
}

$policyName = ""
if ($null -ne $VoiceApplicationsPolicyName) {
    $policyName = $VoiceApplicationsPolicyName.Trim()
}

if ($VoiceApplicationsPolicyAction -eq "Assign" -and [string]::IsNullOrWhiteSpace($policyName)) {
    Write-Error -Message "No policy name was submitted. Enter the name of the voice applications policy under 'Policy name'." -ErrorAction Continue
    throw "No policy name was submitted."
}

if ((-not $Remove) -and $VoiceApplicationsPolicyAction -eq "Remove") {
    Write-Error -Message "Removing the policy only makes sense when removing authorized users. Choose 'Remove users as authorized users' or another option under 'Voice applications policy'." -ErrorAction Continue
    throw "Removing the policy only makes sense when removing authorized users."
}

if ($Remove -and $VoiceApplicationsPolicyAction -eq "Assign") {
    Write-Error -Message "Assigning a policy only makes sense when adding authorized users. Choose 'Add users as authorized users' or another option under 'Voice applications policy'." -ErrorAction Continue
    throw "Assigning a policy only makes sense when adding authorized users."
}

if ($VoiceApplicationsPolicyAction -ne "Assign" -and -not [string]::IsNullOrWhiteSpace($policyName)) {
    Write-Output "WARNING: The policy name '$policyName' is ignored because 'Voice applications policy' is not set to 'Assign a voice applications policy'."
}

#endregion Parameter Validation

########################################################
#region     Function Definitions
########################################################

function Get-AutoAttendantIdentity {
    # Depending on the module version and on -ExcludeContent, the ID is returned as Identity or as Id
    param(
        $AutoAttendant
    )
    if ($null -eq $AutoAttendant) {
        return ""
    }
    $identity = [string]$AutoAttendant.Identity
    if ([string]::IsNullOrWhiteSpace($identity)) {
        $identity = [string]$AutoAttendant.Id
    }
    return $identity
}

function Get-AutoAttendantByName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    $previousWarningPreference = $WarningPreference
    $WarningPreference = "SilentlyContinue"
    try {
        # NameFilter is a server-side match, paged with at most 100 items per page; names and IDs are enough here
        $candidates = [System.Collections.Generic.List[object]]::new()
        $skip = 0
        do {
            $page = @(Get-CsAutoAttendant -NameFilter $Name -ExcludeContent -First 100 -Skip $skip -ErrorAction Stop)
            if ($page.Count -gt 0) { $candidates.AddRange([object[]]$page) }
            $skip += 100
        } while ($page.Count -eq 100)

        $exact = @($candidates | Where-Object { $_.Name -eq $Name })

        if ($exact.Count -eq 0) {
            # Fallback: scan all names, in case the server-side filter is case-sensitive
            $all = [System.Collections.Generic.List[object]]::new()
            $skip = 0
            do {
                $page = @(Get-CsAutoAttendant -ExcludeContent -First 100 -Skip $skip -ErrorAction Stop)
                if ($page.Count -gt 0) { $all.AddRange([object[]]$page) }
                $skip += 100
            } while ($page.Count -eq 100)
            $exact = @($all | Where-Object { $_.Name -eq $Name })
        }

        if ($exact.Count -eq 0) {
            $similar = @($candidates | Select-Object -ExpandProperty Name -Unique)
            $hint = if ($similar.Count -gt 0) { " Similar names: " + (($similar | ForEach-Object { "'$_'" }) -join ", ") + "." } else { "" }
            Write-Error -Message "No auto attendant named '$Name' was found. Check the name in the Teams admin center.$hint" -ErrorAction Continue
            throw "No auto attendant named '$Name' was found."
        }
        if ($exact.Count -gt 1) {
            $list = ($exact | ForEach-Object { "'$($_.Name)' ($(Get-AutoAttendantIdentity -AutoAttendant $_))" }) -join ", "
            Write-Error -Message "More than one auto attendant is named '$Name': $list. Give the auto attendants unique names and run the runbook again." -ErrorAction Continue
            throw "More than one auto attendant is named '$Name'."
        }

        # -ExcludeContent returns names and IDs only, so the full configuration is read by its ID
        return Get-CsAutoAttendant -Identity (Get-AutoAttendantIdentity -AutoAttendant $exact[0]) -ErrorAction Stop
    }
    finally {
        $WarningPreference = $previousWarningPreference
    }
}

function Get-AuthorizedElsewhere {
    # Maps a lowercase user object ID to the other auto attendants and call queues the user is authorized on
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExcludeAutoAttendantIdentity
    )
    $map = @{}
    $previousWarningPreference = $WarningPreference
    $WarningPreference = "SilentlyContinue"
    try {
        $skip = 0
        do {
            $page = @(Get-CsAutoAttendant -First 100 -Skip $skip -ErrorAction Stop)
            foreach ($otherAutoAttendant in $page) {
                if ((Get-AutoAttendantIdentity -AutoAttendant $otherAutoAttendant) -eq $ExcludeAutoAttendantIdentity) {
                    continue
                }
                foreach ($authorizedUser in @($otherAutoAttendant.AuthorizedUsers)) {
                    if ($null -eq $authorizedUser) { continue }
                    $key = ([string]$authorizedUser).ToLowerInvariant()
                    if (-not $map.ContainsKey($key)) { $map[$key] = [System.Collections.Generic.List[string]]::new() }
                    $map[$key].Add("auto attendant '$($otherAutoAttendant.Name)'")
                }
            }
            $skip += 100
        } while ($page.Count -eq 100)

        $skip = 0
        do {
            $page = @(Get-CsCallQueue -First 100 -Skip $skip -ErrorAction Stop)
            foreach ($queue in $page) {
                foreach ($authorizedUser in @($queue.AuthorizedUsers)) {
                    if ($null -eq $authorizedUser) { continue }
                    $key = ([string]$authorizedUser).ToLowerInvariant()
                    if (-not $map.ContainsKey($key)) { $map[$key] = [System.Collections.Generic.List[string]]::new() }
                    $map[$key].Add("call queue '$($queue.Name)'")
                }
            }
            $skip += 100
        } while ($page.Count -eq 100)
    }
    finally {
        $WarningPreference = $previousWarningPreference
    }
    return $map
}

function Get-UserVoiceApplicationsPolicyName {
    # TeamsVoiceApplicationsPolicy is an object on some module versions and a plain string on others
    param(
        $TeamsUser
    )
    if ($null -eq $TeamsUser) {
        return "Global"
    }
    $policyValue = $TeamsUser.TeamsVoiceApplicationsPolicy
    if ($null -eq $policyValue) {
        return "Global"
    }
    $name = if ($policyValue -is [string]) { $policyValue } else { [string]$policyValue.Name }
    if ([string]::IsNullOrWhiteSpace($name)) {
        return "Global"
    }
    return $name
}

function Get-TeamsUserFromCache {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Cache,
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )
    $key = $Identity.ToLowerInvariant()
    if ($Cache.ContainsKey($key)) {
        return $Cache[$key]
    }
    $teamsUser = $null
    try {
        $teamsUser = Get-CsOnlineUser -Identity $Identity -ErrorAction Stop
    }
    catch {
        Write-RjRbLog -Message "Get-CsOnlineUser failed for '$Identity': $($_.Exception.Message)" -Verbose
    }
    $Cache[$key] = $teamsUser
    return $teamsUser
}

function Get-UserLabel {
    param(
        [string]$Identity,
        $TeamsUser
    )
    $displayName = ""
    $upn = ""
    if ($null -ne $TeamsUser) {
        $displayName = [string]$TeamsUser.DisplayName
        $upn = [string]$TeamsUser.UserPrincipalName
    }
    if (-not [string]::IsNullOrWhiteSpace($displayName) -and -not [string]::IsNullOrWhiteSpace($upn)) {
        return "$displayName ($upn)"
    }
    if (-not [string]::IsNullOrWhiteSpace($upn)) {
        return $upn
    }
    if (-not [string]::IsNullOrWhiteSpace($displayName)) {
        return "$displayName ($Identity)"
    }
    return "Unknown user ($Identity)"
}

function Get-UserDisplayName {
    param(
        [string]$Identity,
        $TeamsUser
    )
    if ($null -ne $TeamsUser -and -not [string]::IsNullOrWhiteSpace([string]$TeamsUser.DisplayName)) {
        return [string]$TeamsUser.DisplayName
    }
    return "Unknown user ($Identity)"
}

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

Write-Output "Connect to Microsoft Teams..."

try {
    $VerbosePreference = "SilentlyContinue"
    $tmp = Connect-MicrosoftTeams -Identity -ErrorAction Stop
    $VerbosePreference = "Continue"
    # Check if Teams connection is active
    Get-CsTenant -ErrorAction Stop | Out-Null
}
catch {
    Start-Sleep -Seconds 5
    try {
        $VerbosePreference = "SilentlyContinue"
        $tmp = Connect-MicrosoftTeams -Identity -ErrorAction Stop
        $VerbosePreference = "Continue"
        # Check if Teams connection is active
        Get-CsTenant -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Microsoft Teams PowerShell session could not be established. Stopping script!"
        Exit
    }
}

#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

$skipMain = $false
$hadErrors = $false
$userCache = @{}

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"
Write-Output "Looking up auto attendant '$attendantName'..."

$autoAttendant = Get-AutoAttendantByName -Name $attendantName
$autoAttendantIdentity = Get-AutoAttendantIdentity -AutoAttendant $autoAttendant
Write-Output "Auto attendant: '$($autoAttendant.Name)'"

$currentAuthorized = @()
foreach ($authorizedUser in @($autoAttendant.AuthorizedUsers)) {
    if ($null -eq $authorizedUser) { continue }
    $currentAuthorized += ([string]$authorizedUser).ToLowerInvariant()
}

$currentHidden = @()
foreach ($hiddenUser in @($autoAttendant.HideAuthorizedUsers)) {
    if ($null -eq $hiddenUser) { continue }
    $currentHidden += ([string]$hiddenUser).ToLowerInvariant()
}

Write-Output "Authorized users: $($currentAuthorized.Count) (of 15)"
if ($currentAuthorized.Count -eq 0) {
    Write-Output " - none"
}
foreach ($authorizedId in $currentAuthorized) {
    $authorizedUserObject = Get-TeamsUserFromCache -Cache $userCache -Identity $authorizedId
    $authorizedLabel = Get-UserLabel -Identity $authorizedId -TeamsUser $authorizedUserObject
    $authorizedPolicy = Get-UserVoiceApplicationsPolicyName -TeamsUser $authorizedUserObject
    $hiddenNote = if ($currentHidden -contains $authorizedId) { " - hidden" } else { "" }
    Write-Output " - $authorizedLabel - voice applications policy: $authorizedPolicy$hiddenNote"
}

Write-Output ""
Write-Output "Preflight-Check"
Write-Output "---------------------"

if ($VoiceApplicationsPolicyAction -eq "Assign") {
    try {
        Get-CsTeamsVoiceApplicationsPolicy -Identity $policyName -ErrorAction Stop | Out-Null
        Write-Output "The voice applications policy '$policyName' exists."
    }
    catch {
        Write-Error -Message "Teams - Error: The voice applications policy '$policyName' does not exist in this tenant. Check the policy name in the Teams admin center. Error Message: $($_.Exception.Message)" -ErrorAction Continue
        throw "The voice applications policy '$policyName' does not exist in this tenant."
    }
}

Write-Output "Checking $($requestedUserIds.Count) selected user(s) in Microsoft Teams..."

$results = [System.Collections.Generic.List[object]]::new()
$parsedGuid = [guid]::Empty

foreach ($requestedUserId in $requestedUserIds) {
    $teamsUser = $null
    $objectId = $null

    if ([guid]::TryParse($requestedUserId, [ref]$parsedGuid)) {
        $objectId = $parsedGuid.ToString().ToLowerInvariant()
        $teamsUser = Get-TeamsUserFromCache -Cache $userCache -Identity $objectId
    }
    else {
        $teamsUser = Get-TeamsUserFromCache -Cache $userCache -Identity $requestedUserId
        if ($null -ne $teamsUser -and -not [string]::IsNullOrWhiteSpace([string]$teamsUser.Identity)) {
            $objectId = ([string]$teamsUser.Identity).ToLowerInvariant()
            $userCache[$objectId] = $teamsUser
        }
    }

    $label = Get-UserLabel -Identity $requestedUserId -TeamsUser $teamsUser
    $displayName = Get-UserDisplayName -Identity $requestedUserId -TeamsUser $teamsUser
    $currentPolicy = Get-UserVoiceApplicationsPolicyName -TeamsUser $teamsUser
    $upn = if ($null -ne $teamsUser) { [string]$teamsUser.UserPrincipalName } else { "" }
    $notFoundReason = "not found in Microsoft Teams. This is usually the case if the user is not licensed for Microsoft Teams or the replication of the license has not yet been completed. Check the license and run the runbook again after at least one hour"

    $outcome = ""
    $reason = ""

    if ($null -eq $objectId) {
        $outcome = "Skipped"
        $reason = $notFoundReason
    }
    elseif ($Remove) {
        if ($currentAuthorized -contains $objectId) {
            $outcome = "Remove"
        }
        else {
            $outcome = "NoChange"
            $reason = "not an authorized user of this auto attendant"
        }
    }
    elseif ($null -eq $teamsUser) {
        $outcome = "Skipped"
        $reason = $notFoundReason
    }
    elseif (([string]$teamsUser.AccountType) -ne "User") {
        $outcome = "Skipped"
        $reason = "not a regular user account (account type '$([string]$teamsUser.AccountType)'); authorized users have to be regular users"
    }
    elseif ($teamsUser.EnterpriseVoiceEnabled -ne $true) {
        $outcome = "Skipped"
        $reason = "Enterprise Voice is not enabled; assign a Teams Phone license and run Set Teams Phone first"
    }
    elseif ($currentAuthorized -contains $objectId) {
        $outcome = "NoChange"
        $reason = "already an authorized user"
    }
    else {
        $outcome = "Add"
    }

    $policyStep = $false
    if ($outcome -ne "Skipped" -and $null -ne $teamsUser -and -not [string]::IsNullOrWhiteSpace($upn)) {
        if ($VoiceApplicationsPolicyAction -eq "None") {
            $policyStep = ((-not $Remove) -and ($currentPolicy -eq "Global"))
        }
        elseif ($VoiceApplicationsPolicyAction -eq "Remove") {
            # The policy is only reset for users who are actually taken off the list
            $policyStep = ($outcome -eq "Remove")
        }
        else {
            $policyStep = $true
        }
    }

    $results.Add([PSCustomObject]@{
            Id                  = $objectId
            Label               = $label
            DisplayName         = $displayName
            Upn                 = $upn
            CurrentPolicy       = $currentPolicy
            Outcome             = $outcome
            Reason              = $reason
            PolicyStep          = $policyStep
            PolicyOutcome       = ""
            PolicyDetail        = ""
            PolicyReference     = ""
            PolicyGroupFallback = ""
            NewPolicy           = ""
            PolicyResult        = "Not changed"
        })
}

$newAuthorized = @()
$newHidden = @($currentHidden)

if ($Remove) {
    $removeIds = @($results | Where-Object { $_.Outcome -eq "Remove" } | ForEach-Object { $_.Id })
    $newAuthorized = @($currentAuthorized | Where-Object { $removeIds -notcontains $_ })
    $newHidden = @($currentHidden | Where-Object { $removeIds -notcontains $_ })
}
else {
    $newAuthorized = @($currentAuthorized)
    foreach ($result in $results) {
        if ($result.Outcome -eq "Add" -and $newAuthorized -notcontains $result.Id) {
            $newAuthorized += $result.Id
        }
    }
}

$authorizedChanged = ($newAuthorized.Count -ne $currentAuthorized.Count) -or (@($newAuthorized | Where-Object { $currentAuthorized -notcontains $_ }).Count -gt 0)
$hideChanged = ($newHidden.Count -ne $currentHidden.Count)

if ((-not $Remove) -and $newAuthorized.Count -gt 15) {
    Write-Error -Message "Teams - Error: Auto attendant '$($autoAttendant.Name)' would end up with $($newAuthorized.Count) authorized users. Microsoft allows 15 per auto attendant. Take authorized users off the list first or pick fewer users." -ErrorAction Continue
    throw "Auto attendant '$($autoAttendant.Name)' would end up with $($newAuthorized.Count) authorized users; Microsoft allows 15."
}

Write-Output ""
Write-Output "Planned changes"
Write-Output "---------------------"
foreach ($result in $results) {
    switch ($result.Outcome) {
        "Add" { Write-Output "Add: $($result.Label)" }
        "Remove" { Write-Output "Remove: $($result.Label)" }
        "Skipped" { Write-Output "Skipped: $($result.Label) - $($result.Reason)" }
        default { Write-Output "No action needed: $($result.Label) - $($result.Reason)" }
    }
}

$policyRows = @($results | Where-Object { $_.PolicyStep })

if ($VoiceApplicationsPolicyAction -eq "Remove" -and $policyRows.Count -gt 0) {
    Write-Output ""
    Write-Output "Voice applications policy check"
    Write-Output "---------------------"
    Write-Output "Reading the authorized users of all other auto attendants and call queues..."
    $authorizedElsewhere = Get-AuthorizedElsewhere -ExcludeAutoAttendantIdentity $autoAttendantIdentity

    foreach ($result in $policyRows) {
        $assignments = @()
        try {
            $assignments = @(Get-CsUserPolicyAssignment -Identity $result.Upn -PolicyType TeamsVoiceApplicationsPolicy -ErrorAction Stop)
        }
        catch {
            Write-RjRbLog -Message "Get-CsUserPolicyAssignment failed for '$($result.Upn)': $($_.Exception.Message)" -Verbose
        }
        Write-RjRbLog -Message "Voice applications policy assignment of '$($result.Upn)':" -Data $assignments -Verbose

        $directPolicyName = ""
        $groupPolicyName = ""
        $groupPolicyReference = ""
        foreach ($assignment in $assignments) {
            foreach ($policySource in @($assignment.PolicySource)) {
                if ($null -eq $policySource) { continue }
                $sourcePolicyName = [string]$policySource.PolicyName
                if ([string]::IsNullOrWhiteSpace($sourcePolicyName)) { $sourcePolicyName = [string]$assignment.PolicyName }
                switch ([string]$policySource.AssignmentType) {
                    "Direct" { $directPolicyName = $sourcePolicyName }
                    "Group" {
                        $groupPolicyName = $sourcePolicyName
                        $groupPolicyReference = [string]$policySource.Reference
                    }
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($directPolicyName)) {
            if (-not [string]::IsNullOrWhiteSpace($groupPolicyName)) {
                $result.PolicyOutcome = "GroupOnly"
                $result.PolicyDetail = $groupPolicyName
                $result.PolicyReference = $groupPolicyReference
            }
            else {
                $result.PolicyOutcome = "NoAssignment"
            }
            continue
        }

        $result.PolicyOutcome = "RemoveDirect"
        $result.PolicyDetail = $directPolicyName
        $result.PolicyGroupFallback = $groupPolicyName

        if ($null -ne $result.Id -and $authorizedElsewhere.ContainsKey($result.Id)) {
            $result.PolicyOutcome = "SkippedElsewhere"
            $result.PolicyReference = (@($authorizedElsewhere[$result.Id]) -join ", ")
        }
    }
}

if ((-not $authorizedChanged) -and (-not $hideChanged) -and $policyRows.Count -eq 0) {
    $skipMain = $true
    Write-Output ""
    Write-Output "Nothing needs to be changed on auto attendant '$($autoAttendant.Name)'. No action taken."
}

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

$finalAuthorized = @($currentAuthorized)
$policyOverrides = @{}

if (-not $skipMain) {

    Write-Output ""
    Write-Output "Change authorized users"
    Write-Output "---------------------"

    if ($authorizedChanged -or $hideChanged) {
        $previousWarningPreference = $WarningPreference
        $WarningPreference = "SilentlyContinue"
        try {
            # Set-CsAutoAttendant writes the whole configuration, so only the two lists are changed on a freshly read instance
            $instance = Get-CsAutoAttendant -Identity $autoAttendantIdentity -ErrorAction Stop
            $instance.AuthorizedUsers = [guid[]]$newAuthorized
            if ($hideChanged) {
                $instance.HideAuthorizedUsers = [guid[]]$newHidden
            }
            Set-CsAutoAttendant -Instance $instance -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Error -Message "Teams - Error: Updating auto attendant '$($autoAttendant.Name)' failed. Error Message: $($_.Exception.Message)" -ErrorAction Continue
            throw "Updating auto attendant '$($autoAttendant.Name)' failed."
        }
        finally {
            $WarningPreference = $previousWarningPreference
        }

        foreach ($result in $results) {
            switch ($result.Outcome) {
                "Add" { Write-Output "Added: $($result.Label)" }
                "Remove" { Write-Output "Removed: $($result.Label)" }
            }
        }
        if ($hideChanged) {
            Write-Output "The list of hidden authorized users was updated as well."
        }
    }
    else {
        Write-Output "The authorized users of auto attendant '$($autoAttendant.Name)' were not changed."
    }

    # Read the auto attendant again and compare, the service applies the change asynchronously
    $finalAuthorized = @($newAuthorized)
    $updatedAutoAttendant = $null
    $previousWarningPreference = $WarningPreference
    $WarningPreference = "SilentlyContinue"
    try {
        $updatedAutoAttendant = Get-CsAutoAttendant -Identity $autoAttendantIdentity -ErrorAction Stop
    }
    catch {
        Write-RjRbLog -Message "Reading auto attendant '$($autoAttendant.Name)' again failed: $($_.Exception.Message)" -Verbose
    }
    finally {
        $WarningPreference = $previousWarningPreference
    }

    if ($null -ne $updatedAutoAttendant) {
        $updatedAuthorized = @()
        foreach ($authorizedUser in @($updatedAutoAttendant.AuthorizedUsers)) {
            if ($null -eq $authorizedUser) { continue }
            $updatedAuthorized += ([string]$authorizedUser).ToLowerInvariant()
        }
        $missingIds = @($newAuthorized | Where-Object { $updatedAuthorized -notcontains $_ })
        $unexpectedIds = @($updatedAuthorized | Where-Object { $newAuthorized -notcontains $_ })
        if ($missingIds.Count -gt 0 -or $unexpectedIds.Count -gt 0) {
            Write-Output "WARNING: The authorized users of auto attendant '$($autoAttendant.Name)' do not match the expected result. Check the auto attendant in the Teams admin center."
        }
        $finalAuthorized = $updatedAuthorized
    }
    else {
        Write-Output "WARNING: Auto attendant '$($autoAttendant.Name)' could not be read again, so the result below could not be confirmed."
    }

    if ($policyRows.Count -gt 0) {
        Write-Output ""
        Write-Output "Voice applications policy"
        Write-Output "---------------------"

        foreach ($result in $policyRows) {
            if ($VoiceApplicationsPolicyAction -eq "Assign") {
                if ($result.CurrentPolicy -eq $policyName) {
                    Write-Output "$($result.Label): already uses the voice applications policy '$policyName'"
                    $result.NewPolicy = $policyName
                    $result.PolicyResult = "Already assigned"
                    continue
                }
                try {
                    Grant-CsTeamsVoiceApplicationsPolicy -Identity $result.Upn -PolicyName $policyName -ErrorAction Stop
                    Write-Output "$($result.Label): voice applications policy '$policyName' assigned"
                    $result.NewPolicy = $policyName
                    $result.PolicyResult = "Assigned"
                }
                catch {
                    Write-Error -Message "Teams - Error: The assignment of the voice applications policy '$policyName' for $($result.Upn) could not be completed. Error Message: $($_.Exception.Message)" -ErrorAction Continue
                    $result.PolicyResult = "Assignment failed"
                    $hadErrors = $true
                }
                continue
            }

            if ($VoiceApplicationsPolicyAction -eq "Remove") {
                switch ($result.PolicyOutcome) {
                    "NoAssignment" {
                        Write-Output "$($result.Label): no per-user voice applications policy assigned, nothing to remove"
                        $result.PolicyResult = "No per-user policy"
                    }
                    "GroupOnly" {
                        $groupNote = if ([string]::IsNullOrWhiteSpace($result.PolicyReference)) { "" } else { " (group $($result.PolicyReference))" }
                        Write-Output "WARNING: $($result.Label): the voice applications policy '$($result.PolicyDetail)' comes from a group policy assignment$groupNote and cannot be removed per user. Remove the user from that group or change the group assignment."
                        $result.PolicyResult = "Kept, assigned by group"
                    }
                    "SkippedElsewhere" {
                        Write-Output "WARNING: $($result.Label): the voice applications policy '$($result.PolicyDetail)' was kept, the user is still an authorized user of $($result.PolicyReference)."
                        $result.PolicyResult = "Kept, still authorized elsewhere"
                    }
                    default {
                        try {
                            Grant-CsTeamsVoiceApplicationsPolicy -Identity $result.Upn -PolicyName $null -ErrorAction Stop
                            if ([string]::IsNullOrWhiteSpace($result.PolicyGroupFallback)) {
                                Write-Output "$($result.Label): voice applications policy '$($result.PolicyDetail)' removed, the user falls back to Global"
                                $result.NewPolicy = "Global"
                            }
                            else {
                                Write-Output "$($result.Label): voice applications policy '$($result.PolicyDetail)' removed, the group policy assignment '$($result.PolicyGroupFallback)' now takes over"
                                $result.NewPolicy = $result.PolicyGroupFallback
                            }
                            $result.PolicyResult = "Removed"
                        }
                        catch {
                            Write-Error -Message "Teams - Error: The removal of the voice applications policy for $($result.Upn) could not be completed. Error Message: $($_.Exception.Message)" -ErrorAction Continue
                            $result.PolicyResult = "Removal failed"
                            $hadErrors = $true
                        }
                    }
                }
                continue
            }

            Write-Output "WARNING: $($result.Label) uses the Global voice applications policy, which usually allows no changes. Assign a policy that allows auto attendant changes (run again with 'Assign a voice applications policy')."
            $result.PolicyResult = "Not changed, Global"
        }
    }

    foreach ($result in $results) {
        if ($null -ne $result.Id -and -not [string]::IsNullOrWhiteSpace($result.NewPolicy)) {
            $policyOverrides[$result.Id] = $result.NewPolicy
        }
    }

    Write-Output ""
    Write-Output "Authorized users now"
    Write-Output "---------------------"
    Write-Output "Count: $($finalAuthorized.Count) (of 15)"
    if ($finalAuthorized.Count -eq 0) {
        Write-Output " - none"
    }
    foreach ($authorizedId in $finalAuthorized) {
        $authorizedUserObject = Get-TeamsUserFromCache -Cache $userCache -Identity $authorizedId
        $authorizedLabel = Get-UserLabel -Identity $authorizedId -TeamsUser $authorizedUserObject
        $authorizedPolicy = if ($policyOverrides.ContainsKey($authorizedId)) { $policyOverrides[$authorizedId] } else { Get-UserVoiceApplicationsPolicyName -TeamsUser $authorizedUserObject }
        $hiddenNote = if ($newHidden -contains $authorizedId) { " - hidden" } else { "" }
        Write-Output " - $authorizedLabel - voice applications policy: $authorizedPolicy$hiddenNote"
    }
}

#region Output Data
# Emitted last so the tables are not interleaved with the console output. A marker is only written when rows
# follow it, because the portal applies the name to the next table it receives.
$changeRows = [System.Collections.Generic.List[object]]::new()
$skippedRows = [System.Collections.Generic.List[object]]::new()
$unchangedRows = [System.Collections.Generic.List[object]]::new()
foreach ($result in $results) {
    $rowPolicy = if (-not [string]::IsNullOrWhiteSpace($result.NewPolicy)) { $result.NewPolicy } else { $result.CurrentPolicy }
    switch ($result.Outcome) {
        { $_ -in "Add", "Remove" } {
            $changeRows.Add([PSCustomObject]@{
                    DisplayName             = $result.DisplayName
                    UserPrincipalName       = $result.Upn
                    Change                  = if ($result.Outcome -eq "Add") { "Added" } else { "Removed" }
                    VoiceApplicationsPolicy = $rowPolicy
                    PolicyResult            = $result.PolicyResult
                })
        }
        "Skipped" {
            $skippedRows.Add([PSCustomObject]@{
                    User   = $result.Label
                    Reason = $result.Reason
                })
        }
        default {
            $unchangedRows.Add([PSCustomObject]@{
                    DisplayName             = $result.DisplayName
                    UserPrincipalName       = $result.Upn
                    Reason                  = $result.Reason
                    VoiceApplicationsPolicy = $rowPolicy
                    PolicyResult            = $result.PolicyResult
                })
        }
    }
}

$authorizedRows = [System.Collections.Generic.List[object]]::new()
foreach ($authorizedId in $finalAuthorized) {
    $authorizedUserObject = Get-TeamsUserFromCache -Cache $userCache -Identity $authorizedId
    $authorizedRows.Add([PSCustomObject]@{
            DisplayName             = Get-UserDisplayName -Identity $authorizedId -TeamsUser $authorizedUserObject
            UserPrincipalName       = if ($null -ne $authorizedUserObject) { [string]$authorizedUserObject.UserPrincipalName } else { "" }
            VoiceApplicationsPolicy = if ($policyOverrides.ContainsKey($authorizedId)) { $policyOverrides[$authorizedId] } else { Get-UserVoiceApplicationsPolicyName -TeamsUser $authorizedUserObject }
            Hidden                  = if ($newHidden -contains $authorizedId) { "Yes" } else { "No" }
        })
}

Write-Output ""
if ($changeRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Authorized user changes" })
    Write-Output $changeRows.ToArray()
}
if ($skippedRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Skipped users" })
    Write-Output $skippedRows.ToArray()
}
if ($unchangedRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "No change needed" })
    Write-Output $unchangedRows.ToArray()
}
if ($authorizedRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Authorized users" })
    Write-Output $authorizedRows.ToArray()
}
else {
    Write-Output "Auto attendant '$($autoAttendant.Name)' has no authorized users."
}
#endregion Output Data

if ($hadErrors) {
    throw "At least one voice applications policy could not be changed. See the errors above."
}

#endregion Main Part

########################################################
#region     Cleanup
########################################################

Disconnect-MicrosoftTeams -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

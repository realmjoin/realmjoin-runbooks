<#
    .SYNOPSIS
    Add or remove authorized users of a Teams call queue

    .DESCRIPTION
    Adds the selected users to the authorized users of a call queue or removes them. Authorized users can change the queue settings in the Teams app; Microsoft allows 15 of them per call queue. The Teams voice applications policy they need for that can be assigned or removed in the same run. Details on the checks and options are in the runbook documentation (docs.realmjoin.com).

    .PARAMETER CallQueueName
    Exact name of the call queue as it is shown in the Teams admin center. Upper and lower case do not matter.

    .PARAMETER UserIds
    Users that are added to or removed from the list of authorized users. Several users can be picked at once; each one needs to be enabled for Teams Phone.

    .PARAMETER Remove
    Add users as authorized users puts them on the queue's authorized user list. Remove users as authorized users takes them off it again.

    .PARAMETER VoiceApplicationsPolicyAction
    Leave the policy unchanged touches no policy. Assign a voice applications policy grants the policy entered under "Policy name". Remove the voice applications policy resets a per-user assignment when the users are taken off the list.

    .PARAMETER VoiceApplicationsPolicyName
    Voice applications policy to grant, named exactly as in the Teams admin center. Only used with "Assign a voice applications policy".

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallQueueName": {
                "DisplayName": "Call queue name"
            },
            "UserIds": {
                "DisplayName": "Users"
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "7.9.0" }

# Suppress false positive from PSScriptAnalyzer - $tmp is used to suppress unwanted output from Connect-MicrosoftTeams
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "tmp")]
param(
    [Parameter(Mandatory = $true)]
    [string] $CallQueueName,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Users" -Filter "userType eq 'Member'" } )]
    [string[]] $UserIds,
    [bool] $Remove = $false,
    [ValidateSet("None", "Assign", "Remove")]
    [string] $VoiceApplicationsPolicyAction = "None",
    [string] $VoiceApplicationsPolicyName = "",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
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
Write-RjRbLog -Message "CallQueueName: $CallQueueName" -Verbose
Write-RjRbLog -Message "UserIds: $($UserIds -join ', ')" -Verbose
Write-RjRbLog -Message "Remove: $Remove" -Verbose
Write-RjRbLog -Message "VoiceApplicationsPolicyAction: $VoiceApplicationsPolicyAction" -Verbose
Write-RjRbLog -Message "VoiceApplicationsPolicyName: $VoiceApplicationsPolicyName" -Verbose

#endregion

########################################################
#region     Parameter Validation
##
########################################################

$queueName = ""
if ($null -ne $CallQueueName) {
    $queueName = $CallQueueName.Trim()
}
if ([string]::IsNullOrWhiteSpace($queueName)) {
    Write-Error -Message "No call queue name was submitted. Enter the name of the call queue exactly as it is shown in the Teams admin center." -ErrorAction Continue
    throw "No call queue name was submitted."
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

#endregion

########################################################
#region     Function Definitions
##
########################################################

function Get-CallQueueByName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    $previousWarningPreference = $WarningPreference
    $WarningPreference = "SilentlyContinue"
    try {
        # NameFilter is a server-side "contains" match, paged with at most 100 items per page
        $candidates = [System.Collections.Generic.List[object]]::new()
        $skip = 0
        do {
            $page = @(Get-CsCallQueue -NameFilter $Name -First 100 -Skip $skip -ErrorAction Stop)
            if ($page.Count -gt 0) { $candidates.AddRange([object[]]$page) }
            $skip += 100
        } while ($page.Count -eq 100)

        $exact = @($candidates | Where-Object { $_.Name -eq $Name })

        if ($exact.Count -eq 0) {
            # Fallback: scan names only, in case the server-side filter is case-sensitive
            $all = [System.Collections.Generic.List[object]]::new()
            $skip = 0
            do {
                $page = @(Get-CsCallQueue -ExcludeContent -First 100 -Skip $skip -ErrorAction Stop)
                if ($page.Count -gt 0) { $all.AddRange([object[]]$page) }
                $skip += 100
            } while ($page.Count -eq 100)
            $exact = @($all | Where-Object { $_.Name -eq $Name } | ForEach-Object { Get-CsCallQueue -Identity $_.Identity -ErrorAction Stop })
        }

        if ($exact.Count -eq 0) {
            $similar = @($candidates | Select-Object -ExpandProperty Name -Unique)
            $hint = if ($similar.Count -gt 0) { " Similar names: " + (($similar | ForEach-Object { "'$_'" }) -join ", ") + "." } else { "" }
            Write-Error -Message "No call queue named '$Name' was found. Check the name in the Teams admin center.$hint" -ErrorAction Continue
            throw "No call queue named '$Name' was found."
        }
        if ($exact.Count -gt 1) {
            $list = ($exact | ForEach-Object { "'$($_.Name)' ($($_.Identity))" }) -join ", "
            Write-Error -Message "More than one call queue is named '$Name': $list. Give the call queues unique names and run the runbook again." -ErrorAction Continue
            throw "More than one call queue is named '$Name'."
        }
        return $exact[0]
    }
    finally {
        $WarningPreference = $previousWarningPreference
    }
}

function Get-AuthorizedElsewhere {
    # Maps a lowercase user object ID to the other call queues and auto attendants the user is authorized on
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExcludeQueueIdentity
    )
    $map = @{}
    $previousWarningPreference = $WarningPreference
    $WarningPreference = "SilentlyContinue"
    try {
        $skip = 0
        do {
            $page = @(Get-CsCallQueue -First 100 -Skip $skip -ErrorAction Stop)
            foreach ($queue in $page) {
                if (([string]$queue.Identity) -eq $ExcludeQueueIdentity) {
                    continue
                }
                foreach ($authorizedUser in @($queue.AuthorizedUsers)) {
                    if ($null -eq $authorizedUser) { continue }
                    $key = ([string]$authorizedUser).ToLowerInvariant()
                    if (-not $map.ContainsKey($key)) { $map[$key] = [System.Collections.Generic.List[string]]::new() }
                    $map[$key].Add("call queue '$($queue.Name)'")
                }
            }
            $skip += 100
        } while ($page.Count -eq 100)

        $skip = 0
        do {
            $page = @(Get-CsAutoAttendant -First 100 -Skip $skip -ErrorAction Stop)
            foreach ($autoAttendant in $page) {
                foreach ($authorizedUser in @($autoAttendant.AuthorizedUsers)) {
                    if ($null -eq $authorizedUser) { continue }
                    $key = ([string]$authorizedUser).ToLowerInvariant()
                    if (-not $map.ContainsKey($key)) { $map[$key] = [System.Collections.Generic.List[string]]::new() }
                    $map[$key].Add("auto attendant '$($autoAttendant.Name)'")
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

#endregion

########################################################
#region     Connect Part
##
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

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
##
########################################################

$skipMain = $false
$hadErrors = $false
$userCache = @{}

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"
Write-Output "Looking up call queue '$queueName'..."

$callQueue = Get-CallQueueByName -Name $queueName
$callQueueIdentity = [string]$callQueue.Identity
Write-Output "Call queue: '$($callQueue.Name)'"

$currentAuthorized = @()
foreach ($authorizedUser in @($callQueue.AuthorizedUsers)) {
    if ($null -eq $authorizedUser) { continue }
    $currentAuthorized += ([string]$authorizedUser).ToLowerInvariant()
}

$currentHidden = @()
foreach ($hiddenUser in @($callQueue.HideAuthorizedUsers)) {
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
            $reason = "not an authorized user of this call queue"
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
    Write-Error -Message "Teams - Error: Call queue '$($callQueue.Name)' would end up with $($newAuthorized.Count) authorized users. Microsoft allows 15 per call queue. Take authorized users off the list first or pick fewer users." -ErrorAction Continue
    throw "Call queue '$($callQueue.Name)' would end up with $($newAuthorized.Count) authorized users; Microsoft allows 15."
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
    Write-Output "Reading the authorized users of all other call queues and auto attendants..."
    $authorizedElsewhere = Get-AuthorizedElsewhere -ExcludeQueueIdentity $callQueueIdentity

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
    Write-Output "Nothing needs to be changed on call queue '$($callQueue.Name)'. No action taken."
}

#endregion

########################################################
#region     Main Part
##
########################################################

if (-not $skipMain) {

    Write-Output ""
    Write-Output "Change authorized users"
    Write-Output "---------------------"

    if ($authorizedChanged -or $hideChanged) {
        $previousWarningPreference = $WarningPreference
        $WarningPreference = "SilentlyContinue"
        try {
            if ($hideChanged) {
                Set-CsCallQueue -Identity $callQueueIdentity -AuthorizedUsers ([guid[]]$newAuthorized) -HideAuthorizedUsers ([guid[]]$newHidden) -ErrorAction Stop | Out-Null
            }
            else {
                Set-CsCallQueue -Identity $callQueueIdentity -AuthorizedUsers ([guid[]]$newAuthorized) -ErrorAction Stop | Out-Null
            }
        }
        catch {
            Write-Error -Message "Teams - Error: Updating call queue '$($callQueue.Name)' failed. Error Message: $($_.Exception.Message)" -ErrorAction Continue
            throw "Updating call queue '$($callQueue.Name)' failed."
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
        Write-Output "The authorized users of call queue '$($callQueue.Name)' were not changed."
    }

    # Read the call queue again and compare, the service applies the change asynchronously
    $updatedQueue = $null
    $previousWarningPreference = $WarningPreference
    $WarningPreference = "SilentlyContinue"
    try {
        $updatedQueue = Get-CsCallQueue -Identity $callQueueIdentity -ErrorAction Stop
    }
    catch {
        Write-RjRbLog -Message "Reading call queue '$($callQueue.Name)' again failed: $($_.Exception.Message)" -Verbose
    }
    finally {
        $WarningPreference = $previousWarningPreference
    }

    $finalAuthorized = @($newAuthorized)
    if ($null -ne $updatedQueue) {
        $updatedAuthorized = @()
        foreach ($authorizedUser in @($updatedQueue.AuthorizedUsers)) {
            if ($null -eq $authorizedUser) { continue }
            $updatedAuthorized += ([string]$authorizedUser).ToLowerInvariant()
        }
        $missingIds = @($newAuthorized | Where-Object { $updatedAuthorized -notcontains $_ })
        $unexpectedIds = @($updatedAuthorized | Where-Object { $newAuthorized -notcontains $_ })
        if ($missingIds.Count -gt 0 -or $unexpectedIds.Count -gt 0) {
            Write-Output "WARNING: The authorized users of call queue '$($callQueue.Name)' do not match the expected result. Check the call queue in the Teams admin center."
        }
        $finalAuthorized = $updatedAuthorized
    }
    else {
        Write-Output "WARNING: Call queue '$($callQueue.Name)' could not be read again, so the result below could not be confirmed."
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
                    continue
                }
                try {
                    Grant-CsTeamsVoiceApplicationsPolicy -Identity $result.Upn -PolicyName $policyName -ErrorAction Stop
                    Write-Output "$($result.Label): voice applications policy '$policyName' assigned"
                    $result.NewPolicy = $policyName
                }
                catch {
                    Write-Error -Message "Teams - Error: The assignment of the voice applications policy '$policyName' for $($result.Upn) could not be completed. Error Message: $($_.Exception.Message)" -ErrorAction Continue
                    $hadErrors = $true
                }
                continue
            }

            if ($VoiceApplicationsPolicyAction -eq "Remove") {
                switch ($result.PolicyOutcome) {
                    "NoAssignment" {
                        Write-Output "$($result.Label): no per-user voice applications policy assigned, nothing to remove"
                    }
                    "GroupOnly" {
                        $groupNote = if ([string]::IsNullOrWhiteSpace($result.PolicyReference)) { "" } else { " (group $($result.PolicyReference))" }
                        Write-Output "WARNING: $($result.Label): the voice applications policy '$($result.PolicyDetail)' comes from a group policy assignment$groupNote and cannot be removed per user. Remove the user from that group or change the group assignment."
                    }
                    "SkippedElsewhere" {
                        Write-Output "WARNING: $($result.Label): the voice applications policy '$($result.PolicyDetail)' was kept, the user is still an authorized user of $($result.PolicyReference)."
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
                        }
                        catch {
                            Write-Error -Message "Teams - Error: The removal of the voice applications policy for $($result.Upn) could not be completed. Error Message: $($_.Exception.Message)" -ErrorAction Continue
                            $hadErrors = $true
                        }
                    }
                }
                continue
            }

            Write-Output "WARNING: $($result.Label) uses the Global voice applications policy. Authorized users cannot change anything until a policy that allows call queue management is assigned (run again with 'Assign a voice applications policy')."
        }
    }

    $policyOverrides = @{}
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

    if ($hadErrors) {
        throw "At least one voice applications policy could not be changed. See the errors above."
    }
}

#endregion

########################################################
#region     Cleanup
##
########################################################

Disconnect-MicrosoftTeams -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion

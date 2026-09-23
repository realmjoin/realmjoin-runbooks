<#
    .SYNOPSIS
    Add or remove agents of a Teams call queue

    .DESCRIPTION
    Adds the selected users as individually assigned agents of a Teams call queue or takes them off that list. Agents that come from a group, a team or a shifts schedule are not touched; the output says where they are managed instead. Users without Enterprise Voice are skipped with the reason. Details on the checks and limits are in the runbook documentation (docs.realmjoin.com).

    .PARAMETER CallQueueName
    Exact name of the call queue as shown in the Teams admin center. Upper and lower case do not matter, but the name has to match exactly one queue.

    .PARAMETER UserIds
    Users to add or remove, several at a time. To work as an agent, a user needs a Teams Phone license with Enterprise Voice enabled.

    .PARAMETER Remove
    Add users as agents puts them on the list of individually assigned agents. Remove users as agents takes them off it; agents that come from a group or team stay as they are.

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
                    "Add users as agents": false,
                    "Remove users as agents": true
                }
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "7.9.0" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

# Suppress false positive from PSScriptAnalyzer - $tmp is used to suppress unwanted output from Connect-MicrosoftTeams
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "tmp")]
param(
    [Parameter(Mandatory = $true)]
    [String] $CallQueueName,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Users" -Filter "userType eq 'Member'" } )]
    [String[]] $UserIds,
    [bool] $Remove = $false,
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

#endregion

########################################################
#region     Parameter Validation
##
########################################################

$CallQueueName = "$CallQueueName".Trim()

if ([string]::IsNullOrWhiteSpace($CallQueueName)) {
    Write-Error -Message "No call queue name was submitted. Enter the name of the call queue exactly as it is shown in the Teams admin center." -ErrorAction Continue
    throw "No call queue name was submitted."
}

# The portal delivers Entra ID object IDs; other values are tolerated and resolved in Microsoft Teams later on
$pickedEntries = @()
foreach ($entry in $UserIds) {
    $trimmedEntry = "$entry".Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($trimmedEntry)) {
        continue
    }
    if ($pickedEntries -notcontains $trimmedEntry) {
        $pickedEntries += $trimmedEntry
    }
}

if ($pickedEntries.Count -eq 0) {
    Write-Error -Message "No user was submitted. Select at least one user." -ErrorAction Continue
    throw "No user was submitted."
}

Write-RjRbLog -Message "Users to process: $($pickedEntries.Count)" -Verbose

#endregion

########################################################
#region     Function Definitions
##
########################################################

$script:teamsUserCache = @{}
$script:graphAvailable = $false

function Test-IsGuid {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )
    $parsedGuid = [guid]::Empty
    return [guid]::TryParse($Value, [ref]$parsedGuid)
}

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

function Get-TeamsUser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )
    $cacheKey = $Identity.ToLower()
    if ($script:teamsUserCache.ContainsKey($cacheKey)) {
        return $script:teamsUserCache[$cacheKey]
    }
    $teamsUser = $null
    try {
        $teamsUser = Get-CsOnlineUser -Identity $Identity -ErrorAction Stop
    }
    catch {
        Write-RjRbLog -Message "Get-CsOnlineUser failed for '$Identity': $($_.Exception.Message)" -Verbose
    }
    $script:teamsUserCache[$cacheKey] = $teamsUser
    return $teamsUser
}

function Format-UserLabel {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )
    $teamsUser = Get-TeamsUser -Identity $Identity
    if ($teamsUser -and $teamsUser.DisplayName -and $teamsUser.UserPrincipalName) {
        return "$($teamsUser.DisplayName) ($($teamsUser.UserPrincipalName))"
    }
    if ($teamsUser -and $teamsUser.UserPrincipalName) {
        return [string]$teamsUser.UserPrincipalName
    }
    if ($teamsUser -and $teamsUser.DisplayName) {
        return "$($teamsUser.DisplayName) (ID $Identity)"
    }
    return "Unknown user (ID $Identity)"
}

function Resolve-GroupDisplayName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )
    if (-not $script:graphAvailable) {
        return $null
    }
    try {
        $groupResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$($GroupId)?`$select=displayName" -ErrorAction Stop
        if ($groupResponse -and $groupResponse.displayName) {
            return [string]$groupResponse.displayName
        }
    }
    catch {
        Write-RjRbLog -Message "Could not resolve the name of group '$GroupId': $($_.Exception.Message)" -Verbose
    }
    return $null
}

function Resolve-TeamChannel {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ChannelId,
        [Parameter(Mandatory = $false)]
        [string]$ChannelOwnerId
    )
    if (-not $script:graphAvailable) {
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($ChannelOwnerId)) {
        Write-RjRbLog -Message "The call queue has no channel owner, so the team of channel '$ChannelId' cannot be resolved." -Verbose
        return $null
    }
    try {
        $teamsResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$($ChannelOwnerId)/joinedTeams" -ErrorAction Stop
        $joinedTeams = @($teamsResponse.value)
        if ($joinedTeams.Count -eq 0) {
            return $null
        }
        if ($joinedTeams.Count -gt 100) {
            Write-RjRbLog -Message "The channel owner is a member of $($joinedTeams.Count) teams; only the first 100 are searched." -Verbose
            $joinedTeams = $joinedTeams[0..99]
        }

        $teamNameById = @{}
        $escapedChannelId = [uri]::EscapeDataString($ChannelId)
        $batchRequests = foreach ($team in $joinedTeams) {
            $teamId = [string]$team.id
            $teamNameById[$teamId] = [string]$team.displayName
            @{
                id     = $teamId
                method = "GET"
                url    = "/teams/$teamId/channels/$($escapedChannelId)?`$select=displayName"
            }
        }

        $batchResponses = @(Invoke-RjRbGraphBatch -Requests @($batchRequests) -ProgressLabel "teams" -ProgressInterval 0)
        foreach ($batchResponse in $batchResponses) {
            if ($batchResponse.status -eq 200 -and $batchResponse.body -and $batchResponse.body.displayName) {
                return @{
                    TeamName    = $teamNameById["$($batchResponse.id)"]
                    ChannelName = [string]$batchResponse.body.displayName
                }
            }
        }
    }
    catch {
        Write-RjRbLog -Message "Could not resolve the team and channel of channel '$ChannelId': $($_.Exception.Message)" -Verbose
    }
    return $null
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

# Microsoft Graph is only used to resolve group, team and channel names - a missing connection is not fatal
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    $script:graphAvailable = $true
    Write-RjRbLog -Message "Connected to Microsoft Graph." -Verbose
}
catch {
    Write-RjRbLog -Message "Could not connect to Microsoft Graph: $($_.Exception.Message). Groups, teams and channels are shown with their IDs." -Verbose
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
##
########################################################

$skipMain = $false
$queueManagedElsewhere = $false

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

$callQueue = Get-CallQueueByName -Name $CallQueueName
Write-Output "Call queue: '$($callQueue.Name)' ($($callQueue.Identity))"

# Users is a Guid array, Agents[].ObjectId is a string - compare both as lowercase strings
$currentUsers = @($callQueue.Users | ForEach-Object { ([string]$_).ToLower() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$currentGroups = @($callQueue.DistributionLists | ForEach-Object { ([string]$_).ToLower() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$agentIds = @($callQueue.Agents | ForEach-Object { ([string]$_.ObjectId).ToLower() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

$groupLabels = @()
foreach ($groupId in $currentGroups) {
    $groupName = Resolve-GroupDisplayName -GroupId $groupId
    if ($groupName) {
        $groupLabels += "'$groupName'"
    }
    else {
        $groupLabels += "ID $groupId"
    }
}
$groupList = $groupLabels -join ", "

if ($groupLabels.Count -eq 1) {
    $groupSource = "the group $groupList"
}
elseif ($groupLabels.Count -gt 1) {
    $groupSource = "the groups $groupList"
}
else {
    $groupSource = "another assignment of this call queue"
}

# Call answering is exclusive: team and channel, users and groups, or a shifts schedule
if ($callQueue.ChannelId) {
    $membershipMode = "Channel"
}
elseif ($callQueue.ShiftsTeamId -or $callQueue.ShiftsSchedulingGroupId) {
    $membershipMode = "Shifts"
}
elseif ($currentGroups.Count -gt 0 -and $currentUsers.Count -eq 0) {
    $membershipMode = "Groups"
}
else {
    $membershipMode = "Users"
}

Write-Output "Agents in total (individual users and group members): $($agentIds.Count)"

if ($membershipMode -eq "Channel") {
    $channelInfo = Resolve-TeamChannel -ChannelId $callQueue.ChannelId -ChannelOwnerId $callQueue.ChannelUserObjectId
    if ($channelInfo) {
        $channelSource = "the team '$($channelInfo.TeamName)' (channel '$($channelInfo.ChannelName)')"
    }
    else {
        $channelSource = "a team channel (channel ID $($callQueue.ChannelId))"
        if ($callQueue.ChannelUserObjectId) {
            $channelSource += ", owned by $(Format-UserLabel -Identity $callQueue.ChannelUserObjectId)"
        }
    }
    Write-Output "Call answering: team and channel"
    Write-Output ""
    Write-Output "The agents of call queue '$($callQueue.Name)' are managed through $channelSource."
    Write-Output "Add or remove the members in that team; the call queue follows the team membership automatically. A change can take up to 24 hours to become effective."
    Write-Output "No changes were made."
    $skipMain = $true
    $queueManagedElsewhere = $true
}
elseif ($membershipMode -eq "Shifts") {
    $shiftsTeamName = $null
    if ($callQueue.ShiftsTeamId) {
        $shiftsTeamName = Resolve-GroupDisplayName -GroupId $callQueue.ShiftsTeamId
    }
    if ($shiftsTeamName) {
        $shiftsSource = "the shifts schedule of team '$shiftsTeamName'"
    }
    else {
        $shiftsSource = "a shifts schedule (team ID $($callQueue.ShiftsTeamId))"
    }
    Write-Output "Call answering: shifts schedule"
    Write-Output ""
    Write-Output "The agents of call queue '$($callQueue.Name)' come from $shiftsSource, scheduling group ID $($callQueue.ShiftsSchedulingGroupId)."
    Write-Output "Change the shifts schedule in the Shifts app instead; the call queue follows the schedule automatically."
    Write-Output "No changes were made."
    $skipMain = $true
    $queueManagedElsewhere = $true
}
elseif ($membershipMode -eq "Groups") {
    Write-Output "Call answering: groups"
    Write-Output ""
    Write-Output "The agents of call queue '$($callQueue.Name)' are managed through $groupSource."
    Write-Output "Add or remove the members in that group; the call queue follows the group membership automatically. A change can take a few hours to become effective."
    Write-Output "To assign agents individually instead, change the call answering of the queue in the Teams admin center."
    Write-Output "No changes were made."
    $skipMain = $true
    $queueManagedElsewhere = $true
}
else {
    Write-Output "Call answering: individually assigned users"
    Write-Output "Individually assigned agents: $($currentUsers.Count)"
    foreach ($currentUserId in $currentUsers) {
        Write-Output " - $(Format-UserLabel -Identity $currentUserId)"
    }
    if ($groupLabels.Count -gt 0) {
        Write-Output "Groups assigned to this call queue: $groupList"
        Write-Output "This call queue also gets agents from $groupSource. Only the individually assigned agents are changed here."
    }
}

if (-not $queueManagedElsewhere) {
    Write-Output ""
    Write-Output "Preflight-Check"
    Write-Output "---------------------"

    $results = [System.Collections.Generic.List[object]]::new()
    $idsToAdd = @()
    $idsToRemove = @()
    $processedIds = @()

    foreach ($pickedEntry in $pickedEntries) {
        $teamsUser = Get-TeamsUser -Identity $pickedEntry

        $userId = $null
        if ($teamsUser -and $teamsUser.Identity) {
            $userId = ([string]$teamsUser.Identity).ToLower()
        }
        elseif (Test-IsGuid -Value $pickedEntry) {
            $userId = $pickedEntry
        }

        if ($teamsUser -and $teamsUser.DisplayName) {
            $userLabel = "$($teamsUser.DisplayName) ($($teamsUser.UserPrincipalName))"
        }
        elseif ($userId) {
            $userLabel = "Unknown user (ID $userId)"
        }
        else {
            $userLabel = "Unknown user ('$pickedEntry')"
        }

        if ($userId -and ($processedIds -contains $userId)) {
            Write-RjRbLog -Message "'$userLabel' was selected more than once and is processed only once." -Verbose
            continue
        }
        if ($userId) {
            $processedIds += $userId
        }

        if (-not $userId) {
            $results.Add([PSCustomObject]@{
                    Label   = $userLabel
                    Outcome = "Skipped"
                    Reason  = "the user could not be found in Microsoft Teams"
                })
            continue
        }

        if (-not $Remove) {
            if (-not $teamsUser) {
                $results.Add([PSCustomObject]@{
                        Label   = $userLabel
                        Outcome = "Skipped"
                        Reason  = "the user is not known in Microsoft Teams. Check the Teams Phone license; after a license change it can take about an hour until the user is available"
                    })
                continue
            }
            if ($teamsUser.AccountType -and $teamsUser.AccountType -ne "User") {
                $results.Add([PSCustomObject]@{
                        Label   = $userLabel
                        Outcome = "Skipped"
                        Reason  = "the account type is '$($teamsUser.AccountType)'. Only user accounts can be agents of a call queue"
                    })
                continue
            }
            if ($teamsUser.EnterpriseVoiceEnabled -ne $true) {
                $results.Add([PSCustomObject]@{
                        Label   = $userLabel
                        Outcome = "Skipped"
                        Reason  = "Enterprise Voice is not enabled. Assign a Teams Phone license and set up Teams Phone for the user first"
                    })
                continue
            }
            if ($currentUsers -contains $userId) {
                $results.Add([PSCustomObject]@{
                        Label   = $userLabel
                        Outcome = "Skipped"
                        Reason  = "already an individually assigned agent. No action taken"
                    })
                continue
            }
            if ($agentIds -contains $userId) {
                $results.Add([PSCustomObject]@{
                        Label   = $userLabel
                        Outcome = "Skipped"
                        Reason  = "already an agent through $groupSource. No action taken"
                    })
                continue
            }
            if ($teamsUser.TeamsUpgradeEffectiveMode -and $teamsUser.TeamsUpgradeEffectiveMode -ne "TeamsOnly") {
                Write-Output "WARNING: $userLabel is in Teams upgrade mode '$($teamsUser.TeamsUpgradeEffectiveMode)'. Agents who answer calls in the Teams app need TeamsOnly mode."
            }
            $idsToAdd += $userId
            $results.Add([PSCustomObject]@{
                    Label   = $userLabel
                    Outcome = "Add"
                    Reason  = ""
                })
        }
        else {
            if ($currentUsers -contains $userId) {
                $idsToRemove += $userId
                $results.Add([PSCustomObject]@{
                        Label   = $userLabel
                        Outcome = "Remove"
                        Reason  = ""
                    })
            }
            elseif ($agentIds -contains $userId) {
                $results.Add([PSCustomObject]@{
                        Label   = $userLabel
                        Outcome = "Skipped"
                        Reason  = "an agent through $groupSource, not an individual assignment. Remove the user from that group instead"
                    })
            }
            else {
                $results.Add([PSCustomObject]@{
                        Label   = $userLabel
                        Outcome = "Skipped"
                        Reason  = "not an individually assigned agent of this call queue. No action taken"
                    })
            }
        }
    }

    if (-not $Remove) {
        $newUsers = @($currentUsers) + @($idsToAdd)
        Write-Output "Users to add as agents: $($idsToAdd.Count)"
    }
    else {
        $newUsers = @($currentUsers | Where-Object { $idsToRemove -notcontains $_ })
        Write-Output "Users to remove as agents: $($idsToRemove.Count)"
    }
    $changeCount = $idsToAdd.Count + $idsToRemove.Count

    if ((-not $Remove) -and ($newUsers.Count -gt 20)) {
        Write-Error -Message "The change would result in $($newUsers.Count) individually assigned agents for call queue '$($callQueue.Name)'. Microsoft allows 20 individually assigned agents per call queue; assign a group to the queue for a larger team. No change was made." -ErrorAction Continue
        throw "Call queue '$($callQueue.Name)' would exceed the limit of 20 individually assigned agents."
    }

    if ($Remove -and ($newUsers.Count -eq 0) -and ($currentGroups.Count -eq 0)) {
        Write-Error -Message "The change would leave call queue '$($callQueue.Name)' without any agent. Keep at least one agent, or assign a group or team to the queue in the Teams admin center. No change was made." -ErrorAction Continue
        throw "Call queue '$($callQueue.Name)' would be left without any agent."
    }

    if ($changeCount -eq 0) {
        Write-Output "Nothing to do for call queue '$($callQueue.Name)'."
        $skipMain = $true
    }
}

#endregion

########################################################
#region     Main Part
##
########################################################

if (-not $queueManagedElsewhere) {
    $finalUsers = @($currentUsers)

    if (-not $skipMain) {
        Write-Output ""
        Write-Output "Update call queue"
        Write-Output "---------------------"

        # WarningPreference temporarily set to "SilentlyContinue" to suppress the "ConferenceMode is turned on" warning
        $previousWarningPreference = $WarningPreference
        $WarningPreference = "SilentlyContinue"
        try {
            # Only the user list is bound - the cmdlet re-sends every other setting of the queue unchanged
            Set-CsCallQueue -Identity $callQueue.Identity -Users ([guid[]]$newUsers) -ErrorAction Stop | Out-Null
            Write-Output "Call queue '$($callQueue.Name)' updated."
        }
        catch {
            Write-Error -Message "Updating call queue '$($callQueue.Name)' failed: $($_.Exception.Message)" -ErrorAction Continue
            throw "Updating call queue '$($callQueue.Name)' failed."
        }
        finally {
            $WarningPreference = $previousWarningPreference
        }

        # Verify the result - the Agents list lags behind, so the Users list is compared
        $updatedQueue = $null
        $previousWarningPreference = $WarningPreference
        $WarningPreference = "SilentlyContinue"
        try {
            $updatedQueue = Get-CsCallQueue -Identity $callQueue.Identity -ErrorAction Stop
        }
        catch {
            Write-RjRbLog -Message "Reading call queue '$($callQueue.Name)' back failed: $($_.Exception.Message)" -Verbose
        }
        finally {
            $WarningPreference = $previousWarningPreference
        }

        if ($updatedQueue) {
            $finalUsers = @($updatedQueue.Users | ForEach-Object { ([string]$_).ToLower() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $missingUsers = @($newUsers | Where-Object { $finalUsers -notcontains $_ })
            $unexpectedUsers = @($finalUsers | Where-Object { $newUsers -notcontains $_ })
            if (($missingUsers.Count -gt 0) -or ($unexpectedUsers.Count -gt 0)) {
                Write-Output "WARNING: The agent list of call queue '$($callQueue.Name)' does not match the requested change. Individually assigned agents now:"
                if ($finalUsers.Count -eq 0) {
                    Write-Output " - none"
                }
                foreach ($finalUserId in $finalUsers) {
                    Write-Output " - $(Format-UserLabel -Identity $finalUserId)"
                }
            }
        }
        else {
            $finalUsers = @($newUsers)
            Write-Output "WARNING: Call queue '$($callQueue.Name)' could not be read back. Check the agent list in the Teams admin center."
        }
    }

    Write-Output ""
    Write-Output "Result"
    Write-Output "---------------------"

    foreach ($result in $results) {
        switch ($result.Outcome) {
            "Add" { Write-Output "Added: $($result.Label)" }
            "Remove" { Write-Output "Removed: $($result.Label)" }
            default { Write-Output "Skipped: $($result.Label) - $($result.Reason)" }
        }
    }

    Write-Output ""
    Write-Output "Individually assigned agents now: $($finalUsers.Count) (of 20)"
    if ($groupLabels.Count -gt 0) {
        Write-Output "Agents from $groupSource are not counted here and were not changed."
        Write-Output "A user who was just added to one of the assigned groups can take up to eight hours before the call queue offers the first call."
    }
}

#endregion

########################################################
#region     Cleanup
##
########################################################

Disconnect-MicrosoftTeams -Confirm:$false | Out-Null

if ($script:graphAvailable) {
    try {
        Disconnect-MgGraph -ErrorAction Stop | Out-Null
    }
    catch {
        Write-RjRbLog -Message "Disconnecting from Microsoft Graph failed: $($_.Exception.Message)" -Verbose
    }
}

Write-Output ""
Write-Output "Done!"

#endregion

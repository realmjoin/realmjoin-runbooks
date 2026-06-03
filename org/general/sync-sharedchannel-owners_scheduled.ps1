<#
    .SYNOPSIS
    Ensure a security group's members are owners of mapped Teams and their shared channels.

    .DESCRIPTION
    Teams shared channels do not inherit ownership from their parent team. This scheduled runbook closes
    that gap: for teams selected by display-name prefix, it ensures the members of a mapped security group
    are owners of the team and of every shared channel the team hosts. The prefix-to-owner-group mapping is
    maintained centrally as a RealmJoin org setting. The runbook is add-only - existing owners and members
    are never removed - so newly created shared channels are simply picked up on the next run. It can
    optionally email a report and/or upload the CSV results as a download link. See the accompanying
    documentation for the mapping rules and configuration.

    .PARAMETER TeamOwnerGroupMapping
    Mapping of a team display-name prefix to an owner security group object id, e.g.
    [{ "TeamNamePrefix": "PREFIX1", "OwnerGroupId": "00000000-0000-0000-0000-000000000000" }].
    Hidden parameter, bound to the org Setting "SharedChannelOwners.Mapping". The RealmJoin portal injects
    that value; the runbook accepts it either as the deserialized object/array (structured sub-settings) or
    as a JSON string and normalizes both.

    .PARAMETER IncludeTeamOwners
    When enabled (default), the owner-group members are also ensured as owners and members of the parent
    team itself (M365 group owners/members). Team membership is also the prerequisite for channel ownership.

    .PARAMETER TeamVisibility
    Restricts processing to teams of the given visibility: "Private" (includes hidden-membership teams),
    "Public", or "PrivateAndPublic" (both). Org-wide teams are not specially handled yet; since their backing
    group visibility is Public, they are only included when "Public" or "PrivateAndPublic" is selected.

    .PARAMETER WhatIfMode
    When enabled, the runbook only logs the changes it would make without writing anything.

    .PARAMETER SendEmailReport
    When enabled, a RealmJoin-branded email report is sent via Send-RjReportEmail after the run. The body
    contains run statistics and two CSV attachments (per-team summary and per-change detail).

    .PARAMETER EmailTo
    Recipient email address(es) for the report (comma-separated). Only used when SendEmailReport is enabled.

    .PARAMETER EmailFrom
    Sender mailbox for the report. Bound to the org Setting "RJReport.EmailSender".

    .PARAMETER CreateDownloadLink
    When enabled, the CSV report(s) are uploaded to a storage account and a time-limited download link is
    returned (and included in the email report if that is also enabled). Default off.

    .PARAMETER ContainerName
    Storage container used for the upload. Configured per runbook (not a global RJReport setting).

    .PARAMETER ResourceGroupName
    Resource group that contains the storage account. Bound to "RJReport.StorageAccount.ResourceGroup".

    .PARAMETER StorageAccountName
    Storage account used for the upload. Bound to "RJReport.StorageAccount.StorageAccountName".

    .PARAMETER LinkExpiryDays
    Days until the generated download link expires. Bound to "RJReport.StorageAccount.LinkExpiryDays".

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .NOTES
    Configure the mapping once centrally (Runbook Customization -> Settings) as a structured sub-setting under
    "SharedChannelOwners.Mapping". The hidden TeamOwnerGroupMapping parameter is injected from it at runtime.
    {
        "Settings": {
            "SharedChannelOwners": {
                "Mapping": [
                    { "TeamNamePrefix": "EXT", "OwnerGroupId": "11111111-1111-1111-1111-111111111111" },
                    { "TeamNamePrefix": "EXT Service", "OwnerGroupId": "22222222-2222-2222-2222-222222222222" }
                ]
            }
        }
    }

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "TeamOwnerGroupMapping": {
                "Hide": true
            },
            "IncludeTeamOwners": {
                "DisplayName": "Also make them owners of the parent team"
            },
            "TeamVisibility": {
                "DisplayName": "Apply to which team types",
                "SelectSimple": {
                    "Private only": "Private",
                    "Private + Public": "PrivateAndPublic",
                    "Public only": "Public"
                }
            },
            "WhatIfMode": {
                "DisplayName": "Dry run (log only, no changes)"
            },
            "SendEmailReport": {
                "DisplayName": "Send email report",
                "Select": {
                    "Options": [
                        {
                            "Display": "No",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": [
                                    "EmailTo"
                                ]
                            }
                        },
                        {
                            "Display": "Yes",
                            "ParameterValue": true
                        }
                    ]
                }
            },
            "EmailTo": {
                "DisplayName": "Send report to (email address(es))"
            },
            "EmailFrom": {
                "Hide": true
            },
            "CreateDownloadLink": {
                "DisplayName": "Create a download link (upload report to storage)",
                "SelectSimple": {
                    "Yes - upload report and return a download link": true,
                    "No - do not create a download link": false
                }
            },
            "ContainerName": {
                "Hide": true
            },
            "ResourceGroupName": {
                "Hide": true
            },
            "StorageAccountName": {
                "Hide": true
            },
            "LinkExpiryDays": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.6" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.37.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param(
    # Hidden, sourced from the org Setting "SharedChannelOwners.Mapping". May arrive as a structured
    # object/array (sub-settings) or as a JSON string - both are normalized below.
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "SharedChannelOwners.Mapping" } )]
    [object] $TeamOwnerGroupMapping = "[]",

    [bool] $IncludeTeamOwners = $true,

    # Which team visibilities to process. Org-wide teams are not specially handled yet.
    [ValidateSet("Private", "PrivateAndPublic", "Public")]
    [string] $TeamVisibility = "Private",

    [bool] $WhatIfMode = $false,

    # Enables the email report; when on, EmailTo becomes visible in the portal.
    [bool] $SendEmailReport = $false,

    [string] $EmailTo,

    # Sender mailbox, sourced from the org Setting "RJReport.EmailSender".
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string] $EmailFrom,

    # Enables uploading the CSV report(s) to a storage account and returning a download link.
    [bool] $CreateDownloadLink = $false,

    [string] $ContainerName = "shared-channel-owners",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     Function declaration
##
########################################################

function ConvertTo-MappingArray {
    # Normalizes the injected setting into an array of { TeamNamePrefix, OwnerGroupId } objects.
    # The RealmJoin portal may inject the setting as already-deserialized objects (structured
    # sub-settings) or as a JSON string - handle both, plus a hashtable variant.
    param(
        $Raw
    )

    if ($null -eq $Raw) {
        return @()
    }

    if ($Raw -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Raw)) {
            return @()
        }
        return @($Raw | ConvertFrom-Json)
    }

    # Already structured (PSCustomObject[], hashtable[], single object, ...)
    return @($Raw)
}

function Get-GraphPagedResult {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri
    )

    $results = @()
    $nextLink = $Uri
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink
        if ($response.value) {
            $results += $response.value
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $results
}

function Get-GroupTransitiveUser {
    param(
        [Parameter(Mandatory = $true)]
        [string] $GroupId
    )

    $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId/transitiveMembers/microsoft.graph.user`?`$select=id,displayName,userPrincipalName,userType"
    return Get-GraphPagedResult -Uri $uri
}

function Test-PrefixMatch {
    # A team name matches a prefix only at a word boundary: it must equal the prefix exactly,
    # or be the prefix followed by a space. This prevents "EXT" from matching "External Team",
    # while "EXT Service" still matches "EXT Service Customer One". Trailing spaces in the configured
    # prefix are ignored, and matching is case-insensitive (like Graph).
    param(
        [Parameter(Mandatory = $true)] [string] $DisplayName,
        [Parameter(Mandatory = $true)] [string] $Prefix
    )

    $p = $Prefix.TrimEnd()
    if ([string]::IsNullOrEmpty($p)) {
        return $false
    }
    $cmp = [System.StringComparison]::OrdinalIgnoreCase
    return $DisplayName.Equals($p, $cmp) -or $DisplayName.StartsWith($p + " ", $cmp)
}

function Get-BestMappingEntry {
    # Returns the most specific (longest-prefix) mapping entry that matches the team name at a
    # word boundary, or $null if none matches. Longest prefix wins so a team covered by both
    # "EXT" and "EXT Service" is owned only by the "EXT Service" mapping.
    param(
        [Parameter(Mandatory = $true)] [string] $DisplayName,
        [Parameter(Mandatory = $true)] [object[]] $Entries
    )

    $best = $null
    foreach ($e in $Entries) {
        if (Test-PrefixMatch -DisplayName $DisplayName -Prefix $e.Prefix) {
            if (($null -eq $best) -or ($e.Prefix.Length -gt $best.Prefix.Length)) {
                $best = $e
            }
        }
    }
    return $best
}

function Add-ChannelOwner {
    param(
        [Parameter(Mandatory = $true)] [string] $TeamId,
        [Parameter(Mandatory = $true)] [string] $ChannelId,
        [Parameter(Mandatory = $true)] [string] $UserId,
        [Parameter(Mandatory = $true)] [string] $UserUpn,
        # Hashtable: userId -> @{ MembershipId = ...; Roles = @(...) }
        [Parameter(Mandatory = $true)] [hashtable] $ExistingMembers,
        [bool] $DryRun = $false
    )

    $membersUri = "https://graph.microsoft.com/v1.0/teams/$TeamId/channels/$ChannelId/members"

    $existing = $ExistingMembers[$UserId]
    if ($existing -and ($existing.Roles -contains "owner")) {
        return "skip"
    }

    if ($existing) {
        # Already a member, promote to owner via PATCH
        if ($DryRun) {
            "##   [WhatIf] Would promote '$UserUpn' to owner"
            return "promote"
        }
        $patchUri = "$membersUri/$([uri]::EscapeDataString($existing.MembershipId))"
        $patchBody = @{
            "@odata.type" = "#microsoft.graph.aadUserConversationMember"
            roles         = @("owner")
        }
        Invoke-MgGraphRequest -Method PATCH -Uri $patchUri -Body $patchBody -ContentType "application/json" | Out-Null
        return "promote"
    }

    # Not a member yet - add directly as owner
    if ($DryRun) {
        "##   [WhatIf] Would add '$UserUpn' as owner"
        return "add"
    }

    $addBody = @{
        "@odata.type"     = "#microsoft.graph.aadUserConversationMember"
        roles             = @("owner")
        "user@odata.bind" = "https://graph.microsoft.com/v1.0/users('$UserId')"
    }
    try {
        Invoke-MgGraphRequest -Method POST -Uri $membersUri -Body $addBody -ContentType "application/json" | Out-Null
        return "add"
    }
    catch {
        # Fallback: replication lag / team-membership prerequisite. Add as plain member first, then promote.
        Write-RjRbLog -Message "Direct owner-add for '$UserUpn' failed, trying member-then-promote. Error: $_" -Verbose
        $memberBody = @{
            "@odata.type"     = "#microsoft.graph.aadUserConversationMember"
            roles             = @()
            "user@odata.bind" = "https://graph.microsoft.com/v1.0/users('$UserId')"
        }
        $created = Invoke-MgGraphRequest -Method POST -Uri $membersUri -Body $memberBody -ContentType "application/json"
        if ($created.id) {
            $patchUri = "$membersUri/$([uri]::EscapeDataString($created.id))"
            $patchBody = @{
                "@odata.type" = "#microsoft.graph.aadUserConversationMember"
                roles         = @("owner")
            }
            Invoke-MgGraphRequest -Method PATCH -Uri $patchUri -Body $patchBody -ContentType "application/json" | Out-Null
        }
        return "add"
    }
}

#endregion

########################################################
#region     RJ Log Part
##
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "IncludeTeamOwners: $IncludeTeamOwners" -Verbose
Write-RjRbLog -Message "TeamVisibility: $TeamVisibility" -Verbose
Write-RjRbLog -Message "WhatIfMode: $WhatIfMode" -Verbose
Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}
Write-RjRbLog -Message "TeamOwnerGroupMapping (raw type): $($TeamOwnerGroupMapping.GetType().Name)" -Verbose

#endregion

########################################################
#region     Connect Part
##
########################################################

Write-Output "Initiate MGGraph Session..."
try {
    $VerbosePreference = "SilentlyContinue"
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    $VerbosePreference = "Continue"
}
catch {
    Write-Error "MGGraph Connect failed - stopping script"
    throw ("Graph connection failed")
}

#endregion

########################################################
#region     Main Part
##
########################################################

# Normalize and validate the mapping (accepts structured sub-settings or a JSON string)
try {
    $mapping = ConvertTo-MappingArray -Raw $TeamOwnerGroupMapping
}
catch {
    "## Invalid SharedChannelOwners.Mapping setting - expected an array of { TeamNamePrefix, OwnerGroupId }."
    "## See this runbook's source (.EXAMPLE) for the expected format."
    throw ("Invalid mapping")
}

if (-not $mapping -or $mapping.Count -eq 0) {
    "## No mapping configured. Set the org Setting 'SharedChannelOwners.Mapping'."
    "## See this runbook's source (.EXAMPLE) for the expected format."
    throw ("Empty mapping")
}

if ($WhatIfMode) {
    "## WhatIf mode is ON - no changes will be written."
    ""
}

$mode = if ($WhatIfMode) { "WhatIf" } else { "Live" }

# Validate report configuration early (fail fast before doing the work)
if ($SendEmailReport) {
    if (-not $EmailTo) {
        "## SendEmailReport is enabled but no EmailTo was provided."
        throw ("EmailTo missing")
    }
    if (-not $EmailFrom) {
        "## SendEmailReport is enabled but no sender is configured (org Setting 'RJReport.EmailSender')."
        throw ("EmailFrom missing")
    }
}
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    "## CreateDownloadLink is enabled but no target storage account is configured."
    "## Configure the RJReport.StorageAccount.* settings or pass ResourceGroupName and StorageAccountName."
    throw ("Storage account configuration missing")
}

# Build normalized mapping entries (trimmed prefixes), skipping invalid ones
$mappingEntries = @()
foreach ($entry in $mapping) {
    $prefix = ([string]$entry.TeamNamePrefix).TrimEnd()
    $ownerGroupId = [string]$entry.OwnerGroupId
    if (-not $prefix -or -not $ownerGroupId) {
        "## Skipping invalid mapping entry (missing TeamNamePrefix or OwnerGroupId)."
        continue
    }
    $mappingEntries += [PSCustomObject]@{ Prefix = $prefix; OwnerGroupId = $ownerGroupId }
}

if ($mappingEntries.Count -eq 0) {
    "## No valid mapping entries."
    throw ("No valid mapping entries")
}

"## Configured mappings (most specific prefix wins per team):"
foreach ($me in $mappingEntries) {
    "##   '$($me.Prefix)' -> owner group '$($me.OwnerGroupId)'"
}

# Which group visibilities to process (HiddenMembership counts as private)
$allowedVisibilities = switch ($TeamVisibility) {
    "Public" { @("Public") }
    "PrivateAndPublic" { @("Private", "HiddenMembership", "Public") }
    default { @("Private", "HiddenMembership") }
}
"## Processing teams with visibility: $($allowedVisibilities -join ', ')"
""

# Collect candidate teams across all prefixes (deduplicated by id). Graph startswith is broad; the
# word-boundary check (Test-PrefixMatch) is applied afterwards when resolving the best mapping.
$teamsById = @{}
foreach ($me in $mappingEntries) {
    $filter = "startswith(displayName,'$($me.Prefix.Replace("'", "''"))')"
    $groupsUri = "https://graph.microsoft.com/v1.0/groups`?`$filter=$([uri]::EscapeDataString($filter))&`$select=id,displayName,resourceProvisioningOptions,visibility"
    foreach ($g in @(Get-GraphPagedResult -Uri $groupsUri | Where-Object { $_.resourceProvisioningOptions -contains "Team" -and $allowedVisibilities -contains $_.visibility })) {
        $teamsById[$g.id] = $g
    }
}

# In WhatIf mode, show up-front which teams would be processed (and which were found but skipped)
if ($WhatIfMode) {
    "## Teams that WOULD be processed (visibility '$TeamVisibility'):"
    $wouldProcess = $false
    $skippedAtBoundary = @()
    foreach ($team in ($teamsById.Values | Sort-Object displayName)) {
        $best = Get-BestMappingEntry -DisplayName $team.displayName -Entries $mappingEntries
        if ($null -ne $best) {
            $wouldProcess = $true
            "##   - '$($team.displayName)' [visibility: $($team.visibility)] -> mapping '$($best.Prefix)' / owner group '$($best.OwnerGroupId)'"
        }
        else {
            $skippedAtBoundary += $team.displayName
        }
    }
    if (-not $wouldProcess) {
        "##   (none)"
    }
    if ($skippedAtBoundary.Count -gt 0) {
        "## Found by prefix search but skipped (no word-boundary match):"
        foreach ($name in ($skippedAtBoundary | Sort-Object)) {
            "##   - '$name'"
        }
    }
    ""
}

# Aggregate counters
$totalOwnersAdded = 0
$totalPromoted = 0
$totalChannels = 0
$totalTeams = 0
$totalTeamOwnersAdded = 0
$totalTeamMembersAdded = 0

# Report data (filled regardless; only emitted when SendEmailReport is on)
$teamReportRows = @()
$actionRows = @()

# Cache resolved owner users per owner group (avoid re-querying the same group)
$ownerUsersCache = @{}

foreach ($team in $teamsById.Values) {
    $teamId = $team.id

    # Resolve this team to its single most-specific mapping (word-boundary match)
    $best = Get-BestMappingEntry -DisplayName $team.displayName -Entries $mappingEntries
    if ($null -eq $best) {
        # Returned by a broad Graph startswith but not a real boundary match (e.g. "External Team" vs "EXT")
        Write-RjRbLog -Message "Team '$($team.displayName)' did not match any prefix at a word boundary - skipping." -Verbose
        continue
    }

    "## Team '$($team.displayName)' ($teamId) -> mapping '$($best.Prefix)' / owner group '$($best.OwnerGroupId)'"
    $totalTeams++

    # Resolve desired owners (transitive users of the owner group), excluding guests; cached per group
    if (-not $ownerUsersCache.ContainsKey($best.OwnerGroupId)) {
        $ownerUsersCache[$best.OwnerGroupId] = @(Get-GroupTransitiveUser -GroupId $best.OwnerGroupId | Where-Object { $_.userType -ne "Guest" })
        Write-RjRbLog -Message "Resolved $($ownerUsersCache[$best.OwnerGroupId].Count) owner user(s) for group '$($best.OwnerGroupId)'." -Verbose
    }
    $ownerUsers = $ownerUsersCache[$best.OwnerGroupId]
    if ($ownerUsers.Count -eq 0) {
        "##   Owner group '$($best.OwnerGroupId)' has no (non-guest) user members - skipping team."
        $teamReportRows += [PSCustomObject]@{
            Team                  = $team.displayName
            TeamId                = $teamId
            Visibility            = $team.visibility
            MatchedPrefix         = $best.Prefix
            OwnerGroupId          = $best.OwnerGroupId
            OwnerUserCount        = 0
            SharedChannels        = 0
            TeamMembersAdded      = 0
            TeamOwnersAdded       = 0
            ChannelOwnersAdded    = 0
            ChannelOwnersPromoted = 0
            Status                = "Skipped (owner group empty)"
            Mode                  = $mode
        }
        continue
    }

    # Per-team report counters
    $teamMembersAddedThis = 0
    $teamOwnersAddedThis = 0
    $channelOwnersAddedThis = 0
    $channelPromotedThis = 0
    $teamChannelsThis = 0

    # (Optional) ensure owner-group users are owners and members of the parent team
    if ($IncludeTeamOwners) {
        $existingOwnerIds = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$teamId/owners`?`$select=id" | ForEach-Object { $_.id })
        $existingMemberIds = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$teamId/members`?`$select=id" | ForEach-Object { $_.id })

        foreach ($u in $ownerUsers) {
            # Team membership is the prerequisite for channel ownership - ensure it first
            if ($existingMemberIds -notcontains $u.id) {
                if ($WhatIfMode) {
                    "##     [WhatIf] Would add '$($u.userPrincipalName)' as team member"
                    $teamMembersAddedThis++
                    $totalTeamMembersAdded++
                    $actionRows += [PSCustomObject]@{ Team = $team.displayName; TeamId = $teamId; Scope = "Team"; Channel = ""; UserUpn = $u.userPrincipalName; UserId = $u.id; Action = "Add member"; Mode = $mode }
                }
                else {
                    $refBody = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($u.id)" }
                    try {
                        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$teamId/members/`$ref" -Body $refBody -ContentType "application/json" | Out-Null
                        $teamMembersAddedThis++
                        $totalTeamMembersAdded++
                        $actionRows += [PSCustomObject]@{ Team = $team.displayName; TeamId = $teamId; Scope = "Team"; Channel = ""; UserUpn = $u.userPrincipalName; UserId = $u.id; Action = "Add member"; Mode = $mode }
                    }
                    catch {
                        Write-RjRbLog -Message "Could not add '$($u.userPrincipalName)' as team member: $_" -Verbose
                    }
                }
            }
            if ($existingOwnerIds -notcontains $u.id) {
                if ($WhatIfMode) {
                    "##     [WhatIf] Would add '$($u.userPrincipalName)' as team owner"
                    $teamOwnersAddedThis++
                    $totalTeamOwnersAdded++
                    $actionRows += [PSCustomObject]@{ Team = $team.displayName; TeamId = $teamId; Scope = "Team"; Channel = ""; UserUpn = $u.userPrincipalName; UserId = $u.id; Action = "Add owner"; Mode = $mode }
                }
                else {
                    $refBody = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($u.id)" }
                    try {
                        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$teamId/owners/`$ref" -Body $refBody -ContentType "application/json" | Out-Null
                        $teamOwnersAddedThis++
                        $totalTeamOwnersAdded++
                        $actionRows += [PSCustomObject]@{ Team = $team.displayName; TeamId = $teamId; Scope = "Team"; Channel = ""; UserUpn = $u.userPrincipalName; UserId = $u.id; Action = "Add owner"; Mode = $mode }
                    }
                    catch {
                        Write-RjRbLog -Message "Could not add '$($u.userPrincipalName)' as team owner: $_" -Verbose
                    }
                }
            }
        }
    }

    # Hosted shared channels of this team
    $channelFilter = "membershipType eq 'shared'"
    $channelsUri = "https://graph.microsoft.com/v1.0/teams/$teamId/channels`?`$filter=$([uri]::EscapeDataString($channelFilter))"
    $sharedChannels = @(Get-GraphPagedResult -Uri $channelsUri)

    if ($sharedChannels.Count -eq 0) {
        "##     No shared channels."
    }
    else {
        foreach ($channel in $sharedChannels) {
            $channelId = $channel.id
            $totalChannels++
            $teamChannelsThis++
            "##     Shared channel '$($channel.displayName)'"

            # Index current channel members by userId
            $existingMembers = @{}
            $channelMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/teams/$teamId/channels/$channelId/members")
            foreach ($m in $channelMembers) {
                if ($m.userId) {
                    $existingMembers[$m.userId] = @{
                        MembershipId = $m.id
                        Roles        = @($m.roles)
                    }
                }
            }

            foreach ($u in $ownerUsers) {
                try {
                    $action = Add-ChannelOwner -TeamId $teamId -ChannelId $channelId -UserId $u.id -UserUpn $u.userPrincipalName -ExistingMembers $existingMembers -DryRun $WhatIfMode
                    switch ($action) {
                        "add" {
                            $totalOwnersAdded++
                            $channelOwnersAddedThis++
                            $actionRows += [PSCustomObject]@{ Team = $team.displayName; TeamId = $teamId; Scope = "Channel"; Channel = $channel.displayName; UserUpn = $u.userPrincipalName; UserId = $u.id; Action = "Add owner"; Mode = $mode }
                            if (-not $WhatIfMode) { "##       + Added owner '$($u.userPrincipalName)'" }
                        }
                        "promote" {
                            $totalPromoted++
                            $channelPromotedThis++
                            $actionRows += [PSCustomObject]@{ Team = $team.displayName; TeamId = $teamId; Scope = "Channel"; Channel = $channel.displayName; UserUpn = $u.userPrincipalName; UserId = $u.id; Action = "Promote to owner"; Mode = $mode }
                            if (-not $WhatIfMode) { "##       ~ Promoted '$($u.userPrincipalName)' to owner" }
                        }
                    }
                }
                catch {
                    "##       ! Failed to ensure owner '$($u.userPrincipalName)': $($_.Exception.Message)"
                    Write-RjRbLog -Message "Failed owner sync for '$($u.userPrincipalName)' in channel '$channelId': $_" -Verbose
                }
            }
        }
    }

    # Record per-team report row
    $teamReportRows += [PSCustomObject]@{
        Team                  = $team.displayName
        TeamId                = $teamId
        Visibility            = $team.visibility
        MatchedPrefix         = $best.Prefix
        OwnerGroupId          = $best.OwnerGroupId
        OwnerUserCount        = $ownerUsers.Count
        SharedChannels        = $teamChannelsThis
        TeamMembersAdded      = $teamMembersAddedThis
        TeamOwnersAdded       = $teamOwnersAddedThis
        ChannelOwnersAdded    = $channelOwnersAddedThis
        ChannelOwnersPromoted = $channelPromotedThis
        Status                = "Processed"
        Mode                  = $mode
    }
}

""
"## Done. Teams processed: $totalTeams | Shared channels processed: $totalChannels | Team owners added: $totalTeamOwnersAdded | Team members added: $totalTeamMembersAdded | Channel owners added: $totalOwnersAdded | Promoted to owner: $totalPromoted"
if ($WhatIfMode) {
    "## (WhatIf mode - counts reflect what WOULD have been changed.)"
}

#endregion

########################################################
#region     Report (email and/or download link)
##
########################################################

if ($SendEmailReport -or $CreateDownloadLink) {
    Write-Output ""
    Write-Output "## Preparing report..."

    # Tenant display name for the report footer/subject
    $tenantDisplayName = ""
    try {
        $org = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName"
        $tenantDisplayName = @($org.value).displayName | Select-Object -First 1
    }
    catch {
        Write-RjRbLog -Message "Could not resolve tenant display name: $_" -Verbose
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $basePath = (Get-Location).Path

    # CSV 1: per-team summary
    $teamsCsvPath = Join-Path -Path $basePath -ChildPath "${timestamp}_SharedChannelOwners_Teams.csv"
    if ($teamReportRows.Count -gt 0) {
        $teamReportRows | Sort-Object Team | Export-Csv -Path $teamsCsvPath -NoTypeInformation -Encoding UTF8
    }
    else {
        # Always produce a (header-only) file so the attachment/upload is present
        "" | Select-Object @{N = "Team"; E = { $_ } } | Where-Object { $false } | Export-Csv -Path $teamsCsvPath -NoTypeInformation -Encoding UTF8
    }

    # CSV 2: per-change detail
    $actionsCsvPath = Join-Path -Path $basePath -ChildPath "${timestamp}_SharedChannelOwners_Changes.csv"
    if ($actionRows.Count -gt 0) {
        $actionRows | Sort-Object Team, Scope, Channel, UserUpn | Export-Csv -Path $actionsCsvPath -NoTypeInformation -Encoding UTF8
    }
    else {
        "" | Select-Object @{N = "Team"; E = { $_ } } | Where-Object { $false } | Export-Csv -Path $actionsCsvPath -NoTypeInformation -Encoding UTF8
    }

    $csvFiles = @($teamsCsvPath, $actionsCsvPath)

    # Upload + download link (optional)
    $downloadLinks = @()
    if ($CreateDownloadLink) {
        Write-Output "## Uploading report to storage account..."
        # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
        # transparently connects the managed identity if no Az context is active.
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths $csvFiles `
            -ContainerName $ContainerName `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -LinkExpiryDays $LinkExpiryDays `
            -AddBlobNamePrefix $true

        foreach ($uploadResult in $uploadResults) {
            $downloadLinks += [PSCustomObject]@{
                FileName = $uploadResult.BlobName
                SASLink  = $uploadResult.SASLink
                Expiry   = $uploadResult.EndTime
            }
            Write-Output "## Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }

    # Email report (optional)
    if ($SendEmailReport) {
        Write-Output "## Preparing email report for '$EmailTo'..."

        # Per-mapping team counts for the body
        $mappingSummaryLines = foreach ($me in $mappingEntries) {
            $cnt = @($teamReportRows | Where-Object { $_.MatchedPrefix -eq $me.Prefix }).Count
            "| ``$($me.Prefix)`` | $($me.OwnerGroupId) | $cnt |"
        }

        $modeNote = if ($WhatIfMode) { "**WhatIf / dry run** - the figures below reflect changes that *would* have been made; nothing was written." } else { "Live run - the figures below reflect changes that were applied." }

        # Optional download-link section (when CreateDownloadLink produced links)
        $downloadSection = ""
        if ($downloadLinks.Count -gt 0) {
            $linkLines = foreach ($dl in $downloadLinks) {
                "- [$($dl.FileName)]($($dl.SASLink)) (expires $($dl.Expiry))"
            }
            $downloadSection = @"

## Download links

$($linkLines -join "`n")
"@
        }

        $markdownContent = @"
# Shared Channel Owner Sync

$modeNote

## Summary

| Metric | Value |
|---|---|
| Mode | $mode |
| Team visibility filter | $TeamVisibility |
| Teams processed | $totalTeams |
| Shared channels processed | $totalChannels |
| Team owners added | $totalTeamOwnersAdded |
| Team members added | $totalTeamMembersAdded |
| Channel owners added | $totalOwnersAdded |
| Channel owners promoted | $totalPromoted |

## Mappings

| Prefix | Owner group | Matched teams |
|---|---|---|
$($mappingSummaryLines -join "`n")
$downloadSection
## Attachments

- **$([IO.Path]::GetFileName($teamsCsvPath))** - one row per processed team (visibility, matched prefix, owner group, channel count, owners/members added/promoted).
- **$([IO.Path]::GetFileName($actionsCsvPath))** - one row per individual change (team/channel scope, user, action).
"@

        $emailSubject = "Shared Channel Owner Sync - $totalTeams team(s), $totalChannels channel(s)$(if ($WhatIfMode) { ' [WhatIf]' }) - $tenantDisplayName".Trim()

        Write-Output "Sending report to '$EmailTo'..."
        try {
            Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version -Attachments $csvFiles -UseNativeGraphRequest
            Write-RjRbLog -Message "Email report sent to: $EmailTo" -Verbose
            Write-Output "Email report sent to '$EmailTo'."
        }
        catch {
            Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
            throw
        }
    }
}

#endregion

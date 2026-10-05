<#
	.SYNOPSIS
	Make a group's members owners of mapped teams and shared channels

	.DESCRIPTION
	Shared channels do not inherit the owners of their team. For every team named in the mapping, the members of the mapped security group are made owners of the team and of each shared channel it hosts. It only adds, never removes; new shared channels are picked up on the next run. A dry run shows the changes without applying them. The report can be sent by email or provided as a download link.

	.PARAMETER TeamOwnerGroupMapping
	List of team names with the security group whose members become owners. Taken from the tenant setting SharedChannelOwners.Mapping.

	.PARAMETER IncludeTeamOwners
	Also makes the group members owners and members of the team itself, which is required for owning its channels.

	.PARAMETER WhatIfMode
	Only logs what would change without writing anything.

	.PARAMETER SendEmailReport
	Send the report to the recipient email address.

	.PARAMETER EmailTo
	Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

	.PARAMETER EmailFrom
	Sender address of the report email. Taken from the tenant setting RJReport.EmailSender.

	.PARAMETER BrandingHeaderImageUrl
	Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty.

	.PARAMETER BrandingFooterImageUrl
	Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty.

	.PARAMETER BrandingFooterLink
	Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty.

	.PARAMETER BrandingAccentColor
	Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid.

	.PARAMETER BrandingTextColor
	Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid.

	.PARAMETER ReportFileFormat
	Deliver the report as CSV, as an Excel workbook, or both.

	.PARAMETER CreateDownloadLink
	Also upload the report and return a download link that expires after a few days.

	.PARAMETER ContainerName
	Storage container the report files are uploaded to. Set per runbook.

	.PARAMETER ResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup.

	.PARAMETER StorageAccountName
	Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName.

	.PARAMETER LinkExpiryDays
	Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"TeamOwnerGroupMapping": {
				"Hide": true
			},
			"IncludeTeamOwners": {
				"DisplayName": "Also make them team owners?"
			},
			"WhatIfMode": {
				"DisplayName": "Dry run?"
			},
			"SendEmailReport": {
				"Hide": true
			},
			"EmailTo": {
				"DisplayName": "Recipient email address(es)",
				"Hide": true
			},
			"EmailFrom": {
				"Hide": true
			},
			"BrandingHeaderImageUrl": {
				"Hide": true
			},
			"BrandingFooterImageUrl": {
				"Hide": true
			},
			"BrandingFooterLink": {
				"Hide": true
			},
			"BrandingAccentColor": {
				"Hide": true
			},
			"BrandingTextColor": {
				"Hide": true
			},
			"ReportFileFormat": {
				"DisplayName": "Report file format",
				"Hide": true,
				"Select": {
					"Options": [
						{ "Display": "CSV & XLSX", "ParameterValue": "CSV & XLSX" },
						{ "Display": "CSV only", "ParameterValue": "CSV only" },
						{ "Display": "XLSX only", "ParameterValue": "XLSX only" }
					],
					"ShowValue": false
				}
			},
			"CreateDownloadLink": {
				"Hide": true
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
		},
		"ParameterList": [
			{
				"DisplayName": "Report delivery",
				"DisplayAfter": "WhatIfMode",
				"Select": {
					"Options": [
						{
							"Display": "Output Data only",
							"ParameterValue": "Output Data only",
							"Customization": {
								"Default": { "SendEmailReport": false, "CreateDownloadLink": false },
								"Hide": [ "EmailTo", "ReportFileFormat" ]
							}
						},
						{
							"Display": "Also email the report",
							"ParameterValue": "Also email the report",
							"Customization": {
								"Default": { "SendEmailReport": true, "CreateDownloadLink": false },
								"Show": [ "EmailTo", "ReportFileFormat" ],
								"Mandatory": [ "EmailTo" ]
							}
						},
						{
							"Display": "Also create a download link",
							"ParameterValue": "Also create a download link",
							"Customization": {
								"Default": { "SendEmailReport": false, "CreateDownloadLink": true },
								"Show": [ "ReportFileFormat" ],
								"Hide": [ "EmailTo" ]
							}
						},
						{
							"Display": "Also email & download link",
							"ParameterValue": "Also email & download link",
							"Customization": {
								"Default": { "SendEmailReport": true, "CreateDownloadLink": true },
								"Show": [ "EmailTo", "ReportFileFormat" ],
								"Mandatory": [ "EmailTo" ]
							}
						}
					]
				},
				"Default": "Output Data only"
			}
		]
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    # Hidden, sourced from the org Setting "SharedChannelOwners.Mapping". May arrive as a structured
    # object/array (sub-settings) or as a JSON string - both are normalized below.
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "SharedChannelOwners.Mapping" } )]
    [object] $TeamOwnerGroupMapping = "[]",

    [bool] $IncludeTeamOwners = $true,

    [bool] $WhatIfMode = $false,

    # Enables the email report. Hidden in the portal; set via the "Report delivery" dropdown.
    [bool] $SendEmailReport = $false,

    [string] $EmailTo,

    # Sender mailbox, sourced from the org Setting "RJReport.EmailSender".
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string] $EmailFrom,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" } )]
    [string] $BrandingHeaderImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" } )]
    [string] $BrandingFooterImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" } )]
    [string] $BrandingFooterLink,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" } )]
    [string] $BrandingAccentColor,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" } )]
    [string] $BrandingTextColor,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'CSV & XLSX',

    # Enables uploading the report file(s) to a storage account and returning a download link.
    # Hidden in the portal; set via the "Report delivery" dropdown.
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
#region     Function Definitions
########################################################

function ConvertTo-MappingArray {
    # Normalizes the injected setting into an array of { TeamName, OwnerGroupId } objects.
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
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response. Logs progress for slow or
        large pulls and surfaces Graph errors with the failing URI for easier troubleshooting.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/healthOverviews".

        .EXAMPLE
        PS C:\> $allIssues = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/issues"
    #>
    param(
        [string]$Uri
    )

    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    $pageCount = 0

    do {
        try {
            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to retrieve paged data from '$nextLink': $($_.Exception.Message)" -ErrorAction Continue
            throw
        }

        $pageCount++
        if ($response.value) {
            $allResults.AddRange([object[]]$response.value)
        }

        if ($pageCount % 5 -eq 0) {
            Write-RjRbLog -Message "Pagination progress: $pageCount pages, $($allResults.Count) items retrieved so far" -Verbose
        }

        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    if ($pageCount -gt 1) {
        Write-RjRbLog -Message "Pagination complete: $pageCount pages, $($allResults.Count) total items" -Verbose
    }

    return $allResults.ToArray()
}

function Get-GroupTransitiveUser {
    param(
        [Parameter(Mandatory = $true)]
        [string] $GroupId
    )

    $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId/transitiveMembers/microsoft.graph.user`?`$select=id,displayName,userPrincipalName,userType"
    return Get-GraphPagedResult -Uri $uri
}

function Add-ChannelOwner {
    # Ensures one user is owner of one shared channel. Returns "skip" (already owner), "promote" or "add";
    # with DryRun nothing is written and the action that would be taken is returned.
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

#endregion Function Definitions

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.4.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "IncludeTeamOwners: $IncludeTeamOwners" -Verbose
Write-RjRbLog -Message "WhatIfMode: $WhatIfMode" -Verbose
Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}
Write-RjRbLog -Message "TeamOwnerGroupMapping (raw type): $($TeamOwnerGroupMapping.GetType().Name)" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

# SendEmailReport already existed before the current "Report delivery" labels, so every schedule passes
# it explicitly and no fallback on the recipient is needed.
$sendEmail = $SendEmailReport

# Email delivery needs a recipient
if ($sendEmail -and -not $EmailTo) {
    Write-Error "Email delivery is selected but no recipient email address was provided." -ErrorAction Continue
    throw "Missing recipient email address (EmailTo)"
}

# A configured sender address is required before any mail can be sent
if ($sendEmail -and -not $EmailFrom) {
    Write-Error "The sender email address is missing. Configure the tenant setting RJReport.EmailSender in the runbook customization (https://docs.realmjoin.com/automation/runbooks/runbook-report-settings)." -ErrorAction Continue
    throw "Missing email sender configuration (RJReport.EmailSender)"
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Error "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* tenant settings in the runbook customization (https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) or pass ResourceGroupName and StorageAccountName when starting the runbook." -ErrorAction Continue
    throw "Missing storage account configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)"
}

# Normalize and validate the mapping (accepts structured sub-settings or a JSON string)
try {
    $mapping = @(ConvertTo-MappingArray -Raw $TeamOwnerGroupMapping)
}
catch {
    Write-Error "The setting SharedChannelOwners.Mapping is invalid - expected an array of { TeamName, OwnerGroupId }. See the runbook documentation for the expected format. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw "Invalid mapping"
}

if ($mapping.Count -eq 0) {
    Write-Error "No mapping is configured. Set the org setting SharedChannelOwners.Mapping; the runbook documentation shows the expected format." -ErrorAction Continue
    throw "Empty mapping"
}

# Rows for the Output Data tables and the console summary
$skippedRows = [System.Collections.Generic.List[object]]::new()
$alreadyCorrectRows = [System.Collections.Generic.List[object]]::new()

# Build normalized mapping entries (trimmed team names), skipping invalid ones
$mappingEntries = @()
foreach ($entry in $mapping) {
    $teamName = ([string]$entry.TeamName).Trim()
    $ownerGroupId = [string]$entry.OwnerGroupId
    if (-not $teamName -or -not $ownerGroupId) {
        Write-Output "WARNING: Skipping an invalid mapping entry (missing TeamName or OwnerGroupId)."
        $skippedRows.Add([PSCustomObject]@{ Team = $teamName; Channel = ""; User = ""; Reason = "Invalid mapping entry (missing TeamName or OwnerGroupId)" })
        continue
    }
    $mappingEntries += [PSCustomObject]@{ TeamName = $teamName; OwnerGroupId = $ownerGroupId }
}

if ($mappingEntries.Count -eq 0) {
    Write-Error "The setting SharedChannelOwners.Mapping contains no valid entry (each entry needs TeamName and OwnerGroupId)." -ErrorAction Continue
    throw "No valid mapping entries"
}

$mode = if ($WhatIfMode) { "WhatIf" } else { "Live" }
if ($WhatIfMode) {
    Write-Output "Dry run: no changes will be written."
}
Write-Output "Parameter validation passed."

#endregion Parameter Validation

########################################################
#region     Connect Part
########################################################

Write-Output ""
Write-Output "Connecting to Microsoft Graph..."
try {
    $VerbosePreference = "SilentlyContinue"
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    $VerbosePreference = "Continue"
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity is configured correctly. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw "Graph connection failed"
}

# Tenant display name for the email subject (needs Organization.Read.All, which is granted for the email report)
$tenantDisplayName = ""
if ($sendEmail) {
    try {
        $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
        if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
            $tenantDisplayName = $organizationResponse.value[0].displayName
        }
    }
    catch {
        Write-RjRbLog -Message "Could not resolve tenant display name: $($_.Exception.Message)" -Verbose
    }
}

#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

# Resolve the owner group names once, so the output shows names next to the configured object IDs
$ownerGroupNames = @{}
# Owner groups that cannot be used (deleted or unreadable); their teams are skipped instead of ending the run
$ownerGroupErrors = @{}
foreach ($ownerGroupId in @($mappingEntries | ForEach-Object { $_.OwnerGroupId } | Sort-Object -Unique)) {
    $ownerGroupNames[$ownerGroupId] = $ownerGroupId
    try {
        $ownerGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$([uri]::EscapeDataString($ownerGroupId))?`$select=id,displayName" -Method GET -ErrorAction Stop
        if ($ownerGroup.displayName) {
            $ownerGroupNames[$ownerGroupId] = "$($ownerGroup.displayName) ($ownerGroupId)"
        }
    }
    catch {
        $errorText = "$($_.Exception.Message)"
        Write-RjRbLog -Message "Could not resolve the display name of owner group '$ownerGroupId': $errorText" -Verbose
        if ($errorText -match 'NotFound|404|does not exist') {
            $ownerGroupErrors[$ownerGroupId] = "Owner group '$ownerGroupId' not found"
            Write-Output "WARNING: Owner group '$ownerGroupId' does not exist - the teams mapped to it are skipped."
        }
    }
}

Write-Output "Configured mappings (exact team name -> owner group):"
foreach ($me in $mappingEntries) {
    Write-Output "  '$($me.TeamName)' -> owner group '$($ownerGroupNames[$me.OwnerGroupId])'"
}

# Resolve each mapping entry to the team(s) with that exact display name. (displayName is not guaranteed
# unique, so a name may resolve to 0, 1 or more teams.)
$resolvedMappings = @()
foreach ($me in $mappingEntries) {
    $filter = "displayName eq '$($me.TeamName.Replace("'", "''"))'"
    $groupsUri = "https://graph.microsoft.com/v1.0/groups`?`$filter=$([uri]::EscapeDataString($filter))&`$select=id,displayName,resourceProvisioningOptions,visibility"
    $teams = @(Get-GraphPagedResult -Uri $groupsUri | Where-Object { $_.resourceProvisioningOptions -contains "Team" })
    $resolvedMappings += [PSCustomObject]@{ Entry = $me; Teams = $teams }
}

# Show up front which teams will be processed and which configured names were not found
Write-Output ""
Write-Output "Teams to process:"
$hasTeamsToProcess = $false
foreach ($r in $resolvedMappings) {
    foreach ($team in ($r.Teams | Sort-Object displayName)) {
        $hasTeamsToProcess = $true
        Write-Output "  - '$($team.displayName)' [visibility: $($team.visibility)] -> owner group '$($ownerGroupNames[$r.Entry.OwnerGroupId])'"
    }
}
if (-not $hasTeamsToProcess) {
    Write-Output "  (none)"
}
$notFoundNames = @($resolvedMappings | Where-Object { $_.Teams.Count -eq 0 } | ForEach-Object { $_.Entry.TeamName })
if ($notFoundNames.Count -gt 0) {
    Write-Output "Configured team names not found:"
    foreach ($name in ($notFoundNames | Sort-Object)) {
        Write-Output "  - '$name'"
    }
}

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Sync Owners"
Write-Output "---------------------"
if ($WhatIfMode) {
    Write-Output "Dry run - the changes below are not written."
}

# Aggregate counters
$totalOwnersAdded = 0
$totalPromoted = 0
$totalChannels = 0
$totalTeams = 0
$totalTeamOwnersAdded = 0
$totalTeamMembersAdded = 0

# Report data: one row per team for the report files, one row per change for the files and the Output Data
$teamReportRows = @()
$actionRows = @()

# Cache resolved owner users and guests per owner group (avoid re-querying the same group)
$ownerUsersCache = @{}
$guestUsersCache = @{}

# Flatten resolved mappings to (team, owner-group) pairs; record configured names that matched no team
$teamsToProcess = @()
foreach ($r in $resolvedMappings) {
    if ($r.Teams.Count -eq 0) {
        $teamReportRows += [PSCustomObject]@{
            Team                  = $r.Entry.TeamName
            TeamId                = ""
            Visibility            = ""
            MatchedTeamName       = $r.Entry.TeamName
            OwnerGroup            = $ownerGroupNames[$r.Entry.OwnerGroupId]
            OwnerGroupId          = $r.Entry.OwnerGroupId
            OwnerUserCount        = 0
            SharedChannels        = 0
            TeamMembersAdded      = 0
            TeamOwnersAdded       = 0
            ChannelOwnersAdded    = 0
            ChannelOwnersPromoted = 0
            Status                = "Team not found"
            Mode                  = $mode
        }
        $skippedRows.Add([PSCustomObject]@{ Team = $r.Entry.TeamName; Channel = ""; User = ""; Reason = "Team not found" })
        continue
    }
    foreach ($team in $r.Teams) {
        $teamsToProcess += [PSCustomObject]@{ Team = $team; Entry = $r.Entry }
    }
}

foreach ($item in $teamsToProcess) {
    $team = $item.Team
    $me = $item.Entry
    $teamId = $team.id
    $ownerGroupLabel = $ownerGroupNames[$me.OwnerGroupId]

    Write-Output ""
    Write-Output "Team '$($team.displayName)' -> owner group '$ownerGroupLabel'"
    $totalTeams++

    # Resolve desired owners (transitive users of the owner group), excluding guests; cached per group.
    # A deleted or unreadable owner group skips its teams instead of ending the whole run.
    if (-not $ownerUsersCache.ContainsKey($me.OwnerGroupId) -and -not $ownerGroupErrors.ContainsKey($me.OwnerGroupId)) {
        try {
            $groupUsers = @(Get-GroupTransitiveUser -GroupId $me.OwnerGroupId)
            $ownerUsersCache[$me.OwnerGroupId] = @($groupUsers | Where-Object { $_.userType -ne "Guest" })
            $guestUsersCache[$me.OwnerGroupId] = @($groupUsers | Where-Object { $_.userType -eq "Guest" })
            Write-RjRbLog -Message "Resolved $($ownerUsersCache[$me.OwnerGroupId].Count) owner user(s) for group '$ownerGroupLabel'." -Verbose
        }
        catch {
            $errorText = "$($_.Exception.Message)"
            $ownerGroupErrors[$me.OwnerGroupId] = if ($errorText -match 'NotFound|404|does not exist') { "Owner group '$ownerGroupLabel' not found" } else { "Owner group '$ownerGroupLabel' could not be read: $errorText" }
            Write-RjRbLog -Message "Reading the members of owner group '$ownerGroupLabel' failed: $errorText" -Verbose
        }
    }
    if ($ownerGroupErrors.ContainsKey($me.OwnerGroupId)) {
        Write-Output "  WARNING: $($ownerGroupErrors[$me.OwnerGroupId]) - skipping the team."
        $teamReportRows += [PSCustomObject]@{
            Team                  = $team.displayName
            TeamId                = $teamId
            Visibility            = $team.visibility
            MatchedTeamName       = $me.TeamName
            OwnerGroup            = $ownerGroupLabel
            OwnerGroupId          = $me.OwnerGroupId
            OwnerUserCount        = 0
            SharedChannels        = 0
            TeamMembersAdded      = 0
            TeamOwnersAdded       = 0
            ChannelOwnersAdded    = 0
            ChannelOwnersPromoted = 0
            Status                = "Skipped (owner group not readable)"
            Mode                  = $mode
        }
        $skippedRows.Add([PSCustomObject]@{ Team = $team.displayName; Channel = ""; User = ""; Reason = $ownerGroupErrors[$me.OwnerGroupId] })
        continue
    }
    $ownerUsers = $ownerUsersCache[$me.OwnerGroupId]
    foreach ($guest in $guestUsersCache[$me.OwnerGroupId]) {
        $skippedRows.Add([PSCustomObject]@{ Team = $team.displayName; Channel = ""; User = $guest.userPrincipalName; Reason = "Guest user, skipped (guests cannot belong to a shared channel)" })
    }

    if ($ownerUsers.Count -eq 0) {
        Write-Output "  Owner group has no (non-guest) user members - skipping the team."
        $teamReportRows += [PSCustomObject]@{
            Team                  = $team.displayName
            TeamId                = $teamId
            Visibility            = $team.visibility
            MatchedTeamName       = $me.TeamName
            OwnerGroup            = $ownerGroupLabel
            OwnerGroupId          = $me.OwnerGroupId
            OwnerUserCount        = 0
            SharedChannels        = 0
            TeamMembersAdded      = 0
            TeamOwnersAdded       = 0
            ChannelOwnersAdded    = 0
            ChannelOwnersPromoted = 0
            Status                = "Skipped (owner group empty)"
            Mode                  = $mode
        }
        $skippedRows.Add([PSCustomObject]@{ Team = $team.displayName; Channel = ""; User = ""; Reason = "Owner group '$ownerGroupLabel' has no (non-guest) user members" })
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
            if (($existingMemberIds -contains $u.id) -and ($existingOwnerIds -contains $u.id)) {
                $alreadyCorrectRows.Add([PSCustomObject]@{ Team = $team.displayName; Scope = "Team"; Channel = ""; User = $u.userPrincipalName; Status = "Already team owner and member" })
                continue
            }

            # Team membership is the prerequisite for channel ownership - ensure it first
            if ($existingMemberIds -notcontains $u.id) {
                if ($WhatIfMode) {
                    Write-Output "  [WhatIf] Would add '$($u.userPrincipalName)' as team member"
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
                        Write-Output "  + Added '$($u.userPrincipalName)' as team member"
                    }
                    catch {
                        Write-Output "  WARNING: Could not add '$($u.userPrincipalName)' as team member: $($_.Exception.Message)"
                        Write-RjRbLog -Message "Could not add '$($u.userPrincipalName)' as team member: $_" -Verbose
                        $skippedRows.Add([PSCustomObject]@{ Team = $team.displayName; Channel = ""; User = $u.userPrincipalName; Reason = "Could not add as team member: $($_.Exception.Message)" })
                    }
                }
            }
            if ($existingOwnerIds -notcontains $u.id) {
                if ($WhatIfMode) {
                    Write-Output "  [WhatIf] Would add '$($u.userPrincipalName)' as team owner"
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
                        Write-Output "  + Added '$($u.userPrincipalName)' as team owner"
                    }
                    catch {
                        Write-Output "  WARNING: Could not add '$($u.userPrincipalName)' as team owner: $($_.Exception.Message)"
                        Write-RjRbLog -Message "Could not add '$($u.userPrincipalName)' as team owner: $_" -Verbose
                        $skippedRows.Add([PSCustomObject]@{ Team = $team.displayName; Channel = ""; User = $u.userPrincipalName; Reason = "Could not add as team owner: $($_.Exception.Message)" })
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
        Write-Output "  No shared channels."
    }
    else {
        foreach ($channel in $sharedChannels) {
            $channelId = $channel.id
            $totalChannels++
            $teamChannelsThis++
            Write-Output "  Shared channel '$($channel.displayName)'"

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
                            if ($WhatIfMode) { Write-Output "    [WhatIf] Would add '$($u.userPrincipalName)' as owner" }
                            else { Write-Output "    + Added owner '$($u.userPrincipalName)'" }
                        }
                        "promote" {
                            $totalPromoted++
                            $channelPromotedThis++
                            $actionRows += [PSCustomObject]@{ Team = $team.displayName; TeamId = $teamId; Scope = "Channel"; Channel = $channel.displayName; UserUpn = $u.userPrincipalName; UserId = $u.id; Action = "Promote to owner"; Mode = $mode }
                            if ($WhatIfMode) { Write-Output "    [WhatIf] Would promote '$($u.userPrincipalName)' to owner" }
                            else { Write-Output "    ~ Promoted '$($u.userPrincipalName)' to owner" }
                        }
                        "skip" {
                            $alreadyCorrectRows.Add([PSCustomObject]@{ Team = $team.displayName; Scope = "Channel"; Channel = $channel.displayName; User = $u.userPrincipalName; Status = "Already channel owner" })
                        }
                    }
                }
                catch {
                    Write-Output "    WARNING: Could not make '$($u.userPrincipalName)' an owner: $($_.Exception.Message)"
                    Write-RjRbLog -Message "Failed owner sync for '$($u.userPrincipalName)' in channel '$($channel.displayName)': $_" -Verbose
                    $skippedRows.Add([PSCustomObject]@{ Team = $team.displayName; Channel = $channel.displayName; User = $u.userPrincipalName; Reason = "Could not make channel owner: $($_.Exception.Message)" })
                }
            }
        }
    }

    # Record per-team report row
    $teamReportRows += [PSCustomObject]@{
        Team                  = $team.displayName
        TeamId                = $teamId
        Visibility            = $team.visibility
        MatchedTeamName       = $me.TeamName
        OwnerGroup            = $ownerGroupLabel
        OwnerGroupId          = $me.OwnerGroupId
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

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Teams processed: $totalTeams"
Write-Output "Shared channels processed: $totalChannels"
Write-Output "Team members added: $totalTeamMembersAdded"
Write-Output "Team owners added: $totalTeamOwnersAdded"
Write-Output "Channel owners added: $totalOwnersAdded"
Write-Output "Promoted to channel owner: $totalPromoted"
Write-Output "Already correct: $($alreadyCorrectRows.Count)"
Write-Output "Skipped: $($skippedRows.Count)"
if ($WhatIfMode) {
    Write-Output "Dry run - the counts show what would have been changed."
}

#endregion Main Part

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$xlsxPath = $null
$tempDir = $null
$teamsCsvPath = $null
$actionsCsvPath = $null

# Sort once so the Output Data tables, the CSV and the XLSX exports use identical data
$teamReportRows = @($teamReportRows | Sort-Object Team)
$actionRows = @($actionRows | Sort-Object Team, Scope, Channel, UserUpn)

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if ($sendEmail -or $CreateDownloadLink) {
    Write-Output ""
    Write-Output "## Preparing report..."

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "SharedChannelOwners_$timestamp"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    if ($ReportFileFormat -ne 'XLSX only') {
        # CSV 1: per-team summary
        $teamsCsvPath = Join-Path -Path $tempDir -ChildPath "${timestamp}_SharedChannelOwners_Teams.csv"
        if ($teamReportRows.Count -gt 0) {
            $teamReportRows | Export-Csv -Path $teamsCsvPath -NoTypeInformation -Encoding UTF8
        }
        else {
            # Always produce a (header-only) file so the attachment/upload is present
            "" | Select-Object @{N = "Team"; E = { $_ } } | Where-Object { $false } | Export-Csv -Path $teamsCsvPath -NoTypeInformation -Encoding UTF8
        }
        $reportFiles += $teamsCsvPath

        # CSV 2: per-change detail
        $actionsCsvPath = Join-Path -Path $tempDir -ChildPath "${timestamp}_SharedChannelOwners_Changes.csv"
        if ($actionRows.Count -gt 0) {
            $actionRows | Export-Csv -Path $actionsCsvPath -NoTypeInformation -Encoding UTF8
        }
        else {
            "" | Select-Object @{N = "Team"; E = { $_ } } | Where-Object { $false } | Export-Csv -Path $actionsCsvPath -NoTypeInformation -Encoding UTF8
        }
        $reportFiles += $actionsCsvPath
    }

    if ($ReportFileFormat -ne 'CSV only') {
        # XLSX: both datasets in a single Excel workbook (one worksheet per dataset) with an "Info" cover sheet.
        # Export-RjRbXlsx handles empty datasets itself (writes a "No data available" sheet).
        $xlsxPath = Join-Path -Path $tempDir -ChildPath "${timestamp}_SharedChannelOwners_Report.xlsx"
        $workbookCoverSheet = [ordered]@{
            Title             = 'Shared Channel Owner Sync'
            Generated         = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version' = $Version
            Mode              = $mode
            'Team rows'       = ($teamReportRows | Measure-Object).Count
            'Change rows'     = ($actionRows | Measure-Object).Count
        }
        Export-RjRbXlsx -Worksheets ([ordered]@{ 'Teams' = $teamReportRows; 'Changes' = $actionRows }) -Path $xlsxPath -CoverSheet $workbookCoverSheet
        $reportFiles += $xlsxPath
    }

    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################

$downloadLinks = @()
if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
    Write-Output ""
    Write-Output "## Uploading the report file(s) to the storage account..."

    # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
    # transparently connects the managed identity if no Az context is active.
    try {
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths $reportFiles `
            -ContainerName $ContainerName `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -LinkExpiryDays $LinkExpiryDays `
            -AddBlobNamePrefix $true
    }
    catch {
        Write-Error "Failed to upload the report file(s) to storage account '$StorageAccountName': $($_.Exception.Message). The managed identity needs the 'Storage Account Contributor' role on the storage account." -ErrorAction Continue
        throw
    }

    foreach ($uploadResult in $uploadResults) {
        $downloadLinks += [PSCustomObject]@{
            FileName = $uploadResult.BlobName
            SASLink  = $uploadResult.SASLink
            Expiry   = $uploadResult.EndTime
        }
        Write-Output ""
        Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
        $uploadResult.SASLink | Out-String | Write-Output
    }
}

#endregion Upload / Download Link

########################################################
#region     Send Email Report
########################################################

$brandingMailParams = @{}

if (-not $sendEmail) {
    Write-RjRbLog -Message "Email delivery not selected - email report skipped" -Verbose
}
else {
    Write-Output ""
    Write-Output "## Preparing the email report for '$EmailTo'..."

    # Per-mapping team counts for the body
    $mappingSummaryLines = foreach ($me in $mappingEntries) {
        $cnt = @($teamReportRows | Where-Object { $_.MatchedTeamName -eq $me.TeamName -and $_.Status -eq "Processed" }).Count
        "| ``$($me.TeamName)`` | $($ownerGroupNames[$me.OwnerGroupId]) | $cnt |"
    }

    $modeNote = if ($WhatIfMode) { "**WhatIf / dry run** - the figures below reflect changes that *would* have been made; nothing was written." } else { "Live run - the figures below reflect changes that were applied." }

    # Optional download-link section (when the download link option produced links)
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
| Teams processed | $totalTeams |
| Shared channels processed | $totalChannels |
| Team owners added | $totalTeamOwnersAdded |
| Team members added | $totalTeamMembersAdded |
| Channel owners added | $totalOwnersAdded |
| Channel owners promoted | $totalPromoted |
| Already correct | $($alreadyCorrectRows.Count) |
| Skipped | $($skippedRows.Count) |

## Mappings

| Team name | Owner group | Teams processed |
|---|---|---|
$($mappingSummaryLines -join "`n")
$downloadSection
## Attachments

$(if ($ReportFileFormat -ne 'XLSX only') { "- **$([IO.Path]::GetFileName($teamsCsvPath))** - one row per processed team (visibility, matched team name, owner group, channel count, owners/members added/promoted)." })
$(if ($ReportFileFormat -ne 'XLSX only') { "- **$([IO.Path]::GetFileName($actionsCsvPath))** - one row per individual change (team/channel scope, user, action)." })
$(if ($ReportFileFormat -ne 'CSV only') { "- **$([IO.Path]::GetFileName($xlsxPath))** - both datasets as a formatted Excel workbook (Teams and Changes worksheets)." })

---

*This email was automatically generated. Please do not reply to this email.*
"@

    $markdownFallback = @"
# Shared Channel Owner Sync

$modeNote

## Summary

| Metric | Value |
|---|---|
| Mode | $mode |
| Teams processed | $totalTeams |
| Shared channels processed | $totalChannels |
| Team owners added | $totalTeamOwnersAdded |
| Team members added | $totalTeamMembersAdded |
| Channel owners added | $totalOwnersAdded |
| Channel owners promoted | $totalPromoted |
| Already correct | $($alreadyCorrectRows.Count) |
| Skipped | $($skippedRows.Count) |

## Attachments

- **$([IO.Path]::GetFileName($xlsxPath))** - both datasets as a formatted Excel workbook (Teams and Changes worksheets).

> **Note:** The CSV files were not attached because they exceed the email attachment size limit. The Excel workbook contains the complete data. Choose a report delivery with a download link to obtain the raw CSV files.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    $emailSubject = "Shared Channel Owner Sync - $totalTeams team(s), $totalChannels channel(s)$(if ($WhatIfMode) { ' [WhatIf]' }) - $tenantDisplayName".Trim()

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSVs are too large)
    try {
        $emailParams = @{
            EmailFrom             = $EmailFrom
            EmailTo               = $EmailTo
            Subject               = $emailSubject
            MarkdownContent       = $markdownContent
            TenantDisplayName     = $tenantDisplayName
            ReportVersion         = $Version
            UseNativeGraphRequest = $true
        }
        if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxPath -and (Test-Path -Path $xlsxPath)) {
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
        }
        else {
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles
        }
        Write-RjRbLog -Message "Email report sent to: $EmailTo" -Verbose
        Write-Output "Email report sent to '$EmailTo'."
    }
    catch {
        Write-Error "Failed to send the email report: $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
}

#endregion Send Email Report

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the progress output. Every table has its own
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
Write-Output ""

$summaryValues = [ordered]@{
    "Mapping entries"           = $mappingEntries.Count
    "Teams processed"           = $totalTeams
    "Shared channels processed" = $totalChannels
}
if ($WhatIfMode) {
    $summaryValues["Team members to add"] = $totalTeamMembersAdded
    $summaryValues["Team owners to add"] = $totalTeamOwnersAdded
    $summaryValues["Channel owners to add"] = $totalOwnersAdded
    $summaryValues["Members to promote to channel owner"] = $totalPromoted
}
else {
    $summaryValues["Team members added"] = $totalTeamMembersAdded
    $summaryValues["Team owners added"] = $totalTeamOwnersAdded
    $summaryValues["Channel owners added"] = $totalOwnersAdded
    $summaryValues["Promoted to channel owner"] = $totalPromoted
}
$summaryValues["Already correct"] = $alreadyCorrectRows.Count
$summaryValues["Skipped"] = $skippedRows.Count
$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($actionRows.Count -gt 0) {
    Write-Output "$($actionRows.Count) $(if ($WhatIfMode) { 'planned change(s), dry run' } else { 'change(s)' })"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Changes" })
    Write-Output @($actionRows | Select-Object -Property Team, Scope, Channel, @{ Name = "User"; Expression = { $_.UserUpn } }, Action, Mode)
}
else {
    Write-Output "No changes - every owner was already in place."
}

if ($skippedRows.Count -gt 0) {
    Write-Output "$($skippedRows.Count) skipped"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Skipped" })
    Write-Output @($skippedRows | Select-Object -Property Team, Channel, User, Reason)
}
else {
    Write-Output "Nothing skipped."
}

if ($alreadyCorrectRows.Count -gt 0) {
    Write-Output "$($alreadyCorrectRows.Count) owner assignment(s) already correct"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Already correct" })
    Write-Output @($alreadyCorrectRows | Select-Object -Property Team, Scope, Channel, User, Status)
}
else {
    Write-Output "No owner assignment was already in place."
}

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################

# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-RjRbLog -Message "Removed temporary export directory: $tempDir" -Verbose
}

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

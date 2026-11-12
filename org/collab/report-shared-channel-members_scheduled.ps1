<#
	.SYNOPSIS
	List shared channels of all teams with direct and indirect members

	.DESCRIPTION
	Lists the shared channels hosted by the teams of the tenant with everyone who can open them. This includes owners, guests, people from other tenants and members of teams the channel is shared with. The report covers every team or selected teams, with the members in one table, in one table per channel or for channels given by name. The report can be sent by email or provided as a download link.

	.PARAMETER ReportScope
	"All shared channels, one table" lists every member in one table. "All shared channels, one table per channel" gives each channel its own table and worksheet. "Shared channels by name, one table" reports only the named channels.

	.PARAMETER TeamIds
	Only the shared channels hosted by the selected teams are read. Leave empty to include every team of the tenant.

	.PARAMETER ChannelNames
	Names of the shared channels to report, separated by commas; upper and lower case do not matter. Without "Limit to these teams", matching channels of every team are reported.

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

	.PARAMETER SendEmailReport
	Send the report to the recipient email address.

	.PARAMETER EmailTo
	Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

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

	.PARAMETER SubscriptionId
	Subscription ID of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.SubscriptionId; the subscription the managed identity signs in to is used when empty.

	.PARAMETER LinkExpiryDays
	Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"ReportScope": {
				"DisplayName": "Channels and table layout",
				"Select": {
					"Options": [
						{
							"Display": "All shared channels, one table",
							"ParameterValue": "All shared channels, one table",
							"Customization": {
								"Hide": [ "ChannelNames" ]
							}
						},
						{
							"Display": "All shared channels, one table per channel",
							"ParameterValue": "All shared channels, one table per channel",
							"Customization": {
								"Hide": [ "ChannelNames" ]
							}
						},
						{
							"Display": "Shared channels by name, one table",
							"ParameterValue": "Shared channels by name, one table",
							"Customization": {
								"Show": [ "ChannelNames" ],
								"Mandatory": [ "ChannelNames" ]
							}
						}
					],
					"ShowValue": false
				},
				"Default": "All shared channels, one table"
			},
			"ChannelNames": {
				"DisplayName": "Shared channel names (comma-separated)"
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
			"SendEmailReport": {
				"Hide": true
			},
			"EmailTo": {
				"DisplayName": "Recipient email address(es)",
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
			"SubscriptionId": {
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
				"DisplayAfter": "ChannelNames",
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [ValidateSet('All shared channels, one table', 'All shared channels, one table per channel', 'Shared channels by name, one table')]
    [string]$ReportScope = 'All shared channels, one table',
    # Multi-select team picker; [string[]] is only supported on a Use-RJInterface Graph picker
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Limit to these teams" -Filter "resourceProvisioningOptions/any(c:c eq 'Team')" } )]
    [string[]]$TeamIds,
    [string]$ChannelNames,
    # Standard report-delivery parameter set (report-files mode)
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" } )]
    [string]$BrandingHeaderImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" } )]
    [string]$BrandingFooterImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" } )]
    [string]$BrandingFooterLink,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" } )]
    [string]$BrandingAccentColor,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" } )]
    [string]$BrandingTextColor,
    [bool]$SendEmailReport = $false,
    [string]$EmailTo,
    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',
    [bool]$CreateDownloadLink = $false,
    [string]$ContainerName = "report-shared-channel-members",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
    [string]$ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
    [string]$StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.SubscriptionId" } )]
    [string]$SubscriptionId,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,
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
Write-RjRbLog -Message "ReportScope: $ReportScope" -Verbose
Write-RjRbLog -Message "TeamIds: $($TeamIds -join ', ')" -Verbose
Write-RjRbLog -Message "ChannelNames: $ChannelNames" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
Write-RjRbLog -Message "SubscriptionId: $SubscriptionId" -Verbose
Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

# A sender address is required before any mail can be sent
if (($SendEmailReport -or $EmailTo) -and -not $EmailFrom) {
    Write-Error "The sender email address is missing. Configure the tenant setting RJReport.EmailSender in the runbook customization (https://docs.realmjoin.com/automation/runbooks/runbook-report-settings)." -ErrorAction Continue
    throw "Missing email sender configuration (RJReport.EmailSender)"
}

# Email delivery needs a recipient
if ($SendEmailReport -and -not $EmailTo) {
    Write-Error "Email delivery is selected but no recipient email address was provided." -ErrorAction Continue
    throw "Missing recipient email address (EmailTo)"
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Error "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* tenant settings in the runbook customization (https://docs.realmjoin.com/automation/runbooks/runbook-report-settings)." -ErrorAction Continue
    throw "Missing storage account configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)"
}

$selectedChannelsMode = ($ReportScope -eq 'Shared channels by name, one table')
$perChannelTables = ($ReportScope -eq 'All shared channels, one table per channel')

# The selected teams narrow every scope; the channel names only apply to 'Shared channels by name, one table'.
# The picker delivers an array; comma-separated values are accepted as well, duplicates are dropped.
$teamFilterIds = [System.Collections.Generic.List[string]]::new()
$teamIdSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($teamIdValue in @($TeamIds)) {
    foreach ($teamIdPart in "$teamIdValue" -split ',') {
        $trimmedTeamId = $teamIdPart.Trim()
        if ($trimmedTeamId -and $teamIdSet.Add($trimmedTeamId)) {
            $teamFilterIds.Add($trimmedTeamId)
        }
    }
}

# Comma-separated names; duplicates are dropped, upper and lower case do not matter
$channelNameFilters = [System.Collections.Generic.List[string]]::new()
$channelNameSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if ($selectedChannelsMode) {
    foreach ($namePart in "$ChannelNames" -split ',') {
        $trimmedName = $namePart.Trim()
        if ($trimmedName -and $channelNameSet.Add($trimmedName)) {
            $channelNameFilters.Add($trimmedName)
        }
    }
    if ($channelNameFilters.Count -eq 0) {
        Write-Error "The option 'Shared channels by name, one table' needs at least one channel name. Enter the names in 'Shared channel names (comma-separated)'." -ErrorAction Continue
        throw "Missing shared channel names"
    }
}
elseif ($ChannelNames) {
    Write-RjRbLog -Message "The channel names only apply to the option 'Shared channels by name, one table' and are ignored" -Verbose
}
$channelNameText = $channelNameFilters -join ", "

Write-Output "Channels and table layout: $ReportScope"
if ($teamFilterIds.Count -eq 0) {
    Write-Output "Teams: all teams of the tenant"
}
else {
    Write-Output "Selected teams: $($teamFilterIds.Count)"
}
if ($selectedChannelsMode) {
    Write-Output "Shared channel names: $channelNameText"
}
Write-Output "Parameter validation passed."

#endregion Parameter Validation

########################################################
#region     Function Definitions
########################################################

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

function Get-BatchCollection {
    <#
        .SYNOPSIS
        Returns all items of a collection from a Graph batch response and says whether the list is complete.

        .DESCRIPTION
        A batch response carries only the first page of a collection; the remaining pages are fetched
        with Get-GraphPagedResult. Failed requests, missing bodies and pages that cannot be read are
        never dropped silently: Status is 'Failed' (no items) or 'Incomplete' (the items read so far),
        with the reason in Reason.

        .PARAMETER Response
        A single batch response with id, status and body; $null when Graph returned no response.
    #>
    param(
        [AllowNull()]
        $Response
    )

    if ($null -eq $Response) {
        return [PSCustomObject]@{ Status = 'Failed'; Items = @(); Reason = 'No response from Microsoft Graph' }
    }
    if ($Response.status -ne 200) {
        return [PSCustomObject]@{ Status = 'Failed'; Items = @(); Reason = (Get-BatchErrorText -Response $Response) }
    }
    if ($null -eq $Response.body) {
        return [PSCustomObject]@{ Status = 'Failed'; Items = @(); Reason = 'HTTP 200 without a response body' }
    }

    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @($Response.body.value)) {
        if ($null -ne $item) { $items.Add($item) }
    }

    $nextLink = $Response.body.'@odata.nextLink'
    if ($nextLink) {
        try {
            # The error record of a failed page is dropped here: the gap is returned as 'Incomplete' and
            # reported per channel, often closed by a fallback, so it must not show up as a job error.
            foreach ($item in @(Get-GraphPagedResult -Uri $nextLink 2>$null)) {
                if ($null -ne $item) { $items.Add($item) }
            }
        }
        catch {
            return [PSCustomObject]@{ Status = 'Incomplete'; Items = $items.ToArray(); Reason = "further pages not readable after $($items.Count) item(s): $($_.Exception.Message)" }
        }
    }
    return [PSCustomObject]@{ Status = 'Complete'; Items = $items.ToArray(); Reason = '' }
}

function Get-BatchErrorText {
    <#
        .SYNOPSIS
        Builds a short reason from a failed Graph batch response.

        .PARAMETER Response
        A single batch response with status and body.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Response
    )

    $text = "HTTP $($Response.status)"
    if ($Response.body -and $Response.body.error -and $Response.body.error.message) {
        $text += ": $($Response.body.error.message)"
    }
    return $text
}

function Get-MemberKey {
    <#
        .SYNOPSIS
        Returns the key that identifies a person across the member lists of a channel.

        .PARAMETER Member
        A conversationMember object from /members or /allMembers.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Member
    )

    if ($Member.userId) { return "$($Member.userId)".ToLower() }
    if ($Member.email) { return "$($Member.email)".ToLower() }
    return "$($Member.id)"
}

function Get-ChannelTableName {
    <#
        .SYNOPSIS
        Builds a unique Output Data table and worksheet name for a channel.

        .DESCRIPTION
        Output Data table titles and worksheet names are Excel sheet names: at most 31 characters,
        none of \ / ? * [ ] : and no apostrophe at the start or end. A name that is already in use
        gets a counter such as " (2)". The returned name is added to UsedNames.

        .PARAMETER ChannelName
        Display name of the channel.

        .PARAMETER UsedNames
        Case-insensitive set of the table and worksheet names already in use.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ChannelName,
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.HashSet[string]]$UsedNames
    )

    $baseName = (($ChannelName -replace '[\\/?*\[\]:]', ' ') -replace '\s+', ' ').Trim().Trim("'").Trim()
    if (-not $baseName) { $baseName = "Channel" }
    if ($baseName.Length -gt 31) {
        $baseName = $baseName.Substring(0, 31).TrimEnd().TrimEnd("'").TrimEnd()
    }

    $candidate = $baseName
    $counter = 1
    while ($UsedNames.Contains($candidate)) {
        $counter++
        $suffix = " ($counter)"
        $stem = $baseName
        if ($stem.Length + $suffix.Length -gt 31) {
            $stem = $stem.Substring(0, 31 - $suffix.Length).TrimEnd()
        }
        $candidate = "$stem$suffix"
    }
    [void]$UsedNames.Add($candidate)
    return $candidate
}

function ConvertTo-MarkdownCell {
    <#
        .SYNOPSIS
        Makes a value safe for a cell of a Markdown table in the report email.

        .PARAMETER Value
        The cell value.
    #>
    param(
        [AllowNull()]
        $Value
    )

    return ("$Value" -replace '\|', '/' -replace '\r?\n', ' ')
}

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

Write-Output ""
Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

# The home tenant id tells members from other tenants apart.
$homeTenantId = ""
try {
    $graphContext = Get-MgContext -ErrorAction Stop
    if ($graphContext -and $graphContext.TenantId) {
        $homeTenantId = "$($graphContext.TenantId)".ToLower()
    }
}
catch {
    Write-RjRbLog -Message "The tenant id could not be read from the Graph context: $($_.Exception.Message)" -Verbose
}

# Tenant display name for the email subject, the email body, the report file names and the Organization column (needs Organization.Read.All)
Write-Output "Retrieving tenant information..."
$tenantDisplayName = "Unknown Tenant"
try {
    $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=id,displayName" -Method GET -ErrorAction Stop
    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
        if (-not $homeTenantId -and $organizationResponse.value[0].id) {
            $homeTenantId = "$($organizationResponse.value[0].id)".ToLower()
        }
    }
    Write-Output "Tenant: $tenantDisplayName"
}
catch {
    Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
}

if (-not $homeTenantId) {
    Write-RjRbLog -Message "WARNING: The tenant id could not be determined, so members from other tenants are not marked as external." -Verbose
}

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

Write-Output ""
Write-Output "Get Teams"
Write-Output "---------------------"

# Teams whose channels cannot be read, and selected groups that are no team, are reported, not fatal
$unreadableTeams = [System.Collections.Generic.List[object]]::new()

if ($teamFilterIds.Count -gt 0) {
    # Teams are selected: only these teams are read. A group without a team answers 404 here.
    $selectedTeams = [System.Collections.Generic.List[object]]::new()
    foreach ($selectedTeamId in $teamFilterIds) {
        try {
            $selectedTeam = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/teams/$([uri]::EscapeDataString($selectedTeamId))?`$select=id,displayName" -Method GET -ErrorAction Stop
        }
        catch {
            Write-RjRbLog -Message "WARNING: The selected group '$selectedTeamId' is not a team or could not be read: $($_.Exception.Message)" -Verbose
            $unreadableTeams.Add([PSCustomObject]@{
                    Team   = $selectedTeamId
                    Reason = "Selected group is not a team or not readable: $($_.Exception.Message)"
                })
            continue
        }
        $selectedTeams.Add($selectedTeam)
        Write-Output "Team: $($selectedTeam.displayName)"
    }
    if ($selectedTeams.Count -eq 0) {
        Write-Error "None of the selected groups is a readable team ($(@($unreadableTeams | ForEach-Object { "$($_.Team): $($_.Reason)" }) -join '; ')). Select the teams that host the shared channels." -ErrorAction Continue
        throw "No readable team selected"
    }
    $teams = @($selectedTeams | Sort-Object { "$($_.displayName)" })
}
else {
    # Every team of the tenant. /teams also lists old teams whose group lacks the 'Team' provisioning option,
    # which a group filter on resourceProvisioningOptions would miss.
    try {
        $teams = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/teams?`$select=id,displayName" | Where-Object { $_.id })
    }
    catch {
        Write-Error "Failed to retrieve the teams of the tenant: $($_.Exception.Message)" -ErrorAction Continue
        throw "Unable to retrieve the teams"
    }
    Write-Output "Teams in the tenant: $($teams.Count)"
}
Write-RjRbLog -Message "Teams in scope: $($teams.Count)" -Verbose
$teamScopeName = if ($teamFilterIds.Count -gt 0) { @($teams | ForEach-Object { "$($_.displayName)" }) -join ", " } else { "All teams" }

$teamsById = @{}
foreach ($team in $teams) { $teamsById["$($team.id)"] = $team }

Write-Output ""
Write-Output "Get Shared Channels"
Write-Output "---------------------"
Write-Output "Reading the shared channels of $($teams.Count) team(s). This may take a while in large tenants."

# One request per team; the team id is the request id for correlation. The channel type comes from the
# filter, not from the response: 'shared' is an evolvable enum value, so the Prefer header asks Graph to
# treat it as a regular value.
$sharedChannelFilter = [uri]::EscapeDataString("membershipType eq 'shared'")
$channelRequests = foreach ($team in $teams) {
    @{
        id      = "$($team.id)"
        method  = "GET"
        url     = "/teams/$($team.id)/channels?`$filter=$sharedChannelFilter&`$select=id,displayName,createdDateTime,isArchived"
        headers = @{ Prefer = "include-unknown-enum-members" }
    }
}

$channelRecords = [System.Collections.Generic.List[object]]::new()

if (@($channelRequests).Count -gt 0) {
    try {
        $channelResponses = @(Invoke-RjRbGraphBatch -Requests @($channelRequests) -ProgressLabel "teams" -ProgressInterval 10)
    }
    catch {
        Write-Error "Failed to read the channels through the Graph batch endpoint: $($_.Exception.Message)" -ErrorAction Continue
        throw "Unable to retrieve the shared channels"
    }

    $channelResponseById = @{}
    foreach ($response in $channelResponses) { $channelResponseById["$($response.id)"] = $response }

    # Every team is checked, so a team without a response is reported instead of being skipped silently
    foreach ($team in $teams) {
        $teamId = "$($team.id)"
        $result = Get-BatchCollection -Response $channelResponseById[$teamId]

        foreach ($channel in $result.Items) {
            $channelRecords.Add([PSCustomObject]@{
                    TeamId    = $teamId
                    Team      = "$($team.displayName)"
                    ChannelId = "$($channel.id)"
                    Channel   = "$($channel.displayName)"
                    Archived  = if ($channel.isArchived) { "Yes" } else { "No" }
                    Created   = if ($channel.createdDateTime) { ([datetime]$channel.createdDateTime).ToString("yyyy-MM-dd") } else { "" }
                })
        }

        if ($result.Status -ne 'Complete') {
            # A team that cannot be read (deleted meanwhile, license gap) is reported, not fatal.
            $reason = if ($result.Status -eq 'Incomplete') { "Channel list incomplete, $($result.Reason)" } else { $result.Reason }
            Write-RjRbLog -Message "WARNING: Shared channels of team '$($team.displayName)': $reason" -Verbose
            $unreadableTeams.Add([PSCustomObject]@{
                    Team   = "$($team.displayName)"
                    Reason = $reason
                })
        }
    }
}

Write-Output "Shared channels found: $($channelRecords.Count)"
if ($unreadableTeams.Count -gt 0) {
    Write-Output "Teams that could not be read: $($unreadableTeams.Count)"
}

$missingChannelNames = [System.Collections.Generic.List[string]]::new()
if ($selectedChannelsMode) {
    $matchingChannels = @($channelRecords | Where-Object { $channelNameSet.Contains($_.Channel.Trim()) })
    $foundNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($record in $matchingChannels) { [void]$foundNames.Add($record.Channel.Trim()) }
    foreach ($name in $channelNameFilters) {
        if (-not $foundNames.Contains($name)) { $missingChannelNames.Add($name) }
    }

    if ($matchingChannels.Count -eq 0) {
        Write-Output ""
        if ($channelRecords.Count -gt 0) {
            Write-Output "Shared channels in scope (team / channel):"
            foreach ($record in @($channelRecords | Sort-Object Team, Channel | Select-Object -First 50)) {
                Write-Output "- $($record.Team) / $($record.Channel)"
            }
            if ($channelRecords.Count -gt 50) {
                Write-Output "... and $($channelRecords.Count - 50) more"
            }
        }
        else {
            Write-Output "No shared channels found in scope."
        }
        $scopeText = if ($teamFilterIds.Count -gt 0) { "in the selected teams ($teamScopeName)" } else { "in any team" }
        $unreadableText = if ($unreadableTeams.Count -gt 0) { " $($unreadableTeams.Count) team(s) could not be read." } else { "" }
        Write-Error "No shared channel named '$channelNameText' was found $scopeText. Check the names against the list above.$unreadableText" -ErrorAction Continue
        throw "Shared channels '$channelNameText' not found"
    }
    $channelRecords = [System.Collections.Generic.List[object]]::new()
    foreach ($record in $matchingChannels) { $channelRecords.Add($record) }
    Write-Output "Shared channels matching the names: $($channelRecords.Count)"

    # Names without a match do not stop the run; they are reported in the summary and the email
    if ($missingChannelNames.Count -gt 0) {
        Write-RjRbLog -Message "WARNING: No shared channel found for: $($missingChannelNames -join ', ')" -Verbose
        Write-Output "No shared channel found for: $($missingChannelNames -join ', ')"
    }
}

# Fixed order: the index of a channel in this list is the request id of its member requests
$sharedChannels = @($channelRecords | Sort-Object Team, Channel)

Write-Output ""
Write-Output "Get Channel Members"
Write-Output "---------------------"

# Three requests per channel: direct members, all members (including members of teams the channel
# is shared with) and the teams the channel is shared with.
$memberKinds = @('members', 'allMembers', 'sharedWithTeams')
$memberRequests = for ($i = 0; $i -lt $sharedChannels.Count; $i++) {
    $record = $sharedChannels[$i]
    $channelPath = "/teams/$($record.TeamId)/channels/$([uri]::EscapeDataString($record.ChannelId))"
    foreach ($kind in $memberKinds) {
        @{
            id     = "$i|$kind"
            method = "GET"
            url    = "$channelPath/$kind"
        }
    }
}

$channelData = @{}
for ($i = 0; $i -lt $sharedChannels.Count; $i++) {
    $channelData[$i] = @{}
}

if (@($memberRequests).Count -gt 0) {
    Write-Output "Reading the members of $($sharedChannels.Count) shared channel(s)..."
    try {
        $memberResponses = @(Invoke-RjRbGraphBatch -Requests @($memberRequests) -ProgressLabel "member requests" -ProgressInterval 10)
    }
    catch {
        Write-Error "Failed to read the channel members through the Graph batch endpoint: $($_.Exception.Message)" -ErrorAction Continue
        throw "Unable to retrieve the channel members"
    }

    $memberResponseById = @{}
    foreach ($response in $memberResponses) { $memberResponseById["$($response.id)"] = $response }

    # Every request is checked, so a missing response or an unreadable page is recorded instead of
    # shortening a member list silently
    for ($i = 0; $i -lt $sharedChannels.Count; $i++) {
        foreach ($kind in $memberKinds) {
            $result = Get-BatchCollection -Response $memberResponseById["$i|$kind"]
            $channelData[$i][$kind] = $result
            if ($result.Status -ne 'Complete') {
                Write-RjRbLog -Message "WARNING: '$kind' of channel '$($sharedChannels[$i].Team) / $($sharedChannels[$i].Channel)' is $($result.Status.ToLower()): $($result.Reason)" -Verbose
            }
        }
    }
}

# Fallback for the complete member list. Graph cannot always page into the members of a team from another
# tenant (the next page answers 400), and the list can fail as a whole. The members of the affected teams
# are then read per team through sharedWithTeams/{id}/allowedMembers:
# - list cut off: the teams from other tenants, because the members of this tenant came with the first pages
# - list not readable: every team the channel is shared with, the host team included; when the channel is
#   shared with its host team, Graph lists the host team's members as members via that team
# Without a readable list of shared teams the fallback cannot run and the gap stays visible.
$fallbackRequests = [System.Collections.Generic.List[object]]::new()
$fallbackTeamByRequestId = @{}
for ($i = 0; $i -lt $sharedChannels.Count; $i++) {
    $data = $channelData[$i]
    if (-not $data.ContainsKey('allMembers') -or $data['allMembers'].Status -eq 'Complete') { continue }
    if ($data['sharedWithTeams'].Status -ne 'Complete') { continue }

    $data['fallbackUsed'] = $true
    $data['fallbackMembers'] = [System.Collections.Generic.List[object]]::new()
    $data['fallbackGaps'] = [System.Collections.Generic.List[string]]::new()
    $record = $sharedChannels[$i]
    $channelPath = "/teams/$($record.TeamId)/channels/$([uri]::EscapeDataString($record.ChannelId))"
    $j = 0
    foreach ($sharedTeam in @($data['sharedWithTeams'].Items)) {
        if (-not $sharedTeam.id) { continue }
        $sharedTeamTenantId = "$($sharedTeam.tenantId)".ToLower()
        $isOtherTenant = [bool]($homeTenantId -and $sharedTeamTenantId -and $sharedTeamTenantId -ne $homeTenantId)
        if ($data['allMembers'].Status -eq 'Incomplete' -and -not $isOtherTenant) { continue }
        $requestId = "$i|$j"
        $j++
        $fallbackTeamByRequestId[$requestId] = $sharedTeam
        $fallbackRequests.Add(@{
                id     = $requestId
                method = "GET"
                url    = "$channelPath/sharedWithTeams/$([uri]::EscapeDataString("$($sharedTeam.id)"))/allowedMembers"
            })
    }
}

if ($fallbackRequests.Count -gt 0) {
    Write-Output "Reading the members of $($fallbackRequests.Count) shared team(s) one by one, because the complete member list of some channels could not be read..."
    try {
        $fallbackResponses = @(Invoke-RjRbGraphBatch -Requests @($fallbackRequests) -ProgressLabel "shared teams" -ProgressInterval 10)
    }
    catch {
        Write-RjRbLog -Message "WARNING: The members of the shared teams could not be read: $($_.Exception.Message)" -Verbose
        $fallbackResponses = @()
    }
    $fallbackResponseById = @{}
    foreach ($response in $fallbackResponses) { $fallbackResponseById["$($response.id)"] = $response }

    foreach ($requestId in $fallbackTeamByRequestId.Keys) {
        $index = [int]("$requestId" -split '\|')[0]
        $sharedTeam = $fallbackTeamByRequestId[$requestId]
        $result = Get-BatchCollection -Response $fallbackResponseById[$requestId]
        foreach ($member in $result.Items) {
            # Keep the team the person comes through; allowedMembers carries no source link
            $channelData[$index]['fallbackMembers'].Add([PSCustomObject]@{
                    id          = $member.id
                    displayName = $member.displayName
                    userId      = $member.userId
                    email       = $member.email
                    tenantId    = $member.tenantId
                    roles       = @($member.roles)
                    rjViaTeamId = "$($sharedTeam.id)"
                })
        }
        if ($result.Status -ne 'Complete') {
            $teamLabel = if ($sharedTeam.displayName) { "$($sharedTeam.displayName)" } else { "$($sharedTeam.id)" }
            $channelData[$index]['fallbackGaps'].Add("Members via team '$teamLabel' $(if ($result.Status -eq 'Incomplete') { 'incomplete' } else { 'not readable' }) ($($result.Reason))")
            Write-RjRbLog -Message "WARNING: Members of shared team '$teamLabel' for channel '$($sharedChannels[$index].Team) / $($sharedChannels[$index].Channel)': $($result.Status.ToLower()), $($result.Reason)" -Verbose
        }
    }
}

# Organization names of the other tenants that members or shared teams belong to
$externalTenantIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if ($homeTenantId) {
    foreach ($data in $channelData.Values) {
        $tenantItems = [System.Collections.Generic.List[object]]::new()
        foreach ($kind in $memberKinds) {
            if ($data.ContainsKey($kind)) { foreach ($item in @($data[$kind].Items)) { $tenantItems.Add($item) } }
        }
        if ($data.ContainsKey('fallbackMembers')) { foreach ($item in $data['fallbackMembers']) { $tenantItems.Add($item) } }
        foreach ($item in $tenantItems) {
            $itemTenantId = "$($item.tenantId)".ToLower()
            if ($itemTenantId -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' -and $itemTenantId -ne $homeTenantId) {
                [void]$externalTenantIds.Add($itemTenantId)
            }
        }
    }
}

$tenantNames = @{}
if ($externalTenantIds.Count -gt 0) {
    Write-Output "Resolving the names of $($externalTenantIds.Count) other organization(s)..."
    $tenantRequests = foreach ($externalTenantId in $externalTenantIds) {
        @{
            id     = $externalTenantId
            method = "GET"
            url    = "/tenantRelationships/findTenantInformationByTenantId(tenantId='$externalTenantId')"
        }
    }
    try {
        $tenantResponses = @(Invoke-RjRbGraphBatch -Requests @($tenantRequests) -ProgressLabel "organizations" -ProgressInterval 10)
        $lookupFailures = 0
        foreach ($response in $tenantResponses) {
            if ($response.status -eq 200 -and $response.body.displayName) {
                $tenantNames["$($response.id)"] = "$($response.body.displayName)"
            }
            else {
                $lookupFailures++
                Write-RjRbLog -Message "Organization name of tenant '$($response.id)' not resolved: $(Get-BatchErrorText -Response $response)" -Verbose
            }
        }
        if ($lookupFailures -gt 0) {
            Write-Output "Organization names not resolved: $lookupFailures (the tenant ID is shown instead; resolving needs CrossTenantInformation.ReadBasic.All)"
        }
    }
    catch {
        Write-RjRbLog -Message "Organization names could not be resolved, the tenant IDs are shown instead: $($_.Exception.Message)" -Verbose
    }
}

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

Write-Output ""
Write-Output "Processing members"
Write-Output "---------------------"

$memberRows = [System.Collections.Generic.List[object]]::new()
$channelRows = [System.Collections.Generic.List[object]]::new()
$channelTables = [System.Collections.Generic.List[object]]::new()
$distinctPeople = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$notReadableCount = 0
$incompleteChannelCount = 0
$roleOrder = @{ Owner = 0; Member = 1; Guest = 2 }

# Table and worksheet names in use; "Info" is the cover sheet of the workbook, "History" is reserved by Excel
$usedTableNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($reservedName in @('Summary', 'Shared channels', 'Shared channel members', 'Teams not readable', 'Info', 'History')) {
    [void]$usedTableNames.Add($reservedName)
}

for ($i = 0; $i -lt $sharedChannels.Count; $i++) {
    $record = $sharedChannels[$i]
    $data = $channelData[$i]
    $notes = [System.Collections.Generic.List[string]]::new()

    # Each list is 'Complete', 'Incomplete' (some pages missing) or 'Failed'; nothing is dropped silently
    $directResult = $data['members']
    $allResult = $data['allMembers']
    $sharedWithResult = $data['sharedWithTeams']
    $directOk = ($directResult.Status -ne 'Failed')
    $allOk = ($allResult.Status -ne 'Failed')
    $directComplete = ($directResult.Status -eq 'Complete')
    $directList = @($directResult.Items)
    $allList = @($allResult.Items)
    $sharedWithList = @($sharedWithResult.Items)

    # Teams the channel is shared with, the host team included: when the channel is shared with its host
    # team, Graph lists the host team's members as members via that team. The ids map the source of
    # indirect members to a team name.
    $teamNameById = @{}
    $sharedWithNames = [System.Collections.Generic.List[string]]::new()
    foreach ($sharedTeam in $sharedWithList) {
        $sharedTeamName = if ($sharedTeam.displayName) { "$($sharedTeam.displayName)" } else { "$($sharedTeam.id)" }
        $sharedTeamTenantId = "$($sharedTeam.tenantId)".ToLower()
        if ($homeTenantId -and $sharedTeamTenantId -and $sharedTeamTenantId -ne $homeTenantId) {
            $organizationName = if ($tenantNames.ContainsKey($sharedTeamTenantId)) { $tenantNames[$sharedTeamTenantId] } else { $sharedTeamTenantId }
            $sharedTeamName = "$sharedTeamName ($organizationName)"
        }
        if ($sharedTeam.id) { $teamNameById["$($sharedTeam.id)"] = $sharedTeamName }
        $sharedWithNames.Add($(if ($sharedTeam.isHostTeam) { "$sharedTeamName (host team)" } else { $sharedTeamName }))
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    $memberListIncomplete = $false
    if (-not $directOk -and -not $allOk) {
        $notes.Add("Members not readable ($($directResult.Reason))")
        $notReadableCount++
    }
    else {
        # A broken complete list is closed when every shared team could be read on its own
        $fallbackUsed = [bool]$data['fallbackUsed']
        $fallbackMembers = @(@($data['fallbackMembers']) | Where-Object { $null -ne $_ })
        $fallbackGaps = @(@($data['fallbackGaps']) | Where-Object { $_ })
        $gapClosed = ($fallbackUsed -and $fallbackGaps.Count -eq 0)
        if (-not $allOk) {
            if ($gapClosed) {
                $notes.Add("Members via teams read per team, the complete list was not readable ($($allResult.Reason))")
            }
            else {
                $notes.Add("Members via teams not readable ($($allResult.Reason))")
                $memberListIncomplete = $true
            }
        }
        elseif ($allResult.Status -eq 'Incomplete') {
            if ($gapClosed) {
                $notes.Add("Members of teams from other organizations read per team, the complete list broke off")
            }
            else {
                $notes.Add("Member list incomplete ($($allResult.Reason))")
                $memberListIncomplete = $true
            }
        }
        foreach ($gap in $fallbackGaps) { $notes.Add($gap) }
        if (-not $directOk) {
            $notes.Add("Direct member list not readable, membership taken from the member source ($($directResult.Reason))")
        }
        elseif (-not $directComplete) {
            $notes.Add("Direct member list incomplete ($($directResult.Reason))")
            if (-not $allOk) { $memberListIncomplete = $true }
        }

        $directByKey = @{}
        foreach ($member in $directList) { $directByKey[(Get-MemberKey -Member $member)] = $member }

        # allMembers is the complete list; it can list a person once per way they reach the channel
        $sourceList = $directList
        if ($allOk) { $sourceList = $allList }
        $sourceList = @($sourceList) + $fallbackMembers
        $groups = [ordered]@{}
        foreach ($member in $sourceList) {
            $key = Get-MemberKey -Member $member
            if (-not $groups.Contains($key)) { $groups[$key] = [System.Collections.Generic.List[object]]::new() }
            $groups[$key].Add($member)
        }
        foreach ($key in $directByKey.Keys) {
            if (-not $groups.Contains($key)) {
                $groups[$key] = [System.Collections.Generic.List[object]]::new()
                $groups[$key].Add($directByKey[$key])
            }
        }

        foreach ($key in $groups.Keys) {
            $entries = $groups[$key]
            $isDirect = $directByKey.ContainsKey($key)

            # Indirect entries point to the membership in the source team (.../teams/{team-id}/members/...),
            # direct ones to the channel itself (.../channels/{channel-id}/members/...). Without a source and
            # without a complete direct list, a person is counted as direct rather than left out.
            $viaTeams = [System.Collections.Generic.List[string]]::new()
            foreach ($entry in $entries) {
                $sourceUrl = "$($entry.'@microsoft.graph.originalSourceMembershipUrl')"
                if ($entry.rjViaTeamId) {
                    # Read per shared team by the fallback above
                    $sourceTeamName = if ($teamNameById.ContainsKey("$($entry.rjViaTeamId)")) { $teamNameById["$($entry.rjViaTeamId)"] } else { "Unknown team" }
                    if (-not $viaTeams.Contains($sourceTeamName)) { $viaTeams.Add($sourceTeamName) }
                }
                elseif ($sourceUrl -match '/channels/[^/]+/members/') {
                    $isDirect = $true
                }
                elseif ($sourceUrl -match '/teams/([^/]+)/members/') {
                    $sourceTeamId = $Matches[1]
                    $sourceTeamName = if ($teamNameById.ContainsKey($sourceTeamId)) {
                        $teamNameById[$sourceTeamId]
                    }
                    elseif ($teamsById.ContainsKey($sourceTeamId)) {
                        "$($teamsById[$sourceTeamId].displayName)"
                    }
                    else {
                        "Unknown team"
                    }
                    if (-not $viaTeams.Contains($sourceTeamName)) { $viaTeams.Add($sourceTeamName) }
                }
                elseif (-not $sourceUrl -and -not $directComplete) {
                    $isDirect = $true
                }
            }
            if (-not $isDirect -and $viaTeams.Count -eq 0) { $viaTeams.Add("Not identified") }

            $roleSource = if ($isDirect -and $directByKey.ContainsKey($key)) { $directByKey[$key] } else { $entries[0] }
            $roles = @($roleSource.roles)
            $memberTenantId = "$($roleSource.tenantId)".ToLower()
            $isExternal = [bool]($homeTenantId -and $memberTenantId -and ($memberTenantId -ne $homeTenantId))
            $isGuest = $roles -contains 'guest'

            # Channel ownership exists only for direct members; people who come through a team are members
            $role = if ($isDirect -and ($roles -contains 'owner')) { 'Owner' } elseif ($isGuest) { 'Guest' } else { 'Member' }
            $userType = if ($isExternal) { 'External' } elseif ($isGuest) { 'Guest' } else { 'Internal' }
            $organization = if ($isExternal) {
                if ($tenantNames.ContainsKey($memberTenantId)) { $tenantNames[$memberTenantId] } else { $memberTenantId }
            }
            else {
                $tenantDisplayName
            }
            $membership = if ($isDirect -and $viaTeams.Count -gt 0) { 'Direct and via team' } elseif ($isDirect) { 'Direct' } else { 'Via team' }
            $memberName = if ($roleSource.displayName) { "$($roleSource.displayName)" } elseif ($roleSource.email) { "$($roleSource.email)" } elseif ($roleSource.userId) { "$($roleSource.userId)" } else { "Unknown member ($($roleSource.id))" }

            [void]$distinctPeople.Add($key)
            $rows.Add([PSCustomObject][ordered]@{
                    Team         = $record.Team
                    Channel      = $record.Channel
                    Member       = $memberName
                    Email        = "$($roleSource.email)"
                    Role         = $role
                    Membership   = $membership
                    ViaTeams     = ($viaTeams -join "; ")
                    UserType     = $userType
                    Organization = $organization
                })
        }
    }

    if ($sharedWithResult.Status -eq 'Failed') {
        $notes.Add("Shared-with teams not readable ($($sharedWithResult.Reason))")
    }
    elseif ($sharedWithResult.Status -eq 'Incomplete') {
        $notes.Add("Shared-with teams incomplete ($($sharedWithResult.Reason))")
    }
    if ($memberListIncomplete) { $incompleteChannelCount++ }

    $sortedRows = @($rows | Sort-Object @{ Expression = { $roleOrder[$_.Role] } }, Member)
    foreach ($row in $sortedRows) { $memberRows.Add($row) }

    # Each channel with members gets its own table and worksheet; the name is unique and at most 31 characters
    $channelTable = $null
    if ($perChannelTables -and $sortedRows.Count -gt 0) {
        $channelTable = [PSCustomObject]@{
            Title   = Get-ChannelTableName -ChannelName $record.Channel -UsedNames $usedTableNames
            Team    = $record.Team
            Channel = $record.Channel
            Rows    = $sortedRows
        }
        $channelTables.Add($channelTable)
    }

    $channelRow = [ordered]@{
        Team            = $record.Team
        Channel         = $record.Channel
        Members         = $sortedRows.Count
        Owners          = @($sortedRows | Where-Object { $_.Role -eq 'Owner' }).Count
        Guests          = @($sortedRows | Where-Object { $_.UserType -eq 'Guest' }).Count
        External        = @($sortedRows | Where-Object { $_.UserType -eq 'External' }).Count
        Indirect        = @($sortedRows | Where-Object { $_.Membership -eq 'Via team' }).Count
        SharedWithTeams = ($sharedWithNames -join "; ")
        Archived        = $record.Archived
        Created         = $record.Created
    }
    if ($perChannelTables) { $channelRow.Table = if ($channelTable) { $channelTable.Title } else { "" } }
    $channelRow.Note = ($notes -join "; ")
    $channelRows.Add([PSCustomObject]$channelRow)
}

$ownerCount = @($memberRows | Where-Object { $_.Role -eq 'Owner' }).Count
$guestCount = @($memberRows | Where-Object { $_.UserType -eq 'Guest' }).Count
$externalCount = @($memberRows | Where-Object { $_.UserType -eq 'External' }).Count
$indirectCount = @($memberRows | Where-Object { $_.Membership -eq 'Via team' }).Count
$noOwnerCount = @($channelRows | Where-Object { $_.Owners -eq 0 -and $_.Members -gt 0 }).Count

$summaryValues = [ordered]@{
    "Teams in scope"           = $teams.Count
    "Shared channels"          = $channelRows.Count
    "Member entries"           = $memberRows.Count
    "Distinct people"          = $distinctPeople.Count
    "Owners"                   = $ownerCount
    "Guests"                   = $guestCount
    "External members"         = $externalCount
    "Members via a team only"  = $indirectCount
    "Channels without owner"   = $noOwnerCount
    "Channels not readable"    = $notReadableCount
    "Incomplete member lists"  = $incompleteChannelCount
    "Teams not readable"       = $unreadableTeams.Count
}
if ($selectedChannelsMode) {
    $summaryValues["Channel names not found"] = $missingChannelNames.Count
}

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
foreach ($metric in $summaryValues.Keys) {
    Write-Output "$($metric): $($summaryValues[$metric])"
}
Write-RjRbLog -Message "Shared channels: $($channelRows.Count); member entries: $($memberRows.Count); external: $externalCount; via team only: $indirectCount; unreadable teams: $($unreadableTeams.Count)" -Verbose

# Gaps are never silent: name them for the requestor
if ($notReadableCount -gt 0 -or $incompleteChannelCount -gt 0 -or $unreadableTeams.Count -gt 0) {
    Write-RjRbLog -Message "WARNING: The report is incomplete: $($unreadableTeams.Count) team(s) not readable, $notReadableCount channel(s) without readable members, $incompleteChannelCount channel(s) with an incomplete member list. See the Note column of 'Shared channels' and the table 'Teams not readable'." -Verbose
}

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$csvFile = $null
$xlsxFile = $null
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "SharedChannelMembers_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$safeTenantName = $tenantDisplayName -replace '[\\/:*?"<>|]', '_'
$fileNameBase = "SharedChannelMembers_$($safeTenantName)_$(Get-Date -Format 'yyyyMMdd')"
$perChannelColumns = @('Member', 'Email', 'Role', 'Membership', 'ViaTeams', 'UserType', 'Organization')

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if (($SendEmailReport -or $CreateDownloadLink) -and $channelRows.Count -gt 0) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    # One CSV with all members in every scope; team and channel are columns
    if ($ReportFileFormat -ne 'XLSX only' -and $memberRows.Count -gt 0) {
        $csvFile = Join-Path $tempDir "$fileNameBase.csv"
        $memberRows | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvFile
        Write-RjRbLog -Message "Exported $($memberRows.Count) row(s) to CSV: $csvFile" -Verbose
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFile = Join-Path $tempDir "$fileNameBase.xlsx"
        $worksheets = [ordered]@{ 'Shared channels' = @($channelRows) }
        if ($perChannelTables) {
            foreach ($channelTable in $channelTables) {
                $worksheets[$channelTable.Title] = @($channelTable.Rows | Select-Object -Property $perChannelColumns)
            }
        }
        elseif ($memberRows.Count -gt 0) {
            $worksheets['Shared channel members'] = @($memberRows)
        }
        if ($unreadableTeams.Count -gt 0) { $worksheets['Teams not readable'] = @($unreadableTeams) }

        $workbookCoverSheet = [ordered]@{
            Title                       = 'Shared Channel Members'
            Tenant                      = $tenantDisplayName
            Generated                   = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version'           = $Version
            'Channels and table layout' = $ReportScope
            Teams                       = $teamScopeName
        }
        if ($selectedChannelsMode) {
            $workbookCoverSheet['Shared channel names'] = $channelNameText
            if ($missingChannelNames.Count -gt 0) { $workbookCoverSheet['Names not found'] = $missingChannelNames -join ", " }
        }
        foreach ($metric in $summaryValues.Keys) { $workbookCoverSheet[$metric] = $summaryValues[$metric] }

        Export-RjRbXlsx -Worksheets $worksheets -Path $xlsxFile -CoverSheet $workbookCoverSheet
        $reportFiles += $xlsxFile
        Write-RjRbLog -Message "Exported $($worksheets.Count) worksheet(s) to XLSX: $xlsxFile" -Verbose
    }

    Write-Output ""
    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
}
elseif ($channelRows.Count -eq 0) {
    Write-RjRbLog -Message "No shared channels - skipping the report file export" -Verbose
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################

if ($CreateDownloadLink) {
    Write-Output ""
    if ($reportFiles.Count -gt 0) {
        Write-Output "## Uploading the report file(s) to the storage account..."

        # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
        # transparently connects the managed identity if no Az context is active.
        try {
            $uploadResults = Publish-RjRbFilesToStorageContainer `
                -FilePaths $reportFiles `
                -ContainerName $ContainerName `
                -ResourceGroupName $ResourceGroupName `
                -StorageAccountName $StorageAccountName `
                -SubscriptionId $SubscriptionId `
                -LinkExpiryDays $LinkExpiryDays `
                -AddBlobNamePrefix $true
        }
        catch {
            Write-Error "Failed to upload the report file(s) to storage account '$StorageAccountName': $($_.Exception.Message). The managed identity needs the 'Reader and Data Access' role on the storage account." -ErrorAction Continue
            throw
        }

        foreach ($uploadResult in $uploadResults) {
            Write-Output ""
            Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }
    else {
        Write-Output "No shared channels - skipping the upload."
    }
}

#endregion Upload / Download Link

########################################################
#region     Send Email Report
########################################################

$brandingMailParams = @{}

if ($SendEmailReport -and $EmailTo) {
    Write-Output ""
    Write-Output "## Sending the email report to '$EmailTo'..."

    $emailSubject = "Shared Channel Members Report - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"

    $previewRows = @($channelRows | Select-Object -First 20)
    $previewTable = if ($previewRows.Count -gt 0) {
        $tableLines = @("| Team | Channel | Members | Owners | External | Via team only |", "|---|---|---|---|---|---|")
        foreach ($row in $previewRows) {
            $tableLines += "| $(ConvertTo-MarkdownCell $row.Team) | $(ConvertTo-MarkdownCell $row.Channel) | $($row.Members) | $($row.Owners) | $($row.External) | $($row.Indirect) |"
        }
        $tableLines -join "`n"
    }
    else {
        "No shared channels were found."
    }
    $xlsxFileName = if ($xlsxFile) { Split-Path -Path $xlsxFile -Leaf } else { "the Excel workbook" }
    $scopeLine = if ($selectedChannelsMode) { "$ReportScope ($channelNameText)" } else { $ReportScope }
    $missingNamesText = if ($missingChannelNames.Count -gt 0) {
        "`n> **Note:** No shared channel was found for: $($missingChannelNames -join ', ')`n"
    }
    else {
        ""
    }

    $summaryLines = @("| Metric | Count |", "|--------|-------|")
    foreach ($metric in $summaryValues.Keys) {
        $summaryLines += "| **$metric** | $($summaryValues[$metric]) |"
    }
    $summaryTable = $summaryLines -join "`n"

    $attachmentText = if ($perChannelTables) {
        "The attached report file(s) contain every member of every shared channel. The Excel workbook has one worksheet per channel; the CSV file lists all members with team and channel."
    }
    else {
        "The attached report file(s) contain every member of every listed shared channel with team and channel."
    }

    $markdownContent = @"
# Shared Channel Members Report

Tenant: **$tenantDisplayName**

Channels and table layout: **$scopeLine**

Teams: **$teamScopeName**
$missingNamesText
## Summary

$summaryTable

## Shared channels (first $($previewRows.Count) of $($channelRows.Count))

$previewTable

## Attachments

$attachmentText

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Body used when only the workbook can be attached because the CSV exceeds the attachment size limit
    $markdownFallback = @"
# Shared Channel Members Report

Tenant: **$tenantDisplayName**

Channels and table layout: **$scopeLine**

Teams: **$teamScopeName**
$missingNamesText
## Summary

$summaryTable

## Attachments

- **$xlsxFileName**: Excel workbook with the complete data set

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. Select the download link option to obtain the CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

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

        if ($reportFiles.Count -eq 0) {
            # No shared channels, no files - still send the report so the recipient knows the run happened
            Send-RjRbReportEmail @emailParams @brandingMailParams
        }
        elseif ($ReportFileFormat -eq 'CSV & XLSX' -and $csvFile -and $xlsxFile -and (Test-Path -Path $xlsxFile)) {
            # Both formats attached; the built-in size guard falls back to the workbook alone if the pair is too large
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFile) -FallbackMarkdownContent $markdownFallback
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
else {
    Write-RjRbLog -Message "Email delivery not selected - email report skipped" -Verbose
}

#endregion Send Email Report

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the progress output. Every table has its own
# RjTableTitle marker; a marker is only written when rows follow it.
Write-Output ""

$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($channelRows.Count -gt 0) {
    Write-Output "$($channelRows.Count) shared channel(s):"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Shared channels" })
    Write-Output @($channelRows)
}
else {
    Write-Output "No shared channels found."
}

if ($perChannelTables) {
    foreach ($channelTable in $channelTables) {
        Write-Output "$(@($channelTable.Rows).Count) member(s) in '$($channelTable.Team) / $($channelTable.Channel)':"
        Write-Output ([PSCustomObject]@{ RjTableTitle = $channelTable.Title })
        Write-Output @($channelTable.Rows | Select-Object -Property $perChannelColumns)
    }
    if ($channelRows.Count -gt 0 -and $channelTables.Count -eq 0) {
        Write-Output "No channel members could be read."
    }
}
elseif ($memberRows.Count -gt 0) {
    Write-Output "$($memberRows.Count) member entry(ies):"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Shared channel members" })
    Write-Output @($memberRows)
}
elseif ($channelRows.Count -gt 0) {
    Write-Output "No channel members could be read."
}

if ($unreadableTeams.Count -gt 0) {
    Write-Output "$($unreadableTeams.Count) team(s) could not be read:"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Teams not readable" })
    Write-Output @($unreadableTeams)
}

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################

# Remove the temporary report files, if any were created
foreach ($reportFilePath in $reportFiles) {
    if ($reportFilePath -and (Test-Path -Path $reportFilePath)) {
        try {
            Remove-Item -Path $reportFilePath -Force -ErrorAction Stop
            Write-RjRbLog -Message "Removed temporary report file: $reportFilePath" -Verbose
        }
        catch {
            Write-RjRbLog -Message "Failed to remove temporary report file '$reportFilePath': $($_.Exception.Message)" -Verbose
        }
    }
}
if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove the downloaded branding images, if any were used
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

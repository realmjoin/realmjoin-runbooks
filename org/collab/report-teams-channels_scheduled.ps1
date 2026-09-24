<#
	.SYNOPSIS
	List private and shared channels of all teams with their owners

	.DESCRIPTION
	Walks through every team in the tenant and lists its private and shared channels with the team they belong to, their owners and, if wanted, their members. Private channels are not visible in the group view of the RealmJoin Portal, so this report shows who owns and who can access them. Channels without any owner are listed separately. The report can be sent by email or provided as a download link.

	.PARAMETER IncludePrivateChannels
	Lists the private channels hosted by each team.

	.PARAMETER IncludeSharedChannels
	Lists the shared channels hosted by each team. Members from other tenants are marked as external.

	.PARAMETER IncludeMembers
	Also lists the members of each channel by name. Off lists the owners only, which keeps the report short in large tenants.

	.PARAMETER TeamNamePrefix
	Only teams whose name starts with this text. Leave empty for all teams.

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

	.PARAMETER LinkExpiryDays
	Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"IncludePrivateChannels": {
				"DisplayName": "Include private channels?",
				"SelectSimple": {
					"Yes": true,
					"No": false
				}
			},
			"IncludeSharedChannels": {
				"DisplayName": "Include shared channels?",
				"SelectSimple": {
					"Yes": true,
					"No": false
				}
			},
			"IncludeMembers": {
				"DisplayName": "List the members too?",
				"SelectSimple": {
					"Yes, owners and members": true,
					"No, owners only": false
				}
			},
			"TeamNamePrefix": {
				"DisplayName": "Team name prefix"
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
				"DisplayAfter": "TeamNamePrefix",
				"Select": {
					"Options": [
						{
							"Display": "No report",
							"Customization": {
								"Default": { "SendEmailReport": false, "CreateDownloadLink": false },
								"Hide": [ "EmailTo", "ReportFileFormat" ]
							}
						},
						{
							"Display": "Email report",
							"Customization": {
								"Default": { "SendEmailReport": true, "CreateDownloadLink": false },
								"Show": [ "EmailTo", "ReportFileFormat" ],
								"Mandatory": [ "EmailTo" ]
							}
						},
						{
							"Display": "Report download link",
							"Customization": {
								"Default": { "SendEmailReport": false, "CreateDownloadLink": true },
								"Show": [ "ReportFileFormat" ],
								"Hide": [ "EmailTo" ]
							}
						},
						{
							"Display": "Email report & download link",
							"Customization": {
								"Default": { "SendEmailReport": true, "CreateDownloadLink": true },
								"Show": [ "EmailTo", "ReportFileFormat" ],
								"Mandatory": [ "EmailTo" ]
							}
						}
					]
				},
				"Default": "No report"
			}
		]
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [bool]$IncludePrivateChannels = $true,
    [bool]$IncludeSharedChannels = $true,
    [bool]$IncludeMembers = $false,
    [string]$TeamNamePrefix = "",
    # Standard report-delivery parameter set (report-files mode)
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ } )]
    [string]$EmailFrom,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ } )]
    [string]$BrandingHeaderImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ } )]
    [string]$BrandingFooterImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ } )]
    [string]$BrandingFooterLink,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" -Value $_ } )]
    [string]$BrandingAccentColor,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" -Value $_ } )]
    [string]$BrandingTextColor,
    [bool]$SendEmailReport = $false,
    [string]$EmailTo,
    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',
    [bool]$CreateDownloadLink = $false,
    [string]$ContainerName = "report-teams-channels",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ } )]
    [string]$ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ } )]
    [string]$StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ } )]
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
Write-RjRbLog -Message "IncludePrivateChannels: $IncludePrivateChannels" -Verbose
Write-RjRbLog -Message "IncludeSharedChannels: $IncludeSharedChannels" -Verbose
Write-RjRbLog -Message "IncludeMembers: $IncludeMembers" -Verbose
Write-RjRbLog -Message "TeamNamePrefix: $TeamNamePrefix" -Verbose
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

if (-not $IncludePrivateChannels -and -not $IncludeSharedChannels) {
    Write-Error "Neither private nor shared channels are selected, so there is nothing to report. Select at least one channel type." -ErrorAction Continue
    throw "No channel type selected"
}

$channelTypes = @()
if ($IncludePrivateChannels) { $channelTypes += "private" }
if ($IncludeSharedChannels) { $channelTypes += "shared" }

Write-Output "Channel types: $($channelTypes -join ', ')"
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

function Get-BatchResponseItems {
    <#
        .SYNOPSIS
        Returns all items of a collection returned inside a Graph batch response.

        .DESCRIPTION
        A batch response carries only the first page of a collection. When the body contains an
        @odata.nextLink, the remaining pages are fetched with Get-GraphPagedResult.

        .PARAMETER Body
        The body of a single batch response.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Body
    )

    $items = [System.Collections.Generic.List[object]]::new()
    if ($Body.value) {
        $items.AddRange([object[]]@($Body.value))
    }
    $nextLink = $Body.'@odata.nextLink'
    if ($nextLink) {
        $items.AddRange([object[]]@(Get-GraphPagedResult -Uri $nextLink))
    }
    return $items.ToArray()
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

# The home tenant id tells members of shared channels from other tenants apart.
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

# Tenant display name for the email subject, the email body and the report file names (needs Organization.Read.All)
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

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

Write-Output ""
Write-Output "Get Teams"
Write-Output "---------------------"

# Every Microsoft 365 group that is provisioned as a team
$teamsFilter = "resourceProvisioningOptions/Any(x:x eq 'Team')"
$teamsUri = "https://graph.microsoft.com/v1.0/groups?`$filter=$([uri]::EscapeDataString($teamsFilter))&`$select=id,displayName,visibility,resourceProvisioningOptions"
try {
    $allTeams = @(Get-GraphPagedResult -Uri $teamsUri | Where-Object { @($_.resourceProvisioningOptions) -contains "Team" })
}
catch {
    Write-Error "Failed to retrieve the teams of the tenant: $($_.Exception.Message)" -ErrorAction Continue
    throw "Unable to retrieve the teams"
}

$teams = if ([string]::IsNullOrWhiteSpace($TeamNamePrefix)) {
    $allTeams
}
else {
    @($allTeams | Where-Object { "$($_.displayName)" -like "$TeamNamePrefix*" })
}
$teams = @($teams | Sort-Object { "$($_.displayName)" })
Write-Output "Teams in the tenant: $($allTeams.Count); teams in scope: $($teams.Count)"
Write-RjRbLog -Message "Teams retrieved: $($allTeams.Count), in scope: $($teams.Count)" -Verbose

Write-Output ""
Write-Output "Get Channels"
Write-Output "---------------------"
Write-Output "Reading the $($channelTypes -join ' and ') channels of $($teams.Count) team(s). This may take a while in large tenants."

$teamsById = @{}
foreach ($team in $teams) { $teamsById["$($team.id)"] = $team }

# One request per team and channel type; the team id and the type form the request id for correlation.
$channelRequests = foreach ($team in $teams) {
    foreach ($type in $channelTypes) {
        $channelFilter = [uri]::EscapeDataString("membershipType eq '$type'")
        @{
            id     = "$($team.id)|$type"
            method = "GET"
            url    = "/teams/$($team.id)/channels?`$filter=$channelFilter&`$select=id,displayName,membershipType,createdDateTime,isArchived"
        }
    }
}

$channelRecords = [System.Collections.Generic.List[object]]::new()
$unreadableTeams = [System.Collections.Generic.List[object]]::new()
$unreadableTeamIds = [System.Collections.Generic.HashSet[string]]::new()

if (@($channelRequests).Count -gt 0) {
    try {
        $channelResponses = @(Invoke-RjRbGraphBatch -Requests @($channelRequests) -ProgressLabel "teams" -ProgressInterval 10)
    }
    catch {
        Write-Error "Failed to read the channels through the Graph batch endpoint: $($_.Exception.Message)" -ErrorAction Continue
        throw "Unable to retrieve the channels"
    }

    foreach ($response in $channelResponses) {
        $parts = "$($response.id)" -split '\|', 2
        $teamId = $parts[0]
        $type = $parts[1]
        $team = $teamsById[$teamId]
        if (-not $team) { continue }

        if ($response.status -eq 200) {
            try {
                $channels = @(Get-BatchResponseItems -Body $response.body)
            }
            catch {
                Write-RjRbLog -Message "Paging the $type channels of team '$($team.displayName)' failed: $($_.Exception.Message)" -Verbose
                $channels = @()
                if ($response.body.value) { $channels = @($response.body.value) }
            }
            foreach ($channel in $channels) {
                $channelRecords.Add([PSCustomObject]@{
                        TeamId      = $teamId
                        Team        = "$($team.displayName)"
                        Visibility  = if ($team.visibility) { "$($team.visibility)" } else { "unknown" }
                        ChannelId   = "$($channel.id)"
                        Channel     = "$($channel.displayName)"
                        ChannelType = $type
                        Archived    = if ($channel.isArchived) { "Yes" } else { "No" }
                        Created     = if ($channel.createdDateTime) { ([datetime]$channel.createdDateTime).ToString("yyyy-MM-dd") } else { "" }
                    })
            }
        }
        else {
            # A team that cannot be read (deleted meanwhile, archived without access, license gap) is reported, not fatal.
            $reason = Get-BatchErrorText -Response $response
            Write-RjRbLog -Message "Channels of team '$($team.displayName)' ($type) could not be read: $reason" -Verbose
            if ($unreadableTeamIds.Add($teamId)) {
                $unreadableTeams.Add([PSCustomObject]@{
                        Team   = "$($team.displayName)"
                        TeamId = $teamId
                        Reason = $reason
                    })
            }
        }
    }
}

Write-Output "Channels found: $($channelRecords.Count) ($(@($channelRecords | Where-Object { $_.ChannelType -eq 'private' }).Count) private, $(@($channelRecords | Where-Object { $_.ChannelType -eq 'shared' }).Count) shared)"
if ($unreadableTeams.Count -gt 0) {
    Write-Output "Teams that could not be read: $($unreadableTeams.Count)"
}

Write-Output ""
Write-Output "Get Channel Members"
Write-Output "---------------------"

# One request per channel; the team id and the channel id form the request id.
$membersByChannel = @{}
$memberErrorsByChannel = @{}
$memberRequests = foreach ($record in $channelRecords) {
    @{
        id     = "$($record.TeamId)|$($record.ChannelId)"
        method = "GET"
        url    = "/teams/$($record.TeamId)/channels/$([uri]::EscapeDataString($record.ChannelId))/members"
    }
}

if (@($memberRequests).Count -gt 0) {
    try {
        $memberResponses = @(Invoke-RjRbGraphBatch -Requests @($memberRequests) -ProgressLabel "channels" -ProgressInterval 10)
    }
    catch {
        Write-Error "Failed to read the channel members through the Graph batch endpoint: $($_.Exception.Message)" -ErrorAction Continue
        throw "Unable to retrieve the channel members"
    }

    foreach ($response in $memberResponses) {
        $key = "$($response.id)"
        if ($response.status -eq 200) {
            try {
                $membersByChannel[$key] = @(Get-BatchResponseItems -Body $response.body)
            }
            catch {
                Write-RjRbLog -Message "Paging the members of channel '$key' failed: $($_.Exception.Message)" -Verbose
                $membersByChannel[$key] = @($response.body.value)
            }
        }
        else {
            $memberErrorsByChannel[$key] = Get-BatchErrorText -Response $response
            Write-RjRbLog -Message "Members of channel '$key' could not be read: $($memberErrorsByChannel[$key])" -Verbose
        }
    }
}

Write-Output "Member lists read: $($membersByChannel.Count); not readable: $($memberErrorsByChannel.Count)"

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

Write-Output ""
Write-Output "Processing channels"
Write-Output "---------------------"

$results = [System.Collections.Generic.List[object]]::new()

foreach ($record in ($channelRecords | Sort-Object Team, ChannelType, Channel)) {
    $key = "$($record.TeamId)|$($record.ChannelId)"
    $owners = [System.Collections.Generic.List[string]]::new()
    $ownerEmails = [System.Collections.Generic.List[string]]::new()
    $members = [System.Collections.Generic.List[string]]::new()
    $externalCount = 0
    $note = ""

    if ($memberErrorsByChannel.ContainsKey($key)) {
        $note = "Members not readable ($($memberErrorsByChannel[$key]))"
    }
    else {
        foreach ($member in @($membersByChannel[$key])) {
            if ($null -eq $member) { continue }
            $isOwner = @($member.roles) -contains "owner"
            $memberTenantId = if ($member.tenantId) { "$($member.tenantId)".ToLower() } else { "" }
            $isExternal = ($homeTenantId -and $memberTenantId -and ($memberTenantId -ne $homeTenantId))
            $name = if ($member.displayName) { "$($member.displayName)" } elseif ($member.email) { "$($member.email)" } else { "$($member.userId)" }
            if ($isExternal) {
                $name += " (external)"
                $externalCount++
            }
            if ($isOwner) {
                $owners.Add($name)
                if ($member.email) { $ownerEmails.Add("$($member.email)") }
            }
            else {
                $members.Add($name)
            }
        }
    }

    $row = [ordered]@{
        Team          = $record.Team
        Visibility    = $record.Visibility
        Channel       = $record.Channel
        ChannelType   = $record.ChannelType
        Archived      = $record.Archived
        Created       = $record.Created
        OwnerCount    = $owners.Count
        MemberCount   = $members.Count
        ExternalCount = $externalCount
        Owners        = ($owners -join "; ")
        OwnerEmails   = ($ownerEmails -join "; ")
    }
    if ($IncludeMembers) {
        $row.Members = ($members -join "; ")
    }
    $row.Note = $note
    $results.Add([PSCustomObject]$row)
}

$results = @($results)
$privateRows = @($results | Where-Object { $_.ChannelType -eq "private" })
$sharedRows = @($results | Where-Object { $_.ChannelType -eq "shared" })
$noOwnerRows = @($results | Where-Object { $_.OwnerCount -eq 0 -and -not $_.Note })
$externalRows = @($results | Where-Object { $_.ExternalCount -gt 0 })
$unreadableRows = @($unreadableTeams)

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Teams in scope: $($teams.Count)"
Write-Output "Private channels: $($privateRows.Count)"
Write-Output "Shared channels: $($sharedRows.Count)"
Write-Output "Channels without owner: $($noOwnerRows.Count)"
Write-Output "Channels with external members: $($externalRows.Count)"
Write-Output "Teams not readable: $($unreadableRows.Count)"
Write-RjRbLog -Message "Teams: $($teams.Count); private: $($privateRows.Count); shared: $($sharedRows.Count); without owner: $($noOwnerRows.Count); external: $($externalRows.Count); unreadable teams: $($unreadableRows.Count)" -Verbose

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$csvFile = $null
$xlsxFile = $null
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "TeamsChannels_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$safeTenantName = $tenantDisplayName -replace '[\\/:*?"<>|]', '_'
$fileNameBase = "TeamsChannels_$($safeTenantName)_$(Get-Date -Format 'yyyyMMdd')"

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if (($SendEmailReport -or $CreateDownloadLink) -and $results.Count -gt 0) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFile = Join-Path $tempDir "$fileNameBase.csv"
        $results | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvFile
        Write-RjRbLog -Message "Exported $($results.Count) row(s) to CSV: $csvFile" -Verbose
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFile = Join-Path $tempDir "$fileNameBase.xlsx"
        $worksheets = [ordered]@{ 'Channels' = $results }
        if ($noOwnerRows.Count -gt 0) { $worksheets['Without owner'] = $noOwnerRows }
        if ($unreadableRows.Count -gt 0) { $worksheets['Teams not readable'] = $unreadableRows }
        $workbookCoverSheet = [ordered]@{
            Title                            = 'Teams Channels'
            Tenant                           = $tenantDisplayName
            Generated                        = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version'                = $Version
            'Teams in scope'                 = $teams.Count
            'Private channels'               = $privateRows.Count
            'Shared channels'                = $sharedRows.Count
            'Channels without owner'         = $noOwnerRows.Count
            'Channels with external members' = $externalRows.Count
            'Teams not readable'             = $unreadableRows.Count
        }
        Export-RjRbXlsx -Worksheets $worksheets -Path $xlsxFile -CoverSheet $workbookCoverSheet
        $reportFiles += $xlsxFile
        Write-RjRbLog -Message "Exported $($results.Count) row(s) to XLSX: $xlsxFile" -Verbose
    }

    Write-Output ""
    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
}
elseif ($results.Count -eq 0) {
    Write-RjRbLog -Message "No channels - skipping the report file export" -Verbose
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
                -LinkExpiryDays $LinkExpiryDays `
                -AddBlobNamePrefix $true
        }
        catch {
            Write-Error "Failed to upload the report file(s) to storage account '$StorageAccountName': $($_.Exception.Message). The managed identity needs the 'Storage Account Contributor' role on the storage account." -ErrorAction Continue
            throw
        }

        foreach ($uploadResult in $uploadResults) {
            Write-Output ""
            Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }
    else {
        Write-Output "No channels - skipping the upload."
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

    $emailSubject = "Teams Channels Report - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"

    $previewRows = @($noOwnerRows | Select-Object -First 10)
    $previewTable = if ($previewRows.Count -gt 0) {
        $tableLines = @("| Team | Channel | Type | Members |", "|---|---|---|---|")
        foreach ($row in $previewRows) {
            $tableLines += "| $($row.Team) | $($row.Channel) | $($row.ChannelType) | $($row.MemberCount) |"
        }
        $tableLines -join "`n"
    }
    else {
        "Every channel in the report has at least one owner."
    }
    $xlsxFileName = if ($xlsxFile) { Split-Path -Path $xlsxFile -Leaf } else { "the Excel workbook" }

    $summaryTable = @"
| Metric | Count |
|--------|-------|
| **Teams in scope** | $($teams.Count) |
| **Private channels** | $($privateRows.Count) |
| **Shared channels** | $($sharedRows.Count) |
| **Channels without owner** | $($noOwnerRows.Count) |
| **Channels with external members** | $($externalRows.Count) |
| **Teams not readable** | $($unreadableRows.Count) |
"@

    $markdownContent = @"
# Teams Channels Report

Tenant: **$tenantDisplayName**

## Summary

$summaryTable

## Channels without owner (first $($previewRows.Count) of $($noOwnerRows.Count))

$previewTable

## Attachments

The attached report file(s) contain every channel with its owners$(if ($IncludeMembers) { " and members" }).

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Body used when only the workbook can be attached because the CSV exceeds the attachment size limit
    $markdownFallback = @"
# Teams Channels Report

Tenant: **$tenantDisplayName**

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
            # No channels, no files - still send the report so the recipient knows the run happened
            Send-RjRbReportEmail @emailParams @brandingMailParams
        }
        elseif ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFile -and (Test-Path -Path $xlsxFile)) {
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
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
$maxTableRows = 250
Write-Output ""

$summaryValues = [ordered]@{
    "Teams in scope"                 = $teams.Count
    "Private channels"               = $privateRows.Count
    "Shared channels"                = $sharedRows.Count
    "Channels without owner"         = $noOwnerRows.Count
    "Channels with external members" = $externalRows.Count
    "Teams not readable"             = $unreadableRows.Count
}
$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

$tableColumns = @("Team", "Channel", "Archived", "Created", "OwnerCount", "MemberCount", "ExternalCount", "Owners")
if ($IncludeMembers) { $tableColumns += "Members" }
$tableColumns += "Note"

if ($IncludePrivateChannels) {
    if ($privateRows.Count -gt 0) {
        Write-Output "$($privateRows.Count) private channel(s)$(if ($privateRows.Count -gt $maxTableRows) { ", showing the first $maxTableRows" }):"
        Write-Output ([PSCustomObject]@{ RjTableTitle = "Private channels" })
        Write-Output @($privateRows | Select-Object -First $maxTableRows -Property $tableColumns)
    }
    else {
        Write-Output "No private channels."
    }
}

if ($IncludeSharedChannels) {
    if ($sharedRows.Count -gt 0) {
        Write-Output "$($sharedRows.Count) shared channel(s)$(if ($sharedRows.Count -gt $maxTableRows) { ", showing the first $maxTableRows" }):"
        Write-Output ([PSCustomObject]@{ RjTableTitle = "Shared channels" })
        Write-Output @($sharedRows | Select-Object -First $maxTableRows -Property $tableColumns)
    }
    else {
        Write-Output "No shared channels."
    }
}

if ($noOwnerRows.Count -gt 0) {
    Write-Output "$($noOwnerRows.Count) channel(s) without owner:"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Channels without owner" })
    Write-Output @($noOwnerRows | Select-Object -First $maxTableRows -Property Team, Channel, ChannelType, Archived, MemberCount, ExternalCount)
}
else {
    Write-Output "No channels without owner."
}

if ($unreadableRows.Count -gt 0) {
    Write-Output "$($unreadableRows.Count) team(s) could not be read:"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Teams not readable" })
    Write-Output @($unreadableRows | Select-Object -Property Team, Reason)
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

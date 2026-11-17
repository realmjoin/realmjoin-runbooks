<#
	.SYNOPSIS
	List access packages with their assignments, requests and policies

	.DESCRIPTION
	Lists the access packages of Entra ID entitlement management, all or those matching a name or catalog filter, with everyone assigned to them. Users, guests and service principals are listed, whether they requested access, were added by an admin or by an auto-assignment policy. Further tables show the resource roles each package grants, open requests and assignment policies. The report can be sent by email or provided as a download link.

	.PARAMETER AccessPackageName
	Only access packages whose name matches are reported. Use * as a wildcard, for example "Sales -*" for names starting with "Sales -"; text without * matches anywhere in the name. Case does not matter. Leave empty for all packages.

	.PARAMETER CatalogName
	Only access packages in catalogs whose name matches are reported, with the same rules as "Access package name filter". Both filters apply together. Leave empty for all catalogs.

	.PARAMETER IncludeExpiredAssignments
	Also list the assignments that have already expired, in a separate table. Expired assignments are always counted; the list can be long in tenants that have used access packages for years.

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
			"AccessPackageName": {
				"DisplayName": "Access package name filter"
			},
			"CatalogName": {
				"DisplayName": "Catalog name filter"
			},
			"IncludeExpiredAssignments": {
				"DisplayName": "Include expired assignments?"
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
				"DisplayAfter": "IncludeExpiredAssignments",
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
    [string]$AccessPackageName,
    [string]$CatalogName,
    [bool]$IncludeExpiredAssignments = $false,
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
    [string]$ContainerName = "report-access-package-assignments",
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
Write-RjRbLog -Message "AccessPackageName: $AccessPackageName" -Verbose
Write-RjRbLog -Message "CatalogName: $CatalogName" -Verbose
Write-RjRbLog -Message "IncludeExpiredAssignments: $IncludeExpiredAssignments" -Verbose
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

# Name filters for the access package and its catalog: * is the only wildcard ("Sales -*" = starts with
# "Sales -"), text without * matches anywhere in the name. Both apply together; empty means all.
$nameFilter = "$AccessPackageName".Trim()
$catalogFilter = "$CatalogName".Trim()
$scopeParts = [System.Collections.Generic.List[string]]::new()
if ($nameFilter) { $scopeParts.Add("name $(if ($nameFilter.Contains('*')) { 'matches' } else { 'contains' }) '$nameFilter'") }
if ($catalogFilter) { $scopeParts.Add("catalog $(if ($catalogFilter.Contains('*')) { 'matches' } else { 'contains' }) '$catalogFilter'") }
$packageScopeText = "All access packages"
if ($scopeParts.Count -gt 0) {
    $packageScopeText = $scopeParts -join ', '
    $packageScopeText = $packageScopeText.Substring(0, 1).ToUpper() + $packageScopeText.Substring(1)
}

Write-Output "Access packages: $packageScopeText"
Write-Output "Expired assignments: $(if ($IncludeExpiredAssignments) { 'counted and listed in a separate table' } else { 'counted, not listed' })"
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

        .PARAMETER CollectionProperty
        Property of the response body that holds the items: 'value' for a list, the name of an expanded
        relationship for a single object.
    #>
    param(
        [AllowNull()]
        $Response,
        [string]$CollectionProperty = 'value'
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
    foreach ($item in @($Response.body.$CollectionProperty)) {
        if ($null -ne $item) { $items.Add($item) }
    }

    $nextLinkKey = if ($CollectionProperty -eq 'value') { '@odata.nextLink' } else { "$($CollectionProperty)@odata.nextLink" }
    $nextLink = $Response.body.$nextLinkKey
    if ($nextLink) {
        try {
            # The error record of a failed page is dropped here: the gap is returned as 'Incomplete' and
            # reported per access package, so it must not show up as a job error.
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

function ConvertTo-NameFilterRegex {
    <#
        .SYNOPSIS
        Builds a case-insensitive regex from a name filter with * as the only wildcard; $null for an empty filter.

        .DESCRIPTION
        A filter with * must match the whole name ("Sales -*" = starts with "Sales -"); a filter without *
        matches anywhere in the name. Everything else is matched literally, so names with [ ] or ? need
        no escaping.

        .PARAMETER Filter
        The filter text as entered in the portal.
    #>
    param(
        [string]$Filter
    )

    if (-not $Filter) { return $null }
    $pattern = [regex]::Escape($Filter) -replace '\\\*', '.*'
    if ($Filter.Contains('*')) { $pattern = "^$pattern$" }
    return [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function ConvertTo-UtcDateTime {
    <#
        .SYNOPSIS
        Converts a Graph timestamp (string, DateTime or DateTimeOffset) to a UTC DateTime; $null when empty or unreadable.

        .PARAMETER Value
        The timestamp as returned by Invoke-MgGraphRequest.
    #>
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value -or "$Value" -eq '') { return $null }
    if ($Value -is [datetime]) { return $Value.ToUniversalTime() }
    if ($Value -is [datetimeoffset]) { return $Value.UtcDateTime }

    $parsed = [datetimeoffset]::MinValue
    if ([datetimeoffset]::TryParse("$Value", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$parsed)) {
        return $parsed.UtcDateTime
    }
    return $null
}

function Format-ReportDate {
    <#
        .SYNOPSIS
        Formats a Graph timestamp as 'yyyy-MM-dd HH:mm' (UTC); empty when there is none.

        .PARAMETER Value
        The timestamp as returned by Invoke-MgGraphRequest.
    #>
    param(
        [AllowNull()]
        $Value
    )

    $date = ConvertTo-UtcDateTime -Value $Value
    if ($date) { return $date.ToString('yyyy-MM-dd HH:mm') }
    return ''
}

function Get-DurationText {
    <#
        .SYNOPSIS
        Turns an ISO 8601 duration such as P365D or PT8H into readable text.

        .PARAMETER Duration
        The duration as returned by Graph.
    #>
    param(
        [AllowNull()]
        $Duration
    )

    if (-not $Duration) { return '' }
    $span = $null
    if ($Duration -is [timespan]) {
        $span = $Duration
    }
    else {
        try {
            $span = [System.Xml.XmlConvert]::ToTimeSpan("$Duration")
        }
        catch {
            Write-RjRbLog -Message "Duration '$Duration' could not be converted: $($_.Exception.Message)" -Verbose
            return "$Duration"
        }
    }

    if ($span.TotalDays -ge 1 -and ($span.TotalDays % 1) -eq 0) {
        $days = [int]$span.TotalDays
        return "$days day$(if ($days -ne 1) { 's' })"
    }
    if ($span.TotalHours -ge 1 -and ($span.TotalHours % 1) -eq 0) {
        $hours = [int]$span.TotalHours
        return "$hours hour$(if ($hours -ne 1) { 's' })"
    }
    return "$Duration"
}

function Get-ScheduleEnd {
    <#
        .SYNOPSIS
        Returns the end of an assignment or request schedule as UTC DateTime (End) and as text (Text).

        .DESCRIPTION
        Text is the formatted end date, 'Never' for schedules without expiration and empty when the
        schedule names no end. A duration without end date is added to the start date.

        .PARAMETER Schedule
        An entitlementManagementSchedule object (startDateTime, expiration).
    #>
    param(
        [AllowNull()]
        $Schedule
    )

    $expiration = $Schedule.expiration
    $type = "$($expiration.type)"
    $end = ConvertTo-UtcDateTime -Value $expiration.endDateTime
    if ($end -and $end.Year -ge 9999) {
        $end = $null
        $type = 'noExpiration'
    }
    if (-not $end -and $type -eq 'afterDuration' -and $expiration.duration) {
        $start = ConvertTo-UtcDateTime -Value $Schedule.startDateTime
        if ($start) {
            try {
                $span = if ($expiration.duration -is [timespan]) { $expiration.duration } else { [System.Xml.XmlConvert]::ToTimeSpan("$($expiration.duration)") }
                $end = $start.Add($span)
            }
            catch {
                Write-RjRbLog -Message "Duration '$($expiration.duration)' could not be converted: $($_.Exception.Message)" -Verbose
            }
        }
    }

    $text = if ($end) {
        $end.ToString('yyyy-MM-dd HH:mm')
    }
    elseif ($type -eq 'noExpiration') {
        'Never'
    }
    elseif ($type -eq 'afterDuration' -and $expiration.duration) {
        "After $(Get-DurationText -Duration $expiration.duration)"
    }
    else {
        ''
    }
    return [PSCustomObject]@{ End = $end; Text = $text }
}

function Get-PolicyExpirationText {
    <#
        .SYNOPSIS
        Describes how long assignments created through a policy last.

        .PARAMETER Expiration
        The expirationPattern of an assignment policy.
    #>
    param(
        [AllowNull()]
        $Expiration
    )

    switch ("$($Expiration.type)") {
        'noExpiration' { return 'Never' }
        'afterDuration' { return "After $(Get-DurationText -Duration $Expiration.duration)" }
        'afterDateTime' {
            $end = ConvertTo-UtcDateTime -Value $Expiration.endDateTime
            if ($end) { return "On $($end.ToString('yyyy-MM-dd'))" }
            return 'On a fixed date'
        }
        default { return 'Not specified' }
    }
}

function Get-SubjectName {
    <#
        .SYNOPSIS
        Returns the readable name of an access package subject (display name, principal name or email).

        .PARAMETER Subject
        An accessPackageSubject object.
    #>
    param(
        [AllowNull()]
        $Subject
    )

    if ($null -eq $Subject) { return 'Unknown subject' }
    foreach ($candidate in @($Subject.displayName, $Subject.principalName, $Subject.email)) {
        if ("$candidate".Trim()) { return "$candidate" }
    }
    if ($Subject.objectId) { return "Unknown subject ($($Subject.objectId))" }
    return 'Unknown subject'
}

function Get-SubjectType {
    <#
        .SYNOPSIS
        Classifies an access package subject as Member, Guest, External (not in tenant yet) or Service principal.

        .DESCRIPTION
        The subject carries no user type. Guests are recognized by the #EXT# marker in the principal
        name or by a governed guest lifecycle; a user without object ID is a requestor from a connected
        organization who does not have an account in the tenant yet.

        .PARAMETER Subject
        An accessPackageSubject object.
    #>
    param(
        [AllowNull()]
        $Subject
    )

    if ($null -eq $Subject) { return 'Unknown' }
    $type = "$($Subject.subjectType)"
    if ($type -eq 'servicePrincipal') { return 'Service principal' }
    if (-not $Subject.objectId) { return 'External (not in tenant yet)' }
    if ("$($Subject.principalName)" -match '#EXT#' -or "$($Subject.subjectLifecycle)" -eq 'governed') { return 'Guest' }
    if ($type -eq 'user') { return 'Member' }
    if ($type) { return $type }
    return 'Unknown'
}

function Get-SubjectKey {
    <#
        .SYNOPSIS
        Returns the key that identifies a subject across access packages.

        .PARAMETER Subject
        An accessPackageSubject object.
    #>
    param(
        [AllowNull()]
        $Subject
    )

    foreach ($candidate in @($Subject.objectId, $Subject.principalName, $Subject.email, $Subject.id)) {
        if ("$candidate".Trim()) { return "$candidate".ToLower() }
    }
    return ''
}

function Get-SubjectSetText {
    <#
        .SYNOPSIS
        Describes a list of subject sets (approvers, allowed requestors) as readable text.

        .DESCRIPTION
        Users and groups are shown with the description stored in the policy; without one, the object
        ID is shown, because resolving names would need directory read permissions.

        .PARAMETER SubjectSets
        A collection of subjectSet objects (singleUser, groupMembers, requestorManager, ...).
    #>
    param(
        [AllowNull()]
        $SubjectSets
    )

    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($set in @($SubjectSets)) {
        if ($null -eq $set) { continue }
        $type = "$($set.'@odata.type')" -replace '^#?microsoft\.graph\.', ''
        $description = "$($set.description)".Trim()
        $managerLevel = 0
        [void][int]::TryParse("$($set.managerLevel)", [ref]$managerLevel)

        $text = switch ($type) {
            'singleUser' { if ($description) { $description } else { "User $($set.userId)" } }
            'groupMembers' { if ($description) { "Members of $description" } else { "Members of group $($set.groupId)" } }
            'requestorManager' { if ($managerLevel -gt 1) { "Manager level $managerLevel" } else { 'Manager' } }
            'internalSponsors' { 'Internal sponsors' }
            'externalSponsors' { 'External sponsors' }
            'targetUserSponsors' { 'Sponsors of the user' }
            'attributeRuleMembers' { if ($set.membershipRule) { "Rule: $($set.membershipRule)" } elseif ($description) { $description } else { 'Attribute rule' } }
            'connectedOrganizationMembers' { if ($description) { $description } else { "Connected organization $($set.connectedOrganizationId)" } }
            default { if ($description) { $description } elseif ($type) { $type } else { 'Unknown' } }
        }
        $parts.Add("$text")
    }
    return ($parts -join '; ')
}

function Get-ApproverText {
    <#
        .SYNOPSIS
        Describes the approvers of each approval stage of a policy.

        .PARAMETER ApprovalSettings
        The requestApprovalSettings of an assignment policy.
    #>
    param(
        [AllowNull()]
        $ApprovalSettings
    )

    if (-not $ApprovalSettings -or -not $ApprovalSettings.isApprovalRequiredForAdd) { return '' }
    $stages = @(@($ApprovalSettings.stages) | Where-Object { $null -ne $_ })
    if ($stages.Count -eq 1) {
        return (Get-SubjectSetText -SubjectSets $stages[0].primaryApprovers)
    }
    $parts = for ($i = 0; $i -lt $stages.Count; $i++) {
        "Stage $($i + 1): $(Get-SubjectSetText -SubjectSets $stages[$i].primaryApprovers)"
    }
    return (@($parts) -join ' | ')
}

function Get-ReviewText {
    <#
        .SYNOPSIS
        Describes whether and how often assignments of a policy are reviewed.

        .PARAMETER ReviewSettings
        The reviewSettings of an assignment policy.
    #>
    param(
        [AllowNull()]
        $ReviewSettings
    )

    if (-not $ReviewSettings -or -not $ReviewSettings.isEnabled) { return 'No' }
    $pattern = $ReviewSettings.schedule.recurrence.pattern
    $interval = 0
    [void][int]::TryParse("$($pattern.interval)", [ref]$interval)
    $unit = switch ("$($pattern.type)") {
        'daily' { 'day' }
        'weekly' { 'week' }
        'absoluteMonthly' { 'month' }
        'relativeMonthly' { 'month' }
        'absoluteYearly' { 'year' }
        'relativeYearly' { 'year' }
        default { '' }
    }
    if ($unit -and $interval -eq 1) { return "Every $unit" }
    if ($unit -and $interval -gt 1) { return "Every $interval $($unit)s" }
    return 'Yes'
}

function Get-StateLabel {
    <#
        .SYNOPSIS
        Returns the readable label of an assignment or request state.

        .PARAMETER State
        The state value from Graph.
    #>
    param(
        [AllowNull()]
        [string]$State
    )

    switch ($State) {
        'delivered' { return 'Delivered' }
        'delivering' { return 'Delivering' }
        'partiallyDelivered' { return 'Partially delivered' }
        'deliveryFailed' { return 'Delivery failed' }
        'expired' { return 'Expired' }
        'submitted' { return 'Submitted' }
        'pendingApproval' { return 'Pending approval' }
        'scheduled' { return 'Scheduled' }
        'denied' { return 'Denied' }
        'canceled' { return 'Canceled' }
        default { return "$State" }
    }
}

function Get-RequestTypeLabel {
    <#
        .SYNOPSIS
        Returns the readable label of a request type.

        .PARAMETER RequestType
        The requestType value from Graph.
    #>
    param(
        [AllowNull()]
        [string]$RequestType
    )

    switch ($RequestType) {
        'userAdd' { return 'User request' }
        'userUpdate' { return 'User extension' }
        'userRemove' { return 'User removal' }
        'adminAdd' { return 'Admin assignment' }
        'adminUpdate' { return 'Admin update' }
        'adminRemove' { return 'Admin removal' }
        'systemAdd' { return 'Auto-assignment' }
        'systemUpdate' { return 'System update' }
        'systemRemove' { return 'System removal' }
        'onBehalfAdd' { return 'Request on behalf' }
        'approverRemove' { return 'Approver removal' }
        default { return "$RequestType" }
    }
}

function Get-TargetScopeLabel {
    <#
        .SYNOPSIS
        Returns the readable label of the principals a policy can assign.

        .PARAMETER AllowedTargetScope
        The allowedTargetScope value of an assignment policy.
    #>
    param(
        [AllowNull()]
        [string]$AllowedTargetScope
    )

    switch ($AllowedTargetScope) {
        'notSpecified' { return 'None (admin assignments only)' }
        'specificDirectoryUsers' { return 'Specific users and groups' }
        'specificConnectedOrganizationUsers' { return 'Specific connected organizations' }
        'specificDirectoryServicePrincipals' { return 'Specific service principals' }
        'allMemberUsers' { return 'All members (no guests)' }
        'allDirectoryUsers' { return 'All users (including guests)' }
        'allDirectoryServicePrincipals' { return 'All service principals' }
        'allConfiguredConnectedOrganizationUsers' { return 'All configured connected organizations' }
        'allExternalUsers' { return 'All external users' }
        'allDirectoryAgentIdentities' { return 'All agent identities' }
        default { return "$AllowedTargetScope" }
    }
}

function Get-PolicyType {
    <#
        .SYNOPSIS
        Classifies an assignment policy as Auto-assignment, Admin assignment only or Request.

        .PARAMETER Policy
        An accessPackageAssignmentPolicy object.
    #>
    param(
        [AllowNull()]
        $Policy
    )

    if ($null -eq $Policy) { return '' }
    if ($null -ne $Policy.automaticRequestSettings) { return 'Auto-assignment' }
    if ("$($Policy.allowedTargetScope)" -eq 'notSpecified') { return 'Admin assignment only' }
    return 'Request'
}

function Get-ResourceTypeLabel {
    <#
        .SYNOPSIS
        Returns the readable label of a resource origin system.

        .PARAMETER OriginSystem
        The originSystem value of a resource, role or scope.
    #>
    param(
        [AllowNull()]
        [string]$OriginSystem
    )

    switch ($OriginSystem) {
        'AadGroup' { return 'Group' }
        'AadApplication' { return 'Application' }
        'SharePointOnline' { return 'SharePoint site' }
        'AzureResources' { return 'Azure resource' }
        'AzureResource' { return 'Azure resource' }
        'CustomDataProvidedResource' { return 'Custom data' }
        default { return "$OriginSystem" }
    }
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

# Tenant display name for the email subject, the email body and the report file names (needs Organization.Read.All)
Write-Output "Retrieving tenant information..."
$tenantDisplayName = "Unknown Tenant"
try {
    $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
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
Write-Output "Get Access Packages"
Write-Output "---------------------"

$emBaseUri = "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement"
$emBasePath = "/identityGovernance/entitlementManagement"

# The catalog is expanded for its name; if the expansion is refused, the packages are read without it.
$catalogExpanded = $true
try {
    $allPackages = @(Get-GraphPagedResult -Uri "$emBaseUri/accessPackages?`$expand=catalog" 2>$null | Where-Object { $_.id })
}
catch {
    Write-RjRbLog -Message "The access packages could not be read with their catalog, retrying without it: $($_.Exception.Message)" -Verbose
    $catalogExpanded = $false
    try {
        $allPackages = @(Get-GraphPagedResult -Uri "$emBaseUri/accessPackages" | Where-Object { $_.id })
    }
    catch {
        Write-Error "Failed to read the access packages: $($_.Exception.Message). The managed identity needs the application permission EntitlementManagement.Read.All, and entitlement management needs a Microsoft Entra ID P2 or Microsoft Entra ID Governance license." -ErrorAction Continue
        throw "Unable to retrieve the access packages"
    }
}
Write-Output "Access packages in the tenant: $($allPackages.Count)"
if (-not $catalogExpanded) {
    Write-RjRbLog -Message "WARNING: The catalogs of the access packages could not be read, so the Catalog column stays empty and resources are shown without their names." -Verbose
}

$nameRegex = ConvertTo-NameFilterRegex -Filter $nameFilter
$catalogRegex = ConvertTo-NameFilterRegex -Filter $catalogFilter
if ($catalogRegex -and -not $catalogExpanded) {
    Write-Error "The catalog filter '$catalogFilter' cannot be applied because the catalogs of the access packages could not be read. Leave 'Catalog name filter' empty or run the report again later." -ErrorAction Continue
    throw "Catalogs not readable for the catalog filter"
}

$packages = @(
    foreach ($package in $allPackages) {
        $packageName = "$($package.displayName)"
        if ($nameRegex -and -not $nameRegex.IsMatch($packageName)) { continue }
        if ($catalogRegex -and -not $catalogRegex.IsMatch("$($package.catalog.displayName)")) { continue }
        [PSCustomObject]@{
            Id          = "$($package.id)"
            Name        = $packageName
            Catalog     = "$($package.catalog.displayName)"
            CatalogId   = "$($package.catalog.id)"
            Description = "$($package.description)"
            Hidden      = if ($package.isHidden) { "Yes" } else { "No" }
            Created     = Format-ReportDate -Value $package.createdDateTime
            Modified    = Format-ReportDate -Value $package.modifiedDateTime
        }
    }
) | Sort-Object Catalog, Name
$packages = @($packages)

if ($nameFilter -or $catalogFilter) {
    if ($packages.Count -eq 0) {
        Write-Output ""
        if ($allPackages.Count -gt 0) {
            Write-Output "Access packages in the tenant (catalog / access package):"
            $packageList = @($allPackages | ForEach-Object { "$(if ($catalogExpanded) { "$($_.catalog.displayName) / " })$($_.displayName)" } | Sort-Object)
            foreach ($packageEntry in @($packageList | Select-Object -First 50)) {
                Write-Output "- $packageEntry"
            }
            if ($packageList.Count -gt 50) {
                Write-Output "... and $($packageList.Count - 50) more"
            }
        }
        else {
            Write-Output "The tenant has no access packages."
        }
        Write-Error "No access package matches the filter ($packageScopeText). Check the filter against the list above; use * as a wildcard, for example 'Sales -*' for names starting with 'Sales -'." -ErrorAction Continue
        throw "No access package matches the filter ($packageScopeText)"
    }
    Write-Output "Access packages in scope ($packageScopeText): $($packages.Count)"
}
Write-RjRbLog -Message "Access packages in scope: $($packages.Count)" -Verbose

# Four requests per access package: resource roles, assignments, policies and requests. The package id
# is part of the request id for correlation. The Prefer header returns evolvable enum values such as
# the request type 'approverRemove' instead of 'unknownFutureValue'.
$packageKinds = @('roles', 'assignments', 'policies', 'requests')
$packageData = @{}
for ($i = 0; $i -lt $packages.Count; $i++) { $packageData[$i] = @{} }

if ($packages.Count -gt 0) {
    Write-Output ""
    Write-Output "Get Assignments, Requests, Policies and Resource Roles"
    Write-Output "---------------------"
    Write-Output "Reading $($packages.Count) access package(s). This may take a while in large tenants."

    $preferHeaders = @{ Prefer = "include-unknown-enum-members" }
    $packageRequests = for ($i = 0; $i -lt $packages.Count; $i++) {
        $packageId = [uri]::EscapeDataString($packages[$i].Id)
        $packageFilter = [uri]::EscapeDataString("accessPackage/id eq '$($packages[$i].Id)'")
        @{
            id      = "$i|roles"
            method  = "GET"
            url     = "$emBasePath/accessPackages/$($packageId)?`$expand=resourceRoleScopes(`$expand=role,scope)"
            headers = $preferHeaders
        }
        @{
            id      = "$i|assignments"
            method  = "GET"
            url     = "$emBasePath/assignments?`$filter=$packageFilter&`$expand=target,assignmentPolicy"
            headers = $preferHeaders
        }
        @{
            id      = "$i|policies"
            method  = "GET"
            url     = "$emBasePath/assignmentPolicies?`$filter=$packageFilter"
            headers = $preferHeaders
        }
        @{
            id      = "$i|requests"
            method  = "GET"
            url     = "$emBasePath/assignmentRequests?`$filter=$packageFilter&`$expand=requestor,assignment"
            headers = $preferHeaders
        }
    }

    try {
        $packageResponses = @(Invoke-RjRbGraphBatch -Requests @($packageRequests) -ProgressLabel "access package requests" -ProgressInterval 10)
    }
    catch {
        Write-Error "Failed to read the access package details through the Graph batch endpoint: $($_.Exception.Message)" -ErrorAction Continue
        throw "Unable to retrieve the access package details"
    }

    $packageResponseById = @{}
    foreach ($response in $packageResponses) { $packageResponseById["$($response.id)"] = $response }

    # Every request is checked, so a missing response or an unreadable page is recorded instead of
    # shortening a list silently
    for ($i = 0; $i -lt $packages.Count; $i++) {
        foreach ($kind in $packageKinds) {
            $collectionProperty = if ($kind -eq 'roles') { 'resourceRoleScopes' } else { 'value' }
            $result = Get-BatchCollection -Response $packageResponseById["$i|$kind"] -CollectionProperty $collectionProperty
            $packageData[$i][$kind] = $result
            if ($result.Status -ne 'Complete') {
                Write-RjRbLog -Message "WARNING: '$kind' of access package '$($packages[$i].Name)' is $($result.Status.ToLower()): $($result.Reason)" -Verbose
            }
        }
    }
}

# Resources of the catalogs in scope, so groups, applications and sites are shown by name. The role
# scope of a package only names the scope ("Root") and the origin ID of the resource.
$resourceIndex = @{}
$catalogsNotRead = [System.Collections.Generic.List[string]]::new()
$catalogIds = @($packages | Where-Object { $_.CatalogId } | ForEach-Object { $_.CatalogId } | Sort-Object -Unique)
if ($catalogIds.Count -gt 0) {
    Write-Output "Reading the resources of $($catalogIds.Count) catalog(s)..."
    $catalogRequests = for ($c = 0; $c -lt $catalogIds.Count; $c++) {
        @{
            id     = "$c"
            method = "GET"
            url    = "$emBasePath/catalogs/$([uri]::EscapeDataString($catalogIds[$c]))/resources"
        }
    }
    try {
        $catalogResponses = @(Invoke-RjRbGraphBatch -Requests @($catalogRequests) -ProgressLabel "catalogs" -ProgressInterval 10)
    }
    catch {
        Write-RjRbLog -Message "WARNING: The catalog resources could not be read, resources are shown without their names: $($_.Exception.Message)" -Verbose
        $catalogResponses = @()
    }
    $catalogResponseById = @{}
    foreach ($response in $catalogResponses) { $catalogResponseById["$($response.id)"] = $response }

    for ($c = 0; $c -lt $catalogIds.Count; $c++) {
        $result = Get-BatchCollection -Response $catalogResponseById["$c"]
        $index = @{}
        foreach ($resource in $result.Items) {
            $originId = "$($resource.originId)".ToLower()
            if ($originId -and -not $index.ContainsKey($originId)) { $index[$originId] = $resource }
        }
        $resourceIndex[$catalogIds[$c]] = $index
        if ($result.Status -ne 'Complete') {
            $catalogName = "$(@($packages | Where-Object { $_.CatalogId -eq $catalogIds[$c] } | Select-Object -First 1).Catalog)"
            $catalogsNotRead.Add($catalogName)
            Write-RjRbLog -Message "WARNING: Resources of catalog '$catalogName' are $($result.Status.ToLower()): $($result.Reason)" -Verbose
        }
    }
}

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

Write-Output ""
Write-Output "Processing access packages"
Write-Output "---------------------"

$packageRows = [System.Collections.Generic.List[object]]::new()
$assignmentRows = [System.Collections.Generic.List[object]]::new()
$expiredRows = [System.Collections.Generic.List[object]]::new()
$requestRows = [System.Collections.Generic.List[object]]::new()
$roleRows = [System.Collections.Generic.List[object]]::new()
$policyRows = [System.Collections.Generic.List[object]]::new()
$distinctSubjects = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

$now = (Get-Date).ToUniversalTime()
$openRequestStates = @('submitted', 'pendingApproval', 'scheduled', 'delivering')
$addRequestTypes = @('userAdd', 'adminAdd', 'systemAdd', 'onBehalfAdd')
$kindLabels = @{ roles = 'Resource roles'; assignments = 'Assignments'; policies = 'Policies'; requests = 'Requests' }
$expiredTotal = 0
$incompletePackageCount = 0

for ($i = 0; $i -lt $packages.Count; $i++) {
    $package = $packages[$i]
    $data = $packageData[$i]
    $notes = [System.Collections.Generic.List[string]]::new()

    # Each list is 'Complete', 'Incomplete' (some pages missing) or 'Failed'; nothing is dropped silently
    foreach ($kind in $packageKinds) {
        $result = $data[$kind]
        if ($result.Status -eq 'Failed') { $notes.Add("$($kindLabels[$kind]) not readable ($($result.Reason))") }
        elseif ($result.Status -eq 'Incomplete') { $notes.Add("$($kindLabels[$kind]) incomplete ($($result.Reason))") }
    }
    if ($notes.Count -gt 0) { $incompletePackageCount++ }

    $policies = @($data['policies'].Items)
    $policyById = @{}
    foreach ($policy in $policies) { if ($policy.id) { $policyById["$($policy.id)"] = $policy } }

    # The request that created an assignment tells how it came about (user request, admin, auto-assignment)
    $creatingRequest = @{}
    $openRequests = 0
    $pendingApproval = 0
    foreach ($request in @($data['requests'].Items)) {
        $requestType = "$($request.requestType)"
        $assignmentId = "$($request.assignment.id)"
        if ($assignmentId -and $addRequestTypes -contains $requestType) {
            $created = ConvertTo-UtcDateTime -Value $request.createdDateTime
            $known = $creatingRequest[$assignmentId]
            if (-not $known -or ($created -and $known.Created -and $created -lt $known.Created)) {
                $creatingRequest[$assignmentId] = @{ Type = $requestType; Created = $created }
            }
        }

        $requestState = "$($request.state)"
        if ($openRequestStates -contains $requestState) {
            $openRequests++
            if ($requestState -eq 'pendingApproval') { $pendingApproval++ }
            $requestEnd = Get-ScheduleEnd -Schedule $request.schedule
            $requestRows.Add([PSCustomObject][ordered]@{
                    AccessPackage  = $package.Name
                    Catalog        = $package.Catalog
                    Subject        = Get-SubjectName -Subject $request.requestor
                    PrincipalName  = "$($request.requestor.principalName)"
                    Email          = "$($request.requestor.email)"
                    RequestType    = Get-RequestTypeLabel -RequestType $requestType
                    State          = Get-StateLabel -State $requestState
                    Status         = "$($request.status)"
                    Created        = Format-ReportDate -Value $request.createdDateTime
                    RequestedStart = Format-ReportDate -Value $request.schedule.startDateTime
                    RequestedEnd   = $requestEnd.Text
                    Justification  = ("$($request.justification)" -replace '\r?\n', ' ').Trim()
                })
        }
    }

    # Assignments: active ones in one table, expired ones counted and optionally listed
    $packageAssignments = [System.Collections.Generic.List[object]]::new()
    $packageExpired = [System.Collections.Generic.List[object]]::new()
    $policyAssignmentCount = @{}
    $memberCount = 0
    $guestCount = 0
    $servicePrincipalCount = 0
    $expiringCount = 0
    $deliveryProblemCount = 0
    $packageExpiredCount = 0

    foreach ($assignment in @($data['assignments'].Items)) {
        $state = "$($assignment.state)"
        $policy = $assignment.assignmentPolicy
        if ($policy -and $policy.id -and $policyById.ContainsKey("$($policy.id)")) { $policy = $policyById["$($policy.id)"] }
        $subject = $assignment.target
        $subjectType = Get-SubjectType -Subject $subject

        # How the assignment came about: from the creating request, otherwise from the policy when it allows only one way
        $assignedVia = if ($creatingRequest.ContainsKey("$($assignment.id)")) {
            Get-RequestTypeLabel -RequestType $creatingRequest["$($assignment.id)"].Type
        }
        else {
            switch (Get-PolicyType -Policy $policy) {
                'Auto-assignment' { 'Auto-assignment' }
                'Admin assignment only' { 'Admin assignment' }
                default { 'Not recorded' }
            }
        }

        $scheduleEnd = Get-ScheduleEnd -Schedule $assignment.schedule
        $row = [ordered]@{
            AccessPackage = $package.Name
            Catalog       = $package.Catalog
            Subject       = Get-SubjectName -Subject $subject
            PrincipalName = "$($subject.principalName)"
            Email         = "$($subject.email)"
            SubjectType   = $subjectType
            AssignedVia   = $assignedVia
            Policy        = "$($policy.displayName)"
        }

        if ($state -eq 'expired') {
            $packageExpiredCount++
            if ($IncludeExpiredAssignments) {
                $row.Start = Format-ReportDate -Value $assignment.schedule.startDateTime
                $row.End = $scheduleEnd.Text
                $row.ExpiredOn = Format-ReportDate -Value $assignment.expiredDateTime
                $packageExpired.Add([PSCustomObject]$row)
            }
            continue
        }

        $daysLeft = ''
        if ($scheduleEnd.End) {
            $daysLeft = [int][Math]::Floor(($scheduleEnd.End - $now).TotalDays)
            if ($daysLeft -ge 0 -and $daysLeft -le 30) { $expiringCount++ }
        }
        $row.State = Get-StateLabel -State $state
        $row.Status = "$($assignment.status)"
        $row.Start = Format-ReportDate -Value $assignment.schedule.startDateTime
        $row.End = $scheduleEnd.Text
        $row.DaysLeft = $daysLeft
        $packageAssignments.Add([PSCustomObject]$row)

        switch ($subjectType) {
            'Member' { $memberCount++ }
            'Guest' { $guestCount++ }
            'External (not in tenant yet)' { $guestCount++ }
            'Service principal' { $servicePrincipalCount++ }
        }
        if ($state -in @('deliveryFailed', 'partiallyDelivered')) { $deliveryProblemCount++ }
        if ($policy -and $policy.id) { $policyAssignmentCount["$($policy.id)"] = 1 + [int]$policyAssignmentCount["$($policy.id)"] }
        $subjectKey = Get-SubjectKey -Subject $subject
        if ($subjectKey) { [void]$distinctSubjects.Add($subjectKey) }
    }
    $expiredTotal += $packageExpiredCount
    foreach ($row in @($packageAssignments | Sort-Object Subject)) { $assignmentRows.Add($row) }
    foreach ($row in @($packageExpired | Sort-Object Subject)) { $expiredRows.Add($row) }

    # Resource roles: the groups, applications and sites the package grants, with the role in each
    $packageRoleCount = 0
    $catalogResources = if ($package.CatalogId -and $resourceIndex.ContainsKey($package.CatalogId)) { $resourceIndex[$package.CatalogId] } else { @{} }
    $packageRoles = foreach ($roleScope in @($data['roles'].Items)) {
        $role = $roleScope.role
        $scope = $roleScope.scope
        $originId = "$($scope.originId)"
        $resource = if ($originId -and $catalogResources.ContainsKey($originId.ToLower())) { $catalogResources[$originId.ToLower()] } else { $null }
        $isRootScope = ($scope.isRootScope -eq $true) -or ("$($scope.displayName)" -eq 'Root')
        $resourceName = if ($resource -and $resource.displayName) {
            "$($resource.displayName)"
        }
        elseif ($scope.displayName -and -not $isRootScope) {
            "$($scope.displayName)"
        }
        elseif ($originId) {
            $originId
        }
        else {
            'Unknown resource'
        }
        $originSystem = if ($resource -and $resource.originSystem) { "$($resource.originSystem)" } elseif ($scope.originSystem) { "$($scope.originSystem)" } else { "$($role.originSystem)" }
        $roleName = "$($role.displayName)"
        if ($originSystem -in @('AzureResources', 'AzureResource') -and "$($role.type)" -in @('active', 'eligible')) {
            $roleName = "$roleName ($($role.type))"
        }
        $packageRoleCount++
        [PSCustomObject][ordered]@{
            AccessPackage = $package.Name
            Catalog       = $package.Catalog
            Resource      = $resourceName
            ResourceType  = Get-ResourceTypeLabel -OriginSystem $originSystem
            Role          = $roleName
            Scope         = if ($resource -and -not $isRootScope -and $scope.displayName) { "$($scope.displayName)" } else { "" }
            ResourceId    = if ($resource -and $resource.originId) { "$($resource.originId)" } else { $originId }
        }
    }
    foreach ($row in @($packageRoles | Sort-Object ResourceType, Resource, Role)) { $roleRows.Add($row) }

    # Policies: who can get the package, approval, duration and reviews
    foreach ($policy in @($policies | Sort-Object { "$($_.displayName)" })) {
        $policyType = Get-PolicyType -Policy $policy
        $approvalSettings = $policy.requestApprovalSettings
        $approvalStages = @(@($approvalSettings.stages) | Where-Object { $null -ne $_ }).Count
        $approvalText = if ($approvalSettings -and $approvalSettings.isApprovalRequiredForAdd) {
            if ($approvalStages -gt 1) { "Yes ($approvalStages stages)" } else { 'Yes' }
        }
        else {
            'No'
        }
        $isRequestPolicy = ($policyType -eq 'Request')
        $policyRows.Add([PSCustomObject][ordered]@{
                AccessPackage         = $package.Name
                Catalog               = $package.Catalog
                Policy                = "$($policy.displayName)"
                PolicyType            = $policyType
                WhoCanBeAssigned      = Get-TargetScopeLabel -AllowedTargetScope "$($policy.allowedTargetScope)"
                AllowedTargets        = Get-SubjectSetText -SubjectSets $policy.specificAllowedTargets
                UsersCanRequest       = if ($isRequestPolicy -and $policy.requestorSettings.enableTargetsToSelfAddAccess) { 'Yes' } else { 'No' }
                ApprovalRequired      = if ($isRequestPolicy) { $approvalText } else { 'No' }
                Approvers             = if ($isRequestPolicy) { Get-ApproverText -ApprovalSettings $approvalSettings } else { '' }
                JustificationRequired = if ($isRequestPolicy -and $approvalSettings.isRequestorJustificationRequired) { 'Yes' } else { 'No' }
                Expiration            = Get-PolicyExpirationText -Expiration $policy.expiration
                UsersCanExtend        = if ($isRequestPolicy -and $policy.requestorSettings.enableTargetsToSelfUpdateAccess) { 'Yes' } else { 'No' }
                AccessReviews         = Get-ReviewText -ReviewSettings $policy.reviewSettings
                Assignments           = [int]$policyAssignmentCount["$($policy.id)"]
                Created               = Format-ReportDate -Value $policy.createdDateTime
                Modified              = Format-ReportDate -Value $policy.modifiedDateTime
            })
    }

    if ($package.CatalogId -and $catalogsNotRead.Contains($package.Catalog) -and $packageRoleCount -gt 0) {
        $notes.Add("Catalog resources not readable, resources shown by origin ID")
    }

    $packageRows.Add([PSCustomObject][ordered]@{
            AccessPackage      = $package.Name
            Catalog            = $package.Catalog
            Description        = ($package.Description -replace '\r?\n', ' ').Trim()
            Hidden             = $package.Hidden
            Assignments        = $packageAssignments.Count
            Members            = $memberCount
            Guests             = $guestCount
            ServicePrincipals  = $servicePrincipalCount
            ExpiringIn30Days   = $expiringCount
            DeliveryProblems   = $deliveryProblemCount
            ExpiredAssignments = $packageExpiredCount
            OpenRequests       = $openRequests
            PendingApproval    = $pendingApproval
            Policies           = $policies.Count
            ResourceRoles      = $packageRoleCount
            Created            = $package.Created
            Modified           = $package.Modified
            Note               = ($notes -join "; ")
        })
}

$summaryValues = [ordered]@{
    "Access packages"               = $packageRows.Count
    "Active assignments"            = $assignmentRows.Count
    "Distinct assignees"            = $distinctSubjects.Count
    "Member assignments"            = @($assignmentRows | Where-Object { $_.SubjectType -eq 'Member' }).Count
    "Guest assignments"             = @($assignmentRows | Where-Object { $_.SubjectType -in @('Guest', 'External (not in tenant yet)') }).Count
    "Service principal assignments" = @($assignmentRows | Where-Object { $_.SubjectType -eq 'Service principal' }).Count
    "Expiring within 30 days"       = @($packageRows | ForEach-Object { $_.ExpiringIn30Days } | Measure-Object -Sum).Sum
    "Delivery problems"             = @($packageRows | ForEach-Object { $_.DeliveryProblems } | Measure-Object -Sum).Sum
    "Expired assignments"           = $expiredTotal
    "Open requests"                 = $requestRows.Count
    "Pending approval"              = @($requestRows | Where-Object { $_.State -eq 'Pending approval' }).Count
    "Policies"                      = $policyRows.Count
    "Resource roles"                = $roleRows.Count
    "Packages without assignments"  = @($packageRows | Where-Object { $_.Assignments -eq 0 }).Count
    "Packages not fully read"       = $incompletePackageCount
}
foreach ($metric in @($summaryValues.Keys)) {
    if ($null -eq $summaryValues[$metric]) { $summaryValues[$metric] = 0 }
}

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
foreach ($metric in $summaryValues.Keys) {
    Write-Output "$($metric): $($summaryValues[$metric])"
}
Write-RjRbLog -Message "Access packages: $($packageRows.Count); active assignments: $($assignmentRows.Count); expired: $expiredTotal; open requests: $($requestRows.Count); not fully read: $incompletePackageCount" -Verbose

# Gaps are never silent: name them for the requestor
if ($incompletePackageCount -gt 0) {
    Write-RjRbLog -Message "WARNING: The report is incomplete: $incompletePackageCount access package(s) could not be read completely. See the Note column of 'Access packages'." -Verbose
}

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$csvFiles = @()
$xlsxFile = $null
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "AccessPackageAssignments_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$safeTenantName = $tenantDisplayName -replace '[\\/:*?"<>|]', '_'
$fileNameBase = "AccessPackageAssignments_$($safeTenantName)_$(Get-Date -Format 'yyyyMMdd')"

# Same names for the Output Data tables, the worksheets and (without spaces) the CSV files
$reportTables = [ordered]@{
    'Access packages'     = $packageRows
    'Assignments'         = $assignmentRows
    'Expired assignments' = $expiredRows
    'Open requests'       = $requestRows
    'Resource roles'      = $roleRows
    'Policies'            = $policyRows
}

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if (($SendEmailReport -or $CreateDownloadLink) -and $packageRows.Count -gt 0) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    if ($ReportFileFormat -ne 'XLSX only') {
        foreach ($tableName in $reportTables.Keys) {
            $rows = $reportTables[$tableName]
            if ($rows.Count -eq 0) { continue }
            $csvSuffix = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($tableName) -replace ' ', ''
            $csvFile = Join-Path $tempDir "$($fileNameBase)_$($csvSuffix).csv"
            $rows | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
            $csvFiles += $csvFile
            $reportFiles += $csvFile
            Write-RjRbLog -Message "Exported $($rows.Count) row(s) to CSV: $csvFile" -Verbose
        }
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFile = Join-Path $tempDir "$fileNameBase.xlsx"
        $worksheets = [ordered]@{}
        foreach ($tableName in $reportTables.Keys) {
            if ($reportTables[$tableName].Count -gt 0) { $worksheets[$tableName] = @($reportTables[$tableName]) }
        }

        $workbookCoverSheet = [ordered]@{
            Title                 = 'Access Package Assignments'
            Tenant                = $tenantDisplayName
            Generated             = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version'     = $Version
            'Access packages'     = $packageScopeText
            'Expired assignments' = if ($IncludeExpiredAssignments) { 'Listed' } else { 'Counted, not listed' }
        }
        foreach ($metric in $summaryValues.Keys) { $workbookCoverSheet["Count: $metric"] = $summaryValues[$metric] }

        Export-RjRbXlsx -Worksheets $worksheets -Path $xlsxFile -CoverSheet $workbookCoverSheet
        $reportFiles += $xlsxFile
        Write-RjRbLog -Message "Exported $($worksheets.Count) worksheet(s) to XLSX: $xlsxFile" -Verbose
    }

    Write-Output ""
    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
}
elseif ($packageRows.Count -eq 0) {
    Write-RjRbLog -Message "No access packages - skipping the report file export" -Verbose
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
        Write-Output "No access packages - skipping the upload."
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

    $emailSubject = "Access Package Assignments Report - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"

    $previewRows = @($packageRows | Select-Object -First 20)
    $previewTable = if ($previewRows.Count -gt 0) {
        $tableLines = @("| Access package | Catalog | Assignments | Expiring in 30 days | Open requests |", "|---|---|---|---|---|")
        foreach ($row in $previewRows) {
            $tableLines += "| $(ConvertTo-MarkdownCell $row.AccessPackage) | $(ConvertTo-MarkdownCell $row.Catalog) | $($row.Assignments) | $($row.ExpiringIn30Days) | $($row.OpenRequests) |"
        }
        $tableLines -join "`n"
    }
    else {
        "No access packages were found."
    }
    $xlsxFileName = if ($xlsxFile) { Split-Path -Path $xlsxFile -Leaf } else { "the Excel workbook" }

    $summaryLines = @("| Metric | Count |", "|--------|-------|")
    foreach ($metric in $summaryValues.Keys) {
        $summaryLines += "| **$metric** | $($summaryValues[$metric]) |"
    }
    $summaryTable = $summaryLines -join "`n"
    $expiredText = if ($IncludeExpiredAssignments) { "Expired assignments: **listed**" } else { "Expired assignments: **counted, not listed**" }
    $incompleteText = if ($incompletePackageCount -gt 0) {
        "`n> **Note:** $incompletePackageCount access package(s) could not be read completely. The Note column of the access package list names the gaps.`n"
    }
    else {
        ""
    }

    $markdownContent = @"
# Access Package Assignments Report

Tenant: **$tenantDisplayName**

Access packages: **$packageScopeText**

$expiredText
$incompleteText
## Summary

$summaryTable

## Access packages (first $($previewRows.Count) of $($packageRows.Count))

$previewTable

## Attachments

The attached report file(s) contain the access packages, their assignments, open requests, resource roles and assignment policies.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Body used when only the workbook can be attached because the CSV files exceed the attachment size limit
    $markdownFallback = @"
# Access Package Assignments Report

Tenant: **$tenantDisplayName**

Access packages: **$packageScopeText**

$expiredText
$incompleteText
## Summary

$summaryTable

## Attachments

- **$xlsxFileName**: Excel workbook with the complete data set

> **Note:** The CSV files were not attached because they exceed the email attachment size limit. Select the download link option to obtain the CSV files.

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
            # No access packages, no files - still send the report so the recipient knows the run happened
            Send-RjRbReportEmail @emailParams @brandingMailParams
        }
        elseif ($ReportFileFormat -eq 'CSV & XLSX' -and $csvFiles.Count -gt 0 -and $xlsxFile -and (Test-Path -Path $xlsxFile)) {
            # Both formats attached; the built-in size guard falls back to the workbook alone if the set is too large
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

if ($packageRows.Count -eq 0) {
    Write-Output "No access packages found."
}
else {
    $emptyTableTexts = [ordered]@{
        'Access packages'     = "No access packages found."
        'Assignments'         = "No active assignments found."
        'Expired assignments' = if ($IncludeExpiredAssignments) { "No expired assignments found." } else { "" }
        'Open requests'       = "No open requests found."
        'Resource roles'      = "No resource roles found."
        'Policies'            = "No assignment policies found."
    }
    foreach ($tableName in $reportTables.Keys) {
        $rows = $reportTables[$tableName]
        if ($rows.Count -gt 0) {
            Write-Output "$($rows.Count) row(s) in '$tableName':"
            Write-Output ([PSCustomObject]@{ RjTableTitle = $tableName })
            Write-Output @($rows)
        }
        elseif ($emptyTableTexts[$tableName]) {
            Write-Output $emptyTableTexts[$tableName]
        }
    }
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

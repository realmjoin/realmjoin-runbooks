<#
    .SYNOPSIS
    Alert by email on newly announced Microsoft 365 Service Health issues

    .DESCRIPTION
    Queries the Microsoft 365 Service Health issues feed on a schedule and identifies issues whose first Service Health post falls within a configurable lookback window, since Microsoft frequently back-dates the official start time and filtering on that alone would miss alerts. Optionally narrows monitoring to a chosen set of services and sends one alert email per newly detected issue, with the subject naming the tenant and the issue title. All issue details are carried in the email body; the runbook produces no report files.

    .NOTES
    Common Use Cases:
    - Schedule the runbook to run at or slightly more often than LookbackHours to catch every new Service Health issue exactly once.
    - Set Services to a comma-separated list of service names or short ids (matched case-insensitively) to monitor only specific services, such as Exchange Online or Teams; leave it empty to monitor all services.
    - Leave IncludeAdvisories and IncludeResolvedIssues at their default of $false for the lowest-noise setup, which alerts only on unresolved incidents; set either to $true to also surface advisories or issues Microsoft has already marked resolved.

    Parameter Interactions:
    - An issue counts as newly announced when its first Service Health post falls inside the LookbackHours window (falling back to startDateTime if the issue has no posts) - not by lastModifiedDateTime alone. This avoids missing back-dated issues while preventing re-alerts on every status update of an ongoing incident.
    - The runbook keeps no state between runs, so a failed or skipped run means those alerts are never sent unless LookbackHours is temporarily widened for a catch-up run.
    - One email is sent per new issue, so a busy Service Health day can produce several emails per run.

    .PARAMETER Services
    Comma-separated list of Microsoft 365 service names to monitor, for example Microsoft Intune, Microsoft Entra, Exchange Online. Leave empty to monitor all services. Matching is case-insensitive against both the service display name and its short id, so Intune matches Microsoft Intune. Valid names can be found on the Microsoft 365 admin center service health page.

    .PARAMETER LookbackHours
    How many hours back to look for newly announced issues. Set this to the same interval as the runbook schedule, for example 24 for a daily schedule, so that no issue is missed and none is alerted on twice.

    .PARAMETER IncludeAdvisories
    If set to false, only incidents raise an alert. If set to true, advisories are alerted on as well.

    .PARAMETER IncludeResolvedIssues
    If set to false, issues that Microsoft has already marked as resolved by the time the runbook runs are skipped. If set to true, resolved issues are still reported.

    .PARAMETER EmailFrom
    The sender email address used for the per-issue alert emails. This needs to be configured in the runbook customization.

    .PARAMETER BrandingHeaderImageUrl
    Optional public HTTPS URL of a custom header image (PNG/JPEG/GIF, max. 200 KB) for the alert emails.
    Sourced from the RJReport.Branding.HeaderImageUrl tenant setting. When empty, the default RealmJoin header graphic is used.

    .PARAMETER BrandingFooterImageUrl
    Optional public HTTPS URL of a custom footer image (PNG/JPEG/GIF, max. 200 KB) for the alert emails.
    Sourced from the RJReport.Branding.FooterImageUrl tenant setting. When empty, the default RealmJoin footer graphic is used.

    .PARAMETER BrandingFooterLink
    Optional URL the footer image links to. Sourced from the RJReport.Branding.FooterLink tenant setting.
    When empty, the default link (https://www.realmjoin.com) is used.

    .PARAMETER BrandingAccentColor
    Optional accent color override (6-digit hex, e.g. '#0052cc') for the report email template.
    Sourced from the RJReport.Branding.AccentColor tenant setting. When empty or invalid, the default RealmJoin accent color is used.

    .PARAMETER BrandingTextColor
    Optional text color override (6-digit hex) for the report email template.
    Sourced from the RJReport.Branding.TextColor tenant setting. When empty or invalid, the default RealmJoin text color is used.

    .PARAMETER EmailTo
    Comma-separated list of recipient email addresses for the per-issue alert emails. At least one valid recipient is required.

    .PARAMETER CallerName
    Name of the user or system that started the runbook. Tracked for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Services": {
                "DisplayName": "Services to Monitor (comma-separated, leave empty for all)",
                "DefaultValue": ""
            },
            "LookbackHours": {
                "DisplayName": "Lookback Window (hours 1 - 168) - match to schedule interval"
            },
            "IncludeAdvisories": {
                "DisplayName": "Include Advisories (not just Incidents)"
            },
            "IncludeResolvedIssues": {
                "DisplayName": "Include Already-Resolved Issues"
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
            "EmailTo": {
                "DisplayName": "Alert Email Recipient Email Address(es)"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.38.0" }

param (
    [string]$Services,

    [ValidateRange(1, 168)]
    [int]$LookbackHours = 24,

    [bool]$IncludeAdvisories = $false,

    [bool]$IncludeResolvedIssues = $false,

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

    [Parameter(Mandatory = $true)]
    [string]$EmailTo,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.3.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Services: $Services" -Verbose
Write-RjRbLog -Message "LookbackHours: $LookbackHours" -Verbose
Write-RjRbLog -Message "IncludeAdvisories: $IncludeAdvisories" -Verbose
Write-RjRbLog -Message "IncludeResolvedIssues: $IncludeResolvedIssues" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

# A sender address is required before any mail can be sent
if (-not $EmailFrom) {
    Write-Error "The sender email address is required. Configure it in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -ErrorAction Continue
    throw "Missing email sender configuration (RJReport.EmailSender)."
}

# EmailTo is a comma-separated recipient list - split, trim and validate each address before use.
$emailRecipients = @($EmailTo -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

if ($emailRecipients.Count -eq 0) {
    Write-Error "EmailTo is empty. Provide at least one recipient email address." -ErrorAction Continue
    throw "Missing email recipient configuration (EmailTo)."
}

$emailAddressPattern = '^[^@\s]+@[^@\s]+\.[^@\s]+$'
$invalidRecipients = @($emailRecipients | Where-Object { $_ -notmatch $emailAddressPattern })
if ($invalidRecipients.Count -gt 0) {
    Write-Error "The following entries in EmailTo do not look like valid email addresses: $($invalidRecipients -join ', ')" -ErrorAction Continue
    throw "Invalid email address(es) in EmailTo: $($invalidRecipients -join ', ')"
}

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

function ConvertTo-UtcDateTime {
    <#
        .SYNOPSIS
        Parses a Microsoft Graph ISO-8601 timestamp string into a UTC DateTime.

        .DESCRIPTION
        Graph returns timestamps as strings like "2026-07-30T18:58:54.573Z". A bare [datetime] cast
        parses with the current culture and, because of the trailing "Z", converts to LOCAL time
        (Kind=Local). The lookback cutoff in this runbook is a UTC wall-clock value, and DateTime
        comparison ignores Kind and compares ticks, so on any Automation worker not running in UTC a
        bare cast would silently shift the lookback window - missing real alerts west of UTC and
        re-alerting on old ones east of UTC. Every timestamp comparison and display string in this
        runbook goes through this helper so it is genuinely UTC.

        TryParse (not Parse) is used so a malformed timestamp can never throw and abort the run - it
        is treated as missing instead.

        .PARAMETER Value
        The raw timestamp string from the Graph response. May be null or empty.

        .EXAMPLE
        PS C:\> $utc = ConvertTo-UtcDateTime -Value $issue.startDateTime
    #>
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    $parsedUtc = [datetime]::MinValue
    if ([datetime]::TryParse($Value, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal, [ref]$parsedUtc)) {
        return $parsedUtc
    }
    Write-RjRbLog -Message "WARNING: Could not parse Graph timestamp '$($Value)' as a UTC date/time - treating as missing" -NoDebugOnly -Verbose
    return $null
}

function Format-UtcDateTime {
    <#
        .SYNOPSIS
        Formats a Microsoft Graph ISO-8601 timestamp string as a UTC display string.

        .DESCRIPTION
        Wraps ConvertTo-UtcDateTime and renders the result as "yyyy-MM-dd HH:mm:ss" in UTC, or the
        literal string "N/A" when the value is missing or cannot be parsed. This keeps the null
        handling and the UTC guarantee consistent across every exported and emailed timestamp.

        .PARAMETER Value
        The raw timestamp string from the Graph response. May be null or empty.

        .EXAMPLE
        PS C:\> $display = Format-UtcDateTime -Value $issue.lastModifiedDateTime
    #>
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value
    )
    $parsedUtc = ConvertTo-UtcDateTime -Value $Value
    if ($parsedUtc) {
        return $parsedUtc.ToString("yyyy-MM-dd HH:mm:ss")
    }
    return "N/A"
}

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

Write-Output ""
Write-Output "Connect"
Write-Output "---------------------"

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome
}
catch {
    Write-Error "Failed to connect to Microsoft Graph using the managed identity. Ensure the Automation Account's managed identity is enabled and has the required Graph app role assignments (see .permissions.json)." -ErrorAction Continue
    throw
}

Write-Output "Retrieving tenant information..."
$tenantDisplayName = "Unknown Tenant"
try {
    $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
    }
    elseif ($organizationResponse.displayName) {
        $tenantDisplayName = $organizationResponse.displayName
    }
    Write-Output "Tenant: $($tenantDisplayName)"
}
catch {
    Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
}

# Connect-RjRbGraph is required by Send-RjReportEmail, which this runbook always reaches when new
# issues are found.
Write-Output "Graph connection for RJ RunbookHelper..."
try {
    Connect-RjRbGraph
}
catch {
    Write-Error "Failed to establish the RJ RunbookHelper Graph connection required by Send-RjReportEmail. Ensure the managed identity has the 'Mail.Send' app role assignment (see .permissions.json)." -ErrorAction Continue
    throw
}

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

Write-Output ""
Write-Output "Data Collection"
Write-Output "---------------------"

# Service Health timestamps are UTC and an Azure Automation worker is not guaranteed to run in the
# tenant's local time zone, so the whole lookback calculation stays in UTC.
$cutoffDateTime = (Get-Date).ToUniversalTime().AddHours(-$LookbackHours)
$cutoffFilterValue = $cutoffDateTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
Write-Output "Looking for service health issues announced since $cutoffFilterValue (UTC), covering the last $LookbackHours hour(s)."

# The service filter is a comma-separated free-text list, because the RealmJoin portal cannot render a
# multi-picker for values that are not Graph entities.
$serviceFilterList = @()
if (-not [string]::IsNullOrWhiteSpace($Services)) {
    $serviceFilterList = @($Services -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# Pull the catalog of monitorable services. It is used to sanity-check what the operator typed: a typo
# would otherwise silently match nothing and this monitor would stay quiet forever.
$knownServices = @()
try {
    $rawHealthOverviews = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/healthOverviews")
    $knownServices = @($rawHealthOverviews | ForEach-Object { $_.service } | Where-Object { $_ } | Sort-Object -Unique)
    Write-Output "Tenant reports $($knownServices.Count) monitorable service(s)."
}
catch {
    Write-RjRbLog -Message "Could not retrieve the service catalog: $($_.Exception.Message)" -Verbose
    Write-Output "WARNING: Could not retrieve the list of monitorable services - the service filter cannot be verified this run."
}

if ($serviceFilterList.Count -gt 0) {
    Write-Output "Monitoring these services only: $($serviceFilterList -join ', ')"
    if ($knownServices.Count -gt 0) {
        $unmatchedFilters = @($serviceFilterList | Where-Object {
                $filterEntry = $_
                -not (@($knownServices | Where-Object { $_ -like "*$filterEntry*" -or $filterEntry -like "*$_*" }).Count -gt 0)
            })
        if ($unmatchedFilters.Count -gt 0) {
            Write-RjRbLog -Message "WARNING: These entries in 'Services' match no service in this tenant: $($unmatchedFilters -join ', ')" -Verbose
            Write-Output "WARNING: These entries in 'Services' match no service in this tenant and will never produce an alert: $($unmatchedFilters -join ', ')"
            Write-Output "Available services: $($knownServices -join ', ')"
        }
    }
}
else {
    Write-Output "Monitoring all services (no service filter set)."
}

# Fetch every issue touched inside the lookback window. This is deliberately a superset: filtering the
# API on startDateTime alone would miss issues Microsoft back-dates and publishes days later. Which of
# these count as *newly announced* is decided in Data Processing, from each issue's first post.
Write-Output ""
Write-Output "Getting service health issues..."
Write-Output "Note: This may take a while in tenants with many active service health events."

$issuesSelect = "id,title,service,feature,featureGroup,classification,status,isResolved,startDateTime,endDateTime,lastModifiedDateTime,impactDescription,posts"
$issuesUri = "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/issues?`$filter=lastModifiedDateTime ge $cutoffFilterValue&`$select=$issuesSelect"

try {
    $rawIssues = @(Get-GraphPagedResult -Uri $issuesUri)
}
catch {
    Write-Error "Could not retrieve service health issues from Microsoft Graph. Verify the managed identity holds the 'ServiceHealth.Read.All' application permission (see the runbook's .permissions.json). Details: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

Write-Output "Retrieved $($rawIssues.Count) service health issue(s) modified since $cutoffFilterValue (UTC)."

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

Write-Output ""
Write-Output "Data Processing"
Write-Output "---------------------"

# All date/time values below are UTC, formatted "yyyy-MM-dd HH:mm:ss". Every missing/null value in
# $newIssues (text or datetime) is rendered as the literal string "N/A" - never $null or empty string -
# so CSV/XLSX/email consumers always see a consistent placeholder. Timestamps go through the
# ConvertTo-UtcDateTime / Format-UtcDateTime helpers in Function Definitions, never a bare [datetime]
# cast, so the UTC guarantee holds regardless of the Automation worker's time zone.
#
# Note: Where-Object returns $null (not an empty array) when nothing matches, which breaks .Count
# under Set-StrictMode. Every filter result below is wrapped in @( ... ) so counts are always safe.

$totalFetchedCount = @($rawIssues).Count
Write-RjRbLog -Message "Service health issues fetched from Graph (lastModifiedDateTime >= cutoff): $($totalFetchedCount)" -NoDebugOnly -Verbose

# Stage 1: New-issue detection. Data Collection queries "lastModifiedDateTime ge $cutoff" - a superset
# that also catches issues that only received a status update in the window. Microsoft frequently
# back-dates "startDateTime" (e.g. issue CP1227436 has startDateTime = 2026-01-12 but its first post was
# created 2026-02-05), so startDateTime alone is not a reliable "newly announced" signal. Instead: an
# issue counts as newly announced when its EARLIEST post was created inside the lookback window; if it
# has no posts at all, fall back to startDateTime. Everything else - an issue that merely received an
# update inside the window - is dropped here, which is what stops the runbook re-alerting on the same
# incident every run.
$newlyAnnouncedIssues = @($rawIssues | Where-Object {
        $issue = $_
        $posts = @($issue.posts)
        if ($posts.Count -gt 0) {
            $firstPostUtc = @($posts | ForEach-Object { ConvertTo-UtcDateTime $_.createdDateTime } | Where-Object { $_ } | Sort-Object | Select-Object -First 1)
            if ($firstPostUtc.Count -gt 0) {
                $firstPostUtc[0] -ge $cutoffDateTime
            }
            else {
                # No post timestamp on this issue could be parsed - fall back to startDateTime.
                $startUtc = ConvertTo-UtcDateTime $issue.startDateTime
                $startUtc -and $startUtc -ge $cutoffDateTime
            }
        }
        else {
            $startUtc = ConvertTo-UtcDateTime $issue.startDateTime
            $startUtc -and $startUtc -ge $cutoffDateTime
        }
    })
$newlyAnnouncedCount = @($newlyAnnouncedIssues).Count
$droppedNotNewCount = $totalFetchedCount - $newlyAnnouncedCount
Write-RjRbLog -Message "Issues remaining after new-issue detection (first post / startDateTime >= $($cutoffDateTime.ToString('yyyy-MM-dd HH:mm:ss')) UTC): $($newlyAnnouncedCount)" -NoDebugOnly -Verbose
Write-RjRbLog -Message "Issues dropped as not newly announced (only a status update fell inside the window): $($droppedNotNewCount)" -NoDebugOnly -Verbose

# Stage 2: Service filter. An empty $serviceFilterList keeps every service. Matching is case-insensitive
# ("-like" is case-insensitive by default) and accepts a substring match in either direction, so a
# short-hand entry like "Intune" matches the full Graph service name "Microsoft Intune", and vice versa.
if ($serviceFilterList -and $serviceFilterList.Count -gt 0) {
    $serviceFilteredIssues = @($newlyAnnouncedIssues | Where-Object {
            $issueService = $_.service
            if ([string]::IsNullOrEmpty($issueService)) {
                return $false
            }
            $isMatch = $false
            foreach ($filterService in $serviceFilterList) {
                if ([string]::IsNullOrEmpty($filterService)) { continue }
                if ($issueService -like "*$($filterService)*" -or $filterService -like "*$($issueService)*") {
                    $isMatch = $true
                    break
                }
            }
            $isMatch
        })
}
else {
    $serviceFilteredIssues = @($newlyAnnouncedIssues)
}
$serviceFilteredCount = @($serviceFilteredIssues).Count
$serviceFilterLabel = if ($serviceFilterList -and $serviceFilterList.Count -gt 0) { $serviceFilterList -join ', ' } else { 'all services' }
Write-RjRbLog -Message "Issues remaining after service filter ($($serviceFilterLabel)): $($serviceFilteredCount)" -NoDebugOnly -Verbose

# Stage 3: Classification filter. When advisories are excluded, only "incident" classified issues remain.
if ($IncludeAdvisories) {
    $classificationFilteredIssues = @($serviceFilteredIssues)
}
else {
    $classificationFilteredIssues = @($serviceFilteredIssues | Where-Object { $_.classification -eq 'incident' })
}
$classificationFilteredCount = @($classificationFilteredIssues).Count
Write-RjRbLog -Message "Issues remaining after classification filter (IncludeAdvisories=$($IncludeAdvisories)): $($classificationFilteredCount)" -NoDebugOnly -Verbose

# Stage 4: Resolved filter. When resolved issues are excluded, drop anything Graph already marked resolved.
if ($IncludeResolvedIssues) {
    $finalIssues = @($classificationFilteredIssues)
}
else {
    $finalIssues = @($classificationFilteredIssues | Where-Object { -not $_.isResolved })
}
$finalCount = @($finalIssues).Count
Write-RjRbLog -Message "Issues remaining after resolved filter (IncludeResolvedIssues=$($IncludeResolvedIssues)): $($finalCount)" -NoDebugOnly -Verbose

# Transform surviving issues into user-friendly, export-ready objects. Posts arrive inline on each issue
# ($issue.posts) via the $select on the Data Collection query - there is no per-issue posts call.
$newIssues = @($finalIssues | ForEach-Object {
        $issue = $_
        $posts = @($issue.posts)

        $firstPostTimeText = "N/A"
        $latestUpdateText = "N/A"
        $latestUpdateTimeText = "N/A"

        if ($posts.Count -gt 0) {
            # Pair each post with its parsed UTC timestamp once, drop any post whose timestamp could
            # not be parsed, then take the earliest/latest of what remains.
            $postsWithUtc = @($posts | ForEach-Object {
                    [PSCustomObject]@{
                        Post = $_
                        Utc  = ConvertTo-UtcDateTime $_.createdDateTime
                    }
                })
            $validPosts = @($postsWithUtc | Where-Object { $_.Utc })

            if ($validPosts.Count -gt 0) {
                $firstEntry = $validPosts | Sort-Object Utc | Select-Object -First 1
                $latestEntry = $validPosts | Sort-Object Utc -Descending | Select-Object -First 1

                $firstPostTimeText = $firstEntry.Utc.ToString("yyyy-MM-dd HH:mm:ss")
                $latestUpdateTimeText = $latestEntry.Utc.ToString("yyyy-MM-dd HH:mm:ss")

                $rawContent = $latestEntry.Post.description.content
                if (-not [string]::IsNullOrWhiteSpace($rawContent)) {
                    # Strip HTML tags and collapse whitespace so the summary reads cleanly in CSV/XLSX/email.
                    $strippedContent = $rawContent -replace '<[^>]+>', ' '
                    $strippedContent = $strippedContent -replace '&nbsp;', ' '
                    $strippedContent = $strippedContent -replace '\s+', ' '
                    $strippedContent = $strippedContent.Trim()
                    if ($strippedContent.Length -gt 400) {
                        $latestUpdateText = $strippedContent.Substring(0, 400) + "..."
                    }
                    else {
                        $latestUpdateText = $strippedContent
                    }
                }
            }
        }

        [PSCustomObject]@{
            IssueId              = $issue.id
            Title                = if ([string]::IsNullOrEmpty($issue.title)) { "N/A" } else { $issue.title }
            Service              = if ([string]::IsNullOrEmpty($issue.service)) { "N/A" } else { $issue.service }
            Feature              = if ([string]::IsNullOrEmpty($issue.feature)) { "N/A" } else { $issue.feature }
            FeatureGroup         = if ([string]::IsNullOrEmpty($issue.featureGroup)) { "N/A" } else { $issue.featureGroup }
            Classification       = if ([string]::IsNullOrEmpty($issue.classification)) { "N/A" } else { $issue.classification }
            Status               = if ([string]::IsNullOrEmpty($issue.status)) { "N/A" } else { $issue.status }
            IsResolved           = [bool]$issue.isResolved
            StartDateTime        = Format-UtcDateTime $issue.startDateTime
            EndDateTime          = Format-UtcDateTime $issue.endDateTime
            LastModifiedDateTime = Format-UtcDateTime $issue.lastModifiedDateTime
            FirstPostTime        = $firstPostTimeText
            ImpactDescription    = if ([string]::IsNullOrEmpty($issue.impactDescription)) { "N/A" } else { $issue.impactDescription }
            LatestUpdate         = $latestUpdateText
            LatestUpdateTime     = $latestUpdateTimeText
            # Microsoft 365 admin center deep link to the service health issue detail pane.
            AdminCenterLink      = "https://admin.microsoft.com/Adminportal/Home#/servicehealth/:/alerts/$($issue.id)"
        }
    })

Write-Output "Processed $($newIssues.Count) service health issue(s) after filtering"

# Summary statistics for the operator.
Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Total fetched (lastModifiedDateTime >= cutoff): $($totalFetchedCount)"
Write-Output "Newly announced (first post / startDateTime):   $($newlyAnnouncedCount)"
Write-Output "Dropped as not new (update-only):              $($droppedNotNewCount)"
Write-Output "After service filter:                          $($serviceFilteredCount)"
Write-Output "After classification filter:                   $($classificationFilteredCount)"
Write-Output "After resolved filter:                         $($finalCount)"

if ($newIssues.Count -gt 0) {
    Write-Output ""
    Write-Output "Service Health Issues"
    Write-Output "---------------------"
    $newIssues | Sort-Object StartDateTime -Descending | Format-Table -Property IssueId, Service, Classification, Status, IsResolved, StartDateTime -AutoSize | Out-String | Write-Output
    Write-Output ""
    Write-Output "Found $($newIssues.Count) newly announced service health issue(s) matching the criteria"
}
else {
    Write-Output ""
    Write-Output "No newly announced service health issues found matching the criteria."
}

#endregion Data Processing

########################################################
#region     Send Email Report
########################################################

Write-Output ""
Write-Output "Send Email Report"
Write-Output "---------------------"


$brandingMailParams = @{}
if ($newIssues.Count -eq 0) {
    Write-Output "No new service health issues found - no alert emails to send."
}
else {
    $emailToString = $emailRecipients -join ','
    $successCount = 0
    $failureCount = 0

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    foreach ($issue in $newIssues) {
        try {
            $resolvedText = if ($issue.IsResolved) { "Yes" } else { "No" }

            $markdownContent = @"
## $($issue.Title)

- **Service:** $($issue.Service)
- **Feature:** $($issue.Feature)
- **Feature group:** $($issue.FeatureGroup)
- **Classification:** $($issue.Classification)
- **Status:** $($issue.Status)
- **Resolved:** $resolvedText
- **Start:** $($issue.StartDateTime)
- **End:** $($issue.EndDateTime)
- **Last modified:** $($issue.LastModifiedDateTime)
- **First announced:** $($issue.FirstPostTime)
- **Issue ID:** $($issue.IssueId)

**Impact:**
$($issue.ImpactDescription)

**Latest update ($($issue.LatestUpdateTime)):**
$($issue.LatestUpdate)

**Microsoft 365 admin center:** $($issue.AdminCenterLink)

---

*This email was automatically generated. Please do not reply to this email.*
"@

            $emailSubject = "$tenantDisplayName Service Health Issue: $($issue.Title)"

            # Alerts carry no attachments - every detail is in the Markdown body above, so a plain
            # Send-RjReportEmail is used with no attachment-size guard.
            Send-RjReportEmail `
                -EmailFrom $EmailFrom `
                -EmailTo $emailToString `
                -Subject $emailSubject `
                -MarkdownContent $markdownContent `
                -TenantDisplayName $tenantDisplayName `
                -ReportVersion $Version `
                @brandingMailParams

            $successCount++
        }
        catch {
            $failureCount++
            Write-Output "Error sending alert email for issue '$($issue.Title)' ($($issue.IssueId)): $($_.Exception.Message)"
            Write-RjRbLog -Message "Error sending alert email for issue '$($issue.IssueId)': $($_.Exception.Message)" -Verbose
        }
    }

    Write-Output ""
    Write-Output "Alert email summary: $successCount sent, $failureCount failed (of $($newIssues.Count) new issues)."

    if ($failureCount -gt 0 -and $successCount -eq 0) {
        Write-Error "Failed to send any of the $($newIssues.Count) service health alert email(s) to '$emailToString'. Verify that EmailFrom is a valid, licensed sender mailbox, that the runbook's managed identity has been granted the 'Mail.Send' Microsoft Graph application permission, and that every address in EmailTo is a valid, deliverable recipient." -ErrorAction Continue
        throw "Failed to send any of the $($newIssues.Count) service health alert email(s)."
    }
}

#endregion Send Email Report

########################################################
#region     Cleanup
########################################################

Write-Output ""
Write-Output "Cleaning up..."
Write-Output "---------------------"

# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

Disconnect-MgGraph | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

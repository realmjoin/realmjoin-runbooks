<#
    .SYNOPSIS
    Generate report for Endpoint Privilege Management (EPM) elevation requests

    .DESCRIPTION
    Queries Microsoft Intune for EPM elevation requests with flexible filtering options.
    Supports filtering by multiple status types and time range.
    Sends an email report with summary statistics and detailed report file attachments.
    The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
    The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
    When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

    .NOTES
    Runbook Type: Scheduled (recommended: monthly)

    Purpose & Use Cases:
    - Regular reporting of EPM activities
    - Audit trail for approved/denied elevation requests
    - Analysis of expired requests to identify process bottlenecks
    - Identification of frequently requested applications for automatic elevation rules

    Status Types Explained:
    - Pending: Awaits admin decision (use monitor-pending-EPM-requests for time-critical alerting)
    - Approved: Admin approved the request, user can proceed with elevation
    - Denied: Admin rejected the request due to security/policy concerns
    - Expired: Request expired before admin review (may indicate slow response times)
    - Revoked: Previously approved elevation was later revoked by admin
    - Completed: User successfully executed the elevated application after approval

    Data Retention & Time Ranges:
    - Intune retains EPM request details for 30 days after creation
    - For long-term analysis, archive CSV exports outside of Intune
    - Default filter (Approved/Denied/Expired/Revoked, 30 days)

    Email & Export Details:
    - Generates CSV and/or Excel (xlsx) report files with complete request details (see ReportFileFormat)
    - Emails sent individually to each recipient for privacy
    - No email sent when zero requests match the filter criteria
    - Report files include: timestamps, users, devices, applications, justifications, file hashes

    .PARAMETER EmailTo
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization.

    .PARAMETER BrandingHeaderImageUrl
    Optional public HTTPS URL of a custom header image (PNG/JPEG/GIF, max. 200 KB) for the report email.
    Sourced from the RJReport.Branding.HeaderImageUrl tenant setting. When empty, the default RealmJoin header graphic is used.

    .PARAMETER BrandingFooterImageUrl
    Optional public HTTPS URL of a custom footer image (PNG/JPEG/GIF, max. 200 KB) for the report email.
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

    .PARAMETER IncludePending
    Include requests with status "Pending" - Awaiting approval decision.

    .PARAMETER IncludeApproved
    Include requests with status "Approved" - Request has been approved by an administrator.

    .PARAMETER IncludeDenied
    Include requests with status "Denied" - Request was rejected by an administrator.

    .PARAMETER IncludeExpired
    Include requests with status "Expired" - Request expired before approval/denial.

    .PARAMETER IncludeRevoked
    Include requests with status "Revoked" - Previously approved request was revoked.

    .PARAMETER IncludeCompleted
    Include requests with status "Completed" - Request was approved and executed successfully.

    .PARAMETER MaxAgeInDays
    Filter requests created within the last X days (default: 30).
    Note: Request details are retained in Intune for 30 days after creation.

    .PARAMETER ReportFileFormat
    Controls which report file formats are generated and delivered: "CSV only", "CSV & XLSX" (default) or "XLSX only".

    .PARAMETER CreateDownloadLink
    If enabled, the report files are uploaded to an Azure Storage Account and time-limited download links are returned. Disabled by default.

    .PARAMETER ContainerName
    Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

    .PARAMETER ResourceGroupName
    Resource group that contains the storage account. Sourced from the RJReport tenant settings.

    .PARAMETER StorageAccountName
    Storage account name used for the upload. Sourced from the RJReport tenant settings.

    .PARAMETER LinkExpiryDays
    Number of days until the generated download link expires. Sourced from the RJReport tenant settings.

    .PARAMETER CallerName
    Internal parameter for tracking purposes

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"CallerName": {
				"Hide": true
			},
			"EmailTo": {
				"DisplayName": "Recipient Email Address(es)"
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
			"EmailFrom": {
				"Hide": true
			},
			"IncludePending": {
				"DisplayName": "Pending Requests (awaiting approval)"
			},
			"IncludeApproved": {
				"DisplayName": "Approved Requests (approved by admin)"
			},
			"IncludeDenied": {
				"DisplayName": "Denied Requests (rejected by admin)"
			},
			"IncludeExpired": {
				"DisplayName": "Expired Requests (expired before decision)"
			},
			"IncludeRevoked": {
				"DisplayName": "Revoked Requests (approval revoked)"
			},
			"IncludeCompleted": {
				"DisplayName": "Completed Requests (approved and executed)"
			},
			"MaxAgeInDays": {
				"DisplayName": "Filter requests created within last X days (retention: 30 days)"
			},
			"ReportFileFormat": {
				"DisplayName": "Report file format",
				"Select": {
					"Options": [
						{
							"Display": "CSV & XLSX",
							"ParameterValue": "CSV & XLSX"
						},
						{
							"Display": "CSV only",
							"ParameterValue": "CSV only"
						},
						{
							"Display": "XLSX only",
							"ParameterValue": "XLSX only"
						}
					],
					"ShowValue": false
				}
			},
			"CreateDownloadLink": {
				"DisplayName": "Create a file download link (upload report to storage)?",
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
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [bool] $IncludeApproved = $true,
    [bool] $IncludeDenied = $true,
    [bool] $IncludeExpired = $true,
    [bool] $IncludeRevoked = $true,
    [bool] $IncludePending = $false,
    [bool] $IncludeCompleted = $false,
    [int] $MaxAgeInDays = 30,
    [string] $EmailTo,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
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

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'CSV & XLSX',

    [bool] $CreateDownloadLink = $false,

    [string] $ContainerName = "report-epm-elevation-requests",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ } )]
    [string] $ResourceGroupName,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ } )]
    [string] $StorageAccountName,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6
)

########################################################
#region     RJ Log Part
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.3.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
Write-RjRbLog -Message "Include Pending: $IncludePending" -Verbose
Write-RjRbLog -Message "Include Approved: $IncludeApproved" -Verbose
Write-RjRbLog -Message "Include Denied: $IncludeDenied" -Verbose
Write-RjRbLog -Message "Include Expired: $IncludeExpired" -Verbose
Write-RjRbLog -Message "Include Revoked: $IncludeRevoked" -Verbose
Write-RjRbLog -Message "Include Completed: $IncludeCompleted" -Verbose
Write-RjRbLog -Message "Max Age In Days: $MaxAgeInDays" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}

#endregion

########################################################
#region     Parameter Validation
########################################################

# Validate Email Addresses (only if email is requested)
if ($EmailTo -and (-not $EmailFrom)) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -Verbose
    throw "This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings"
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

# Validate that at least one status is selected
if (-not ($IncludePending -or $IncludeApproved -or $IncludeDenied -or $IncludeExpired -or $IncludeRevoked -or $IncludeCompleted)) {
    Write-RjRbLog -Message "At least one status must be selected for the report." -Verbose
    throw "At least one status must be selected for the report."
}

# Validate time range
if ($MaxAgeInDays -lt 1 -or $MaxAgeInDays -gt 30) {
    Write-Warning "MaxAgeInDays should be between 1 and 30. Request information is retained for 30 days in Intune." -Verbose
    if ($MaxAgeInDays -gt 30) {
        Write-RjRbLog -Message "MaxAgeInDays set to 30 (maximum retention period)" -Verbose
        $MaxAgeInDays = 60
    }
}

#endregion

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/applications".

        .EXAMPLE
        PS C:\> $allApps = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/applications"
    #>
    param(
        [string]$Uri
    )

    $allResults = @()
    $nextLink = $Uri

    do {
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        if ($response.value) {
            $allResults += $response.value
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $allResults
}

#endregion

########################################################
#region     Connect and Initialize
########################################################

Write-Output "Connecting to Microsoft Graph..."
Connect-MgGraph -Identity -NoWelcome

Write-Output "Getting basic tenant information..."
# Get tenant information
$tenant = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method GET
if ($tenant.value -and (($(($tenant.value) | Measure-Object).Count) -gt 0)) {
    $tenant = $tenant.value[0]
}
elseif ($tenant.'@odata.context') {
    # Single tenant response
    $tenant = $tenant
}
else {
    Write-Error "Could not retrieve tenant information" -ErrorAction Continue
    throw "Could not retrieve tenant information"
}

$tenantDisplayName = $tenant.displayName
$tenantId = $tenant.id

# Connect RJ RunbookHelper for email reporting
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

#endregion

########################################################
#region     Build Filter and Query EPM Requests
########################################################

Write-Output ""
Write-Output "## Building query filter..."

# Build status filter
$selectedStatuses = @()
if ($IncludePending) { $selectedStatuses += "Pending" }
if ($IncludeApproved) { $selectedStatuses += "Approved" }
if ($IncludeDenied) { $selectedStatuses += "Denied" }
if ($IncludeExpired) { $selectedStatuses += "Expired" }
if ($IncludeRevoked) { $selectedStatuses += "Revoked" }
if ($IncludeCompleted) { $selectedStatuses += "Completed" }

Write-Output "Selected statuses: $($selectedStatuses -join ', ')"

# Build the status filter with OR conditions
$statusFilters = @()
foreach ($status in $selectedStatuses) {
    $statusFilters += "status eq '$status'"
}
$statusFilterString = $statusFilters -join ' or '

# Build the date filter
$dateThreshold = (Get-Date).AddDays(-$MaxAgeInDays)
$dateThresholdString = $dateThreshold.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

Write-Output "Date threshold: Requests created after $($dateThreshold.ToString('yyyy-MM-dd HH:mm:ss'))"

# Combine filters - include both status and date filtering in Graph API
$combinedFilter = "($statusFilterString) and requestCreatedDateTime gt $dateThresholdString"

$filter = [System.Uri]::EscapeDataString($combinedFilter)
$Uri = "https://graph.microsoft.com/beta/deviceManagement/elevationRequests?`$filter=$filter"

Write-Output "Querying EPM elevation requests..."
Write-RjRbLog -Message "Graph API filter: $combinedFilter" -Verbose

$currentDate = Get-Date

try {
    $filteredRequests = Get-GraphPagedResult -Uri $Uri -ErrorAction Stop

    Write-Output "Retrieved $($filteredRequests.Count) request(s) matching filter criteria."

    # If no requests found, exit without sending email
    if ($filteredRequests.Count -eq 0) {
        Write-Output ""
        Write-Output "## No EPM elevation requests found matching the specified criteria."
        Write-Output "No email will be sent as there are no matching requests."
        exit 0
    }

}
catch {
    Write-Error "Failed to retrieve EPM elevation requests: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

#endregion

########################################################
#region     Process and Prepare Data
########################################################

Write-Output ""
Write-Output "## Processing request data..."

# Prepare structured data for display and export
$processedRequests = @()

foreach ($request in $filteredRequests) {
    $requestCreated = if ($request.requestCreatedDateTime) {
        [datetime]$request.requestCreatedDateTime
    } else {
        $null
    }

    $requestModified = if ($request.requestLastModifiedDateTime) {
        [datetime]$request.requestLastModifiedDateTime
    } else {
        $null
    }

    $requestExpiry = if ($request.requestExpiryDateTime) {
        [datetime]$request.requestExpiryDateTime
    } else {
        $null
    }

    $fileName = if ($request.applicationDetail.fileName) {
        $request.applicationDetail.fileName
    } else {
        "Unknown"
    }

    $productName = if ($request.applicationDetail.productName) {
        $request.applicationDetail.productName
    } else {
        "Unknown"
    }

    $processedRequests += [PSCustomObject]@{
        RequestId               = $request.id
        Status                  = $request.status
        RequestedBy             = $request.requestedByUserPrincipalName
        DeviceId                = $request.requestedOnDeviceId
        FileName                = $fileName
        ProductName             = $productName
        FileVersion             = if ($request.applicationDetail.fileVersion) { $request.applicationDetail.fileVersion } else { "N/A" }
        FileHash                = if ($request.applicationDetail.fileHash) { $request.applicationDetail.fileHash } else { "N/A" }
        FilePath                = if ($request.applicationDetail.filePath) { $request.applicationDetail.filePath } else { "N/A" }
        Justification           = if ($request.requestJustification) { $request.requestJustification } else { "None provided" }
        RequestCreated          = $requestCreated
        RequestModified         = $requestModified
        RequestExpiry           = $requestExpiry
        ReviewerName            = if ($request.reviewerJustification) { $request.reviewerJustification } else { "N/A" }
        ReviewerComments        = if ($request.reviewerJustification) { $request.reviewerJustification } else { "N/A" }
    }
}

# Generate statistics by status
$statusStats = $processedRequests | Group-Object -Property Status | Select-Object @{Name='Status';Expression={$_.Name}}, Count

# Display summary
Write-Output ""
Write-Output "## Summary of EPM Elevation Requests:"
Write-Output "Total requests: $($processedRequests.Count)"
foreach ($stat in $statusStats) {
    Write-Output "  - $($stat.Status): $($stat.Count)"
}

#endregion

########################################################
#region     Report File Export (if needed for download link or email)
########################################################

$reportFiles = @()
$csvFilePath = $null
$xlsxFilePath = $null

if ($EmailTo -or $CreateDownloadLink) {
    $fileBaseName = "$(Get-Date -Format 'yyyyMMdd_HHmmss')_EPM_Elevation_Requests_$($tenantDisplayName)"
    $sortedRequests = $processedRequests | Sort-Object -Property RequestCreated

    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath "$($fileBaseName).csv"
        $sortedRequests | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvFilePath
        Write-RjRbLog -Message "Exported requests to CSV: $($csvFilePath)" -Verbose
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath "$($fileBaseName).xlsx"
        $sortedRequests | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Elevation Requests"
        $reportFiles += $xlsxFilePath
        Write-RjRbLog -Message "Exported requests to XLSX: $($xlsxFilePath)" -Verbose
    }
}

#endregion

########################################################
#region     Upload / Download Link (if CreateDownloadLink is enabled)
########################################################

if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
    Write-Output ""
    Write-Output "## Uploading report to storage account..."

    # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
    # transparently connects the managed identity if no Az context is active.
    $uploadResults = Publish-RjRbFilesToStorageContainer `
        -FilePaths $reportFiles `
        -ContainerName $ContainerName `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -LinkExpiryDays $LinkExpiryDays `
        -AddBlobNamePrefix $true

    Write-Output "## Report uploaded to storage account."
    foreach ($uploadResult in $uploadResults) {
        Write-Output "## Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
        $uploadResult.SASLink | Out-String | Write-Output
    }
}

#endregion

########################################################
#region     Send Email Report (if EmailTo is provided)
########################################################

if ($EmailTo) {
    Write-Output ""
    Write-Output "## Preparing email report to send to $($EmailTo)"

    # Build status breakdown table
    $statusBreakdown = $statusStats | ForEach-Object {
        "| $($_.Status) | $($_.Count) |"
    }

    $statusBreakdownTable = @"
| Status | Count |
|--------|-------|
$($statusBreakdown -join "`n")
"@

    # Status descriptions
    $statusDescriptions = @"
### Status Definitions

- **Pending**: Request is awaiting approval decision from an administrator
- **Approved**: Request has been approved by an administrator and elevation is granted
- **Denied**: Request was rejected by an administrator
- **Expired**: Request expired before an approval/denial decision was made
- **Revoked**: Previously approved request was revoked by an administrator
- **Completed**: Request was approved and executed successfully by the user
"@

    # Create markdown content (SUMMARY ONLY - no details)
    $markdownContent = @"
# EPM Elevation Requests Report

Tenant **$($tenantDisplayName)** (ID: $($tenantId))

- Report date: $($currentDate.ToString('yyyy-MM-dd HH:mm'))
- Time range: Last $MaxAgeInDays days (since $($dateThreshold.ToString('yyyy-MM-dd HH:mm')))
- Total requests: **$($processedRequests.Count)**

## Summary Statistics

$statusBreakdownTable

### Additional Metrics

| Metric | Value |
|--------|-------|
| **Unique Users** | $(($processedRequests | Select-Object -ExpandProperty RequestedBy -Unique | Measure-Object).Count) |
| **Unique Devices** | $(($processedRequests | Select-Object -ExpandProperty DeviceId -Unique | Measure-Object).Count) |
| **Applications Requested** | $(($processedRequests | Select-Object -ExpandProperty FileName -Unique | Measure-Object).Count) |

$statusDescriptions

## Report Details

Detailed information about all $($processedRequests.Count) request(s) is available in the attached report file(s).

### Review Process

To review and manage EPM elevation requests:

1. Go to [Intune Admin Center](https://intune.microsoft.com)
2. Navigate to: **Endpoint Security > Endpoint Privilege Management > Elevation requests**
3. Review requests and take appropriate action

## Attachments

The attached report file(s) contain complete details for all matching requests, including:
- Request ID and status
- User and device information
- Application details (file name, version, hash, path)
- Request justification
- Created, modified, and expiry timestamps
- Reviewer comments (if applicable)

---

*This email was automatically generated. Please do not reply to this email.*

"@

    # Build email subject
    $subjectPrefix = if ($IncludePending -and $selectedStatuses.Count -eq 1) {
        "[Action Required]"
    } else {
        ""
    }

    $statusSummary = if ($selectedStatuses.Count -le 2) {
        $selectedStatuses -join " & "
    } else {
        "Status Report"
    }

    $emailSubject = "$subjectPrefix EPM Elevation $statusSummary - $($processedRequests.Count) Request(s) - $($tenantDisplayName)".Trim()

    $markdownFallback = @"
# EPM Elevation Requests Report

Tenant **$($tenantDisplayName)** (ID: $($tenantId))

- Report date: $($currentDate.ToString('yyyy-MM-dd HH:mm'))
- Time range: Last $MaxAgeInDays days (since $($dateThreshold.ToString('yyyy-MM-dd HH:mm')))
- Total requests: **$($processedRequests.Count)**

## Summary Statistics

$statusBreakdownTable

## Attachments

- **$(Split-Path -Path $xlsxFilePath -Leaf)**: Formatted Excel workbook with the complete request details

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*

"@

    # Send email report (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
    Write-Output "Sending report to '$($EmailTo)'..."
    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        $guardParams = @{
            EmailFrom         = $EmailFrom
            EmailTo           = $EmailTo
            Subject           = $emailSubject
            MarkdownContent   = $markdownContent
            TenantDisplayName = $tenantDisplayName
            ReportVersion     = $Version
        }
        if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFilePath) {
            Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFilePath) -FallbackMarkdownContent $markdownFallback
        }
        else {
            Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
        }
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
}

#endregion

########################################################
#region     Cleanup
########################################################
# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

foreach ($reportFilePath in $reportFiles) {
    if ($reportFilePath -and (Test-Path -Path $reportFilePath)) {
        try {
            Remove-Item -Path $reportFilePath -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not remove temporary report file '$reportFilePath': $_"
        }
    }
}

#endregion

Write-Output ""
Write-Output "## Report generation completed successfully."

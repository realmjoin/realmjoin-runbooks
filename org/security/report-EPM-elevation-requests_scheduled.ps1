<#
    .SYNOPSIS
    Report EPM elevation requests by status and age

    .DESCRIPTION
    Collects the Endpoint Privilege Management elevation requests from Intune, filtered by status and by how long ago they were created. An email report carries the counts and the full list as report files. Intune keeps request details for 30 days, so older requests cannot be reported. The report can be sent by email or provided as a download link.

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

    .PARAMETER IncludeApproved
    Includes requests an administrator approved.

    .PARAMETER IncludeDenied
    Includes requests an administrator rejected.

    .PARAMETER IncludeExpired
    Includes requests that expired before a decision was made.

    .PARAMETER IncludeRevoked
    Includes requests whose approval was withdrawn later.

    .PARAMETER IncludePending
    Includes requests that are still waiting for a decision.

    .PARAMETER IncludeCompleted
    Includes requests that were approved and used.

    .PARAMETER MaxAgeInDays
    Only requests created within this many days are reported. Intune keeps request details for 30 days.

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
			"CallerName": {
				"Hide": true
			},
			"EmailTo": {
				"DisplayName": "Recipient email address(es)"
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
				"DisplayName": "Include pending requests?"
			},
			"IncludeApproved": {
				"DisplayName": "Include approved requests?"
			},
			"IncludeDenied": {
				"DisplayName": "Include denied requests?"
			},
			"IncludeExpired": {
				"DisplayName": "Include expired requests?"
			},
			"IncludeRevoked": {
				"DisplayName": "Include revoked requests?"
			},
			"IncludeCompleted": {
				"DisplayName": "Include completed requests?"
			},
			"MaxAgeInDays": {
				"DisplayName": "Created within (days)"
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
				"DisplayName": "Create a download link?",
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
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
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
    [int] $LinkExpiryDays = 6,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
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

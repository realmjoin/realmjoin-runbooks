<#
	.SYNOPSIS
	Report EPM elevation requests by status and age

	.DESCRIPTION
	Collects the Endpoint Privilege Management elevation requests from Intune, filtered by status and by how long ago they were created. The requests are listed per status with a summary of the counts. Intune keeps request details for 30 days, so older requests cannot be reported. The report can be sent by email or provided as a download link.

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
	Only requests created within this many days are reported. Intune keeps request details for 30 days, so a larger value is reduced to 30.

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
			"IncludePending": {
				"DisplayName": "Include pending requests?"
			},
			"IncludeCompleted": {
				"DisplayName": "Include completed requests?"
			},
			"MaxAgeInDays": {
				"DisplayName": "Created within (days)"
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
				"DisplayAfter": "MaxAgeInDays",
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
    [bool] $IncludeApproved = $true,
    [bool] $IncludeDenied = $true,
    [bool] $IncludeExpired = $true,
    [bool] $IncludeRevoked = $true,
    [bool] $IncludePending = $false,
    [bool] $IncludeCompleted = $false,
    [int] $MaxAgeInDays = 30,
    [bool] $SendEmailReport = $false,
    [string] $EmailTo,
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

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'CSV & XLSX',

    [bool] $CreateDownloadLink = $false,

    [string] $ContainerName = "report-epm-elevation-requests",

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
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.4.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "IncludeApproved: $IncludeApproved" -Verbose
Write-RjRbLog -Message "IncludeDenied: $IncludeDenied" -Verbose
Write-RjRbLog -Message "IncludeExpired: $IncludeExpired" -Verbose
Write-RjRbLog -Message "IncludeRevoked: $IncludeRevoked" -Verbose
Write-RjRbLog -Message "IncludePending: $IncludePending" -Verbose
Write-RjRbLog -Message "IncludeCompleted: $IncludeCompleted" -Verbose
Write-RjRbLog -Message "MaxAgeInDays: $MaxAgeInDays" -Verbose
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

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

# Schedules created before the "Report delivery" choice existed pass a recipient but no SendEmailReport.
# For them the recipient alone keeps the email enabled; every newer run passes SendEmailReport explicitly.
$sendEmail = if ($PSBoundParameters.ContainsKey('SendEmailReport')) { $SendEmailReport } else { [bool]$EmailTo }

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

# Validate that at least one status is selected
if (-not ($IncludePending -or $IncludeApproved -or $IncludeDenied -or $IncludeExpired -or $IncludeRevoked -or $IncludeCompleted)) {
    Write-Error "At least one status must be selected for the report." -ErrorAction Continue
    throw "At least one status must be selected for the report."
}

# Validate time range: Intune keeps request details for 30 days, so a longer window adds nothing
if ($MaxAgeInDays -gt 30) {
    Write-Output "WARNING: Intune keeps elevation request details for 30 days - the time range is reduced from $MaxAgeInDays to 30 days."
    $MaxAgeInDays = 30
}
elseif ($MaxAgeInDays -lt 1) {
    Write-Output "WARNING: The time range must be at least 1 day - $MaxAgeInDays is raised to 1 day."
    $MaxAgeInDays = 1
}
Write-RjRbLog -Message "Effective time range: $MaxAgeInDays day(s)" -Verbose

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

function Format-ReportDateTime {
    <#
        .SYNOPSIS
        Formats a timestamp for the Output Data tables, or returns "N/A" when it is empty.

        .PARAMETER Value
        The timestamp.
    #>
    param(
        $Value
    )

    if ($null -eq $Value) { return "N/A" }
    return ([datetime]$Value).ToString("yyyy-MM-dd HH:mm")
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
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity is configured correctly. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

# Tenant display name and ID for the email and the report file names (needs Organization.Read.All)
$tenantDisplayName = "Unknown Tenant"
$tenantId = "unknown"
try {
    $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=id,displayName" -Method GET -ErrorAction Stop
    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
        $tenantId = $organizationResponse.value[0].id
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

$filter = [uri]::EscapeDataString($combinedFilter)
$Uri = "https://graph.microsoft.com/beta/deviceManagement/elevationRequests?`$filter=$filter"

Write-Output "Querying EPM elevation requests..."
Write-RjRbLog -Message "Graph API filter: $combinedFilter" -Verbose

$currentDate = Get-Date

try {
    $filteredRequests = @(Get-GraphPagedResult -Uri $Uri)
}
catch {
    Write-Error "Failed to retrieve EPM elevation requests: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

Write-Output "Retrieved $($filteredRequests.Count) request(s) matching filter criteria."

#endregion Data Collection

########################################################
#region     Data Processing
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
        DeviceName              = if ($request.deviceName) { $request.deviceName } else { "Unknown device ($($request.requestedOnDeviceId))" }
        DeviceId                = $request.requestedOnDeviceId
        FileName                = $fileName
        ProductName             = $productName
        ProductVersion          = if ($request.applicationDetail.productVersion) { $request.applicationDetail.productVersion } else { "N/A" }
        FileHash                = if ($request.applicationDetail.fileHash) { $request.applicationDetail.fileHash } else { "N/A" }
        FilePath                = if ($request.applicationDetail.filePath) { $request.applicationDetail.filePath } else { "N/A" }
        Justification           = if ($request.requestJustification) { $request.requestJustification } else { "None provided" }
        RequestCreated          = $requestCreated
        RequestModified         = $requestModified
        RequestExpiry           = $requestExpiry
        ReviewerName            = if ($request.reviewCompletedByUserPrincipalName) { $request.reviewCompletedByUserPrincipalName } else { "N/A" }
        ReviewerComments        = if ($request.reviewerJustification) { $request.reviewerJustification } else { "N/A" }
    }
}

$sortedRequests = @($processedRequests | Sort-Object -Property RequestCreated)

# Generate statistics by status
$statusStats = $processedRequests | Group-Object -Property Status | Select-Object @{Name = 'Status'; Expression = { $_.Name } }, Count
$uniqueUserCount = @($processedRequests | Select-Object -ExpandProperty RequestedBy -Unique).Count
$uniqueDeviceCount = @($processedRequests | Select-Object -ExpandProperty DeviceId -Unique).Count
$uniqueApplicationCount = @($processedRequests | Select-Object -ExpandProperty FileName -Unique).Count

# Display summary
Write-Output ""
Write-Output "## Summary of EPM Elevation Requests:"
if ($processedRequests.Count -eq 0) {
    Write-Output "No EPM elevation requests found matching the specified criteria."
}
else {
    Write-Output "Total requests: $($processedRequests.Count)"
    foreach ($stat in $statusStats) {
        Write-Output "  - $($stat.Status): $($stat.Count)"
    }
}

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$csvFilePath = $null
$xlsxFilePath = $null
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "EPMElevationRequests_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if (($sendEmail -or $CreateDownloadLink) -and $sortedRequests.Count -gt 0) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    $safeTenantName = $tenantDisplayName -replace '[\\/:*?"<>|]', '_'
    $fileBaseName = "$(Get-Date -Format 'yyyyMMdd_HHmmss')_EPM_Elevation_Requests_$($safeTenantName)"

    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFilePath = Join-Path $tempDir "$($fileBaseName).csv"
        $sortedRequests | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvFilePath
        Write-RjRbLog -Message "Exported requests to CSV: $($csvFilePath)" -Verbose
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFilePath = Join-Path $tempDir "$($fileBaseName).xlsx"
        $sortedRequests | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Elevation Requests"
        $reportFiles += $xlsxFilePath
        Write-RjRbLog -Message "Exported requests to XLSX: $($xlsxFilePath)" -Verbose
    }

    Write-Output ""
    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
}
elseif ($sortedRequests.Count -eq 0) {
    Write-RjRbLog -Message "No matching requests - skipping the report file export" -Verbose
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
        Write-Output "No matching requests - skipping the upload."
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
elseif ($processedRequests.Count -eq 0) {
    Write-Output ""
    Write-Output "No email will be sent as there are no matching requests."
    Write-RjRbLog -Message "No matching requests - email report skipped" -Verbose
}
else {
    Write-Output ""
    Write-Output "## Sending the email report to '$EmailTo'..."

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
| **Unique Users** | $uniqueUserCount |
| **Unique Devices** | $uniqueDeviceCount |
| **Applications Requested** | $uniqueApplicationCount |

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

    $xlsxFileName = if ($xlsxFilePath) { Split-Path -Path $xlsxFilePath -Leaf } else { "the Excel workbook" }
    $markdownFallback = @"
# EPM Elevation Requests Report

Tenant **$($tenantDisplayName)** (ID: $($tenantId))

- Report date: $($currentDate.ToString('yyyy-MM-dd HH:mm'))
- Time range: Last $MaxAgeInDays days (since $($dateThreshold.ToString('yyyy-MM-dd HH:mm')))
- Total requests: **$($processedRequests.Count)**

## Summary Statistics

$statusBreakdownTable

## Attachments

- **$($xlsxFileName)**: Formatted Excel workbook with the complete request details

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Choose a delivery with a download link to obtain the raw CSV file.

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
        if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFilePath -and (Test-Path -Path $xlsxFilePath)) {
            # Both formats attached; the built-in size guard falls back to the workbook alone if the pair is too large
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFilePath) -FallbackMarkdownContent $markdownFallback
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
    "Time range"     = "Last $MaxAgeInDays days (since $($dateThreshold.ToString('yyyy-MM-dd HH:mm')))"
    "Statuses"       = ($selectedStatuses -join ', ')
    "Total requests" = $processedRequests.Count
}
foreach ($status in $selectedStatuses) {
    $summaryValues["$status requests"] = @($processedRequests | Where-Object { $_.Status -eq $status }).Count
}
$summaryValues["Unique users"] = $uniqueUserCount
$summaryValues["Unique devices"] = $uniqueDeviceCount
$summaryValues["Applications requested"] = $uniqueApplicationCount

$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = "$($summaryValues[$metric])" }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

# One table per selected status, with the columns that matter for it (oldest request first)
$colCreated = @{ Name = 'Created'; Expression = { Format-ReportDateTime -Value $_.RequestCreated } }
$colModified = @{ Name = 'LastModified'; Expression = { Format-ReportDateTime -Value $_.RequestModified } }
$colExpiry = @{ Name = 'Expires'; Expression = { Format-ReportDateTime -Value $_.RequestExpiry } }
$statusTables = @(
    @{ Status = "Pending"; Columns = @($colCreated, $colExpiry, 'RequestedBy', 'DeviceName', 'FileName', 'ProductName', 'Justification') }
    @{ Status = "Approved"; Columns = @($colCreated, $colModified, 'RequestedBy', 'DeviceName', 'FileName', 'ProductName', 'Justification', 'ReviewerName', 'ReviewerComments') }
    @{ Status = "Denied"; Columns = @($colCreated, $colModified, 'RequestedBy', 'DeviceName', 'FileName', 'ProductName', 'Justification', 'ReviewerName', 'ReviewerComments') }
    @{ Status = "Expired"; Columns = @($colCreated, $colExpiry, 'RequestedBy', 'DeviceName', 'FileName', 'ProductName', 'Justification') }
    @{ Status = "Revoked"; Columns = @($colCreated, $colModified, 'RequestedBy', 'DeviceName', 'FileName', 'ProductName', 'ReviewerName', 'ReviewerComments') }
    @{ Status = "Completed"; Columns = @($colCreated, $colModified, 'RequestedBy', 'DeviceName', 'FileName', 'ProductName', 'Justification') }
)

foreach ($table in $statusTables) {
    if ($selectedStatuses -notcontains $table.Status) { continue }
    $title = "$($table.Status) requests"
    $statusRequests = @($sortedRequests | Where-Object { $_.Status -eq $table.Status })
    if ($statusRequests.Count -gt 0) {
        $rows = @($statusRequests | Select-Object -Property $table.Columns)
        Write-Output "$($statusRequests.Count) request(s): $title"
        Write-Output ([PSCustomObject]@{ RjTableTitle = $title })
        Write-Output $rows
    }
    else {
        Write-Output "No $($table.Status.ToLower()) requests."
    }
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

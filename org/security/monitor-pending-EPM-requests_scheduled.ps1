<#
	.SYNOPSIS
	Alert by email about pending EPM elevation requests

	.DESCRIPTION
	Checks Intune for Endpoint Privilege Management elevation requests that are still waiting for a decision and sends an email when there are any, so approvers do not miss them. The email can carry a table with the request details and the report files. The report can be sent by email or provided as a download link.

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

	.PARAMETER DetailedReport
	Adds a table with every pending request and attaches the report files. Otherwise the email only states how many requests are pending.

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
			"DetailedReport": {
				"DisplayName": "Include request details?"
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
			"SubscriptionId": {
				"Hide": true
			},
			"LinkExpiryDays": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [bool] $DetailedReport = $false,
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

    [string] $ContainerName = "monitor-pending-epm-requests",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
    [string] $ResourceGroupName,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.SubscriptionId" } )]
    [string] $SubscriptionId,

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

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.4.0"
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
Write-RjRbLog -Message "Detailed Report: $DetailedReport" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "SubscriptionId: $SubscriptionId" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}

#endregion RJ Log Part

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

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
# The report email is sent through this session as well
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity is configured correctly. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

Write-Output "Getting basic tenant information..."
# Get tenant information
# Only the display name and the ID are used (needs Organization.Read.All)
$tenant = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=id,displayName" -Method GET
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

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

Write-Output "## Querying pending EPM elevation requests..."

$currentDate = Get-Date

try {
    $filter = [System.Uri]::EscapeDataString("status eq 'Pending'")
    $Uri = "https://graph.microsoft.com/beta/deviceManagement/elevationRequests?`$filter=$filter"

    # @() keeps a single request an array, so .Count is the number of requests
    $pendingRequests = @(Get-GraphPagedResult -Uri $Uri)

    Write-Output "Found $($pendingRequests.Count) pending elevation request(s)."

    # Without pending requests no report files are created and no email is sent
    if ($pendingRequests.Count -eq 0) {
        Write-Output ""
        Write-Output "## No pending EPM elevation requests found."
        Write-Output "No email will be sent as there are no pending requests."
    }

}
catch {
    Write-Error "Failed to retrieve EPM elevation requests: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

# Prepare structured data for display and export
$processedRequests = @()
# Device names for the Output Data table only (the report files keep their columns)
$requestDeviceNames = @{}

foreach ($request in $pendingRequests) {
    $requestDeviceNames["$($request.id)"] = $request.deviceName

    $requestCreated = if ($request.requestCreatedDateTime) {
        [datetime]$request.requestCreatedDateTime
    } else {
        $null
    }

    $requestExpiry = if ($request.requestExpiryDateTime) {
        [datetime]$request.requestExpiryDateTime
    } else {
        $null
    }

    $daysUntilExpiry = if ($requestExpiry) {
        [math]::Floor(($requestExpiry - $currentDate).TotalDays)
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
        RequestedBy             = $request.requestedByUserPrincipalName
        DeviceId                = $request.requestedOnDeviceId
        FileName                = $fileName
        ProductName             = $productName
        FileHash                = if ($request.applicationDetail.fileHash) { $request.applicationDetail.fileHash } else { "N/A" }
        Justification           = if ($request.requestJustification) { $request.requestJustification } else { "None provided" }
        RequestCreated          = $requestCreated
        RequestExpiry           = $requestExpiry
        DaysUntilExpiry         = $daysUntilExpiry
        Status                  = $request.status
    }
}

# Display summary
if ($processedRequests.Count -gt 0) {
    Write-Output ""
    Write-Output "## Summary of Pending EPM Elevation Requests:"
    Write-Output "Total pending requests: $($processedRequests.Count)"
}

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$csvFilePath = $null
$xlsxFilePath = $null

if (($EmailTo -or $CreateDownloadLink) -and $processedRequests.Count -gt 0) {
    $fileBaseName = "$(Get-Date -Format 'yyyyMMdd_HHmmss')_PendingEPMRequests_$($tenantDisplayName)"

    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath "$($fileBaseName).csv"
        $processedRequests | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvFilePath
        Write-RjRbLog -Message "Exported pending requests to CSV: $($csvFilePath)" -Verbose
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath "$($fileBaseName).xlsx"
        $processedRequests | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Pending Requests"
        $reportFiles += $xlsxFilePath
        Write-RjRbLog -Message "Exported pending requests to XLSX: $($xlsxFilePath)" -Verbose
    }
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
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
        -SubscriptionId $SubscriptionId `
        -LinkExpiryDays $LinkExpiryDays `
        -AddBlobNamePrefix $true

    Write-Output "## Report uploaded to storage account."
    foreach ($uploadResult in $uploadResults) {
        Write-Output "## Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
        $uploadResult.SASLink | Out-String | Write-Output
    }
}

#endregion Upload / Download Link

########################################################
#region     Send Email Report
########################################################

if ($EmailTo -and $processedRequests.Count -gt 0) {
    Write-Output ""
    Write-Output "## Preparing email report to send to $($EmailTo)"

    # Build markdown table for detailed view
    $detailedTable = if ($DetailedReport -and $processedRequests.Count -gt 0) {
        $sortedRequests = $processedRequests | Sort-Object -Property RequestCreated
        $maxRowsInEmail = 10
        $displayRequests = if ($sortedRequests.Count -gt $maxRowsInEmail) {
            $sortedRequests | Select-Object -First $maxRowsInEmail
        } else {
            $sortedRequests
        }

        $rows = foreach ($req in $displayRequests) {
            $createdText = if ($req.RequestCreated) { $req.RequestCreated.ToString("yyyy-MM-dd HH:mm") } else { "Unknown" }
            $expiryText = if ($req.RequestExpiry) {
                "$($req.RequestExpiry.ToString('yyyy-MM-dd HH:mm')) ($($req.DaysUntilExpiry) days)"
            } else {
                "Unknown"
            }
            $justificationText = $req.Justification -replace '\|', '&#124;' -replace '\n', ' ' -replace '\r', ''

            "| $createdText | $($req.RequestedBy) | $($req.FileName) | $($req.DeviceId) | $expiryText | $justificationText |"
        }

        $additionalRowsNote = if ($sortedRequests.Count -gt $maxRowsInEmail) {
            "`n`nShowing first $maxRowsInEmail of $($sortedRequests.Count) pending requests. See the attached report file(s) for the complete list."
        } else {
            ""
        }

        @"

## Detailed Request Information

| Created | Requested By | File Name | DeviceId | Expires | Justification |
|---------|--------------|-----------|----------|---------|---------------|
$($rows -join "`n")$additionalRowsNote

"@
    } else {
        ""
    }

    # Create markdown content
    $markdownContent = @"
# Pending EPM Elevation Requests Report

Tenant **$($tenantDisplayName)** (ID: $($tenantId))

- Report date: $($currentDate.ToString('yyyy-MM-dd HH:mm'))
- Pending requests: **$($processedRequests.Count)**

## Summary

There are currently **$($processedRequests.Count)** pending Endpoint Privilege Management elevation request(s) awaiting review.

### Statistics

| Metric | Value |
|--------|-------|
| **Total Pending Requests** | $($processedRequests.Count) |
| **Unique Users** | $(($processedRequests | Select-Object -ExpandProperty RequestedBy -Unique | Measure-Object).Count) |
| **Unique Devices** | $(($processedRequests | Select-Object -ExpandProperty DeviceId -Unique | Measure-Object).Count) |
| **Applications Requested** | $(($processedRequests | Select-Object -ExpandProperty FileName -Unique | Measure-Object).Count) |

$detailedTable

## Next Steps

**1. Access Intune Admin Center:**

- Go to [Intune Admin Center](https://intune.microsoft.com)
- Navigate to: Endpoint Security > Endpoint Privilege Management > Elevation requests

**2. Review Each Request:**

- Verify user identity and business need
- Check application details and file hash
- Review justification provided by the user

**3. Take Action:**

- Approve legitimate requests
- Deny suspicious or unjustified requests
- Add approved items to EPM automatic elevation rules if appropriate

$(if ($DetailedReport) {
@"

## Attachments

The report file(s) attached to this email contain the complete list of pending elevation requests for further analysis and tracking.
"@
} else {
@"

## Detailed Information

To receive detailed request information including a report file export, enable the "Include detailed request information" option in the runbook parameters.
"@
})

---

*This email was automatically generated. Please do not reply to this email.*

"@

    # Send email report (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
    $emailSubject = "[Action Required] $($processedRequests.Count) Pending EPM Elevation Request(s) - $($tenantDisplayName)"

    Write-Output "Sending report to '$($EmailTo)'..."
    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        if ($DetailedReport -and $reportFiles.Count -gt 0) {
            $markdownFallback = @"
# Pending EPM Elevation Requests Report

Tenant **$($tenantDisplayName)** (ID: $($tenantId))

- Report date: $($currentDate.ToString('yyyy-MM-dd HH:mm'))
- Pending requests: **$($processedRequests.Count)**

## Summary

There are currently **$($processedRequests.Count)** pending Endpoint Privilege Management elevation request(s) awaiting review.

## Attachments

- **$(Split-Path -Path $xlsxFilePath -Leaf)**: Formatted Excel workbook with the complete list of pending elevation requests

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*

"@

            $guardParams = @{
                EmailFrom             = $EmailFrom
                EmailTo               = $EmailTo
                Subject               = $emailSubject
                MarkdownContent       = $markdownContent
                TenantDisplayName     = $tenantDisplayName
                ReportVersion         = $Version
                UseNativeGraphRequest = $true
            }
            if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFilePath) {
                Send-RjRbReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFilePath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjRbReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
            }
        }
        else {
            Send-RjRbReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version -UseNativeGraphRequest @brandingMailParams
            Write-Output "Email report sent successfully to: $EmailTo"
        }
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
}

#endregion Send Email Report

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the progress output. Every table has its own
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
$summaryRows = @(
    [PSCustomObject]@{ Metric = "Pending requests"; Value = "$($processedRequests.Count)" }
    [PSCustomObject]@{ Metric = "Unique users"; Value = "$(($processedRequests | Select-Object -ExpandProperty RequestedBy -Unique | Measure-Object).Count)" }
    [PSCustomObject]@{ Metric = "Unique devices"; Value = "$(($processedRequests | Select-Object -ExpandProperty DeviceId -Unique | Measure-Object).Count)" }
    [PSCustomObject]@{ Metric = "Applications requested"; Value = "$(($processedRequests | Select-Object -ExpandProperty FileName -Unique | Measure-Object).Count)" }
)
Write-Output ""
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

# The request list is part of the detailed report only; the Summary above is written on every run
if ($DetailedReport -and $processedRequests.Count -gt 0) {
    # Oldest request first
    $requestRows = @($processedRequests | Sort-Object -Property RequestCreated | Select-Object -Property @(
            @{ Name = 'RequestCreated'; Expression = { if ($_.RequestCreated) { $_.RequestCreated.ToString('yyyy-MM-dd HH:mm:ss') } else { "Unknown" } } }
            'RequestedBy'
            'FileName'
            'ProductName'
            @{ Name = 'DeviceName'; Expression = { "$($requestDeviceNames["$($_.RequestId)"])" } }
            'DeviceId'
            @{ Name = 'RequestExpiry'; Expression = { if ($_.RequestExpiry) { $_.RequestExpiry.ToString('yyyy-MM-dd HH:mm:ss') } else { "Unknown" } } }
            @{ Name = 'DaysUntilExpiry'; Expression = { "$($_.DaysUntilExpiry)" } }
            'Justification'
            'FileHash'
            'RequestId'
        ))
    Write-Output ""
    Write-Output "## Detailed list:"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Pending Requests" })
    Write-Output $requestRows
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

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

<#
	.SYNOPSIS
	List the groups this user owns

	.DESCRIPTION
	Lists the Entra ID groups this user owns, with their names, IDs and type (Microsoft 365, security or distribution). Every run shows the list as Output Data tables in the portal. Nothing is changed. The report can be sent by email or provided as a download link.

	.PARAMETER UserName
	User principal name of the user the runbook acts on. Set by the portal from the selected user.

	.PARAMETER SendMail
	Send the report to the recipient email address. Set by the "Report delivery" selection; schedules and API calls can pass it directly.

	.PARAMETER ReportFileFormat
	Deliver the report as CSV, as an Excel workbook, or both.

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

	.PARAMETER CreateDownloadLink
	Also upload the report and return a download link that expires after a few days. Set by the "Report delivery" selection; schedules and API calls can pass it directly.

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
			"UserName": {
				"Hide": true
			},
			"SendMail": {
				"Hide": true
			},
			"CreateDownloadLink": {
				"Hide": true
			},
			"ReportFileFormat": {
				"DisplayName": "Report file format",
				"Hide": true,
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
			"EmailTo": {
				"DisplayName": "Recipient email address(es)",
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
			"EmailFrom": {
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
				"DisplayAfter": "SendMail",
				"Select": {
					"Options": [
						{
							"Display": "Output Data only",
							"ParameterValue": "Output Data only",
							"Customization": {
								"Default": { "SendMail": false, "CreateDownloadLink": false },
								"Hide": [ "EmailTo", "ReportFileFormat" ]
							}
						},
						{
							"Display": "Also email the report",
							"ParameterValue": "Also email the report",
							"Customization": {
								"Default": { "SendMail": true, "CreateDownloadLink": false },
								"Show": [ "EmailTo", "ReportFileFormat" ],
								"Mandatory": [ "EmailTo" ]
							}
						},
						{
							"Display": "Also create a download link",
							"ParameterValue": "Also create a download link",
							"Customization": {
								"Default": { "SendMail": false, "CreateDownloadLink": true },
								"Show": [ "ReportFileFormat" ],
								"Hide": [ "EmailTo" ]
							}
						},
						{
							"Display": "Also email & download link",
							"ParameterValue": "Also email & download link",
							"Customization": {
								"Default": { "SendMail": true, "CreateDownloadLink": true },
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
    [Parameter(Mandatory = $true)]
    [String] $UserName,

    [bool] $SendMail = $false,

    [Parameter(Mandatory = $false)]
    [string] $EmailTo,

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

    [bool] $CreateDownloadLink = $false,

    [string] $ContainerName = "user-group-ownerandmemberships",

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

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.5.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "SendMail: $SendMail" -Verbose
if ($SendMail) {
    Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
    Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
}
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

# A recipient and a configured sender are required to send an email report
if ($SendMail) {
    if (-not $EmailTo) {
        throw "A recipient email address (EmailTo) is required when 'Send the report via email' is enabled."
    }
    if (-not $EmailFrom) {
        Write-Warning -Message "The sender email address is required to send an email report. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -Verbose
        throw "The sender email address (EmailFrom) needs to be configured in the runbook customization."
    }
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

Write-Output "## Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity is configured correctly. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

# Tenant display name for the report email header; only needed when the report is emailed
$tenantDisplayName = "Unknown Tenant"
if ($SendMail) {
    try {
        $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
        if ($organizationResponse.value -and $organizationResponse.value[0].displayName) {
            $tenantDisplayName = $organizationResponse.value[0].displayName
        }
    }
    catch {
        Write-RjRbLog -Message "Failed to retrieve tenant display name: $($_.Exception.Message)" -Verbose
    }
}

if ($CreateDownloadLink) {
    try {
        Write-Output "Connecting to Azure (RealmJoin)..."
        Connect-RjRbAzAccount
    }
    catch {
        Write-Error "Failed to connect to Azure (RealmJoin): $_"
        throw $_
    }
}

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

try {
    $User = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($UserName))" -Method GET -ErrorAction Stop
}
catch {
    Write-Error "Failed to retrieve user '$UserName': $($_.Exception.Message)" -ErrorAction Continue
    throw
}
$OwnedGroups = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users/$($User.id)/ownedObjects/microsoft.graph.group/"

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

# Build a structured report object per owned group (used for console output, Output Data, CSV file, and email)
$reportData = @()
if ($OwnedGroups) {
    $reportData = foreach ($OwnedGroup in $OwnedGroups) {
        $groupType = if ($OwnedGroup.groupTypes -contains "Unified") {
            "M365"
        } elseif ($OwnedGroup.securityEnabled -and -not $OwnedGroup.mailEnabled) {
            "Security"
        } elseif ($OwnedGroup.mailEnabled) {
            "Distribution"
        } else {
            "Other"
        }

        [PSCustomObject]@{
            DisplayName = $OwnedGroup.displayName
            ID          = $OwnedGroup.id
            Type        = $groupType
        }
    }
    $reportData = @($reportData)
}

"## Listing group ownerships for '$($User.userPrincipalName)':"
if ($reportData.Count -gt 0) {
    foreach ($item in $reportData) {
        "## Group '$($item.DisplayName)' with id '$($item.ID)'"
    }
} else {
    "## User is not an owner of any groups."
}

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

# The report files are only needed when they will be uploaded and/or attached to an email
$csvFilePath = $null
$xlsxFilePath = $null
$reportFiles = @()
if (($SendMail -or $CreateDownloadLink) -and $reportData.Count -gt 0) {
    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFileName = "group-ownerships_$($User.userPrincipalName)_$(Get-Date -Format 'yyyyMMdd').csv"
        $csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath $csvFileName
        $reportData | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvFilePath
        Write-RjRbLog -Message "Exported $($reportData.Count) groups to CSV: $csvFilePath" -Verbose
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFileName = "group-ownerships_$($User.userPrincipalName)_$(Get-Date -Format 'yyyyMMdd').xlsx"
        $xlsxFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath $xlsxFileName
        $reportData | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Group Ownerships"
        $reportFiles += $xlsxFilePath
        Write-RjRbLog -Message "Exported $($reportData.Count) groups to XLSX: $xlsxFilePath" -Verbose
    }
}
elseif (($SendMail -or $CreateDownloadLink) -and $reportData.Count -eq 0) {
    Write-Output ""
    Write-Output "## No groups found - skipping report export, upload and email."
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

if ($SendMail -and $reportFiles.Count -gt 0) {
    Write-Output ""
    Write-Output "## Preparing email report to send to '$($EmailTo)'..."

    $subject = "Group Ownerships - $($User.userPrincipalName) - $(Get-Date -Format 'yyyy-MM-dd')"

    $markdownContent = @"
# Group Ownerships Report

**User:** $($User.userPrincipalName)
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary
- Groups owned by the user: **$($reportData.Count)**

The report file(s) are attached for your review.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    $markdownFallback = @"
# Group Ownerships Report

**User:** $($User.userPrincipalName)
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary
- Groups owned by the user: **$($reportData.Count)**

- **$($xlsxFileName)**: Formatted Excel workbook with the complete report

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        # -UseNativeGraphRequest sends through the Connect-MgGraph session established above
        $guardParams = @{
            EmailFrom             = $EmailFrom
            EmailTo               = $EmailTo
            Subject               = $subject
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
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to send email report: $($_.Exception.Message)"
    }
}

#endregion Send Email Report

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the progress output. Every table has its own
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
Write-Output ""

$summaryRows = @(
    [PSCustomObject]@{ Metric = "Groups owned by the user"; Value = $reportData.Count }
    [PSCustomObject]@{ Metric = "Microsoft 365 groups"; Value = @($reportData | Where-Object { $_.Type -eq 'M365' }).Count }
    [PSCustomObject]@{ Metric = "Security groups"; Value = @($reportData | Where-Object { $_.Type -eq 'Security' }).Count }
    [PSCustomObject]@{ Metric = "Distribution groups"; Value = @($reportData | Where-Object { $_.Type -eq 'Distribution' }).Count }
    [PSCustomObject]@{ Metric = "Other groups"; Value = @($reportData | Where-Object { $_.Type -eq 'Other' }).Count }
)
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($reportData.Count -gt 0) {
    # Same rows and columns as the CSV file and the "Group Ownerships" worksheet
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Group Ownerships" })
    Write-Output $reportData
}
else {
    Write-Output "No group ownerships were found for '$($User.userPrincipalName)'."
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

if ($CreateDownloadLink) {
    Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
}

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup
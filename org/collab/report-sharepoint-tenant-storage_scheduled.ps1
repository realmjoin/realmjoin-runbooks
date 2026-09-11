<#
	.SYNOPSIS
	Monitor SharePoint Online tenant storage and alert when thresholds are exceeded

	.DESCRIPTION
	Scheduled monitor for SharePoint Online tenant storage capacity and usage. Connects to the SharePoint admin center using managed identity, retrieves the tenant storage quota and the top site collections by consumed storage, and reports the full inventory to the runbook output on every run. An alert email is sent only when free storage falls below the configured low-storage limit or unused licensed storage rises above the configured reclaimable threshold.

	.PARAMETER AlertLowStorageLimitInMB
	Low-storage alert threshold in megabytes. An alert email is sent when free tenant storage falls below this limit.

	.PARAMETER AlertUnusedStorageLimitInMB
	Unused-storage alert threshold in megabytes. An alert email is sent when unused licensed storage (storage assigned but not consumed by any site) rises above this limit, indicating storage that could be reclaimed.

	.PARAMETER TopSiteCount
	Number of site collections to report, ordered by consumed storage. Default is 10.

	.PARAMETER EmailFrom
	The sender email address. This needs to be configured in the runbook customization.

	.PARAMETER BrandingHeaderImageUrl
	URL of a custom header image for report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

	.PARAMETER BrandingFooterImageUrl
	URL of a custom footer image for report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

	.PARAMETER BrandingFooterLink
	Link target applied to the footer image in report emails, for example the company website. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

	.PARAMETER BrandingAccentColor
	Accent color used for headings and highlights in report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

	.PARAMETER BrandingTextColor
	Body text color used in report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

	.PARAMETER AlertEmailTo
	Recipient email address for alert emails. Emails are sent only when storage thresholds are exceeded.

	.PARAMETER AlertEmailSubject
	Subject line for alert emails.

	.PARAMETER CallerName
	Name of the user or system that started the runbook. Tracked for auditing purposes.

	.INPUTS
	RunbookCustomization: {

			"AlertLowStorageLimitInMB": {
				"DisplayName": "Alert when free storage falls below (MB)"
			},
			"AlertUnusedStorageLimitInMB": {
				"DisplayName": "Alert when unused storage rises above (MB)"
			},
			"TopSiteCount": {
				"DisplayName": "Number of top site collections to report"
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
			"AlertEmailTo": {
				"DisplayName": "Alert recipient email address"
			},
			"AlertEmailSubject": {
				"DisplayName": "Alert email subject"
			},
			"CallerName": {
				"Hide": true
			}
		}
	}

	.NOTES
	Common Use Cases:
	- Scheduled daily health check of SharePoint Online tenant storage, alerting only when a
	  threshold is breached.
	- Spotting a tenant approaching its storage quota before users are blocked from saving files.
	- Spotting a large amount of unused, potentially reclaimable licensed storage.

	Runbook Type: Scheduled (recommended: daily). The storage summary and the top site collections
	are written to the runbook output on every run regardless of whether a threshold is breached, so
	job history remains useful even on days with no alert.

	Parameter Interactions:
	- AlertLowStorageLimitInMB alerts when free tenant storage drops below the configured value.
	- AlertUnusedStorageLimitInMB alerts when free tenant storage rises above the configured value
	  (an indicator of reclaimable licensed storage); set it to 0 to disable this check.
	- Both checks can fire in the same run only if AlertLowStorageLimitInMB is configured higher than
	  AlertUnusedStorageLimitInMB - review both values together when tuning thresholds.
	- The alert email is sent only when at least one threshold is breached; a run with no breach
	  completes normally and sends nothing.
	- The top site collections list covers SharePoint site collections only; OneDrive for Business
	  sites are excluded because their storage does not count against the tenant storage quota this
	  runbook monitors.


	Notes and Limitations:
	- Get-PnPTenantSite does not reliably report a site's creation date on every tenant or module
	  version; the report shows "Unknown" for that site when this occurs.
	- Enumerating all site collections can take several minutes in tenants with a large number of
	  sites.
#>
#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "PnP.PowerShell"; ModuleVersion = "3.4.1" }

param(

    [Parameter(Mandatory = $true)]
    [int]$AlertLowStorageLimitInGB = 200,

    [int]$AlertUnusedStorageLimitInGB = 1024,

    [ValidateRange(1, 100)]
    [int]$TopSiteCount = 10,

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
    [string]$AlertEmailTo,

    [Parameter(Mandatory = $true)]
    [string]$AlertEmailSubject = "RealmJoin - SharePoint Online Storage Alert",

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.3.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "AlertLowStorageLimitInMB: $AlertLowStorageLimitInMB" -Verbose
Write-RjRbLog -Message "AlertUnusedStorageLimitInMB: $AlertUnusedStorageLimitInMB" -Verbose
Write-RjRbLog -Message "TopSiteCount: $TopSiteCount" -Verbose

Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "AlertEmailTo: $AlertEmailTo" -Verbose
Write-RjRbLog -Message "AlertEmailSubject: $AlertEmailSubject" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################
# A sender address is required before any alert mail can be sent
if ($AlertEmailTo -and -not $EmailFrom) {
    Write-Error -ErrorAction Continue -Message "Cannot send the storage alert to '$AlertEmailTo': no sender address is configured. Configure the 'RJReport.EmailSender' RealmJoin setting before this scheduled runbook can send alert emails - without it, every run will collect storage data successfully but silently fail to notify anyone. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
    throw "Missing email sender configuration (RJReport.EmailSender)."
}
#endregion Parameter Validation

########################################################
#region     Connect Part
########################################################
Write-Output "Connecting to SharePoint Online (PnP.PowerShell)..."

Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
$mgSPOrootSiteResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/sites/root"
$SharePointAdminUrl = $mgSPOrootSiteResponse["webUrl"]
$SharePointAdminUrl = $SharePointAdminUrl.Replace(".sharepoint.com","-admin.sharepoint.com")
Write-RjRbLog -Message "SharePointAdminUrl: $SharePointAdminUrl" -Verbose

if ([string]::IsNullOrWhiteSpace($SharePointAdminUrl)) {
    Write-Error "SharePointAdminUrl is not discovered." -ErrorAction Continue
    throw "SharePointAdminUrl is not configured"
}


if ([string]::IsNullOrWhiteSpace($SharePointAdminUrl)) {
    Write-Error "SharePointAdminUrl is not configured. Set the 'RJRunbook.SharePoint.AdminUrl' RealmJoin setting to the tenant's SharePoint admin center URL (e.g. https://contoso-admin.sharepoint.com) before running this runbook." -ErrorAction Continue
    throw "SharePointAdminUrl is not configured"
}

try {
    $VerbosePreference = "SilentlyContinue"
    Connect-PnPOnline -Url $SharePointAdminUrl -ManagedIdentity -ErrorAction Stop
    $VerbosePreference = "Continue"
}
catch {
    $connectError = $_
    $connectErrorMessage = $connectError.Exception.Message
    if ($connectError.Exception.InnerException) { $connectErrorMessage += " " + $connectError.Exception.InnerException.Message }
    if ($connectErrorMessage -like "*Access denied*" -or $connectErrorMessage -like "*403*" -or $connectErrorMessage -like "*Unauthorized*" -or $connectErrorMessage -like "*401*") {
        Write-Error "Connected to '$SharePointAdminUrl', but the managed identity was denied access. Grant the managed identity the 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API (appId 00000003-0000-0ff1-ce00-000000000000) with admin consent - Microsoft Graph permissions alone are not sufficient, the grant must be on the SharePoint API specifically. Underlying error: $($connectError.Exception.Message)" -ErrorAction Continue
        throw "Managed identity lacks the Sites.FullControl.All SharePoint application permission"
    }
    else {
        Write-Error "Failed to connect to SharePoint Online via PnP.PowerShell using managed identity against '$SharePointAdminUrl': $($connectError.Exception.Message). Verify the URL is the tenant's SharePoint ADMIN center URL (format: https://<tenant>-admin.sharepoint.com) and that 'PnP.PowerShell' is imported into this Automation Account's modules." -ErrorAction Continue
        throw
    }
}

Write-Output "Connecting to Microsoft Graph for RJ RunbookHelper..."
try {
    Connect-RjRbGraph
}
catch {
    Write-Error "Failed to connect to Microsoft Graph via RJ RunbookHelper: $_" -ErrorAction Continue
    throw
}

Write-Output "## Retrieving tenant information..."
$tenantDisplayName = "Unknown Tenant"
try {
    # No Connect-MgGraph session exists in this runbook (SharePoint access is PnP-only), so the tenant
    # name is resolved through the RJ RunbookHelper Graph wrapper already connected above instead of
    # pulling in Connect-MgGraph / Microsoft.Graph.Authentication just for this one lookup.
    $organizationResponse = Invoke-RjRbRestMethodGraph -Resource "/organization" -OdSelect "displayName" -ErrorAction Stop
    if ($organizationResponse) {
        if ($organizationResponse.displayName) {
            $tenantDisplayName = $organizationResponse.displayName
        }
        elseif ($organizationResponse.Count -gt 0 -and $organizationResponse[0].displayName) {
            $tenantDisplayName = $organizationResponse[0].displayName
        }
    }
    Write-Output "## Tenant: $($tenantDisplayName)"
}
catch {
    Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
}
#endregion Connect Part

########################################################
#region     Data Collection
########################################################
Write-Output ""
Write-Output "Collect SharePoint Online storage data"
Write-Output "---------------------"

# Tenant-wide storage quota for the current geo location - this is the whole basis for the alerting.
try {
    $storageQuota = Get-PnPGeoStorageQuota -ErrorAction Stop
}
catch {
    Write-Error "Failed to read the tenant storage quota via Get-PnPGeoStorageQuota. If this is an access-denied error, the managed identity is connected but lacks the 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API. Underlying error: $($_.Exception.Message)" -ErrorAction Continue
    throw "Unable to retrieve SharePoint Online tenant storage quota"
}

if (-not $storageQuota) {
    Write-Error "Get-PnPGeoStorageQuota returned no data. Verify the managed identity holds the 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API with admin consent granted." -ErrorAction Continue
    throw "No SharePoint Online tenant storage quota returned"
}

# Site collections with their storage metrics. OneDrive for Business sites are deliberately NOT
# included (-IncludeOneDriveSites is omitted): personal sites do not count against the tenant
# storage quota, so listing them here would misrepresent the top storage consumers.
Write-Output "Retrieving site collections (this can take several minutes in large tenants)..."
try {
    $allSites = @(Get-PnPTenantSite -ErrorAction Stop)
}
catch {
    Write-Error "Failed to enumerate SharePoint Online site collections via Get-PnPTenantSite. If this is an access-denied error, the managed identity lacks the 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API. Underlying error: $($_.Exception.Message)" -ErrorAction Continue
    throw "Unable to retrieve SharePoint Online site collections"
}

Write-Output "Retrieved $($allSites.Count) site collection(s)."
Write-RjRbLog -Message "Site collections retrieved: $($allSites.Count)" -Verbose
#endregion Data Collection

########################################################
#region     Data Processing
########################################################
Write-Output ""
Write-Output "SharePoint Online Tenant Storage"
Write-Output "---------------------"

# ===== Derive storage metrics =====
# Get-PnPGeoStorageQuota returns GeoUsedStorageMB and StorageQuotaMB
$usedMB = $storageQuota.GeoUsedStorageMB
$quotaMB = $storageQuota.TenantStorageMB

# Fail with clear message if quota values are missing or unusable
if ($null -eq $usedMB -or $null -eq $quotaMB -or $quotaMB -le 0) {
    Write-Error "Unable to retrieve valid storage quota values. Used: $usedMB, Quota: $quotaMB" -ErrorAction Continue
    throw "Cannot determine tenant storage quota"
}

$freeMB = [Math]::Max(0, $quotaMB - $usedMB)
$usedPercent = if ($quotaMB -gt 0) { [Math]::Round(($usedMB / $quotaMB) * 100, 1) } else { 0 }

$usedGB = [Math]::Round($usedMB / 1024, 2)
$quotaGB = [Math]::Round($quotaMB / 1024, 2)
$freeGB = [Math]::Round($freeMB / 1024, 2)

# ===== Threshold evaluation =====
$alertTriggered = $false
$alertReasons = @()

# Low storage check
if ($freeMB -lt $AlertLowStorageLimitInMB) {
    $alertReasons += "Free tenant storage ($freeGB GB) is below the configured low-storage limit ($([Math]::Round($AlertLowStorageLimitInMB / 1024, 2)) GB)."
    $alertTriggered = $true
}

# Unused storage check (only if threshold is enabled, i.e., > 0)
if ($AlertUnusedStorageLimitInMB -gt 0 -and $freeMB -gt $AlertUnusedStorageLimitInMB) {
    $alertReasons += "Free tenant storage ($freeGB GB) exceeds the configured unused-storage limit ($([Math]::Round($AlertUnusedStorageLimitInMB / 1024, 2)) GB); licensed storage may be reclaimable."
    $alertTriggered = $true
}

# ===== Top sites processing =====
# Sort by storage descending, shape in a single pass with null-safe storage and date handling
$topSites = @()
if ($allSites.Count -gt 0) {
    $topSites = @($allSites | Sort-Object -Property { [double]($_.StorageUsageCurrent ?? 0) } -Descending | Select-Object -First $TopSiteCount | ForEach-Object {
        # Treat null storage as 0; normalize to GB
        $siteStorageMB = if ($null -eq $_.StorageUsageCurrent) { 0 } else { [double]$_.StorageUsageCurrent }
        $siteStorageGB = [Math]::Round($siteStorageMB / 1024, 2)
        $sitePercent = if ($quotaMB -gt 0) { [Math]::Round(($siteStorageMB / $quotaMB) * 100, 2) } else { 0 }


        # Handle empty title
        $displayTitle = if ([string]::IsNullOrEmpty($_.Title)) { $_.Url } else { $_.Title }

        [PSCustomObject]@{
            Title                = $displayTitle
            Url                  = $_.Url
            StorageUsedGB        = $siteStorageGB
            PercentOfTenantStorage = $sitePercent
        }
    })
}

# ===== Display to runbook output =====
Write-Output "Total Quota: $quotaGB GB"
Write-Output "Used: $usedMB MB ($usedPercent%)"
Write-Output "Free: $freeGB GB"
Write-Output ""

if ($topSites.Count -gt 0) {
    Write-Output "Top $($topSites.Count) Site Collections:"
    $topSites | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Output $_ }
    Write-Output ""
}

if ($alertTriggered) {
    Write-Output "ALERT: Storage threshold(s) breached:"
    foreach ($reason in $alertReasons) {
        Write-Output "  - $reason"
    }
}
else {
    Write-Output "No thresholds were breached."
}

# ===== Build Markdown email content =====
# Construct the markdown table rows from top sites, guarding pipes in titles
$tableRows = @()
foreach ($site in $topSites) {
    # Escape pipe characters that could appear in site titles
    $escapedTitle = $site.Title -replace '\|', '\|'
    $tableRows += "| $escapedTitle | $($site.Url) | $($site.StorageUsedGB) GB |"
}

$tableContent = if ($tableRows.Count -gt 0) {
    "| Site Title | URL | Storage Used |`n| --- | --- | --- | --- | --- |`n$($tableRows -join "`n")"
} else {
    "(No site collections found)"
}

$markdownContent = @"
# SharePoint Online Tenant Storage Alert

**Tenant:** $tenantDisplayName

## Alert Reasons

$($alertReasons | ForEach-Object { "- $_" } | Out-String)

## Storage Summary

- **Total Quota:** $quotaGB GB
- **Used:** $usedMB MB ($usedPercent%)
- **Free:** $freeGB GB

## Top Site Collections

$tableContent

---

*This email was automatically generated. Please do not reply to this email.*
"@

Write-RjRbLog -Message "Data processing completed. Alert triggered: $alertTriggered. Top sites processed: $($topSites.Count)" -Verbose
#endregion Data Processing

########################################################
#region     Send Email Report
########################################################
# Initialized unconditionally so Cleanup can safely reference it even when no alert fired.
$brandingMailParams = @{}

if (-not $alertTriggered) {
    Write-RjRbLog -Message "No storage thresholds were breached. Skipping alert email." -Verbose
    Write-Output ""
    Write-Output "No thresholds were breached - no alert email is being sent."
}
else {
    Write-RjRbLog -Message "Threshold breach detected: $($alertReasons -join '; ')" -Verbose

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        $emailParams = @{
            EmailFrom         = $EmailFrom
            EmailTo           = $AlertEmailTo
            Subject           = $AlertEmailSubject
            MarkdownContent   = $markdownContent
            TenantDisplayName = $tenantDisplayName
            ReportVersion     = $Version
        }

        Send-RjReportEmail @emailParams @brandingMailParams
    }
    catch {
        # The storage data above was already collected successfully and is visible in this job's output -
        # only the alert notification failed to send. Distinguish the likely causes for an operator
        # reading this days after a scheduled run.
        $sendError = $_
        $sendErrorMessage = $sendError.Exception.Message
        if ($sendError.Exception.InnerException) { $sendErrorMessage += " " + $sendError.Exception.InnerException.Message }
        if ($sendErrorMessage -like "*EmailFrom*" -or $sendErrorMessage -like "*sender*" -or $sendErrorMessage -like "*RJReport.EmailSender*") {
            Write-Error "The storage data was collected successfully (see the job output above for the quota and site details) - only the alert email failed to send, because no valid sender address is configured. Set the 'RJReport.EmailSender' RealmJoin setting to a mailbox the managed identity is allowed to send as. Underlying error: $($sendError.Exception.Message)" -ErrorAction Continue
            throw "Alert email not sent: EmailFrom / RJReport.EmailSender is not configured"
        }
        elseif ($sendErrorMessage -like "*403*" -or $sendErrorMessage -like "*Forbidden*" -or $sendErrorMessage -like "*Unauthorized*" -or $sendErrorMessage -like "*401*" -or $sendErrorMessage -like "*consent*") {
            Write-Error "The storage data was collected successfully (see the job output above) - only the alert email failed to send, because Microsoft Graph denied the send request. Verify the managed identity has been granted the 'Mail.Send' application permission and that consent has been completed. Underlying error: $($sendError.Exception.Message)" -ErrorAction Continue
            throw "Alert email not sent: Mail.Send permission missing or not consented"
        }
        elseif ($sendErrorMessage -like "*recipient*" -or $sendErrorMessage -like "*ResolveRecipients*" -or (($sendErrorMessage -like "*invalid*") -and ($sendErrorMessage -like "*address*" -or $sendErrorMessage -like "*recipient*"))) {
            Write-Error "The storage data was collected successfully (see the job output above) - only the alert email failed to send, because the recipient address '$AlertEmailTo' was rejected. Verify the 'AlertEmailTo' parameter is set to a valid, existing mailbox. Underlying error: $($sendError.Exception.Message)" -ErrorAction Continue
            throw "Alert email not sent: recipient address '$AlertEmailTo' is invalid"
        }
        else {
            Write-Error "The storage data was collected successfully (see the job output above) - only the alert email failed to send: $($sendError.Exception.Message)" -ErrorAction Continue
            throw "Failed to send alert email report: $($sendError.Exception.Message)"
        }
    }
}
#endregion Send Email Report

########################################################
#region     Cleanup
########################################################
try {
    Disconnect-PnPOnline -ErrorAction Stop
}
catch {
    Write-RjRbLog -Message "Disconnect-PnPOnline: no active PnP session to disconnect or disconnect failed: $($_.Exception.Message)" -Verbose
}

foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

Write-Output ""
Write-Output "Done!"
#endregion Cleanup
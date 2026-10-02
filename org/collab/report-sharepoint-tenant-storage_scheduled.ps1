<#
	.SYNOPSIS
	Monitor SharePoint storage and alert when limits are exceeded

	.DESCRIPTION
	Checks the storage of the SharePoint Online tenant on every run: the quota, how much is used, and the site collections that use the most. The full inventory is written to the run output. An alert email is sent only when the free storage drops below the low-storage limit or the licensed but unused storage exceeds the reclaimable limit.

	.PARAMETER AlertLowStorageLimitInGB
	Send an alert when the free tenant storage drops below this many gigabytes.

	.PARAMETER AlertUnusedStorageLimitInGB
	Send an alert when the licensed storage that no site uses exceeds this many gigabytes. That storage could be reclaimed.

	.PARAMETER TopSiteCount
	How many of the largest site collections are listed.

	.PARAMETER EmailFrom
	Sender address of the alert email. Taken from the tenant setting RJReport.EmailSender.

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

	.PARAMETER AlertEmailTo
	Address the alert goes to when a limit is exceeded.

	.PARAMETER AlertEmailSubject
	Subject line of the alert email.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"AlertLowStorageLimitInGB": {
				"DisplayName": "Alert when free storage falls below (GB)"
			},
			"AlertUnusedStorageLimitInGB": {
				"DisplayName": "Alert when unused storage rises above (GB)"
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

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "PnP.PowerShell"; ModuleVersion = "3.4.1" }

param(

    [Parameter(Mandatory = $true)]
    [int]$AlertLowStorageLimitInGB = 200,

    [int]$AlertUnusedStorageLimitInGB = 1024,

    [ValidateRange(1, 100)]
    [int]$TopSiteCount = 10,

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

$Version = "1.5.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "AlertLowStorageLimitInGB: $AlertLowStorageLimitInGB" -Verbose
Write-RjRbLog -Message "AlertUnusedStorageLimitInGB: $AlertUnusedStorageLimitInGB" -Verbose
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
Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph using the managed identity. Ensure the Automation Account's managed identity is enabled and has the required Graph app role assignments (see .permissions.json). Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

Write-Output "## Retrieving tenant information..."
$tenantDisplayName = "Unknown Tenant"
try {
    $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
    }
    Write-Output "## Tenant: $($tenantDisplayName)"
}
catch {
    Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
}

# The SharePoint admin center URL is derived from the URL of the tenant root site
$SharePointAdminUrl = $null
try {
    $mgSPOrootSiteResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/sites/root" -ErrorAction Stop
    $SharePointAdminUrl = $mgSPOrootSiteResponse["webUrl"]
}
catch {
    Write-Error "Failed to read the tenant root site from Microsoft Graph (/sites/root) to discover the SharePoint admin center URL. Verify the managed identity holds the 'Sites.Read.All' Microsoft Graph application permission. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

if ([string]::IsNullOrWhiteSpace($SharePointAdminUrl)) {
    Write-Error "The SharePoint admin center URL could not be discovered from the tenant root site (Microsoft Graph /sites/root)." -ErrorAction Continue
    throw "SharePointAdminUrl is not discovered"
}
$SharePointAdminUrl = $SharePointAdminUrl.Replace(".sharepoint.com", "-admin.sharepoint.com")
Write-RjRbLog -Message "SharePointAdminUrl: $SharePointAdminUrl" -Verbose

Write-Output "Connecting to SharePoint Online (PnP.PowerShell)..."
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
# Get-PnPGeoStorageQuota returns GeoUsedStorageMB and TenantStorageMB
$usedMB = $storageQuota.GeoUsedStorageMB
$quotaMB = $storageQuota.TenantStorageMB

# Fail with clear message if quota values are missing or unusable
if ($null -eq $usedMB -or $null -eq $quotaMB -or $quotaMB -le 0) {
    Write-Error "Unable to retrieve valid storage quota values. Used MB: $usedMB, Quota MB: $quotaMB" -ErrorAction Continue
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
$lowStorageResult = "OK"
if ($freeGB -lt $AlertLowStorageLimitInGB) {
    $alertReasons += "Free tenant storage ($freeGB GB) is below the configured low-storage limit ($AlertLowStorageLimitInGB GB)."
    $alertTriggered = $true
    $lowStorageResult = "Breached"
}

# Unused storage check (only if threshold is enabled, i.e., > 0)
$unusedStorageResult = if ($AlertUnusedStorageLimitInGB -gt 0) { "OK" } else { "Disabled" }
if ($AlertUnusedStorageLimitInGB -gt 0 -and $freeGB -gt $AlertUnusedStorageLimitInGB) {
    $alertReasons += "Free tenant storage ($freeGB GB) exceeds the configured unused-storage limit ($AlertUnusedStorageLimitInGB GB); licensed storage may be reclaimable."
    $alertTriggered = $true
    $unusedStorageResult = "Breached"
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
Write-Output "Used: $usedGB GB ($usedPercent%)"
Write-Output "Free: $freeGB GB"
Write-Output ""

if ($topSites.Count -gt 0) {
    Write-Output "Site collections: $($allSites.Count) (the largest $($topSites.Count) are listed in the Output Data tab)"
}
else {
    Write-Output "Site collections: 0"
}
Write-Output ""

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
    "| Site Title | URL | Storage Used |`n| --- | --- | --- |`n$($tableRows -join "`n")"
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
- **Used:** $usedGB GB ($usedPercent%)
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
# Set when the alert email could not be sent; the run fails in Cleanup, after the tables are written
$alertSendFailure = $null

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
            EmailFrom             = $EmailFrom
            EmailTo               = $AlertEmailTo
            Subject               = $AlertEmailSubject
            MarkdownContent       = $markdownContent
            TenantDisplayName     = $tenantDisplayName
            ReportVersion         = $Version
            UseNativeGraphRequest = $true   # sends through the Connect-MgGraph session
        }

        Send-RjRbReportEmail @emailParams @brandingMailParams
        Write-Output ""
        Write-Output "Alert email sent to '$AlertEmailTo'."
    }
    catch {
        # The storage data was already collected successfully and follows in the Output Data tab -
        # only the alert notification failed to send. Distinguish the likely causes for an operator
        # reading this days after a scheduled run; the run fails in Cleanup, after the tables are written.
        $sendError = $_
        $sendErrorMessage = $sendError.Exception.Message
        if ($sendError.Exception.InnerException) { $sendErrorMessage += " " + $sendError.Exception.InnerException.Message }
        if ($sendErrorMessage -like "*EmailFrom*" -or $sendErrorMessage -like "*sender*" -or $sendErrorMessage -like "*RJReport.EmailSender*") {
            Write-Error "The storage data was collected successfully (see the Output Data tab for the quota and site details) - only the alert email failed to send, because no valid sender address is configured. Set the 'RJReport.EmailSender' RealmJoin setting to a mailbox the managed identity is allowed to send as. Underlying error: $($sendError.Exception.Message)" -ErrorAction Continue
            $alertSendFailure = "Alert email not sent: EmailFrom / RJReport.EmailSender is not configured"
        }
        elseif ($sendErrorMessage -like "*403*" -or $sendErrorMessage -like "*Forbidden*" -or $sendErrorMessage -like "*Unauthorized*" -or $sendErrorMessage -like "*401*" -or $sendErrorMessage -like "*consent*") {
            Write-Error "The storage data was collected successfully (see the Output Data tab) - only the alert email failed to send, because Microsoft Graph denied the send request. Verify the managed identity has been granted the 'Mail.Send' application permission and that consent has been completed. Underlying error: $($sendError.Exception.Message)" -ErrorAction Continue
            $alertSendFailure = "Alert email not sent: Mail.Send permission missing or not consented"
        }
        elseif ($sendErrorMessage -like "*recipient*" -or $sendErrorMessage -like "*ResolveRecipients*" -or (($sendErrorMessage -like "*invalid*") -and ($sendErrorMessage -like "*address*" -or $sendErrorMessage -like "*recipient*"))) {
            Write-Error "The storage data was collected successfully (see the Output Data tab) - only the alert email failed to send, because the recipient address '$AlertEmailTo' was rejected. Verify the 'AlertEmailTo' parameter is set to a valid, existing mailbox. Underlying error: $($sendError.Exception.Message)" -ErrorAction Continue
            $alertSendFailure = "Alert email not sent: recipient address '$AlertEmailTo' is invalid"
        }
        else {
            Write-Error "The storage data was collected successfully (see the Output Data tab) - only the alert email failed to send: $($sendError.Exception.Message)" -ErrorAction Continue
            $alertSendFailure = "Failed to send alert email report: $($sendError.Exception.Message)"
        }
    }
}
#endregion Send Email Report

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the progress output. Every table has its own
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
Write-Output ""

$storageValues = [ordered]@{
    "Quota (GB)"       = $quotaGB
    "Used (GB)"        = $usedGB
    "Used (%)"         = $usedPercent
    "Free (GB)"        = $freeGB
    "Site collections" = $allSites.Count
}
$storageRows = @(foreach ($metric in $storageValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = [double]$storageValues[$metric] }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Tenant storage" })
Write-Output $storageRows

$thresholdRows = @(
    [PSCustomObject]@{ Check = "Free storage below the low-storage limit"; LimitGB = $AlertLowStorageLimitInGB; FreeGB = $freeGB; Result = $lowStorageResult }
    [PSCustomObject]@{ Check = "Free storage above the unused-storage limit"; LimitGB = $AlertUnusedStorageLimitInGB; FreeGB = $freeGB; Result = $unusedStorageResult }
)
Write-Output ([PSCustomObject]@{ RjTableTitle = "Threshold checks" })
Write-Output $thresholdRows

if ($topSites.Count -gt 0) {
    Write-Output "Top $($topSites.Count) site collection(s) by storage used:"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Top site collections" })
    Write-Output @($topSites | Select-Object -Property Title, Url, StorageUsedGB, PercentOfTenantStorage)
}
else {
    Write-Output "No site collections found."
}

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################
try {
    Disconnect-PnPOnline -ErrorAction Stop
}
catch {
    Write-RjRbLog -Message "Disconnect-PnPOnline: no active PnP session to disconnect or disconnect failed: $($_.Exception.Message)" -Verbose
}

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

# Fail the run only now that the tables are written and the sessions are closed
if ($alertSendFailure) {
    throw $alertSendFailure
}

Write-Output ""
Write-Output "Done!"
#endregion Cleanup
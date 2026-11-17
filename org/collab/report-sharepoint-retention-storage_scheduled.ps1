<#
	.SYNOPSIS
	Report how much storage retention uses in SharePoint sites and OneDrives

	.DESCRIPTION
	Measures the hidden Preservation Hold library of SharePoint site collections and OneDrives. When a retention policy, retention label or hold applies to a site, SharePoint keeps deleted content and the original version of edited content in this library, so it grows over time. For every site the size of the library is compared with the total storage the site uses. The run output lists the total retention storage of all scanned sites, a breakdown by site type and the sites with the most retention storage; the complete data set is offered as a CSV download link and can also be sent by email. Give a site URL for an ad hoc analysis of one site collection, or leave it empty and choose all sites, SharePoint sites only or OneDrives only for a scheduled analysis of the whole tenant. Nothing is changed.

	.PARAMETER SiteUrl
	URL of one site collection or OneDrive to analyze ad hoc. Leave empty to analyze all sites of the selected scope.

	.PARAMETER Scope
	Which sites are analyzed when no site URL is given: all site collections and OneDrives, only SharePoint site collections or only OneDrives.

	.PARAMETER TopSiteCount
	How many sites with the most retention storage are listed.

	.PARAMETER CreateDownloadLink
	Upload the complete data set as a CSV file and return a download link that expires after a few days.

	.PARAMETER EmailTo
	Send the report to these addresses, separated by commas. Leave empty to send no email.

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
			"SiteUrl": {
				"DisplayName": "Single site URL (ad hoc, leave empty for all sites)"
			},
			"Scope": {
				"DisplayName": "Sites to analyze",
				"SelectSimple": {
					"SharePoint sites and OneDrives": "All",
					"SharePoint sites only": "SharePoint",
					"OneDrives only": "OneDrive"
				}
			},
			"TopSiteCount": {
				"DisplayName": "Number of top sites to list"
			},
			"CreateDownloadLink": {
				"DisplayName": "Create a download link?",
				"SelectSimple": {
					"Yes - upload the complete data set and return a download link": true,
					"No - do not create a download link": false
				}
			},
			"EmailTo": {
				"DisplayName": "Recipient email address(es)"
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
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }
#Requires -Modules @{ModuleName = "PnP.PowerShell"; ModuleVersion = "3.4.1" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [string]$SiteUrl = "",

    [ValidateSet("All", "SharePoint", "OneDrive")]
    [string]$Scope = "All",

    [ValidateRange(1, 100)]
    [int]$TopSiteCount = 10,

    [bool]$CreateDownloadLink = $true,

    [string]$EmailTo = "",

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

    [string]$ContainerName = "report-sharepoint-retention-storage",

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
#region     Function Definitions
########################################################

# Returns a reason when a site cannot be read, otherwise $null.
# Read-only locked sites are still readable and are therefore measured.
function Get-SiteSkipReason {
    param(
        [Parameter(Mandatory = $true)]
        $Site
    )
    $template = [string]$Site.Template
    $lockState = [string]$Site.LockState
    $archiveStatus = [string]$Site.ArchiveStatus
    $status = [string]$Site.Status

    if ($template -like "RedirectSite*") { return "Redirect site" }
    if ($lockState -eq "NoAccess") { return "Locked (NoAccess)" }
    if ($archiveStatus -ne "" -and $archiveStatus -ne "NotArchived") { return "Archived ($archiveStatus)" }
    if ($status -ne "" -and $status -ne "Active") { return "Not active ($status)" }
    return $null
}

function ConvertTo-GB {
    param([double]$Bytes)
    return [Math]::Round($Bytes / 1GB, 3)
}

function Get-Percent {
    param([double]$Part, [double]$Total)
    if ($Total -le 0) { return 0 }
    return [Math]::Round(($Part / $Total) * 100, 2)
}

#endregion Function Definitions

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "SiteUrl: $SiteUrl" -Verbose
Write-RjRbLog -Message "Scope: $Scope" -Verbose
Write-RjRbLog -Message "TopSiteCount: $TopSiteCount" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
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

Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

$SiteUrl = $SiteUrl.Trim().TrimEnd('/')
$singleSiteMode = -not [string]::IsNullOrWhiteSpace($SiteUrl)

if ($singleSiteMode) {
    $parsedSiteUri = $null
    if (-not [System.Uri]::TryCreate($SiteUrl, [System.UriKind]::Absolute, [ref]$parsedSiteUri) -or $parsedSiteUri.Scheme -ne "https" -or $parsedSiteUri.Host -notlike "*.sharepoint.com") {
        Write-Error "The site URL '$SiteUrl' is not a valid SharePoint Online URL. Use the full URL of a site collection or OneDrive, for example https://contoso.sharepoint.com/sites/Projects." -ErrorAction Continue
        throw "Invalid SiteUrl"
    }
}

$sendEmail = $false
if (-not [string]::IsNullOrWhiteSpace($EmailTo)) {
    if ([string]::IsNullOrWhiteSpace($EmailFrom)) {
        Write-Error "A recipient is given but the sender email address is missing. Configure the tenant setting RJReport.EmailSender in the runbook customization (https://docs.realmjoin.com/automation/runbooks/runbook-report-settings)." -ErrorAction Continue
        throw "Missing email sender configuration (RJReport.EmailSender)"
    }
    $sendEmail = $true
}

if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Error "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* tenant settings in the runbook customization (https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) or start the runbook without a download link." -ErrorAction Continue
    throw "Missing storage account configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)"
}

$scopeLabel = if ($singleSiteMode) { "Single site" } else { $Scope }
if ($singleSiteMode) {
    Write-Output "Mode: ad hoc analysis of one site ($SiteUrl)"
}
else {
    Write-Output "Mode: analysis of all sites in scope '$Scope'"
}
Write-Output "Top sites listed: $TopSiteCount"
Write-Output "Download link: $(if ($CreateDownloadLink) { 'yes' } else { 'no' })"
Write-Output "Email report: $(if ($sendEmail) { $EmailTo } else { 'no' })"

#endregion Parameter Validation

########################################################
#region     Connect Part
########################################################

Write-Output ""
Write-Output "Connect Part"
Write-Output "---------------------"

try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    Write-RjRbLog -Message "Connected to Microsoft Graph via managed identity." -Verbose
}
catch {
    Write-Error "Failed to connect to Microsoft Graph using the managed identity. Ensure the system-assigned managed identity of the Automation account is enabled. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

$tenantDisplayName = "Unknown Tenant"
try {
    $orgInfo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
    if ($orgInfo.value -and $orgInfo.value[0].displayName) {
        $tenantDisplayName = $orgInfo.value[0].displayName
    }
}
catch {
    Write-RjRbLog -Message "Failed to retrieve tenant display name: $($_.Exception.Message)" -Verbose
}
Write-Output "Tenant: $tenantDisplayName"

try {
    $rootSite = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/sites/root?`$select=webUrl" -Method GET -ErrorAction Stop
    $rootHost = ([System.Uri]$rootSite.webUrl).Host
    $sharePointAdminUrl = "https://" + $rootHost.Replace(".sharepoint.com", "-admin.sharepoint.com")
}
catch {
    Write-Error "Could not determine the SharePoint admin URL via Microsoft Graph (/sites/root). The managed identity needs the Graph application permission 'Sites.Read.All'. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw "SharePoint admin URL not discovered"
}
Write-RjRbLog -Message "SharePointAdminUrl: $sharePointAdminUrl" -Verbose

try {
    $VerbosePreference = "SilentlyContinue"
    $adminConnection = Connect-PnPOnline -Url $sharePointAdminUrl -ManagedIdentity -ReturnConnection -ErrorAction Stop
    $VerbosePreference = "Continue"
    Write-Output "Connected to $sharePointAdminUrl"
}
catch {
    $VerbosePreference = "Continue"
    Write-Error "Failed to connect to the SharePoint admin center '$sharePointAdminUrl'. The managed identity needs the 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API (AppId 00000003-0000-0ff1-ce00-000000000000). Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

Write-Output ""
Write-Output "Retrieve Sites"
Write-Output "---------------------"

$allSites = @()
try {
    if ($singleSiteMode) {
        $allSites = @(Get-PnPTenantSite -Identity $SiteUrl -Connection $adminConnection -ErrorAction Stop)
    }
    else {
        Write-Output "Retrieving site collections in scope '$Scope' (this can take several minutes in large tenants)..."
        switch ($Scope) {
            "SharePoint" { $allSites = @(Get-PnPTenantSite -Connection $adminConnection -ErrorAction Stop) }
            "OneDrive" { $allSites = @(Get-PnPTenantSite -IncludeOneDriveSites -Filter "Url -like '-my.sharepoint.com/personal/'" -Connection $adminConnection -ErrorAction Stop) }
            default { $allSites = @(Get-PnPTenantSite -IncludeOneDriveSites -Connection $adminConnection -ErrorAction Stop) }
        }
    }
}
catch {
    $message = $_.Exception.Message
    if ($singleSiteMode -and $message -match "Cannot get site|not found|does not exist|404") {
        Write-Error "The site '$SiteUrl' was not found. Use the URL of the site collection itself (not of a subsite, library or page)." -ErrorAction Continue
        throw "Site not found"
    }
    Write-Error "Failed to retrieve the site collections via Get-PnPTenantSite. If this is an access-denied error, the managed identity lacks 'Sites.FullControl.All' on the Office 365 SharePoint Online API. Error: $message" -ErrorAction Continue
    throw "Unable to retrieve SharePoint site collections"
}
Write-Output "Found $($allSites.Count) site(s)."

Write-Output ""
Write-Output "Measure Preservation Hold Libraries"
Write-Output "---------------------"

$siteRows = [System.Collections.Generic.List[object]]::new()
$siteIndex = 0
$runStart = Get-Date

foreach ($site in $allSites) {
    $siteIndex++
    if ($siteIndex % 100 -eq 0) {
        $elapsed = [int]((Get-Date) - $runStart).TotalMinutes
        Write-Output "Progress: $siteIndex of $($allSites.Count) sites, $elapsed min elapsed."
    }

    $siteUrlValue = [string]$site.Url
    $siteType = if ([string]$site.Template -like "SPSPERS*") { "OneDrive" } else { "SharePoint" }
    $siteStorageBytes = if ($null -eq $site.StorageUsageCurrent) { 0 } else { [double]$site.StorageUsageCurrent * 1MB }

    $row = [PSCustomObject]@{
        Title                     = if ([string]::IsNullOrEmpty($site.Title)) { $siteUrlValue } else { [string]$site.Title }
        Url                       = $siteUrlValue
        SiteType                  = $siteType
        Owner                     = [string]$site.Owner
        SiteStorageGB             = ConvertTo-GB -Bytes $siteStorageBytes
        RetentionStorageGB        = 0
        RetentionPercentOfSite    = 0
        RetentionFileCount        = 0
        RetentionLastModified     = ""
        HasPreservationHold       = $false
        Status                    = ""
        Details                   = ""
        SiteStorageBytes          = $siteStorageBytes
        RetentionStorageBytes     = [double]0
    }

    $skipReason = Get-SiteSkipReason -Site $site
    if ($skipReason) {
        $row.Status = "Skipped"
        $row.Details = $skipReason
        $siteRows.Add($row)
        continue
    }

    # The Preservation Hold library counts towards the site storage, so an empty site cannot hold any.
    # Skipping these saves one connection per site, which matters for tenants with many unused OneDrives.
    if ($siteStorageBytes -le 0 -and -not $singleSiteMode) {
        $row.Status = "NoLibrary"
        $row.Details = "Site uses no storage"
        $siteRows.Add($row)
        continue
    }

    try {
        $VerbosePreference = "SilentlyContinue"
        $siteConnection = Connect-PnPOnline -Url $siteUrlValue -ManagedIdentity -ReturnConnection -ErrorAction Stop
        $metric = Get-PnPFolderStorageMetric -FolderSiteRelativeUrl "PreservationHoldLibrary" -Connection $siteConnection -ErrorAction Stop
        $VerbosePreference = "Continue"

        $retentionBytes = [double]$metric.TotalSize
        $row.HasPreservationHold = $true
        $row.RetentionStorageBytes = $retentionBytes
        $row.RetentionStorageGB = ConvertTo-GB -Bytes $retentionBytes
        $row.RetentionPercentOfSite = Get-Percent -Part $retentionBytes -Total $siteStorageBytes
        $row.RetentionFileCount = [int64]$metric.TotalFileCount
        if ($metric.LastModified -and ([datetime]$metric.LastModified).Year -gt 1) {
            $row.RetentionLastModified = ([datetime]$metric.LastModified).ToString("yyyy-MM-dd HH:mm")
        }
        $row.Status = "Measured"
    }
    catch {
        $VerbosePreference = "Continue"
        $message = $_.Exception.Message
        if ($message -match "File Not Found|not found|does not exist|404|FileNotFound") {
            # No retention has ever applied to this site, so SharePoint never created the library
            $row.Status = "NoLibrary"
        }
        elseif ($message -match "archiv") {
            $row.Status = "Skipped"
            $row.Details = "Archived"
        }
        else {
            $row.Status = "ReadFailed"
            $row.Details = $message
            Write-RjRbLog -Message "WARNING: Could not measure the Preservation Hold library of '$siteUrlValue'. Error: $message" -NoDebugOnly
        }
    }
    $siteRows.Add($row)
}

$elapsedTotal = [Math]::Round(((Get-Date) - $runStart).TotalMinutes, 1)
Write-Output "Measured $($allSites.Count) site(s) in $elapsedTotal min."

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

$measuredRows = @($siteRows | Where-Object { $_.Status -eq "Measured" })
$skippedRows = @($siteRows | Where-Object { $_.Status -eq "Skipped" })
$failedRows = @($siteRows | Where-Object { $_.Status -eq "ReadFailed" })
$noLibraryCount = @($siteRows | Where-Object { $_.Status -eq "NoLibrary" }).Count

$totalSiteBytes = [double](($siteRows | Measure-Object -Property SiteStorageBytes -Sum).Sum)
$totalRetentionBytes = [double](($measuredRows | Measure-Object -Property RetentionStorageBytes -Sum).Sum)
$totalRetentionFiles = [int64](($measuredRows | Measure-Object -Property RetentionFileCount -Sum).Sum)

# Breakdown per site type (only meaningful when both types are in scope, but always cheap to compute)
$typeRows = @(foreach ($group in ($siteRows | Group-Object -Property SiteType | Sort-Object Name)) {
        $groupSiteBytes = [double](($group.Group | Measure-Object -Property SiteStorageBytes -Sum).Sum)
        $groupRetentionBytes = [double](($group.Group | Measure-Object -Property RetentionStorageBytes -Sum).Sum)
        [PSCustomObject]@{
            SiteType               = $group.Name
            Sites                  = $group.Count
            SitesWithRetention     = @($group.Group | Where-Object { $_.HasPreservationHold }).Count
            SiteStorageGB          = ConvertTo-GB -Bytes $groupSiteBytes
            RetentionStorageGB     = ConvertTo-GB -Bytes $groupRetentionBytes
            RetentionPercentOfSite = Get-Percent -Part $groupRetentionBytes -Total $groupSiteBytes
        }
    })

$topSites = @($measuredRows | Where-Object { $_.RetentionStorageBytes -gt 0 } |
    Sort-Object -Property RetentionStorageBytes -Descending |
    Select-Object -First $TopSiteCount)

$summaryValues = [ordered]@{
    "Sites in scope"                         = $siteRows.Count
    "Sites with Preservation Hold library"   = $measuredRows.Count
    "Sites without Preservation Hold library" = $noLibraryCount
    "Sites skipped (archived, locked, redirect)" = $skippedRows.Count
    "Sites that could not be read"           = $failedRows.Count
    "Total site storage (GB)"                = ConvertTo-GB -Bytes $totalSiteBytes
    "Retention storage (GB)"                 = ConvertTo-GB -Bytes $totalRetentionBytes
    "Retention share of site storage (%)"    = Get-Percent -Part $totalRetentionBytes -Total $totalSiteBytes
    "Files in Preservation Hold libraries"   = $totalRetentionFiles
}

$totalLabel = if ($singleSiteMode) { "Site" } elseif ($Scope -eq "All") { "Tenant" } else { "Tenant ($Scope)" }

Write-Output ""
Write-Output "Retention Storage - $totalLabel"
Write-Output "---------------------"
foreach ($metricName in $summaryValues.Keys) {
    Write-Output ("{0}: {1}" -f $metricName, $summaryValues[$metricName])
}

if (-not $singleSiteMode -and $typeRows.Count -gt 1) {
    Write-Output ""
    foreach ($typeRow in $typeRows) {
        Write-Output ("{0}: {1} GB retention of {2} GB site storage ({3}%) in {4} of {5} site(s)" -f $typeRow.SiteType, $typeRow.RetentionStorageGB, $typeRow.SiteStorageGB, $typeRow.RetentionPercentOfSite, $typeRow.SitesWithRetention, $typeRow.Sites)
    }
}

Write-Output ""
if ($topSites.Count -gt 0) {
    Write-Output "Top $($topSites.Count) site(s) by retention storage:"
    $rank = 0
    foreach ($topSite in $topSites) {
        $rank++
        Write-Output ("{0,3}. {1} GB of {2} GB ({3}%) - {4}" -f $rank, $topSite.RetentionStorageGB, $topSite.SiteStorageGB, $topSite.RetentionPercentOfSite, $topSite.Url)
    }
}
else {
    Write-Output "No site in scope holds retained content."
}

if ($failedRows.Count -gt 0) {
    Write-Error "$($failedRows.Count) site(s) could not be read. Their retention storage is missing from the totals. See the 'Sites that could not be read' table for details." -ErrorAction Continue
}

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$exportColumns = @("Title", "Url", "SiteType", "Owner", "SiteStorageGB", "RetentionStorageGB", "RetentionPercentOfSite", "RetentionFileCount", "RetentionLastModified", "HasPreservationHold", "Status", "Details")
$exportRows = @($siteRows | Sort-Object -Property RetentionStorageBytes, SiteStorageBytes -Descending | Select-Object -Property $exportColumns)

$tempDir = $null
$reportFiles = @()
if (($CreateDownloadLink -or $sendEmail) -and $exportRows.Count -gt 0) {
    $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "SPORetentionStorage_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $csvPath = Join-Path -Path $tempDir -ChildPath "SPORetentionStorage-$($scopeLabel -replace '\s', '')-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    $exportRows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    $reportFiles += $csvPath
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################

if ($CreateDownloadLink) {
    Write-Output ""
    if ($reportFiles.Count -gt 0) {
        Write-Output "Uploading the complete data set to the storage account..."
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
            Write-Error "Failed to upload the report file to storage account '$StorageAccountName': $($_.Exception.Message). The managed identity needs the 'Reader and Data Access' role on the storage account." -ErrorAction Continue
            throw
        }

        foreach ($uploadResult in $uploadResults) {
            Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }
    else {
        Write-Output "No site in scope - skipping the upload."
    }
}

#endregion Upload / Download Link

########################################################
#region     Send Email Report
########################################################

$brandingMailParams = @{}

if ($sendEmail) {
    Write-Output ""
    Write-Output "Sending the email report to '$EmailTo'..."

    $topTable = if ($topSites.Count -gt 0) {
        $lines = @("| Site | Type | Retention storage | Site storage | Share |", "| --- | --- | --- | --- | --- |")
        foreach ($topSite in $topSites) {
            $escapedTitle = $topSite.Title -replace '\|', '\|'
            $lines += "| [$escapedTitle]($($topSite.Url)) | $($topSite.SiteType) | $($topSite.RetentionStorageGB) GB | $($topSite.SiteStorageGB) GB | $($topSite.RetentionPercentOfSite)% |"
        }
        $lines -join "`n"
    }
    else {
        "No site in scope holds retained content."
    }

    $typeSection = ""
    if (-not $singleSiteMode -and $typeRows.Count -gt 1) {
        $typeLines = @("| Site type | Sites | With retention | Retention storage | Site storage | Share |", "| --- | --- | --- | --- | --- | --- |")
        foreach ($typeRow in $typeRows) {
            $typeLines += "| $($typeRow.SiteType) | $($typeRow.Sites) | $($typeRow.SitesWithRetention) | $($typeRow.RetentionStorageGB) GB | $($typeRow.SiteStorageGB) GB | $($typeRow.RetentionPercentOfSite)% |"
        }
        $typeSection = "## By site type`n`n$($typeLines -join "`n")`n"
    }

    $markdownContent = @"
# SharePoint Retention Storage Report

**Tenant:** $tenantDisplayName
**Scope:** $(if ($singleSiteMode) { $SiteUrl } else { $Scope })
**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')

## Summary

- Retention storage: **$($summaryValues['Retention storage (GB)']) GB** of **$($summaryValues['Total site storage (GB)']) GB** site storage (**$($summaryValues['Retention share of site storage (%)'])%**)
- Files in Preservation Hold libraries: **$totalRetentionFiles**
- Sites in scope: **$($siteRows.Count)**, with Preservation Hold library: **$($measuredRows.Count)**
- Sites skipped: **$($skippedRows.Count)**, could not be read: **$($failedRows.Count)**

$typeSection
## Top $($topSites.Count) sites by retention storage

$topTable

The attached CSV file contains all sites in scope.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        $emailParams = @{
            EmailFrom             = $EmailFrom
            EmailTo               = $EmailTo
            Subject               = "SharePoint Retention Storage ($scopeLabel) - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"
            MarkdownContent       = $markdownContent
            TenantDisplayName     = $tenantDisplayName
            ReportVersion         = $Version
            UseNativeGraphRequest = $true
        }
        if ($reportFiles.Count -gt 0) {
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles
        }
        else {
            Send-RjRbReportEmail @emailParams @brandingMailParams
        }
        Write-Output "Email report sent to '$EmailTo'."
    }
    catch {
        Write-Error "Failed to send the email report: $($_.Exception.Message). The managed identity needs the Graph application permission 'Mail.Send'." -ErrorAction Continue
    }
}

#endregion Send Email Report

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the progress output.
# A title marker is only written when rows follow it.
Write-Output ""

Write-Output ([PSCustomObject]@{ RjTableTitle = "Retention storage - $totalLabel" })
Write-Output @(foreach ($metricName in $summaryValues.Keys) { [PSCustomObject]@{ Metric = $metricName; Value = [double]$summaryValues[$metricName] } })

if (-not $singleSiteMode -and $typeRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Retention storage by site type" })
    Write-Output $typeRows
}

$topColumns = @("Title", "Url", "SiteType", "RetentionStorageGB", "SiteStorageGB", "RetentionPercentOfSite", "RetentionFileCount", "RetentionLastModified")
if ($topSites.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Top $($topSites.Count) sites by retention storage" })
    Write-Output @($topSites | Select-Object -Property $topColumns)
}

if ($failedRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Sites that could not be read" })
    Write-Output @($failedRows | Select-Object -Property Url, SiteType, SiteStorageGB, Details)
}

if ($skippedRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Skipped sites" })
    Write-Output @($skippedRows | Select-Object -Property Url, SiteType, SiteStorageGB, Details)
}

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################

foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}
if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# PnP connections were created with -ReturnConnection and are not the current session, so there is nothing to disconnect
if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

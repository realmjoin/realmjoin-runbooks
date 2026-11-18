<#
    .SYNOPSIS
    Find and remove SharePoint site user ID mismatches for selected users

    .DESCRIPTION
    A site user ID mismatch occurs when a user account is deleted and recreated with the same user principal name. The new account gets a new ID (PUID), but the user information list of every site the old account visited still holds the old ID, which blocks access for the new account. For each selected user the current ID is read from the SharePoint user profile, and every site collection and/or OneDrive in scope is checked for an entry with the same login name but a different ID. Without dry run the stale entries are removed (including the site collection administrator role), so SharePoint adds the user again with the correct ID on the next access. Permissions and SharePoint group memberships are not restored; the groups are listed in the report so they can be granted again. A stale entry on the old OneDrive owned by the user is only reported. Archived, redirect and inaccessible sites are skipped.

    .PARAMETER UserPrincipalName
    Users to check. Each user must have a SharePoint user profile, which is created on the first access to SharePoint.

    .PARAMETER Scope
    Which sites are scanned: all site collections and OneDrives, only SharePoint site collections or only OneDrives.

    .PARAMETER WhatIfMode
    Only reports the mismatches without changing anything.

    .PARAMETER BulkLoadThreshold
    Up to this number of users each user is looked up individually per site. Above it all users of a site are loaded once, which is expensive on large sites.

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

    .PARAMETER CreateDownloadLink
    Also upload the CSV reports and return download links that expire after a few days.

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
            "UserPrincipalName": {
                "DisplayName": "Users"
            },
            "Scope": {
                "DisplayName": "Sites to scan",
                "SelectSimple": {
                    "SharePoint sites and OneDrives": "All",
                    "SharePoint sites only": "SharePoint",
                    "OneDrives only": "OneDrive"
                }
            },
            "WhatIfMode": {
                "DisplayName": "Dry run?"
            },
            "BulkLoadThreshold": {
                "Hide": true
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
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Use-RjRbInterface -Type Graph -Entity User -Attribute userPrincipalName })]
    [string[]]$UserPrincipalName,

    [ValidateSet("All", "SharePoint", "OneDrive")]
    [string]$Scope = "All",

    [bool]$WhatIfMode = $true,

    [ValidateRange(1, 1000)]
    [int]$BulkLoadThreshold = 10,

    [string]$EmailTo = "",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ })]
    [string]$EmailFrom,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ })]
    [string]$BrandingHeaderImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ })]
    [string]$BrandingFooterImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ })]
    [string]$BrandingFooterLink,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" -Value $_ })]
    [string]$BrandingAccentColor,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" -Value $_ })]
    [string]$BrandingTextColor,

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "fix-sharepoint-user-id-mismatch",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ })]
    [string]$ResourceGroupName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ })]
    [string]$StorageAccountName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ })]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     Function Definitions
########################################################

# Returns a reason when a site cannot be scanned, otherwise $null.
# Read-only sites are scanned, so their mismatches are reported, but nothing is removed there.
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
    if ($lockState -eq "NoAccess") { return "Locked ($lockState)" }
    if ($archiveStatus -ne "" -and $archiveStatus -ne "NotArchived") { return "Archived ($archiveStatus)" }
    if ($status -ne "" -and $status -ne "Active") { return "Not active ($status)" }
    return $null
}

# Returns the site user with this login name, or $null when the user never visited the site.
function Get-SiteUserByLogin {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,
        [Parameter(Mandatory = $true)]
        [string]$LoginName
    )
    try {
        Get-PnPUser -Identity $LoginName -Connection $Connection -ErrorAction Stop
    }
    catch {
        # "User cannot be found" is a plain ServerException. Anything else (incl. ServerUnauthorizedAccessException) is a real error.
        $exceptionTypes = for ($ex = $_.Exception; $ex; $ex = $ex.InnerException) { $ex.GetType().FullName }
        if ($exceptionTypes -contains 'Microsoft.SharePoint.Client.ServerException') { return $null }
        throw
    }
}

# SharePoint groups of the stale entry, so the memberships can be granted again after the removal.
function Get-SiteUserGroupNames {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,
        [Parameter(Mandatory = $true)]
        $SiteUser
    )
    try {
        $groups = Get-PnPProperty -ClientObject $SiteUser -Property Groups -Connection $Connection -ErrorAction Stop
        return (@($groups | ForEach-Object { $_.Title }) -join "; ")
    }
    catch {
        Write-RjRbLog -Message "Groups of '$($SiteUser.LoginName)' could not be read. Error: $($_.Exception.Message)" -Verbose
        return ""
    }
}

#endregion

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "UserPrincipalName: $($UserPrincipalName -join ', ')" -Verbose
Write-RjRbLog -Message "Scope: $Scope" -Verbose
Write-RjRbLog -Message "WhatIfMode: $WhatIfMode" -Verbose
Write-RjRbLog -Message "BulkLoadThreshold: $BulkLoadThreshold" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
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

Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

$upns = @($UserPrincipalName | ForEach-Object { "$_" -split "," } | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -ne "" } | Select-Object -Unique)
if ($upns.Count -eq 0) {
    throw "No users given."
}

$sendEmail = $false
if (-not [string]::IsNullOrWhiteSpace($EmailTo)) {
    if ([string]::IsNullOrWhiteSpace($EmailFrom)) {
        Write-Output "WARNING: No sender address is configured (RJReport.EmailSender). The report email is not sent. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings"
    }
    else {
        $sendEmail = $true
    }
}

if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Error "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -ErrorAction Continue
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

if ($WhatIfMode) {
    Write-Output "Mode: dry run - nothing is changed, mismatches are only reported"
}
else {
    Write-Output "Mode: live - stale user entries are removed from the sites"
}
Write-Output "Scope: $Scope"
Write-Output "Users: $($upns.Count)"

#endregion

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

if ($sendEmail) {
    # Send-RjReportEmail authenticates through the RJ RunbookHelper Graph session.
    try {
        Connect-RjRbGraph
    }
    catch {
        Write-Error "Failed to connect via Connect-RjRbGraph (required for the report email): $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
}

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
    Connect-PnPOnline -Url $sharePointAdminUrl -ManagedIdentity -ErrorAction Stop
    $VerbosePreference = "Continue"
    Write-Output "Connected to $sharePointAdminUrl"
}
catch {
    $VerbosePreference = "Continue"
    Write-Error "Failed to connect to the SharePoint admin center '$sharePointAdminUrl'. The managed identity needs the 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API (AppId 00000003-0000-0ff1-ce00-000000000000). Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

# --- Current PUID of every user from the SharePoint user profile ---
# Key = claims login name, as stored in the user information list of the sites.
$userRows = [System.Collections.Generic.List[object]]::new()
$targetByLogin = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($upn in $upns) {
    $userRow = [PSCustomObject]@{
        UserPrincipalName = $upn
        CurrentPuid       = ""
        Status            = ""
        SitesWithMismatch = 0
        EntriesRemoved    = 0
        RemovalsFailed    = 0
        Details           = ""
    }
    $userRows.Add($userRow)

    try {
        $VerbosePreference = "SilentlyContinue"
        $userProfile = Get-PnPUserProfileProperty -Account $upn -ErrorAction Stop
        $VerbosePreference = "Continue"
    }
    catch {
        $VerbosePreference = "Continue"
        $userRow.Status = "ProfileNotFound"
        $userRow.Details = $_.Exception.Message
        Write-Output "WARNING: The user profile of $upn could not be read. The user is skipped. Error: $($_.Exception.Message)"
        continue
    }

    $sid = [string]$userProfile.SID
    if (-not $sid -and $userProfile.UserProfileProperties) {
        $sid = [string]$userProfile.UserProfileProperties["SID"]
    }

    # SID format: i:0h.f|membership|<PUID>@live.com
    if ($sid -notmatch '\|(?<puid>[0-9a-f]+)@live\.com$') {
        $userRow.Status = "NoPuid"
        $userRow.Details = "SID in user profile: '$sid'"
        Write-Output "WARNING: No PUID in the user profile of $upn (SID: '$sid'). The user is skipped."
        continue
    }
    $userRow.CurrentPuid = $Matches.puid
    $userRow.Status = "Resolved"

    $loginName = [string]$userProfile.AccountName
    if ([string]::IsNullOrWhiteSpace($loginName)) {
        $loginName = "i:0#.f|membership|$upn"
    }
    $targetByLogin[$loginName] = $userRow
    Write-Output "User $upn - current PUID $($userRow.CurrentPuid)"
}

if ($targetByLogin.Count -eq 0) {
    Write-Error "None of the users could be resolved to a current PUID. Verify that the users exist, have accessed SharePoint at least once and that the managed identity has the 'User.Read.All' application permission on the Office 365 SharePoint Online API." -ErrorAction Continue
    throw "No user resolved"
}

$useBulkLoad = $targetByLogin.Count -gt $BulkLoadThreshold
Write-Output ("Site user lookup: {0}" -f $(if ($useBulkLoad) { "load all users per site" } else { "individual lookup of $($targetByLogin.Count) user(s) per site" }))

# --- Sites in scope ---
Write-Output "Retrieving site collections in scope (this can take several minutes in large tenants)..."
try {
    switch ($Scope) {
        "SharePoint" { $allSites = @(Get-PnPTenantSite -ErrorAction Stop) }
        "OneDrive" { $allSites = @(Get-PnPTenantSite -IncludeOneDriveSites -Filter "Url -like '-my.sharepoint.com/personal/'" -ErrorAction Stop) }
        default { $allSites = @(Get-PnPTenantSite -IncludeOneDriveSites -ErrorAction Stop) }
    }
}
catch {
    Write-Error "Failed to enumerate the site collections via Get-PnPTenantSite. If this is an access-denied error, the managed identity lacks 'Sites.FullControl.All' on the Office 365 SharePoint Online API. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw "Unable to retrieve SharePoint site collections"
}
Write-Output "Found $($allSites.Count) site(s) in scope."

#endregion

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Scan Sites"
Write-Output "---------------------"

$findingRows = [System.Collections.Generic.List[object]]::new()
$siteIssueRows = [System.Collections.Generic.List[object]]::new()
$processedSiteCount = 0
$skippedSiteCount = 0
$failedSiteCount = 0

$siteIndex = 0
foreach ($site in $allSites) {
    $siteIndex++
    if ($siteIndex % 250 -eq 0) {
        Write-Output "Progress: $siteIndex of $($allSites.Count) sites scanned, $($findingRows.Count) mismatch(es) found."
    }

    $siteUrl = [string]$site.Url
    $siteType = if ($siteUrl -like "*-my.sharepoint.com/personal/*") { "OneDrive" } else { "SharePoint" }

    $skipReason = Get-SiteSkipReason -Site $site
    if ($skipReason) {
        $skippedSiteCount++
        $siteIssueRows.Add([PSCustomObject]@{ SiteUrl = $siteUrl; SiteType = $siteType; Status = "Skipped"; Details = $skipReason })
        continue
    }

    try {
        $VerbosePreference = "SilentlyContinue"
        $siteConnection = Connect-PnPOnline -Url $siteUrl -ManagedIdentity -ReturnConnection -ErrorAction Stop
        if ($useBulkLoad) {
            $siteUsers = @(Get-PnPUser -Connection $siteConnection -ErrorAction Stop | Where-Object { $targetByLogin.ContainsKey([string]$_.LoginName) })
        }
        else {
            $siteUsers = @(foreach ($loginName in $targetByLogin.Keys) { Get-SiteUserByLogin -Connection $siteConnection -LoginName $loginName })
        }
        $VerbosePreference = "Continue"
    }
    catch {
        $VerbosePreference = "Continue"
        $message = $_.Exception.Message
        if ($message -match "archiv") {
            $skippedSiteCount++
            $siteIssueRows.Add([PSCustomObject]@{ SiteUrl = $siteUrl; SiteType = $siteType; Status = "Skipped"; Details = "Archived" })
        }
        else {
            $failedSiteCount++
            $siteIssueRows.Add([PSCustomObject]@{ SiteUrl = $siteUrl; SiteType = $siteType; Status = "ReadFailed"; Details = $message })
            Write-RjRbLog -Message "WARNING: Could not read the users of '$siteUrl'. Error: $message" -NoDebugOnly
        }
        continue
    }
    $processedSiteCount++

    foreach ($siteUser in $siteUsers) {
        if ($null -eq $siteUser) { continue }
        $target = $targetByLogin[[string]$siteUser.LoginName]

        # -eq is case-insensitive, so upper/lower case hex does not matter
        if (-not $siteUser.UserId -or $siteUser.UserId.NameId -eq $target.CurrentPuid) { continue }
        $target.SitesWithMismatch++

        $row = [PSCustomObject]@{
            UserPrincipalName = $target.UserPrincipalName
            SiteUrl           = $siteUrl
            SiteType          = $siteType
            StaleNameId       = [string]$siteUser.UserId.NameId
            CurrentPuid       = $target.CurrentPuid
            IsSiteAdmin       = [bool]$siteUser.IsSiteAdmin
            SharePointGroups  = Get-SiteUserGroupNames -Connection $siteConnection -SiteUser $siteUser
            Status            = ""
            Details           = ""
        }

        # The stale account owning a OneDrive is the old account's own OneDrive - the recreated
        # account gets a new one. The primary owner cannot be removed, so only report it.
        if ($siteType -eq "OneDrive" -and [string]$site.Owner -eq $target.UserPrincipalName) {
            $row.Status = "Skipped"
            $row.Details = "Old OneDrive of the user - the primary owner cannot be removed"
        }
        elseif ($WhatIfMode) {
            $row.Status = "WhatIf"
        }
        elseif ([string]$site.LockState -eq "ReadOnly") {
            $row.Status = "Skipped"
            $row.Details = "Site is locked (ReadOnly)"
        }
        else {
            try {
                if ($siteUser.IsSiteAdmin) {
                    Remove-PnPSiteCollectionAdmin -Owners $siteUser.LoginName -Connection $siteConnection -ErrorAction Stop
                }
                Remove-PnPUser -Identity $siteUser.Id -Force -Connection $siteConnection -ErrorAction Stop
                $row.Status = "Removed"
                $target.EntriesRemoved++
                Write-Output "Removed stale entry of $($target.UserPrincipalName) (ID $($row.StaleNameId)) from $siteUrl"
            }
            catch {
                $row.Status = "Failed"
                $row.Details = $_.Exception.Message
                $target.RemovalsFailed++
                Write-Output "ERROR: Removing the stale entry of $($target.UserPrincipalName) from $siteUrl failed: $($_.Exception.Message)"
            }
        }
        $findingRows.Add($row)
    }
}

$removedCount = @($findingRows | Where-Object { $_.Status -eq "Removed" }).Count
$wouldRemoveCount = @($findingRows | Where-Object { $_.Status -eq "WhatIf" }).Count
$removeFailedCount = @($findingRows | Where-Object { $_.Status -eq "Failed" }).Count
$notRemovableCount = @($findingRows | Where-Object { $_.Status -eq "Skipped" }).Count
$unresolvedUserCount = $upns.Count - $targetByLogin.Count

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Users resolved: $($targetByLogin.Count) of $($upns.Count)"
Write-Output "Sites in scope: $($allSites.Count)"
Write-Output "Sites scanned: $processedSiteCount"
Write-Output "Sites skipped (archived, redirect, no access): $skippedSiteCount"
Write-Output "Sites that could not be read: $failedSiteCount"
Write-Output "Mismatches found: $($findingRows.Count)"
if ($WhatIfMode) {
    Write-Output "Stale entries that would be removed: $wouldRemoveCount"
}
else {
    Write-Output "Stale entries removed: $removedCount (failed: $removeFailedCount)"
}
Write-Output "Stale entries that cannot be removed (old OneDrive, read-only site): $notRemovableCount"

if ($removeFailedCount -gt 0 -or $failedSiteCount -gt 0 -or $unresolvedUserCount -gt 0) {
    Write-Error "$removeFailedCount removal(s) failed, $failedSiteCount site(s) could not be read and $unresolvedUserCount user(s) could not be resolved. See the report and the job log for details." -ErrorAction Continue
}

#endregion

########################################################
#region     Report Part
########################################################

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

$userReportRows = @($userRows | Sort-Object UserPrincipalName)
$findingReportRows = @($findingRows | Sort-Object UserPrincipalName, SiteUrl)
$siteIssueReportRows = @($siteIssueRows | Sort-Object Status, SiteUrl)

$tempDir = $null
$reportFiles = @()
if ($sendEmail -or $CreateDownloadLink) {
    $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "SPOUserIdMismatch_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $fileNameBase = "SPOUserIdMismatch-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $exports = @(
        @{ Rows = $userReportRows; Name = "$fileNameBase-Users.csv" }
        @{ Rows = $findingReportRows; Name = "$fileNameBase-Mismatches.csv" }
        @{ Rows = $siteIssueReportRows; Name = "$fileNameBase-SkippedSites.csv" }
    )
    foreach ($export in $exports) {
        if ($export.Rows.Count -gt 0) {
            $path = Join-Path -Path $tempDir -ChildPath $export.Name
            $export.Rows | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
            $reportFiles += $path
        }
    }
}

if ($CreateDownloadLink) {
    Write-Output ""
    Write-Output "Uploading report to storage account..."
    $uploadResults = Publish-RjRbFilesToStorageContainer `
        -FilePaths $reportFiles `
        -ContainerName $ContainerName `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -LinkExpiryDays $LinkExpiryDays `
        -AddBlobNamePrefix $true
    foreach ($uploadResult in $uploadResults) {
        Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
        $uploadResult.SASLink | Out-String | Write-Output
    }
}

$brandingMailParams = $null
if ($sendEmail) {
    $runMode = if ($WhatIfMode) { "Dry run (nothing changed)" } else { "Live" }
    $removalLine = if ($WhatIfMode) { "- Stale entries that would be removed: **$wouldRemoveCount**" } else { "- Stale entries removed: **$removedCount** (failed: **$removeFailedCount**)" }
    $markdownContent = @"
# SharePoint User ID Mismatch Report

**Tenant:** $tenantDisplayName
**Run mode:** $runMode
**Scope:** $Scope
**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary

- Users resolved: **$($targetByLogin.Count)** of **$($upns.Count)**
- Sites in scope: **$($allSites.Count)**
- Sites scanned: **$processedSiteCount**
- Sites skipped (archived, redirect, no access): **$skippedSiteCount**
- Sites that could not be read: **$failedSiteCount**
- Mismatches found: **$($findingRows.Count)**
$removalLine
- Stale entries that cannot be removed (old OneDrive, read-only site): **$notRemovableCount**

Permissions and SharePoint group memberships of removed entries are not restored. The attached CSV files list the users, every mismatch with its former SharePoint groups and all skipped sites.

---

*This email was automatically generated. Please do not reply to this email.*
"@
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor
    try {
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject "SharePoint User ID Mismatch - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')" -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version -Attachments $reportFiles @brandingMailParams
        Write-RjRbLog -Message "Report email sent to '$EmailTo'." -Verbose
    }
    catch {
        Write-Error "Failed to send the report email: $($_.Exception.Message)" -ErrorAction Continue
    }
}

# Output Data tab: a title marker is only written when rows follow it.
Write-Output ""
$summaryValues = [ordered]@{
    "Users resolved"                                = $targetByLogin.Count
    "Users not resolved"                            = $unresolvedUserCount
    "Sites in scope"                                = $allSites.Count
    "Sites scanned"                                 = $processedSiteCount
    "Sites skipped (archived, redirect, no access)" = $skippedSiteCount
    "Sites that could not be read"                  = $failedSiteCount
    "Mismatches found"                              = $findingRows.Count
}
if ($WhatIfMode) {
    $summaryValues["Stale entries that would be removed"] = $wouldRemoveCount
}
else {
    $summaryValues["Stale entries removed"] = $removedCount
    $summaryValues["Removals failed"] = $removeFailedCount
}
$summaryValues["Stale entries that cannot be removed"] = $notRemovableCount
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output @(foreach ($metric in $summaryValues.Keys) { [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] } })

Write-Output ([PSCustomObject]@{ RjTableTitle = "Users" })
Write-Output $userReportRows
if ($findingReportRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = $(if ($WhatIfMode) { "Mismatches (dry run)" } else { "Mismatches" }) })
    Write-Output $findingReportRows
}
if ($siteIssueReportRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Skipped sites" })
    Write-Output $siteIssueReportRows
}

#endregion

########################################################
#region     Cleanup
########################################################

if ($brandingMailParams) {
    foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
        if ($brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
            Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
        }
    }
}
if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

try {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}
catch {
    Write-RjRbLog -Message "Microsoft Graph session was already closed." -Verbose
}

Write-Output ""
Write-Output "Done!"

#endregion

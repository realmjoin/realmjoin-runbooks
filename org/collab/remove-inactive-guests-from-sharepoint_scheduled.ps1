<#
    .SYNOPSIS
    Remove disabled inactive guests from all SharePoint sites and OneDrives

    .DESCRIPTION
    Finds disabled guest accounts without a sign-in for the configured number of days and removes them from the user information list of every SharePoint site collection and OneDrive (equivalent to Remove-SPOUser). This prevents the site user ID mismatch that occurs when a deleted guest is invited again later. All guests are determined first; the expensive pass over all site collections only starts when at least one guest needs to be removed, and every site is visited only once for all guests together. Locked, archived and redirect sites are skipped. Members of the ignore groups are never touched. Nothing is written to the guest account itself. A dry run lists all removals without changing anything.

    .PARAMETER RemoveAfterDays
    Disabled guests with no sign-in for at least this many days are removed from SharePoint.

    .PARAMETER IgnoreGroupIds
    Guests that are members of one of these groups, directly or through nested groups, are never processed. Use the same groups as in Cleanup Inactive Guests.

    .PARAMETER WhatIfMode
    Only reports from which sites the guests would be removed without changing anything.

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
            "RemoveAfterDays": {
                "DisplayName": "Remove after (days without sign-in)"
            },
            "IgnoreGroupIds": {
                "DisplayName": "Ignore groups"
            },
            "WhatIfMode": {
                "DisplayName": "Dry run?"
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
    [ValidateRange(1, 3650)]
    [int]$RemoveAfterDays = 90,

    [ValidateScript({ Use-RjRbInterface -Type Graph -Entity Group -DisplayName "Ignore groups" })]
    [string[]]$IgnoreGroupIds = @(),

    [bool]$WhatIfMode = $true,

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

    [string]$ContainerName = "remove-inactive-guests-from-sharepoint",

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

function Get-GraphPagedResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )
    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    do {
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        if ($response.value) {
            $allResults.AddRange([object[]]$response.value)
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)
    return $allResults
}

# Graph returns ISO strings (or DateTime objects, depending on the deserializer); 0001-01-01 means "never".
function ConvertTo-UtcDateTime {
    param($Value)
    if ($null -eq $Value -or "$Value" -eq "") { return $null }
    if ($Value -is [datetime]) {
        $parsed = $Value.ToUniversalTime()
    }
    else {
        $parsed = [datetime]::MinValue
        $styles = [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal
        if (-not [datetime]::TryParse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) {
            return $null
        }
    }
    if ($parsed.Year -le 1) { return $null }
    return $parsed
}

# Same rule as Cleanup Inactive Guests: most recent sign-in, creation date for guests that never signed in.
function Get-GuestLastActivity {
    param(
        [Parameter(Mandatory = $true)]
        $User
    )
    $candidates = @()
    if ($User.signInActivity) {
        foreach ($property in @('lastSignInDateTime', 'lastNonInteractiveSignInDateTime', 'lastSuccessfulSignInDateTime')) {
            $date = ConvertTo-UtcDateTime -Value $User.signInActivity.$property
            if ($date) { $candidates += $date }
        }
    }
    if ($candidates.Count -gt 0) {
        return [PSCustomObject]@{
            Date  = ($candidates | Sort-Object -Descending | Select-Object -First 1)
            Basis = "LastSignIn"
        }
    }
    return [PSCustomObject]@{
        Date  = ConvertTo-UtcDateTime -Value $User.createdDateTime
        Basis = "Created (never signed in)"
    }
}

# Returns a reason when a site must not be touched, otherwise $null.
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
    if ($lockState -in @("ReadOnly", "NoAccess")) { return "Locked ($lockState)" }
    if ($archiveStatus -ne "" -and $archiveStatus -ne "NotArchived") { return "Archived ($archiveStatus)" }
    if ($status -ne "" -and $status -ne "Active") { return "Not active ($status)" }
    return $null
}

#endregion

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "RemoveAfterDays: $RemoveAfterDays" -Verbose
Write-RjRbLog -Message "IgnoreGroupIds: $($IgnoreGroupIds -join ', ')" -Verbose
Write-RjRbLog -Message "WhatIfMode: $WhatIfMode" -Verbose
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

$IgnoreGroupIds = @($IgnoreGroupIds | ForEach-Object { "$_".Trim() } | Where-Object { $_ -ne "" } | Select-Object -Unique)

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
    Write-Output "Mode: dry run - nothing is changed, removals are only reported"
}
else {
    Write-Output "Mode: live - guests are removed from SharePoint sites"
}
Write-Output "Remove after: $RemoveAfterDays day(s) without sign-in (only disabled guests)"
Write-Output "Ignore groups: $(if ($IgnoreGroupIds.Count -gt 0) { $IgnoreGroupIds.Count } else { 'none' })"

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

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

# --- Ignore groups: a group that cannot be read aborts the run, so no protected guest is processed ---
$ignoredUserIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($groupId in $IgnoreGroupIds) {
    try {
        $group = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$groupId`?`$select=id,displayName" -Method GET -ErrorAction Stop
        $members = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/transitiveMembers/microsoft.graph.user?`$select=id&`$top=999")
    }
    catch {
        Write-Error "Ignore group '$groupId' or its members could not be read. The run is aborted so that no protected guest is processed. Verify that the group exists and that the managed identity has the 'GroupMember.Read.All' permission. Error: $($_.Exception.Message)" -ErrorAction Continue
        throw "Ignore group '$groupId' not available"
    }
    foreach ($member in $members) {
        [void]$ignoredUserIds.Add([string]$member.id)
    }
    Write-Output "Ignore group '$($group.displayName)': $($members.Count) user(s)"
}

# --- Disabled guest accounts ---
Write-Output "Retrieving disabled guest accounts..."
$guests = @()
try {
    $select = "id,displayName,userPrincipalName,mail,accountEnabled,createdDateTime,signInActivity"
    $guests = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users?`$filter=userType eq 'Guest'&`$select=$select&`$top=999" | Where-Object { -not $_.accountEnabled })
}
catch {
    $message = $_.Exception.Message
    if ($message -match "403|Forbidden|401|Unauthorized|Authentication_RequestFromNonPremiumTenant") {
        Write-Error "Access denied while reading guest accounts with their sign-in activity. The managed identity needs the Graph application permissions 'User.ReadWrite.All' and 'AuditLog.Read.All', and the tenant needs an Entra ID P1 license for signInActivity. Error: $message" -ErrorAction Continue
        throw "Missing permission or license to read signInActivity"
    }
    Write-Error "Failed to retrieve guest accounts from Microsoft Graph: $message" -ErrorAction Continue
    throw
}
Write-Output "Found $($guests.Count) disabled guest account(s)."

# --- Candidates: disabled, inactive long enough, not ignored ---
$nowUtc = (Get-Date).ToUniversalTime()
$candidates = [System.Collections.Generic.List[object]]::new()
$candidateByLogin = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
$ignoredCount = 0
$notDueCount = 0

foreach ($guest in $guests) {
    $activity = Get-GuestLastActivity -User $guest
    if ($null -eq $activity.Date) {
        Write-RjRbLog -Message "Guest '$($guest.userPrincipalName)' ($($guest.id)) has no sign-in and no creation date. Skipped." -Verbose
        continue
    }
    $inactiveDays = [int][math]::Floor(($nowUtc - $activity.Date).TotalDays)
    if ($inactiveDays -lt $RemoveAfterDays) {
        $notDueCount++
        continue
    }
    if ($ignoredUserIds.Contains([string]$guest.id)) {
        $ignoredCount++
        continue
    }

    $upn = [string]$guest.userPrincipalName
    $candidate = [PSCustomObject]@{
        DisplayName       = [string]$guest.displayName
        UserPrincipalName = $upn
        Mail              = [string]$guest.mail
        LastActivity      = $activity.Date.ToString("yyyy-MM-dd HH:mm")
        ActivityBasis     = $activity.Basis
        InactiveDays      = $inactiveDays
        SitesFound        = 0
        SitesRemoved      = 0
        SitesFailed       = 0
        UserId            = [string]$guest.id
    }
    $candidates.Add($candidate)
    # Entra guests appear in SharePoint with the membership claim of their UPN.
    $candidateByLogin["i:0#.f|membership|$upn"] = $candidate
}

Write-Output "Disabled guests not yet due ($RemoveAfterDays days): $notDueCount"
Write-Output "Ignored (member of an ignore group): $ignoredCount"
Write-Output "Guests to remove from SharePoint: $($candidates.Count)"
foreach ($candidate in $candidates) {
    Write-Output "  $($candidate.UserPrincipalName) ($($candidate.InactiveDays) days inactive)"
}

#endregion

########################################################
#region     Main Part
########################################################

$removalRows = [System.Collections.Generic.List[object]]::new()
$siteIssueRows = [System.Collections.Generic.List[object]]::new()
$allSites = @()
$processedSiteCount = 0
$skippedSiteCount = 0
$failedSiteCount = 0

if ($candidates.Count -eq 0) {
    Write-Output ""
    Write-Output "No guest needs to be removed from SharePoint. The site collections are not scanned."
}
else {
    Write-Output ""
    Write-Output "Connect to SharePoint Online"
    Write-Output "---------------------"

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

    Write-Output "Retrieving all site collections including OneDrives (this can take several minutes in large tenants)..."
    try {
        $allSites = @(Get-PnPTenantSite -IncludeOneDriveSites -ErrorAction Stop)
    }
    catch {
        Write-Error "Failed to enumerate the site collections via Get-PnPTenantSite. If this is an access-denied error, the managed identity lacks 'Sites.FullControl.All' on the Office 365 SharePoint Online API. Error: $($_.Exception.Message)" -ErrorAction Continue
        throw "Unable to retrieve SharePoint site collections"
    }
    Write-Output "Found $($allSites.Count) site collection(s) and OneDrive(s)."

    Write-Output ""
    Write-Output "Scan Site Collections"
    Write-Output "---------------------"

    $siteIndex = 0
    foreach ($site in $allSites) {
        $siteIndex++
        if ($siteIndex % 250 -eq 0) {
            Write-Output "Progress: $siteIndex of $($allSites.Count) sites scanned, $($removalRows.Count) guest entries found."
        }

        $siteUrl = [string]$site.Url
        $siteType = if ([string]$site.Template -like "SPSPERS*") { "OneDrive" } else { "SharePoint" }

        $skipReason = Get-SiteSkipReason -Site $site
        if ($skipReason) {
            $skippedSiteCount++
            $siteIssueRows.Add([PSCustomObject]@{ SiteUrl = $siteUrl; SiteType = $siteType; Status = "Skipped"; Details = $skipReason })
            continue
        }

        # One read of the user information list per site, matched against all guests at once.
        $siteUsers = $null
        try {
            $VerbosePreference = "SilentlyContinue"
            $siteConnection = Connect-PnPOnline -Url $siteUrl -ManagedIdentity -ReturnConnection -ErrorAction Stop
            $siteUsers = @(Get-PnPUser -Connection $siteConnection -ErrorAction Stop)
            $VerbosePreference = "Continue"
        }
        catch {
            $VerbosePreference = "Continue"
            $message = $_.Exception.Message
            if ($message -match "archiv") {
                $skippedSiteCount++
                $siteIssueRows.Add([PSCustomObject]@{ SiteUrl = $siteUrl; SiteType = $siteType; Status = "Skipped"; Details = "Archived" })
            }
            elseif ($message -match "locked|read-only|ReadOnly") {
                $skippedSiteCount++
                $siteIssueRows.Add([PSCustomObject]@{ SiteUrl = $siteUrl; SiteType = $siteType; Status = "Skipped"; Details = "Locked" })
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
            $loginName = [string]$siteUser.LoginName
            if (-not $candidateByLogin.ContainsKey($loginName)) { continue }
            $candidate = $candidateByLogin[$loginName]
            $candidate.SitesFound++

            $row = [PSCustomObject]@{
                UserPrincipalName = $candidate.UserPrincipalName
                DisplayName       = $candidate.DisplayName
                SiteUrl           = $siteUrl
                SiteType          = $siteType
                Action            = "RemoveFromSite"
                Status            = ""
                Details           = ""
            }

            if ($WhatIfMode) {
                $row.Status = "WhatIf"
            }
            else {
                try {
                    Remove-PnPUser -Identity $loginName -Force -Connection $siteConnection -ErrorAction Stop
                    $row.Status = "Done"
                    $candidate.SitesRemoved++
                    Write-Output "Removed $($candidate.UserPrincipalName) from $siteUrl"
                }
                catch {
                    $row.Status = "Failed"
                    $row.Details = $_.Exception.Message
                    $candidate.SitesFailed++
                    Write-Output "ERROR: Removing $($candidate.UserPrincipalName) from $siteUrl failed: $($_.Exception.Message)"
                }
            }
            $removalRows.Add($row)
        }
    }
}

$removedCount = @($removalRows | Where-Object { $_.Status -eq "Done" }).Count
$wouldRemoveCount = @($removalRows | Where-Object { $_.Status -eq "WhatIf" }).Count
$removeFailedCount = @($removalRows | Where-Object { $_.Status -eq "Failed" }).Count

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Guests to remove from SharePoint: $($candidates.Count)"
if ($candidates.Count -gt 0) {
    Write-Output "Site collections and OneDrives total: $($allSites.Count)"
    Write-Output "Sites scanned: $processedSiteCount"
    Write-Output "Sites skipped (locked, archived, redirect): $skippedSiteCount"
    Write-Output "Sites that could not be read: $failedSiteCount"
    if ($WhatIfMode) {
        Write-Output "Site memberships that would be removed: $wouldRemoveCount"
    }
    else {
        Write-Output "Site memberships removed: $removedCount (failed: $removeFailedCount)"
    }
}

if ($removeFailedCount -gt 0 -or $failedSiteCount -gt 0) {
    Write-Error "$removeFailedCount removal(s) failed and $failedSiteCount site(s) could not be read. See the report and the job log for details." -ErrorAction Continue
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

$guestRows = @($candidates | Select-Object DisplayName, UserPrincipalName, Mail, LastActivity, ActivityBasis, InactiveDays, SitesFound, SitesRemoved, SitesFailed, UserId)
$removalReportRows = @($removalRows | Sort-Object UserPrincipalName, SiteUrl)
$siteIssueReportRows = @($siteIssueRows | Sort-Object Status, SiteUrl)

$tempDir = $null
$reportFiles = @()
if (($sendEmail -or $CreateDownloadLink) -and $candidates.Count -gt 0) {
    $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "GuestSPOCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $fileNameBase = "GuestSPOCleanup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $exports = @(
        @{ Rows = $guestRows; Name = "$fileNameBase-Guests.csv" }
        @{ Rows = $removalReportRows; Name = "$fileNameBase-SiteRemovals.csv" }
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
    if ($reportFiles.Count -gt 0) {
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
    else {
        Write-Output "No guest to process - skipping report upload."
    }
}

$brandingMailParams = $null
if ($sendEmail -and $reportFiles.Count -gt 0) {
    $runMode = if ($WhatIfMode) { "Dry run (nothing changed)" } else { "Live" }
    $removalLine = if ($WhatIfMode) { "- Site memberships that would be removed: **$wouldRemoveCount**" } else { "- Site memberships removed: **$removedCount** (failed: **$removeFailedCount**)" }
    $markdownContent = @"
# Guest SharePoint Cleanup Report

**Tenant:** $tenantDisplayName
**Run mode:** $runMode
**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary

- Disabled guests without sign-in for **$RemoveAfterDays** days: **$($candidates.Count)**
- Site collections and OneDrives total: **$($allSites.Count)**
- Sites scanned: **$processedSiteCount**
- Sites skipped (locked, archived, redirect): **$skippedSiteCount**
- Sites that could not be read: **$failedSiteCount**
$removalLine

The attached CSV files list the guests, every site membership and all skipped sites.

---

*This email was automatically generated. Please do not reply to this email.*
"@
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor
    try {
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject "Guest SharePoint Cleanup - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')" -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version -Attachments $reportFiles @brandingMailParams
        Write-RjRbLog -Message "Report email sent to '$EmailTo'." -Verbose
    }
    catch {
        Write-Error "Failed to send the report email: $($_.Exception.Message)" -ErrorAction Continue
    }
}
elseif ($sendEmail) {
    Write-Output "No guest to process - no report email sent."
}

# Output Data tab: a title marker is only written when rows follow it.
Write-Output ""
$summaryValues = [ordered]@{
    "Guests to remove from SharePoint"           = $candidates.Count
    "Ignored (member of an ignore group)"        = $ignoredCount
    "Site collections and OneDrives total"       = $allSites.Count
    "Sites scanned"                              = $processedSiteCount
    "Sites skipped (locked, archived, redirect)" = $skippedSiteCount
    "Sites that could not be read"               = $failedSiteCount
}
if ($WhatIfMode) {
    $summaryValues["Site memberships that would be removed"] = $wouldRemoveCount
}
else {
    $summaryValues["Site memberships removed"] = $removedCount
    $summaryValues["Removals failed"] = $removeFailedCount
}
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output @(foreach ($metric in $summaryValues.Keys) { [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] } })

if ($guestRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Guests" })
    Write-Output $guestRows
}
if ($removalReportRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = $(if ($WhatIfMode) { "Planned site removals (dry run)" } else { "Site removals" }) })
    Write-Output $removalReportRows
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

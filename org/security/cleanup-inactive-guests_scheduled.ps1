<#
    .SYNOPSIS
    Disable and delete guest accounts without recent sign-in

    .DESCRIPTION
    Evaluates every guest account in Entra ID by its last sign-in. Guests without a sign-in for the configured number of days are disabled; guests that are already disabled and have no sign-in for a longer period are deleted. Guests that never signed in are measured from their creation date. Members of the ignore groups are never touched. A dry run lists all actions without changing anything. All actions are written to a CSV report that can be sent by email or provided as a download link.

    .PARAMETER DisableAfterDays
    Guests with no sign-in for at least this many days are disabled.

    .PARAMETER DeleteAfterDays
    Disabled guests with no sign-in for at least this many days are deleted. Must be greater than "Disable after (days)".

    .PARAMETER IgnoreGroupIds
    Guests that are members of one of these groups, directly or through nested groups, are never disabled or deleted.

    .PARAMETER WhatIfMode
    Only reports what would be disabled or deleted without changing anything.

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
    Also upload the CSV report and return a download link that expires after a few days.

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
            "DisableAfterDays": {
                "DisplayName": "Disable after (days without sign-in)"
            },
            "DeleteAfterDays": {
                "DisplayName": "Delete after (days without sign-in)"
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
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [ValidateRange(1, 3650)]
    [int]$DisableAfterDays = 14,

    [ValidateRange(1, 3650)]
    [int]$DeleteAfterDays = 180,

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

    [string]$ContainerName = "cleanup-inactive-guests",

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

# Most recent of interactive, non-interactive and successful sign-in. Guests that never signed in are
# measured from their creation date, so a freshly invited guest is not disabled right away.
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

#endregion

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "DisableAfterDays: $DisableAfterDays" -Verbose
Write-RjRbLog -Message "DeleteAfterDays: $DeleteAfterDays" -Verbose
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

if ($DeleteAfterDays -le $DisableAfterDays) {
    Write-Error "DeleteAfterDays ($DeleteAfterDays) must be greater than DisableAfterDays ($DisableAfterDays). A guest is disabled first and deleted in a later run." -ErrorAction Continue
    throw "Invalid parameter: DeleteAfterDays must be greater than DisableAfterDays"
}

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
    Write-Output "Mode: dry run - nothing is changed, actions are only reported"
}
else {
    Write-Output "Mode: live - guests are disabled and deleted"
}
Write-Output "Disable after: $DisableAfterDays day(s) without sign-in"
Write-Output "Delete after: $DeleteAfterDays day(s) without sign-in (only already disabled guests)"
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

# --- Ignore groups: resolve every group first. A missing group aborts the run, because guests that
# should be protected would otherwise be disabled or deleted. ---
$ignoredUserIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($groupId in $IgnoreGroupIds) {
    try {
        $group = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$groupId`?`$select=id,displayName" -Method GET -ErrorAction Stop
    }
    catch {
        Write-Error "Ignore group '$groupId' could not be read. The run is aborted so that no protected guest is processed. Verify that the group exists and that the managed identity has the 'GroupMember.Read.All' permission. Error: $($_.Exception.Message)" -ErrorAction Continue
        throw "Ignore group '$groupId' not available"
    }
    try {
        $members = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/transitiveMembers/microsoft.graph.user?`$select=id&`$top=999")
    }
    catch {
        Write-Error "Members of ignore group '$($group.displayName)' ($groupId) could not be read. The run is aborted so that no protected guest is processed. Error: $($_.Exception.Message)" -ErrorAction Continue
        throw "Ignore group '$groupId' members not available"
    }
    foreach ($member in $members) {
        [void]$ignoredUserIds.Add([string]$member.id)
    }
    Write-Output "Ignore group '$($group.displayName)': $($members.Count) user(s)"
}

# --- All guest accounts with sign-in activity ---
Write-Output "Retrieving guest accounts..."
$guests = @()
try {
    $select = "id,displayName,userPrincipalName,mail,accountEnabled,createdDateTime,externalUserState,signInActivity"
    $guests = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users?`$filter=userType eq 'Guest'&`$select=$select&`$top=999")
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
Write-Output "Found $($guests.Count) guest account(s)."
Write-RjRbLog -Message "Retrieved $($guests.Count) guest accounts." -Verbose

#endregion

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Evaluate Guests"
Write-Output "---------------------"

$nowUtc = (Get-Date).ToUniversalTime()
$results = [System.Collections.Generic.List[object]]::new()
$activeCount = 0
$alreadyDisabledCount = 0
$unknownActivityCount = 0

foreach ($guest in $guests) {
    $activity = Get-GuestLastActivity -User $guest
    if ($null -eq $activity.Date) {
        # Neither a sign-in nor a creation date - never act on a guest whose age cannot be determined.
        $unknownActivityCount++
        Write-RjRbLog -Message "Guest '$($guest.userPrincipalName)' ($($guest.id)) has no sign-in and no creation date. Skipped." -Verbose
        continue
    }
    $inactiveDays = [int][math]::Floor(($nowUtc - $activity.Date).TotalDays)
    $enabled = [bool]$guest.accountEnabled

    $action = $null
    if (-not $enabled -and $inactiveDays -ge $DeleteAfterDays) {
        $action = "Delete"
    }
    elseif ($enabled -and $inactiveDays -ge $DisableAfterDays) {
        $action = "Disable"
    }

    if ($null -eq $action) {
        if ($enabled) { $activeCount++ } else { $alreadyDisabledCount++ }
        continue
    }

    $createdDate = ConvertTo-UtcDateTime -Value $guest.createdDateTime

    $row = [PSCustomObject]@{
        DisplayName         = [string]$guest.displayName
        UserPrincipalName   = [string]$guest.userPrincipalName
        Mail                = [string]$guest.mail
        ExternalUserState   = [string]$guest.externalUserState
        AccountEnabled      = $enabled
        CreatedDateTime     = if ($createdDate) { $createdDate.ToString("yyyy-MM-dd HH:mm") } else { "" }
        LastActivity        = $activity.Date.ToString("yyyy-MM-dd HH:mm")
        ActivityBasis       = $activity.Basis
        InactiveDays        = $inactiveDays
        Action              = $action
        Status              = ""
        Details             = ""
        UserId              = [string]$guest.id
    }

    if ($ignoredUserIds.Contains([string]$guest.id)) {
        $row.Status = "Ignored"
        $row.Details = "Member of an ignore group"
    }
    elseif ($WhatIfMode) {
        $row.Status = "WhatIf"
    }
    else {
        $row.Status = "Pending"
    }
    $results.Add($row)
}

# --- Apply ---
foreach ($row in ($results | Where-Object { $_.Status -eq "Pending" })) {
    try {
        if ($row.Action -eq "Disable") {
            Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($row.UserId)" -Method PATCH -Body (@{ accountEnabled = $false } | ConvertTo-Json -Compress) -ContentType "application/json" -ErrorAction Stop | Out-Null
            $row.Status = "Done"
            $row.AccountEnabled = $false
            Write-Output "Disabled: $($row.UserPrincipalName) ($($row.InactiveDays) days inactive)"
        }
        else {
            Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($row.UserId)" -Method DELETE -ErrorAction Stop | Out-Null
            $row.Status = "Done"
            Write-Output "Deleted: $($row.UserPrincipalName) ($($row.InactiveDays) days inactive)"
        }
    }
    catch {
        $row.Status = "Failed"
        $row.Details = $_.Exception.Message
        Write-Output "ERROR: $($row.Action) of '$($row.UserPrincipalName)' failed: $($_.Exception.Message)"
        Write-RjRbLog -Message "WARNING: $($row.Action) of guest '$($row.UserPrincipalName)' ($($row.UserId)) failed. If the error is 403 Forbidden, the managed identity needs 'User.ReadWrite.All' (and for guests with an admin role a privileged role). Error: $($_.Exception.Message)" -NoDebugOnly
    }
    Start-Sleep -Milliseconds 100
}

$countOf = { param($Action, $Status) @($results | Where-Object { $_.Action -eq $Action -and $_.Status -eq $Status }).Count }
$disableWhatIf = & $countOf "Disable" "WhatIf"
$disableDone = & $countOf "Disable" "Done"
$disableFailed = & $countOf "Disable" "Failed"
$deleteWhatIf = & $countOf "Delete" "WhatIf"
$deleteDone = & $countOf "Delete" "Done"
$deleteFailed = & $countOf "Delete" "Failed"
$ignoredCount = @($results | Where-Object { $_.Status -eq "Ignored" }).Count

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Guest accounts total: $($guests.Count)"
Write-Output "Active guests (no action): $activeCount"
Write-Output "Disabled guests not yet due for deletion: $alreadyDisabledCount"
Write-Output "Guests without sign-in and creation date (skipped): $unknownActivityCount"
Write-Output "Ignored (member of an ignore group): $ignoredCount"
if ($WhatIfMode) {
    Write-Output "Would disable: $disableWhatIf"
    Write-Output "Would delete: $deleteWhatIf"
}
else {
    Write-Output "Disabled: $disableDone (failed: $disableFailed)"
    Write-Output "Deleted: $deleteDone (failed: $deleteFailed)"
}

if (($disableFailed + $deleteFailed) -gt 0) {
    Write-Error "$($disableFailed + $deleteFailed) action(s) failed. See the report and the job log for details." -ErrorAction Continue
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

$reportRows = @($results | Sort-Object -Property Action, Status, InactiveDays -Descending | Select-Object DisplayName, UserPrincipalName, Mail, ExternalUserState, AccountEnabled, CreatedDateTime, LastActivity, ActivityBasis, InactiveDays, Action, Status, Details, UserId)

$tempDir = $null
$reportFiles = @()
if (($sendEmail -or $CreateDownloadLink) -and $reportRows.Count -gt 0) {
    $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "GuestCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $csvFilePath = Join-Path -Path $tempDir -ChildPath "GuestCleanup-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    $reportRows | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
    $reportFiles += $csvFilePath
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
        Write-Output "No guest actions - skipping report upload."
    }
}

$brandingMailParams = $null
if ($sendEmail -and $reportFiles.Count -gt 0) {
    $runMode = if ($WhatIfMode) { "Dry run (nothing changed)" } else { "Live" }
    $actionLines = if ($WhatIfMode) {
        "- Would disable: **$disableWhatIf**`n- Would delete: **$deleteWhatIf**"
    }
    else {
        "- Disabled: **$disableDone** (failed: **$disableFailed**)`n- Deleted: **$deleteDone** (failed: **$deleteFailed**)"
    }
    $markdownContent = @"
# Inactive Guest Cleanup Report

**Tenant:** $tenantDisplayName
**Run mode:** $runMode
**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Rules

- Disable after **$DisableAfterDays** days without sign-in
- Delete disabled guests after **$DeleteAfterDays** days without sign-in

## Summary

- Guest accounts total: **$($guests.Count)**
$actionLines
- Ignored (ignore group): **$ignoredCount**

The attached CSV file lists every guest with the action and its result.

---

*This email was automatically generated. Please do not reply to this email.*
"@
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor
    try {
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject "Inactive Guest Cleanup - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')" -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version -Attachments $reportFiles @brandingMailParams
        Write-RjRbLog -Message "Report email sent to '$EmailTo'." -Verbose
    }
    catch {
        Write-Error "Failed to send the report email: $($_.Exception.Message)" -ErrorAction Continue
    }
}
elseif ($sendEmail) {
    Write-Output "No guest actions - no report email sent."
}

# Output Data tab: a title marker is only written when rows follow it.
Write-Output ""
$summaryValues = [ordered]@{
    "Guest accounts total"                     = $guests.Count
    "Active guests (no action)"                = $activeCount
    "Disabled guests not yet due for deletion" = $alreadyDisabledCount
    "Ignored (member of an ignore group)"      = $ignoredCount
}
if ($WhatIfMode) {
    $summaryValues["Would disable"] = $disableWhatIf
    $summaryValues["Would delete"] = $deleteWhatIf
}
else {
    $summaryValues["Disabled"] = $disableDone
    $summaryValues["Deleted"] = $deleteDone
    $summaryValues["Failed"] = $disableFailed + $deleteFailed
}
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output @(foreach ($metric in $summaryValues.Keys) { [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] } })

if ($reportRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = $(if ($WhatIfMode) { "Planned guest actions (dry run)" } else { "Guest actions" }) })
    Write-Output $reportRows
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

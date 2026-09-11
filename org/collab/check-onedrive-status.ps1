<#
	.SYNOPSIS
	Check the status of a user's OneDrive

	.DESCRIPTION
	Connects to the SharePoint admin center using the managed identity and retrieves the status of the specified user's personal site (OneDrive). Reports whether the site is active or archived, its lock state, and whether it resides in the tenant recycle bin. The runbook is read-only and makes no changes to the site or its state.

	.PARAMETER UserPrincipalName
	User principal name of the user whose OneDrive status should be checked. This parameter accepts the UPN of a user whose account has already been deleted, as deleted users' OneDrive sites may still exist in the tenant recycle bin.

	.PARAMETER CallerName
	Name of the user or system that started the runbook. Tracked for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {

			"UserPrincipalName": {
				"DisplayName": "User Principal Name (UPN)"
			},
			"CallerName": {
				"Hide": true
			}
		}
	}

	.NOTES

	Common Use Cases:
	- Check whether an active user's OneDrive is provisioned, and if so, whether it is locked
	  or archived.
	- Check whether a deleted user's OneDrive still exists in the tenant recycle bin, and when
	  it is scheduled to be purged.

	Parameter Interactions:
	- UserPrincipalName accepts the UPN of an already-deleted account, not only active users.
	  This is intentional: a user picker cannot select a deleted account, so the parameter is
	  free text rather than a picker.
	- For a deleted user, recycle bin matching relies on the deleted site's SiteOwnerEmail; a
	  missing value or a prior UPN rename can cause a false "Not found" result.

	This runbook is strictly read-only and makes no changes to the tenant.
#>
#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "PnP.PowerShell"; ModuleVersion = "3.4.1" }

param(

    [Parameter(Mandatory = $true)]
    [string]$UserPrincipalName,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
$Version = "1.4.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "UserPrincipalName: $UserPrincipalName" -Verbose
#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################
$UserPrincipalName = $UserPrincipalName.Trim()

if ([string]::IsNullOrWhiteSpace($UserPrincipalName)) {
    Write-Error "UserPrincipalName must not be empty. Provide the UPN of the user whose OneDrive should be checked (e.g. user@contoso.com)." -ErrorAction Continue
    throw "UserPrincipalName is empty"
}

# Deliberately a light sanity check, not a strict RFC validation: the UPN may belong to an already
# deleted account, so it cannot be verified against Entra ID before the SharePoint lookups run.
if ($UserPrincipalName -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
    Write-Error "'$UserPrincipalName' is not a valid user principal name. Expected the format user@domain.tld (e.g. user@contoso.com)." -ErrorAction Continue
    throw "UserPrincipalName '$UserPrincipalName' has an invalid format"
}
#endregion Parameter Validation

########################################################
#region     Connect Part
########################################################
Write-Output ""
Write-Output "Connect to SharePoint Online"
Write-Output "---------------------"

# get sharepoint admin URL

Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
$mgSPOrootSiteResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/sites/root"
$SharePointAdminUrl = $mgSPOrootSiteResponse["webUrl"]
$SharePointAdminUrl = $SharePointAdminUrl.Replace(".sharepoint.com","-admin.sharepoint.com")
Write-RjRbLog -Message "SharePointAdminUrl: $SharePointAdminUrl" -Verbose

if ([string]::IsNullOrWhiteSpace($SharePointAdminUrl)) {
    Write-Error "SharePointAdminUrl is not discovered." -ErrorAction Continue
    throw "SharePointAdminUrl is not configured"
}

$pnpConnected = $false
try {
    $VerbosePreference = "SilentlyContinue"
    Connect-PnPOnline -Url $SharePointAdminUrl -ManagedIdentity -ErrorAction Stop
    $VerbosePreference = "Continue"
    # Confirm the connection actually landed on a working SharePoint context before the
    # tenant-admin cmdlets in the next region rely on it.
    Get-PnPWeb -ErrorAction Stop | Out-Null
    $pnpConnected = $true
    Write-Output "Connected to SharePoint Online: $SharePointAdminUrl"
}
catch {
    $errorMessage = $_.Exception.Message
    if ($errorMessage -match "401|403|Access denied|Unauthorized") {
        Write-Error "Access denied while connecting to SharePoint Online ($SharePointAdminUrl). The Automation account's managed identity needs the 'Sites.FullControl.All' APPLICATION permission granted on the Office 365 SharePoint Online API (AppId 00000003-0000-0ff1-ce00-000000000000), with admin consent. Microsoft Graph permissions alone are NOT sufficient - the permission grant must be made on the SharePoint Online API specifically. Error: $errorMessage" -ErrorAction Continue
        throw "Access denied connecting to SharePoint Online"
    }
    elseif ($errorMessage -match "managed identity|ManagedIdentity|identity endpoint|token") {
        Write-Error "Failed to acquire a token via the system-assigned managed identity. Ensure a system-assigned managed identity is enabled on the Automation account and that it has been granted 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API (AppId 00000003-0000-0ff1-ce00-000000000000). Error: $errorMessage" -ErrorAction Continue
        throw "Managed identity authentication failed"
    }
    else {
        Write-Error "Failed to connect to SharePoint Online ($SharePointAdminUrl). Verify SharePointAdminUrl points to the tenant's SharePoint ADMIN CENTER (e.g. https://<tenant>-admin.sharepoint.com), not a regular site, and that the 'PnP.PowerShell' module is imported into the Automation Account. Error: $errorMessage" -ErrorAction Continue
        throw "Could not establish SharePoint Online connection"
    }
}
#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################
Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"
Write-Output "User: $UserPrincipalName"

$upnKey = $UserPrincipalName.ToLower()

# The OneDrive URL is resolved from the user profile. This only works while the user account (and
# therefore the profile) still exists - for a deleted user this stays empty, which is expected and
# is why the recycle bin lookup in the Main Part does not depend on it.
$personalUrl = $null
try {
    $userProfile = Get-PnPUserProfileProperty -Account $UserPrincipalName -ErrorAction Stop
    if ($userProfile) {
        $personalUrl = $userProfile.PersonalUrl
    }
}
catch {
    $profileErrorMessage = $_.Exception.Message
    if ($profileErrorMessage -match "401|403|Access denied|Unauthorized") {
        # A permission denial here looks identical to "the account no longer exists" unless it is
        # called out. Surface it so the operator can tell a missing grant from a deleted user, but
        # do not throw: the recycle bin lookup in the Main Part can still produce a useful answer.
        Write-Error "Access denied while reading the user profile for '$UserPrincipalName'. The OneDrive URL could not be resolved because of insufficient permission, not because the account is missing - the reported status may be incomplete. Error: $profileErrorMessage" -ErrorAction Continue
    }
    else {
        # Expected and benign: once a user account is deleted, its profile (and PersonalUrl) is gone
        # with it. This is a normal path for this read-only check, not a failure - the recycle bin
        # lookup in the Main Part does not depend on this succeeding.
        Write-RjRbLog -Message "No user profile could be read for '$UserPrincipalName' - this is expected if the account no longer exists. Details: $($profileErrorMessage)" -Verbose
    }
}

if ([string]::IsNullOrWhiteSpace($personalUrl)) {
    Write-Output "Current OneDrive URL: not resolvable (the account may no longer exist)"
    $personalUrl = $null
}
elseif ($personalUrl -notlike "*/personal/*") {
    # A profile can carry a PersonalUrl that does not point at a provisioned personal site.
    Write-RjRbLog -Message "Resolved PersonalUrl '$personalUrl' is not a personal site URL - ignoring it." -Verbose
    Write-Output "Current OneDrive URL: not a personal site URL - ignoring it"
    $personalUrl = $null
}
else {
    $personalUrl = $personalUrl.TrimEnd('/')
    Write-Output "Current OneDrive URL: $personalUrl"
}
#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################
Write-Output ""
Write-Output "Check OneDrive Status"
Write-Output "---------------------"

#region Check for an active OneDrive site collection
$site = $null
if ($personalUrl) {
    try {
        $site = Get-PnPTenantSite -Identity $personalUrl -Detailed -ErrorAction Stop
    }
    catch {
        # Not an error condition: a deleted or never-provisioned OneDrive simply is not an active
        # site collection, and the recycle bin check below tells the two cases apart. If the
        # managed identity lacks SharePoint permissions this call also fails with 403/Access
        # denied - that is surfaced instead by the recycle bin lookup below, which needs the same
        # tenant-admin permission and runs unconditionally when no active site is found.
        Write-RjRbLog -Message "No active site collection found at '$personalUrl' - this is expected if the OneDrive was deleted or never provisioned. Details: $($_.Exception.Message)" -Verbose
    }
}
#endregion Check for an active OneDrive site collection

#region Check the tenant recycle bin
# Runs INDEPENDENTLY of the profile lookup: a deleted user has no profile, so the deleted personal
# site is matched by its SiteOwnerEmail, with the resolved URL as a fallback key. Only queried when
# there is no active site - if the OneDrive is active there is nothing to look for.
$deletedSite = $null
if (-not $site) {
    try {
        # -IncludeOnlyPersonalSite restricts the result to OneDrive sites. -Limit lifts the default
        # page size of 200; ALL is not yet supported by PnP, so a high explicit limit is used.
        $deletedSites = Get-PnPTenantDeletedSite -IncludeOnlyPersonalSite -Limit 1000 -Detailed -ErrorAction Stop

        foreach ($candidate in $deletedSites) {
            $ownerMatch = (-not [string]::IsNullOrWhiteSpace($candidate.SiteOwnerEmail)) -and ($candidate.SiteOwnerEmail.Trim().ToLower() -eq $upnKey)
            $urlMatch = $personalUrl -and (-not [string]::IsNullOrWhiteSpace($candidate.Url)) -and ($candidate.Url.Trim().TrimEnd('/').ToLower() -eq $personalUrl.ToLower())

            if ($ownerMatch -or $urlMatch) {
                $deletedSite = $candidate
                break
            }
        }
    }
    catch {
        $recycleBinErrorMessage = $_.Exception.Message
        if ($recycleBinErrorMessage -match "401|403|Access denied|Unauthorized") {
            # The connection itself succeeded (region:Connect), but the managed identity does not
            # have permission to call this tenant-admin cmdlet. This is a distinct, actionable
            # cause from "nothing found" and is worth calling out by name rather than folding it
            # into the generic enumeration-failure message below.
            Write-Error "Access denied while querying the SharePoint tenant recycle bin. The connection succeeded, but the Automation account's managed identity does not have sufficient SharePoint Online permission to enumerate deleted sites (requires 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API, AppId 00000003-0000-0ff1-ce00-000000000000, with admin consent). The OneDrive could not be confirmed as deleted or permanently removed - the reported status may be incomplete. Error: $recycleBinErrorMessage" -ErrorAction Continue
        }
        else {
            # This is a read-only check: a failed lookup here does not mean anything was changed
            # or left in an inconsistent state, only that this one status source is missing.
            Write-Error "Could not enumerate the SharePoint tenant recycle bin: $recycleBinErrorMessage. The OneDrive could not be confirmed as deleted or permanently removed - the reported status may be incomplete." -ErrorAction Continue
        }
        # Deliberately not re-thrown: a partial answer (active-site check already completed) is
        # still useful to the operator, and this runbook makes no changes that would need undoing.
    }
}
#endregion Check the tenant recycle bin

#region Build and report the status
if ($site) {
    # Archive state is evaluated BEFORE lock state, and both are combined: archiving a site
    # typically also sets it ReadOnly, so checking the lock state first would report an archived
    # OneDrive as merely "Active (read-only)" and silently lose the archived signal.
    #
    # ArchiveStatus is an enum with a documented value set - NotArchived, FullyArchived,
    # RecentlyArchived, Reactivating, Archived. Match those values explicitly instead of treating
    # "anything unexpected" as archived: a deny-list reports a perfectly healthy NotArchived site
    # as archived, which is the opposite of the truth. An unrecognised value (a new enum member
    # added by Microsoft) is reported verbatim rather than being silently forced into either bucket.
    $archiveStatusValue = if ($site.ArchiveStatus) { [string]$site.ArchiveStatus } else { "" }
    $lockSuffix = switch ($site.LockState) {
        "ReadOnly" { " (read-only)" }
        "NoAccess" { " (no access)" }
        default { "" }
    }
    $siteStatus = switch ($archiveStatusValue) {
        # Not archived at all - the normal state of a live OneDrive.
        "NotArchived" { "Active$lockSuffix" }
        # Fully moved to archive storage; content is not accessible until reactivated.
        "FullyArchived" { "Archived$lockSuffix" }
        # Archived within the last 7 days - still cheap/fast to reactivate.
        "RecentlyArchived" { "Archived (recently archived)$lockSuffix" }
        # Currently being brought back out of the archive; transitional, not a steady state.
        "Reactivating" { "Reactivating from archive$lockSuffix" }
        # Generic archived value.
        "Archived" { "Archived$lockSuffix" }
        # No value reported at all (older tenants / site types that do not surface the property).
        "" { "Active$lockSuffix" }
        default { "Active (unknown archive status '$archiveStatusValue')$lockSuffix" }
    }
    $isArchived = $archiveStatusValue -in @("FullyArchived", "RecentlyArchived", "Archived")

    $oneDriveStatus = [PSCustomObject]@{
        UserPrincipalName = $UserPrincipalName
        OneDriveUrl       = $site.Url
        Status            = $siteStatus
        Exists            = $true
        ArchiveStatus     = $(if ($archiveStatusValue) { $archiveStatusValue } else { "NotArchived" })
        IsArchived        = $isArchived
        LockState         = $site.LockState
        IsReadOnly        = ($site.LockState -eq "ReadOnly")
        InRecycleBin      = $false
        DeletionTime      = $null
    }
}
elseif ($deletedSite) {
    $oneDriveStatus = [PSCustomObject]@{
        UserPrincipalName = $UserPrincipalName
        OneDriveUrl       = $deletedSite.Url
        Status            = "Deleted (in recycle bin)"
        Exists            = $false
        ArchiveStatus     = "n/a"
        IsArchived        = $false
        LockState         = "n/a"
        IsReadOnly        = "n/a"
        InRecycleBin      = $true
        DeletionTime      = $deletedSite.DeletionTime
    }
}
else {
    # Neither active nor in the recycle bin: never provisioned, or already purged after the
    # retention period (93 days by default).
    $oneDriveStatus = [PSCustomObject]@{
        UserPrincipalName = $UserPrincipalName
        OneDriveUrl       = $personalUrl
        Status            = "Not found (never provisioned or permanently deleted)"
        Exists            = $false
        ArchiveStatus     = "n/a"
        IsArchived        = $false
        LockState         = "n/a"
        IsReadOnly        = "n/a"
        InRecycleBin      = $false
        DeletionTime      = $null
    }
}

Write-Output ""
Write-Output "Result"
Write-Output "---------------------"
Write-Output "Status:            $($oneDriveStatus.Status)"
Write-Output "OneDrive URL:      $(if ($oneDriveStatus.OneDriveUrl) { $oneDriveStatus.OneDriveUrl } else { 'n/a' })"
Write-Output "Site exists:       $($oneDriveStatus.Exists)"
Write-Output "Archive status:    $($oneDriveStatus.ArchiveStatus)"
Write-Output "Archived:          $($oneDriveStatus.IsArchived)"
Write-Output "Lock state:        $($oneDriveStatus.LockState)"
Write-Output "Read-only:         $($oneDriveStatus.IsReadOnly)"
Write-Output "In recycle bin:    $($oneDriveStatus.InRecycleBin)"

if ($oneDriveStatus.DeletionTime) {
    Write-Output "Deletion time:     $(Get-Date $oneDriveStatus.DeletionTime -Format 'yyyy-MM-dd HH:mm:ss')"
}
#endregion Build and report the status

# Emit the status object so the result is available as structured runbook output in addition to the
# formatted text above.
$oneDriveStatus
#endregion Main Part

########################################################
#region     Cleanup
########################################################
if ($pnpConnected) {
    try {
        Disconnect-PnPOnline -ErrorAction Stop
    }
    catch {
        Write-RjRbLog -Message "Failed to disconnect from SharePoint Online: $($_.Exception.Message)" -Verbose
    }
}

Write-Output ""
Write-Output "Done!"
#endregion Cleanup

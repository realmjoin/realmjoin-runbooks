<#
	.SYNOPSIS
	Check whether a user's OneDrive is active, locked or deleted

	.DESCRIPTION
	Looks up the personal OneDrive site of a user and reports whether it is active or archived, whether it is locked, and whether it sits in the tenant recycle bin. Works for users whose account has already been deleted, as their OneDrive may still be in the recycle bin. Nothing is changed.

	.PARAMETER UserPrincipalName
	User principal name of the user whose OneDrive is checked. Deleted users are accepted.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {

			"UserPrincipalName": {
				"DisplayName": "User principal name"
			},
			"CallerName": {
				"Hide": true
			}
		}
	}

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
$Version = "1.5.0"
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
#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################
Write-Output ""
Write-Output "Check OneDrive Status"
Write-Output "---------------------"

#region Check for an active OneDrive site collection
$site = $null
try {
    # -eq is case-insensitive in PowerShell, so no normalization of the owner is needed.
    $site = Get-PnPTenantSite -IncludeOneDriveSites -Filter "Url -like '-my.sharepoint.com/personal/'" -ErrorAction Stop |
        Where-Object { $_.Owner -eq $UserPrincipalName } |
        Select-Object -First 1

    if ($site) {
        # The filtered listing omits properties such as ArchiveStatus; -Detailed returns the full set.
        $site = Get-PnPTenantSite -Identity $site.Url -Detailed -ErrorAction Stop
    }
}
catch {
    $siteErrorMessage = $_.Exception.Message
    if ($siteErrorMessage -match "401|403|Access denied|Unauthorized") {
        Write-Error "Access denied while enumerating OneDrive sites. The managed identity needs 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API (AppId 00000003-0000-0ff1-ce00-000000000000), with admin consent. The reported status may be incomplete. Error: $siteErrorMessage" -ErrorAction Continue
    }
    else {
        Write-Error "Could not enumerate OneDrive sites: $siteErrorMessage. The reported status may be incomplete." -ErrorAction Continue
    }
}

if ($site) {
    Write-Output "Active OneDrive found: $($site.Url)"
}
else {
    Write-Output "No active OneDrive found for '$UserPrincipalName'"
}
#endregion Check for an active OneDrive site collection

#region Check the tenant recycle bin
$deletedSite = $null
if (-not $site) {
    try {
        # -Limit lifts the default page size of 200.
        $deletedSite = Get-PnPTenantDeletedSite -IncludeOnlyPersonalSite -Limit 100000 -Detailed -ErrorAction Stop |
            Where-Object { $_.SiteOwnerEmail -eq $UserPrincipalName } |
            Select-Object -First 1
    }
    catch {
        $recycleBinErrorMessage = $_.Exception.Message
        if ($recycleBinErrorMessage -match "401|403|Access denied|Unauthorized") {
            Write-Error "Access denied while querying the SharePoint tenant recycle bin. The managed identity needs 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API (AppId 00000003-0000-0ff1-ce00-000000000000), with admin consent. The reported status may be incomplete. Error: $recycleBinErrorMessage" -ErrorAction Continue
        }
        else {
            Write-Error "Could not enumerate the SharePoint tenant recycle bin: $recycleBinErrorMessage. The reported status may be incomplete." -ErrorAction Continue
        }
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
        # StorageUsageCurrent is reported in MB.
        StorageUsedGB     = [math]::Round($site.StorageUsageCurrent / 1024, 2)
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
        # StorageUsed (from -Detailed) is reported in bytes.
        StorageUsedGB     = $(if ($null -ne $deletedSite.StorageUsed) { [math]::Round($deletedSite.StorageUsed / 1GB, 2) } else { $null })
    }
}
else {
    # Neither active nor in the recycle bin: never provisioned, or already purged after the
    # retention period (93 days by default).
    $oneDriveStatus = [PSCustomObject]@{
        UserPrincipalName = $UserPrincipalName
        OneDriveUrl       = $null
        Status            = "Not found (never provisioned or permanently deleted)"
        Exists            = $false
        ArchiveStatus     = "n/a"
        IsArchived        = $false
        LockState         = "n/a"
        IsReadOnly        = "n/a"
        InRecycleBin      = $false
        DeletionTime      = $null
        StorageUsedGB     = $null
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
Write-Output "Storage used:      $(if ($null -ne $oneDriveStatus.StorageUsedGB) { "$($oneDriveStatus.StorageUsedGB) GB" } else { 'n/a' })"

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

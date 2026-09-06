<#
	.SYNOPSIS
	List all members and administrators of a SharePoint Online site collection

	.DESCRIPTION
	Connects to a SharePoint Online site collection using PnP.PowerShell with the system-assigned managed identity and retrieves the members of the site collection administrators, Owners group, Members group, and Visitors group. Each group's members are listed with their type, such as user, security group, or Entra ID group.

	.PARAMETER SiteUrl
	Full URL of the SharePoint Online site collection, for example https://contoso.sharepoint.com/sites/marketing

	.PARAMETER CallerName
	Name of the user or system that started the runbook. Tracked for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"SiteUrl": {
				"DisplayName": "Site collection URL"
			},
			"CallerName": {
				"Hide": true
			}
		}
	}

	.NOTES
	Parameter Interactions:
	- SiteUrl must point at a site collection root (e.g. https://contoso.sharepoint.com/sites/marketing),
	  not a sub-site. A sub-site URL still returns results, but they describe the parent site
	  collection - the runbook logs a warning when this happens.
	- The Owners, Members, and Visitors groups are resolved via the site's associated-group properties,
	  not by matching localized group names, so the report is accurate regardless of tenant language.
	  Any of the three may be absent (common on Teams-connected sites) and is reported as "not configured"
	  rather than causing a failure.
#>
#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "PnP.PowerShell"; ModuleVersion = "3.4.1" }

param(
    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.2.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "SiteUrl: $SiteUrl" -Verbose
#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################
if ([string]::IsNullOrWhiteSpace($SiteUrl)) {
    Write-Error "No site collection URL was supplied. Provide the full URL of the site collection, for example 'https://contoso.sharepoint.com/sites/marketing'." -ErrorAction Continue
    throw "SiteUrl is required"
}

# Normalize: users frequently paste a URL with a trailing slash or a page path from the browser address bar
$SiteUrl = $SiteUrl.Trim().TrimEnd('/')

$parsedSiteUri = $null
if (-not [System.Uri]::TryCreate($SiteUrl, [System.UriKind]::Absolute, [ref]$parsedSiteUri)) {
    Write-Error "The site collection URL '$SiteUrl' is not a valid absolute URL. Expected format: 'https://contoso.sharepoint.com/sites/marketing'." -ErrorAction Continue
    throw "Invalid SiteUrl format"
}

if ($parsedSiteUri.Scheme -ne 'https') {
    Write-Error "The site collection URL must use HTTPS. Received scheme '$($parsedSiteUri.Scheme)' in '$SiteUrl'." -ErrorAction Continue
    throw "SiteUrl must use HTTPS"
}

Write-RjRbLog -Message "Validated site collection URL: $SiteUrl" -Verbose
#endregion Parameter Validation

########################################################
#region     Connect Part
########################################################
Write-Output ""
Write-Output "Connect to SharePoint Online"
Write-Output "---------------------"

$pnpConnected = $false
try {
    $VerbosePreference = "SilentlyContinue"
    Connect-PnPOnline -Url $SiteUrl -ManagedIdentity -ErrorAction Stop
    $VerbosePreference = "Continue"
    $pnpConnectedWeb = Get-PnPWeb -ErrorAction Stop
    $pnpConnected = $true
    Write-Output "Connected to '$($pnpConnectedWeb.Title)' ($($pnpConnectedWeb.Url))"
}
catch {
    $connectErrorMessage = "$_"
    if ($connectErrorMessage -like "*401*" -or $connectErrorMessage -like "*403*" -or $connectErrorMessage -like "*Access denied*" -or $connectErrorMessage -like "*Unauthorized*" -or $connectErrorMessage -like "*Forbidden*") {
        Write-Error "Access denied while connecting to SharePoint site '$SiteUrl'. The Automation account's managed identity needs SharePoint application permissions (e.g. 'Sites.Read.All' or 'Sites.FullControl.All') granted with admin consent on the SharePoint API specifically - Microsoft Graph permissions alone are not sufficient here. Ask your tenant administrator to grant these under Entra ID > Enterprise Applications for this Automation account's identity. Error: $connectErrorMessage" -ErrorAction Continue
        throw "Managed identity lacks SharePoint application permissions for '$SiteUrl'"
    }
    elseif ($connectErrorMessage -like "*404*" -or $connectErrorMessage -like "*File Not Found*" -or $connectErrorMessage -like "*Cannot get site*" -or $connectErrorMessage -like "*could not be found*") {
        Write-Error "The site collection '$SiteUrl' could not be found. Verify the URL is correct, that the site still exists (it may have been deleted), and that it points at a site collection root (e.g. '/sites/...' or '/teams/...') rather than a sub-site, document, or a OneDrive/personal ('/personal/...') URL, which behaves differently. Error: $connectErrorMessage" -ErrorAction Continue
        throw "Site collection '$SiteUrl' not found"
    }
    elseif ($connectErrorMessage -like "*managed identity*" -or $connectErrorMessage -like "*no token*" -or $connectErrorMessage -like "*token*acquire*" -or $connectErrorMessage -like "*Identity not found*") {
        Write-Error "Could not acquire a token via the system-assigned managed identity. Verify that a system-assigned managed identity is enabled on this Azure Automation account and that it has not been disabled or removed. Error: $connectErrorMessage" -ErrorAction Continue
        throw "Managed identity token acquisition failed"
    }
    else {
        Write-Error "Could not connect to SharePoint Online site '$SiteUrl'. Error: $connectErrorMessage" -ErrorAction Continue
        throw
    }
}
#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################
Write-Output ""
Write-Output "Preflight-Check"
Write-Output "---------------------"

# Re-load the connected web with the associated-group properties. Get-PnPWeb in the Connect
# region does not eager-load these navigation properties, so they must be requested explicitly
# here before Main can read them.
try {
    $pnpPreflightWeb = Get-PnPWeb -Includes Title, Url, AssociatedOwnerGroup, AssociatedMemberGroup, AssociatedVisitorGroup -ErrorAction Stop
}
catch {
    # Hard failure: if the web itself cannot be read at all, there is nothing for Main to work with.
    $preflightWebErrorMessage = "$_"
    if ($preflightWebErrorMessage -like "*401*" -or $preflightWebErrorMessage -like "*403*" -or $preflightWebErrorMessage -like "*Access denied*" -or $preflightWebErrorMessage -like "*Unauthorized*" -or $preflightWebErrorMessage -like "*Forbidden*") {
        Write-Error "Access denied while reading properties of '$($pnpConnectedWeb.Url)'. Connecting to the site succeeded, but reading its properties needs SharePoint application permissions (e.g. 'Sites.Read.All') granted with admin consent on the SharePoint API - being able to connect does not imply being able to read site data. Error: $preflightWebErrorMessage" -ErrorAction Continue
        throw "Managed identity lacks read access to web properties for '$($pnpConnectedWeb.Url)'"
    }
    elseif ($preflightWebErrorMessage -like "*404*" -or $preflightWebErrorMessage -like "*File Not Found*" -or $preflightWebErrorMessage -like "*could not be found*") {
        Write-Error "The site '$($pnpConnectedWeb.Url)' could not be read - it may have been deleted after the connection was established. Re-run the runbook against a current site collection URL. Error: $preflightWebErrorMessage" -ErrorAction Continue
        throw "Site '$($pnpConnectedWeb.Url)' no longer available"
    }
    else {
        Write-Error "Could not read properties of the connected SharePoint web '$($pnpConnectedWeb.Url)'. Error: $preflightWebErrorMessage" -ErrorAction Continue
        throw "Failed to load web properties for '$($pnpConnectedWeb.Url)'"
    }
}

# Site-collection-scope check: the user is asked for a "Site Collection URL", and associated
# groups / site collection admins are site-collection-scoped concepts. If the connected web's
# URL is not the site collection root, associated groups still resolve (they are inherited from
# the root web) but the result may be surprising to a caller who pointed this at a sub-site.
# This is a soft warning, not a hard failure, because PnP can still successfully resolve the
# associated groups either way.
try {
    $pnpSite = Get-PnPSite -Includes Url -ErrorAction Stop
    $siteCollectionRootUrl = $pnpSite.Url.TrimEnd('/')
    $connectedWebUrl = $pnpPreflightWeb.Url.TrimEnd('/')
    if ($connectedWebUrl -ne $siteCollectionRootUrl) {
        Write-RjRbLog -Message "WARNING: The connected URL '$connectedWebUrl' is a sub-site, not the site collection root ('$siteCollectionRootUrl'). Associated owner/member/visitor groups and site collection admins are scoped to the parent site collection, not this sub-site - the groups reported below belong to '$siteCollectionRootUrl'." -Verbose
    }
}
catch {
    # Non-fatal: the root-vs-subsite comparison is a convenience warning only. If Get-PnPSite
    # itself fails (e.g. reduced permissions), skip the comparison rather than failing preflight.
    Write-RjRbDebug -Message "Could not determine site collection root URL for comparison: $_"
}

# Resolve the three associated groups language-agnostically via the web's navigation properties -
# never by matching group display names (e.g. "Owners"/"Besitzer"), which vary by tenant language.
# Any of the three may legitimately be absent (no visitor group configured, Teams-connected sites
# often diverge from the classic Owners/Members/Visitors model) - keep the bucket in the list with
# a null Group rather than throwing, so Main can report "not configured" per bucket.
$associatedGroups = @(
    [PSCustomObject]@{ Bucket = 'Owners'; Group = $pnpPreflightWeb.AssociatedOwnerGroup }
    [PSCustomObject]@{ Bucket = 'Members'; Group = $pnpPreflightWeb.AssociatedMemberGroup }
    [PSCustomObject]@{ Bucket = 'Visitors'; Group = $pnpPreflightWeb.AssociatedVisitorGroup }
)

$resolvedGroupCount = ($associatedGroups | Where-Object { $null -ne $_.Group }).Count
Write-Output "Preflight complete for '$($pnpPreflightWeb.Title)' ($($pnpPreflightWeb.Url)) - $resolvedGroupCount of 3 associated groups resolved."
#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################
# Translates a SharePoint principal into a human-readable member type. PrincipalType is declared as a
# flags enum on Microsoft.SharePoint.Client.User, but CSOM populates it with a single value in practice,
# so matching it as a string is safe (and every arm returns, so fallthrough never applies). The LoginName
# claim is what distinguishes an Entra group from a SharePoint group - PrincipalType reports both as a group.
function Get-SPPrincipalTypeLabel {
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Principal
    )

    if ($null -eq $Principal) { return "Unknown" }

    $principalType = "$($Principal.PrincipalType)"
    $loginName = "$($Principal.LoginName)"

    switch -Regex ($principalType) {
        'SharePointGroup' { return "SharePoint group" }
        'SecurityGroup' {
            # Entra ID (Azure AD) principals arrive as federated claims; everything else is a classic
            # SharePoint/Windows security group.
            if ($loginName -match 'federateddirectoryclaimprovider') { return "Entra ID group" }
            if ($loginName -match 'tenant\|') { return "Entra ID group" }
            if ($loginName -match 'c:0\(\.s\|true') { return "Everyone" }
            if ($loginName -match 'spo-grid-all-users') { return "All tenant users" }
            return "Security group"
        }
        'User' { return "User" }
        'DistributionList' { return "Distribution list" }
        default {
            if ([string]::IsNullOrWhiteSpace($principalType)) { return "Unknown" }
            return $principalType
        }
    }
}

# Projects a SharePoint principal into the flat shape used for every output bucket.
function ConvertTo-SPMemberRecord {
    param (
        [Parameter(Mandatory = $true)]
        $Principal,

        [Parameter(Mandatory = $true)]
        [string]$Bucket,

        [Parameter(Mandatory = $false)]
        [string]$GroupName = ""
    )

    $displayName = if ([string]::IsNullOrWhiteSpace($Principal.Title)) { "(no display name)" } else { $Principal.Title }
    $email = if ([string]::IsNullOrWhiteSpace($Principal.Email)) { "" } else { $Principal.Email }

    $memberType = Get-SPPrincipalTypeLabel -Principal $Principal

    # LoginName carries the claim string; for an Entra user the UPN is the part after the last pipe.
    # Only users get a UserName: for groups and special principals ("Everyone", "All tenant users")
    # the trailing claim segment is a GUID or a literal like "true", never something worth printing.
    $loginName = "$($Principal.LoginName)"
    $upn = ""
    if ($memberType -eq 'User' -and $loginName -match '\|([^|]+)$') {
        $upn = $Matches[1]
    }

    [PSCustomObject]@{
        Bucket      = $Bucket
        GroupName   = $GroupName
        DisplayName = $displayName
        MemberType  = $memberType
        UserName    = $upn
        Email       = $email
        LoginName   = $loginName
    }
}

Write-Output ""
Write-Output "Site Collection Administrators"
Write-Output "---------------------"

$siteCollectionAdmins = @()
try {
    $rawSiteAdmins = Get-PnPSiteCollectionAdmin -ErrorAction Stop
    foreach ($admin in $rawSiteAdmins) {
        $siteCollectionAdmins += ConvertTo-SPMemberRecord -Principal $admin -Bucket 'Site Collection Administrators'
    }
}
catch {
    $siteAdminErrorMessage = $_.Exception.Message
    if ($siteAdminErrorMessage -like "*401*" -or $siteAdminErrorMessage -like "*403*" -or $siteAdminErrorMessage -like "*Access denied*" -or $siteAdminErrorMessage -like "*Unauthorized*" -or $siteAdminErrorMessage -like "*Forbidden*") {
        Write-Error "Access denied while retrieving the site collection administrators for '$SiteUrl'. Reading site collection administrators requires a higher privilege level than reading the site itself - the managed identity may be able to connect and read the web, yet still lack the rights to list admins. Verify the SharePoint application permission granted is 'Sites.FullControl.All' (not just 'Sites.Read.All') with admin consent on the SharePoint API. Error: $siteAdminErrorMessage" -ErrorAction Continue
        throw "Managed identity lacks permission to list site collection administrators for '$SiteUrl'"
    }
    else {
        Write-Error "Failed to retrieve the site collection administrators for '$SiteUrl': $siteAdminErrorMessage" -ErrorAction Continue
        throw "Could not read site collection administrators"
    }
}

if ($siteCollectionAdmins.Count -eq 0) {
    Write-Output "No site collection administrators were returned."
}
else {
    Write-RjRbLog -Message "Site collection administrators found: $($siteCollectionAdmins.Count)" -Verbose
    $siteCollectionAdmins | Sort-Object DisplayName | ForEach-Object {
        Write-Output "- $($_.DisplayName) [$($_.MemberType)]$(if ($_.UserName) { " - $($_.UserName)" })"
    }
}

# The three default groups are resolved from the web's associated-group properties in the preflight
# region, so this reports the correct groups regardless of the site's display language.
$groupMembershipResults = @()

foreach ($bucketEntry in $associatedGroups) {
    $bucketLabel = $bucketEntry.Bucket
    $group = $bucketEntry.Group

    Write-Output ""
    Write-Output "Associated $bucketLabel Group"
    Write-Output "---------------------"

    if ($null -eq $group) {
        Write-Output "No associated $($bucketLabel.ToLower()) group is configured for this site collection."
        Write-RjRbLog -Message "Associated $bucketLabel group: not configured" -Verbose
        continue
    }

    $groupTitle = "$($group.Title)"
    Write-Output "Group: $groupTitle"

    $groupMembers = @()
    try {
        $rawGroupMembers = Get-PnPGroupMember -Identity $group -ErrorAction Stop
        foreach ($member in $rawGroupMembers) {
            $groupMembers += ConvertTo-SPMemberRecord -Principal $member -Bucket "$bucketLabel Group" -GroupName $groupTitle
        }
    }
    catch {
        # One unreadable group must not cost the report its other three buckets.
        Write-RjRbLog -Message "WARNING: Could not read the members of the associated $bucketLabel group '$groupTitle': $($_.Exception.Message)" -Verbose
        Write-Output "Members could not be retrieved for this group."
        continue
    }

    if ($groupMembers.Count -eq 0) {
        Write-Output "This group has no members."
    }
    else {
        $groupMembers | Sort-Object DisplayName | ForEach-Object {
            Write-Output "- $($_.DisplayName) [$($_.MemberType)]$(if ($_.UserName) { " - $($_.UserName)" })"
        }
    }

    Write-RjRbLog -Message "Associated $bucketLabel group '$groupTitle' members: $($groupMembers.Count)" -Verbose
    $groupMembershipResults += $groupMembers
}

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Site collection: $SiteUrl"
Write-Output "Site collection administrators: $($siteCollectionAdmins.Count)"
foreach ($bucketEntry in $associatedGroups) {
    $bucketLabel = $bucketEntry.Bucket
    if ($null -eq $bucketEntry.Group) {
        Write-Output "Associated $bucketLabel group: not configured"
    }
    else {
        $bucketCount = @($groupMembershipResults | Where-Object { $_.Bucket -eq "$bucketLabel Group" }).Count
        Write-Output "Associated $bucketLabel group '$($bucketEntry.Group.Title)': $bucketCount member(s)"
    }
}
#endregion Main Part

########################################################
#region     Cleanup
########################################################
if ($pnpConnected) {
    try {
        Disconnect-PnPOnline -ErrorAction Stop
    }
    catch {
        Write-RjRbLog -Message "Failed to disconnect from SharePoint Online cleanly: $($_.Exception.Message)" -Verbose
    }
}

Write-Output ""
Write-Output "Done!"
#endregion Cleanup

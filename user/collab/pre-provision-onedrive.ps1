<#
	.SYNOPSIS
	Request the OneDrive of this user before the first sign-in

	.DESCRIPTION
	Requests the OneDrive of this user in SharePoint Online so it is available before the first sign-in. The account must be enabled and, when the license check is on, have a SharePoint service plan assigned. Nothing is requested if the OneDrive already exists. SharePoint creates the OneDrive in the background, usually within minutes and sometimes only after 24 hours, and the run does not wait for it.

	.PARAMETER UserName
	User principal name of the user the runbook acts on. Set by the portal from the selected user.

	.PARAMETER CheckSharePointLicense
	When enabled, the runbook stops if this user has no enabled SharePoint service plan from any license, assigned directly or by group. When disabled, the request is sent anyway, but SharePoint creates the OneDrive only once a license is assigned.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"UserName": {
				"Hide": true
			},
			"CheckSharePointLicense": {
				"DisplayName": "Check the SharePoint license first?"
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
    [string]$UserName,

    [bool]$CheckSharePointLicense = $true,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "CheckSharePointLicense: $CheckSharePointLicense" -Verbose
#endregion RJ Log Part

########################################################
#region     Connect Part
########################################################
Write-Output ""
Write-Output "Connect to Microsoft Graph and SharePoint Online"
Write-Output "---------------------"

Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop

$mgSPOrootSiteResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/sites/root" -ErrorAction Stop
$SharePointAdminUrl = $mgSPOrootSiteResponse["webUrl"]
if ([string]::IsNullOrWhiteSpace($SharePointAdminUrl)) {
    Write-Error "The SharePoint admin center URL could not be discovered from the tenant root site (Microsoft Graph /sites/root)." -ErrorAction Continue
    throw "SharePointAdminUrl is not discovered"
}
$SharePointAdminUrl = $SharePointAdminUrl.Replace(".sharepoint.com", "-admin.sharepoint.com")
Write-RjRbLog -Message "SharePointAdminUrl: $SharePointAdminUrl" -Verbose

$pnpConnected = $false
try {
    $VerbosePreference = "SilentlyContinue"
    Connect-PnPOnline -Url $SharePointAdminUrl -ManagedIdentity -ErrorAction Stop
    $VerbosePreference = "Continue"
    Get-PnPWeb -ErrorAction Stop | Out-Null
    $pnpConnected = $true
    Write-Output "Connected to SharePoint Online: $SharePointAdminUrl"
}
catch {
    $VerbosePreference = "Continue"
    $errorMessage = $_.Exception.Message
    if ($errorMessage -match "401|403|Access denied|Unauthorized") {
        Write-Error "Access denied while connecting to SharePoint Online ($SharePointAdminUrl). The Automation account's managed identity needs the 'Sites.FullControl.All' APPLICATION permission granted on the Office 365 SharePoint Online API (AppId 00000003-0000-0ff1-ce00-000000000000), with admin consent. Microsoft Graph permissions alone are NOT sufficient. Error: $errorMessage" -ErrorAction Continue
        throw "Access denied connecting to SharePoint Online"
    }
    elseif ($errorMessage -match "managed identity|ManagedIdentity|identity endpoint|token") {
        Write-Error "Failed to acquire a token via the system-assigned managed identity. Ensure a system-assigned managed identity is enabled on the Automation account and that it has been granted 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API (AppId 00000003-0000-0ff1-ce00-000000000000). Error: $errorMessage" -ErrorAction Continue
        throw "Managed identity authentication failed"
    }
    else {
        Write-Error "Failed to connect to SharePoint Online ($SharePointAdminUrl). Verify that the 'PnP.PowerShell' module is imported into the Automation Account. Error: $errorMessage" -ErrorAction Continue
        throw "Could not establish SharePoint Online connection"
    }
}
#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################
Write-Output ""
Write-Output "Preflight Check"
Write-Output "---------------------"

#region Verify the user account via Microsoft Graph
$targetUser = $null
try {
    $encodedUserName = [uri]::EscapeDataString($UserName)
    $targetUser = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$encodedUserName`?`$select=id,displayName,userPrincipalName,accountEnabled,assignedPlans" -ErrorAction Stop
}
catch {
    $userErrorMessage = $_.Exception.Message
    if ($userErrorMessage -match "404|NotFound|Request_ResourceNotFound") {
        Write-Error "User '$UserName' was not found in Microsoft Entra ID." -ErrorAction Continue
        throw "User '$UserName' not found"
    }
    Write-Error "Failed to read user '$UserName' from Microsoft Graph. The managed identity needs the 'User.Read.All' application permission. Error: $userErrorMessage" -ErrorAction Continue
    throw "Could not read user '$UserName'"
}

$upn = $targetUser["userPrincipalName"]
Write-Output "User:              $($targetUser["displayName"]) ($upn)"

if ($targetUser["accountEnabled"] -ne $true) {
    Write-Error "The account of '$upn' is disabled. SharePoint only provisions a OneDrive for users who are allowed to sign in. Enable the account first and run this runbook again." -ErrorAction Continue
    throw "User '$upn' is disabled"
}
Write-Output "Account enabled:   True"

if ($CheckSharePointLicense) {
    # assignedPlans covers direct and group-based licenses; OneDrive plans also report service 'SharePoint'.
    $sharePointPlans = @($targetUser["assignedPlans"] | Where-Object { $_["service"] -eq "SharePoint" -and $_["capabilityStatus"] -eq "Enabled" })
    if ($sharePointPlans.Count -eq 0) {
        Write-Error "User '$upn' has no enabled SharePoint service plan assigned. Assign a license that includes SharePoint Online (e.g. Microsoft 365 E3/E5, F3 or SharePoint Online Plan 1/2), wait for the assignment to take effect and run this runbook again." -ErrorAction Continue
        throw "User '$upn' has no SharePoint license"
    }
    Write-Output "SharePoint plan:   Enabled ($($sharePointPlans.Count) plan(s) assigned)"
}
else {
    Write-Output "SharePoint plan:   Not verified (check disabled)"
    Write-RjRbLog -Message "SharePoint license check skipped. Without a SharePoint license the OneDrive will not be created." -Verbose
}
#endregion Verify the user account via Microsoft Graph

#region Check for an existing OneDrive
$personalUrl = $null
try {
    $userProfile = Get-PnPUserProfileProperty -Account $upn -ErrorAction Stop
    if ($userProfile -and $userProfile.PersonalUrl -like "*/personal/*") {
        $personalUrl = $userProfile.PersonalUrl.TrimEnd('/')
    }
}
catch {
    # Expected for new users whose SharePoint user profile has not been created yet.
    Write-RjRbLog -Message "No user profile could be read for '$upn'. Details: $($_.Exception.Message)" -Verbose
}

$existingSite = $null
if ($personalUrl) {
    try {
        $existingSite = Get-PnPTenantSite -Identity $personalUrl -ErrorAction Stop
    }
    catch {
        Write-RjRbLog -Message "No active site collection found at '$personalUrl'. Details: $($_.Exception.Message)" -Verbose
    }
}

if (-not $existingSite) {
    try {
        $deletedSites = Get-PnPTenantDeletedSite -IncludeOnlyPersonalSite -Limit 1000 -Detailed -ErrorAction Stop
        $deletedSite = $deletedSites | Where-Object {
            (-not [string]::IsNullOrWhiteSpace($_.SiteOwnerEmail)) -and ($_.SiteOwnerEmail.Trim() -eq $upn)
        } | Select-Object -First 1

        if ($deletedSite) {
            Write-Warning "A deleted OneDrive of '$upn' was found in the tenant recycle bin ($($deletedSite.Url), deleted $($deletedSite.DeletionTime)). Consider restoring it instead of creating a new, empty OneDrive."
        }
    }
    catch {
        # Informational only; the provisioning request does not depend on this lookup.
        Write-RjRbLog -Message "Could not query the tenant recycle bin. Details: $($_.Exception.Message)" -Verbose
    }
}
#endregion Check for an existing OneDrive
#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################
Write-Output ""
Write-Output "Pre-Provision OneDrive"
Write-Output "---------------------"

if ($existingSite) {
    Write-Output "The OneDrive of '$upn' already exists - no action required."
    $result = [PSCustomObject]@{
        UserPrincipalName = $upn
        Status            = "AlreadyProvisioned"
        OneDriveUrl       = $existingSite.Url
        RequestedAt       = $null
    }
}
else {
    try {
        New-PnPPersonalSite -Email @($upn) -ErrorAction Stop
    }
    catch {
        $provisionErrorMessage = $_.Exception.Message
        if ($provisionErrorMessage -match "401|403|Access denied|Unauthorized") {
            Write-Error "Access denied while requesting the OneDrive for '$upn'. The managed identity needs the 'Sites.FullControl.All' and 'User.ReadWrite.All' application permissions on the Office 365 SharePoint Online API (AppId 00000003-0000-0ff1-ce00-000000000000). Error: $provisionErrorMessage" -ErrorAction Continue
            throw "Access denied requesting OneDrive provisioning"
        }
        Write-Error "Failed to request the OneDrive for '$upn'. Error: $provisionErrorMessage" -ErrorAction Continue
        throw "OneDrive provisioning request failed"
    }

    Write-Output "The OneDrive provisioning request for '$upn' has been queued."
    Write-Output "Provisioning is processed asynchronously by SharePoint and can take from a few minutes up to 24 hours or longer."
    Write-Output "Use the runbook 'Check OneDrive Status' to verify the result."
    $result = [PSCustomObject]@{
        UserPrincipalName = $upn
        Status            = "ProvisioningRequested"
        OneDriveUrl       = $null
        RequestedAt       = (Get-Date).ToUniversalTime()
    }
}

$result
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

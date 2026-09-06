<#
	.SYNOPSIS
	Check whether a user is ready to enrol devices in Microsoft Intune

	.DESCRIPTION
	Evaluates a selected user account for Intune device enrollment readiness and reports a readiness result (Ready, Ready with warnings, or Not ready) along with specific blockers. The runbook checks account status, Intune licensing, device enrollment limits, platform restrictions, and Conditional Access policies that explicitly target device registration or Intune enrollment; policies requiring compliant devices via "All resources" are exempted by Microsoft Entra design. Platform-scoped policies and browser-only client-app requirements are evaluated against the specified enrollment platform, and the runbook performs read-only diagnostics only.

	.NOTES
	Interpretation notes:
	- Checks performed: account state, Intune license and service plan, tenant MDM authority, device
	  enrollment limit, platform restrictions, registered authentication methods, Conditional Access
	  policies, and optionally pilot group membership.
	- Conditional Access is evaluated as a static "What If" against the enrollment sign-in for the
	  selected EnrollmentPlatform; Entra's own What If tool remains the authority.
	- Compliant-device requirements on "All resources" policies do not block enrollment (documented
	  Entra exemption); only policies targeting device registration or the Intune enrollment apps are
	  treated as strict gates.
	- Not evaluated statically: named locations, device filters, sign-in frequency, and terms of use.
	- Expired or already-used Temporary Access Passes are not counted as usable methods.

	Prerequisites:
	- Tenant MDM authority must be "intune" or "office365"; other values block every user.

	.PARAMETER UserName
	User principal name of the user to check for Intune enrolment readiness.

	.PARAMETER EnrollmentPlatform
	Device platform assumed during Conditional Access evaluation. Platform-scoped policies that do not cover this platform are ruled out. When set to 'All', the script evaluates every platform and reports results per platform.

	.PARAMETER CheckPilotGroupMembership
	If set to true, the script checks whether the user is a member of the pilot group. Non-members are reported as Not ready; if the group cannot be found or membership cannot be verified, a warning is issued.

	.PARAMETER PilotGroupDisplayName
	Display name of the pilot group to check for membership. This parameter can be overridden per run or configured in the runbook customization.

	.PARAMETER CallerName
	Name of the user or system that started the runbook. Tracked for auditing purposes.

	.INPUTS
	RunbookCustomization: {
        "Parameters": {
            "EnrollmentPlatform": {
                "DisplayName": "Platform to enroll",
                "SelectSimple": {
                    "Windows": "Windows",
                    "iOS / iPadOS": "iOS",
                    "Android": "Android",
                    "macOS": "macOS",
                    "All platforms": "All"
                }
            },
            "CheckPilotGroupMembership": {
                "DisplayName": "Check pilot group membership"
            },
            "PilotGroupDisplayName": {
                "DisplayName": "Pilot group name"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Target User" } )]
    [String]$UserName,

    [ValidateSet('Windows', 'iOS', 'Android', 'macOS', 'All')]
    [string]$EnrollmentPlatform = 'Windows',

    [bool]$CheckPilotGroupMembership = $false,

    [string]$PilotGroupDisplayName = "col - All Users - Pilot (users)",

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "EnrollmentPlatform: $EnrollmentPlatform" -Verbose
Write-RjRbLog -Message "CheckPilotGroupMembership: $CheckPilotGroupMembership" -Verbose
Write-RjRbLog -Message "PilotGroupDisplayName: $PilotGroupDisplayName" -Verbose
#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################
# The pilot check is meaningless without a group name to look up: an empty name matches nothing, so the
# result would be reported as 'not a member' and read as a finding rather than a configuration mistake.
if ($CheckPilotGroupMembership -and [string]::IsNullOrWhiteSpace($PilotGroupDisplayName)) {
    Write-Error "The pilot group check is enabled but no pilot group name was supplied." -ErrorAction Continue
    throw "PilotGroupDisplayName is required when CheckPilotGroupMembership is enabled"
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
    Write-Error "Failed to connect to Microsoft Graph using the managed identity: $($_.Exception.Message). Ensure the Azure Automation Account's managed identity is enabled and has the required Microsoft Graph application permissions assigned (see this runbook's .permissions.json)." -ErrorAction Continue
    throw
}
#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################
Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"
Write-Output "Getting tenant-level Intune enrollment readiness data (licensing, enrollment configurations, MDM authority, Conditional Access)."

# 1. Subscribed SKUs - used to derive which SKUs carry an Intune-capable service plan.
# Small, single-page tenant-level list; $top is not required by this endpoint, no paging needed.
try {
    $skuResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/subscribedSkus?`$select=skuId,skuPartNumber,servicePlans,prepaidUnits,consumedUnits" -Method GET -ErrorAction Stop
    $StatusQuoTenantSkus = $skuResult.value
}
catch {
    $errorMessage = $_.Exception.Message
    if ($errorMessage -like "*Forbidden*" -or $errorMessage -like "*403*" -or $errorMessage -like "*Authorization_RequestDenied*") {
        Write-Error "Access to the tenant's subscribed SKUs was denied (403). The managed identity is missing the 'Organization.Read.All' Microsoft Graph application permission. Grant it to the Azure Automation Account's managed identity and try again." -ErrorAction Continue
        throw "Missing Organization.Read.All permission on the managed identity"
    }
    elseif ($errorMessage -like "*Unauthorized*" -or $errorMessage -like "*401*" -or $errorMessage -like "*InvalidAuthenticationToken*") {
        Write-Error "Authentication to Microsoft Graph failed while retrieving subscribed SKUs (401). Verify the Azure Automation Account's managed identity is enabled and has not been disabled or removed." -ErrorAction Continue
        throw "Authentication to Microsoft Graph failed"
    }
    elseif ($errorMessage -like "*429*" -or $errorMessage -like "*TooManyRequests*") {
        Write-Error "Microsoft Graph throttled the request for subscribed SKUs (429). This is transient - simply re-run the runbook." -ErrorAction Continue
        throw "Microsoft Graph request was throttled (429)"
    }
    else {
        Write-Error "Failed to retrieve subscribed SKUs: $errorMessage" -ErrorAction Continue
        throw
    }
}

$IntuneCapableSkuIds = @(
    $StatusQuoTenantSkus | Where-Object {
        $_.servicePlans | Where-Object { $_.servicePlanName -like "INTUNE*" }
    } | Select-Object -ExpandProperty skuId
)

$intuneCapableSkuPartNumbers = @(
    $StatusQuoTenantSkus | Where-Object { $IntuneCapableSkuIds -contains $_.skuId } | Select-Object -ExpandProperty skuPartNumber
)

# The service plan IDs of the Intune plans themselves. Needed to tell "the Intune plan on this licence is
# switched off" apart from "some unrelated plan (Yammer, Stream, ...) is switched off" - checking only for
# a non-empty disabledPlans list reports the former when it is really the latter.
$IntuneServicePlanIds = @(
    $StatusQuoTenantSkus |
        ForEach-Object { $_.servicePlans } |
        Where-Object { $_.servicePlanName -like "INTUNE*" } |
        ForEach-Object { [string]$_.servicePlanId } |
        Sort-Object -Unique
)

Write-Output "Subscribed SKUs found: $($StatusQuoTenantSkus.Count)"
Write-Output "Intune-capable SKUs found: $($IntuneCapableSkuIds.Count)"
if ($intuneCapableSkuPartNumbers.Count -gt 0) {
    Write-Output "Intune-capable SKU part numbers: $($intuneCapableSkuPartNumbers -join ', ')"
}
else {
    Write-Output "WARNING: No subscribed SKU in this tenant carries an Intune service plan."
}

# 2. Device enrollment configurations (limit + platform restriction), with assignments expanded
# so Main can determine which one is assigned to the target user/pilot group.
try {
    $enrollmentConfigResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/deviceEnrollmentConfigurations?`$expand=assignments&`$top=999" -Method GET -ErrorAction Stop
    $StatusQuoEnrollmentConfigs = $enrollmentConfigResult.value
}
catch {
    $errorMessage = $_.Exception.Message
    if ($errorMessage -like "*Forbidden*" -or $errorMessage -like "*403*" -or $errorMessage -like "*Authorization_RequestDenied*") {
        Write-Error "Access to device enrollment configurations was denied (403). The managed identity is missing the 'DeviceManagementConfiguration.Read.All' or 'DeviceManagementServiceConfig.Read.All' Microsoft Graph application permission. Grant the missing permission to the Azure Automation Account's managed identity and try again." -ErrorAction Continue
        throw "Missing Intune read permission on the managed identity"
    }
    elseif ($errorMessage -like "*Unauthorized*" -or $errorMessage -like "*401*" -or $errorMessage -like "*InvalidAuthenticationToken*") {
        Write-Error "Authentication to Microsoft Graph failed while retrieving device enrollment configurations (401). Verify the Azure Automation Account's managed identity is enabled and has not been disabled or removed." -ErrorAction Continue
        throw "Authentication to Microsoft Graph failed"
    }
    elseif ($errorMessage -like "*429*" -or $errorMessage -like "*TooManyRequests*") {
        Write-Error "Microsoft Graph throttled the request for device enrollment configurations (429). This is transient - simply re-run the runbook." -ErrorAction Continue
        throw "Microsoft Graph request was throttled (429)"
    }
    else {
        Write-Error "Failed to retrieve device enrollment configurations: $errorMessage" -ErrorAction Continue
        throw
    }
}

$CurrentEnrollmentLimitConfigs = @(
    $StatusQuoEnrollmentConfigs | Where-Object { $_.'@odata.type' -like "*deviceEnrollmentLimitConfiguration" } | Sort-Object -Property priority
)
$CurrentPlatformRestrictionConfigs = @(
    $StatusQuoEnrollmentConfigs | Where-Object {
        $_.'@odata.type' -like "*deviceEnrollmentPlatformRestrictionsConfiguration" -or
        $_.'@odata.type' -like "*deviceEnrollmentPlatformRestrictionConfiguration"
    } | Sort-Object -Property priority
)

Write-Output "Device enrollment configurations found: $($StatusQuoEnrollmentConfigs.Count)"
Write-Output "Enrollment limit configurations: $($CurrentEnrollmentLimitConfigs.Count)"
Write-Output "Platform restriction configurations: $($CurrentPlatformRestrictionConfigs.Count)"
foreach ($config in $CurrentEnrollmentLimitConfigs) {
    $configName = if ($config.displayName -like "") { "Global" } else { $config.displayName }
    Write-Output "  - Limit config '$configName' (priority $($config.priority))"
}
foreach ($config in $CurrentPlatformRestrictionConfigs) {
    $configName = if ($config.displayName -like "") { "Global" } else { $config.displayName }
    Write-Output "  - Platform restriction config '$configName' (priority $($config.priority))"
}

# 3. Tenant MDM authority
try {
    # mobileDeviceManagementAuthority is only returned by the SINGLE-ENTITY form of /organization.
    # Verified live against a tenant:
    # - GET /organization?$select=...,mobileDeviceManagementAuthority returns HTTP 400 on BOTH v1.0 and
    #   beta - Graph rewrites the collection $select into an invalid internal "id in (...)" filter;
    # - GET /organization without $select returns 200 but omits the property entirely;
    # - GET /organization/{tenantId}?$select=... returns 200 with the value, on v1.0 as well as beta.
    # v1.0 is therefore used, which removes the previous beta dependency. Get-MgContext is only a fast
    # path for the tenant ID; the collection read (which always works without $select) is the fallback.
    $currentTenantId = $null
    try {
        $currentTenantId = [string](Get-MgContext).TenantId
    }
    catch {
        Write-RjRbLog -Message "Graph context did not yield a tenant ID; resolving it from /organization instead: $($_.Exception.Message)" -Verbose
    }

    if ([string]::IsNullOrWhiteSpace($currentTenantId)) {
        $orgResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=id" -Method GET -ErrorAction Stop
        $currentTenantId = [string](@($orgResult.value) | Select-Object -First 1).id
        if ([string]::IsNullOrWhiteSpace($currentTenantId)) {
            Write-Error "Could not resolve the tenant ID from either the Graph context or the organization collection. The tenant MDM authority cannot be determined without it." -ErrorAction Continue
            throw "Unable to resolve tenant ID for MDM authority lookup"
        }
    }
    $StatusQuoMdmAuthority = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization/$currentTenantId`?`$select=id,displayName,mobileDeviceManagementAuthority" -Method GET -ErrorAction Stop
}
catch {
    $errorMessage = $_.Exception.Message
    if ($errorMessage -like "*Forbidden*" -or $errorMessage -like "*403*" -or $errorMessage -like "*Authorization_RequestDenied*") {
        Write-Error "Access to the tenant's organization information was denied (403). The managed identity is missing the 'Organization.Read.All' Microsoft Graph application permission. Grant it to the Azure Automation Account's managed identity and try again." -ErrorAction Continue
        throw "Missing Organization.Read.All permission on the managed identity"
    }
    elseif ($errorMessage -like "*Unauthorized*" -or $errorMessage -like "*401*" -or $errorMessage -like "*InvalidAuthenticationToken*") {
        Write-Error "Authentication to Microsoft Graph failed while retrieving the tenant MDM authority (401). Verify the Azure Automation Account's managed identity is enabled and has not been disabled or removed." -ErrorAction Continue
        throw "Authentication to Microsoft Graph failed"
    }
    elseif ($errorMessage -like "*429*" -or $errorMessage -like "*TooManyRequests*") {
        Write-Error "Microsoft Graph throttled the request for the tenant MDM authority (429). This is transient - simply re-run the runbook." -ErrorAction Continue
        throw "Microsoft Graph request was throttled (429)"
    }
    else {
        Write-Error "Failed to retrieve tenant MDM authority: $errorMessage" -ErrorAction Continue
        throw
    }
}

$CurrentMdmAuthority = switch ($StatusQuoMdmAuthority.mobileDeviceManagementAuthority) {
    "intune" { "intune" }
    "sccm" { "sccm" }
    "office365" { "office365" }
    default { "unknown" }
}

Write-Output "Tenant MDM Authority: $($CurrentMdmAuthority)"
if ($CurrentMdmAuthority -ne "intune" -and $CurrentMdmAuthority -ne "office365") {
    Write-Output "WARNING: MDM authority is '$($CurrentMdmAuthority)' - this is a tenant-level blocker for Intune enrollment unless it is set via co-management or another supported path."
}

# 4. Enabled Conditional Access policies
try {
    $caResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies?`$top=999" -Method GET -ErrorAction Stop
    $StatusQuoCaPolicies = @($caResult.value | Where-Object { $_.state -eq 'enabled' })
}
catch {
    $errorMessage = $_.Exception.Message
    if ($errorMessage -like "*Forbidden*" -or $errorMessage -like "*403*" -or $errorMessage -like "*Authorization_RequestDenied*") {
        Write-Error "Access to Conditional Access policies was denied (403). The managed identity is missing the 'Policy.Read.All' Microsoft Graph application permission. Grant it to the Azure Automation Account's managed identity and try again." -ErrorAction Continue
        throw "Missing Policy.Read.All permission on the managed identity"
    }
    elseif ($errorMessage -like "*Unauthorized*" -or $errorMessage -like "*401*" -or $errorMessage -like "*InvalidAuthenticationToken*") {
        Write-Error "Authentication to Microsoft Graph failed while retrieving Conditional Access policies (401). Verify the Azure Automation Account's managed identity is enabled and has not been disabled or removed." -ErrorAction Continue
        throw "Authentication to Microsoft Graph failed"
    }
    elseif ($errorMessage -like "*429*" -or $errorMessage -like "*TooManyRequests*") {
        Write-Error "Microsoft Graph throttled the request for Conditional Access policies (429). This is transient - simply re-run the runbook." -ErrorAction Continue
        throw "Microsoft Graph request was throttled (429)"
    }
    else {
        Write-Error "Failed to retrieve Conditional Access policies: $errorMessage" -ErrorAction Continue
        throw
    }
}

Write-Output "Enabled Conditional Access policies found: $($StatusQuoCaPolicies.Count)"

Write-Output ""
Write-Output "Tenant StatusQuo Summary:"
Write-Output "---------------------"
Write-Output "MDM Authority: $($CurrentMdmAuthority)"
Write-Output "Intune-capable SKUs: $($IntuneCapableSkuIds.Count)"
Write-Output "Enabled CA policies: $($StatusQuoCaPolicies.Count)"
Write-Output "Enrollment limit configs: $($CurrentEnrollmentLimitConfigs.Count)"
Write-Output "Platform restriction configs: $($CurrentPlatformRestrictionConfigs.Count)"

Write-Output ""
Write-Output "Preflight-Check"
Write-Output "---------------------"

# 1. Resolve the target user. This is a genuine blocker - the runbook cannot report on a user it
# cannot find, so any failure here (including a 404-shaped "not found") stops the run.
Write-Output "Resolving target user '$UserName'..."
try {
    $targetUser = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$UserName`?`$select=id,userPrincipalName,displayName,accountEnabled,assignedLicenses,usageLocation" -Method GET -ErrorAction Stop
}
catch {
    $errorMessage = $_.Exception.Message
    if ($errorMessage -like "*Request_ResourceNotFound*" -or $errorMessage -like "*404*" -or $errorMessage -like "*NotFound*") {
        Write-Error "The selected user '$UserName' could not be found in Entra ID. The user picker value may be stale (the user could have been deleted or renamed since it was selected) - re-open the runbook and pick the user again." -ErrorAction Continue
        throw "User '$UserName' not found in Entra ID"
    }
    elseif ($errorMessage -like "*Forbidden*" -or $errorMessage -like "*403*" -or $errorMessage -like "*Authorization_RequestDenied*") {
        Write-Error "Access to the user's Entra ID profile was denied (403). The managed identity is missing the 'User.Read.All' or 'Directory.Read.All' Microsoft Graph application permission. Grant the missing permission to the Azure Automation Account's managed identity and try again." -ErrorAction Continue
        throw "Missing User.Read.All / Directory.Read.All permission on the managed identity"
    }
    elseif ($errorMessage -like "*Unauthorized*" -or $errorMessage -like "*401*" -or $errorMessage -like "*InvalidAuthenticationToken*") {
        Write-Error "Authentication to Microsoft Graph failed while resolving user '$UserName' (401). Verify the Azure Automation Account's managed identity is enabled and has not been disabled or removed." -ErrorAction Continue
        throw "Authentication to Microsoft Graph failed"
    }
    elseif ($errorMessage -like "*429*" -or $errorMessage -like "*TooManyRequests*") {
        Write-Error "Microsoft Graph throttled the request to resolve user '$UserName' (429). This is transient - simply re-run the runbook." -ErrorAction Continue
        throw "Microsoft Graph request was throttled (429)"
    }
    else {
        Write-Error "Failed to resolve user '$UserName' in Entra ID: $errorMessage" -ErrorAction Continue
        throw "User '$UserName' could not be resolved in Entra ID. Verify the value refers to an existing user (object ID or userPrincipalName)."
    }
}

if (-not $targetUser -or -not $targetUser.id) {
    Write-Error "The selected user '$UserName' could not be found in Entra ID. The user picker value may be stale (the user could have been deleted or renamed since it was selected) - re-open the runbook and pick the user again." -ErrorAction Continue
    throw "User '$UserName' not found in Entra ID"
}

Write-Output "Target user resolved: $($targetUser.displayName) ($($targetUser.userPrincipalName))"

# 2. Verify the Intune service is reachable and the managed identity has Intune read permission.
# A lightweight, side-effect-free call ($top=1) is enough to prove both connectivity and permission
# before the Main part starts pulling the actual readiness data.
Write-Output "Verifying Intune service reachability and permissions..."
try {
    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/deviceEnrollmentConfigurations?`$top=1" -Method GET -ErrorAction Stop | Out-Null
    Write-Output "Intune service is reachable."
}
catch {
    $errorMessage = $_.Exception.Message
    if ($errorMessage -like "*Forbidden*" -or $errorMessage -like "*403*" -or $errorMessage -like "*Authorization_RequestDenied*") {
        Write-Error "Access to Intune device enrollment configuration was denied (403). The managed identity is missing the 'DeviceManagementConfiguration.Read.All' or 'DeviceManagementServiceConfig.Read.All' Microsoft Graph application permission. Assign the missing permission to the Azure Automation Account's managed identity and try again." -ErrorAction Continue
        throw "Missing Intune read permission on the managed identity"
    }
    elseif ($errorMessage -like "*Unauthorized*" -or $errorMessage -like "*401*" -or $errorMessage -like "*InvalidAuthenticationToken*") {
        Write-Error "Authentication to Microsoft Graph failed while checking Intune reachability (401). Verify the Azure Automation Account's managed identity is enabled and has not been disabled or removed." -ErrorAction Continue
        throw "Authentication to Microsoft Graph failed"
    }
    elseif ($errorMessage -like "*429*" -or $errorMessage -like "*TooManyRequests*") {
        Write-Error "Microsoft Graph throttled the Intune reachability check (429). This is transient - simply re-run the runbook." -ErrorAction Continue
        throw "Microsoft Graph request was throttled (429)"
    }
    else {
        Write-Error "Failed to reach the Intune service: $errorMessage" -ErrorAction Continue
        throw "Intune service is not reachable"
    }
}

# 3. Optionally resolve the pilot group. This is informational only - if the group cannot be
# uniquely resolved, the pilot-membership finding will be reported as "Unknown" later on rather than
# failing the whole run.
$pilotGroup = $null
if ($CheckPilotGroupMembership) {
    Write-Output "Resolving pilot group '$PilotGroupDisplayName'..."

    # Escape single quotes for the OData filter literal (the default display name contains
    # spaces and parentheses, which are fine, but a literal quote would break the filter).
    $escapedPilotGroupDisplayName = $PilotGroupDisplayName -replace "'", "''"

    try {
        $pilotGroupResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$escapedPilotGroupDisplayName'&`$select=id,displayName" -Method GET -ErrorAction Stop

        if (-not $pilotGroupResult.value -or $pilotGroupResult.value.Count -eq 0) {
            Write-RjRbLog -Message "WARNING: Pilot group '$PilotGroupDisplayName' was not found. Pilot group membership will be reported as 'Unknown'." -Verbose
            $pilotGroup = $null
        }
        else {
            if ($pilotGroupResult.value.Count -gt 1) {
                Write-RjRbLog -Message "WARNING: More than one group matches display name '$PilotGroupDisplayName'. Using the first match; pilot group membership may be inaccurate." -Verbose
            }
            $pilotGroup = $pilotGroupResult.value | Select-Object -First 1
            Write-Output "Pilot group resolved: $($pilotGroup.displayName)"
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -like "*Forbidden*" -or $errorMessage -like "*403*" -or $errorMessage -like "*Authorization_RequestDenied*") {
            Write-RjRbLog -Message "WARNING: Access to resolve pilot group '$PilotGroupDisplayName' was denied (403). The managed identity is missing the 'Group.Read.All' Microsoft Graph application permission. Pilot group membership will be reported as 'Unknown'. Error: $errorMessage" -Verbose
        }
        elseif ($errorMessage -like "*429*" -or $errorMessage -like "*TooManyRequests*") {
            Write-RjRbLog -Message "WARNING: Microsoft Graph throttled the request to resolve pilot group '$PilotGroupDisplayName' (429) - this is transient and may clear on a re-run. Pilot group membership will be reported as 'Unknown'. Error: $errorMessage" -Verbose
        }
        else {
            Write-RjRbLog -Message "WARNING: Failed to resolve pilot group '$PilotGroupDisplayName': $errorMessage. Pilot group membership will be reported as 'Unknown'." -Verbose
        }
        $pilotGroup = $null
    }
}
#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################
# Each check appends a finding to $findings. A finding is "Blocker" (enrollment will fail),
# "Warning" (enrollment may fail, or depends on something we cannot see from Graph), "Pass", or
# "Info" (a fact worth showing that does not affect the verdict - e.g. a Conditional Access policy
# that is in scope on paper but cannot fire during a baseline enrollment).
$findings = [System.Collections.Generic.List[object]]::new()

function Add-ReadinessFinding {
    param(
        [Parameter(Mandatory = $true)][string]$Check,
        [Parameter(Mandatory = $true)][ValidateSet('Pass', 'Warning', 'Blocker', 'Info')][string]$Result,
        [Parameter(Mandatory = $true)][string]$Detail,
        # Set for findings that only concern one enrollment platform (Conditional Access); empty for
        # platform-neutral findings. Drives the per-platform verdict when every platform is checked.
        [string]$Platform = ''
    )
    $findings.Add([PSCustomObject]@{
            Check    = $Check
            Result   = $Result
            Detail   = $Detail
            Platform = $Platform
        })
}

function Write-WrappedOutput {
    <#
        Word-wraps a long explanation to a fixed width with a constant left indent, so the reasoning
        under a finding headline stays scannable in the portal instead of becoming one 300-character line.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [int]$Indent = 8,
        [int]$Width = 110
    )
    $pad = ' ' * $Indent
    $line = $pad
    foreach ($word in ($Text -split '\s+' | Where-Object { $_ })) {
        if (($line.Length + $word.Length) -gt $Width -and $line.Trim().Length -gt 0) {
            Write-Output $line.TrimEnd()
            $line = $pad
        }
        $line += "$word "
    }
    if ($line.Trim().Length -gt 0) { Write-Output $line.TrimEnd() }
}

# --- Shared Conditional Access / authentication-method helpers ---------------------------------

# Authentication-strength policies express their allowedCombinations in the authenticationMethodModes
# vocabulary ("fido2", "password,microsoftAuthenticatorPush", ...), which is NOT the same vocabulary as
# the @odata.type of a registered authentication method. Translating between the two is what makes a
# real strength evaluation possible instead of a "verify this manually" warning.

function Get-RegisteredAuthCombinationNames {
    <#
        Maps a user's registered authentication method objects onto the authenticationMethodModes names
        used by authentication strength allowedCombinations. Returns the distinct set of mode names.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowNull()]$AuthenticationMethods
    )

    $modeNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($method in @($AuthenticationMethods)) {
        $methodType = [string]$method.'@odata.type'
        switch ($methodType) {
            '#microsoft.graph.passwordAuthenticationMethod' {
                [void]$modeNames.Add('password')
            }
            '#microsoft.graph.fido2AuthenticationMethod' {
                [void]$modeNames.Add('fido2')
            }
            '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod' {
                [void]$modeNames.Add('windowsHelloForBusiness')
            }
            '#microsoft.graph.platformCredentialAuthenticationMethod' {
                # Platform credentials (Platform SSO on macOS) are phishing-resistant and are treated by
                # Entra as equivalent to Windows Hello for Business in strength combinations.
                [void]$modeNames.Add('windowsHelloForBusiness')
            }
            '#microsoft.graph.softwareOathAuthenticationMethod' {
                [void]$modeNames.Add('softwareOath')
            }
            '#microsoft.graph.hardwareOathAuthenticationMethod' {
                [void]$modeNames.Add('hardwareOath')
            }
            '#microsoft.graph.x509CertificateAuthenticationMethod' {
                # Graph does not expose whether the certificate is configured as single- or multi-factor,
                # so both modes are credited; the strength evaluation is deliberately optimistic here.
                [void]$modeNames.Add('x509CertificateMultiFactor')
                [void]$modeNames.Add('x509CertificateSingleFactor')
            }
            '#microsoft.graph.temporaryAccessPassAuthenticationMethod' {
                # Graph keeps expired, not-yet-valid and already-consumed passes in the list and flags
                # them with isUsable = false. Such a pass satisfies nothing - crediting it reported a
                # user with only an expired TAP as ready for a FIDO2-or-TAP strength.
                if ($method.isUsable -ne $false) {
                    if ($method.isUsableOnce -eq $true) {
                        [void]$modeNames.Add('temporaryAccessPassOneTime')
                    }
                    else {
                        [void]$modeNames.Add('temporaryAccessPassMultiUse')
                    }
                }
            }
            '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' {
                # The Authenticator app covers push approval; a device tag of SoftwareTokenActivated also
                # means the app can produce an OATH code.
                [void]$modeNames.Add('microsoftAuthenticatorPush')
                if ([string]$method.deviceTag -eq 'SoftwareTokenActivated') {
                    [void]$modeNames.Add('softwareOath')
                }
            }
            '#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod' {
                [void]$modeNames.Add('deviceBasedPush')
            }
            '#microsoft.graph.phoneAuthenticationMethod' {
                # SMS and voice are distinct modes; phoneType tells which one this registration is.
                switch ([string]$method.phoneType) {
                    'mobile' { [void]$modeNames.Add('sms'); [void]$modeNames.Add('voice') }
                    'alternateMobile' { [void]$modeNames.Add('voice') }
                    'office' { [void]$modeNames.Add('voice') }
                    default { [void]$modeNames.Add('sms'); [void]$modeNames.Add('voice') }
                }
            }
            '#microsoft.graph.emailAuthenticationMethod' {
                # Email OTP is a self-service password reset method only - it satisfies no MFA strength.
            }
            default {
                # Unknown or new method type: intentionally not credited, so the evaluation stays honest.
            }
        }
    }

    return @($modeNames)
}

function Test-MfaCapableMethod {
    <#
        Returns $true if the registered mode names include at least one factor Entra accepts as a second
        factor for a plain "require MFA" grant control (i.e. anything other than a password alone).
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$RegisteredCombinationNames
    )

    $mfaCapableModes = @(
        'fido2', 'windowsHelloForBusiness', 'x509CertificateMultiFactor', 'deviceBasedPush',
        'temporaryAccessPassOneTime', 'temporaryAccessPassMultiUse', 'microsoftAuthenticatorPush',
        'softwareOath', 'hardwareOath', 'sms', 'voice', 'federatedMultiFactor'
    )

    return (@($RegisteredCombinationNames | Where-Object { $mfaCapableModes -contains $_ }).Count -gt 0)
}


# ---------------------------------------------------------------------------------------------------
# Conditional Access "What If" evaluation for the Intune enrollment sign-in
# ---------------------------------------------------------------------------------------------------
# A CA policy only affects enrollment if EVERY one of its conditions matches the sign-in that Intune
# enrollment actually performs. Evaluating the target apps and the user scope alone produces false
# blockers: a policy scoped to legacy authentication clients, to browser-only sessions, to the
# device-code flow, or to an elevated risk level cannot fire during a normal enrollment, yet it
# targets "All" cloud apps and therefore looks relevant.
#
# The enrollment sign-in modelled here:
#   client app type  : mobileAppsAndDesktopClients - enrollment sign-ins come from native clients
#                      (OOBE / Autopilot, Company Portal, the enrollment broker), never from a
#                      standalone browser session
#   device platform  : the platform being enrolled, passed in per evaluation - include AND exclude
#                      platform conditions are applied against it
#   auth flow        : neither device-code flow nor authentication transfer
#   user/sign-in risk: none (the baseline case; risk-gated policies are reported separately)
#   device state     : not compliant, not hybrid Entra joined (the device is only now being enrolled)
#
# Compliant-device grants: Microsoft Entra exempts the Intune enrollment sign-in from the
# "Require device to be marked as compliant" control (documented on Microsoft Learn: "The Require
# device to be marked as compliant control doesn't block Intune enrollment"), precisely to avoid the
# chicken-and-egg problem of a device that cannot be compliant before it is enrolled. An app-targeted
# policy carrying that control is therefore NOT an enrollment blocker. Only a policy that explicitly
# targets the enrollment surface (the 'register or join devices' user action, or the Intune
# enrollment apps named directly) is treated as deliberate gating and evaluated strictly.
#
# Anything this model cannot decide is reported as "Unknown" rather than silently passed or blocked -
# named locations, device filter rules, sign-in frequency and terms of use are outside what Graph
# exposes statically. Entra's own "What If" tool remains the authority.

function Test-AuthStrengthSatisfied {
    <#
        Decides whether the user's registered authentication methods can satisfy an authentication
        strength policy. Graph embeds the strength's allowedCombinations directly in the CA policy, so
        this is a real evaluation and not a guess: each allowed combination is a comma-separated set of
        method names, ALL of which the user must have registered for that combination to be usable.
        Returns 'Satisfied', 'NotSatisfied' or 'Unknown'.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowNull()]$AuthenticationStrength,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$RegisteredCombinationNames
    )

    $allowedCombinations = @($AuthenticationStrength.allowedCombinations)
    if ($allowedCombinations.Count -eq 0) { return 'Unknown' }
    if ($RegisteredCombinationNames.Count -eq 0) { return 'Unknown' }

    foreach ($combination in $allowedCombinations) {
        # A combination such as "password,microsoftAuthenticatorPush" requires every listed factor.
        $requiredFactors = @([string]$combination -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($requiredFactors.Count -eq 0) { continue }

        $unmetFactors = @($requiredFactors | Where-Object { $RegisteredCombinationNames -notcontains $_ })
        if ($unmetFactors.Count -eq 0) { return 'Satisfied' }
    }

    return 'NotSatisfied'
}

function Test-CaPolicyAppliesToEnrollment {
    <#
        Applies every condition of a CA policy to the modelled enrollment sign-in for one target
        platform. Returns a PSCustomObject with Applies (bool), Reason (why it was excluded, for the
        log), RiskGated (bool - the policy only fires at elevated risk, so it is reported as
        informational rather than as a baseline blocker) and ExplicitEnrollmentTarget (bool - the
        policy names the enrollment surface directly rather than catching it via 'All' resources).
    #>
    param(
        [Parameter(Mandatory = $true)]$Policy,
        [Parameter(Mandatory = $true)]$User,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$UserGroupIds,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$UserRoleTemplateIds,
        # One Graph devicePlatform value per evaluation: 'windows', 'iOS', 'android' or 'macOS'.
        [Parameter(Mandatory = $true)][string]$EnrollmentPlatform
    )

    $notApplicable = {
        param($reason)
        [PSCustomObject]@{ Applies = $false; Reason = $reason; RiskGated = $false }
    }

    $conditions = $Policy.conditions

    # --- Target resources: the Intune enrollment path -----------------------------------------------
    # 'Microsoft Intune Enrollment' (d4ebce55) and 'Microsoft Intune' (0000000a) are the apps the
    # enrollment sign-in hits; 'urn:user:registerdevice' is the matching user action.
    $intuneEnrollmentAppIds = @('d4ebce55-015a-49b5-a083-c84d1797ae8c', '0000000a-0000-0000-c000-000000000000')
    $includeApps = @($conditions.applications.includeApplications)
    $excludeApps = @($conditions.applications.excludeApplications)
    $includeUserActions = @($conditions.applications.includeUserActions)

    # A policy that names the enrollment surface directly is deliberate gating; one that merely
    # catches it via 'All' resources is subject to Entra's built-in enrollment exemptions.
    $explicitEnrollmentTarget = ($includeUserActions -contains 'urn:user:registerdevice') -or
        (@($includeApps | Where-Object { $intuneEnrollmentAppIds -contains $_ }).Count -gt 0)

    $targetsEnrollment = $explicitEnrollmentTarget
    if ($includeApps -contains 'All') { $targetsEnrollment = $true }

    # A user action other than registerdevice (e.g. urn:user:registersecurityinfo) is its own sign-in
    # and never part of enrollment.
    if ($includeUserActions.Count -gt 0 -and $includeUserActions -notcontains 'urn:user:registerdevice') {
        return & $notApplicable "targets the user action(s) $($includeUserActions -join ', '), not device registration"
    }
    if (-not $targetsEnrollment) {
        return & $notApplicable "does not target the Intune enrollment apps, device registration or all cloud apps"
    }
    # An "All apps" policy that explicitly excludes the enrollment apps is out of the path.
    if ($includeApps -contains 'All' -and @($excludeApps | Where-Object { $intuneEnrollmentAppIds -contains $_ }).Count -gt 0) {
        return & $notApplicable "excludes the Intune enrollment application"
    }

    # --- Client app types --------------------------------------------------------------------------
    # Enrollment sign-ins come from native clients (OOBE / Autopilot, Company Portal, the enrollment
    # broker) - never from a standalone browser session, and never over legacy protocols. A policy
    # scoped only to 'browser' (or to 'other'/'exchangeActiveSync') cannot fire during enrollment.
    $clientAppTypes = @($conditions.clientAppTypes | Where-Object { $_ })
    if ($clientAppTypes.Count -gt 0 -and $clientAppTypes -notcontains 'all' -and $clientAppTypes -notcontains 'mobileAppsAndDesktopClients') {
        return & $notApplicable "applies only to the client app type(s) $($clientAppTypes -join ', '); the enrollment sign-in comes from a native client (OOBE, Company Portal), which none of those cover"
    }

    # --- Authentication flows ---------------------------------------------------------------------
    # Enrollment uses neither the device code flow nor authentication transfer, so a policy scoped to
    # those flows cannot fire. This is what made "Block Device Code Flow" look like a blocker.
    $transferMethods = [string]$conditions.authenticationFlows.transferMethods
    if (-not [string]::IsNullOrWhiteSpace($transferMethods)) {
        $enrollmentFlows = @('none')
        $scopedFlows = @($transferMethods -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if (@($scopedFlows | Where-Object { $enrollmentFlows -contains $_ }).Count -eq 0) {
            return & $notApplicable "applies only to the authentication flow(s) $($transferMethods), which enrollment does not use"
        }
    }

    # --- Device platforms -------------------------------------------------------------------------
    # The platform being enrolled is known, so the include AND exclude lists are evaluated for real.
    # The Where-Object filter matters: a policy without a platform condition yields $null here, and
    # @($null).Count is 1 - filtering keeps the count honest.
    $includePlatforms = @($conditions.devicePlatforms.includePlatforms | Where-Object { $_ })
    $excludePlatforms = @($conditions.devicePlatforms.excludePlatforms | Where-Object { $_ })
    $platformScoped = ($includePlatforms.Count -gt 0 -or $excludePlatforms.Count -gt 0)
    if ($includePlatforms.Count -gt 0 -and $includePlatforms -notcontains 'all' -and $includePlatforms -notcontains $EnrollmentPlatform) {
        return & $notApplicable "is limited to the device platform(s) $($includePlatforms -join ', ') and does not apply when enrolling $EnrollmentPlatform"
    }
    if ($excludePlatforms -contains $EnrollmentPlatform) {
        return & $notApplicable "excludes the device platform $EnrollmentPlatform"
    }

    # --- User scope -------------------------------------------------------------------------------
    $userConditions = $conditions.users
    $includeUsers = @($userConditions.includeUsers)
    $excludeUsers = @($userConditions.excludeUsers)
    $includeGroups = @($userConditions.includeGroups)
    $excludeGroups = @($userConditions.excludeGroups)
    $includeRoles = @($userConditions.includeRoles)
    $excludeRoles = @($userConditions.excludeRoles)

    $isGuest = ([string]$User.userPrincipalName -like '*#EXT#*') -or ([string]$User.userType -eq 'Guest')

    # Exclusions win over every inclusion.
    $isExcluded = ($excludeUsers -contains [string]$User.id)
    if (-not $isExcluded -and $excludeUsers -contains 'GuestsOrExternalUsers' -and $isGuest) { $isExcluded = $true }
    if (-not $isExcluded -and $excludeGroups.Count -gt 0) {
        $isExcluded = @($excludeGroups | Where-Object { $UserGroupIds -contains $_ }).Count -gt 0
    }
    if (-not $isExcluded -and $excludeRoles.Count -gt 0) {
        $isExcluded = @($excludeRoles | Where-Object { $UserRoleTemplateIds -contains $_ }).Count -gt 0
    }
    if (-not $isExcluded -and $userConditions.excludeGuestsOrExternalUsers -and $isGuest) { $isExcluded = $true }
    if ($isExcluded) {
        return & $notApplicable "the user is excluded from this policy"
    }

    $isIncluded = ($includeUsers -contains 'All') -or ($includeUsers -contains [string]$User.id)
    if (-not $isIncluded -and $includeUsers -contains 'GuestsOrExternalUsers' -and $isGuest) { $isIncluded = $true }
    if (-not $isIncluded -and $includeGroups.Count -gt 0) {
        $isIncluded = @($includeGroups | Where-Object { $UserGroupIds -contains $_ }).Count -gt 0
    }
    if (-not $isIncluded -and $includeRoles.Count -gt 0) {
        $isIncluded = @($includeRoles | Where-Object { $UserRoleTemplateIds -contains $_ }).Count -gt 0
    }
    if (-not $isIncluded -and $userConditions.includeGuestsOrExternalUsers -and $isGuest) { $isIncluded = $true }
    if (-not $isIncluded) {
        return & $notApplicable "the user is not in this policy's assignment scope"
    }

    # --- Risk conditions --------------------------------------------------------------------------
    # A risk-gated policy only fires when Entra actually rates the sign-in or the user as risky, which
    # is not the baseline enrollment case. Keep it, but flag it so it is reported as informational.
    $userRiskLevels = @($conditions.userRiskLevels)
    $signInRiskLevels = @($conditions.signInRiskLevels)
    $riskGated = ($userRiskLevels.Count -gt 0) -or ($signInRiskLevels.Count -gt 0)

    [PSCustomObject]@{
        Applies                  = $true
        Reason                   = if ($platformScoped) { "in scope for a $EnrollmentPlatform enrollment (the policy is platform-scoped)" } else { "in scope" }
        RiskGated                = $riskGated
        RiskLevels               = @($userRiskLevels + $signInRiskLevels | Sort-Object -Unique)
        PlatformScoped           = $platformScoped
        Platforms                = $includePlatforms
        ExcludedPlatforms        = $excludePlatforms
        EnrollmentPlatform       = $EnrollmentPlatform
        ExplicitEnrollmentTarget = $explicitEnrollmentTarget
    }
}

function Get-CaEnrollmentAssessment {
    <#
        Turns an applicable CA policy into a verdict for the enrollment sign-in. Returns a
        PSCustomObject with Result ('Pass', 'Warning', 'Blocker', 'Info'), Category (a short, stable
        label used for the report's aggregate counts) and Detail (the human-readable explanation).
    #>
    param(
        [Parameter(Mandatory = $true)]$Policy,
        [Parameter(Mandatory = $true)]$Scope,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$RegisteredCombinationNames,
        [Parameter(Mandatory = $true)][bool]$HasMfaCapableMethod,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$MethodText
    )

    $grantControls = $Policy.grantControls
    $builtInControls = @($grantControls.builtInControls)
    $authStrength = $grantControls.authenticationStrength

    # Report-only policies are not enforced - they never block a real sign-in.
    $isReportOnly = ([string]$Policy.state -eq 'enabledForReportingButNotEnforced')

    # A risk-gated policy does not fire for a baseline enrollment; downgrade it to informational.
    $riskNote = ""
    if ($Scope.RiskGated) {
        $riskNote = " This policy only applies when the user or sign-in risk is $($Scope.RiskLevels -join '/'), which is not the case for a normal enrollment."
    }
    $platformNote = if ($Scope.PlatformScoped) { " The policy is platform-scoped and applies when enrolling $($Scope.EnrollmentPlatform)." } else { "" }

    $downgrade = {
        param($result)
        # Report-only and risk-gated policies cannot block the baseline enrollment sign-in.
        if ($isReportOnly -or $Scope.RiskGated) { return 'Info' }
        return $result
    }

    if ($builtInControls -contains 'block') {
        $result = & $downgrade 'Blocker'
        $prefix = if ($result -eq 'Info') { "This policy would block access in the enrollment path, but does not apply to a baseline enrollment." } else { "This policy blocks access for this user in the enrollment path. Enrollment will fail until the user is excluded or the policy is changed." }
        return [PSCustomObject]@{
            Result   = $result
            Category = 'Conditional Access policy blocks enrollment'
            Detail   = "$prefix$riskNote$platformNote$(if ($isReportOnly) { ' The policy is in report-only mode and is not enforced.' })"
        }
    }

    $requiresCompliant = ($builtInControls -contains 'compliantDevice')
    $requiresHybrid = ($builtInControls -contains 'domainJoinedDevice')
    $requiresCompliantOrHybrid = $requiresCompliant -or $requiresHybrid
    $requiresMfa = ($builtInControls -contains 'mfa')
    # 'OR' means any single control is enough, so an MFA alternative rescues a compliant-device requirement.
    $controlOperator = if ([string]::IsNullOrWhiteSpace([string]$grantControls.operator)) { 'OR' } else { [string]$grantControls.operator }

    if ($requiresCompliant -and -not $Scope.ExplicitEnrollmentTarget) {
        # Documented platform behavior (Microsoft Learn, "Require device compliance with Conditional
        # Access"): "The Require device to be marked as compliant control doesn't block Intune
        # enrollment." Entra exempts the enrollment sign-in from the compliant-device check to avoid
        # the chicken-and-egg problem, so an app-targeted policy carrying this control is not an
        # enrollment blocker. Only a policy explicitly targeting the enrollment surface (handled
        # below) is treated as deliberate gating.
        $nonDeviceControls = @($builtInControls | Where-Object { $_ -notin @('compliantDevice', 'domainJoinedDevice') })
        $hasOtherGrantLegs = ($nonDeviceControls.Count -gt 0) -or ($null -ne $authStrength)
        if ($controlOperator -eq 'OR' -or -not $hasOtherGrantLegs) {
            return [PSCustomObject]@{
                Result   = & $downgrade 'Pass'
                Category = 'Conditional Access compliant-device requirement exempted for enrollment'
                Detail   = "This policy requires a compliant or hybrid Entra joined device, but Microsoft Entra exempts the Intune enrollment sign-in from the compliant-device requirement (documented behavior), so it does not block enrollment. The policy applies to the device as usual once it is enrolled.$riskNote$platformNote"
            }
        }
        # Operator AND with further controls: the device legs are exempt for the enrollment sign-in,
        # but the remaining legs (MFA, authentication strength) still gate it - evaluate those below.
        $requiresCompliantOrHybrid = $false
    }

    if ($requiresCompliantOrHybrid -and $requiresHybrid -and -not $requiresCompliant -and -not $Scope.ExplicitEnrollmentTarget) {
        # Hybrid-join-only requirement: the documented enrollment exemption names only the
        # compliant-device control, so whether it also lifts a hybrid-join-only requirement cannot be
        # verified from Graph. With an OR operator a satisfiable alternative still rescues it.
        $hasSatisfiableAlternative = $false
        if ($controlOperator -eq 'OR') {
            if ($requiresMfa -and $HasMfaCapableMethod) { $hasSatisfiableAlternative = $true }
            if ($authStrength -and (Test-AuthStrengthSatisfied -AuthenticationStrength $authStrength -RegisteredCombinationNames $RegisteredCombinationNames) -eq 'Satisfied') { $hasSatisfiableAlternative = $true }
        }
        if ($hasSatisfiableAlternative) {
            $alternatives = @($builtInControls | Where-Object { $_ -notin @('compliantDevice', 'domainJoinedDevice') })
            return [PSCustomObject]@{
                Result   = & $downgrade 'Pass'
                Category = 'Conditional Access satisfied by alternative control'
                Detail   = "This policy asks for a hybrid Entra joined device, but its controls are combined with OR and the user can satisfy an alternative ($($alternatives -join ', ')), so it does not block enrollment.$riskNote$platformNote"
            }
        }
        return [PSCustomObject]@{
            Result   = if ($isReportOnly -or $Scope.RiskGated) { 'Info' } else { 'Warning' }
            Category = 'Conditional Access hybrid-join requirement not verifiable'
            Detail   = "This policy requires a hybrid Entra joined device in the enrollment path. The documented enrollment exemption covers only the compliant-device control, so whether this blocks a cloud-native enrollment cannot be verified from Graph - check it with the Entra What If tool.$riskNote$platformNote$(if ($isReportOnly) { ' The policy is in report-only mode and is not enforced.' })"
        }
    }

    if ($requiresCompliantOrHybrid) {
        # The policy explicitly targets the enrollment surface (registerdevice user action or the
        # Intune enrollment apps named directly) and demands a device state a device being enrolled
        # cannot yet have. That is deliberate gating, so it is evaluated strictly. With an OR operator
        # and a second, satisfiable control the user still gets through; with AND, or as the only
        # control, this is a genuine blocker.
        # Only controls that can be VERIFIED from Graph count as a rescue. An app-protection-policy
        # control (compliantApplication) is deliberately NOT credited: whether the enrolling client is a
        # managed application cannot be determined from Graph, and crediting it would silently turn a
        # genuine blocker into a Pass. It is surfaced as an unresolved alternative instead.
        $hasSatisfiableAlternative = $false
        if ($controlOperator -eq 'OR') {
            if ($requiresMfa -and $HasMfaCapableMethod) { $hasSatisfiableAlternative = $true }
            if ($authStrength -and (Test-AuthStrengthSatisfied -AuthenticationStrength $authStrength -RegisteredCombinationNames $RegisteredCombinationNames) -eq 'Satisfied') { $hasSatisfiableAlternative = $true }
        }
        $hasUnverifiableAlternative = ($controlOperator -eq 'OR') -and ($builtInControls -contains 'compliantApplication')

        if ($hasSatisfiableAlternative) {
            $alternatives = @($builtInControls | Where-Object { $_ -notin @('compliantDevice', 'domainJoinedDevice') })
            return [PSCustomObject]@{
                Result   = & $downgrade 'Pass'
                Category = 'Conditional Access satisfied by alternative control'
                Detail   = "This policy asks for a compliant or hybrid Entra joined device, but its controls are combined with OR and the user can satisfy an alternative ($($alternatives -join ', ')), so it does not block enrollment.$riskNote$platformNote"
            }
        }

        if ($hasUnverifiableAlternative) {
            return [PSCustomObject]@{
                Result   = if ($isReportOnly -or $Scope.RiskGated) { 'Info' } else { 'Warning' }
                Category = 'Conditional Access alternative control not verifiable'
                Detail   = "This policy asks for a compliant or hybrid Entra joined device OR an approved/app-protected client application. A device being enrolled cannot yet be compliant, so enrollment succeeds only if the enrolling client satisfies the app-protection requirement - which cannot be determined from Graph. Verify this policy against the enrollment client manually.$riskNote$platformNote"
            }
        }

        $result = & $downgrade 'Blocker'
        $prefix = if ($result -eq 'Info') { "This policy requires a compliant or hybrid Entra joined device, but does not apply to a baseline enrollment." } else { "This policy explicitly targets the enrollment path (device registration or the Intune enrollment apps) and requires a compliant or hybrid Entra joined device. A device being enrolled cannot yet be compliant, so this blocks enrollment unless the user is excluded or the policy is changed." }
        return [PSCustomObject]@{
            Result   = $result
            Category = 'Conditional Access requires compliant/hybrid joined device'
            Detail   = "$prefix$riskNote$platformNote$(if ($isReportOnly) { ' The policy is in report-only mode and is not enforced.' })"
        }
    }

    # Authentication strength is a real evaluation: Graph ships the allowed method combinations with
    # the policy, so they can be matched against what the user has actually registered.
    if ($authStrength) {
        $strengthName = if ([string]::IsNullOrWhiteSpace([string]$authStrength.displayName)) { "custom strength" } else { [string]$authStrength.displayName }
        $strengthVerdict = Test-AuthStrengthSatisfied -AuthenticationStrength $authStrength -RegisteredCombinationNames $RegisteredCombinationNames

        switch ($strengthVerdict) {
            'Satisfied' {
                return [PSCustomObject]@{
                    Result   = & $downgrade 'Pass'
                    Category = 'Conditional Access authentication strength satisfied'
                    Detail   = "This policy requires the authentication strength '$strengthName' and the user has a registered method combination that satisfies it.$riskNote$platformNote"
                }
            }
            'NotSatisfied' {
                $result = & $downgrade 'Blocker'
                $allowed = @($authStrength.allowedCombinations) -join ', '
                $prefix = if ($result -eq 'Info') { "This policy requires the authentication strength '$strengthName', which the user's registered methods do not satisfy, but it does not apply to a baseline enrollment." } else { "This policy requires the authentication strength '$strengthName', which none of the user's registered methods satisfy. Registered: $MethodText. The strength accepts: $allowed. Register one of the accepted methods." }
                return [PSCustomObject]@{
                    Result   = $result
                    Category = 'Conditional Access authentication strength not satisfied'
                    Detail   = "$prefix$riskNote$platformNote$(if ($isReportOnly) { ' The policy is in report-only mode and is not enforced.' })"
                }
            }
            default {
                return [PSCustomObject]@{
                    Result   = 'Warning'
                    Category = 'Conditional Access authentication strength unknown'
                    Detail   = "This policy requires the authentication strength '$strengthName', but the user's registered methods could not be read, so it could not be evaluated.$riskNote$platformNote"
                }
            }
        }
    }

    if ($requiresMfa) {
        if ($HasMfaCapableMethod) {
            return [PSCustomObject]@{
                Result   = & $downgrade 'Pass'
                Category = 'Conditional Access MFA satisfied'
                Detail   = "This policy requires multi-factor authentication and the user has a suitable method registered ($MethodText).$riskNote$platformNote"
            }
        }
        $result = & $downgrade 'Blocker'
        $prefix = if ($result -eq 'Info') { "This policy requires multi-factor authentication that the user cannot satisfy, but it does not apply to a baseline enrollment." } else { "This policy requires multi-factor authentication, but the user has no registered method that can satisfy it (registered: $MethodText). Enrollment will fail at sign-in." }
        return [PSCustomObject]@{
            Result   = $result
            Category = 'Conditional Access requires MFA the user cannot satisfy'
            Detail   = "$prefix$riskNote$platformNote$(if ($isReportOnly) { ' The policy is in report-only mode and is not enforced.' })"
        }
    }

    # Remaining controls (app protection policy, terms of use, password change, custom factors) cannot
    # be decided from Graph alone. Report them rather than guessing either way.
    $remaining = @($builtInControls | Where-Object { $_ })
    if ($grantControls.termsOfUse -and @($grantControls.termsOfUse).Count -gt 0) { $remaining += 'termsOfUse' }
    if ($remaining.Count -eq 0) {
        return [PSCustomObject]@{
            Result   = 'Info'
            Category = 'Conditional Access session controls only'
            Detail   = "This policy applies in the enrollment path but sets no grant control that can block sign-in (session controls only).$riskNote$platformNote"
        }
    }

    return [PSCustomObject]@{
        Result   = if ($isReportOnly -or $Scope.RiskGated) { 'Info' } else { 'Warning' }
        Category = 'Conditional Access grant control not evaluated'
        Detail   = "This policy applies in the enrollment path and requires: $($remaining -join ', '). Whether the user can satisfy it cannot be determined from Graph - review it manually.$riskNote$platformNote"
    }
}

$userLabel = "$($targetUser.displayName) ($($targetUser.userPrincipalName))"

Write-Output ""
Write-Output "Intune Enrollment Readiness for $userLabel"
Write-Output "---------------------"

#region Account state

if ($targetUser.accountEnabled -eq $true) {
    Add-ReadinessFinding -Check "Account enabled" -Result "Pass" -Detail "The account is enabled and can sign in."
}
else {
    Add-ReadinessFinding -Check "Account enabled" -Result "Blocker" -Detail "The account is disabled. A disabled user cannot sign in and therefore cannot enroll a device."
}

#endregion Account state

#region Intune license

$assignedSkuIds = @($targetUser.assignedLicenses | Where-Object { $_.skuId } | ForEach-Object { [string]$_.skuId })

# An Intune-capable SKU only helps if the Intune service plan inside it is actually switched on. Collect
# the Intune plan IDs this user has explicitly disabled, per assigned licence, so a licence whose Intune
# plan is off does not count as Intune-licensed.
$disabledIntuneServicePlanIds = @(
    $targetUser.assignedLicenses |
        Where-Object { $_.disabledPlans } |
        ForEach-Object { $_.disabledPlans } |
        ForEach-Object { [string]$_ } |
        Where-Object { $IntuneServicePlanIds -contains $_ } |
        Sort-Object -Unique
)

$matchingIntuneSkuIds = @(
    foreach ($assignedLicense in @($targetUser.assignedLicenses)) {
        $assignedSkuId = [string]$assignedLicense.skuId
        if (-not $assignedSkuId -or $IntuneCapableSkuIds -notcontains $assignedSkuId) { continue }

        # Keep this licence only if it still leaves at least one of its Intune plans enabled.
        $skuIntunePlanIds = @(
            $StatusQuoTenantSkus |
                Where-Object { [string]$_.skuId -eq $assignedSkuId } |
                ForEach-Object { $_.servicePlans } |
                Where-Object { $_.servicePlanName -like "INTUNE*" } |
                ForEach-Object { [string]$_.servicePlanId }
        )
        $licenseDisabledPlanIds = @($assignedLicense.disabledPlans | ForEach-Object { [string]$_ })
        $enabledIntunePlanIds = @($skuIntunePlanIds | Where-Object { $licenseDisabledPlanIds -notcontains $_ })
        if ($enabledIntunePlanIds.Count -gt 0) { $assignedSkuId }
    }
)

if ($matchingIntuneSkuIds.Count -gt 0) {
    # Resolve the SKU part numbers so the output names the license instead of printing bare GUIDs.
    $matchingSkuNames = @(
        $StatusQuoTenantSkus |
            Where-Object { $matchingIntuneSkuIds -contains [string]$_.skuId } |
            ForEach-Object { $_.skuPartNumber }
    )
    $skuNameText = if ($matchingSkuNames.Count -gt 0) { $matchingSkuNames -join ", " } else { $matchingIntuneSkuIds -join ", " }
    Add-ReadinessFinding -Check "Intune license" -Result "Pass" -Detail "An Intune service plan is assigned via: $skuNameText."
}
else {
    if ($assignedSkuIds.Count -eq 0) {
        Add-ReadinessFinding -Check "Intune license" -Result "Blocker" -Detail "No licenses are assigned to this user. Intune enrollment requires a license that includes an Intune service plan (for example Intune Plan 1, Microsoft 365 E3/E5 or Business Premium)."
    }
    elseif ($disabledIntuneServicePlanIds.Count -gt 0) {
        # The specific Intune plan is switched off on an otherwise Intune-capable license - a distinct and
        # commonly missed cause, and the only case where naming it is accurate.
        Add-ReadinessFinding -Check "Intune license" -Result "Blocker" -Detail "The user holds an Intune-capable license, but the Intune service plan itself is switched off on it ($($disabledIntuneServicePlanIds.Count) Intune plan(s) disabled). Re-enable the Intune service plan on the assigned license."
    }
    else {
        Add-ReadinessFinding -Check "Intune license" -Result "Blocker" -Detail "None of the assigned licenses includes an Intune service plan. Assign a license that contains Intune (for example Intune Plan 1, Microsoft 365 E3/E5 or Business Premium)."
    }
}

#endregion Intune license

#region MDM authority

if ($CurrentMdmAuthority -eq 'intune' -or $CurrentMdmAuthority -eq 'office365') {
    Add-ReadinessFinding -Check "MDM authority" -Result "Pass" -Detail "The tenant MDM authority is '$CurrentMdmAuthority'."
}
else {
    Add-ReadinessFinding -Check "MDM authority" -Result "Blocker" -Detail "The tenant MDM authority is '$CurrentMdmAuthority'. Device enrollment into Intune requires the MDM authority to be Intune. This blocks every user in the tenant, not just this one."
}

#endregion MDM authority

#region Device enrollment limit

$deviceCount = $null
try {
    $ownedDevices = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)/ownedDevices?`$select=id&`$top=999" -Method GET -ErrorAction Stop
    $deviceCount = @($ownedDevices.value).Count
}
catch {
    $errorMessage = $_.Exception.Message
    if ($errorMessage -like "*Forbidden*" -or $errorMessage -like "*403*" -or $errorMessage -like "*Authorization_RequestDenied*") {
        Write-RjRbLog -Message "WARNING: Access to the registered devices of '$userLabel' was denied (403). The managed identity is missing the 'User.Read.All' or 'Directory.Read.All' Microsoft Graph application permission. The device enrollment limit check will be reported as a warning. Error: $errorMessage" -Verbose
    }
    elseif ($errorMessage -like "*429*" -or $errorMessage -like "*TooManyRequests*") {
        Write-RjRbLog -Message "WARNING: Microsoft Graph throttled the request for the registered devices of '$userLabel' (429) - this is transient and may clear on a re-run. Error: $errorMessage" -Verbose
    }
    else {
        Write-RjRbLog -Message "WARNING: Could not read the registered devices of '$userLabel': $errorMessage" -Verbose
    }
}

# The applicable limit is the highest-priority enrollment limit configuration. Graph orders these by
# 'priority', where priority 0 is the tenant default that applies when no assigned config wins.
$applicableLimitConfig = $CurrentEnrollmentLimitConfigs | Where-Object { $_.priority -gt 0 } | Select-Object -First 1
if (-not $applicableLimitConfig) {
    $applicableLimitConfig = $CurrentEnrollmentLimitConfigs | Where-Object { $_.priority -eq 0 } | Select-Object -First 1
}
# Test against $null, not truthiness: a limit of 0 is a legitimate "block all enrollment" setting, and
# 0 is falsy in PowerShell, so a truthy test would silently report it as "no limit configured".
$enrollmentLimit = if ($applicableLimitConfig -and $null -ne $applicableLimitConfig.limit) { [int]$applicableLimitConfig.limit } else { $null }
$limitConfigName = if ($applicableLimitConfig) {
    if ([string]::IsNullOrWhiteSpace($applicableLimitConfig.displayName)) { "Global" } else { $applicableLimitConfig.displayName }
}
else { "Global" }

if ($null -eq $deviceCount) {
    Add-ReadinessFinding -Check "Device enrollment limit" -Result "Warning" -Detail "The number of devices already registered to this user could not be read, so the enrollment limit could not be evaluated."
}
elseif ($null -eq $enrollmentLimit) {
    Add-ReadinessFinding -Check "Device enrollment limit" -Result "Pass" -Detail "The user has $deviceCount registered device(s). No device enrollment limit could be determined from the enrollment restrictions."
}
elseif ($deviceCount -ge $enrollmentLimit) {
    Add-ReadinessFinding -Check "Device enrollment limit" -Result "Blocker" -Detail "The user has $deviceCount registered device(s) and the applicable limit ('$limitConfigName') is $enrollmentLimit. Enrollment of another device will be refused until a device is removed or the limit is raised."
}
else {
    Add-ReadinessFinding -Check "Device enrollment limit" -Result "Pass" -Detail "The user has $deviceCount of $enrollmentLimit permitted device(s) ('$limitConfigName')."
}

#endregion Device enrollment limit

#region Platform restrictions

# Platform restrictions are per-platform and assigned to groups. Report the platform states of the
# default (priority 0) configuration and flag that group-assigned overrides may narrow this further,
# because resolving assignment precedence per user is not something Graph exposes directly.
$defaultPlatformConfig = $CurrentPlatformRestrictionConfigs | Where-Object { $_.priority -eq 0 } | Select-Object -First 1
$assignedPlatformConfigCount = @($CurrentPlatformRestrictionConfigs | Where-Object { $_.priority -gt 0 }).Count

if (-not $defaultPlatformConfig) {
    Add-ReadinessFinding -Check "Platform restrictions" -Result "Warning" -Detail "No default platform restriction configuration was found, so the permitted enrollment platforms could not be determined."
}
else {
    $blockedPlatforms = [System.Collections.Generic.List[string]]::new()
    $allowedPlatforms = [System.Collections.Generic.List[string]]::new()
    # These are the platform properties Graph actually exposes on a platform-restrictions configuration.
    # 'androidForWorkRestriction' and 'macRestriction' do not exist on this type - reading them would
    # silently contribute nothing - and 'windowsMobileRestriction' is real and must not be missed.
    foreach ($platformProperty in @('windowsRestriction', 'windowsMobileRestriction', 'iosRestriction', 'androidRestriction', 'macOSRestriction')) {
        $restriction = $defaultPlatformConfig.$platformProperty
        if (-not $restriction) { continue }
        $platformLabel = $platformProperty -replace 'Restriction$', ''
        if ($restriction.platformBlocked -eq $true) { $blockedPlatforms.Add($platformLabel) }
        else { $allowedPlatforms.Add($platformLabel) }
    }

    if ($allowedPlatforms.Count -eq 0) {
        Add-ReadinessFinding -Check "Platform restrictions" -Result "Blocker" -Detail "The default enrollment restriction blocks every platform, so no device can be enrolled."
    }
    else {
        $detail = "Enrollment is permitted for: $($allowedPlatforms -join ', ')."
        if ($blockedPlatforms.Count -gt 0) { $detail += " Blocked: $($blockedPlatforms -join ', ')." }
        if ($assignedPlatformConfigCount -gt 0) {
            $detail += " $assignedPlatformConfigCount group-assigned restriction(s) exist and may override this for the user - verify the assignment if enrollment still fails."
            Add-ReadinessFinding -Check "Platform restrictions" -Result "Warning" -Detail $detail
        }
        else {
            Add-ReadinessFinding -Check "Platform restrictions" -Result "Pass" -Detail $detail
        }
    }
}

#endregion Platform restrictions

#region Conditional Access vs registered authentication methods

$registeredMethods = @()
$registeredMethodTypes = @()
$authMethodsKnown = $false
try {
    $authMethodsResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)/authentication/methods" -Method GET -ErrorAction Stop
    # Keep the full objects: deviceTag, phoneType and isUsableOnce are needed to map a registration onto
    # the authenticationMethodModes vocabulary that authentication-strength policies are written in.
    $registeredMethods = @($authMethodsResult.value)
    $registeredMethodTypes = @($registeredMethods | ForEach-Object { [string]$_.'@odata.type' } | Sort-Object -Unique)
    $authMethodsKnown = $true
}
catch {
    $errorMessage = $_.Exception.Message
    if ($errorMessage -like "*Forbidden*" -or $errorMessage -like "*403*" -or $errorMessage -like "*Authorization_RequestDenied*") {
        Write-RjRbLog -Message "WARNING: Access to the authentication methods of '$userLabel' was denied (403). The managed identity is missing the 'UserAuthenticationMethod.Read.All' Microsoft Graph application permission. The registered authentication methods and any MFA-dependent Conditional Access findings will be reported as warnings. Error: $errorMessage" -Verbose
    }
    elseif ($errorMessage -like "*429*" -or $errorMessage -like "*TooManyRequests*") {
        Write-RjRbLog -Message "WARNING: Microsoft Graph throttled the request for the authentication methods of '$userLabel' (429) - this is transient and may clear on a re-run. Error: $errorMessage" -Verbose
    }
    else {
        Write-RjRbLog -Message "WARNING: Could not read the authentication methods of '$userLabel': $errorMessage" -Verbose
    }
}

# Translate the registered methods into the authenticationMethodModes vocabulary (fido2,
# "password,microsoftAuthenticatorPush", ...) that Conditional Access authentication-strength policies
# express their allowedCombinations in. Without this translation a strength can only be reported as
# "verify manually"; with it, the strength can actually be evaluated against what the user has.
$registeredModeNames = @(Get-RegisteredAuthCombinationNames -AuthenticationMethods $registeredMethods)
$hasStrongAuth = Test-MfaCapableMethod -RegisteredCombinationNames $registeredModeNames
$userStrongMethods = @($registeredModeNames | Where-Object { $_ -ne 'password' } | Sort-Object)

$methodText = if ($registeredModeNames.Count -gt 0) { ($registeredModeNames | Sort-Object) -join ", " } else { "none" }
Write-RjRbLog -Message "Registered authentication methods: $methodText" -Verbose

# A Temporary Access Pass that has expired, is not yet valid or was already consumed is still listed
# by Graph (isUsable = false) but is deliberately not credited above. Say so in the finding - it is
# the most common reason a user who "has a TAP" still cannot enroll.
$unusableTapCount = @($registeredMethods | Where-Object { [string]$_.'@odata.type' -eq '#microsoft.graph.temporaryAccessPassAuthenticationMethod' -and $_.isUsable -eq $false }).Count
$unusableTapNote = if ($unusableTapCount -gt 0) { " $unusableTapCount Temporary Access Pass(es) are registered but not usable (expired, not yet valid or already used) and were ignored - issue a new TAP if one is required." } else { "" }
if ($unusableTapCount -gt 0) { Write-RjRbLog -Message "Ignored $unusableTapCount unusable Temporary Access Pass(es) for '$userLabel'." -Verbose }

if (-not $authMethodsKnown) {
    Add-ReadinessFinding -Check "Registered authentication methods" -Result "Warning" -Detail "The authentication methods of this user could not be read, so Conditional Access MFA and authentication-strength requirements could not be evaluated."
}
elseif ($registeredModeNames.Count -eq 0) {
    Add-ReadinessFinding -Check "Registered authentication methods" -Result "Warning" -Detail "This user has no usable registered authentication methods. Any Conditional Access policy that requires MFA will block enrollment.$unusableTapNote"
}
elseif ($hasStrongAuth) {
    Add-ReadinessFinding -Check "Registered authentication methods" -Result "Pass" -Detail "The user has $($userStrongMethods.Count) method(s) that can satisfy an MFA requirement: $methodText.$unusableTapNote"
}
else {
    Add-ReadinessFinding -Check "Registered authentication methods" -Result "Warning" -Detail "The user has only password-based authentication ($methodText). Any Conditional Access policy that requires MFA will block enrollment until a second factor is registered.$unusableTapNote"
}

# Conditional Access is evaluated "What If"-style against the sign-in that Intune enrollment actually
# performs, so only policies whose EVERY condition matches are considered. Evaluating target apps and
# user scope alone produced false blockers: a policy scoped to legacy authentication clients, to the
# device-code flow, or to an elevated risk level targets "All" cloud apps and therefore looked relevant
# even though it can never fire during an interactive enrollment.

# CA assignment scope can reference groups and directory roles, so resolve both once for this user.
$userGroupIds = @()
try {
    $memberOfResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)/transitiveMemberOf/microsoft.graph.group?`$select=id&`$top=999" -Method GET -ErrorAction Stop
    $userGroupIds = @($memberOfResult.value | ForEach-Object { [string]$_.id })
}
catch {
    $errorMessage = $_.Exception.Message
    if ($errorMessage -like "*Forbidden*" -or $errorMessage -like "*403*" -or $errorMessage -like "*Authorization_RequestDenied*") {
        Write-RjRbLog -Message "WARNING: Access to the group memberships of '$userLabel' was denied (403). The managed identity is missing the 'Group.Read.All' Microsoft Graph application permission. Conditional Access scoping may be incomplete. Error: $errorMessage" -Verbose
    }
    elseif ($errorMessage -like "*429*" -or $errorMessage -like "*TooManyRequests*") {
        Write-RjRbLog -Message "WARNING: Microsoft Graph throttled the request for the group memberships of '$userLabel' (429) - this is transient and may clear on a re-run. Conditional Access scoping may be incomplete. Error: $errorMessage" -Verbose
    }
    else {
        Write-RjRbLog -Message "WARNING: Could not read group memberships of '$userLabel', Conditional Access scoping may be incomplete: $errorMessage" -Verbose
    }
}

$userRoleTemplateIds = @()
try {
    $roleResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)/transitiveMemberOf/microsoft.graph.directoryRole?`$select=roleTemplateId&`$top=999" -Method GET -ErrorAction Stop
    $userRoleTemplateIds = @($roleResult.value | ForEach-Object { [string]$_.roleTemplateId } | Where-Object { $_ })
}
catch {
    Write-RjRbLog -Message "WARNING: Could not read the directory roles of '$userLabel'; Conditional Access policies scoped to directory roles may be missed: $($_.Exception.Message)" -Verbose
}

# Map the EnrollmentPlatform parameter onto the Graph devicePlatform vocabulary. 'All' evaluates
# every enrollable platform and reports Conditional Access findings (and the verdict) per platform.
$platformMap = [ordered]@{ 'Windows' = 'windows'; 'iOS' = 'iOS'; 'Android' = 'android'; 'macOS' = 'macOS' }
$platformsToCheck = if ($EnrollmentPlatform -eq 'All') { @($platformMap.Keys | ForEach-Object { [string]$_ }) } else { @($EnrollmentPlatform) }
$multiPlatform = ($platformsToCheck.Count -gt 1)

foreach ($platformKey in $platformsToCheck) {
    $graphPlatform = [string]$platformMap[$platformKey]
    $checkPrefix = if ($multiPlatform) { "Conditional Access ($platformKey)" } else { "Conditional Access" }

    $relevantPolicies = [System.Collections.Generic.List[object]]::new()
    $skippedPolicyCount = 0

    foreach ($policy in $StatusQuoCaPolicies) {
        $scope = Test-CaPolicyAppliesToEnrollment -Policy $policy -User $targetUser -UserGroupIds $userGroupIds -UserRoleTemplateIds $userRoleTemplateIds -EnrollmentPlatform $graphPlatform
        if (-not $scope.Applies) {
            $skippedPolicyCount++
            $skippedName = if ([string]::IsNullOrWhiteSpace([string]$policy.displayName)) { [string]$policy.id } else { [string]$policy.displayName }
            # Logged rather than printed: this is the audit trail for why a policy was ruled out.
            Write-RjRbLog -Message "Conditional Access policy '$skippedName' is not in the $platformKey enrollment path - $($scope.Reason)." -Verbose
            continue
        }
        $relevantPolicies.Add([PSCustomObject]@{ Policy = $policy; Scope = $scope })
    }

    Write-RjRbLog -Message "Conditional Access ($platformKey): $($relevantPolicies.Count) of $(@($StatusQuoCaPolicies).Count) enabled policy(ies) apply to the enrollment sign-in; $skippedPolicyCount ruled out by their conditions." -Verbose

    if ($relevantPolicies.Count -eq 0) {
        Add-ReadinessFinding -Check $checkPrefix -Result "Pass" -Platform $platformKey -Detail "No enabled Conditional Access policy applies to the Intune enrollment sign-in for this user on $platformKey ($skippedPolicyCount policy(ies) were ruled out by their conditions)."
    }
    else {
        foreach ($entry in $relevantPolicies) {
            $policy = $entry.Policy
            $policyName = if ([string]::IsNullOrWhiteSpace([string]$policy.displayName)) { "Unnamed policy ($($policy.id))" } else { [string]$policy.displayName }
            $assessment = Get-CaEnrollmentAssessment -Policy $policy -Scope $entry.Scope -RegisteredCombinationNames $registeredModeNames -HasMfaCapableMethod $hasStrongAuth -MethodText $methodText
            Add-ReadinessFinding -Check "${checkPrefix}: $policyName" -Result $assessment.Result -Platform $platformKey -Detail $assessment.Detail
        }
    }
}

#endregion Conditional Access vs registered authentication methods

#region Pilot group membership

if ($CheckPilotGroupMembership) {
    if (-not $pilotGroup) {
        Add-ReadinessFinding -Check "Pilot group membership" -Result "Warning" -Detail "The pilot group '$PilotGroupDisplayName' was not found, so membership could not be checked."
    }
    else {
        $isPilotMember = $false
        $membershipVerified = $false
        try {
            $pilotCheck = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$($pilotGroup.id)/transitiveMembers/microsoft.graph.user?`$select=id&`$filter=id eq '$($targetUser.id)'" -Method GET -ErrorAction Stop
            $isPilotMember = @($pilotCheck.value).Count -gt 0
            $membershipVerified = $true
        }
        catch {
            $errorMessage = $_.Exception.Message
            if ($errorMessage -like "*Forbidden*" -or $errorMessage -like "*403*" -or $errorMessage -like "*Authorization_RequestDenied*") {
                Write-RjRbLog -Message "WARNING: Access to check membership of pilot group '$($pilotGroup.displayName)' was denied (403). The managed identity is missing the 'Group.Read.All' Microsoft Graph application permission. Error: $errorMessage" -Verbose
            }
            elseif ($errorMessage -like "*429*" -or $errorMessage -like "*TooManyRequests*") {
                Write-RjRbLog -Message "WARNING: Microsoft Graph throttled the request to check membership of pilot group '$($pilotGroup.displayName)' (429) - this is transient and may clear on a re-run. Error: $errorMessage" -Verbose
            }
            else {
                Write-RjRbLog -Message "WARNING: Could not check membership of pilot group '$($pilotGroup.displayName)': $errorMessage" -Verbose
            }
            Add-ReadinessFinding -Check "Pilot group membership" -Result "Warning" -Detail "Membership of the pilot group '$($pilotGroup.displayName)' could not be verified."
        }

        if ($isPilotMember) {
            Add-ReadinessFinding -Check "Pilot group membership" -Result "Pass" -Detail "The user is a member of the pilot group '$($pilotGroup.displayName)'."
        }
        elseif ($membershipVerified) {
            # The check was explicitly requested: in a piloted rollout every enrollment-relevant
            # configuration is targeted at that group, so a non-member is not ready by definition.
            Add-ReadinessFinding -Check "Pilot group membership" -Result "Blocker" -Detail "The user is not a member of the pilot group '$($pilotGroup.displayName)'. Configuration targeted at the pilot group will not reach the user - add the user to the group before enrolling."
        }
    }
}

#endregion Pilot group membership

# Rendering: the verdict comes FIRST (it is the one line the reader came for), then the findings
# grouped by severity - blockers, warnings, passes, informational - each as a short headline with
# its explanation word-wrapped underneath. Nothing is printed twice. Deliberately not wrapped in a
# nested sub-region - a fragment must not end on an #endregion line, which the builder strips as a
# self-authored region wrapper.

$blockers = @($findings | Where-Object { $_.Result -eq 'Blocker' })
$warnings = @($findings | Where-Object { $_.Result -eq 'Warning' })
$passes = @($findings | Where-Object { $_.Result -eq 'Pass' })
$infos = @($findings | Where-Object { $_.Result -eq 'Info' })

$overallResult = if ($blockers.Count -gt 0) { "NOT READY - $($blockers.Count) blocker(s), $($warnings.Count) warning(s)" }
elseif ($warnings.Count -gt 0) { "READY WITH WARNINGS - $($warnings.Count) item(s) could not be fully verified" }
else { "READY - no blockers or warnings" }

# Section titles carry a leading "## " so the portal renders them as headings.
Write-Output ""
Write-Output "## Readiness Result"
Write-Output "---------------------"
Write-Output ("{0,-10}: {1}" -f 'User', $userLabel)
Write-Output ("{0,-10}: {1}" -f 'Platform', $(if ($multiPlatform) { "All ($($platformsToCheck -join ', '))" } else { $EnrollmentPlatform }))
Write-Output ("{0,-10}: {1}" -f 'Result', $overallResult)
if ($multiPlatform) {
    # Per-platform result: platform-neutral findings (license, MDM authority, limits) count against
    # every platform; Conditional Access findings only against the platform they were evaluated for.
    foreach ($platformKey in $platformsToCheck) {
        $platformBlockers = @($blockers | Where-Object { [string]$_.Platform -in @('', $platformKey) })
        $platformWarnings = @($warnings | Where-Object { [string]$_.Platform -in @('', $platformKey) })
        $platformResult = if ($platformBlockers.Count -gt 0) { "NOT READY ($($platformBlockers.Count) blocker(s))" }
        elseif ($platformWarnings.Count -gt 0) { "READY WITH WARNINGS ($($platformWarnings.Count) warning(s))" }
        else { "READY" }
        Write-Output ("{0,-10}: {1}" -f "  $platformKey", $platformResult)
    }
}

# Sort each group so the checks read in a stable order: Conditional Access policies after the
# account/licence/tenant checks, alphabetically within each.
$sortByCheck = @{ Expression = { if ($_.Check -like 'Conditional Access*') { 1 } else { 0 } } }, @{ Expression = { $_.Check } }

# Blockers and warnings go to the runbook output - they are what the requester must act on.
$renderGroup = {
    param([string]$Title, [object[]]$Items, [string]$Marker)
    Write-Output ""
    Write-Output "## $Title ($($Items.Count))"
    Write-Output "---------------------"
    if ($Items.Count -eq 0) {
        Write-Output "  none"
        return
    }
    foreach ($item in ($Items | Sort-Object -Property $sortByCheck)) {
        # Headline on its own line, explanation indented underneath - the eye can scan the headlines
        # and only read the reasoning for the items that matter.
        Write-Output "  $Marker $($item.Check)"
        Write-WrappedOutput -Text $item.Detail
    }
}

& $renderGroup 'Blockers' $blockers '[X]'
& $renderGroup 'Warnings' $warnings '[!]'

# Passed and informational findings are the evidence trail, not the answer: they go to the job log
# (visible in the Automation account, suppressed from the requester's output) so the output stays
# focused on what is wrong. One summary line in the output says where to find them.
$logGroup = {
    param([string]$Title, [object[]]$Items, [string]$Marker)
    Write-RjRbLog -Message "$Title ($($Items.Count))" -Verbose
    foreach ($item in ($Items | Sort-Object -Property $sortByCheck)) {
        Write-RjRbLog -Message "$Marker $($item.Check) - $($item.Detail)" -Verbose
    }
}

& $logGroup 'Passed' $passes '[OK]'
if ($infos.Count -gt 0) {
    & $logGroup 'Informational' $infos '[i]'
    Write-RjRbLog -Message "Informational Conditional Access policies are in scope on paper but cannot affect a baseline enrollment (report-only, risk-gated, or satisfied by an alternative control). They do not count against the result." -Verbose
}

Write-Output ""
Write-Output "$($passes.Count) check(s) passed$(if ($infos.Count -gt 0) { ", $($infos.Count) informational" }) - details are in the job log."
#endregion Main Part

########################################################
#region     Cleanup
########################################################
try {
    Disconnect-MgGraph -ErrorAction Stop | Out-Null
}
catch {
    Write-RjRbLog -Message "Microsoft Graph session was already disconnected or could not be closed: $($_.Exception.Message)" -Verbose
}

Write-Output ""
Write-Output "Done!"
#endregion Cleanup

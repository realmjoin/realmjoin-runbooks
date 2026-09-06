<#
	.SYNOPSIS
	Report Intune enrollment readiness for a set of users

	.DESCRIPTION
	Analyzes whether each user in a selected user set can enroll a device in Microsoft Intune by checking account status, Intune licensing, device enrollment limits, authentication methods, and Conditional Access policies that explicitly target device registration or Intune enrollment; policies requiring compliant devices via "All resources" are exempted per Microsoft Entra design. Platform-scoped policies and browser-only client-app constraints are evaluated against the selected enrollment platform. Results are exported as CSV and/or XLSX with optional email delivery.

	.NOTES
	Interpretation notes:
	- Checks performed per user: account state, Intune license and service plan, tenant MDM authority,
	  device enrollment limit, platform restrictions, registered authentication methods, Conditional
	  Access policies, and optionally pilot group membership.
	- Conditional Access is evaluated as a static "What If" against the enrollment sign-in for each
	  user's EnrollmentPlatform; Entra's own What If tool remains the authority.
	- Compliant-device requirements on "All resources" policies do not block enrollment (documented
	  Entra exemption); only policies targeting device registration or the Intune enrollment apps are
	  treated as strict gates.
	- Not evaluated statically: named locations, device filters, sign-in frequency, and terms of use.
	- Expired or already-used Temporary Access Passes are not counted as usable methods.

	Prerequisites:
	- Requires the RJReport.EmailSender setting for email delivery, and at least one of UserName or
	  GroupName (memberships resolved transitively).

	.PARAMETER UserName
	User principal names of users to check for Intune enrollment readiness. Select one or more users. At least one of UserName or GroupName must be supplied; both may be combined.

	.PARAMETER GroupName
	Display name of a group whose members to check for Intune enrollment readiness. Group membership is resolved transitively, including nested groups. At least one of UserName or GroupName must be supplied; both may be combined.

	.PARAMETER EnrollmentPlatform
	Device platform assumed during Conditional Access evaluation. Platform-scoped policies that do not cover this platform are ruled out. When set to 'All', the script evaluates every platform and reports results per platform.

	.PARAMETER CheckPilotGroupMembership
	If set to true, the report includes a column showing pilot group membership for each user. Users who are not members are marked "Not ready" with the reason "Not a member of the pilot group"; if the group cannot be found or verified, a warning is issued.

	.PARAMETER PilotGroupDisplayName
	Display name of the pilot group to check membership against when CheckPilotGroupMembership is enabled. Default is "col - All Users - Pilot (users)". This can be overridden per run or configured via runbook customization.

	.PARAMETER EmailFrom
	The sender email address for report delivery. Configured as a tenant setting; leave empty if no email report is requested.

	.PARAMETER BrandingHeaderImageUrl
	URL of a custom header image for report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

	.PARAMETER BrandingFooterImageUrl
	URL of a custom footer image for report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

	.PARAMETER BrandingFooterLink
	Link target applied to the footer image in report emails, for example the company website. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

	.PARAMETER BrandingAccentColor
	Accent color used for headings and highlights in report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

	.PARAMETER BrandingTextColor
	Body text color used in report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

	.PARAMETER SendEmailReport
	If set to true, the report is sent as an email to the address specified by EmailTo. If false, the report is generated but not emailed.

	.PARAMETER EmailTo
	Recipient email address or multiple comma-separated addresses for the report email. Required when SendEmailReport is set to true. Each recipient receives an individual email for privacy.

	.PARAMETER ReportFileFormat
	File format for the generated report: CSV only, CSV & XLSX (both files), or XLSX only.

	.PARAMETER CallerName
	Name of the user or system that started the runbook. Tracked for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"UserName": {
				"DisplayName": "Users to check"
			},
			"GroupName": {
				"DisplayName": "Group to check (members)"
			},
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
				"DisplayName": "Pilot group display name"
			},
			"EmailFrom": {
				"Hide": true
			},
			"SendEmailReport": {
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
			"ReportFileFormat": {
				"DisplayName": "Report file format",
				"Select": {
					"Options": [
						{ "Display": "CSV & XLSX", "ParameterValue": "CSV & XLSX" },
						{ "Display": "CSV only",   "ParameterValue": "CSV only" },
						{ "Display": "XLSX only",  "ParameterValue": "XLSX only" }
					],
					"ShowValue": false
				}
			},
			"CallerName": {
				"Hide": true
			}
		},
		"ParameterList": [
			{
				"DisplayName": "Report delivery",
				"DisplayAfter": "BrandingTextColor",
				"Select": {
					"Options": [
						{
							"Display": "No email report",
							"Customization": {
								"Default": { "SendEmailReport": false },
								"Hide": [ "EmailTo", "ReportFileFormat" ]
							}
						},
						{
							"Display": "Email report",
							"Customization": {
								"Default": { "SendEmailReport": true },
								"Show": [ "EmailTo", "ReportFileFormat" ],
								"Mandatory": [ "EmailTo" ]
							}
						}
					]
				}
			}
		]
	}

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param(
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Users to check" } )]
    [String[]]$UserName = @(),

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Group to check (members)" } )]
    [String]$GroupName = "",

    [ValidateSet('Windows', 'iOS', 'Android', 'macOS', 'All')]
    [string]$EnrollmentPlatform = 'Windows',

    [bool]$CheckPilotGroupMembership = $false,

    [string]$PilotGroupDisplayName = "col - All Users - Pilot (users)",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ } )]
    [string]$EmailFrom,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ } )]
    [string]$BrandingHeaderImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ } )]
    [string]$BrandingFooterImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ } )]
    [string]$BrandingFooterLink,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" -Value $_ } )]
    [string]$BrandingAccentColor,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" -Value $_ } )]
    [string]$BrandingTextColor,

    [bool]$SendEmailReport = $false,

    [string]$EmailTo,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "RealmJoin Runbook: Report Intune Enrollment Readiness. Version: $Version" -Verbose

Write-RjRbLog -Message "UserName: $(($UserName | Measure-Object).Count) user(s) selected" -Verbose
Write-RjRbLog -Message "GroupName: $GroupName" -Verbose
Write-RjRbLog -Message "EnrollmentPlatform: $EnrollmentPlatform" -Verbose
Write-RjRbLog -Message "CheckPilotGroupMembership: $CheckPilotGroupMembership" -Verbose
Write-RjRbLog -Message "PilotGroupDisplayName: $PilotGroupDisplayName" -Verbose

Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################
# The report needs a scope. Both pickers are individually optional so either can be used alone, but
# supplying neither would silently produce an empty report instead of telling the requestor why.
$hasUserScope = @($UserName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0
$hasGroupScope = -not [string]::IsNullOrWhiteSpace($GroupName)

if (-not $hasUserScope -and -not $hasGroupScope) {
    Write-Error "No users selected. Select one or more users, a group whose members should be checked, or both." -ErrorAction Continue
    throw "No report scope supplied: either 'Users to check' or 'Group to check (members)' is required"
}

# The pilot check is meaningless without a group name to look up. An empty name would match nothing and
# every user would be reported as 'Unknown', so fail fast rather than produce a misleading column.
if ($CheckPilotGroupMembership -and [string]::IsNullOrWhiteSpace($PilotGroupDisplayName)) {
    Write-Error "The pilot group check is enabled but no pilot group name was supplied." -ErrorAction Continue
    throw "PilotGroupDisplayName is required when CheckPilotGroupMembership is enabled"
}

# A sender address is required before any mail can be sent
if (($SendEmailReport -or $EmailTo) -and -not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. Configure it in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
    Write-Error -Message "Missing email sender configuration (RJReport.EmailSender)." -ErrorAction Continue
    throw "Missing email sender configuration (RJReport.EmailSender)."
}

# A recipient is required if the email report was switched on
if ($SendEmailReport -and (-not $EmailTo)) {
    Write-Error -Message "SendEmailReport is enabled but no EmailTo address was provided." -ErrorAction Continue
    throw "Missing email recipient (EmailTo) while SendEmailReport is enabled."
}
#endregion Parameter Validation

########################################################
#region     Function Definitions
########################################################
function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response. Logs progress for slow or
        large pulls and surfaces Graph errors with the failing URI for easier troubleshooting.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/healthOverviews".

        .EXAMPLE
        PS C:\> $allIssues = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/issues"
    #>
    param(
        [string]$Uri
    )

    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    $pageCount = 0

    do {
        try {
            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to retrieve paged data from '$nextLink': $($_.Exception.Message)" -ErrorAction Continue
            throw
        }

        $pageCount++
        if ($response.value) {
            $allResults.AddRange([object[]]$response.value)
        }

        if ($pageCount % 5 -eq 0) {
            Write-RjRbLog -Message "Pagination progress: $pageCount pages, $($allResults.Count) items retrieved so far" -Verbose
        }

        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    if ($pageCount -gt 1) {
        Write-RjRbLog -Message "Pagination complete: $pageCount pages, $($allResults.Count) total items" -Verbose
    }

    return $allResults.ToArray()
}

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
#endregion Function Definitions

########################################################
#region     Connect Part
########################################################
Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    # Fatal: without a Graph session nothing in this report can be produced.
    Write-Error "Failed to connect to Microsoft Graph using the Automation Account's managed identity: $($_.Exception.Message). Verify the managed identity is enabled on this Automation Account and has been granted the application permissions listed in .permissions.json (at minimum User.Read.All, Directory.Read.All, Organization.Read.All)." -ErrorAction Continue
    throw
}

Write-Output "## Retrieving tenant information..."
$tenantDisplayName = "Unknown Tenant"
try {
    $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
    }
    elseif ($organizationResponse.displayName) {
        $tenantDisplayName = $organizationResponse.displayName
    }
    Write-Output "## Tenant: $($tenantDisplayName)"
}
catch {
    # Non-fatal: the report still runs, just with a generic tenant label. 403 here almost always
    # means Organization.Read.All is missing on the managed identity.
    Write-RjRbLog -Message "WARNING: Failed to retrieve tenant information (continuing with 'Unknown Tenant'): $($_.Exception.Message). If this is a 403/Forbidden, grant the Organization.Read.All application permission to the Automation Account's managed identity." -Verbose
}

# "Email report" feature - Connect-RjRbGraph authenticates the sender identity used by Send-RjReportEmail
if ($SendEmailReport) {
    Write-Output "Graph connection for RJ RunbookHelper..."
    try {
        Connect-RjRbGraph
    }
    catch {
        # Fatal only because SendEmailReport was requested; the report files themselves are unaffected
        # by this failure since it happens before any data collection or export.
        Write-Error "Failed to establish the RJ RunbookHelper Graph connection required for Send-RjReportEmail: $($_.Exception.Message). Verify the managed identity has the Mail.Send application permission granted (required for the optional report email)." -ErrorAction Continue
        throw
    }
}
#endregion Connect Part

########################################################
#region     Data Collection
########################################################
Write-Output ""
Write-Output "## Resolving target users"
Write-Output "---------------------"

# Initialize target user list
[System.Collections.Generic.List[object]]$targetUsers = @()
$resolvedUserIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

# Resolve individually-selected users
if ($UserName -and $UserName.Count -gt 0) {
    foreach ($userId in $UserName) {
        try {
            $user = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$userId`?`$select=id,userPrincipalName,displayName,accountEnabled,assignedLicenses,usageLocation,department" -Method GET -ErrorAction Stop
            if ($user) {
                $targetUsers.Add($user)
                [void]$resolvedUserIds.Add($user.id)
            }
        }
        catch {
            # Non-fatal: one unresolvable picker value must not abort the whole report.
            $userLookupError = $_
            if ($userLookupError.Exception.Message -like "*404*" -or $userLookupError.Exception.Message -like "*Request_ResourceNotFound*") {
                Write-RjRbLog -Message "WARNING: User '$userId' was not found in Entra ID. The picker value may be stale (the user may have been deleted since it was selected). Skipping this user." -Verbose
            }
            elseif ($userLookupError.Exception.Message -like "*429*" -or $userLookupError.Exception.Message -like "*TooManyRequests*") {
                Write-RjRbLog -Message "WARNING: Request for user '$userId' was throttled by Microsoft Graph (429). Skipping for this run; re-run the report to retry. Detail: $($userLookupError.Exception.Message)" -Verbose
            }
            elseif ($userLookupError.Exception.Message -like "*403*" -or $userLookupError.Exception.Message -like "*Forbidden*") {
                Write-RjRbLog -Message "WARNING: Access denied resolving user '$userId'. Grant the User.Read.All application permission to the Automation Account's managed identity. Detail: $($userLookupError.Exception.Message)" -Verbose
            }
            else {
                Write-RjRbLog -Message "WARNING: Failed to resolve user '$userId': $($userLookupError.Exception.Message)" -Verbose
            }
        }
    }
}

# Resolve group members if a group is specified
if ($GroupName) {
    try {
        Write-RjRbLog -Message "Retrieving group members..." -Verbose
        $groupUri = "https://graph.microsoft.com/v1.0/groups/$GroupName/transitiveMembers/microsoft.graph.user?`$select=id,userPrincipalName,displayName,accountEnabled,assignedLicenses,usageLocation,department&`$top=999"
        $groupMembers = Get-GraphPagedResult -Uri $groupUri

        foreach ($member in $groupMembers) {
            if (-not $resolvedUserIds.Contains($member.id)) {
                $targetUsers.Add($member)
                [void]$resolvedUserIds.Add($member.id)
            }
        }
    }
    catch {
        # Non-fatal here: if individual users were also supplied, the report can still proceed with those.
        # Zero total resolved users is caught by the "no users to evaluate" guard below.
        $groupLookupError = $_
        if ($groupLookupError.Exception.Message -like "*404*" -or $groupLookupError.Exception.Message -like "*Request_ResourceNotFound*") {
            Write-RjRbLog -Message "WARNING: Group '$GroupName' was not found in Entra ID. The picker value may be stale (the group may have been deleted since it was selected)." -Verbose
        }
        elseif ($groupLookupError.Exception.Message -like "*429*" -or $groupLookupError.Exception.Message -like "*TooManyRequests*") {
            Write-RjRbLog -Message "WARNING: Request for members of group '$GroupName' was throttled by Microsoft Graph (429). Re-run the report to retry. Detail: $($groupLookupError.Exception.Message)" -Verbose
        }
        elseif ($groupLookupError.Exception.Message -like "*403*" -or $groupLookupError.Exception.Message -like "*Forbidden*") {
            Write-RjRbLog -Message "WARNING: Access denied retrieving members of group '$GroupName'. Grant the Group.Read.All and GroupMember.Read.All application permissions to the Automation Account's managed identity. Detail: $($groupLookupError.Exception.Message)" -Verbose
        }
        else {
            Write-RjRbLog -Message "WARNING: Failed to retrieve members from group '$GroupName': $($groupLookupError.Exception.Message)" -Verbose
        }
    }
}

# Validate that we have at least one user
if ($targetUsers.Count -eq 0) {
    Write-Error "No users to evaluate. Please select at least one user or provide a group." -ErrorAction Continue
    throw "No target users specified or resolved"
}

Write-Output "Resolved $($targetUsers.Count) user(s) for evaluation"
if ($targetUsers.Count -gt 100) {
    Write-RjRbLog -Message "Note: Evaluating a large number of users may take several minutes." -Verbose
}

Write-Output ""
Write-Output "## Tenant enrollment context"
Write-Output "---------------------"

# Collect tenant-level Intune context
try {
    $skusUri = "https://graph.microsoft.com/v1.0/subscribedSkus?`$select=skuId,skuPartNumber,servicePlans"
    $tenantSkus = Get-GraphPagedResult -Uri $skusUri

    # Derive Intune-capable SKU IDs
    [System.Collections.Generic.List[string]]$intuneCapableSkuIds = @()
    $intuneSkuPartNumbers = @()

    foreach ($sku in $tenantSkus) {
        if ($sku.servicePlans) {
            $hasIntunePlan = $sku.servicePlans | Where-Object { $_.servicePlanName -like "INTUNE*" }
            if ($hasIntunePlan) {
                [void]$intuneCapableSkuIds.Add($sku.skuId)
                $intuneSkuPartNumbers += $sku.skuPartNumber
            }
        }
    }

    Write-Output "Found Intune-capable licenses: $($intuneSkuPartNumbers -join ', ')"
}
catch {
    # Non-fatal: license readiness will show as unknown for all users, but the rest of the report still runs.
    $skuError = $_
    if ($skuError.Exception.Message -like "*403*" -or $skuError.Exception.Message -like "*Forbidden*") {
        Write-RjRbLog -Message "WARNING: Access denied retrieving subscribed SKUs. Grant the User.Read.All application permission to the Automation Account's managed identity. License readiness will be reported as unknown for all users. Detail: $($skuError.Exception.Message)" -Verbose
    }
    elseif ($skuError.Exception.Message -like "*429*" -or $skuError.Exception.Message -like "*TooManyRequests*") {
        Write-RjRbLog -Message "WARNING: Request for subscribed SKUs was throttled by Microsoft Graph (429). License readiness will be reported as unknown for all users; re-run the report to retry. Detail: $($skuError.Exception.Message)" -Verbose
    }
    else {
        Write-RjRbLog -Message "WARNING: Failed to retrieve tenant subscribed SKUs: $($skuError.Exception.Message)" -Verbose
    }
    $tenantSkus = @()
    [System.Collections.Generic.List[string]]$intuneCapableSkuIds = @()
}

# Collect enrollment configurations
try {
    $enrollmentUri = "https://graph.microsoft.com/v1.0/deviceManagement/deviceEnrollmentConfigurations?`$expand=assignments"
    $allEnrollmentConfigs = Get-GraphPagedResult -Uri $enrollmentUri

    $enrollmentLimitConfigs = @($allEnrollmentConfigs | Where-Object { $_.'@odata.type' -like "*deviceEnrollmentLimitConfiguration" } | Sort-Object -Property priority)
    $platformRestrictionConfigs = @($allEnrollmentConfigs | Where-Object { $_.'@odata.type' -like "*deviceEnrollmentPlatformRestriction*" } | Sort-Object -Property priority)

    Write-Output "Found $($enrollmentLimitConfigs.Count) enrollment limit configuration(s)"
    Write-Output "Found $($platformRestrictionConfigs.Count) platform restriction configuration(s)"
}
catch {
    # Non-fatal: enrollment limit/platform-restriction readiness will show as unknown for all users.
    $enrollmentConfigError = $_
    if ($enrollmentConfigError.Exception.Message -like "*403*" -or $enrollmentConfigError.Exception.Message -like "*Forbidden*") {
        Write-RjRbLog -Message "WARNING: Access denied retrieving device enrollment configurations. Grant the DeviceManagementServiceConfig.Read.All application permission to the Automation Account's managed identity. Detail: $($enrollmentConfigError.Exception.Message)" -Verbose
    }
    elseif ($enrollmentConfigError.Exception.Message -like "*429*" -or $enrollmentConfigError.Exception.Message -like "*TooManyRequests*") {
        Write-RjRbLog -Message "WARNING: Request for enrollment configurations was throttled by Microsoft Graph (429). Re-run the report to retry. Detail: $($enrollmentConfigError.Exception.Message)" -Verbose
    }
    else {
        Write-RjRbLog -Message "WARNING: Failed to retrieve enrollment configurations: $($enrollmentConfigError.Exception.Message)" -Verbose
    }
    $enrollmentLimitConfigs = @()
    $platformRestrictionConfigs = @()
}

# Collect Conditional Access policies
try {
    $caUri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
    $allCaPolicies = Get-GraphPagedResult -Uri $caUri

    $caPolicies = @($allCaPolicies | Where-Object { $_.state -eq 'enabled' })
    Write-Output "Found $($caPolicies.Count) enabled Conditional Access policy(ies)"
}
catch {
    # Non-fatal: Conditional Access readiness will show as unknown for all users.
    $caError = $_
    if ($caError.Exception.Message -like "*403*" -or $caError.Exception.Message -like "*Forbidden*") {
        Write-RjRbLog -Message "WARNING: Access denied retrieving Conditional Access policies. Grant the Policy.Read.All application permission to the Automation Account's managed identity. Detail: $($caError.Exception.Message)" -Verbose
    }
    elseif ($caError.Exception.Message -like "*429*" -or $caError.Exception.Message -like "*TooManyRequests*") {
        Write-RjRbLog -Message "WARNING: Request for Conditional Access policies was throttled by Microsoft Graph (429). Re-run the report to retry. Detail: $($caError.Exception.Message)" -Verbose
    }
    else {
        Write-RjRbLog -Message "WARNING: Failed to retrieve Conditional Access policies: $($caError.Exception.Message)" -Verbose
    }
    $caPolicies = @()
}

# Retrieve MDM authority
try {
    # mobileDeviceManagementAuthority is only returned by the SINGLE-ENTITY form of /organization.
    # Verified live against a tenant:
    # - GET /organization?$select=...,mobileDeviceManagementAuthority returns HTTP 400 on BOTH v1.0 and
    #   beta - Graph rewrites the collection $select into an invalid internal "id in (...)" filter;
    # - GET /organization without $select returns 200 but omits the property entirely;
    # - GET /organization/{tenantId}?$select=... returns 200 with the value, on v1.0 as well as beta.
    # So v1.0 is used (no beta dependency) and the tenant ID is taken from the property-less collection
    # read, which is the one form of the call that always works. Get-MgContext is only a fast path:
    # relying on it alone previously produced "MDM authority could not be determined" for every user.
    $tenantId = $null
    try {
        $tenantId = [string](Get-MgContext).TenantId
    }
    catch {
        Write-RjRbLog -Message "Graph context did not yield a tenant ID; resolving it from /organization instead: $($_.Exception.Message)" -Verbose
    }

    if ([string]::IsNullOrWhiteSpace($tenantId)) {
        $collectionResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=id" -Method GET -ErrorAction Stop
        $tenantId = [string](@($collectionResult.value) | Select-Object -First 1).id
    }

    if ([string]::IsNullOrWhiteSpace($tenantId)) {
        throw "The tenant ID could not be resolved from the Graph context or from /organization."
    }

    $orgResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization/$tenantId`?`$select=id,displayName,mobileDeviceManagementAuthority" -Method GET -ErrorAction Stop
    $mdmAuthorityValue = [string]$orgResult.mobileDeviceManagementAuthority

    # Graph returns these values lower-cased ("intune"); switch is case-insensitive, so both spellings
    # are covered by the same labels.
    switch ($mdmAuthorityValue) {
        "intune" { $mdmAuthority = "Intune" }
        "GDPRDataProcessorServiceForMicrosoft365" { $mdmAuthority = "GDPR Data Processor (Intune)" }
        "sccm" { $mdmAuthority = "Configuration Manager (co-management)" }
        "office365" { $mdmAuthority = "Office 365 (Legacy)" }
        "unknown" { $mdmAuthority = "Not set" }
        default { $mdmAuthority = if ($mdmAuthorityValue) { $mdmAuthorityValue } else { "Not set" } }
    }

    Write-Output "MDM Authority: $mdmAuthority"
}
catch {
    # Non-fatal: MDM authority is reported as "Unknown" and the rest of the report still runs.
    $mdmError = $_
    if ($mdmError.Exception.Message -like "*403*" -or $mdmError.Exception.Message -like "*Forbidden*") {
        Write-RjRbLog -Message "WARNING: Access denied retrieving the organization's MDM authority. Grant the Organization.Read.All application permission to the Automation Account's managed identity. Detail: $($mdmError.Exception.Message)" -Verbose
    }
    elseif ($mdmError.Exception.Message -like "*429*" -or $mdmError.Exception.Message -like "*TooManyRequests*") {
        Write-RjRbLog -Message "WARNING: Request for the organization's MDM authority was throttled by Microsoft Graph (429). Re-run the report to retry. Detail: $($mdmError.Exception.Message)" -Verbose
    }
    else {
        Write-RjRbLog -Message "WARNING: Failed to retrieve organization MDM authority: $($mdmError.Exception.Message)" -Verbose
    }
    $mdmAuthority = "Unknown"
}

# Resolve pilot group if requested
$pilotGroupId = $null
[System.Collections.Generic.HashSet[string]]$pilotMemberIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$pilotMembersResolved = $false

if ($CheckPilotGroupMembership -and $PilotGroupDisplayName) {
    try {
        # Escape single quotes in the filter value for OData
        $escapedGroupName = $PilotGroupDisplayName -replace "'", "''"
        $groupSearchUri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$escapedGroupName'&`$select=id,displayName"
        $groupResult = Invoke-MgGraphRequest -Uri $groupSearchUri -Method GET -ErrorAction Stop

        if ($groupResult.value.Count -eq 0) {
            Write-RjRbLog -Message "WARNING: Pilot group '$PilotGroupDisplayName' not found" -Verbose
        }
        elseif ($groupResult.value.Count -gt 1) {
            Write-RjRbLog -Message "WARNING: Multiple groups match display name '$PilotGroupDisplayName'; using first match" -Verbose
            $pilotGroupId = $groupResult.value[0].id
        }
        else {
            $pilotGroupId = $groupResult.value[0].id
            Write-Output "Resolved pilot group: $($groupResult.value[0].displayName)"

            # Retrieve pilot group member IDs
            $pilotMembersUri = "https://graph.microsoft.com/v1.0/groups/$pilotGroupId/transitiveMembers/microsoft.graph.user?`$select=id"
            $pilotMembers = Get-GraphPagedResult -Uri $pilotMembersUri

            foreach ($member in $pilotMembers) {
                [void]$pilotMemberIds.Add($member.id)
            }

            # Mark pilot membership as successfully resolved only after member enumeration completes
            $pilotMembersResolved = $true
            Write-Output "Pilot group has $($pilotMemberIds.Count) member(s)"
        }
    }
    catch {
        # Non-fatal: pilot group membership will show as unknown for all users; the rest of the report still runs.
        # $pilotMembersResolved remains $false
        $pilotGroupError = $_
        if ($pilotGroupError.Exception.Message -like "*403*" -or $pilotGroupError.Exception.Message -like "*Forbidden*") {
            Write-RjRbLog -Message "WARNING: Access denied resolving pilot group '$PilotGroupDisplayName'. Grant the Group.Read.All and GroupMember.Read.All application permissions to the Automation Account's managed identity. Detail: $($pilotGroupError.Exception.Message)" -Verbose
        }
        elseif ($pilotGroupError.Exception.Message -like "*429*" -or $pilotGroupError.Exception.Message -like "*TooManyRequests*") {
            Write-RjRbLog -Message "WARNING: Request for pilot group '$PilotGroupDisplayName' was throttled by Microsoft Graph (429). Re-run the report to retry. Detail: $($pilotGroupError.Exception.Message)" -Verbose
        }
        else {
            Write-RjRbLog -Message "WARNING: Failed to resolve pilot group '$PilotGroupDisplayName': $($pilotGroupError.Exception.Message). The value entered may no longer match a group display name in the tenant." -Verbose
        }
    }
}

Write-Output ""
Write-Output "## Collecting per-user data"
Write-Output "---------------------"

# Initialize hashtables for per-user data
$userAuthMethods = @{}
$userDeviceCounts = @{}

$userCounter = 0
foreach ($user in $targetUsers) {
    $userCounter++

    if ($userCounter % 25 -eq 0) {
        Write-RjRbLog -Message "Processing user $userCounter of $($targetUsers.Count)..." -Verbose
    }

    # Collect authentication methods
    try {
        $authUri = "https://graph.microsoft.com/v1.0/users/$($user.id)/authentication/methods"
        $authMethodsResult = Invoke-MgGraphRequest -Uri $authUri -Method GET -ErrorAction Stop

        if ($authMethodsResult.value) {
            # Keep the full method objects, not just their @odata.type: the authentication-strength
            # evaluation needs deviceTag, phoneType and isUsableOnce to map a registration onto the
            # authenticationMethodModes vocabulary that allowedCombinations uses.
            $userAuthMethods[$user.id] = @($authMethodsResult.value)
        }
        else {
            $userAuthMethods[$user.id] = $null
        }
    }
    catch {
        # Non-fatal: this single user's authentication-method readiness is recorded as unknown; the report continues.
        $authError = $_
        if ($authError.Exception.Message -like "*403*" -or $authError.Exception.Message -like "*Forbidden*") {
            Write-RjRbLog -Message "WARNING: Access denied retrieving authentication methods for user '$($user.userPrincipalName)'. Grant the UserAuthenticationMethod.Read.All application permission to the Automation Account's managed identity. Recorded as unknown. Detail: $($authError.Exception.Message)" -Verbose
        }
        elseif ($authError.Exception.Message -like "*429*" -or $authError.Exception.Message -like "*TooManyRequests*") {
            Write-RjRbLog -Message "WARNING: Request for authentication methods of user '$($user.userPrincipalName)' was throttled by Microsoft Graph (429). Recorded as unknown; re-run the report to retry. Detail: $($authError.Exception.Message)" -Verbose
        }
        elseif ($authError.Exception.Message -like "*404*" -or $authError.Exception.Message -like "*Request_ResourceNotFound*") {
            Write-RjRbLog -Message "WARNING: User '$($user.userPrincipalName)' was not found when retrieving authentication methods; the account may have been deleted since the report started. Recorded as unknown." -Verbose
        }
        else {
            Write-RjRbLog -Message "WARNING: Failed to retrieve authentication methods for user '$($user.userPrincipalName)': $($authError.Exception.Message)" -Verbose
        }
        $userAuthMethods[$user.id] = $null
    }

    # Collect device count
    try {
        $deviceCountUri = "https://graph.microsoft.com/v1.0/users/$($user.id)/ownedDevices?`$select=id"
        $ownedDevicesResult = Invoke-MgGraphRequest -Uri $deviceCountUri -Method GET -ErrorAction Stop

        if ($ownedDevicesResult.value) {
            $userDeviceCounts[$user.id] = @($ownedDevicesResult.value).Count
        }
        else {
            $userDeviceCounts[$user.id] = 0
        }
    }
    catch {
        # Non-fatal: this single user's device count is recorded as unknown; the report continues.
        $deviceError = $_
        if ($deviceError.Exception.Message -like "*403*" -or $deviceError.Exception.Message -like "*Forbidden*") {
            Write-RjRbLog -Message "WARNING: Access denied retrieving owned devices for user '$($user.userPrincipalName)'. Grant the Directory.Read.All application permission to the Automation Account's managed identity. Recorded as unknown. Detail: $($deviceError.Exception.Message)" -Verbose
        }
        elseif ($deviceError.Exception.Message -like "*429*" -or $deviceError.Exception.Message -like "*TooManyRequests*") {
            Write-RjRbLog -Message "WARNING: Request for owned devices of user '$($user.userPrincipalName)' was throttled by Microsoft Graph (429). Recorded as unknown; re-run the report to retry. Detail: $($deviceError.Exception.Message)" -Verbose
        }
        elseif ($deviceError.Exception.Message -like "*404*" -or $deviceError.Exception.Message -like "*Request_ResourceNotFound*") {
            Write-RjRbLog -Message "WARNING: User '$($user.userPrincipalName)' was not found when retrieving owned devices; the account may have been deleted since the report started. Recorded as unknown." -Verbose
        }
        else {
            Write-RjRbLog -Message "WARNING: Failed to retrieve owned device count for user '$($user.userPrincipalName)': $($authError.Exception.Message)" -Verbose
        }
        $userDeviceCounts[$user.id] = $null
    }
}

Write-Output "Collected authentication and device data for $($targetUsers.Count) user(s)"
#endregion Data Collection

########################################################
#region     Data Processing
########################################################
Write-RjRbLog -Message "Processing enrollment readiness evaluation..." -Verbose

# Build a mapping of Intune-specific service plan IDs from SKUs for license validation
$intuneServicePlanIds = @()
foreach ($sku in $tenantSkus) {
    foreach ($plan in $sku.servicePlans) {
        if ($plan.servicePlanName -like "INTUNE*") {
            $intuneServicePlanIds += [string]$plan.servicePlanId
        }
    }
}
$intuneServicePlanIds = @($intuneServicePlanIds | Sort-Object -Unique)

# Caches for user group memberships and directory roles, to avoid repeated Graph calls (keyed by user.id).
# Both feed the Conditional Access assignment-scope evaluation.
$userGroupCache = @{}
$userRoleCache = @{}

# Track blocking reasons for summary statistics. Categories come from the Conditional Access assessment
# at runtime, so the counter is initialised on first use rather than from a fixed list.
$blockingReasonCounts = @{}

# Platform enumeration for Conditional Access evaluation
$platformMap = [ordered]@{ 'Windows' = 'windows'; 'iOS' = 'iOS'; 'Android' = 'android'; 'macOS' = 'macOS' }
$platformsToCheck = if ($EnrollmentPlatform -eq 'All') { @($platformMap.Keys | ForEach-Object { [string]$_ }) } else { @($EnrollmentPlatform) }

# Build per-user readiness assessment
$reportRows = @()

foreach ($user in $targetUsers) {
    # Compute platform-neutral blockers/warnings ONCE per user
    $neutralBlockingReasons = @()
    $neutralWarnings = @()
    $permittedPlatforms = @()

    # 1. Check account enabled
    if ($user.accountEnabled -ne $true) {
        $neutralBlockingReasons += "Account disabled"
        $blockingReasonCounts["Account disabled"] += 1
    }

    # 2. Check Intune license and resolve SKU part numbers
    $intuneLicensed = $false
    $intuneLicenseNames = @()
    $intuneServicePlanDisabled = $false

    if ($user.assignedLicenses -and $user.assignedLicenses.Count -gt 0) {
        foreach ($assignedSku in $user.assignedLicenses) {
            if ($assignedSku.skuId -in $intuneCapableSkuIds) {
                # Check if this SKU's Intune service plan is disabled
                if ($assignedSku.disabledPlans -and $assignedSku.disabledPlans.Count -gt 0) {
                    # Cross-reference disabledPlans GUIDs against Intune service plan IDs
                    $disabledIntuneServiceIds = @($assignedSku.disabledPlans | Where-Object { [string]$_ -in $intuneServicePlanIds })
                    if ($disabledIntuneServiceIds.Count -gt 0) {
                        # This SKU has Intune capability but its Intune plan is disabled
                        $intuneServicePlanDisabled = $true
                        continue
                    }
                }

                # The SKU is Intune-capable and the Intune plan is not disabled
                $intuneLicensed = $true

                # Resolve SKU part number
                $skuObj = $tenantSkus | Where-Object { $_.skuId -eq $assignedSku.skuId } | Select-Object -First 1
                if ($skuObj) {
                    $intuneLicenseNames += $skuObj.skuPartNumber
                }
            }
        }
    }

    if (-not $intuneLicensed) {
        if ($user.assignedLicenses.Count -eq 0) {
            $neutralBlockingReasons += "No Intune-capable license assigned"
            $blockingReasonCounts["No Intune-capable license assigned"] += 1
        }
        elseif ($intuneServicePlanDisabled) {
            $neutralBlockingReasons += "Intune service plan disabled on assigned licence"
            $blockingReasonCounts["Intune service plan disabled on assigned licence"] += 1
        }
        else {
            $neutralBlockingReasons += "No Intune-capable license assigned"
            $blockingReasonCounts["No Intune-capable license assigned"] += 1
        }
    }

    # 3. Check MDM authority. This is a TENANT-WIDE fact, and the two cases are treated differently on
    # purpose:
    # - INDETERMINATE (the read failed): reported once against the tenant in the summary below and
    #   deliberately NOT repeated per user. Attaching it to every row buried the users who actually had
    #   an individual problem, which is exactly what made the previous report unreadable.
    # - GENUINELY NOT INTUNE: kept as a per-user blocking reason, because it really does block every one
    #   of these users from enrolling. Suppressing it per row would let a user show as "Ready" while the
    #   tenant makes enrollment impossible. The user runbook reaches the same verdict for the same reason.
    if ([string]::IsNullOrEmpty($mdmAuthority) -or $mdmAuthority -eq "Unknown") {
        # No per-user finding on purpose - see the tenant-wide notice in the summary.
    }
    elseif ($mdmAuthority -notlike "Intune*" -and $mdmAuthority -ne "Office 365 (Legacy)" -and $mdmAuthority -notlike "*co-management*") {
        $neutralBlockingReasons += "MDM Authority not set to Intune"
        $blockingReasonCounts["MDM Authority not set to Intune"] += 1
    }

    # 4. Check device enrollment limit
    $deviceCount = $userDeviceCounts[$user.id]
    $enrollmentLimitValue = $null

    if ($enrollmentLimitConfigs -and $enrollmentLimitConfigs.Count -gt 0) {
        # Select by priority: highest > 0, else priority 0 default
        $priorityOrderedConfigs = @($enrollmentLimitConfigs | Sort-Object -Property priority -Descending)

        # First try any assigned config with priority > 0
        $applicableConfig = $priorityOrderedConfigs | Where-Object { $_.priority -gt 0 } | Select-Object -First 1

        # Fall back to priority 0 default
        if (-not $applicableConfig) {
            $applicableConfig = $priorityOrderedConfigs | Where-Object { $_.priority -eq 0 } | Select-Object -First 1
        }

        # Only use non-null limits; zero is a valid "block all" value
        if ($applicableConfig -and $null -ne $applicableConfig.limit) {
            $enrollmentLimitValue = $applicableConfig.limit
        }
    }

    if ($null -ne $deviceCount) {
        if ($null -ne $enrollmentLimitValue -and $deviceCount -ge $enrollmentLimitValue) {
            $neutralBlockingReasons += "Device enrollment limit reached ($deviceCount/$enrollmentLimitValue)"
            $blockingReasonCounts["Device enrollment limit reached"] += 1
        }
    }
    else {
        $neutralWarnings += "Device count unknown"
    }

    # 5. Check platform restrictions
    $defaultPlatformConfig = $platformRestrictionConfigs | Where-Object { $_.priority -eq 0 } | Select-Object -First 1
    $assignedPlatformConfigCount = @($platformRestrictionConfigs | Where-Object { $_.priority -gt 0 }).Count

    if (-not $defaultPlatformConfig) {
        $neutralWarnings += "Platform restrictions could not be determined"
    }
    else {
        $blockedPlatforms = @()
        $allowedPlatforms = @()
        # These are the platform properties Graph actually exposes on a platform-restrictions configuration.
        # 'androidForWorkRestriction' and 'macRestriction' do not exist on this type - reading them would
        # silently contribute nothing - and 'windowsMobileRestriction' is real and must not be missed.
        foreach ($platformProperty in @('windowsRestriction', 'windowsMobileRestriction', 'iosRestriction', 'androidRestriction', 'macOSRestriction')) {
            $restriction = $defaultPlatformConfig.$platformProperty
            if (-not $restriction) { continue }
            $platformLabel = $platformProperty -replace 'Restriction$', ''
            if ($restriction.platformBlocked -eq $true) {
                $blockedPlatforms += $platformLabel
            }
            else {
                $allowedPlatforms += $platformLabel
            }
        }

        if ($allowedPlatforms.Count -eq 0) {
            $neutralBlockingReasons += "All enrollment platforms are blocked by default restriction"
            $blockingReasonCounts["All enrollment platforms are blocked"] += 1
        }
        else {
            $permittedPlatforms = $allowedPlatforms -join ", "
            if ($assignedPlatformConfigCount -gt 0) {
                $neutralWarnings += "Group-assigned platform restrictions may override the default for this user"
            }
        }
    }

    # 6. Check authentication methods
    $authMethods = $userAuthMethods[$user.id]
    $authMethodsKnown = ($null -ne $authMethods)

    # Translate the registered methods into the authenticationMethodModes vocabulary that
    # authentication-strength allowedCombinations use, so strengths can actually be evaluated.
    $registeredModeNames = @(Get-RegisteredAuthCombinationNames -AuthenticationMethods $authMethods)
    $userHasMfa = Test-MfaCapableMethod -RegisteredCombinationNames $registeredModeNames

    $mfaCapableAuthMethods = @($registeredModeNames | Where-Object { $_ -ne 'password' } | Sort-Object)
    $userMethodText = if ($registeredModeNames.Count -gt 0) { ($registeredModeNames | Sort-Object) -join ", " } else { "none" }

    # An unreadable set of authentication methods makes every MFA/strength verdict unreliable
    if (-not $authMethodsKnown -and $caPolicies.Count -gt 0) {
        $neutralWarnings += "Authentication methods could not be read - Conditional Access MFA requirements were not fully evaluated"
    }

    # 7. Determine pilot group membership
    # When $CheckPilotGroupMembership is enabled, pilot group membership is a blocker, not just a column.
    $inPilotGroup = if ($pilotMembersResolved) {
        $pilotMemberIds.Contains($user.id)
    }
    else {
        "Unknown"
    }

    if ($CheckPilotGroupMembership -eq $true) {
        if ($pilotMembersResolved) {
            # Pilot group membership was resolved; check if user is a member
            if (-not $pilotMemberIds.Contains($user.id)) {
                $neutralBlockingReasons += "Not a member of pilot group '$PilotGroupDisplayName'"
                $blockingReasonCounts["Not a member of the pilot group"] += 1
            }
        }
        else {
            # Pilot group membership could not be resolved; add a warning
            $neutralWarnings += "Pilot group membership could not be verified (group '$PilotGroupDisplayName' not resolved)"
        }
    }

    # Group memberships and directory roles are needed to resolve CA assignment scope. Resolve each
    # once per user and cache it: a tenant with many policies would otherwise re-query per policy.
    if (-not $userGroupCache.ContainsKey($user.id)) {
        try {
            $memberOfResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($user.id)/transitiveMemberOf/microsoft.graph.group?`$select=id&`$top=999" -Method GET -ErrorAction Stop
            $userGroupCache[$user.id] = @($memberOfResult.value | ForEach-Object { [string]$_.id })
        }
        catch {
            $userGroupCache[$user.id] = @()
            Write-RjRbLog -Message "WARNING: Could not resolve group memberships for user '$($user.userPrincipalName)' when evaluating Conditional Access; policy scoping for this user may be incomplete: $($_.Exception.Message)" -Verbose
        }
    }
    $userGroupIds = @($userGroupCache[$user.id])

    if (-not $userRoleCache.ContainsKey($user.id)) {
        try {
            $roleResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($user.id)/transitiveMemberOf/microsoft.graph.directoryRole?`$select=roleTemplateId&`$top=999" -Method GET -ErrorAction Stop
            $userRoleCache[$user.id] = @($roleResult.value | ForEach-Object { [string]$_.roleTemplateId } | Where-Object { $_ })
        }
        catch {
            $userRoleCache[$user.id] = @()
            Write-RjRbLog -Message "WARNING: Could not resolve directory roles for user '$($user.userPrincipalName)'; Conditional Access policies scoped to roles may be missed: $($_.Exception.Message)" -Verbose
        }
    }
    $userRoleTemplateIds = @($userRoleCache[$user.id])

    # Build display value for auth methods
    $authMethodDisplay = if ($mfaCapableAuthMethods.Count -gt 0) {
        $mfaCapableAuthMethods -join "; "
    }
    elseif (-not $authMethodsKnown) { "Unknown" }
    elseif ($registeredModeNames -contains 'password') { "Password only" }
    else { "None registered" }

    # Evaluate Conditional Access policies for EACH PLATFORM
    foreach ($platformKey in $platformsToCheck) {
        $blockingReasons = @($neutralBlockingReasons)  # Start with platform-neutral blockers
        $warnings = @($neutralWarnings)                # Start with platform-neutral warnings
        $caBlockingPolicies = @()

        # Evaluate Conditional Access policies against the enrollment sign-in ("What If"-style) for THIS PLATFORM
        $caFindings = [System.Collections.Generic.List[object]]::new()
        $caBlockingPolicies = @()

        foreach ($policy in $caPolicies) {
            $scope = Test-CaPolicyAppliesToEnrollment -Policy $policy -User $user -UserGroupIds $userGroupIds -UserRoleTemplateIds $userRoleTemplateIds -EnrollmentPlatform $platformMap[$platformKey]
            if (-not $scope.Applies) { continue }

            $policyName = if ([string]::IsNullOrWhiteSpace([string]$policy.displayName)) { "Unnamed policy ($($policy.id))" } else { [string]$policy.displayName }
            $assessment = Get-CaEnrollmentAssessment -Policy $policy -Scope $scope -RegisteredCombinationNames $registeredModeNames -HasMfaCapableMethod $userHasMfa -MethodText $userMethodText

            # Prefix category/policy if checking multiple platforms
            $categoryPrefix = if ($platformsToCheck.Count -gt 1) { "[$platformKey] " } else { "" }

            $caFindings.Add([PSCustomObject]@{
                PolicyName = $policyName
                Result     = $assessment.Result
                Category   = $assessment.Category
                Detail     = $assessment.Detail
            })

            if ($assessment.Result -eq 'Blocker') {
                $caBlockingPolicies += $policyName
                $blockingReasons += "$($categoryPrefix)$($assessment.Category): $policyName"
                $blockingReasonCounts["$($categoryPrefix)$($assessment.Category)"] += 1
            }
            elseif ($assessment.Result -eq 'Warning') {
                $warnings += "$($categoryPrefix)$($assessment.Category): $policyName"
            }
        }

        # Determine readiness status for THIS PLATFORM
        if ($blockingReasons.Count -gt 0) {
            $readinessStatus = "Not ready"
        }
        elseif ($warnings.Count -gt 0) {
            $readinessStatus = "Ready with warnings"
        }
        else {
            $readinessStatus = "Ready"
        }

        # Get CA relevant policy names for this platform
        $caRelevantPolicyNames = @($caFindings | ForEach-Object { $_.PolicyName })

        # Build the report row for THIS (user, platform) combination
        $reportRows += [PSCustomObject]@{
            DisplayName                = $user.displayName
            UserPrincipalName          = $user.userPrincipalName
            UserId                     = $user.id
            EnrollmentPlatform         = $platformKey
            AccountEnabled             = $user.accountEnabled
            IntuneLicensed             = $intuneLicensed
            IntuneLicenses             = if ($intuneLicenseNames.Count -gt 0) { $intuneLicenseNames -join "; " } else { "None" }
            MdmAuthority               = $mdmAuthority
            PermittedPlatforms         = if ([string]::IsNullOrEmpty($permittedPlatforms)) { "Not determined" } else { $permittedPlatforms }
            RegisteredDeviceCount      = if ($null -ne $deviceCount) { $deviceCount.ToString() } else { "Unknown" }
            DeviceEnrollmentLimit      = if ($enrollmentLimitValue) { $enrollmentLimitValue.ToString() } else { "Not configured" }
            MfaCapable                 = $userHasMfa
            RegisteredAuthMethods      = $authMethodDisplay
            BlockingPolicies           = if ($caBlockingPolicies.Count -gt 0) { $caBlockingPolicies -join "; " } else { "None" }
            CaPoliciesInEnrollmentPath = if ($caRelevantPolicyNames.Count -gt 0) { $caRelevantPolicyNames -join "; " } else { "None" }
            InPilotGroup               = $inPilotGroup
            ReadinessStatus            = $readinessStatus
            BlockingReasons            = if ($blockingReasons.Count -gt 0) { $blockingReasons -join "; " } else { "None" }
            Warnings                   = if ($warnings.Count -gt 0) { $warnings -join "; " } else { "None" }
            Department                 = if ([string]::IsNullOrEmpty($user.department)) { "Not set" } else { $user.department }
        }
    }
}

# Sort: "Not ready" first, then "Ready with warnings", then "Ready"; secondarily by DisplayName, tertiarily by EnrollmentPlatform
$reportRows = $reportRows | Sort-Object -Property `
    @{ Expression = {
        switch ($_.ReadinessStatus) {
            "Not ready" { 0 }
            "Ready with warnings" { 1 }
            "Ready" { 2 }
            default { 3 }
        }
    }}, DisplayName, EnrollmentPlatform

# Compute summary statistics
# IMPORTANT: $summaryStats must carry stable SCALAR values regardless of single/multiple platform branch,
# so downstream fragments can interpolate them reliably without rendering as System.Collections.Hashtable.
$platformCounts = @{}

if ($platformsToCheck.Count -eq 1) {
    # Single platform: compute counts once
    $readyCount = ($reportRows | Where-Object { $_.ReadinessStatus -eq "Ready" }).Count
    $readyWithWarningsCount = ($reportRows | Where-Object { $_.ReadinessStatus -eq "Ready with warnings" }).Count
    $notReadyCount = ($reportRows | Where-Object { $_.ReadinessStatus -eq "Not ready" }).Count
    $platformCounts[$platformsToCheck[0]] = @{
        Ready             = $readyCount
        ReadyWithWarnings = $readyWithWarningsCount
        NotReady          = $notReadyCount
    }
}
else {
    # Multiple platforms: group by platform and sum the totals
    $readyCount = 0
    $readyWithWarningsCount = 0
    $notReadyCount = 0
    foreach ($platform in $platformsToCheck) {
        $platformRows = @($reportRows | Where-Object { $_.EnrollmentPlatform -eq $platform })
        $pReady = ($platformRows | Where-Object { $_.ReadinessStatus -eq "Ready" }).Count
        $pReadyWithWarnings = ($platformRows | Where-Object { $_.ReadinessStatus -eq "Ready with warnings" }).Count
        $pNotReady = ($platformRows | Where-Object { $_.ReadinessStatus -eq "Not ready" }).Count

        $platformCounts[$platform] = @{
            Ready             = $pReady
            ReadyWithWarnings = $pReadyWithWarnings
            NotReady          = $pNotReady
        }

        $readyCount += $pReady
        $readyWithWarningsCount += $pReadyWithWarnings
        $notReadyCount += $pNotReady
    }
}

# Build top 5 blocking reasons
$topBlockingReasons = @()
$blockingReasonCounts.GetEnumerator() |
    Sort-Object -Property Value -Descending |
    Select-Object -First 5 |
    ForEach-Object {
        $topBlockingReasons += [PSCustomObject]@{
            Reason = $_.Key
            Count  = $_.Value
        }
    }

# Build PlatformBreakdown string: empty for single platform, semicolon-separated detail for multiple
$platformBreakdown = ""
if ($platformsToCheck.Count -gt 1) {
    $breakdownLines = @()
    foreach ($platform in $platformsToCheck) {
        $counts = $platformCounts[$platform]
        $breakdownLines += "$($platform): $($counts.Ready) ready, $($counts.ReadyWithWarnings) ready with warnings, $($counts.NotReady) not ready"
    }
    $platformBreakdown = $breakdownLines -join "; "
}

$summaryStats = @{
    TotalUsersChecked    = $reportRows.Count
    ReadyCount           = $readyCount
    ReadyWithWarningsCount = $readyWithWarningsCount
    NotReadyCount        = $notReadyCount
    PlatformBreakdown    = $platformBreakdown
    TopBlockingReasons   = $topBlockingReasons
}

# Output summary to console
Write-Output ""
Write-Output "## Enrollment Readiness Result"
Write-Output "---------------------"

if ($platformsToCheck.Count -eq 1) {
    Write-Output ("{0,-22}: {1}" -f "Users evaluated", $reportRows.Count)
    Write-Output ("{0,-22}: {1}" -f "Platform", $platformsToCheck[0])
    Write-Output ("{0,-22}: {1}" -f "Ready", $readyCount)
    Write-Output ("{0,-22}: {1}" -f "Ready with warnings", $readyWithWarningsCount)
    Write-Output ("{0,-22}: {1}" -f "Not ready", $notReadyCount)
}
else {
    Write-Output ("{0,-22}: {1}" -f "User/platform combinations evaluated", $reportRows.Count)
    Write-Output ""
    foreach ($platform in $platformsToCheck) {
        $counts = $platformCounts[$platform]
        Write-Output ("  {0,-20}: {1} ready, {2} ready with warnings, {3} not ready" -f $platform, $counts.Ready, $counts.ReadyWithWarnings, $counts.NotReady)
    }
}

# The MDM authority is a property of the tenant, not of a user, so it is reported once here rather than
# as a warning on every single row.
if ([string]::IsNullOrEmpty($mdmAuthority) -or $mdmAuthority -eq "Unknown") {
    Write-Output ""
    Write-Output "WARNING: The tenant MDM authority could not be determined. This affects the whole tenant, not individual users, and was therefore not counted against any user's readiness. Verify in the Intune admin center that the MDM authority is set to Intune."
}
else {
    Write-Output ""
    Write-Output ("{0,-22}: {1}" -f "Tenant MDM authority", $mdmAuthority)
}

if ($topBlockingReasons.Count -gt 0) {
    Write-Output ""
    Write-Output "## Top blocking reasons"
    Write-Output "---------------------"
    foreach ($reason in $topBlockingReasons) {
        Write-Output ("  - {0}: {1}" -f $reason.Reason, $reason.Count)
    }
}

# Output users not ready
$notReadyUsers = @($reportRows | Where-Object { $_.ReadinessStatus -eq "Not ready" })
if ($notReadyUsers.Count -gt 0) {
    Write-Output ""
    Write-Output ("## Not ready ({0})" -f $notReadyUsers.Count)
    Write-Output "---------------------"

    $displayCount = [Math]::Min($notReadyUsers.Count, 50)
    for ($i = 0; $i -lt $displayCount; $i++) {
        $user = $notReadyUsers[$i]
        $platformLabel = if ($platformsToCheck.Count -gt 1) { " [$($user.EnrollmentPlatform)]" } else { "" }
        Write-Output ("  [X] {0} ({1}){2}" -f $user.DisplayName, $user.UserPrincipalName, $platformLabel)

        # Split blocking reasons and indent each one
        $reasons = @($user.BlockingReasons -split "; " | Where-Object { $_ -and $_.Trim() })
        foreach ($reason in $reasons) {
            Write-Output ("        {0}" -f $reason)
        }
    }

    if ($notReadyUsers.Count -gt 50) {
        $remainingCount = $notReadyUsers.Count - 50
        Write-Output "  ... and $remainingCount more (see report file for full list)"
    }
}

# Output users ready with warnings
$warningUsers = @($reportRows | Where-Object { $_.ReadinessStatus -eq "Ready with warnings" })
if ($warningUsers.Count -gt 0) {
    Write-Output ""
    Write-Output ("## Ready with warnings ({0})" -f $warningUsers.Count)
    Write-Output "---------------------"

    $displayCount = [Math]::Min($warningUsers.Count, 50)
    for ($i = 0; $i -lt $displayCount; $i++) {
        $user = $warningUsers[$i]
        $platformLabel = if ($platformsToCheck.Count -gt 1) { " [$($user.EnrollmentPlatform)]" } else { "" }
        Write-Output ("  [!] {0} ({1}){2}" -f $user.DisplayName, $user.UserPrincipalName, $platformLabel)

        # Split warnings and indent each one
        $warnings = @($user.Warnings -split "; " | Where-Object { $_ -and $_.Trim() })
        foreach ($warning in $warnings) {
            Write-Output ("        {0}" -f $warning)
        }
    }

    if ($warningUsers.Count -gt 50) {
        $remainingCount = $warningUsers.Count - 50
        Write-Output "  ... and $remainingCount more (see report file for full list)"
    }
}

# Check if all users are ready
if ($notReadyUsers.Count -eq 0 -and $warningUsers.Count -eq 0) {
    Write-Output ""
    if ($platformsToCheck.Count -eq 1) {
        Write-Output "All evaluated users are ready for enrollment."
    } else {
        Write-Output "All evaluated user/platform combinations are ready for enrollment."
    }
}

Write-RjRbLog -Message "Processed $($reportRows.Count) user/platform combination(s)" -Verbose
#endregion Data Processing

########################################################
#region     Report File Export
########################################################
$reportFiles = @()
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "IntuneEnrollmentReadiness_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

# Sanitise tenant display name for use in file paths (remove illegal characters)
$sanitizedTenantName = $tenantDisplayName -replace '[\\/:*?"<>|]', '' | ForEach-Object { $_ -replace '\s+', '_' }
if ([string]::IsNullOrWhiteSpace($sanitizedTenantName)) {
    $sanitizedTenantName = "Tenant"
}

if ($ReportFileFormat -ne 'XLSX only') {
    if ($reportRows.Count -gt 0) {
        $fileName = Join-Path $tempDir "intune-enrollment-readiness_$($sanitizedTenantName)_$(Get-Date -Format 'yyyyMMdd').csv"
        $reportRows | Export-Csv -Path $fileName -NoTypeInformation -Encoding UTF8
        $reportFiles += $fileName
        Write-RjRbLog -Message "Exported $($reportRows.Count) items to: $fileName" -Verbose
    }
    else {
        Write-Output "No data found - skipping CSV export"
    }
}

Write-Output "Report file export completed: $($reportFiles.Count) file(s) created"

if ($ReportFileFormat -ne 'CSV only') {
    if ($reportRows.Count -gt 0) {
        # $tenantDisplayName may contain characters that are illegal in file names (e.g. '/', '\', ':') - sanitise before use
        $sanitizedTenantName = $tenantDisplayName -replace '[\\/:*?"<>|]', '_'
        $xlsxFile = Join-Path $tempDir "intune-enrollment-readiness_$($sanitizedTenantName)_$(Get-Date -Format 'yyyyMMdd').xlsx"

        $notReadyRows = @($reportRows | Where-Object { $_.ReadinessStatus -eq 'Not ready' })

        $topBlockingReasonsText = if ($summaryStats.TopBlockingReasons -and $summaryStats.TopBlockingReasons.Count -gt 0) {
            ($summaryStats.TopBlockingReasons | ForEach-Object { "$($_.Reason) ($($_.Count))" }) -join '; '
        }
        else {
            'None'
        }

        $workbookCoverSheet = [ordered]@{
            Title                        = 'Intune Enrollment Readiness Report'
            Generated                    = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version'            = $Version
            Tenant                       = $tenantDisplayName
            'Total Users Checked'        = $summaryStats.TotalUsersChecked
            'Ready Count'                = $summaryStats.ReadyCount
            'Ready With Warnings Count'  = $summaryStats.ReadyWithWarningsCount
            'Not Ready Count'            = $summaryStats.NotReadyCount
            'Enrollment Platform'        = $EnrollmentPlatform
            'Top Blocking Reasons'       = $topBlockingReasonsText
        }
        if (-not [string]::IsNullOrEmpty($summaryStats.PlatformBreakdown)) {
            $workbookCoverSheet['Per Platform'] = $summaryStats.PlatformBreakdown
        }

        $xlsxWorksheets = [ordered]@{
            'All Users' = $reportRows
        }
        if ($notReadyRows.Count -gt 0) {
            $xlsxWorksheets['Not Ready'] = $notReadyRows
        }

        Export-RjRbXlsx -Worksheets $xlsxWorksheets `
            -Path $xlsxFile `
            -CoverSheet $workbookCoverSheet `
            -HighlightRules @(
                @{ Column = 'ReadinessStatus'; Value = 'Not ready'; Color = 'Red' }
                @{ Column = 'ReadinessStatus'; Value = 'Ready with warnings'; Color = 'Yellow' }
                @{ Column = 'ReadinessStatus'; Value = 'Ready'; Color = 'Green' }
            )

        $reportFiles += $xlsxFile
        Write-RjRbLog -Message "Exported $($reportRows.Count) items to: $xlsxFile" -Verbose
    }
    else {
        Write-Output "No data found - skipping XLSX export"
    }
}
#endregion Report File Export

########################################################
#region     Send Email Report
########################################################
if ($SendEmailReport) {
    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    $emailSubject = "Intune Enrollment Readiness - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"

    $topBlockingReasonsMarkdown = if ($summaryStats.TopBlockingReasons -and $summaryStats.TopBlockingReasons.Count -gt 0) {
        ($summaryStats.TopBlockingReasons | ForEach-Object { "- $($_.Reason): $($_.Count)" }) -join "`n"
    }
    else {
        "- No blocking reasons recorded"
    }

    # Build the summary bullet block once: the per-platform breakdown line is only present when the
    # runbook evaluated all platforms (PlatformBreakdown non-empty) - never emit a blank line otherwise.
    $summaryLines = @(
        "- Users checked: $($summaryStats.TotalUsersChecked)"
        "- Ready for enrollment: $($summaryStats.ReadyCount)"
        "- Ready with warnings: $($summaryStats.ReadyWithWarningsCount)"
        "- Not ready: $($summaryStats.NotReadyCount)"
    )
    if ($summaryStats.PlatformBreakdown) {
        $summaryLines += "- Per platform: $($summaryStats.PlatformBreakdown)"
    }
    $summaryLines += "- Enrollment platform evaluated: $EnrollmentPlatform"
    $summaryMarkdown = $summaryLines -join "`n"

    $markdownContent = @"
# Intune Enrollment Readiness Report

**Tenant:** $tenantDisplayName
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary

$summaryMarkdown

## Top blocking reasons

$topBlockingReasonsMarkdown

The full per-user results ($($reportRows.Count) rows) are attached to this email.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    $markdownFallbackXlsxOnly = @"
# Intune Enrollment Readiness Report

**Tenant:** $tenantDisplayName
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary

$summaryMarkdown

## Top blocking reasons

$topBlockingReasonsMarkdown

The full report was too large to attach in all requested formats; the Excel workbook is attached instead.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    try {
        $emailParams = @{
            EmailFrom         = $EmailFrom
            EmailTo           = $EmailTo
            Subject           = $emailSubject
            MarkdownContent   = $markdownContent
            TenantDisplayName = $tenantDisplayName
            ReportVersion     = $Version
        }

        if ($reportFiles.Count -eq 0) {
            Send-RjReportEmail @emailParams @brandingMailParams
        }
        elseif ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFile -and (Test-Path -Path $xlsxFile)) {
            # Both formats attached; fall back to the workbook alone if the pair is too large.
            Send-RjReportEmail @emailParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFile) -FallbackMarkdownContent $markdownFallbackXlsxOnly
        }
        else {
            Send-RjReportEmail @emailParams @brandingMailParams -Attachments $reportFiles
        }
    }
    catch {
        # The report files were already generated successfully at this point - only delivery by email
        # failed. Re-thrown so the run is flagged as failed, but the wording must not suggest data loss.
        $emailError = $_
        if ($emailError.Exception.Message -like "*403*" -or $emailError.Exception.Message -like "*Forbidden*") {
            Write-Error "The report was generated successfully, but sending it by email failed: access denied. Grant the Mail.Send application permission to the Automation Account's managed identity and re-run, or retrieve the report files directly. Detail: $($emailError.Exception.Message)" -ErrorAction Continue
        }
        else {
            Write-Error "The report was generated successfully, but sending it by email failed: $($emailError.Exception.Message). The report data itself is not lost - only delivery by email failed." -ErrorAction Continue
        }
        Write-RjRbLog -Message "Error sending email report (report files were generated successfully): $($emailError.Exception.Message)" -Verbose
        throw "Failed to send email report: $($emailError.Exception.Message)"
    }
}
#endregion Send Email Report

########################################################
#region     Cleanup
########################################################
try {
    Disconnect-MgGraph -ErrorAction Stop | Out-Null
}
catch {
    # Non-fatal: cleanup best-effort only. Reaching here typically just means there was no active
    # Graph session to close (e.g. the initial connect failed earlier and already threw).
    Write-RjRbLog -Message "Disconnect-MgGraph: no active Microsoft Graph session to disconnect, or disconnect failed: $($_.Exception.Message)" -Verbose
}

foreach ($reportFilePath in $reportFiles) {
    if ($reportFilePath -and (Test-Path -Path $reportFilePath)) {
        try {
            Remove-Item -Path $reportFilePath -Force -ErrorAction Stop
            Write-RjRbLog -Message "Removed temporary report file: $reportFilePath" -Verbose
        }
        catch {
            # Non-fatal: the report has already been generated (and delivered, if requested); a leftover
            # temp file only affects the Automation sandbox disk, not the report's correctness.
            Write-RjRbLog -Message "Failed to remove temporary report file '$reportFilePath': $($_.Exception.Message)" -Verbose
        }
    }
}

if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

Write-Output ""
Write-Output "Done!"
#endregion Cleanup

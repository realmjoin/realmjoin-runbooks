<#
    .SYNOPSIS
    Keep a group filled with users who registered a secure MFA method

    .DESCRIPTION
    Keeps an Entra ID group in sync with the users who registered at least one secure authentication method, such as a passkey or the Microsoft Authenticator app. Users who lose their secure method are removed. Admins, an exclusion group and individual users can be kept out, for example when the group controls self-service password reset. A dry run only shows the changes, and the report can be sent by email or provided as a download link. Details on the options are in the runbook documentation (docs.realmjoin.com).

    .PARAMETER TargetGroupId
    Group whose members are managed by this runbook. Members that no longer qualify are removed.

    .PARAMETER IncludePasskeys
    Passkeys and FIDO2 security keys, which are phishing-resistant, count as secure.

    .PARAMETER IncludePlatformCredentials
    Windows Hello for Business and macOS platform credentials count as secure.

    .PARAMETER IncludeMicrosoftAuthenticator
    The Microsoft Authenticator app, with push or passwordless sign-in, counts as secure.

    .PARAMETER IncludeSoftwareOtp
    Time-based one-time codes from authenticator apps count as secure.

    .PARAMETER IncludeHardwareOtp
    Hardware one-time password tokens count as secure.

    .PARAMETER IncludeCertificateBasedAuth
    Sign-in with a certificate, for example from a smart card, counts as secure.

    .PARAMETER SecureOnly
    Strict mode: users who also have a phone, email or security question method registered never qualify, even with a secure method.

    .PARAMETER SecureMethodsOverride
    Custom list of method names that count as secure, separated by commas. When set, the individual method switches are ignored. Preset in the runbook customization; the method names are listed in the runbook documentation.

    .PARAMETER UnsecureMethodsOverride
    Custom list of method names that count as unsecure in strict mode, separated by commas. Preset in the runbook customization.

    .PARAMETER ExcludeAdmins
    Users with an Entra ID directory role, active or eligible, never qualify and are removed from the group. Useful when the group drives self-service password reset.

    .PARAMETER ExcludeGroupId
    Members of this group, for example break glass or service accounts, never qualify and are removed from the target group. Leave empty for none.

    .PARAMETER ExcludeUserIds
    Users who never qualify and are removed from the target group. Several can be picked.

    .PARAMETER WhatIfMode
    Only logs which users would be added or removed without changing the group.

    .PARAMETER SendEmail
    Send the report by email after the run.

    .PARAMETER EmailTo
    Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

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

    .PARAMETER ReportFileFormat
    Deliver the report as CSV, as an Excel workbook, or both.

    .PARAMETER CreateDownloadLink
    Also upload the report and return a download link that expires after a few days.

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
            "TargetGroupId": {
                "DisplayName": "Target group"
            },
            "IncludePasskeys": {
                "DisplayName": "Passkeys and FIDO2 keys count as secure?"
            },
            "IncludePlatformCredentials": {
                "DisplayName": "Platform credentials count as secure?"
            },
            "IncludeMicrosoftAuthenticator": {
                "DisplayName": "Microsoft Authenticator counts as secure?"
            },
            "IncludeSoftwareOtp": {
                "DisplayName": "Software OTP counts as secure?"
            },
            "IncludeHardwareOtp": {
                "DisplayName": "Hardware OTP tokens count as secure?"
            },
            "IncludeCertificateBasedAuth": {
                "DisplayName": "Certificate-based auth counts as secure?"
            },
            "SecureOnly": {
                "DisplayName": "Strict mode?"
            },
            "SecureMethodsOverride": {
                "DisplayName": "Custom secure methods",
                "Hide": true
            },
            "UnsecureMethodsOverride": {
                "DisplayName": "Custom unsecure methods",
                "Hide": true
            },
            "ExcludeAdmins": {
                "DisplayName": "Exclude admins?"
            },
            "ExcludeGroupId": {
                "DisplayName": "Exclusion group"
            },
            "ExcludeUserIds": {
                "DisplayName": "Excluded users"
            },
            "WhatIfMode": {
                "DisplayName": "Dry run?"
            },
            "SendEmail": {
                "DisplayName": "Send report by email?",
                "Default": false,
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - send the report via email",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": ["EmailTo", "ReportFileFormat"],
                                "Mandatory": ["EmailTo"]
                            }
                        },
                        {
                            "Display": "No - do not send an email",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": ["EmailTo", "ReportFileFormat"]
                            }
                        }
                    ],
                    "ShowValue": false
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
            "CreateDownloadLink": {
                "DisplayName": "Create a download link?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - upload report and return a download link",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": ["ReportFileFormat"]
                            }
                        },
                        {
                            "Display": "No - do not create a download link",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": ["ReportFileFormat"]
                            }
                        }
                    ],
                    "ShowValue": false
                }
            },
            "ReportFileFormat": {
                "DisplayName": "Report file format",
                "Hide": true,
                "Select": {
                    "Options": [
                        {
                            "Display": "CSV & XLSX",
                            "ParameterValue": "CSV & XLSX"
                        },
                        {
                            "Display": "CSV only",
                            "ParameterValue": "CSV only"
                        },
                        {
                            "Display": "XLSX only",
                            "ParameterValue": "XLSX only"
                        }
                    ],
                    "ShowValue": false
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

# Suppress false positive from PSScriptAnalyzer - $idx is assigned in ForEach-Object -Begin and used in -Process block
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "idx")]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Target group" } )]
    [string]$TargetGroupId,

    [bool]$IncludePasskeys = $true,
    [bool]$IncludePlatformCredentials = $true,
    [bool]$IncludeMicrosoftAuthenticator = $true,
    [bool]$IncludeSoftwareOtp = $false,
    [bool]$IncludeHardwareOtp = $false,
    [bool]$IncludeCertificateBasedAuth = $true,

    [bool]$SecureOnly = $false,

    [string]$SecureMethodsOverride = "",

    [string]$UnsecureMethodsOverride = "",

    [bool]$ExcludeAdmins = $true,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclusion group" } )]
    [string]$ExcludeGroupId = "",

    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Excluded users" -Filter "userType eq 'Member'" } )]
    [string[]]$ExcludeUserIds = @(),

    [bool]$WhatIfMode = $false,

    [bool]$SendEmail = $false,

    [Parameter(Mandatory = $false)]
    [string]$EmailTo,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ })]
    [string]$EmailFrom,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ })]
    [string]$BrandingHeaderImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ })]
    [string]$BrandingFooterImageUrl,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ })]
    [string]$BrandingFooterLink,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" -Value $_ } )]
    [string]$BrandingAccentColor,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" -Value $_ } )]
    [string]$BrandingTextColor,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "sync-mfa-secure-users-to-group",

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
#region     RJ Log Part
########################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.5.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "TargetGroupId: $TargetGroupId" -Verbose
Write-RjRbLog -Message "IncludePasskeys: $IncludePasskeys" -Verbose
Write-RjRbLog -Message "IncludePlatformCredentials: $IncludePlatformCredentials" -Verbose
Write-RjRbLog -Message "IncludeMicrosoftAuthenticator: $IncludeMicrosoftAuthenticator" -Verbose
Write-RjRbLog -Message "IncludeSoftwareOtp: $IncludeSoftwareOtp" -Verbose
Write-RjRbLog -Message "IncludeHardwareOtp: $IncludeHardwareOtp" -Verbose
Write-RjRbLog -Message "IncludeCertificateBasedAuth: $IncludeCertificateBasedAuth" -Verbose
Write-RjRbLog -Message "SecureOnly: $SecureOnly" -Verbose
Write-RjRbLog -Message "SecureMethodsOverride: $SecureMethodsOverride" -Verbose
Write-RjRbLog -Message "UnsecureMethodsOverride: $UnsecureMethodsOverride" -Verbose
Write-RjRbLog -Message "ExcludeAdmins: $ExcludeAdmins" -Verbose
Write-RjRbLog -Message "ExcludeGroupId: $ExcludeGroupId" -Verbose
Write-RjRbLog -Message "ExcludeUserIds: $($ExcludeUserIds -join ', ')" -Verbose
Write-RjRbLog -Message "WhatIfMode: $WhatIfMode" -Verbose
Write-RjRbLog -Message "SendEmail: $SendEmail" -Verbose
if ($SendEmail) {
    Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
    Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
    Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
}
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
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

# Method group toggles and the methodsRegistered values they cover (see companion documentation)
$methodGroups = @(
    @{ Enabled = $IncludePasskeys; Methods = @("fido2SecurityKey", "passKeyDeviceBound", "passKeyDeviceBoundAuthenticator") }
    @{ Enabled = $IncludePlatformCredentials; Methods = @("windowsHelloForBusiness", "passKeyDeviceBoundWindowsHello", "macOsSecureEnclaveKey") }
    @{ Enabled = $IncludeMicrosoftAuthenticator; Methods = @("microsoftAuthenticatorPush", "microsoftAuthenticatorPasswordless") }
    @{ Enabled = $IncludeSoftwareOtp; Methods = @("softwareOneTimePasscode") }
    @{ Enabled = $IncludeHardwareOtp; Methods = @("hardwareOneTimePasscode") }
    @{ Enabled = $IncludeCertificateBasedAuth; Methods = @("certificateBasedAuthentication") }
)
$builtInUnsecureMethods = @("mobilePhone", "alternateMobilePhone", "officePhone", "email", "securityQuestion")
$knownMethods = @($methodGroups | ForEach-Object { $_.Methods }) + $builtInUnsecureMethods + @("temporaryAccessPass")

# Determine the secure method set - a filled override replaces all toggles
if (-not [string]::IsNullOrWhiteSpace($SecureMethodsOverride)) {
    $secureMethods = @($SecureMethodsOverride -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
    Write-Output "Secure methods override is set - method group toggles are ignored."
    foreach ($method in $secureMethods) {
        if ($method -notin $knownMethods) {
            Write-Output "Warning: '$method' is not a known methodsRegistered value. It will still be evaluated (future Graph values are allowed) - please check for typos."
        }
    }
}
else {
    $secureMethods = @($methodGroups | Where-Object { $_.Enabled } | ForEach-Object { $_.Methods })
}

if ($secureMethods.Count -eq 0) {
    Write-Error "No secure methods selected. Enable at least one method group toggle or provide a custom secure methods list - an empty secure set would remove all members from the target group." -ErrorAction Continue
    throw "No secure methods selected."
}

# Determine the unsecure method set - only relevant in strict mode
$unsecureMethods = @()
if ($SecureOnly) {
    if (-not [string]::IsNullOrWhiteSpace($UnsecureMethodsOverride)) {
        $unsecureMethods = @($UnsecureMethodsOverride -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
        Write-Output "Unsecure methods override is set - the built-in unsecure list is replaced."
        foreach ($method in $unsecureMethods) {
            if ($method -notin $knownMethods) {
                Write-Output "Warning: '$method' is not a known methodsRegistered value. It will still be evaluated (future Graph values are allowed) - please check for typos."
            }
        }
    }
    else {
        $unsecureMethods = $builtInUnsecureMethods
    }

    $overlap = @($secureMethods | Where-Object { $_ -in $unsecureMethods })
    if ($overlap.Count -gt 0) {
        Write-Output "Warning: The following methods are in both the secure and the unsecure set: $($overlap -join ', '). Unsecure wins - users with such a method never qualify in strict mode."
    }
}

$secureSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$secureMethods, [System.StringComparer]::OrdinalIgnoreCase)
$unsecureSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$unsecureMethods, [System.StringComparer]::OrdinalIgnoreCase)

# Validate email configuration (only if email is requested)
if ($SendEmail) {
    if (-not $EmailTo) {
        Write-Warning -Message "A recipient email address is required when the email report is enabled. Provide EmailTo or disable SendEmail." -Verbose
        throw "Missing recipient email address (EmailTo)."
    }
    if (-not $EmailFrom) {
        Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -Verbose
        throw "This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings"
    }
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

#endregion

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response. Uses a generic list to stay
        efficient for large tenants (tens of thousands of items across many pages).

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query.
    #>
    param(
        [string]$Uri
    )

    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri

    do {
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        if ($response.value) {
            $allResults.AddRange([object[]]@($response.value))
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $allResults
}

#endregion

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    throw
}

if ($SendEmail -or $CreateDownloadLink) {
    # Get tenant information for the report cover sheet and email
    $tenantInfo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method Get
    $TenantDisplayName = $tenantInfo.value[0].displayName
}

if ($SendEmail) {
    # Connect RJ RunbookHelper for email reporting
    Write-Output "Graph connection for RJ RunbookHelper..."
    Connect-RjRbGraph
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

# Validate target group exists
try {
    $targetGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$TargetGroupId`?`$select=id,displayName" -Method GET -ErrorAction Stop
    Write-RjRbLog -Message "Target Group:    $($targetGroup.displayName)" -Verbose
}
catch {
    Write-Error "Target group with ID '$TargetGroupId' was not found in Entra ID. Please verify the group exists." -ErrorAction Continue
    throw "Target group '$TargetGroupId' not found."
}

# Validate the exclusion group (optional) - it must exist and must not be the target group itself
$excludeGroup = $null
if (-not [string]::IsNullOrWhiteSpace($ExcludeGroupId)) {
    if ($ExcludeGroupId -eq $TargetGroupId) {
        Write-Error "The exclusion group must not be the target group itself - all members would be removed on every run." -ErrorAction Continue
        throw "Exclusion group equals target group."
    }
    try {
        $excludeGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$ExcludeGroupId`?`$select=id,displayName" -Method GET -ErrorAction Stop
        Write-RjRbLog -Message "Exclusion Group: $($excludeGroup.displayName)" -Verbose
    }
    catch {
        Write-Error "Exclusion group with ID '$ExcludeGroupId' was not found in Entra ID. Please verify the group exists." -ErrorAction Continue
        throw "Exclusion group '$ExcludeGroupId' not found."
    }
}

# Resolve the individually excluded users (optional) - accepts object IDs and UPNs. Unresolvable
# entries only produce a warning so a deleted account never breaks a scheduled sync.
$excludeUsers = @()
$excludeUserInputs = @($ExcludeUserIds | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Select-Object -Unique)
if ($excludeUserInputs.Count -gt 0) {
    $excludeUserProbeRequests = @($excludeUserInputs | ForEach-Object -Begin { $idx = 1 } -Process {
            @{
                id     = "$idx"
                method = "GET"
                url    = "/users/$([uri]::EscapeDataString($_))?`$select=id,userPrincipalName"
            }
            $idx++
        })
    $excludeUserProbeResponses = Invoke-RjRbGraphBatch -Requests $excludeUserProbeRequests -ProgressLabel "excluded user lookups"

    $resolvedExcludeUsers = [System.Collections.Generic.List[object]]::new()
    foreach ($response in $excludeUserProbeResponses) {
        if ($response.status -eq 200 -and $response.body.id) {
            $resolvedExcludeUsers.Add([PSCustomObject]@{ id = $response.body.id; userPrincipalName = $response.body.userPrincipalName })
        }
        else {
            $reqIdx = [int]$response.id - 1
            $inputValue = if ($reqIdx -ge 0 -and $reqIdx -lt $excludeUserInputs.Count) { $excludeUserInputs[$reqIdx] } else { "unknown" }
            Write-Output "Warning: Excluded user '$inputValue' could not be resolved (status $($response.status)) - the entry is ignored. Please verify the user ID / UPN."
        }
    }
    # Sort for stable output and deduplicate (the same user could be listed by ID and by UPN)
    $excludeUsers = @($resolvedExcludeUsers | Sort-Object userPrincipalName -Unique)
}

Write-Output ""
Write-Output "Configuration"
Write-Output "---------------------"
Write-Output "Target Group:     $($targetGroup.displayName)"
Write-Output "Secure methods:   $($secureMethods -join ', ')"
Write-Output "Strict mode:      $SecureOnly"
if ($SecureOnly) {
    Write-Output "Unsecure methods: $($unsecureMethods -join ', ')"
}
Write-Output "Exclude admins:   $ExcludeAdmins"
Write-Output "Exclusion group:  $(if ($excludeGroup) { $excludeGroup.displayName } else { "(none)" })"
Write-Output "Excluded users:   $(if ($excludeUsers.Count -gt 0) { @($excludeUsers.userPrincipalName) -join ', ' } else { "(none)" })"
Write-Output "Mode:             $(if ($WhatIfMode) { "WhatIf (no changes will be made)" } else { "Live" })"

#endregion

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Retrieving the authentication methods registration report..."
Write-Output "---------------------"
Write-Output "Note: This may take a while depending on the number of users in your tenant."

$reportSelect = "`$select=id,userPrincipalName,userDisplayName,userType,methodsRegistered"
try {
    # $top=999 keeps the page count low in large tenants; fall back to default paging if the endpoint rejects it
    try {
        $registrationDetails = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails?`$top=999&$reportSelect")
    }
    catch {
        Write-RjRbLog -Message "Report query with `$top paging failed, retrying with default page size. Error: $($_.Exception.Message)" -Verbose
        $registrationDetails = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails?$reportSelect")
    }
}
catch {
    Write-Error "Failed to retrieve the authentication methods registration report: $($_.Exception.Message)" -ErrorAction Continue
    throw "Registration report query failed."
}

if ($registrationDetails.Count -eq 0) {
    Write-Error "The authentication methods registration report returned no entries. Please verify the tenant has an Entra ID P1/P2 license and the managed identity holds the AuditLog.Read.All permission." -ErrorAction Continue
    throw "Registration report is empty."
}

# Guests are out of scope - they are neither added nor removed
$memberRows = @($registrationDetails | Where-Object { $_.userType -eq "member" })

# Evaluate which users qualify: at least one secure method, and in strict mode no unsecure method
$desiredUsers = [System.Collections.Generic.List[object]]::new()
foreach ($row in $memberRows) {
    $methods = [string[]]@($row.methodsRegistered | Where-Object { $_ })
    if ($methods.Count -eq 0) {
        continue
    }

    $hasSecure = $secureSet.Overlaps($methods)
    $hasUnsecure = $SecureOnly -and $unsecureSet.Overlaps($methods)
    if ($hasSecure -and -not $hasUnsecure) {
        $desiredUsers.Add($row)
    }
}
$desiredUserIds = @($desiredUsers | Select-Object -ExpandProperty id)

# Methods-based evaluation before exclusions - kept for the report "Qualifies" column
$qualifyingUserIds = $desiredUserIds

# Exclusions: admin users and exclusion group members never qualify and are removed if already members
$exclusionReasons = @{}

if ($ExcludeAdmins) {
    Write-Output ""
    Write-Output "Determining admin users (directory role holders)..."

    try {
        $roleAssignments = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$select=principalId")
    }
    catch {
        Write-Error "Failed to retrieve directory role assignments: $($_.Exception.Message). Please verify the managed identity holds the RoleManagement.Read.Directory permission." -ErrorAction Continue
        throw "Directory role assignment query failed."
    }
    $adminPrincipalIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($assignment in $roleAssignments) {
        if ($assignment.principalId) { [void]$adminPrincipalIds.Add($assignment.principalId) }
    }

    # PIM-eligible assignments require Entra ID P2 - degrade to active assignments only if unavailable
    try {
        $eligibleSchedules = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/roleManagement/directory/roleEligibilitySchedules?`$select=principalId")
        foreach ($schedule in $eligibleSchedules) {
            if ($schedule.principalId) { [void]$adminPrincipalIds.Add($schedule.principalId) }
        }
    }
    catch {
        Write-Output "Warning: PIM-eligible role assignments could not be queried (requires Entra ID P2) - only active role assignments are excluded. Error: $($_.Exception.Message)"
    }

    # Resolve principal types via batched lookups: users count directly, role-assignable groups are
    # expanded to their transitive user members, other principals (service principals) are ignored
    $adminUserIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $principalIdList = @($adminPrincipalIds)
    if ($principalIdList.Count -gt 0) {
        $userProbeRequests = @($principalIdList | ForEach-Object -Begin { $idx = 1 } -Process {
                @{
                    id     = "$idx"
                    method = "GET"
                    url    = "/users/$($_)?`$select=id"
                }
                $idx++
            })
        $userProbeResponses = Invoke-RjRbGraphBatch -Requests $userProbeRequests -ProgressLabel "admin principal lookups"

        $adminGroupCandidateIds = [System.Collections.Generic.List[string]]::new()
        foreach ($response in $userProbeResponses) {
            if ($response.status -eq 200 -and $response.body.id) {
                [void]$adminUserIds.Add($response.body.id)
            }
            elseif ($response.status -eq 404) {
                $reqIdx = [int]$response.id - 1
                if ($reqIdx -ge 0 -and $reqIdx -lt $principalIdList.Count) {
                    $adminGroupCandidateIds.Add($principalIdList[$reqIdx])
                }
            }
        }

        if ($adminGroupCandidateIds.Count -gt 0) {
            $groupProbeRequests = @($adminGroupCandidateIds | ForEach-Object -Begin { $idx = 1 } -Process {
                    @{
                        id     = "$idx"
                        method = "GET"
                        url    = "/groups/$($_)?`$select=id"
                    }
                    $idx++
                })
            $groupProbeResponses = Invoke-RjRbGraphBatch -Requests $groupProbeRequests -ProgressLabel "admin group lookups"
            foreach ($response in $groupProbeResponses) {
                if ($response.status -ne 200 -or -not $response.body.id) { continue }
                $groupMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$($response.body.id)/transitiveMembers/microsoft.graph.user?`$top=999&`$select=id")
                foreach ($member in $groupMembers) { [void]$adminUserIds.Add($member.id) }
            }
        }
    }

    foreach ($adminUserId in $adminUserIds) {
        if (-not $exclusionReasons.ContainsKey($adminUserId)) { $exclusionReasons[$adminUserId] = "admin role" }
    }
    Write-Output "Admin users found:   $($adminUserIds.Count)"
}

if ($excludeGroup) {
    Write-Output ""
    Write-Output "Getting members of exclusion group '$($excludeGroup.displayName)'..."
    $excludeGroupMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$ExcludeGroupId/transitiveMembers/microsoft.graph.user?`$top=999&`$select=id")
    foreach ($member in $excludeGroupMembers) {
        if (-not $exclusionReasons.ContainsKey($member.id)) { $exclusionReasons[$member.id] = "exclusion group" }
    }
    Write-Output "Exclusion group members: $($excludeGroupMembers.Count)"
}

if ($excludeUsers.Count -gt 0) {
    foreach ($excludeUser in $excludeUsers) {
        if (-not $exclusionReasons.ContainsKey($excludeUser.id)) { $exclusionReasons[$excludeUser.id] = "user exclusion list" }
    }
    Write-Output ""
    Write-Output "Individually excluded users: $($excludeUsers.Count)"
}

# Excluded users are dropped from the desired set - the regular diff then also removes
# excluded users that are already group members
$excludedQualifyingCount = 0
if ($exclusionReasons.Count -gt 0) {
    $excludedQualifyingCount = @($desiredUserIds | Where-Object { $exclusionReasons.ContainsKey($_) }).Count
    $desiredUserIds = @($desiredUserIds | Where-Object { -not $exclusionReasons.ContainsKey($_) })
}

Write-Output ""
Write-Output "Report entries:      $($registrationDetails.Count)"
Write-Output "Member users:        $($memberRows.Count) (guests are skipped)"
if ($exclusionReasons.Count -gt 0) {
    Write-Output "Excluded users:      $excludedQualifyingCount (qualifying users blocked by exclusions)"
}
Write-Output "Qualifying users:    $($desiredUserIds.Count)"

if ($desiredUserIds.Count -eq 0) {
    Write-Output ""
    Write-Output "Warning: No user qualifies with the current configuration. All current group members will be removed$(if ($WhatIfMode) { " (WhatIf - no changes will be made)" })."
}

# Get current members of the target group - user objects only via OData cast,
# so devices, service principals and nested groups are never touched
Write-Output ""
Write-Output "Getting current members of '$($targetGroup.displayName)'..."
$currentMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$TargetGroupId/members/microsoft.graph.user?`$top=999&`$select=id,userPrincipalName,userType")

# Guests are out of scope on the group side as well - existing guest members are kept
$currentUserMembers = @($currentMembers | Where-Object { $_.userType -ne "Guest" })
$currentMemberIds = @($currentUserMembers | Select-Object -ExpandProperty id)
Write-Output "Current user members: $($currentMemberIds.Count)"

# Calculate diff using HashSets — O(n) instead of O(n²)
$desiredSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$desiredUserIds, [System.StringComparer]::OrdinalIgnoreCase)
$currentSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$currentMemberIds, [System.StringComparer]::OrdinalIgnoreCase)

$toAdd = @($desiredUserIds | Where-Object { -not $currentSet.Contains($_) })
$toRemove = @($currentMemberIds | Where-Object { -not $desiredSet.Contains($_) })

Write-Output ""
Write-Output "Changes required:"
Write-Output "  Users to add:    $($toAdd.Count)"
Write-Output "  Users to remove: $($toRemove.Count)"

# Initialize counters for summary output
$addedCount = 0
$addFailedCount = 0
$removedCount = 0
$removeFailedCount = 0

if ($WhatIfMode) {
    # Dry run - report the pending changes without touching the group
    if ($toAdd.Count -gt 0) {
        $reportUpnLookup = @{}
        foreach ($row in $memberRows) { $reportUpnLookup[$row.id] = $row.userPrincipalName }
        foreach ($userId in $toAdd) {
            Write-Output "## [WhatIf] Would add '$($reportUpnLookup[$userId])'"
        }
    }
    if ($toRemove.Count -gt 0) {
        $memberUpnLookup = @{}
        foreach ($member in $currentUserMembers) { $memberUpnLookup[$member.id] = $member.userPrincipalName }
        foreach ($userId in $toRemove) {
            Write-Output "## [WhatIf] Would remove '$($memberUpnLookup[$userId])'"
        }
    }
}
else {
    # Add new members via Graph batch API (20 per batch call)
    if ($toAdd.Count -gt 0) {
        Write-RjRbLog -Message "Adding $($toAdd.Count) user(s) via batch API..." -Verbose

        $addRequests = @($toAdd | ForEach-Object -Begin { $idx = 1 } -Process {
                @{
                    id      = "$idx"
                    method  = "POST"
                    url     = "/groups/$TargetGroupId/members/`$ref"
                    headers = @{ "Content-Type" = "application/json" }
                    body    = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$_" }
                }
                $idx++
            })

        $addResponses = Invoke-RjRbGraphBatch -Requests $addRequests -ProgressLabel "adds"
        $addedCount = ($addResponses | Where-Object { $_.status -in 200, 201, 204 }).Count
        $alreadyExisted = ($addResponses | Where-Object { $_.status -eq 400 -and $_.body.error.message -like "*already exist*" }).Count
        $addFailedCount = $addResponses.Count - $addedCount - $alreadyExisted

        $addedCount += $alreadyExisted  # already-member is not an error

        Write-RjRbLog -Message "Added: $($addedCount) user(s)$(if ($addFailedCount -gt 0) { ", failed: $($addFailedCount)" })" -Verbose
        if ($addFailedCount -gt 0) {
            $addResponses | Where-Object { $_.status -notin 200, 201, 204 -and -not ($_.status -eq 400 -and $_.body.error.message -like "*already exist*") } | ForEach-Object {
                Write-RjRbLog -Message "Add failed (status $($_.status), id $($_.id)): $($_.body.error.message)" -Verbose
            }
        }
    }

    # Remove members that no longer qualify via Graph batch API (20 per batch call)
    if ($toRemove.Count -gt 0) {
        Write-RjRbLog -Message "Removing $($toRemove.Count) user(s) via batch API..." -Verbose

        # Build UPN lookup for verbose logging
        $upnLookup = @{}
        $currentUserMembers | ForEach-Object { $upnLookup[$_.id] = $_.userPrincipalName }

        $removeRequests = @($toRemove | ForEach-Object -Begin { $idx = 1 } -Process {
                @{
                    id     = "$idx"
                    method = "DELETE"
                    url    = "/groups/$TargetGroupId/members/$_/`$ref"
                }
                $idx++
            })

        $removeResponses = Invoke-RjRbGraphBatch -Requests $removeRequests -ProgressLabel "removes"
        $removedCount = ($removeResponses | Where-Object { $_.status -in 200, 204 }).Count
        $alreadyGone = ($removeResponses | Where-Object { $_.status -eq 404 }).Count
        $removeFailedCount = $removeResponses.Count - $removedCount - $alreadyGone

        $removedCount += $alreadyGone  # already-removed is not an error

        Write-RjRbLog -Message "Removed: $($removedCount) user(s)$(if ($removeFailedCount -gt 0) { ", failed: $($removeFailedCount)" })" -Verbose
        if ($removeFailedCount -gt 0) {
            $removeResponses | Where-Object { $_.status -notin 200, 204, 404 } | ForEach-Object {
                $reqIdx = [int]$_.id - 1
                $uid = if ($reqIdx -ge 0 -and $reqIdx -lt $toRemove.Count) { $toRemove[$reqIdx] } else { "unknown" }
                $upn = if ($upnLookup.ContainsKey($uid)) { $upnLookup[$uid] } else { $uid }
                Write-RjRbLog -Message "Remove failed (status $($_.status)): $upn — $($_.body.error.message)" -Verbose
            }
        }
    }
}

if ($toAdd.Count -eq 0 -and $toRemove.Count -eq 0) {
    Write-Output ""
    Write-Output "Group is already up to date. No changes needed."
}

#endregion

########################################################
#region     Report File Export (if email or download link is enabled)
########################################################

$reportFiles = @()
$xlsxPath = $null
$tempDir = $null
$fileName_Changes = "mfa-secure-users-group-sync-changes.csv"
$fileName_AllUsers = "mfa-secure-users-group-sync-all-users.csv"
$fileName_Xlsx = "mfa-secure-users-group-sync-report.xlsx"
$actionAddLabel = if ($WhatIfMode) { "Would add" } else { "Added" }
$actionRemoveLabel = if ($WhatIfMode) { "Would remove" } else { "Removed" }
$changeRows = @()

if ($SendEmail -or $CreateDownloadLink) {
    Write-Output ""
    Write-Output "Generating report files..."

    # Unsecure classification for the report columns - the active strict-mode list, or the built-in list for information
    $reportUnsecureSet = if ($unsecureSet.Count -gt 0) {
        $unsecureSet
    }
    else {
        [System.Collections.Generic.HashSet[string]]::new([string[]]$builtInUnsecureMethods, [System.StringComparer]::OrdinalIgnoreCase)
    }

    # Per-user evaluation of all member users from the registration report.
    # "Qualifies" reflects the pure methods evaluation; exclusions are shown separately,
    # the effective add/remove decision ("Action") comes from the exclusion-filtered desired set.
    $qualifiesSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$qualifyingUserIds, [System.StringComparer]::OrdinalIgnoreCase)
    $allUserRows = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $memberRows) {
        $methods = [string[]]@($row.methodsRegistered | Where-Object { $_ })
        $qualifies = $qualifiesSet.Contains($row.id)
        $isDesired = $desiredSet.Contains($row.id)
        $isMember = $currentSet.Contains($row.id)
        $action = if ($isDesired -and -not $isMember) { $actionAddLabel } elseif (-not $isDesired -and $isMember) { $actionRemoveLabel } else { "" }
        $allUserRows.Add([PSCustomObject]@{
                UserPrincipalName    = $row.userPrincipalName
                DisplayName          = $row.userDisplayName
                Qualifies            = if ($qualifies) { "yes" } else { "no" }
                ExclusionReason      = if ($exclusionReasons.ContainsKey($row.id)) { $exclusionReasons[$row.id] } else { "" }
                GroupMemberBefore    = if ($isMember) { "yes" } else { "no" }
                Action               = $action
                SecureMethods        = @($methods | Where-Object { $secureSet.Contains($_) }) -join ', '
                UnsecureMethods      = @($methods | Where-Object { $reportUnsecureSet.Contains($_) }) -join ', '
                AllMethodsRegistered = $methods -join ', '
            })
    }

    # Group members that are missing from the registration report (disabled or deleted accounts)
    $reportRowIds = [System.Collections.Generic.HashSet[string]]::new([string[]]@($memberRows | Select-Object -ExpandProperty id), [System.StringComparer]::OrdinalIgnoreCase)
    foreach ($member in $currentUserMembers) {
        if (-not $reportRowIds.Contains($member.id)) {
            $allUserRows.Add([PSCustomObject]@{
                    UserPrincipalName    = $member.userPrincipalName
                    DisplayName          = ""
                    Qualifies            = "no"
                    ExclusionReason      = if ($exclusionReasons.ContainsKey($member.id)) { $exclusionReasons[$member.id] } else { "" }
                    GroupMemberBefore    = "yes"
                    Action               = $actionRemoveLabel
                    SecureMethods        = ""
                    UnsecureMethods      = ""
                    AllMethodsRegistered = "(not in registration report - disabled or deleted account)"
                })
        }
    }

    $allUserRows = @($allUserRows | Sort-Object UserPrincipalName)
    $changeRows = @($allUserRows | Where-Object { $_.Action } | Sort-Object Action, UserPrincipalName)

    $tempDir = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "MfaSecureUsersGroupSync_$(Get-Date -Format 'yyyyMMdd_HHmmss')"))

    if ($changeRows.Count -gt 0 -and $ReportFileFormat -ne 'XLSX only') {
        $csvChangesPath = Join-Path $tempDir.FullName $fileName_Changes
        $changeRows | Export-Csv -Path $csvChangesPath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvChangesPath
        Write-Output "Exported changes to: $csvChangesPath"
    }

    if ($allUserRows.Count -gt 0 -and $ReportFileFormat -ne 'XLSX only') {
        $csvAllUsersPath = Join-Path $tempDir.FullName $fileName_AllUsers
        $allUserRows | Export-Csv -Path $csvAllUsersPath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvAllUsersPath
        Write-Output "Exported per-user evaluation to: $csvAllUsersPath"
    }

    # Excel workbook: info cover sheet (chosen parameters and result counts) + changes + per-user evaluation
    $coverSheet = [ordered]@{
        Title                      = "MFA Secure Users Group Sync"
        "Tenant"                   = $TenantDisplayName
        "Generated (UTC)"          = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm")
        "Runbook version"          = $Version
        "Mode"                     = $(if ($WhatIfMode) { "WhatIf (no changes were made)" } else { "Live" })
        "Target group"             = $targetGroup.displayName
        "Secure methods"           = ($secureMethods -join ', ')
        "Strict mode (SecureOnly)" = "$SecureOnly"
    }
    if ($SecureOnly) {
        $coverSheet["Unsecure methods"] = ($unsecureMethods -join ', ')
    }
    $coverSheet["Exclude admins"] = "$ExcludeAdmins"
    if ($excludeGroup) {
        $coverSheet["Exclusion group"] = $excludeGroup.displayName
    }
    if ($excludeUsers.Count -gt 0) {
        $coverSheet["Excluded users (individual)"] = (@($excludeUsers.userPrincipalName) -join ', ')
    }
    if ([string]::IsNullOrWhiteSpace($SecureMethodsOverride)) {
        $coverSheet["Method group toggles"] = "Passkeys/FIDO2: $(if ($IncludePasskeys) { 'on' } else { 'off' }), Platform credentials: $(if ($IncludePlatformCredentials) { 'on' } else { 'off' }), Microsoft Authenticator: $(if ($IncludeMicrosoftAuthenticator) { 'on' } else { 'off' }), Software OTP: $(if ($IncludeSoftwareOtp) { 'on' } else { 'off' }), Hardware OTP: $(if ($IncludeHardwareOtp) { 'on' } else { 'off' }), Certificate-based: $(if ($IncludeCertificateBasedAuth) { 'on' } else { 'off' })"
    }
    else {
        $coverSheet["Secure methods override"] = $SecureMethodsOverride
    }
    $coverSheet["Report entries"] = "$($registrationDetails.Count)"
    $coverSheet["Member users evaluated"] = "$($memberRows.Count)"
    if ($exclusionReasons.Count -gt 0) {
        $coverSheet["Excluded users"] = "$excludedQualifyingCount"
    }
    $coverSheet["Qualifying users"] = "$($desiredUserIds.Count)"
    $coverSheet["Previous members"] = "$($currentMemberIds.Count)"
    $coverSheet[$actionAddLabel] = "$($toAdd.Count)"
    $coverSheet[$actionRemoveLabel] = "$($toRemove.Count)"

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxPath = Join-Path $tempDir.FullName $fileName_Xlsx
        Export-RjRbXlsx -Worksheets ([ordered]@{ "Changes" = $changeRows; "All Users" = $allUserRows }) -Path $xlsxPath `
            -CoverSheet $coverSheet `
            -HighlightRules @(
            @{ Column = "Action"; Value = $actionAddLabel; Color = "Green" },
            @{ Column = "Action"; Value = $actionRemoveLabel; Color = "Red" }
        )
        $reportFiles += $xlsxPath
        Write-Output "Exported Excel report to: $xlsxPath"
    }
}

#endregion

########################################################
#region     Upload / Download Link (if CreateDownloadLink is enabled)
########################################################

if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
    Write-Output ""
    Write-Output "Uploading report to storage account..."

    # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
    # transparently connects the managed identity if no Az context is active.
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

#endregion

########################################################
#region     Send Email Report (if SendEmail is enabled)
########################################################

$brandingMailParams = @{}
if ($SendEmail) {
    Write-Output ""
    Write-Output "Preparing email report..."

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    $modeNote = if ($WhatIfMode) { " (WhatIf - no changes were made)" } else { "" }
    $changesSummary = if ($changeRows.Count -gt 0) {
        "**$($toAdd.Count) user(s)** to be added and **$($toRemove.Count) user(s)** to be removed$modeNote."
    }
    else {
        "**No changes required** - the group is already in sync$modeNote."
    }

    $attachmentLines = @()
    if ($ReportFileFormat -ne 'XLSX only') {
        if ($changeRows.Count -gt 0) {
            $attachmentLines += "- **$($fileName_Changes)**: All performed changes with the per-user method details (CSV)"
        }
        $attachmentLines += "- **$($fileName_AllUsers)**: Evaluation of every member user - registered methods, qualification and group membership (CSV)"
    }
    if ($ReportFileFormat -ne 'CSV only') {
        $attachmentLines += "- **$($fileName_Xlsx)**: The same data as a formatted Excel workbook with an info cover sheet (chosen parameters and result counts)"
    }

    $summarySection = @"
# MFA Secure Users Group Sync Report

## Summary

$changesSummary

| | |
|---|---|
| **Target group** | $($targetGroup.displayName) |
| **Mode** | $(if ($WhatIfMode) { "WhatIf (no changes were made)" } else { "Live" }) |
| **Secure methods** | $($secureMethods -join ', ') |
| **Strict mode (SecureOnly)** | $SecureOnly |$(if ($SecureOnly) { "`n| **Unsecure methods** | $($unsecureMethods -join ', ') |" })
| **Exclude admins** | $ExcludeAdmins |$(if ($excludeGroup) { "`n| **Exclusion group** | $($excludeGroup.displayName) |" })$(if ($excludeUsers.Count -gt 0) { "`n| **Excluded users (individual)** | $($excludeUsers.Count) |" })
| **Report entries** | $($registrationDetails.Count) |
| **Member users evaluated** | $($memberRows.Count) |$(if ($exclusionReasons.Count -gt 0) { "`n| **Excluded users** | $excludedQualifyingCount |" })
| **Qualifying users** | $($desiredUserIds.Count) |
| **Previous members** | $($currentMemberIds.Count) |
| **$actionAddLabel** | $($toAdd.Count) |
| **$actionRemoveLabel** | $($toRemove.Count) |
"@

    $emailFooter = @"

---

*This email was automatically generated. Please do not reply to this email.*
"@

    $markdownContent = @"
$summarySection

## Data Files

The following files are attached to this email:

$($attachmentLines -join "`n")
$emailFooter
"@

    # Fallback content when the CSV files are not attached (size limit):
    # the Excel workbook alone carries the complete data at a fraction of the size.
    $markdownFallback = @"
$summarySection

## Data Files

- **$($fileName_Xlsx)**: Formatted Excel workbook with an info cover sheet, the performed changes and the per-user evaluation of all member users

> **Note:** The CSV files were not attached because they exceed the email attachment size limit. The Excel workbook contains the complete data ("Changes" and "All Users" worksheets). Enable the download link option (CreateDownloadLink) to obtain the raw CSV files.
$emailFooter
"@

    $emailSubject = "MFA Secure Users Group Sync$(if ($WhatIfMode) { " (WhatIf)" }) - $($toAdd.Count) to add, $($toRemove.Count) to remove"

    # Attachment size guarded: with "CSV & XLSX" the email falls back to the workbook alone
    # when the full set exceeds the size budget; otherwise a failed send throws.
    $guardParams = @{
        EmailFrom         = $EmailFrom
        EmailTo           = $EmailTo
        Subject           = $emailSubject
        MarkdownContent   = $markdownContent
        TenantDisplayName = $TenantDisplayName
        ReportVersion     = $Version
    }
    if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxPath) {
        Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
    }
    else {
        Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
    }
}

#endregion

########################################################
#region     Cleanup
########################################################

# Cleanup temporary report files
if ($tempDir -and (Test-Path $tempDir.FullName)) {
    Remove-Item -Path $tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Write-Verbose "Cleaned up temporary files"
}

# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Target Group:         $($targetGroup.displayName)"
Write-Output "Secure methods:       $($secureMethods -join ', ')"
Write-Output "Strict mode:          $SecureOnly"
if ($SecureOnly) {
    Write-Output "Unsecure methods:     $($unsecureMethods -join ', ')"
}
Write-Output "Exclude admins:       $ExcludeAdmins"
Write-Output "Exclusion group:      $(if ($excludeGroup) { $excludeGroup.displayName } else { "(none)" })"
Write-Output "User exclusion list:  $(if ($excludeUsers.Count -gt 0) { "$($excludeUsers.Count) user(s)" } else { "(none)" })"
Write-Output "Report entries:       $($registrationDetails.Count)"
Write-Output "Member users:         $($memberRows.Count)"
if ($exclusionReasons.Count -gt 0) {
    Write-Output "Excluded users:       $excludedQualifyingCount"
}
Write-Output "Qualifying users:     $($desiredUserIds.Count)"
Write-Output "Previous members:     $($currentMemberIds.Count)"
if ($WhatIfMode) {
    Write-Output "Would add:            $($toAdd.Count)"
    Write-Output "Would remove:         $($toRemove.Count)"
}
else {
    Write-Output "Added:                $addedCount$(if ($addFailedCount -gt 0) { " (failed: $addFailedCount)" })"
    Write-Output "Removed:              $removedCount$(if ($removeFailedCount -gt 0) { " (failed: $removeFailedCount)" })"
}

Disconnect-MgGraph | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion

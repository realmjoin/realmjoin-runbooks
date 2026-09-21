<#
    .SYNOPSIS
    Email users about devices they have not used for a while

    .DESCRIPTION
    Finds Intune devices that have not been active for a given number of days. Each primary user gets an email listing their stale devices and what to do about them. Users can be included or excluded by group. Emails can be redirected: all of them to an override address for tests, or those of accounts matching a name pattern to a dedicated recipient. Stale devices without a primary user can be collected into one combined email.

    .PARAMETER Days
    Devices inactive for at least this many days count as stale.

    .PARAMETER MaxDays
    Only devices inactive for at most this many days are included. Leave empty for no upper limit.

    .PARAMETER Windows
    Includes Windows devices.

    .PARAMETER MacOS
    Includes macOS devices.

    .PARAMETER iOS
    Includes iOS and iPadOS devices.

    .PARAMETER Android
    Includes Android devices.

    .PARAMETER EmailFrom
    Sender address of the notification email. Taken from the tenant setting RJReport.EmailSender.

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

    .PARAMETER ServiceDeskDisplayName
    Service desk name shown in the email. Taken from the tenant setting RJReport.ServiceDesk_DisplayName.

    .PARAMETER ServiceDeskEmail
    Service desk email address shown in the email. Taken from the tenant setting RJReport.ServiceDesk_EMail.

    .PARAMETER ServiceDeskPhone
    Service desk phone number shown in the email. Taken from the tenant setting RJReport.ServiceDesk_Phone.

    .PARAMETER ServiceDeskPortalUrl
    Link to the service desk portal shown in the email. Taken from the tenant setting RJReport.ServiceDesk_PortalUrl.

    .PARAMETER ServiceDeskTicketUrl
    Link to the service desk ticket shown in the email. Leave empty for no link.

    .PARAMETER UseUserScope
    Whether users are filtered by group membership. Set by the "Filter users by group?" choice.

    .PARAMETER IncludeUserGroup
    Only users in this group are notified.

    .PARAMETER ExcludeUserGroup
    Users in this group are not notified.

    .PARAMETER OverrideEmailRecipient
    Sends every email, including pattern-routed ones and the combined email, to these addresses instead of the normal recipients. For tests, pilots or a ticket system.

    .PARAMETER SendNoPrimaryUserDevicesToOverride
    Collects stale devices that have no primary user into one combined email to the "Recipient for devices without primary user". Those devices ignore the user filter.

    .PARAMETER NoPrimaryUserEmailRecipient
    Addresses for the combined email, separated by commas. Required when the combined email is enabled and no override is set.

    .PARAMETER OverrideUserNamePattern
    Wildcard patterns for user names, separated by commas, for example DEM-*,KIOSK-*. Emails of matching users go to the "Recipient for pattern-matched users" instead.

    .PARAMETER UserNamePatternEmailRecipient
    Addresses that receive the emails of users matching the pattern, separated by commas. Required when a pattern is set and no override is active.

    .PARAMETER MailTemplateLanguage
    English, German, or the custom template from the runbook customization; English is used where the custom template is empty.

    .PARAMETER CustomMailTemplateSubject
    Subject of the email when the custom template is used.

    .PARAMETER CustomMailTemplateBeforeDeviceDetails
    Text above the device list when the custom template is used. Markdown is allowed.

    .PARAMETER CustomMailTemplateAfterDeviceDetails
    Text below the device list when the custom template is used. Markdown is allowed.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Days": {
                "DisplayName": "Days without activity"
            },
            "MaxDays": {
                "DisplayName": "Maximum days without activity"
            },
            "Windows": {
                "DisplayName": "Include Windows devices?"
            },
            "MacOS": {
                "DisplayName": "Include macOS devices?"
            },
            "iOS": {
                "DisplayName": "Include iOS devices?"
            },
            "Android": {
                "DisplayName": "Include Android devices?"
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
            "ServiceDeskDisplayName": {
                "Hide": true
            },
            "ServiceDeskEmail": {
                "Hide": true
            },
            "ServiceDeskPhone": {
                "Hide": true
            },
            "ServiceDeskPortalUrl": {
                "Hide": true
            },
            "ServiceDeskTicketUrl": {
                "Hide": true
            },
            "UseUserScope": {
                "Hide": true
            },
            "IncludeUserGroup": {
                "DisplayName": "Include users from group",
                "Hide": true
            },
            "ExcludeUserGroup": {
                "DisplayName": "Exclude users from group",
                "Hide": true
            },
            "OverrideEmailRecipient": {
                "DisplayName": "Redirect all emails to"
            },
            "SendNoPrimaryUserDevicesToOverride": {
                "Hide": true
            },
            "NoPrimaryUserEmailRecipient": {
                "DisplayName": "Recipient for devices without primary user",
                "Hide": true
            },
            "OverrideUserNamePattern": {
                "DisplayName": "Primary user name pattern"
            },
            "UserNamePatternEmailRecipient": {
                "DisplayName": "Recipient for pattern-matched users"
            },
            "MailTemplateLanguage": {
                "DisplayName": "Mail template",
                "Hide": true
            },
            "CustomMailTemplateSubject": {
                "DisplayName": "Custom: email subject",
                "Hide": true
            },
            "CustomMailTemplateBeforeDeviceDetails": {
                "DisplayName": "Custom: text before device list",
                "Hide": true
            },
            "CustomMailTemplateAfterDeviceDetails": {
                "DisplayName": "Custom: text after device list",
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        },
        "ParameterList": [
            {
                "DisplayName": "Filter users by group?",
                "DisplayAfter": "EmailFrom",
                "Default": false,
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes, filter by group membership",
                            "Customization": {
                                "Hide": [],
                                "Show": ["IncludeUserGroup", "ExcludeUserGroup"],
                                "Default": {
                                    "UseUserScope": true
                                }
                            }
                        },
                        {
                            "Display": "No, send to all primary users",
                            "Customization": {
                                "Hide": ["IncludeUserGroup", "ExcludeUserGroup"],
                                "Default": {
                                    "UseUserScope": false
                                }
                            },
                            "ParameterValue": false
                        }
                    ]
                }
            },
            {
                "DisplayName": "Combine devices without primary user?",
                "DisplayAfter": "UserNamePatternEmailRecipient",
                "Default": false,
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes, send one combined email",
                            "Customization": {
                                "Hide": [],
                                "Show": ["NoPrimaryUserEmailRecipient"],
                                "Default": {
                                    "SendNoPrimaryUserDevicesToOverride": true
                                }
                            }
                        },
                        {
                            "Display": "No, skip them",
                            "Customization": {
                                "Hide": ["NoPrimaryUserEmailRecipient"],
                                "Default": {
                                    "SendNoPrimaryUserDevicesToOverride": false
                                }
                            },
                            "ParameterValue": false
                        }
                    ]
                }
            },
            {
                "DisplayName": "Mail template",
                "DisplayAfter": "Android",
                "Default": "EN",
                "Select": {
                    "Options": [
                        {
                            "Display": "English (default)",
                            "Customization": {
                                "Default": {
                                    "MailTemplateLanguage": "EN"
                                }
                            },
                            "ParameterValue": "EN"
                        },
                        {
                            "Display": "German",
                            "Customization": {
                                "Default": {
                                    "MailTemplateLanguage": "DE"
                                }
                            },
                            "ParameterValue": "DE"
                        },
                        {
                            "Display": "Custom template from runbook customization",
                            "Customization": {
                                "Default": {
                                    "MailTemplateLanguage": "Custom"
                                }
                            },
                            "ParameterValue": "Custom"
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
    [int] $Days = 30,
    [int] $MaxDays = $null,
    [bool] $Windows = $true,
    [bool] $MacOS = $true,
    [bool] $iOS = $true,
    [bool] $Android = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
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
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_DisplayName" } )]
    [string]$ServiceDeskDisplayName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_EMail" } )]
    [string]$ServiceDeskEmail,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_Phone" } )]
    [string]$ServiceDeskPhone,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_PortalUrl" } )]
    [string]$ServiceDeskPortalUrl,
    [string]$ServiceDeskTicketUrl = "",
    [bool] $UseUserScope = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Include users from group" } )]
    [string]$IncludeUserGroup,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclude users from group" } )]
    [string]$ExcludeUserGroup,
    [string]$OverrideEmailRecipient,
    [string]$OverrideUserNamePattern = "",
    [string]$UserNamePatternEmailRecipient = "",
    [bool] $SendNoPrimaryUserDevicesToOverride = $false,
    [string]$NoPrimaryUserEmailRecipient = "",
    [ValidateSet("EN", "DE", "Custom")]
    [string]$MailTemplateLanguage = "EN",
    [string]$CustomMailTemplateSubject,
    [string]$CustomMailTemplateBeforeDeviceDetails,
    [string]$CustomMailTemplateAfterDeviceDetails,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.7.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
Write-RjRbLog -Message "Service Desk Display Name: $ServiceDeskDisplayName" -Verbose
Write-RjRbLog -Message "Service Desk Email: $ServiceDeskEmail" -Verbose
Write-RjRbLog -Message "Service Desk Phone: $ServiceDeskPhone" -Verbose
Write-RjRbLog -Message "Service Desk Portal URL: $ServiceDeskPortalUrl" -Verbose
Write-RjRbLog -Message "Service Desk Ticket URL: $ServiceDeskTicketUrl" -Verbose
Write-RjRbLog -Message "Days: $Days" -Verbose
Write-RjRbLog -Message "MaxDays: $MaxDays" -Verbose
Write-RjRbLog -Message "Windows: $Windows" -Verbose
Write-RjRbLog -Message "MacOS: $MacOS" -Verbose
Write-RjRbLog -Message "iOS: $iOS" -Verbose
Write-RjRbLog -Message "Android: $Android" -Verbose
Write-RjRbLog -Message "UseUserScope: $UseUserScope" -Verbose
Write-RjRbLog -Message "IncludeUserGroup: $IncludeUserGroup" -Verbose
Write-RjRbLog -Message "ExcludeUserGroup: $ExcludeUserGroup" -Verbose
Write-RjRbLog -Message "OverrideEmailRecipient: $OverrideEmailRecipient" -Verbose
Write-RjRbLog -Message "OverrideUserNamePattern: $OverrideUserNamePattern" -Verbose
Write-RjRbLog -Message "UserNamePatternEmailRecipient: $UserNamePatternEmailRecipient" -Verbose
Write-RjRbLog -Message "SendNoPrimaryUserDevicesToOverride: $SendNoPrimaryUserDevicesToOverride" -Verbose
Write-RjRbLog -Message "NoPrimaryUserEmailRecipient: $NoPrimaryUserEmailRecipient" -Verbose
Write-RjRbLog -Message "MailTemplateLanguage: $MailTemplateLanguage" -Verbose
Write-RjRbLog -Message "CustomMailTemplateSubject: $CustomMailTemplateSubject" -Verbose
Write-RjRbLog -Message "CustomMailTemplateBeforeDeviceDetails: $CustomMailTemplateBeforeDeviceDetails" -Verbose
Write-RjRbLog -Message "CustomMailTemplateAfterDeviceDetails: $CustomMailTemplateAfterDeviceDetails" -Verbose

#endregion

########################################################
#region     Parameter Validation
########################################################

# Validate Email Address
if (-not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -Verbose
    throw "The sender email address is required. This needs to be configured in the runbook customization."
    exit
}

# Validate override routing configuration
$globalOverrideActive = -not [string]::IsNullOrWhiteSpace($OverrideEmailRecipient)
if ($globalOverrideActive) {
    Write-Warning "OverrideEmailRecipient is set - ALL notifications are redirected to '$OverrideEmailRecipient'. No end user receives an email."
}

# Combined email for devices without a primary user
$effectiveNoPrimaryUserRecipient = $null
if ($SendNoPrimaryUserDevicesToOverride) {
    if ($globalOverrideActive) {
        $effectiveNoPrimaryUserRecipient = $OverrideEmailRecipient
    }
    elseif (-not [string]::IsNullOrWhiteSpace($NoPrimaryUserEmailRecipient)) {
        $effectiveNoPrimaryUserRecipient = $NoPrimaryUserEmailRecipient
    }
    else {
        throw "SendNoPrimaryUserDevicesToOverride is enabled but neither NoPrimaryUserEmailRecipient nor OverrideEmailRecipient is set. Configure a recipient for the combined email."
    }
}
elseif (-not [string]::IsNullOrWhiteSpace($NoPrimaryUserEmailRecipient)) {
    Write-Warning "NoPrimaryUserEmailRecipient is set but SendNoPrimaryUserDevicesToOverride is disabled - the recipient will be ignored."
}

# Pattern-based redirect of user notifications; parse the comma-separated pattern list once
$overrideUserPatterns = @()
$effectivePatternRecipient = $null
if (-not [string]::IsNullOrWhiteSpace($OverrideUserNamePattern)) {
    if ($globalOverrideActive) {
        Write-Warning "OverrideUserNamePattern is set, but OverrideEmailRecipient already redirects all notifications - the pattern has no additional effect."
    }
    elseif ([string]::IsNullOrWhiteSpace($UserNamePatternEmailRecipient)) {
        throw "OverrideUserNamePattern is set but UserNamePatternEmailRecipient is empty. Configure a recipient for pattern-matched users."
    }
    else {
        $effectivePatternRecipient = $UserNamePatternEmailRecipient
        $overrideUserPatterns = @($OverrideUserNamePattern.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        Write-Warning "OverrideUserNamePattern is set - notifications of users matching '$OverrideUserNamePattern' are redirected to '$UserNamePatternEmailRecipient'; all other users are mailed directly."
    }
}
elseif (-not [string]::IsNullOrWhiteSpace($UserNamePatternEmailRecipient)) {
    Write-Warning "UserNamePatternEmailRecipient is set but OverrideUserNamePattern is empty - the recipient will be ignored."
}

# Validate Custom Mail Template parameters - fallback to EN if any parameter is missing
if ($MailTemplateLanguage -eq "Custom") {
    $customTemplateIncomplete = $false

    if ([string]::IsNullOrWhiteSpace($CustomMailTemplateSubject)) {
        Write-Warning -Message "CustomMailTemplateSubject is missing. Falling back to English (EN) template." -Verbose
        $customTemplateIncomplete = $true
    }
    if ([string]::IsNullOrWhiteSpace($CustomMailTemplateBeforeDeviceDetails)) {
        Write-Warning -Message "CustomMailTemplateBeforeDeviceDetails is missing. Falling back to English (EN) template." -Verbose
        $customTemplateIncomplete = $true
    }
    if ([string]::IsNullOrWhiteSpace($CustomMailTemplateAfterDeviceDetails)) {
        Write-Warning -Message "CustomMailTemplateAfterDeviceDetails is missing. Falling back to English (EN) template." -Verbose
        $customTemplateIncomplete = $true
    }

    if ($customTemplateIncomplete) {
        Write-Warning -Message "One or more custom mail template parameters are missing. Using English (EN) template as fallback." -Verbose
        $MailTemplateLanguage = "EN"
        Write-RjRbLog -Message "Mail template language changed to EN (fallback)" -Verbose
    }
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
        by following the @odata.nextLink property in the response.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query.
    #>
    param(
        [string]$Uri
    )

    $allResults = @()
    $nextLink = $Uri

    do {
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        if ($response.value) {
            $allResults += $response.value
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $allResults
}

function Get-MailTemplate {
    <#
        .SYNOPSIS
        Returns the mail template based on the selected language or custom template.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("EN", "DE", "Custom")]
        [string]$Language,
        [string]$CustomSubject,
        [string]$CustomBeforeDeviceDetails,
        [string]$CustomAfterDeviceDetails
    )

    $template = @{
        Subject             = ""
        BeforeDeviceDetails = ""
        AfterDeviceDetails  = ""
    }

    switch ($Language) {
        "EN" {
            $template.Subject = "Action Required: Inactive Devices"
            $template.BeforeDeviceDetails = "Dear user,`n`nWe have identified the following devices associated with your account that have been inactive for"
            $template.AfterDeviceDetails = @"
## What You Should Do Now

Please review each listed device and choose the appropriate action:

### Option 1: You Still Have the Device

If the device is still in your possession:

1. **Turn on the device**
2. **Sign in with your account**
3. **Verify that it is connected to the Internet**
4. **Check for and install any pending system updates**
5. The device will automatically sync with our management system

### Option 2: You No Longer Have the Device

If you no longer own or use the device:

1. **Contact your Service Desk**
2. Inform them which device (name/serial number) you no longer use

## Why Is This Important?

- **Security:** Inactive devices can pose a security risk
- **Compliance:** We need to ensure all registered devices are actively used

## Questions?

If you have any questions or problems, please contact your Service Desk.
"@
        }
        "DE" {
            $template.Subject = "Handlungsbedarf: Inaktive Geräte"
            $template.BeforeDeviceDetails = "Liebe Nutzerin, lieber Nutzer,`n`nwir haben die folgenden Geräte identifiziert, die Ihrem Konto zugeordnet sind und seit"
            $template.AfterDeviceDetails = @"
## Was Sie jetzt tun sollten

Bitte prüfen Sie jedes aufgeführte Gerät und wählen Sie die entsprechende Aktion:

### Option 1: Sie besitzen das Gerät noch

Wenn sich das Gerät noch in Ihrem Besitz befindet:

1. **Schalten Sie das Gerät ein**
2. **Melden Sie sich mit Ihrem Konto an**
3. **Stellen Sie sicher, dass es mit dem Internet verbunden ist**
4. **Prüfen Sie, ob System Updates verfügbar sind und installieren Sie diese**
5. Das Gerät wird sich automatisch mit unserem System synchronisieren

### Option 2: Sie besitzen das Gerät nicht mehr

Wenn Sie das Gerät nicht mehr besitzen oder verwenden:

1. **Kontaktieren Sie Ihren Service Desk**
2. Teilen Sie mit, welches Gerät (Name/Seriennummer) Sie nicht mehr verwenden

## Warum ist das wichtig?

- **Sicherheit:** Inaktive Geräte können ein Sicherheitsrisiko darstellen
- **Compliance:** Wir müssen sicherstellen, dass alle registrierten Geräte aktiv verwendet werden

## Fragen?

Wenn Sie Fragen oder Probleme haben, wenden Sie sich bitte an Ihren Service Desk.
"@
        }
        "Custom" {
            $template.Subject = $CustomSubject
            $template.BeforeDeviceDetails = $CustomBeforeDeviceDetails
            $template.AfterDeviceDetails = $CustomAfterDeviceDetails
        }
    }

    return $template
}

function Get-DeviceListMarkdown {
    <#
        .SYNOPSIS
        Builds the localized markdown device list section for notification emails.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Devices,
        [Parameter(Mandatory = $true)]
        [string]$MailTemplateLanguage
    )

    $deviceListMarkdown = ""
    foreach ($device in $Devices) {
        $lastSync = if ($device.lastSyncDateTime) {
            (Get-Date $device.lastSyncDateTime).ToString("yyyy-MM-dd")
        }
        else {
            "Unknown"
        }

        # Calculate actual inactive days
        $inactiveDays = if ($device.lastSyncDateTime) {
            [math]::Round(((Get-Date) - (Get-Date $device.lastSyncDateTime)).TotalDays)
        }
        else {
            "Unknown"
        }

        # Device name header - localized based on mail template language
        $deviceNameHeader = if ($MailTemplateLanguage -eq "DE") { "### $($device.deviceName)" } else { "### $($device.deviceName)" }
        $osLabel = if ($MailTemplateLanguage -eq "DE") { "Betriebssystem" } else { "Operating System" }
        $modelLabel = if ($MailTemplateLanguage -eq "DE") { "Modell" } else { "Model" }
        $serialLabel = if ($MailTemplateLanguage -eq "DE") { "Seriennummer" } else { "Serial Number" }
        $userLabel = if ($MailTemplateLanguage -eq "DE") { "Primärer Benutzer" } else { "Primary User" }
        $lastSyncLabel = if ($MailTemplateLanguage -eq "DE") { "Letzte Synchronisation" } else { "Last Sync" }
        $inactiveLabel = if ($MailTemplateLanguage -eq "DE") { "Inaktiv seit" } else { "Inactive Since" }
        $daysLabel = if ($MailTemplateLanguage -eq "DE") { "Tagen" } else { "days" }

        $primaryUserValue = if ($device.userPrincipalName) {
            $device.userPrincipalName
        }
        elseif ($MailTemplateLanguage -eq "DE") {
            "Nicht zugewiesen"
        }
        else {
            "Not assigned"
        }

        $deviceListMarkdown += @"
$deviceNameHeader

- **$($osLabel):** $($device.operatingSystem)
- **$($modelLabel):** $($device.manufacturer) $($device.model)
- **$($serialLabel):** $($device.serialNumber)
- **$($userLabel):** $primaryUserValue
- **$($lastSyncLabel):** $lastSync
- **$($inactiveLabel):** $inactiveDays $daysLabel

"@
    }

    return $deviceListMarkdown
}

#endregion

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_)"
    throw
}

# Connect RJ RunbookHelper for email sending
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

#endregion

########################################################
#region     Data Collection
########################################################

# Get tenant information
Write-Output ""
Write-Output "Retrieving tenant information..."
$tenantDisplayName = "Unknown Tenant"
try {
    $organizationUri = "https://graph.microsoft.com/v1.0/organization?`$select=displayName"
    $organizationResponse = Invoke-MgGraphRequest -Uri $organizationUri -Method GET -ErrorAction Stop

    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
        Write-Output "Tenant: $($tenantDisplayName)"
    }
    elseif ($organizationResponse.displayName) {
        $tenantDisplayName = $organizationResponse.displayName
        Write-Output "Tenant: $($tenantDisplayName)"
    }
}
catch {
    Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
}

# Calculate the date threshold for stale devices
$beforeDate = (Get-Date).AddDays(-$Days) | Get-Date -Format "yyyy-MM-dd"

# Prepare filter for the Graph API query
if ($null -ne $MaxDays -and $MaxDays -gt $Days) {
    # Filter for devices inactive between Days and MaxDays
    $afterDate = (Get-Date).AddDays(-$MaxDays) | Get-Date -Format "yyyy-MM-dd"
    $filter = "lastSyncDateTime le $($beforeDate)T00:00:00Z and lastSyncDateTime ge $($afterDate)T00:00:00Z"
    Write-RjRbLog -Message "Filtering devices inactive between $Days and $MaxDays days" -Verbose
}
else {
    # Filter for devices inactive for at least Days
    $filter = "lastSyncDateTime le $($beforeDate)T00:00:00Z"
    Write-RjRbLog -Message "Filtering devices inactive for at least $Days days" -Verbose
}

# Define the properties to select
$selectProperties = @(
    'deviceName'
    'lastSyncDateTime'
    'enrolledDateTime'
    'userPrincipalName'
    'id'
    'serialNumber'
    'manufacturer'
    'model'
    'operatingSystem'
    'osVersion'
    'complianceState'
)
$selectString = ($selectProperties -join ',')

# Get all stale devices with primary users
Write-Output ""
if ($null -ne $MaxDays -and $MaxDays -gt $Days) {
    Write-Output "Listing devices inactive between $Days and $MaxDays days..."
}
else {
    Write-Output "Listing devices not active for at least $Days days..."
}
Write-Output ""

$encodedFilter = [System.Uri]::EscapeDataString($filter)
$devicesUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=$selectString&`$filter=$encodedFilter"
$devices = Get-GraphPagedResult -Uri $devicesUri

Write-Output "Found $($devices.Count) total stale devices before platform filtering"

# Filter devices by platform and primary user
$filteredDevices = @()
$devicesWithoutUser = @()

foreach ($device in $devices) {
    $include = $false

    # Check if the device's platform matches any of the selected platforms
    if ($Windows -and $device.operatingSystem -eq "Windows") {
        $include = $true
    }
    elseif ($MacOS -and $device.operatingSystem -eq "macOS") {
        $include = $true
    }
    elseif ($iOS -and $device.operatingSystem -eq "iOS") {
        $include = $true
    }
    elseif ($Android -and $device.operatingSystem -eq "Android") {
        $include = $true
    }

    if (-not $include) {
        continue
    }

    # Devices without a primary user are either collected for the override recipient or skipped
    if (-not $device.userPrincipalName) {
        if ($SendNoPrimaryUserDevicesToOverride) {
            $devicesWithoutUser += $device
        }
        else {
            Write-RjRbLog -Message "Skipping device '$($device.deviceName)' - no primary user assigned" -Verbose
        }
        continue
    }

    $filteredDevices += $device
}

Write-Output "Found $($filteredDevices.Count) stale devices after platform filtering"
if ($SendNoPrimaryUserDevicesToOverride) {
    Write-Output "Found $($devicesWithoutUser.Count) stale devices without a primary user (will be sent as one combined email)"
}

#endregion

########################################################
#region     Data Processing
########################################################

# Get group membership for filtering if UseUserScope is enabled
$includeUserIds = @()
$excludeUserIds = @()

if ($UseUserScope) {
    Write-Output ""
    Write-Output "Processing user scope filtering..."

    # Get users from include group
    if ($IncludeUserGroup) {
        Write-Output "Getting members from include group..."
        try {
            $includeGroupUri = "https://graph.microsoft.com/v1.0/groups/$IncludeUserGroup/members?`$select=id,userPrincipalName"
            $includeMembers = Get-GraphPagedResult -Uri $includeGroupUri
            $includeUserIds = $includeMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' } | ForEach-Object { $_.id }
            Write-Output "Include group contains $($includeUserIds.Count) users"
        }
        catch {
            Write-Warning "Failed to retrieve include group members: $($_)"
        }
    }

    # Get users from exclude group
    if ($ExcludeUserGroup) {
        Write-Output "Getting members from exclude group..."
        try {
            $excludeGroupUri = "https://graph.microsoft.com/v1.0/groups/$ExcludeUserGroup/members?`$select=id,userPrincipalName"
            $excludeMembers = Get-GraphPagedResult -Uri $excludeGroupUri
            $excludeUserIds = $excludeMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' } | ForEach-Object { $_.id }
            Write-Output "Exclude group contains $($excludeUserIds.Count) users"
        }
        catch {
            Write-Warning "Failed to retrieve exclude group members: $($_)"
        }
    }
}

# Group devices by primary user
$devicesByUser = @{}

foreach ($device in $filteredDevices) {
    $userPrincipalName = $device.userPrincipalName

    # Get user ID for scope filtering
    if ($UseUserScope) {
        try {
            $encodedUserPrincipalName = [System.Uri]::EscapeDataString($userPrincipalName)
            $userUri = "https://graph.microsoft.com/v1.0/users/{0}?`$select=id,displayName,mail" -f $encodedUserPrincipalName
            $userInfo = Invoke-MgGraphRequest -Uri $userUri -Method GET -ErrorAction SilentlyContinue

            if ($userInfo) {
                $userId = $userInfo.id

                # Apply include filter
                if ($IncludeUserGroup -and ($includeUserIds.Count -gt 0) -and ($userId -notin $includeUserIds)) {
                    Write-RjRbLog -Message "Skipping user '$($userPrincipalName)' - not in include group" -Verbose
                    continue
                }

                # Apply exclude filter
                if ($ExcludeUserGroup -and ($excludeUserIds.Count -gt 0) -and ($userId -in $excludeUserIds)) {
                    Write-RjRbLog -Message "Skipping user '$($userPrincipalName)' - in exclude group" -Verbose
                    continue
                }
            }
        }
        catch {
            Write-RjRbLog -Message "Could not retrieve user info for $($userPrincipalName): $($_.Exception.Message)" -Verbose
            continue
        }
    }

    if (-not $devicesByUser.ContainsKey($userPrincipalName)) {
        $devicesByUser[$userPrincipalName] = @()
    }

    $devicesByUser[$userPrincipalName] += $device
}

Write-Output ""
Write-Output "Will notify $($devicesByUser.Count) users about their stale devices"

#endregion

########################################################
#region     Email Notifications
########################################################

Write-Output ""
Write-Output "## Sending email notifications to users..."
Write-Output ""

$emailsSent = 0
$emailsFailed = 0
$patternRoutedUsers = 0

# Get mail template based on language selection
$mailTemplate = Get-MailTemplate -Language $MailTemplateLanguage -CustomSubject $CustomMailTemplateSubject -CustomBeforeDeviceDetails $CustomMailTemplateBeforeDeviceDetails -CustomAfterDeviceDetails $CustomMailTemplateAfterDeviceDetails

# Build Service Desk contact information section
$serviceDeskSection = ""
if ($ServiceDeskDisplayName -or $ServiceDeskEmail -or $ServiceDeskPhone -or $ServiceDeskPortalUrl -or $ServiceDeskTicketUrl) {
    $serviceDeskSection = "`n`n### Service Desk Contact Information`n"
    if ($ServiceDeskDisplayName) {
        $serviceDeskSection += "`n $($ServiceDeskDisplayName)"
    }
    if ($ServiceDeskEmail) {
        $serviceDeskSection += "`n **Email:** [$($ServiceDeskEmail)](mailto:$($ServiceDeskEmail))"
    }
    if ($ServiceDeskPhone) {
        $serviceDeskSection += "`n **Phone:** [$($ServiceDeskPhone)](tel:$($ServiceDeskPhone))"
    }
    if ($ServiceDeskPortalUrl) {
        $serviceDeskSection += "`n **Portal:** [$($ServiceDeskPortalUrl)]($($ServiceDeskPortalUrl))"
    }
    if ($ServiceDeskTicketUrl) {
        $serviceDeskSection += "`n **Ticket:** [$($ServiceDeskTicketUrl)]($($ServiceDeskTicketUrl))"
    }
}

$brandingMailParams = @{}
if ($devicesByUser.Count -gt 0 -or ($SendNoPrimaryUserDevicesToOverride -and $devicesWithoutUser.Count -gt 0)) {
    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor
}

foreach ($userEmail in $devicesByUser.Keys) {
    $userDevices = $devicesByUser[$userEmail]

    # Determine actual recipient: the global override wins over everything;
    # otherwise pattern-matched users go to the pattern recipient, the rest directly to the user
    $routeToOverride = $false
    $actualRecipient = $userEmail
    if ($globalOverrideActive) {
        $routeToOverride = $true
        $actualRecipient = $OverrideEmailRecipient
    }
    elseif ($overrideUserPatterns.Count -gt 0) {
        foreach ($pattern in $overrideUserPatterns) {
            if ($userEmail -like $pattern) {
                $routeToOverride = $true
                $actualRecipient = $effectivePatternRecipient
                $patternRoutedUsers++
                break
            }
        }
    }

    Write-Output "Processing user: $($userEmail) ($($userDevices.Count) device(s)) - Sending to: $($actualRecipient)"

    # Build device list for email
    $deviceListMarkdown = Get-DeviceListMarkdown -Devices $userDevices -MailTemplateLanguage $MailTemplateLanguage

    # Build email subject
    $emailSubject = $mailTemplate.Subject

    # Add user information to subject if sending to override recipient
    if ($routeToOverride) {
        $emailSubject = "$($mailTemplate.Subject) - User: $userEmail"
    }

    # Determine inactivity period text
    $inactivityPeriodText = switch ($MailTemplateLanguage) {
        "DE" { "mindestens **$($Days) Tage** inaktiv sind" }
        "EN" { "at least **$($Days) days**" }
        "Custom" { "" }
    }

    # Build override recipient note
    $overrideNoteEN = if ($routeToOverride) {
        "**Note:** This email was sent to you instead of the end user.`n`n**Affected User:** $($userEmail)`n"
    }
    else { "" }

    $overrideNoteDE = if ($routeToOverride) {
        "**Hinweis:** Diese E-Mail wurde an Sie statt an den Endbenutzer gesendet.`n`n**Betroffener Benutzer:** $($userEmail)`n"
    }
    else { "" }

    $overrideNote = if ($MailTemplateLanguage -eq "DE") { $overrideNoteDE } else { $overrideNoteEN }

    # Build email header based on language
    $emailHeader = if ($MailTemplateLanguage -eq "DE") {
        "# Inaktive Geräte - Handlungsbedarf"
    }
    else {
        "# Inactive Devices - Action Required"
    }

    # Build email footer
    $autoGeneratedNote = if ($MailTemplateLanguage -eq "DE") {
        "*Diese E-Mail wurde automatisch generiert. Bitte antworten Sie nicht auf diese E-Mail.*"
    }
    else {
        "*This email was automatically generated. Please do not reply to this email.*"
    }

    $markdownContent = @"
$emailHeader

$overrideNote
$($mailTemplate.BeforeDeviceDetails) $($inactivityPeriodText):

$($deviceListMarkdown)

$($mailTemplate.AfterDeviceDetails)$($serviceDeskSection)

---

$autoGeneratedNote
"@

    # Send email to user
    try {
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $actualRecipient -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version @brandingMailParams

        Write-Output "Email sent successfully to $($actualRecipient)"
        Write-RjRbLog -Message "Email sent to $($actualRecipient) for user $($userEmail) with $($userDevices.Count) device(s)" -Verbose
        $emailsSent++
    }
    catch {
        Write-Warning "Failed to send email to $($actualRecipient) : $_"
        Write-RjRbLog -Message "Failed to send email to $($actualRecipient) for user $($userEmail) : $_" -Verbose
        $emailsFailed++
    }
}

# Send one combined email for all devices without a primary user to the override recipient
if ($SendNoPrimaryUserDevicesToOverride -and $devicesWithoutUser.Count -gt 0) {
    Write-Output "Processing $($devicesWithoutUser.Count) device(s) without primary user - Sending to: $($effectiveNoPrimaryUserRecipient)"

    $deviceListMarkdown = Get-DeviceListMarkdown -Devices $devicesWithoutUser -MailTemplateLanguage $MailTemplateLanguage

    if ($MailTemplateLanguage -eq "DE") {
        $emailSubject = "$($mailTemplate.Subject) - Geräte ohne primären Benutzer"
        $emailHeader = "# Inaktive Geräte - Handlungsbedarf"
        $noUserNote = "**Hinweis:** Die folgenden inaktiven Geräte haben keinen primären Benutzer in Intune zugewiesen. Bitte prüfen Sie diese zentral."
        $inactivityLine = if ($null -ne $MaxDays -and $MaxDays -gt $Days) {
            "Diese Geräte sind seit **$($Days) bis $($MaxDays) Tagen** inaktiv:"
        }
        else {
            "Diese Geräte sind seit mindestens **$($Days) Tagen** inaktiv:"
        }
        $autoGeneratedNote = "*Diese E-Mail wurde automatisch generiert. Bitte antworten Sie nicht auf diese E-Mail.*"
    }
    else {
        $emailSubject = "$($mailTemplate.Subject) - Devices without Primary User"
        $emailHeader = "# Inactive Devices - Action Required"
        $noUserNote = "**Note:** The following inactive devices have no primary user assigned in Intune. Please review them centrally."
        $inactivityLine = if ($null -ne $MaxDays -and $MaxDays -gt $Days) {
            "These devices have been inactive between **$($Days) and $($MaxDays) days**:"
        }
        else {
            "These devices have been inactive for at least **$($Days) days**:"
        }
        $autoGeneratedNote = "*This email was automatically generated. Please do not reply to this email.*"
    }

    $markdownContent = @"
$emailHeader

$noUserNote

$inactivityLine

$($deviceListMarkdown)$($serviceDeskSection)

---

$autoGeneratedNote
"@

    try {
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $effectiveNoPrimaryUserRecipient -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version @brandingMailParams

        Write-Output "Email sent successfully to $($effectiveNoPrimaryUserRecipient)"
        Write-RjRbLog -Message "Email sent to $($effectiveNoPrimaryUserRecipient) for $($devicesWithoutUser.Count) device(s) without primary user" -Verbose
        $emailsSent++
    }
    catch {
        Write-Warning "Failed to send email to $($effectiveNoPrimaryUserRecipient) : $_"
        Write-RjRbLog -Message "Failed to send email to $($effectiveNoPrimaryUserRecipient) for devices without primary user : $_" -Verbose
        $emailsFailed++
    }
}

#endregion

########################################################
#region     Output/Export
########################################################

Write-Output ""
Write-Output "===================="
Write-Output "Notification Summary"
Write-Output "===================="
Write-Output "Total emails sent: $($emailsSent)"
Write-Output "Failed notifications: $($emailsFailed)"
Write-Output "Total devices: $($filteredDevices.Count + $devicesWithoutUser.Count)"
if ($SendNoPrimaryUserDevicesToOverride) {
    Write-Output "Devices without primary user: $($devicesWithoutUser.Count)"
}
if ($null -ne $MaxDays -and $MaxDays -gt $Days) {
    Write-Output "Inactivity range: $($Days) to $($MaxDays) days"
}
else {
    Write-Output "Days threshold: $($Days) days (minimum)"
}

if ($UseUserScope) {
    Write-Output ""
    Write-Output "User Scope Filtering:"
    if ($IncludeUserGroup) {
        Write-Output "  - Include group: $($includeUserIds.Count) users"
    }
    if ($ExcludeUserGroup) {
        Write-Output "  - Exclude group: $($excludeUserIds.Count) users"
    }
}

if ($globalOverrideActive -or $overrideUserPatterns.Count -gt 0 -or $SendNoPrimaryUserDevicesToOverride) {
    Write-Output ""
    Write-Output "Email Routing:"
    if ($globalOverrideActive) {
        Write-Output "  - Global override active: ALL emails sent to: $($OverrideEmailRecipient)"
    }
    elseif ($overrideUserPatterns.Count -gt 0) {
        Write-Output "  - Users matching pattern '$($OverrideUserNamePattern)': $($patternRoutedUsers) (sent to: $($effectivePatternRecipient))"
        Write-Output "  - All other notifications sent directly to end users"
    }
    if ($SendNoPrimaryUserDevicesToOverride) {
        Write-Output "  - Devices without primary user: $($devicesWithoutUser.Count) (combined email sent to: $($effectiveNoPrimaryUserRecipient))"
    }
}

Write-Output ""
Write-Output "Done!"

#endregion

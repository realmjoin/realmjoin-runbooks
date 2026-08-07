<#
    .SYNOPSIS
    Notify primary users about their stale devices via email

    .DESCRIPTION
    Identifies devices that haven't been active for a specified number of days and sends personalized email notifications to the primary users of those devices. The email contains device information and action steps for the user. Optionally filter users by including or excluding specific groups. Devices without a primary user (and devices whose primary user matches a configurable name pattern, e.g. Device Enrollment Manager accounts) can optionally be routed to the override email recipient while all other notifications are sent directly to the end users.

    .NOTES
    This runbook automatically sends personalized email notifications to users who have devices that haven't synced for a specified number of days.
    The email is sent directly to the primary user's email address and includes detailed information about each inactive device.

    Prerequisites:
    - EmailFrom parameter must be configured in runbook customization (RJReport.EmailSender setting)
    - Optional: Service Desk contact information can be configured (ServiceDesk_DisplayName, ServiceDesk_EMail, ServiceDesk_Phone, ServiceDesk_PortalUrl)

    Common Use Cases:
    - Automated user reminders about inactive devices to encourage regular device check-ins
    - Proactive device lifecycle management by alerting users before devices are retired
    - Security and compliance by ensuring users are aware of all devices registered to them
    - Using MaxDays parameter for staged notifications (e.g., first reminder at 30 days, final notice at 60 days)
    - User scope filtering to target specific departments or exclude service accounts
    - Centrally handling devices without a primary user or owned by Device Enrollment Manager (e.g. DEM-*) accounts via the override recipient

    Pilot and Testing Options:
    - Use OverrideEmailRecipient parameter to send all notifications to a test mailbox instead of end users
    - Perfect for validating email content and testing filters before rolling out to production
    - Send notifications to ticket systems or shared mailboxes for centralized handling

    .PARAMETER Days
    Number of days without activity to be considered stale (minimum threshold).

    .PARAMETER MaxDays
    Optional maximum number of days without activity. If set, only devices inactive between Days and MaxDays will be included.

    .PARAMETER Windows
    Include Windows devices in the results.

    .PARAMETER MacOS
    Include macOS devices in the results.

    .PARAMETER iOS
    Include iOS devices in the results.

    .PARAMETER Android
    Include Android devices in the results.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization.

    .PARAMETER ServiceDeskDisplayName
    Service Desk display name for user contact information (optional).

    .PARAMETER ServiceDeskEmail
    Service Desk email address for user contact information (optional).

    .PARAMETER ServiceDeskPhone
    Service Desk phone number for user contact information (optional).

    .PARAMETER ServiceDeskPortalUrl
    Service Desk portal URL for user contact information, rendered as a clickable link (optional).

    .PARAMETER ServiceDeskTicketUrl
    Direct link to a Service Desk ticket, rendered as a clickable link (optional). Empty by default, so no ticket link is added.

    .PARAMETER UseUserScope
    Enable user scope filtering to include or exclude users based on group membership.

    .PARAMETER IncludeUserGroup
    Only send emails to users who are members of this group. Requires UseUserScope to be enabled.

    .PARAMETER ExcludeUserGroup
    Do not send emails to users who are members of this group. Requires UseUserScope to be enabled.

    .PARAMETER OverrideEmailRecipient
    Optional: Email address(es) to send all notifications to instead of end users. Can be comma-separated for multiple recipients. Perfect for testing, piloting, or sending to ticket systems. If left empty, emails will be sent to the actual end users.

    .PARAMETER SendNoPrimaryUserDevicesToOverride
    If enabled, stale devices without a primary user (and devices whose primary user matches OverrideUserNamePattern) are sent to OverrideEmailRecipient, while all other notifications go directly to the end users. Requires OverrideEmailRecipient to be set. Devices without a primary user bypass user scope filtering.

    .PARAMETER OverrideUserNamePattern
    Optional wildcard pattern(s) matched against the primary user UPN (comma-separated, e.g. 'DEM-*,KIOSK-*', case-insensitive). Matching users' notifications are redirected to OverrideEmailRecipient. Only used when SendNoPrimaryUserDevicesToOverride is enabled.

    .PARAMETER MailTemplateLanguage
    Select which email template to use: EN (English, default), DE (German), or Custom (from Runbook Customizations).

    .PARAMETER CustomMailTemplateSubject
    Custom email subject line (only used when MailTemplateLanguage is set to 'Custom').

    .PARAMETER CustomMailTemplateBeforeDeviceDetails
    Custom text to display before the device list (only used when MailTemplateLanguage is set to 'Custom'). Supports Markdown formatting.

    .PARAMETER CustomMailTemplateAfterDeviceDetails
    Custom text to display after the device list (only used when MailTemplateLanguage is set to 'Custom'). Supports Markdown formatting.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Days": {
                "DisplayName": "Minimum Days Without Activity"
            },
            "MaxDays": {
                "DisplayName": "(Optional) Maximum Days Without Activity"
            },
            "Windows": {
                "DisplayName": "Include Windows Devices"
            },
            "MacOS": {
                "DisplayName": "Include macOS Devices"
            },
            "iOS": {
                "DisplayName": "Include iOS Devices"
            },
            "Android": {
                "DisplayName": "Include Android Devices"
            },
            "EmailFrom": {
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
                "DisplayName": "Use User Scope Filtering",
                "Hide": true
            },
            "IncludeUserGroup": {
                "DisplayName": "Users to include (Group)",
                "Hide": true
            },
            "ExcludeUserGroup": {
                "DisplayName": "Users to exclude (Group)",
                "Hide": true
            },
            "OverrideEmailRecipient": {
                "DisplayName": "(Optional) Override Email Recipient(s)"
            },
            "SendNoPrimaryUserDevicesToOverride": {
                "DisplayName": "Send Devices without Primary User to Override Recipient",
                "Hide": true
            },
            "OverrideUserNamePattern": {
                "DisplayName": "(Optional) Primary User Name Pattern for Override Routing (e.g. 'DEM-*')",
                "Hide": true
            },
            "MailTemplateLanguage": {
                "DisplayName": "Mail Template",
                "Hide": true
            },
            "CustomMailTemplateSubject": {
                "DisplayName": "Custom: Email Subject",
                "Hide": true
            },
            "CustomMailTemplateBeforeDeviceDetails": {
                "DisplayName": "Custom: Text Before Device List",
                "Hide": true
            },
            "CustomMailTemplateAfterDeviceDetails": {
                "DisplayName": "Custom: Text After Device List",
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        },
        "ParameterList": [
            {
                "DisplayName": "(Optional) Enable user scope filtering to include or exclude users based on group membership.",
                "DisplayAfter": "EmailFrom",
                "Default": false,
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - filter by group membership",
                            "Customization": {
                                "Hide": [],
                                "Show": ["IncludeUserGroup", "ExcludeUserGroup"],
                                "Default": {
                                    "UseUserScope": true
                                }
                            }
                        },
                        {
                            "Display": "No - send to all primary users",
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
                "DisplayName": "(Optional) Send inactive devices with no primary user to the Override Email Recipient. The rest will be sent to the users.",
                "DisplayAfter": "OverrideEmailRecipient",
                "Default": false,
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - devices without primary user (and pattern matches) go to the override recipient",
                            "Customization": {
                                "Hide": [],
                                "Show": ["OverrideUserNamePattern"],
                                "Default": {
                                    "SendNoPrimaryUserDevicesToOverride": true
                                }
                            }
                        },
                        {
                            "Display": "No - skip devices without primary user (default)",
                            "Customization": {
                                "Hide": ["OverrideUserNamePattern"],
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
                "DisplayName": "Select which email template to use",
                "DisplayAfter": "Android",
                "Default": "EN",
                "Select": {
                    "Options": [
                        {
                            "Display": "EN (English - Default)",
                            "Customization": {
                                "Default": {
                                    "MailTemplateLanguage": "EN"
                                }
                            },
                            "ParameterValue": "EN"
                        },
                        {
                            "Display": "DE (German)",
                            "Customization": {
                                "Default": {
                                    "MailTemplateLanguage": "DE"
                                }
                            },
                            "ParameterValue": "DE"
                        },
                        {
                            "Display": "Custom - Use Template from Runbook Customizations (Fallback is English)",
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }
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
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Include Users from Group" } )]
    [string]$IncludeUserGroup,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclude Users from Group" } )]
    [string]$ExcludeUserGroup,
    [string]$OverrideEmailRecipient,
    [bool] $SendNoPrimaryUserDevicesToOverride = $false,
    [string]$OverrideUserNamePattern = "",
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

$Version = "1.4.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
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
Write-RjRbLog -Message "SendNoPrimaryUserDevicesToOverride: $SendNoPrimaryUserDevicesToOverride" -Verbose
Write-RjRbLog -Message "OverrideUserNamePattern: $OverrideUserNamePattern" -Verbose
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
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -Verbose
    throw "The sender email address is required. This needs to be configured in the runbook customization."
    exit
}

# Validate override routing configuration
if ($SendNoPrimaryUserDevicesToOverride -and [string]::IsNullOrWhiteSpace($OverrideEmailRecipient)) {
    throw "SendNoPrimaryUserDevicesToOverride is enabled but OverrideEmailRecipient is empty. Configure at least one override recipient."
}
if (-not $SendNoPrimaryUserDevicesToOverride -and -not [string]::IsNullOrWhiteSpace($OverrideUserNamePattern)) {
    Write-Warning "OverrideUserNamePattern is set but SendNoPrimaryUserDevicesToOverride is disabled - the pattern will be ignored."
}

# Parse the comma-separated pattern list once
$overrideUserPatterns = @()
if ($SendNoPrimaryUserDevicesToOverride -and -not [string]::IsNullOrWhiteSpace($OverrideUserNamePattern)) {
    $overrideUserPatterns = @($OverrideUserNamePattern.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
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
    Write-Output "Found $($devicesWithoutUser.Count) stale devices without a primary user (will be sent to the override recipient)"
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

foreach ($userEmail in $devicesByUser.Keys) {
    $userDevices = $devicesByUser[$userEmail]

    # Determine actual recipient: with SendNoPrimaryUserDevicesToOverride only pattern-matched
    # users are redirected; otherwise a filled OverrideEmailRecipient redirects everyone
    $routeToOverride = $false
    if ($SendNoPrimaryUserDevicesToOverride) {
        foreach ($pattern in $overrideUserPatterns) {
            if ($userEmail -like $pattern) {
                $routeToOverride = $true
                break
            }
        }
        if ($routeToOverride) {
            $patternRoutedUsers++
        }
    }
    elseif (-not [string]::IsNullOrWhiteSpace($OverrideEmailRecipient)) {
        $routeToOverride = $true
    }

    $actualRecipient = if ($routeToOverride) {
        $OverrideEmailRecipient
    }
    else {
        $userEmail
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
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $actualRecipient -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version

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
    Write-Output "Processing $($devicesWithoutUser.Count) device(s) without primary user - Sending to: $($OverrideEmailRecipient)"

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
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $OverrideEmailRecipient -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version

        Write-Output "Email sent successfully to $($OverrideEmailRecipient)"
        Write-RjRbLog -Message "Email sent to $($OverrideEmailRecipient) for $($devicesWithoutUser.Count) device(s) without primary user" -Verbose
        $emailsSent++
    }
    catch {
        Write-Warning "Failed to send email to $($OverrideEmailRecipient) : $_"
        Write-RjRbLog -Message "Failed to send email to $($OverrideEmailRecipient) for devices without primary user : $_" -Verbose
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

if ($SendNoPrimaryUserDevicesToOverride) {
    Write-Output ""
    Write-Output "Override Routing Mode: Enabled"
    Write-Output "  - Devices without primary user: $($devicesWithoutUser.Count) (sent to: $($OverrideEmailRecipient))"
    if ($overrideUserPatterns.Count -gt 0) {
        Write-Output "  - Users matching pattern '$($OverrideUserNamePattern)': $($patternRoutedUsers) (sent to: $($OverrideEmailRecipient))"
    }
    Write-Output "  - All other notifications sent directly to end users"
}
elseif (-not [string]::IsNullOrWhiteSpace($OverrideEmailRecipient)) {
    Write-Output ""
    Write-Output "Override Recipient Mode: Enabled"
    Write-Output "  - All emails sent to: $($OverrideEmailRecipient)"
}

Write-Output ""
Write-Output "Done!"

#endregion

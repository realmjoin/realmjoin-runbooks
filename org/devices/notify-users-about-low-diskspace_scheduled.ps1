<#
    .SYNOPSIS
    Notify primary users about low disk space on their devices via email

    .DESCRIPTION
    Identifies Intune managed Windows and macOS devices whose free disk space is below a configurable threshold, either a fixed amount of free space in gigabytes or a percentage of the total disk size, and sends one personalized email per primary user.
    The email lists all affected devices of the user with their free and total disk space, rates each device as Critical or Warning and contains practical, platform-specific steps to free up space.
    The evaluation can be limited to critical devices, to devices with a recent Intune inventory, to the members of an Entra device group and to users included in or excluded by a group.
    A simulation mode lists the affected users and devices without sending anything, and a global override recipient redirects all notifications to a test or shared mailbox.

    .NOTES
    This runbook is the user-facing counterpart of the "Report Devices Low Diskspace" runbook. Both use the same threshold settings and the same
    Critical/Warning rating, so the report gives administrators the overview while this runbook asks the affected users to free up space themselves.

    Recipient resolution:
    The primary user of a device is resolved via the Entra object id that Intune reports in managedDevice.userId, so guest accounts and
    users whose current UPN differs from the address recorded at enrollment are resolved correctly. Devices for which Intune reports no
    userId fall back to a lookup by user principal name. The notification is sent to the user's mail attribute, with the UPN as fallback.

    Prerequisites:
    - EmailFrom parameter must be configured in runbook customization (RJReport.EmailSender setting)
    - Optional: Service Desk contact information can be configured (ServiceDesk_DisplayName, ServiceDesk_EMail, ServiceDesk_Phone, ServiceDesk_PortalUrl)

    Data source and freshness:
    The free and total disk space values are taken from the Intune hardware inventory of each device, which is refreshed with the regular device check-in.
    They describe the state of the last successful inventory and not necessarily the current state of the device. To avoid notifying users based on outdated
    numbers, devices whose last Intune sync is older than MaxInventoryAgeDays are skipped (0 disables this check).
    The "Report Devices Low Diskspace" runbook deliberately does not apply this filter, so it lists devices with a stale inventory as well - it can therefore show more
    devices than are notified here. The number skipped for an outdated inventory is reported in this runbook's output, which accounts for the difference.
    Devices that report a total disk size of zero bytes have no usable storage inventory and are excluded from the evaluation, but their number is reported.
    Only Windows and macOS devices are evaluated, because the storage inventory of mobile devices is less reliable and the cleanup guidance differs.

    Common Use Cases:
    - Recurring reminders to users whose devices are about to run out of disk space, before updates and app installations start to fail
    - Two-stage campaigns: report all devices below the threshold to administrators, notify only the critical ones (NotifyOnSeverity)
    - Staged rollouts per department or pilot group via the user and device group scope options
    - Excluding service or shared accounts via the exclude group

    Pilot and Testing Options:
    - Use SimulationMode to list the affected users and devices without sending any email
    - Use OverrideEmailRecipient to send all notifications to a test mailbox instead of end users
    - Perfect for validating email content and testing thresholds and filters before rolling out to production

    .PARAMETER ThresholdType
    Determines how low disk space is detected, either by a fixed amount of free space in gigabytes or by the percentage of free space relative to the disk size.

    .PARAMETER FreeSpaceThresholdGB
    Devices with less free disk space than this value in gigabytes are considered. Only used when the threshold type is set to free space in gigabytes.

    .PARAMETER FreeSpacePercentThreshold
    Devices with a lower percentage of free disk space than this value are considered. Only used when the threshold type is set to free space in percent.

    .PARAMETER NotifyOnSeverity
    Selects which devices trigger a notification: every device below the threshold (Warning and Critical) or only devices below half of the threshold (Critical only).

    .PARAMETER Windows
    Include Windows devices in the evaluation.

    .PARAMETER MacOS
    Include macOS devices in the evaluation.

    .PARAMETER MaxInventoryAgeDays
    Devices whose last Intune sync is older than this number of days are skipped, because their storage inventory is considered outdated. Devices without a last sync date are skipped as well. Set to 0 to disable the check.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization.

    .PARAMETER BrandingHeaderImageUrl
    Optional public HTTPS URL of a custom header image (PNG/JPEG/GIF, max. 200 KB) for the notification email.
    Sourced from the RJReport.Branding.HeaderImageUrl tenant setting. When empty, the default RealmJoin header graphic is used.

    .PARAMETER BrandingFooterImageUrl
    Optional public HTTPS URL of a custom footer image (PNG/JPEG/GIF, max. 200 KB) for the notification email.
    Sourced from the RJReport.Branding.FooterImageUrl tenant setting. When empty, the default RealmJoin footer graphic is used.

    .PARAMETER BrandingFooterLink
    Optional URL the footer image links to. Sourced from the RJReport.Branding.FooterLink tenant setting.
    When empty, the default link (https://www.realmjoin.com) is used.

    .PARAMETER BrandingAccentColor
    Optional accent color override (6-digit hex, e.g. '#0052cc') for the notification email template.
    Sourced from the RJReport.Branding.AccentColor tenant setting. When empty or invalid, the default RealmJoin accent color is used.

    .PARAMETER BrandingTextColor
    Optional text color override (6-digit hex) for the notification email template.
    Sourced from the RJReport.Branding.TextColor tenant setting. When empty or invalid, the default RealmJoin text color is used.

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
    Only notify users who are (transitive) members of this group. Requires UseUserScope to be enabled.

    .PARAMETER ExcludeUserGroup
    Do not notify users who are (transitive) members of this group. Requires UseUserScope to be enabled.

    .PARAMETER IncludeDeviceGroup
    Optional Entra device group. When set, only devices that are (transitive) members of this group are evaluated. Can be combined with the user scope.

    .PARAMETER OverrideEmailRecipient
    Optional: Global override - when set, ALL notifications are sent to this address instead of the end users. Can be comma-separated for multiple recipients. Perfect for testing and piloting, or for routing everything to a shared mailbox. If left empty, every user is mailed directly.

    .PARAMETER SimulationMode
    When enabled, the runbook lists the affected users and devices in the output but does not send any email.

    .PARAMETER MailTemplateLanguage
    Select which email template to use: EN (English, default), DE (German), or Custom (from Runbook Customizations).

    .PARAMETER CustomMailTemplateSubject
    Custom email subject line (only used when MailTemplateLanguage is set to 'Custom').

    .PARAMETER CustomMailTemplateBeforeDeviceDetails
    Custom text to display before the device list (only used when MailTemplateLanguage is set to 'Custom'). Supports Markdown formatting.

    .PARAMETER CustomMailTemplateAfterDeviceDetails
    Custom text to display after the device list (only used when MailTemplateLanguage is set to 'Custom'). Supports Markdown formatting. Replaces the built-in cleanup steps, so it should contain its own guidance.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "ThresholdType": {
                "DisplayName": "How should low disk space be determined?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Free space below a fixed size (GB)",
                            "Customization": {
                                "Show": [
                                    "FreeSpaceThresholdGB"
                                ],
                                "Hide": [
                                    "FreeSpacePercentThreshold"
                                ]
                            },
                            "ParameterValue": "Free space in GB"
                        },
                        {
                            "Display": "Free space below a percentage of the disk size (%)",
                            "Customization": {
                                "Show": [
                                    "FreeSpacePercentThreshold"
                                ],
                                "Hide": [
                                    "FreeSpaceThresholdGB"
                                ]
                            },
                            "ParameterValue": "Free space in percent"
                        }
                    ],
                    "ShowValue": false
                }
            },
            "FreeSpaceThresholdGB": {
                "DisplayName": "Low Disk Space Threshold (free GB)"
            },
            "FreeSpacePercentThreshold": {
                "DisplayName": "Low Disk Space Threshold (free %)",
                "Hide": true
            },
            "NotifyOnSeverity": {
                "DisplayName": "Which devices should trigger a notification?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Warning and Critical - every device below the threshold",
                            "ParameterValue": "Warning and Critical"
                        },
                        {
                            "Display": "Critical only - devices below half of the threshold",
                            "ParameterValue": "Critical only"
                        }
                    ],
                    "ShowValue": false
                }
            },
            "Windows": {
                "DisplayName": "Include Windows Devices"
            },
            "MacOS": {
                "DisplayName": "Include macOS Devices"
            },
            "MaxInventoryAgeDays": {
                "DisplayName": "Skip devices whose last Intune sync is older than (days, 0 = no limit)"
            },
            "IncludeDeviceGroup": {
                "DisplayName": "Limit to devices in group (optional)"
            },
            "OverrideEmailRecipient": {
                "DisplayName": "Redirect * ALL * Emails to Override Recipient(s)"
            },
            "SimulationMode": {
                "DisplayName": "Notification mode",
                "SelectSimple": {
                    "Send notifications to users": false,
                    "Simulation - list affected users only, send nothing": true
                }
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
                "DisplayAfter": "IncludeDeviceGroup",
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
                            "Display": "No - notify all primary users",
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
                "DisplayName": "Select which email template to use",
                "DisplayAfter": "SimulationMode",
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param(
    [ValidateSet('Free space in GB', 'Free space in percent')]
    [string] $ThresholdType = 'Free space in GB',
    [ValidateRange(1, 100000)]
    [int] $FreeSpaceThresholdGB = 20,
    [ValidateRange(1, 99)]
    [int] $FreeSpacePercentThreshold = 10,
    [ValidateSet('Warning and Critical', 'Critical only')]
    [string] $NotifyOnSeverity = 'Warning and Critical',
    [bool] $Windows = $true,
    [bool] $MacOS = $true,
    [ValidateRange(0, 3650)]
    [int] $MaxInventoryAgeDays = 14,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ } )]
    [string] $EmailFrom,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ } )]
    [string] $BrandingHeaderImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ } )]
    [string] $BrandingFooterImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ } )]
    [string] $BrandingFooterLink,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" -Value $_ } )]
    [string] $BrandingAccentColor,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" -Value $_ } )]
    [string] $BrandingTextColor,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_DisplayName" } )]
    [string] $ServiceDeskDisplayName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_EMail" } )]
    [string] $ServiceDeskEmail,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_Phone" } )]
    [string] $ServiceDeskPhone,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_PortalUrl" } )]
    [string] $ServiceDeskPortalUrl,
    [string] $ServiceDeskTicketUrl = "",
    [bool] $UseUserScope = $false,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Include Users from Group" } )]
    [string] $IncludeUserGroup,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclude Users from Group" } )]
    [string] $ExcludeUserGroup,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Limit to devices in group (optional)" } )]
    [string] $IncludeDeviceGroup,
    [string] $OverrideEmailRecipient,
    [bool] $SimulationMode = $false,
    [ValidateSet("EN", "DE", "Custom")]
    [string] $MailTemplateLanguage = "EN",
    [string] $CustomMailTemplateSubject,
    [string] $CustomMailTemplateBeforeDeviceDetails,
    [string] $CustomMailTemplateAfterDeviceDetails,
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

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "ThresholdType: $ThresholdType" -Verbose
Write-RjRbLog -Message "FreeSpaceThresholdGB: $FreeSpaceThresholdGB" -Verbose
Write-RjRbLog -Message "FreeSpacePercentThreshold: $FreeSpacePercentThreshold" -Verbose
Write-RjRbLog -Message "NotifyOnSeverity: $NotifyOnSeverity" -Verbose
Write-RjRbLog -Message "Windows: $Windows" -Verbose
Write-RjRbLog -Message "MacOS: $MacOS" -Verbose
Write-RjRbLog -Message "MaxInventoryAgeDays: $MaxInventoryAgeDays" -Verbose
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
Write-RjRbLog -Message "UseUserScope: $UseUserScope" -Verbose
Write-RjRbLog -Message "IncludeUserGroup: $IncludeUserGroup" -Verbose
Write-RjRbLog -Message "ExcludeUserGroup: $ExcludeUserGroup" -Verbose
Write-RjRbLog -Message "IncludeDeviceGroup: $IncludeDeviceGroup" -Verbose
Write-RjRbLog -Message "OverrideEmailRecipient: $OverrideEmailRecipient" -Verbose
Write-RjRbLog -Message "SimulationMode: $SimulationMode" -Verbose
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
}

# Validate override routing configuration
$globalOverrideActive = -not [string]::IsNullOrWhiteSpace($OverrideEmailRecipient)
if ($globalOverrideActive) {
    Write-Warning "OverrideEmailRecipient is set - ALL notifications are redirected to '$OverrideEmailRecipient'. No end user receives an email."
}

if ($SimulationMode) {
    Write-Warning "SimulationMode is enabled - affected users and devices are listed, no email is sent."
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

# At least one platform has to be evaluated
$selectedPlatforms = @()
if ($Windows) { $selectedPlatforms += 'Windows' }
if ($MacOS) { $selectedPlatforms += 'macOS' }

if ($selectedPlatforms.Count -eq 0) {
    throw "All platform filters are disabled. Enable at least one platform (Windows, macOS) to evaluate devices."
}

$platformSummary = $selectedPlatforms -join ', '

# User scope without any group has no effect
$userScopeConfigured = $UseUserScope -and (-not [string]::IsNullOrWhiteSpace($IncludeUserGroup) -or -not [string]::IsNullOrWhiteSpace($ExcludeUserGroup))
if ($UseUserScope -and -not $userScopeConfigured) {
    Write-Warning "UseUserScope is enabled but neither an include nor an exclude group is configured - all primary users are notified."
}

$deviceGroupActive = -not [string]::IsNullOrWhiteSpace($IncludeDeviceGroup)

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

function Get-PlatformKey {
    <#
        .SYNOPSIS
        Maps the operatingSystem value of a managed device to the platform key used for the cleanup tips.

        .PARAMETER OperatingSystem
        The operatingSystem value of the managed device as reported by Intune.
    #>
    param([string]$OperatingSystem)

    switch -Wildcard ($OperatingSystem) {
        "Windows*" { return 'Windows' }
        "macOS*" { return 'macOS' }
        default { return $null }
    }
}

function Test-PlatformIncluded {
    <#
        .SYNOPSIS
        Checks whether a device's operating system is included by the platform filter parameters.

        .PARAMETER OperatingSystem
        The operatingSystem value of the managed device as reported by Intune.
    #>
    param([string]$OperatingSystem)

    switch -Wildcard ($OperatingSystem) {
        "Windows*" { return $Windows }
        "macOS*" { return $MacOS }
        default { return $false }
    }
}

function Test-LowDiskSpace {
    <#
        .SYNOPSIS
        Checks whether a device is below the configured low disk space threshold.

        .PARAMETER FreeGB
        Free disk space of the device in gigabytes.

        .PARAMETER FreePercent
        Free disk space of the device as a percentage of its total disk size.
    #>
    param(
        [double]$FreeGB,
        [double]$FreePercent
    )

    if ($ThresholdType -eq 'Free space in percent') {
        return $FreePercent -lt $FreeSpacePercentThreshold
    }
    return $FreeGB -lt $FreeSpaceThresholdGB
}

function Get-DiskSeverity {
    <#
        .SYNOPSIS
        Rates how urgent the lack of free disk space on a device is.

        .DESCRIPTION
        Devices below half of the configured threshold are rated as Critical, all other devices below the threshold as Warning.

        .PARAMETER FreeGB
        Free disk space of the device in gigabytes.

        .PARAMETER FreePercent
        Free disk space of the device as a percentage of its total disk size.
    #>
    param(
        [double]$FreeGB,
        [double]$FreePercent
    )

    if ($ThresholdType -eq 'Free space in percent') {
        if ($FreePercent -lt ($FreeSpacePercentThreshold / 2)) { return 'Critical' }
    }
    elseif ($FreeGB -lt ($FreeSpaceThresholdGB / 2)) {
        return 'Critical'
    }
    return 'Warning'
}

function Get-GroupUserSet {
    <#
        .SYNOPSIS
        Resolves the transitive user members of a group into case-insensitive sets of object ids and user principal names.

        .DESCRIPTION
        Uses the transitiveMembers navigation with the user type cast, so nested group memberships are included.
        Both the object id and the user principal name are kept: a device is matched on the object id of its
        primary user whenever Intune reports one, because that id survives UPN changes and is unambiguous for
        guest accounts, and falls back to the UPN otherwise.
        A failing lookup stops the runbook, because a silently empty include group would notify every user
        and a silently empty exclude group would notify users that should have been excluded.

        .PARAMETER GroupId
        The object id of the group.

        .PARAMETER Label
        Label used in console output and error messages, e.g. "include" or "exclude".
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $idSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $upnSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $memberCount = 0

    # No Write-Output in this function: it returns its result on the success stream, and any progress
    # line written here would be captured into that return value, turning it into an Object[] and
    # flattening the HashSets. The caller prints the progress instead.
    try {
        $groupUri = "https://graph.microsoft.com/v1.0/groups/$GroupId/transitiveMembers/microsoft.graph.user?`$top=999&`$select=id,userPrincipalName"
        $members = Get-GraphPagedResult -Uri $groupUri
        foreach ($member in $members) {
            $memberCount++
            if (-not [string]::IsNullOrEmpty($member.id)) {
                [void]$idSet.Add($member.id)
            }
            if (-not [string]::IsNullOrEmpty($member.userPrincipalName)) {
                [void]$upnSet.Add($member.userPrincipalName)
            }
        }
    }
    catch {
        Write-Error "Failed to retrieve members of the $Label user group ('$GroupId'): $($_.Exception.Message)" -ErrorAction Continue
        throw "Unable to retrieve $Label user group membership"
    }

    return [PSCustomObject]@{
        Ids   = $idSet
        Upns  = $upnSet
        Count = $memberCount
    }
}

function Test-UserInScope {
    <#
        .SYNOPSIS
        Tests whether the primary user of a device belongs to a resolved user group scope.

        .DESCRIPTION
        Matches on the Entra object id whenever Intune reports one on the device; the user principal name is
        only used as a fallback for devices without a userId.

        .PARAMETER Scope
        A scope as returned by Get-GroupUserSet.

        .PARAMETER UserId
        The Entra object id of the device's primary user, if reported by Intune.

        .PARAMETER UserPrincipalName
        The user principal name of the device's primary user.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Scope,
        [string]$UserId,
        [string]$UserPrincipalName
    )

    if (-not [string]::IsNullOrWhiteSpace($UserId) -and $Scope.Ids.Contains($UserId)) { return $true }
    if (-not [string]::IsNullOrWhiteSpace($UserPrincipalName) -and $Scope.Upns.Contains($UserPrincipalName)) { return $true }
    return $false
}

function Get-GroupDeviceIdSet {
    <#
        .SYNOPSIS
        Resolves the transitive device members of a group into a case-insensitive set of Entra device ids.

        .DESCRIPTION
        Group members of type #microsoft.graph.device expose their Entra Device ID via the 'deviceId' property,
        which corresponds to the managedDevice 'azureADDeviceId'. Nested group memberships are included.

        .PARAMETER GroupId
        The object id of the device group.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )

    $deviceIdSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # No Write-Output here either - see the note in Get-GroupUserSet
    try {
        $groupUri = "https://graph.microsoft.com/v1.0/groups/$GroupId/transitiveMembers?`$select=id,deviceId,displayName"
        $members = Get-GraphPagedResult -Uri $groupUri
        foreach ($member in $members) {
            if ($member.'@odata.type' -eq '#microsoft.graph.device' -and -not [string]::IsNullOrEmpty($member.deviceId)) {
                [void]$deviceIdSet.Add($member.deviceId)
            }
        }
    }
    catch {
        Write-Error "Failed to retrieve members of the device group ('$GroupId'): $($_.Exception.Message)" -ErrorAction Continue
        throw "Unable to retrieve device group membership"
    }

    # The comma keeps PowerShell from enumerating the HashSet into loose strings, which would lose
    # the OrdinalIgnoreCase comparer and turn Contains() into case-sensitive array membership
    return , $deviceIdSet
}

function ConvertTo-GraphPathSegment {
    <#
        .SYNOPSIS
        Escapes a value for use as a single path segment of a Microsoft Graph URL.

        .DESCRIPTION
        Graph resolves a user principal name as a path segment, where '@' is a legal character (RFC 3986 pchar)
        and has to stay literal - percent-encoding it as '%40' breaks the route resolution of the $batch endpoint,
        which rejects the request with status 400 because the identifier then contains a '%'. Only '%' itself and
        '#' (guest accounts contain '#EXT#') actually need escaping. The '%' has to be replaced first, otherwise
        the escape sequence introduced for '#' would be escaped a second time.

        .PARAMETER Value
        The raw path segment, e.g. a user principal name.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return $Value.Replace('%', '%25').Replace('#', '%23')
}

function Resolve-NotificationUsers {
    <#
        .SYNOPSIS
        Resolves the mail address and account state of the users to notify via Graph JSON batching.

        .DESCRIPTION
        Each user is looked up individually to obtain the mail attribute and the accountEnabled flag. Intune
        reports the Entra object id of the primary user in managedDevice.userId, which is used as the lookup
        identifier whenever it is present: an object id needs no escaping and stays valid for guest accounts and
        for users whose current UPN differs from the address that Intune recorded at enrollment. Devices without
        a userId fall back to a lookup by user principal name.
        The requests are sent through the Graph $batch endpoint by the module function Invoke-RjRbGraphBatch, which
        handles the chunking (20 requests per call), the transport and the retry of throttled inner requests
        (status 429) with the Retry-After interval reported by Graph. Lookups that are still throttled after the
        last retry and other failed lookups are marked and reported so that the affected users are skipped instead
        of aborting the run.

        .PARAMETER Users
        The user identities to resolve, as objects with Key, Id and UserPrincipalName.
    #>
    param(
        [array]$Users
    )

    $resolvedUsers = @{}

    # The request id has to be a string; a sequential counter is mapped back to the user identity
    $userByRequestId = @{}
    $requestCounter = 0
    $requests = foreach ($user in $Users) {
        $requestCounter++
        $userByRequestId["$requestCounter"] = $user
        $identifier = if (-not [string]::IsNullOrWhiteSpace($user.Id)) {
            $user.Id
        }
        else {
            ConvertTo-GraphPathSegment -Value $user.UserPrincipalName
        }
        @{
            id     = "$requestCounter"
            method = "GET"
            # The identifier MUST be wrapped in a subexpression: '?' is a legal character in an unbraced
            # PowerShell variable name (cf. the automatic variable $?), so "$identifier?" would parse as the
            # undefined variable 'identifier?' and silently drop the user from the URL.
            url    = "/users/$($identifier)?`$select=id,displayName,mail,userPrincipalName,accountEnabled"
        }
    }

    if ($requestCounter -gt 0) {
        $responses = Invoke-RjRbGraphBatch -Requests @($requests) -ProgressLabel "user lookups" -ProgressInterval 10

        foreach ($item in $responses) {
            $user = $userByRequestId["$($item.id)"]
            if (-not $user) { continue }

            # Prefer the UPN in log lines; devices without one are only identifiable by their user object id
            $identityLabel = if (-not [string]::IsNullOrWhiteSpace($user.UserPrincipalName)) { $user.UserPrincipalName } else { $user.Id }

            if ($item.status -eq 200) {
                $mail = $item.body.mail
                # The UPN returned by Graph is authoritative; the one recorded by Intune can be outdated
                $upn = if (-not [string]::IsNullOrWhiteSpace($item.body.userPrincipalName)) { $item.body.userPrincipalName } else { $user.UserPrincipalName }
                $resolvedUsers[$user.Key] = [PSCustomObject]@{
                    UserPrincipalName = $upn
                    DisplayName       = $item.body.displayName
                    Recipient         = if (-not [string]::IsNullOrWhiteSpace($mail)) { $mail } else { $upn }
                    AccountEnabled    = [bool]$item.body.accountEnabled
                    LookupFailed      = $false
                    FailureStatus     = $null
                }
            }
            elseif ($item.status -eq 429) {
                # Still throttled after the retries of Invoke-RjRbGraphBatch - handled as a missing result below
                Write-RjRbLog -Message "User lookup for '$identityLabel' was still throttled after the retries." -Verbose
            }
            else {
                # The Graph error body carries the actual reason - a bare status code is not diagnosable
                $errorCode = $item.body.error.code
                $errorMessage = $item.body.error.message
                $errorDetail = if ($errorCode -or $errorMessage) { " - $($errorCode): $($errorMessage)" } else { "" }
                Write-RjRbLog -Message "User lookup for '$identityLabel' failed with status $($item.status).$errorDetail" -Verbose
                $resolvedUsers[$user.Key] = [PSCustomObject]@{
                    UserPrincipalName = $user.UserPrincipalName
                    DisplayName       = $null
                    Recipient         = $null
                    AccountEnabled    = $false
                    LookupFailed      = $true
                    FailureStatus     = $item.status
                }
            }
        }
    }

    # Users that are still throttled after the retries, or that received no response at all, count as failed lookups
    foreach ($user in $Users) {
        if (-not $resolvedUsers.ContainsKey($user.Key)) {
            $identityLabel = if (-not [string]::IsNullOrWhiteSpace($user.UserPrincipalName)) { $user.UserPrincipalName } else { $user.Id }
            Write-RjRbLog -Message "User lookup for '$identityLabel' returned no result." -Verbose
            $resolvedUsers[$user.Key] = [PSCustomObject]@{
                UserPrincipalName = $user.UserPrincipalName
                DisplayName       = $null
                Recipient         = $null
                AccountEnabled    = $false
                LookupFailed      = $true
                FailureStatus     = $null
            }
        }
    }

    return $resolvedUsers
}

function Get-MailTemplate {
    <#
        .SYNOPSIS
        Returns the mail template based on the selected language or custom template.

        .DESCRIPTION
        The built-in templates contain the subject lines, the introduction, the platform-specific cleanup steps
        and the closing text. The custom template only provides subject, introduction and closing text - the
        cleanup steps are left empty, so the custom closing text should contain its own guidance.
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
        SubjectCritical     = ""
        BeforeDeviceDetails = ""
        TipsIntro           = ""
        TipsWindows         = ""
        TipsMacOS           = ""
        AfterDeviceDetails  = ""
    }

    switch ($Language) {
        "EN" {
            $template.Subject = "Action Required: Low Disk Space on Your Device"
            $template.SubjectCritical = "Urgent: Critically Low Disk Space on Your Device"
            $template.BeforeDeviceDetails = "Dear user,`n`nThe following device(s) assigned to your account reported"
            $template.TipsIntro = @"
## What You Can Do Now

The steps below usually free up a significant amount of space and only take a few minutes. Please do not delete files you are unsure about - if in doubt, ask your Service Desk.
"@
            $template.TipsWindows = @"
### Windows

1. **Run Storage Sense:** Open *Settings > System > Storage*, turn on Storage Sense and choose *Run Storage Sense now* to remove temporary files automatically
2. **Clean up system files:** Search for *Disk Cleanup* in the Start menu, choose *Clean up system files* and remove temporary files, delivery optimization files and previous Windows installations
3. **Empty the Recycle Bin**
4. **Clean up your Downloads folder:** Delete installers, archives and files you no longer need
5. **Free up space in OneDrive:** Right-click synced folders in File Explorer and choose *Free up space* - the files stay available online without using local disk space
6. **Uninstall apps you no longer use:** *Settings > Apps > Installed apps*
7. **Clear caches:** Sign out of Microsoft Teams and clear its cache, and clear your browser cache
8. **Move large personal files:** Videos, photos and archives belong in OneDrive or on external storage rather than on the local disk
"@
            $template.TipsMacOS = @"
### macOS

1. **Check the storage recommendations:** Open the *Apple menu > System Settings > General > Storage* and review the recommendations
2. **Optimize storage:** Enable *Store in iCloud* and *Optimize Storage* so rarely used files are kept online only
3. **Empty the Trash:** Turn on *Empty Trash automatically* to delete items after 30 days
4. **Clean up your Downloads folder:** Delete installers, archives and files you no longer need
5. **Remove applications you no longer use** from the Applications folder
6. **Complete a Time Machine backup:** Local snapshots are removed automatically once a backup to the backup disk has completed
"@
            $template.AfterDeviceDetails = @"
## Why Is This Important?

- **Updates:** Security and feature updates need free disk space and fail when the disk is full
- **Applications:** Installations and updates of required applications can fail
- **Performance and data:** A full disk slows the device down and can cause synchronization errors (OneDrive, email)

## Questions?

If you have any questions or need help freeing up space, please contact your Service Desk.
"@
        }
        "DE" {
            $template.Subject = "Handlungsbedarf: Wenig freier Speicherplatz auf Ihrem Gerät"
            $template.SubjectCritical = "Dringend: Kritisch wenig freier Speicherplatz auf Ihrem Gerät"
            $template.BeforeDeviceDetails = "Liebe Nutzerin, lieber Nutzer,`n`nfür die folgenden Geräte, die Ihrem Konto zugeordnet sind, wurde"
            $template.TipsIntro = @"
## Was Sie jetzt tun können

Die folgenden Schritte schaffen in der Regel viel Platz und dauern nur wenige Minuten. Bitte löschen Sie keine Dateien, bei denen Sie unsicher sind - fragen Sie im Zweifel Ihren Service Desk.
"@
            $template.TipsWindows = @"
### Windows

1. **Speicheroptimierung ausführen:** Öffnen Sie *Einstellungen > System > Speicher*, aktivieren Sie die Speicheroptimierung und wählen Sie *Speicheroptimierung jetzt ausführen*, um temporäre Dateien automatisch zu entfernen
2. **Systemdateien bereinigen:** Suchen Sie im Startmenü nach *Datenträgerbereinigung*, wählen Sie *Systemdateien bereinigen* und entfernen Sie temporäre Dateien, Übermittlungsoptimierungsdateien und vorherige Windows-Installationen
3. **Papierkorb leeren**
4. **Downloads-Ordner aufräumen:** Löschen Sie Installationsdateien, Archive und Dateien, die Sie nicht mehr benötigen
5. **Speicherplatz in OneDrive freigeben:** Klicken Sie im Explorer mit der rechten Maustaste auf synchronisierte Ordner und wählen Sie *Speicherplatz freigeben* - die Dateien bleiben online verfügbar, belegen aber keinen lokalen Speicher mehr
6. **Nicht mehr benötigte Apps deinstallieren:** *Einstellungen > Apps > Installierte Apps*
7. **Caches leeren:** Melden Sie sich von Microsoft Teams ab und leeren Sie dessen Cache sowie den Cache Ihres Browsers
8. **Große persönliche Dateien auslagern:** Videos, Fotos und Archive gehören in OneDrive oder auf einen externen Datenträger statt auf die lokale Festplatte
"@
            $template.TipsMacOS = @"
### macOS

1. **Speicherempfehlungen prüfen:** Öffnen Sie *Apple-Menü > Systemeinstellungen > Allgemein > Speicher* und sehen Sie sich die Empfehlungen an
2. **Speicher optimieren:** Aktivieren Sie *In iCloud speichern* und *Speicher optimieren*, damit selten genutzte Dateien nur noch online vorgehalten werden
3. **Papierkorb leeren:** Aktivieren Sie *Papierkorb automatisch leeren*, damit Objekte nach 30 Tagen gelöscht werden
4. **Downloads-Ordner aufräumen:** Löschen Sie Installationsdateien, Archive und Dateien, die Sie nicht mehr benötigen
5. **Nicht mehr benötigte Programme entfernen** aus dem Ordner Programme
6. **Time-Machine-Backup abschließen:** Lokale Schnappschüsse werden automatisch entfernt, sobald ein Backup auf das Backup-Volume abgeschlossen ist
"@
            $template.AfterDeviceDetails = @"
## Warum ist das wichtig?

- **Updates:** Sicherheits- und Funktionsupdates benötigen freien Speicherplatz und schlagen bei voller Festplatte fehl
- **Anwendungen:** Installationen und Updates benötigter Anwendungen können fehlschlagen
- **Leistung und Daten:** Eine volle Festplatte verlangsamt das Gerät und kann zu Synchronisationsfehlern führen (OneDrive, E-Mail)

## Fragen?

Wenn Sie Fragen haben oder Hilfe beim Freigeben von Speicherplatz benötigen, wenden Sie sich bitte an Ihren Service Desk.
"@
        }
        "Custom" {
            $template.Subject = $CustomSubject
            $template.SubjectCritical = $CustomSubject
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

        .PARAMETER Devices
        The processed device objects of one user.

        .PARAMETER MailTemplateLanguage
        The selected mail template language; labels are German for DE and English otherwise.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Devices,
        [Parameter(Mandatory = $true)]
        [string]$MailTemplateLanguage
    )

    $isGerman = $MailTemplateLanguage -eq "DE"
    $osLabel = if ($isGerman) { "Betriebssystem" } else { "Operating System" }
    $modelLabel = if ($isGerman) { "Modell" } else { "Model" }
    $freeSpaceLabel = if ($isGerman) { "Freier Speicherplatz" } else { "Free disk space" }
    $ofLabel = if ($isGerman) { "von" } else { "of" }
    $statusLabel = "Status"
    $lastInventoryLabel = if ($isGerman) { "Letzte Inventur" } else { "Last inventory" }
    $criticalText = if ($isGerman) { "Kritisch - bitte umgehend handeln" } else { "Critical - please act now" }
    $warningText = if ($isGerman) { "Warnung - bitte zeitnah Speicherplatz freigeben" } else { "Warning - please free up space soon" }

    $deviceListMarkdown = ""
    foreach ($device in $Devices) {
        $statusText = if ($device.Severity -eq 'Critical') { $criticalText } else { $warningText }
        $modelValue = (("$($device.Manufacturer) $($device.Model)").Trim())
        if (-not $modelValue) { $modelValue = "N/A" }

        $deviceListMarkdown += @"
### $($device.DeviceName)

- **$($osLabel):** $($device.OperatingSystem) $($device.OSVersion)
- **$($modelLabel):** $modelValue
- **$($freeSpaceLabel):** $($device.FreeSpaceGB) GB $ofLabel $($device.TotalSpaceGB) GB ($($device.FreePercent) %)
- **$($statusLabel):** $statusText
- **$($lastInventoryLabel):** $($device.LastSync)


"@
    }

    return $deviceListMarkdown
}

function Get-StorageTipsMarkdown {
    <#
        .SYNOPSIS
        Builds the cleanup tips section for the platforms of a user's affected devices.

        .PARAMETER Template
        The mail template hashtable returned by Get-MailTemplate.

        .PARAMETER Platforms
        The distinct platform keys ('Windows', 'macOS') of the user's affected devices.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Template,
        [array]$Platforms
    )

    # The custom template does not provide tips (it is expected to bring its own guidance)
    if ([string]::IsNullOrWhiteSpace($Template.TipsIntro)) {
        return ""
    }

    $sections = @($Template.TipsIntro)
    if ('Windows' -in $Platforms) { $sections += $Template.TipsWindows }
    if ('macOS' -in $Platforms) { $sections += $Template.TipsMacOS }

    return ($sections -join "`n`n")
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
    Write-Error "Failed to connect to Microsoft Graph: $($_)"
    throw
}

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

# Connect RJ RunbookHelper for email sending
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

#endregion

########################################################
#region     Data Collection
########################################################

# The threshold text is reused in the console output and in the notification emails
$thresholdText = if ($ThresholdType -eq 'Free space in percent') {
    "less than **$($FreeSpacePercentThreshold) %** free disk space"
}
else {
    "less than **$($FreeSpaceThresholdGB) GB** free disk space"
}
$thresholdTextPlain = $thresholdText -replace '\*\*', ''

Write-Output ""
Write-Output "Evaluating devices with $($thresholdTextPlain)"
Write-Output "Notify on severity: $($NotifyOnSeverity)"
Write-Output "Included platforms: $($platformSummary)"
if ($MaxInventoryAgeDays -gt 0) {
    Write-Output "Devices whose last Intune sync is older than $($MaxInventoryAgeDays) day(s) are skipped."
}
Write-Output "Note: This may take a while depending on the number of devices in your tenant."
Write-Output ""

# Resolve the optional scope filters first, so that a broken group configuration stops the run before any evaluation
$includeDeviceIds = $null
if ($deviceGroupActive) {
    Write-Output "Retrieving members of the device group (including nested groups)..."
    $includeDeviceIds = Get-GroupDeviceIdSet -GroupId $IncludeDeviceGroup
    Write-Output "The device group contains $($includeDeviceIds.Count) device(s)."
}

$includeUserScope = $null
$excludeUserScope = $null
if ($userScopeConfigured) {
    if (-not [string]::IsNullOrWhiteSpace($IncludeUserGroup)) {
        Write-Output "Retrieving members of the include user group (including nested groups)..."
        $includeUserScope = Get-GroupUserSet -GroupId $IncludeUserGroup -Label "include"
        Write-Output "The include user group contains $($includeUserScope.Count) user(s)."
    }
    if (-not [string]::IsNullOrWhiteSpace($ExcludeUserGroup)) {
        Write-Output "Retrieving members of the exclude user group (including nested groups)..."
        $excludeUserScope = Get-GroupUserSet -GroupId $ExcludeUserGroup -Label "exclude"
        Write-Output "The exclude user group contains $($excludeUserScope.Count) user(s)."
    }
}

# The storage properties cannot be used in an OData filter, so all devices are retrieved
# with a narrow property projection and evaluated locally.
$selectProperties = @(
    'id'
    'azureADDeviceId'
    'deviceName'
    'userId'
    'userPrincipalName'
    'userDisplayName'
    'serialNumber'
    'manufacturer'
    'model'
    'operatingSystem'
    'osVersion'
    'lastSyncDateTime'
    'freeStorageSpaceInBytes'
    'totalStorageSpaceInBytes'
)
$selectString = ($selectProperties -join ',')

Write-Output ""
Write-Output "Listing managed devices..."
$devicesUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=$selectString"
$devices = Get-GraphPagedResult -Uri $devicesUri
$totalDevicesScanned = ($devices | Measure-Object).Count
Write-Output "Found $($totalDevicesScanned) managed device(s) before filtering"

#endregion

########################################################
#region     Data Processing
########################################################

$flaggedDevices = @()
$devicesByUser = @{}
$devicesWithoutUser = @()
$devicesEvaluated = 0
$devicesSkippedByDeviceGroup = 0
$devicesWithoutStorageData = 0
$devicesInventoryOutdated = 0
$devicesExcludedBySeverity = 0
$devicesSkippedByUserScope = 0

$inventoryCutoff = if ($MaxInventoryAgeDays -gt 0) { (Get-Date).AddDays(-$MaxInventoryAgeDays) } else { $null }

foreach ($device in $devices) {
    if (-not (Test-PlatformIncluded -OperatingSystem $device.operatingSystem)) {
        continue
    }

    # Optional device group scope, matched via the Entra device id
    if ($deviceGroupActive) {
        $azureAdDeviceId = if ($device.azureADDeviceId) { "$($device.azureADDeviceId)" } else { "" }
        if (-not $azureAdDeviceId -or -not $includeDeviceIds.Contains($azureAdDeviceId)) {
            $devicesSkippedByDeviceGroup++
            continue
        }
    }

    $devicesEvaluated++

    $totalBytes = [double]($device.totalStorageSpaceInBytes)
    $freeBytes = [double]($device.freeStorageSpaceInBytes)

    # Devices without a usable hardware inventory report a total size of zero and cannot be rated
    if ($totalBytes -le 0 -or $freeBytes -lt 0) {
        $devicesWithoutStorageData++
        Write-RjRbLog -Message "Skipping device '$($device.deviceName)' - no usable storage inventory (total: $($device.totalStorageSpaceInBytes), free: $($device.freeStorageSpaceInBytes))" -Verbose
        continue
    }

    # Devices with an outdated inventory are skipped, so users are not notified based on stale numbers
    $lastSyncDateTime = if ($device.lastSyncDateTime) { Get-Date $device.lastSyncDateTime } else { $null }
    if ($null -ne $inventoryCutoff) {
        if ($null -eq $lastSyncDateTime -or $lastSyncDateTime -lt $inventoryCutoff) {
            $devicesInventoryOutdated++
            Write-RjRbLog -Message "Skipping device '$($device.deviceName)' - last sync $($device.lastSyncDateTime) is older than $MaxInventoryAgeDays day(s)" -Verbose
            continue
        }
    }

    # Exact values drive the threshold test and the severity rating; the rounded ones are for display
    # only. Comparing rounded values would shift the effective boundary by up to half a percentage
    # point, silently dropping devices that are measurably below the configured threshold.
    $freeSpaceGBExact = $freeBytes / 1GB
    $freePercentExact = ($freeBytes / $totalBytes) * 100

    $freeSpaceGB = [math]::Round($freeSpaceGBExact, 1)
    $totalSpaceGB = [math]::Round($totalBytes / 1GB, 1)
    $freePercent = [int][math]::Round($freePercentExact, 0)

    if (-not (Test-LowDiskSpace -FreeGB $freeSpaceGBExact -FreePercent $freePercentExact)) {
        continue
    }

    $severity = Get-DiskSeverity -FreeGB $freeSpaceGBExact -FreePercent $freePercentExact

    $flaggedDevice = [PSCustomObject]@{
        DeviceName       = $device.deviceName
        PrimaryUserId    = $device.userId
        PrimaryUser      = $device.userPrincipalName
        UserDisplayName  = $device.userDisplayName
        OperatingSystem  = $device.operatingSystem
        OSVersion        = $device.osVersion
        PlatformKey      = Get-PlatformKey -OperatingSystem $device.operatingSystem
        Manufacturer     = if ($null -ne $device.manufacturer) { $device.manufacturer } else { "" }
        Model            = if ($null -ne $device.model) { $device.model } else { "" }
        SerialNumber     = $device.serialNumber
        FreeSpaceGB      = $freeSpaceGB
        TotalSpaceGB     = $totalSpaceGB
        FreePercent      = $freePercent
        Severity         = $severity
        LastSync         = if ($lastSyncDateTime) { $lastSyncDateTime.ToString("yyyy-MM-dd") } else { "N/A" }
        LastSyncDateTime = $lastSyncDateTime
        DeviceId         = $device.id
        AzureADDeviceId  = $device.azureADDeviceId
    }
    $flaggedDevices += $flaggedDevice

    if ($NotifyOnSeverity -eq 'Critical only' -and $severity -ne 'Critical') {
        $devicesExcludedBySeverity++
        continue
    }

    # Devices without a primary user cannot be notified; they are listed in the output for central follow-up
    if ([string]::IsNullOrWhiteSpace($device.userPrincipalName)) {
        $devicesWithoutUser += $flaggedDevice
        Write-RjRbLog -Message "Skipping device '$($device.deviceName)' - no primary user assigned" -Verbose
        continue
    }

    # Optional user scope, matched via the primary user's object id and, as a fallback, its UPN
    if ($userScopeConfigured) {
        if ($null -ne $includeUserScope -and -not (Test-UserInScope -Scope $includeUserScope -UserId $device.userId -UserPrincipalName $device.userPrincipalName)) {
            $devicesSkippedByUserScope++
            Write-RjRbLog -Message "Skipping device '$($device.deviceName)' - user '$($device.userPrincipalName)' is not in the include group" -Verbose
            continue
        }
        if ($null -ne $excludeUserScope -and (Test-UserInScope -Scope $excludeUserScope -UserId $device.userId -UserPrincipalName $device.userPrincipalName)) {
            $devicesSkippedByUserScope++
            Write-RjRbLog -Message "Skipping device '$($device.deviceName)' - user '$($device.userPrincipalName)' is in the exclude group" -Verbose
            continue
        }
    }

    # Group on the primary user's object id when Intune reports one - it survives UPN changes and is
    # unambiguous for guest accounts; devices without a userId fall back to the lowercased UPN
    $userKey = if (-not [string]::IsNullOrWhiteSpace($device.userId)) { $device.userId.ToLowerInvariant() } else { $device.userPrincipalName.ToLowerInvariant() }
    if (-not $devicesByUser.ContainsKey($userKey)) {
        $devicesByUser[$userKey] = @()
    }
    $devicesByUser[$userKey] += $flaggedDevice
}

# Worst devices first, both in the overall list and per user
$flaggedDevices = @($flaggedDevices | Sort-Object -Property FreeSpaceGB, FreePercent)
foreach ($userKey in @($devicesByUser.Keys)) {
    $devicesByUser[$userKey] = @($devicesByUser[$userKey] | Sort-Object -Property FreeSpaceGB, FreePercent)
}

$criticalCount = ($flaggedDevices | Where-Object { $_.Severity -eq 'Critical' } | Measure-Object).Count
$warningCount = ($flaggedDevices | Where-Object { $_.Severity -eq 'Warning' } | Measure-Object).Count

# Resolve the recipients (mail attribute, account state) of all users with affected devices
$usersToNotify = @()
$usersSkippedDisabled = @()
$usersSkippedLookupFailed = @()
$lookupPermissionDenied = $false

if ($devicesByUser.Count -gt 0) {
    Write-Output ""
    Write-Output "Resolving $($devicesByUser.Count) user(s) with affected devices..."

    $userIdentities = @($devicesByUser.Keys | ForEach-Object {
            $firstDevice = $devicesByUser[$_][0]
            [PSCustomObject]@{
                Key               = $_
                Id                = $firstDevice.PrimaryUserId
                UserPrincipalName = $firstDevice.PrimaryUser
            }
        })
    $resolvedUsers = Resolve-NotificationUsers -Users $userIdentities

    foreach ($userKey in ($devicesByUser.Keys | Sort-Object)) {
        $userDevices = $devicesByUser[$userKey]
        $userInfo = $resolvedUsers[$userKey]

        if ($null -eq $userInfo -or $userInfo.LookupFailed) {
            $usersSkippedLookupFailed += $userDevices[0].PrimaryUser
            if ($null -ne $userInfo -and $userInfo.FailureStatus -in 401, 403) {
                $lookupPermissionDenied = $true
            }
            continue
        }
        if (-not $userInfo.AccountEnabled) {
            $usersSkippedDisabled += $userInfo.UserPrincipalName
            Write-RjRbLog -Message "Skipping user '$($userInfo.UserPrincipalName)' - account is disabled" -Verbose
            continue
        }

        $usersToNotify += [PSCustomObject]@{
            UserPrincipalName = $userInfo.UserPrincipalName
            DisplayName       = $userInfo.DisplayName
            Recipient         = $userInfo.Recipient
            Devices           = $userDevices
            WorstSeverity     = if (($userDevices | Where-Object { $_.Severity -eq 'Critical' } | Measure-Object).Count -gt 0) { 'Critical' } else { 'Warning' }
            Platforms         = @($userDevices | ForEach-Object { $_.PlatformKey } | Where-Object { $_ } | Select-Object -Unique)
        }
    }

    if ($usersSkippedLookupFailed.Count -gt 0 -and $usersToNotify.Count -eq 0 -and $usersSkippedDisabled.Count -eq 0) {
        if ($lookupPermissionDenied) {
            Write-Warning "None of the affected users could be resolved via Microsoft Graph - the lookups were denied. Check that the managed identity has the User.Read.All permission."
        }
        else {
            Write-Warning "None of the affected users could be resolved via Microsoft Graph. The verbose log lists the Graph error of each individual lookup."
        }
    }
}

#endregion

########################################################
#region     Output
########################################################

Write-Output ""
Write-Output "Summary of devices with low disk space for $($tenantDisplayName):"
Write-Output "Devices scanned: $($totalDevicesScanned)"
if ($deviceGroupActive) {
    Write-Output "Devices skipped - not in device group: $($devicesSkippedByDeviceGroup)"
}
Write-Output "Devices evaluated (after platform and device group filter): $($devicesEvaluated)"
Write-Output "Devices without usable storage inventory (excluded): $($devicesWithoutStorageData)"
if ($MaxInventoryAgeDays -gt 0) {
    Write-Output "Devices skipped - inventory outdated (last sync older than $($MaxInventoryAgeDays) day(s)): $($devicesInventoryOutdated)"
}
Write-Output "Devices below the threshold: $($flaggedDevices.Count)"
Write-Output "  Critical: $($criticalCount)"
Write-Output "  Warning: $($warningCount)"
if ($NotifyOnSeverity -eq 'Critical only') {
    Write-Output "Devices excluded by severity selector (Warning): $($devicesExcludedBySeverity)"
}
Write-Output "Devices without primary user (skipped): $($devicesWithoutUser.Count)"
if ($userScopeConfigured) {
    Write-Output "Devices skipped by user scope: $($devicesSkippedByUserScope)"
}
Write-Output "Users with affected devices: $($devicesByUser.Count)"
Write-Output ""

if ($flaggedDevices.Count -eq 0) {
    Write-Output "No devices found matching the low disk space criteria."
}
else {
    Write-Output "Detailed list of devices with low disk space:"
    Write-Output ""

    $displayDevices = @()
    foreach ($device in $flaggedDevices) {
        $displayDevices += [PSCustomObject]@{
            FreeGB      = $device.FreeSpaceGB
            FreePercent = $device.FreePercent
            TotalGB     = $device.TotalSpaceGB
            Severity    = $device.Severity
            DeviceName  = if ($device.DeviceName -and $device.DeviceName.Length -gt 15) { $device.DeviceName.Substring(0, 14) + ".." } elseif ($device.DeviceName) { $device.DeviceName } else { "N/A" }
            OS          = $device.PlatformKey
            PrimaryUser = if ($device.PrimaryUser -and $device.PrimaryUser.Length -gt 30) { $device.PrimaryUser.Substring(0, 29) + ".." } elseif ($device.PrimaryUser) { $device.PrimaryUser } else { "N/A" }
            LastSync    = $device.LastSync
        }
    }

    $displayDevices | Format-Table -AutoSize
}

if ($devicesWithoutUser.Count -gt 0) {
    Write-Output ""
    Write-Output "Devices without a primary user (no notification possible, please review centrally):"
    $devicesWithoutUser | Select-Object DeviceName, @{ Name = 'OS'; Expression = { $_.PlatformKey } }, FreeSpaceGB, FreePercent, Severity, LastSync | Format-Table -AutoSize
}

if ($usersSkippedDisabled.Count -gt 0) {
    Write-Output ""
    Write-Output "Users skipped because their account is disabled:"
    $usersSkippedDisabled | ForEach-Object { Write-Output "  - $_" }
}

if ($usersSkippedLookupFailed.Count -gt 0) {
    Write-Output ""
    Write-Output "Users skipped because the user lookup failed:"
    $usersSkippedLookupFailed | ForEach-Object { Write-Output "  - $_" }
}

#endregion

########################################################
#region     Email Notifications
########################################################

Write-Output ""
if ($SimulationMode) {
    Write-Output "## Simulation - listing users that would be notified (no email is sent)..."
}
else {
    Write-Output "## Sending email notifications to users..."
}
Write-Output ""

$emailsSent = 0
$emailsFailed = 0
$emailsSimulated = 0

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

# Localized text fragments that are identical for every user
$isGermanTemplate = $MailTemplateLanguage -eq "DE"

$emailHeader = if ($isGermanTemplate) {
    "# Wenig freier Speicherplatz - Handlungsbedarf"
}
else {
    "# Low Disk Space - Action Required"
}

$autoGeneratedNote = if ($isGermanTemplate) {
    "*Diese E-Mail wurde automatisch generiert. Bitte antworten Sie nicht auf diese E-Mail.*"
}
else {
    "*This email was automatically generated. Please do not reply to this email.*"
}

$thresholdSentence = switch ($MailTemplateLanguage) {
    "DE" {
        if ($ThresholdType -eq 'Free space in percent') { "weniger als **$($FreeSpacePercentThreshold) %** freier Speicherplatz gemeldet" }
        else { "weniger als **$($FreeSpaceThresholdGB) GB** freier Speicherplatz gemeldet" }
    }
    "EN" { $thresholdText }
    "Custom" { "" }
}

$criticalSentence = if ($isGermanTemplate) {
    ". Mindestens ein Gerät hat **kritisch wenig** freien Speicherplatz - bitte schaffen Sie noch heute Platz"
}
else {
    ". At least one device is **critically low** on free space - please free up space today"
}

$brandingMailParams = @{}
if (-not $SimulationMode -and $usersToNotify.Count -gt 0) {
    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor
}

foreach ($user in $usersToNotify) {
    $userDevices = $user.Devices
    $userIsCritical = $user.WorstSeverity -eq 'Critical'

    # Determine actual recipient: the global override wins, otherwise the user's mail address
    $actualRecipient = if ($globalOverrideActive) { $OverrideEmailRecipient } else { $user.Recipient }

    if ($SimulationMode) {
        Write-Output "Would notify user: $($user.UserPrincipalName) ($($userDevices.Count) device(s), worst: $($user.WorstSeverity)) - Recipient: $($actualRecipient)"
        $emailsSimulated++
        continue
    }

    Write-Output "Processing user: $($user.UserPrincipalName) ($($userDevices.Count) device(s), worst: $($user.WorstSeverity)) - Sending to: $($actualRecipient)"

    # Build email subject (severity-aware, user appended when redirected)
    $emailSubject = if ($userIsCritical) { $mailTemplate.SubjectCritical } else { $mailTemplate.Subject }
    if ($globalOverrideActive) {
        $emailSubject = "$($emailSubject) - User: $($user.UserPrincipalName)"
    }

    # Build override recipient note
    $overrideNote = ""
    if ($globalOverrideActive) {
        $overrideNote = if ($isGermanTemplate) {
            "**Hinweis:** Diese E-Mail wurde an Sie statt an den Endbenutzer gesendet.`n`n**Betroffener Benutzer:** $($user.UserPrincipalName)`n"
        }
        else {
            "**Note:** This email was sent to you instead of the end user.`n`n**Affected User:** $($user.UserPrincipalName)`n"
        }
    }

    # Introduction: the built-in templates append the threshold and, if applicable, the critical hint
    $introduction = if ($MailTemplateLanguage -eq "Custom") {
        $mailTemplate.BeforeDeviceDetails
    }
    else {
        $suffix = if ($userIsCritical) { $criticalSentence } else { "" }
        "$($mailTemplate.BeforeDeviceDetails) $($thresholdSentence)$($suffix):"
    }

    $deviceListMarkdown = Get-DeviceListMarkdown -Devices $userDevices -MailTemplateLanguage $MailTemplateLanguage
    $tipsMarkdown = Get-StorageTipsMarkdown -Template $mailTemplate -Platforms $user.Platforms

    $markdownContent = @"
$emailHeader

$overrideNote
$introduction

$($deviceListMarkdown)
$tipsMarkdown

$($mailTemplate.AfterDeviceDetails)$($serviceDeskSection)

---

$autoGeneratedNote
"@

    # Send email to user
    try {
        Send-RjRbReportEmail -EmailFrom $EmailFrom -EmailTo $actualRecipient -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version @brandingMailParams

        Write-Output "Email sent successfully to $($actualRecipient)"
        Write-RjRbLog -Message "Email sent to $($actualRecipient) for user $($user.UserPrincipalName) with $($userDevices.Count) device(s)" -Verbose
        $emailsSent++
    }
    catch {
        Write-Warning "Failed to send email to $($actualRecipient) : $_"
        Write-RjRbLog -Message "Failed to send email to $($actualRecipient) for user $($user.UserPrincipalName) : $_" -Verbose
        $emailsFailed++
    }
}

if ($usersToNotify.Count -eq 0) {
    Write-Output "No users to notify."
}

#endregion

########################################################
#region     Output/Export
########################################################

Write-Output ""
Write-Output "===================="
Write-Output "Notification Summary"
Write-Output "===================="
if ($SimulationMode) {
    Write-Output "Mode: Simulation - no emails sent"
}
else {
    Write-Output "Mode: Send notifications"
}
Write-Output "Threshold: $($thresholdTextPlain)"
Write-Output "Notify on severity: $($NotifyOnSeverity)"
Write-Output "Platforms: $($platformSummary)"
Write-Output "Devices below the threshold: $($flaggedDevices.Count) (Critical: $($criticalCount), Warning: $($warningCount))"
Write-Output "Devices without primary user (skipped): $($devicesWithoutUser.Count)"
Write-Output "Users with affected devices: $($devicesByUser.Count)"
Write-Output "Users skipped - account disabled: $($usersSkippedDisabled.Count)"
Write-Output "Users skipped - user lookup failed: $($usersSkippedLookupFailed.Count)"
if ($SimulationMode) {
    Write-Output "Users that would be notified: $($emailsSimulated)"
}
else {
    Write-Output "Users notified: $($emailsSent)"
    Write-Output "Failed notifications: $($emailsFailed)"
}

if ($userScopeConfigured) {
    Write-Output ""
    Write-Output "User Scope Filtering:"
    if ($null -ne $includeUserScope) {
        Write-Output "  - Include group: $($includeUserScope.Count) users"
    }
    if ($null -ne $excludeUserScope) {
        Write-Output "  - Exclude group: $($excludeUserScope.Count) users"
    }
    Write-Output "  - Devices skipped by user scope: $($devicesSkippedByUserScope)"
}

if ($deviceGroupActive) {
    Write-Output ""
    Write-Output "Device Scope Filtering:"
    Write-Output "  - Device group: $($includeDeviceIds.Count) device(s)"
    Write-Output "  - Devices skipped - not in device group: $($devicesSkippedByDeviceGroup)"
}

if ($globalOverrideActive) {
    Write-Output ""
    Write-Output "Email Routing:"
    Write-Output "  - Global override active: ALL emails sent to: $($OverrideEmailRecipient)"
}

Write-Output ""
Write-Output "Done!"

#endregion

########################################################
#region     Cleanup
########################################################

# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

#endregion

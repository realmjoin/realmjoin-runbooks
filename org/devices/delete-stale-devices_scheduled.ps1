<#
    .SYNOPSIS
    Scheduled deletion of stale devices based on last activity date and platform

    .DESCRIPTION
    Identifies Intune managed devices that have not been active for a specified number of days.
    By default the runbook runs in report-only mode (simulation) and lists the devices that would be deleted.
    When deletion is enabled, the matching devices are deleted from Intune and the results are included in the report.
    An email report with CSV and/or Excel (xlsx) attachments can be sent optionally and the report files can also be uploaded to an Azure Storage Account, returning time-limited download links.

    .NOTES
    This runbook deletes managed devices from Intune based on inactivity. Use with care!

    Prerequisites:
    - EmailFrom parameter must be configured in runbook customization (RJReport.EmailSender setting) when email reporting is used

    Common Use Cases:
    - Regular cleanup of stale device records in Intune
    - Simulation runs (report-only mode) before enabling actual deletion
    - Scheduled lifecycle management with an audit trail via email report

    The runbook supports optional user scope filtering to include or exclude devices based on primary user group membership.
    This acts as an additional safety net when deletion is enabled.

    .PARAMETER Days
    Number of days without activity to be considered stale.

    .PARAMETER Windows
    Include Windows devices in the results.

    .PARAMETER MacOS
    Include macOS devices in the results.

    .PARAMETER iOS
    Include iOS devices in the results.

    .PARAMETER Android
    Include Android devices in the results.

    .PARAMETER DeleteDevices
    If set to true, the matching stale devices are deleted from Intune.
    If false (default), the runbook only reports which devices would be deleted (simulation).

    .PARAMETER EmailTo
    If specified, an email with the report will be sent to the provided address(es).
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization

    .PARAMETER BrandingHeaderImageUrl
    Optional public HTTPS URL of a custom header image (PNG/JPEG/GIF, max. 200 KB) for the report email.
    Sourced from the RJReport.Branding.HeaderImageUrl tenant setting. When empty, the default RealmJoin header graphic is used.

    .PARAMETER BrandingFooterImageUrl
    Optional public HTTPS URL of a custom footer image (PNG/JPEG/GIF, max. 200 KB) for the report email.
    Sourced from the RJReport.Branding.FooterImageUrl tenant setting. When empty, the default RealmJoin footer graphic is used.

    .PARAMETER BrandingFooterLink
    Optional URL the footer image links to. Sourced from the RJReport.Branding.FooterLink tenant setting.
    When empty, the default link (https://www.realmjoin.com) is used.

    .PARAMETER BrandingAccentColor
    Optional accent color override (6-digit hex, e.g. '#0052cc') for the report email template.
    Sourced from the RJReport.Branding.AccentColor tenant setting. When empty or invalid, the default RealmJoin accent color is used.

    .PARAMETER BrandingTextColor
    Optional text color override (6-digit hex) for the report email template.
    Sourced from the RJReport.Branding.TextColor tenant setting. When empty or invalid, the default RealmJoin text color is used.

    .PARAMETER ReportFileFormat
    Controls which report file formats are generated and delivered: "CSV only", "CSV & XLSX" (default) or "XLSX only".

    .PARAMETER CreateDownloadLink
    If enabled, the report files are uploaded to an Azure Storage Account and time-limited download links are returned. Disabled by default.

    .PARAMETER ContainerName
    Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

    .PARAMETER ResourceGroupName
    Resource group that contains the storage account. Sourced from the RJReport tenant settings.

    .PARAMETER StorageAccountName
    Storage account name used for the upload. Sourced from the RJReport tenant settings.

    .PARAMETER LinkExpiryDays
    Number of days until the generated download link expires. Sourced from the RJReport tenant settings.

    .PARAMETER UseUserScope
    Enable user scope filtering to include or exclude devices based on primary user group membership.

    .PARAMETER IncludeUserGroup
    Only include devices whose primary users are members of this group. Requires UseUserScope to be enabled.

    .PARAMETER ExcludeUserGroup
    Exclude devices whose primary users are members of this group. Requires UseUserScope to be enabled.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Days": {
                "DisplayName": "Minimum Days Without Activity"
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
            "DeleteDevices": {
                "DisplayName": "Deletion Mode",
                "SelectSimple": {
                    "Report only - show what would be deleted (simulation)": false,
                    "Delete stale devices from Intune": true
                }
            },
            "CallerName": {
                "Hide": true
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)"
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
            "EmailFrom": {
                "Hide": true
            },
            "ReportFileFormat": {
                "DisplayName": "Report file format",
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
            "CreateDownloadLink": {
                "DisplayName": "Create a file download link (upload report to storage)?",
                "SelectSimple": {
                    "Yes - upload report and return a download link": true,
                    "No - do not create a download link": false
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
            }
        },
        "ParameterList": [
            {
                "DisplayName": "(Optional) Enable user scope filtering to include or exclude devices based on primary user group membership.",
                "DisplayAfter": "EmailFrom",
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
                            "Display": "No - include all devices",
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
            }
        ]
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [int] $Days = 30,
    [bool] $Windows = $true,
    [bool] $MacOS = $true,
    [bool] $iOS = $true,
    [bool] $Android = $true,
    [bool] $DeleteDevices = $false,
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
    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'CSV & XLSX',
    [bool] $CreateDownloadLink = $false,
    [string] $ContainerName = "delete-stale-devices",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,
    [bool] $UseUserScope = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Include Users from Group" } )]
    [string]$IncludeUserGroup,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclude Users from Group" } )]
    [string]$ExcludeUserGroup,
    [Parameter(Mandatory = $false)]
    [string] $EmailTo,
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

$Version = "2.2.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Days: $Days" -Verbose
Write-RjRbLog -Message "Windows: $Windows" -Verbose
Write-RjRbLog -Message "MacOS: $MacOS" -Verbose
Write-RjRbLog -Message "iOS: $iOS" -Verbose
Write-RjRbLog -Message "Android: $Android" -Verbose
Write-RjRbLog -Message "DeleteDevices: $DeleteDevices" -Verbose
Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
Write-RjRbLog -Message "UseUserScope: $UseUserScope" -Verbose
Write-RjRbLog -Message "IncludeUserGroup: $IncludeUserGroup" -Verbose
Write-RjRbLog -Message "ExcludeUserGroup: $ExcludeUserGroup" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

# Validate Email Addresses (only if email is requested)
if ($EmailTo -and -not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -Verbose
    throw "This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings"
    exit
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
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
        by following the @odata.nextLink property in the response.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/applications".

        .EXAMPLE
        PS C:\> $allApps = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/applications"
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

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

# Connect to Microsoft Graph
Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop

# Get tenant information
Write-Output "## Retrieving tenant information..."
$tenantDisplayName = "Unknown Tenant"
try {
    $organizationUri = "https://graph.microsoft.com/v1.0/organization?`$select=displayName"
    $organizationResponse = Invoke-MgGraphRequest -Uri $organizationUri -Method GET -ErrorAction Stop

    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
        Write-Output "## Tenant: $($tenantDisplayName)"
    }
    elseif ($organizationResponse.displayName) {
        $tenantDisplayName = $organizationResponse.displayName
        Write-Output "## Tenant: $($tenantDisplayName)"
    }
}
catch {
    Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
}

# Connect RJ RunbookHelper for email reporting
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

Write-Output ""

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

# Calculate the date threshold for stale devices
$beforeDate = (Get-Date).AddDays(-$Days) | Get-Date -Format "yyyy-MM-dd"

# Prepare filter for the Graph API query
$filter = "lastSyncDateTime le $($beforeDate)T00:00:00Z"
Write-RjRbLog -Message "Filtering devices inactive for at least $Days days" -Verbose

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

# Get all stale devices
Write-Output "## Listing devices not active for at least $($Days) days"
Write-Output ""

$encodedFilter = [System.Uri]::EscapeDataString($filter)
$devicesUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=$selectString&`$filter=$encodedFilter"
$devices = Get-GraphPagedResult -Uri $devicesUri

    #region User Scope Filtering
    ##############################

# Get group membership for filtering if UseUserScope is enabled
$includeUserIds = @()
$excludeUserIds = @()

if ($UseUserScope) {
    Write-Output ""
    Write-Output "## Processing user scope filtering..."

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
            Write-Warning "Failed to retrieve include group members: $_"
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
            Write-Warning "Failed to retrieve exclude group members: $_"
        }
    }
    Write-Output ""
}

    #endregion User Scope Filtering

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

# Filter devices by platform based on user selection
$filteredDevices = @()

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

    if ($include) {
        # Try to get additional user information
        if ($device.userPrincipalName) {
            try {
                $encodedUserPrincipalName = [System.Uri]::EscapeDataString($device.userPrincipalName)
                $userUri = "https://graph.microsoft.com/v1.0/users/{0}?`$select=id,displayName,city,usageLocation" -f $encodedUserPrincipalName
                $userInfo = Invoke-MgGraphRequest -Uri $userUri -Method GET -ErrorAction SilentlyContinue

                if ($userInfo) {
                    $device | Add-Member -Name "userDisplayName" -Value $userInfo.displayName -MemberType "NoteProperty" -Force
                    $device | Add-Member -Name "userLocation" -Value "$($userInfo.city), $($userInfo.usageLocation)" -MemberType "NoteProperty" -Force

                    # Apply user scope filtering if enabled
                    if ($UseUserScope) {
                        $userId = $userInfo.id

                        # Apply include filter
                        if ($IncludeUserGroup -and ($includeUserIds.Count -gt 0) -and ($userId -notin $includeUserIds)) {
                            Write-RjRbLog -Message "Skipping device '$($device.deviceName)' - primary user '$($device.userPrincipalName)' not in include group" -Verbose
                            continue
                        }

                        # Apply exclude filter
                        if ($ExcludeUserGroup -and ($excludeUserIds.Count -gt 0) -and ($userId -in $excludeUserIds)) {
                            Write-RjRbLog -Message "Skipping device '$($device.deviceName)' - primary user '$($device.userPrincipalName)' in exclude group" -Verbose
                            continue
                        }
                    }
                }
            }
            catch {
                Write-RjRbLog -Message "Could not retrieve user info for $($device.userPrincipalName): $($_.Exception.Message)" -Verbose
            }
        }

        $filteredDevices += $device
    }
}

# Display summary counts
Write-Output "## Summary of stale devices for $($tenantDisplayName):"
Write-Output "Total devices: $($filteredDevices.Count)"

if ($Windows) {
    $windowsCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Windows" } | Measure-Object).Count
    Write-Output "Windows devices: $($windowsCount)"
}

if ($MacOS) {
    $macOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "macOS" } | Measure-Object).Count
    Write-Output "macOS devices: $($macOSCount)"
}

if ($iOS) {
    $iOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "iOS" } | Measure-Object).Count
    Write-Output "iOS devices: $($iOSCount)"
}

if ($Android) {
    $androidCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Android" } | Measure-Object).Count
    Write-Output "Android devices: $($androidCount)"
}

#endregion Data Processing

########################################################
#region     Device Deletion
########################################################

# Delete devices only when deletion mode is enabled; the default is a report-only simulation.
# Deletion happens BEFORE the report is generated so the report reflects the actual results.
$deletedDevices = @()
$failedDeletions = @()

if ($DeleteDevices -and $filteredDevices.Count -gt 0) {
    Write-Output ""
    Write-Output "## Device Deletion"
    Write-Output "Deleting $($filteredDevices.Count) stale devices..."

    foreach ($device in $filteredDevices) {
        try {
            Write-Output "Deleting device: $($device.deviceName) (ID: $($device.id))"
            $deleteUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$($device.id)"
            Invoke-MgGraphRequest -Uri $deleteUri -Method DELETE -ErrorAction Stop | Out-Null
            $device | Add-Member -Name "deletionStatus" -Value "Deleted" -MemberType "NoteProperty" -Force
            $deletedDevices += $device
            Write-Output "Successfully deleted device: $($device.deviceName)"
        }
        catch {
            Write-Output "Failed to delete device $($device.deviceName): $($_.Exception.Message)"
            Write-RjRbLog -Message "Failed to delete device $($device.deviceName): $($_.Exception.Message)" -Verbose
            $device | Add-Member -Name "deletionStatus" -Value "Failed" -MemberType "NoteProperty" -Force
            $failedDeletions += $device
        }
    }
}
elseif ($filteredDevices.Count -gt 0) {
    Write-Output ""
    Write-Output "## Report-only mode (simulation): the listed devices WOULD be deleted."
    Write-Output "Set 'DeleteDevices' to true to delete them."
    foreach ($device in $filteredDevices) {
        $device | Add-Member -Name "deletionStatus" -Value "Would be deleted" -MemberType "NoteProperty" -Force
    }
}

#endregion Device Deletion

########################################################
#region     Output & Report
########################################################

Write-Output ""
Write-Output "## Detailed list of stale devices:"
Write-Output ""

# Convert to PSCustomObject array for consistent formatting
$displayDevices = @()
foreach ($device in $filteredDevices) {
    $displayDevices += [PSCustomObject]@{
        LastSync     = if ($device.lastSyncDateTime) { Get-Date $device.lastSyncDateTime -Format yyyy-MM-dd } else { "N/A" }
        DeviceName   = if ($device.deviceName -and $device.deviceName.Length -gt 15) { $device.deviceName.Substring(0, 14) + ".." } elseif ($device.deviceName) { $device.deviceName } else { "N/A" }
        DeviceID     = if ($device.id -and $device.id.Length -gt 15) { $device.id.Substring(0, 14) + ".." } elseif ($device.id) { $device.id } else { "N/A" }
        SerialNumber = if ($device.serialNumber -and $device.serialNumber.Length -gt 15) { $device.serialNumber.Substring(0, 14) + ".." } elseif ($device.serialNumber) { $device.serialNumber } else { "N/A" }
        PrimaryUser  = if ($device.userPrincipalName -and $device.userPrincipalName.Length -gt 20) { $device.userPrincipalName.Substring(0, 19) + ".." } elseif ($device.userPrincipalName) { $device.userPrincipalName } else { "N/A" }
        Status       = if ($device.deletionStatus) { $device.deletionStatus } else { "N/A" }
    }
}

# Display the filtered devices
$displayDevices | Sort-Object -Property LastSync | Format-Table -AutoSize

# Prepare additional metadata for the report body
$selectedPlatforms = @()
if ($Windows) { $selectedPlatforms += 'Windows' }
if ($MacOS) { $selectedPlatforms += 'macOS' }
if ($iOS) { $selectedPlatforms += 'iOS' }
if ($Android) { $selectedPlatforms += 'Android' }
$platformSummary = if ($selectedPlatforms.Count -gt 0) { $selectedPlatforms -join ', ' } else { 'No specific platforms selected' }
$totalDevicesEvaluated = ($devices | Measure-Object).Count

if ($filteredDevices.Count -gt 10) {
    $filteredDevices_moreThan10 = $true
}

$modeText = if ($DeleteDevices) { "deletion" } else { "report-only (simulation)" }
$actionText = if ($DeleteDevices) { "have been deleted from Intune" } else { "**would be deleted** from Intune (report-only mode - no changes were made)" }

# Build Markdown content
$markdownContent = if ($filteredDevices.Count -eq 0) {
    @"
# Stale Devices Deletion Report

No managed devices matched the stale device criteria (inactive for at least **$Days days**) for the selected platforms. Nothing to delete.

## What We Checked

- Run mode: $($modeText)
- Inactivity threshold: at least **$Days days**
- Platforms evaluated: $($platformSummary)
- Devices evaluated: $($totalDevicesEvaluated)
$(if ($UseUserScope) {
    $filterInfo = @()
    if ($IncludeUserGroup) { $filterInfo += "Include group: $($includeUserIds.Count) users" }
    if ($ExcludeUserGroup) { $filterInfo += "Exclude group: $($excludeUserIds.Count) users" }
    "- User scope filtering: $($filterInfo -join ', ')"
})

---

*This email was automatically generated. Please do not reply to this email.*
"@
}
else {
    @"
# Stale Devices Deletion Report

This report lists devices that have been inactive for at least **$Days days**. The listed devices $($actionText).
$(if ($UseUserScope) {
    $filterInfo = @()
    if ($IncludeUserGroup) { $filterInfo += "Include group with $($includeUserIds.Count) users" }
    if ($ExcludeUserGroup) { $filterInfo += "Exclude group with $($excludeUserIds.Count) users" }
    "`n**User Scope Filtering Applied:** $($filterInfo -join ', ')"
})

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Stale Devices** | $($filteredDevices.Count) |
$(
    $summaryLines = @()
    if ($DeleteDevices) {
        $summaryLines += "| **Successfully Deleted** | $($deletedDevices.Count) |"
        if ($failedDeletions.Count -gt 0) {
            $summaryLines += "| **Failed Deletions** | $($failedDeletions.Count) |"
        }
    }
    if ($Windows) {
        $windowsCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Windows" } | Measure-Object).Count
        $summaryLines += "| **Windows Devices** | $windowsCount |"
    }
    if ($MacOS) {
        $macOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "macOS" } | Measure-Object).Count
        $summaryLines += "| **macOS Devices** | $macOSCount |"
    }
    if ($iOS) {
        $iOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "iOS" } | Measure-Object).Count
        $summaryLines += "| **iOS Devices** | $iOSCount |"
    }
    if ($Android) {
        $androidCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Android" } | Measure-Object).Count
        $summaryLines += "| **Android Devices** | $androidCount |"
    }
    $summaryLines -join "`n"
)

$(if ($filteredDevices_moreThan10) {
    "## Top 10 Stale Devices (by Last Sync Date)"
    ""
    "This table lists the top 10 devices that have been inactive the longest, based on the current defined threshold (at least $Days days)."
    ""
} else {
    "## Stale Devices"
    ""
    "This table lists all devices matching the inactivity criteria (at least $Days days)."
    ""
})


$(if ($filteredDevices.Count -gt 0) {
    $sortedDevices = $filteredDevices | Sort-Object -Property lastSyncDateTime

    # If more than 10 devices, only show top 10 in email (oldest first)
    $devicesToShow = if ($filteredDevices.Count -gt 10) {
        $sortedDevices | Select-Object -First 10
    } else {
        $sortedDevices
    }

    # Create markdown table
    $table = @"
| Last Sync | Device Name | Operating System | Serial Number | Primary User | Status |
|-----------|-------------|------------------|---------------|--------------|--------|
"@

    foreach ($device in $devicesToShow) {
        $lastSync = Get-Date $device.lastSyncDateTime -Format yyyy-MM-dd
        $deviceName = $device.deviceName
        $os = $device.operatingSystem
        $serialNumber = $device.serialNumber
        $user = $device.userPrincipalName
        $status = $device.deletionStatus

        $table += "`n| $($lastSync) | $($deviceName) | $($os) | $($serialNumber) | $($user) | $($status) |"
    }

    $table
})

$(if ($DeleteDevices -and $failedDeletions.Count -gt 0) {
    $failedSection = @"
## Failed Deletions

The following devices could not be deleted and require manual review:

"@
    foreach ($failedDevice in $failedDeletions) {
        $failedSection += "`n- $($failedDevice.deviceName) (ID: $($failedDevice.id))"
    }
    $failedSection
})

$(if (-not $DeleteDevices) {
    @"
## Next Steps

This was a simulation run - **no devices were deleted**. Review the listed devices and, when you are confident the selection is correct, re-run the runbook with the deletion mode set to "Delete stale devices from Intune".
"@
})

## Attachments

The report file(s) attached to this email contain the full list of affected devices for further analysis.

---

*This email was automatically generated. Please do not reply to this email.*

"@
}

# Create report files in current location (only needed for the email report and/or download link)
$fileNameBase = "StaleDevicesDeletionReport_$($tenantDisplayName)_$($Days)Days"
$csvFilePath = $null
$xlsxFilePath = $null
$reportFiles = @()
if (($EmailTo -or $CreateDownloadLink) -and $filteredDevices.Count -gt 0) {
    # Build clean export rows including the deletion status
    $exportDevices = @()
    foreach ($device in $filteredDevices) {
        $exportDevices += [PSCustomObject]@{
            DeviceName      = $device.deviceName
            DeviceId        = $device.id
            SerialNumber    = $device.serialNumber
            Manufacturer    = $device.manufacturer
            Model           = $device.model
            OperatingSystem = $device.operatingSystem
            OSVersion       = $device.osVersion
            ComplianceState = $device.complianceState
            LastSync        = $device.lastSyncDateTime
            EnrolledDate    = $device.enrolledDateTime
            PrimaryUser     = $device.userPrincipalName
            UserDisplayName = $device.userDisplayName
            UserLocation    = $device.userLocation
            DeletionStatus  = $device.deletionStatus
        }
    }
    $exportDevices = @($exportDevices | Sort-Object -Property LastSync)

    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath "$fileNameBase.csv"
        $exportDevices | Export-Csv -Path $csvFilePath -NoTypeInformation
        $reportFiles += $csvFilePath
        Write-RjRbLog -Message "Exported stale devices to CSV: $($csvFilePath)" -Verbose
    }
    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath "$fileNameBase.xlsx"
        $highlightRules = @(
            @{ Column = 'DeletionStatus'; Value = 'Deleted'; Color = 'Green' }
            @{ Column = 'DeletionStatus'; Value = 'Failed'; Color = 'Red' }
            @{ Column = 'DeletionStatus'; Value = 'Would be deleted'; Color = 'Yellow' }
        )
        $exportDevices | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Stale Devices" -HighlightRules $highlightRules
        $reportFiles += $xlsxFilePath
        Write-RjRbLog -Message "Exported stale devices to XLSX: $($xlsxFilePath)" -Verbose
    }
}

# Upload / Download Link (optional)
if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
    Write-Output ""
    Write-Output "## Uploading report to storage account..."

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
        Write-Output ""
        Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
        $uploadResult.SASLink | Out-String | Write-Output
    }
}

#endregion Output & Report

########################################################
#region     Email Report
########################################################

# Send email report (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
$emailSubject = "Stale Devices Report"
if ($DeleteDevices) {
    $emailSubject += " - DELETION"
}
$emailSubject += " - $($tenantDisplayName) - $($Days)+ days"

if ($EmailTo) {
    Write-Output ""
    Write-Output "Sending report to '$($EmailTo)'..."
    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        if ($reportFiles.Count -gt 0) {
            $markdownFallback = @"
# Stale Devices Deletion Report

This report lists devices that have been inactive for at least **$Days days**. The listed devices $($actionText).

## Summary Statistics

- Total stale devices: **$($filteredDevices.Count)**
$(if ($DeleteDevices) {
    "- Successfully deleted: **$($deletedDevices.Count)**"
    if ($failedDeletions.Count -gt 0) { "`n- Failed deletions: **$($failedDeletions.Count)**" }
})

## Attachments

- **$($fileNameBase).xlsx**: Formatted Excel workbook with the complete device list

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

            $guardParams = @{
                EmailFrom         = $EmailFrom
                EmailTo           = $EmailTo
                Subject           = $emailSubject
                MarkdownContent   = $markdownContent
                TenantDisplayName = $tenantDisplayName
                ReportVersion     = $Version
            }
            if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFilePath) {
                Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFilePath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
            }
        }
        else {
            Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version @brandingMailParams
        }

        Write-RjRbLog -Message "Email report sent successfully to: $($EmailTo)" -Verbose
    }
    catch {
        Write-Output "Error sending email: $_"
        Write-RjRbLog -Message "Error sending email: $_" -Verbose
        throw "Failed to send email report: $($_.Exception.Message)"
    }
}
else {
    Write-RjRbLog -Message "No recipient email address provided - email report skipped" -Verbose
}

#endregion Email Report

########################################################
#region     Cleanup
########################################################
# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

# Remove the temporary report files, if any were created.
foreach ($reportFilePath in $reportFiles) {
    if ($reportFilePath -and (Test-Path -Path $reportFilePath)) {
        try {
            Remove-Item -Path $reportFilePath -Force -ErrorAction Stop
            Write-RjRbLog -Message "Removed temporary report file: $reportFilePath" -Verbose
        }
        catch {
            Write-RjRbLog -Message "Failed to remove temporary report file '$reportFilePath': $($_.Exception.Message)" -Verbose
        }
    }
}

# Output summary
Write-Output ""
Write-Output "## Operation Summary:"
Write-Output "Stale devices found: $($filteredDevices.Count)"
if ($DeleteDevices) {
    Write-Output "Devices successfully deleted: $($deletedDevices.Count)"
    if ($failedDeletions.Count -gt 0) {
        Write-Output "Devices failed to delete: $($failedDeletions.Count)"
    }
}
else {
    Write-Output "Report-only mode: no devices were deleted."
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

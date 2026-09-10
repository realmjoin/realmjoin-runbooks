<#
    .SYNOPSIS
    Scheduled report of managed devices running low on free disk space.

    .DESCRIPTION
    Identifies and lists Intune managed devices whose free disk space is below a configurable threshold, either a fixed amount of free space in gigabytes or a percentage of the total disk size.
    The result can be narrowed down by platform and by manufacturer and model filters, and each reported device is rated as Critical or Warning depending on how far below the threshold it is.
    Automatically sends a report via email with CSV and/or Excel (xlsx) attachments.
    The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
    The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
    When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

    .NOTES
    This runbook complements the reporting foundation and delivers a recurring overview of devices that are about to run out of disk space,
    so that affected users can be contacted before the lack of free space starts to block updates, app installations or profile synchronization.

    Prerequisites:
    - EmailFrom parameter must be configured in runbook customization (RJReport.EmailSender setting)

    Data source and freshness:
    The free and total disk space values are taken from the Intune hardware inventory of each device, which is refreshed with the regular device check-in.
    They therefore describe the state of the last successful inventory and not necessarily the current state, so the Last Sync column of the report should be used to judge how up to date a row is.
    Devices that report a total disk size of zero bytes have no usable storage inventory (this is common for Android Enterprise work profiles) and are excluded from the evaluation, but their number is reported.
    This report deliberately lists devices regardless of how old their inventory is, so that a device which stopped checking in still shows up. Its user-facing counterpart
    "Notify Users About Low Diskspace" does the opposite and skips devices whose last Intune sync is older than its MaxInventoryAgeDays setting, so that no user is asked to
    free up space based on outdated numbers. Both runbooks apply the same threshold and the same Critical/Warning rating, but the report can therefore list more devices than
    the notification runbook writes to - the difference is the devices with a stale inventory, and the notification runbook reports their number in its own output.

    Platform defaults:
    Windows and macOS are included by default, iOS/iPadOS and Android are not, because the default threshold in gigabytes is dimensioned for desktop disks
    and would report a large number of perfectly healthy mobile devices. When mobile platforms are enabled, the percentage based threshold usually gives more meaningful results.

    Common Use Cases:
    - Recurring disk space monitoring across the managed device fleet
    - Finding devices that are likely to fail feature updates or app deployments because of insufficient free space
    - Preparing targeted user communication or cleanup campaigns
    - Checking a specific hardware generation via the manufacturer and model filters

    .PARAMETER ThresholdType
    Determines how low disk space is detected, either by a fixed amount of free space in gigabytes or by the percentage of free space relative to the disk size.

    .PARAMETER FreeSpaceThresholdGB
    Devices with less free disk space than this value in gigabytes are reported. Only used when the threshold type is set to free space in gigabytes.

    .PARAMETER FreeSpacePercentThreshold
    Devices with a lower percentage of free disk space than this value are reported. Only used when the threshold type is set to free space in percent.

    .PARAMETER Windows
    Include Windows devices in the results.

    .PARAMETER MacOS
    Include macOS devices in the results.

    .PARAMETER iOS
    Include iOS and iPadOS devices in the results.

    .PARAMETER Android
    Include Android devices in the results.

    .PARAMETER ManufacturerFilter
    Optional comma-separated list of manufacturer names. A device is included when its manufacturer contains one of the entries. Leave empty to include all manufacturers.

    .PARAMETER ModelFilter
    Optional comma-separated list of model names. A device is included when its model contains one of the entries. Leave empty to include all models.

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
            "Windows": {
                "DisplayName": "Include Windows Devices"
            },
            "MacOS": {
                "DisplayName": "Include macOS Devices"
            },
            "iOS": {
                "DisplayName": "Include iOS/iPadOS Devices"
            },
            "Android": {
                "DisplayName": "Include Android Devices"
            },
            "ManufacturerFilter": {
                "DisplayName": "Manufacturer Filter (comma-separated, substring match, leave empty for all)"
            },
            "ModelFilter": {
                "DisplayName": "Model Filter (comma-separated, substring match, leave empty for all)"
            },
            "CallerName": {
                "Hide": true
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)"
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
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [ValidateSet('Free space in GB', 'Free space in percent')]
    [string] $ThresholdType = 'Free space in GB',
    [ValidateRange(1, 100000)]
    [int] $FreeSpaceThresholdGB = 20,
    [ValidateRange(1, 99)]
    [int] $FreeSpacePercentThreshold = 10,
    [bool] $Windows = $true,
    [bool] $MacOS = $true,
    [bool] $iOS = $false,
    [bool] $Android = $false,
    [string] $ManufacturerFilter = "",
    [string] $ModelFilter = "",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ } )]
    [string]$EmailFrom,
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
    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'XLSX only',
    [bool] $CreateDownloadLink = $false,
    [string] $ContainerName = "report-devices-low-diskspace",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,
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

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
Write-RjRbLog -Message "ThresholdType: $ThresholdType" -Verbose
Write-RjRbLog -Message "FreeSpaceThresholdGB: $FreeSpaceThresholdGB" -Verbose
Write-RjRbLog -Message "FreeSpacePercentThreshold: $FreeSpacePercentThreshold" -Verbose
Write-RjRbLog -Message "Windows: $Windows" -Verbose
Write-RjRbLog -Message "MacOS: $MacOS" -Verbose
Write-RjRbLog -Message "iOS: $iOS" -Verbose
Write-RjRbLog -Message "Android: $Android" -Verbose
Write-RjRbLog -Message "ManufacturerFilter: $ManufacturerFilter" -Verbose
Write-RjRbLog -Message "ModelFilter: $ModelFilter" -Verbose
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

# Validate Email Addresses (only if email is requested)
if ($EmailTo -and -not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -Verbose
    throw "This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings"
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

# At least one platform has to be evaluated
$selectedPlatforms = @()
if ($Windows) { $selectedPlatforms += 'Windows' }
if ($MacOS) { $selectedPlatforms += 'macOS' }
if ($iOS) { $selectedPlatforms += 'iOS/iPadOS' }
if ($Android) { $selectedPlatforms += 'Android' }

if ($selectedPlatforms.Count -eq 0) {
    throw "All platform filters are disabled. Enable at least one platform (Windows, macOS, iOS/iPadOS, Android) to generate a report."
}

$platformSummary = $selectedPlatforms -join ', '

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

function ConvertTo-FilterList {
    <#
        .SYNOPSIS
        Splits a comma-separated filter string into a trimmed list of non-empty values.

        .PARAMETER RawValue
        The raw parameter value as entered in the runbook customization.
    #>
    param([string]$RawValue)
    if ($RawValue -like "") { return @() }
    return @($RawValue -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
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
        "iOS*" { return $iOS }
        "iPadOS*" { return $iOS }
        "Android*" { return $Android }
        default { return $false }
    }
}

function Get-PlatformDeviceCount {
    <#
        .SYNOPSIS
        Counts how many of the reported devices belong to one of the selected platforms.

        .PARAMETER Devices
        The already processed device objects to count.

        .PARAMETER Platform
        The platform label as used in the selected platform list, e.g. "iOS/iPadOS".
    #>
    param(
        [array]$Devices,
        [string]$Platform
    )

    $matchedDevices = @($Devices | Where-Object {
            switch -Wildcard ($_.OperatingSystem) {
                "Windows*" { $Platform -eq 'Windows' }
                "macOS*" { $Platform -eq 'macOS' }
                "iOS*" { $Platform -eq 'iOS/iPadOS' }
                "iPadOS*" { $Platform -eq 'iOS/iPadOS' }
                "Android*" { $Platform -eq 'Android' }
                default { $false }
            }
        })

    return $matchedDevices.Count
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
        Devices below half of the configured threshold are rated as Critical, all other reported devices as Warning.

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

#endregion

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

#endregion

########################################################
#region     Data Collection
########################################################

# The threshold text is reused in the console output, the email subject and the report body
$thresholdText = if ($ThresholdType -eq 'Free space in percent') {
    "less than **$($FreeSpacePercentThreshold) %** free disk space"
}
else {
    "less than **$($FreeSpaceThresholdGB) GB** free disk space"
}
$thresholdTextPlain = $thresholdText -replace '\*\*', ''

$manufacturerList = ConvertTo-FilterList -RawValue $ManufacturerFilter
$modelList = ConvertTo-FilterList -RawValue $ModelFilter

Write-Output "## Listing devices with $($thresholdTextPlain)"
Write-Output "Included platforms: $($platformSummary)"
if ($manufacturerList.Count -gt 0) { Write-Output "Manufacturer filter: $($manufacturerList -join ', ')" }
if ($modelList.Count -gt 0) { Write-Output "Model filter: $($modelList -join ', ')" }
Write-Output "Note: This may take a while depending on the number of devices in your tenant."
Write-Output ""

# The storage properties cannot be used in an OData filter, so all devices are retrieved
# with a narrow property projection and evaluated locally.
$selectProperties = @(
    'id'
    'deviceName'
    'userPrincipalName'
    'userDisplayName'
    'serialNumber'
    'manufacturer'
    'model'
    'operatingSystem'
    'osVersion'
    'lastSyncDateTime'
    'complianceState'
    'freeStorageSpaceInBytes'
    'totalStorageSpaceInBytes'
)
$selectString = ($selectProperties -join ',')

$devicesUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=$selectString"
$devices = Get-GraphPagedResult -Uri $devicesUri
$totalDevicesScanned = ($devices | Measure-Object).Count

#endregion

########################################################
#region     Data Processing
########################################################

$flaggedDevices = @()
$devicesEvaluated = 0
$devicesWithoutStorageData = 0

foreach ($device in $devices) {
    if (-not (Test-PlatformIncluded -OperatingSystem $device.operatingSystem)) {
        continue
    }

    $manufacturer = if ($null -ne $device.manufacturer) { $device.manufacturer } else { "" }
    $model = if ($null -ne $device.model) { $device.model } else { "" }

    # Each filter is independent; an empty filter means "match all values for that dimension".
    # When both are populated they are combined with AND (a device must match every set filter).
    $manufacturerMatch = ($manufacturerList.Count -eq 0) -or ($manufacturerList | Where-Object { $manufacturer -like "*$_*" }).Count -gt 0
    $modelMatch = ($modelList.Count -eq 0) -or ($modelList | Where-Object { $model -like "*$_*" }).Count -gt 0

    if (-not ($manufacturerMatch -and $modelMatch)) {
        continue
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

    # Exact values drive the threshold test and the severity rating; the rounded ones are for display
    # only. Comparing rounded values would shift the effective boundary by up to half a percentage
    # point, silently dropping devices that are measurably below the configured threshold.
    # Kept identical to the notify counterpart so both rate a given device the same way.
    $freeSpaceGBExact = $freeBytes / 1GB
    $freePercentExact = ($freeBytes / $totalBytes) * 100

    $freeSpaceGB = [math]::Round($freeSpaceGBExact, 1)
    $totalSpaceGB = [math]::Round($totalBytes / 1GB, 1)
    $freePercent = [int][math]::Round($freePercentExact, 0)

    if (-not (Test-LowDiskSpace -FreeGB $freeSpaceGBExact -FreePercent $freePercentExact)) {
        continue
    }

    $flaggedDevices += [PSCustomObject]@{
        DeviceName      = $device.deviceName
        PrimaryUser     = $device.userPrincipalName
        UserDisplayName = $device.userDisplayName
        OperatingSystem = $device.operatingSystem
        OSVersion       = $device.osVersion
        Manufacturer    = $manufacturer
        Model           = $model
        SerialNumber    = $device.serialNumber
        FreeSpaceGB     = $freeSpaceGB
        TotalSpaceGB    = $totalSpaceGB
        FreePercent     = $freePercent
        Severity        = Get-DiskSeverity -FreeGB $freeSpaceGBExact -FreePercent $freePercentExact
        ComplianceState = $device.complianceState
        LastSync        = if ($device.lastSyncDateTime) { Get-Date $device.lastSyncDateTime -Format yyyy-MM-dd } else { "N/A" }
        DeviceId        = $device.id
    }
}

# Worst devices first
$flaggedDevices = @($flaggedDevices | Sort-Object -Property FreeSpaceGB, FreePercent)

$criticalCount = ($flaggedDevices | Where-Object { $_.Severity -eq 'Critical' } | Measure-Object).Count
$warningCount = ($flaggedDevices | Where-Object { $_.Severity -eq 'Warning' } | Measure-Object).Count

#endregion

########################################################
#region     Output
########################################################

Write-Output "## Summary of devices with low disk space for $($tenantDisplayName):"
Write-Output "Devices scanned: $($totalDevicesScanned)"
Write-Output "Devices evaluated (after platform and hardware filters): $($devicesEvaluated)"
Write-Output "Devices without usable storage inventory (excluded): $($devicesWithoutStorageData)"
Write-Output "Devices below the threshold: $($flaggedDevices.Count)"
Write-Output "  Critical: $($criticalCount)"
Write-Output "  Warning: $($warningCount)"

foreach ($platform in $selectedPlatforms) {
    Write-Output "$($platform) devices below the threshold: $(Get-PlatformDeviceCount -Devices $flaggedDevices -Platform $platform)"
}

Write-Output ""

if ($flaggedDevices.Count -eq 0) {
    Write-Output "No devices found matching the low disk space criteria."
}
else {
    Write-Output "## Detailed list of devices with low disk space:"
    Write-Output ""

    $displayDevices = @()
    foreach ($device in $flaggedDevices) {
        $displayDevices += [PSCustomObject]@{
            FreeGB       = $device.FreeSpaceGB
            FreePercent  = $device.FreePercent
            TotalGB      = $device.TotalSpaceGB
            Severity     = $device.Severity
            DeviceName   = if ($device.DeviceName -and $device.DeviceName.Length -gt 15) { $device.DeviceName.Substring(0, 14) + ".." } elseif ($device.DeviceName) { $device.DeviceName } else { "N/A" }
            Model        = if ($device.Model -and $device.Model.Length -gt 20) { $device.Model.Substring(0, 19) + ".." } elseif ($device.Model) { $device.Model } else { "N/A" }
            PrimaryUser  = if ($device.PrimaryUser -and $device.PrimaryUser.Length -gt 20) { $device.PrimaryUser.Substring(0, 19) + ".." } elseif ($device.PrimaryUser) { $device.PrimaryUser } else { "N/A" }
            LastSync     = $device.LastSync
        }
    }

    $displayDevices | Format-Table -AutoSize
}

#endregion

########################################################
#region     Email Report Content
########################################################

if ($EmailTo) {
    Write-Output ""
    Write-Output "## Preparing email report to send to $($EmailTo)"
}

$filterSummary = @()
if ($manufacturerList.Count -gt 0) { $filterSummary += "Manufacturer: $($manufacturerList -join ', ')" }
if ($modelList.Count -gt 0) { $filterSummary += "Model: $($modelList -join ', ')" }
$filterSummaryText = if ($filterSummary.Count -gt 0) { $filterSummary -join ' | ' } else { 'None' }

$markdownContent = if ($flaggedDevices.Count -eq 0) {
    @"
# Devices Low Disk Space Report

Great news — no managed device reported $($thresholdText) for the selected platforms.

## What We Checked

- Threshold: $($thresholdText)
- Platforms evaluated: $($platformSummary)
- Hardware filters: $($filterSummaryText)
- Devices scanned: $($totalDevicesScanned)
- Devices evaluated: $($devicesEvaluated)
- Devices without usable storage inventory (excluded): $($devicesWithoutStorageData)

## Recommendations

- Continue to monitor this report regularly to spot devices running out of space early
- Keep the threshold aligned with the disk sizes of your current hardware generation
- Make sure devices check in regularly so the disk space inventory stays up to date

---

*This email was automatically generated. Please do not reply to this email.*
"@
}
else {
    @"
# Devices Low Disk Space Report

This report shows managed devices that reported $($thresholdText).

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Devices Below Threshold** | $($flaggedDevices.Count) |
| **Critical** | $($criticalCount) |
| **Warning** | $($warningCount) |
$(
    $summaryLines = @()
    foreach ($platform in $selectedPlatforms) {
        $summaryLines += "| **$platform Devices** | $(Get-PlatformDeviceCount -Devices $flaggedDevices -Platform $platform) |"
    }
    $summaryLines += "| **Devices Evaluated** | $devicesEvaluated |"
    $summaryLines += "| **Excluded - No Storage Inventory** | $devicesWithoutStorageData |"
    $summaryLines -join "`n"
)

$(
    # A subexpression joins multiple output strings with $OFS (a space), so the lines are
    # joined explicitly - otherwise the heading and its description end up on one line and
    # Markdown swallows the description into the heading.
    $headingLines = if ($flaggedDevices.Count -gt 10) {
        @("## Top 10 Devices (by Lowest Free Disk Space)", "",
          "This table lists the ten devices with the least free disk space, based on the current threshold ($($thresholdText)).")
    }
    else {
        @("## Devices With Low Disk Space", "",
          "This table lists all devices matching the current threshold ($($thresholdText)).")
    }
    $headingLines -join "`n"
)


$(
    $devicesToShow = if ($flaggedDevices.Count -gt 10) {
        $flaggedDevices | Select-Object -First 10
    } else {
        $flaggedDevices
    }

    $table = @"
| Free GB | Free % | Total GB | Severity | Device Name | Operating System | Model | Primary User | Last Sync |
|---------|--------|----------|----------|-------------|------------------|-------|--------------|-----------|
"@

    foreach ($device in $devicesToShow) {
        $table += "`n| $($device.FreeSpaceGB) | $($device.FreePercent) | $($device.TotalSpaceGB) | $($device.Severity) | $($device.DeviceName) | $($device.OperatingSystem) | $($device.Model) | $($device.PrimaryUser) | $($device.LastSync) |"
    }

    $table
)

## Data Freshness

The disk space values come from the Intune hardware inventory, which is refreshed with the regular device check-in. They describe the state of the last successful inventory, so please use the Last Sync column to judge how current a row is. $($devicesWithoutStorageData) device(s) reported no usable storage inventory and were excluded from the evaluation.

## Recommendations

### Review and Action

Please review the listed devices and take appropriate action:
- Contact the primary users of devices rated as Critical first
- Free up space by removing unused applications, local caches and old user profiles
- Check whether pending feature updates or app deployments are blocked by the lack of free space
- Verify whether devices with unusually small disks still meet your hardware requirements

### Preventive Measures

Regularly reviewing disk space helps:
- Avoid failed updates and app installations
- Reduce support tickets caused by devices running out of space
- Plan hardware replacements based on evidence

## Attachments

The report file(s) attached to this email contain the full list of devices with low disk space for further analysis.

---

*This email was automatically generated. Please do not reply to this email.*

"@
}

#endregion

########################################################
#region     Export
########################################################

# Create report files in current location (only needed for the email report and/or download link)
$fileNameSuffix = if ($ThresholdType -eq 'Free space in percent') {
    "$($FreeSpacePercentThreshold)Percent"
}
else {
    "$($FreeSpaceThresholdGB)GB"
}
$fileNameBase = "DevicesLowDiskspaceReport_$($tenantDisplayName)_$($fileNameSuffix)"
$csvFilePath = $null
$xlsxFilePath = $null
$reportFiles = @()
if (($EmailTo -or $CreateDownloadLink) -and $flaggedDevices.Count -gt 0) {
    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath "$fileNameBase.csv"
        $flaggedDevices | Export-Csv -Path $csvFilePath -NoTypeInformation
        $reportFiles += $csvFilePath
        Write-RjRbLog -Message "Exported devices with low disk space to CSV: $($csvFilePath)" -Verbose
    }
    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath "$fileNameBase.xlsx"
        $highlightRules = @(
            @{ Column = 'Severity'; Value = 'Critical'; Color = 'Red' }
            @{ Column = 'Severity'; Value = 'Warning'; Color = 'Yellow' }
        )
        $flaggedDevices | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Low Disk Space" -HighlightRules $highlightRules
        $reportFiles += $xlsxFilePath
        Write-RjRbLog -Message "Exported devices with low disk space to XLSX: $($xlsxFilePath)" -Verbose
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

#endregion

########################################################
#region     Email Report
########################################################

# Send email report (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
$emailSubject = "Devices Low Disk Space Report - $($tenantDisplayName) - $($thresholdTextPlain)"

$brandingMailParams = @{}
if ($EmailTo) {
    Write-Output "Sending report to '$($EmailTo)'..."

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        if ($reportFiles.Count -gt 0) {
            $markdownFallback = @"
# Devices Low Disk Space Report

This report shows managed devices that reported $($thresholdText).

## Summary Statistics

- Devices below threshold: **$($flaggedDevices.Count)**
- Critical: **$($criticalCount)**
- Warning: **$($warningCount)**

## Attachments

- **$($fileNameBase).xlsx**: Formatted Excel workbook with the complete list of devices with low disk space

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
                Send-RjRbReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFilePath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjRbReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
            }
        }
        else {
            Send-RjRbReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version @brandingMailParams
        }

        Write-RjRbLog -Message "Email report sent successfully to: $($EmailTo)" -Verbose
        Write-Output "Low disk space report generated and sent successfully"
        Write-Output "Recipient: $($EmailTo)"
        Write-Output "Devices below the threshold: $($flaggedDevices.Count)"
        Write-Output "Threshold: $($thresholdTextPlain)"
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

#endregion

########################################################
#region     Cleanup
########################################################

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

# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

#endregion

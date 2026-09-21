<#
    .SYNOPSIS
    List managed mobile devices with inventory and network details

    .DESCRIPTION
    Lists all Intune managed Android, iOS and iPadOS devices with their inventory: IMEI, serial number, phone number, carrier, ownership, compliance and enrollment. Optionally the last reported IP address and subnet, ICCID, eSIM identifier, cellular technology, UDID, battery health and Shared iPad state are added. That shows in which networks the devices were last active. The list can be limited by platform, a device group or a group of the primary users. The report can be sent by email or provided as a download link.

    .PARAMETER Android
    Includes Android devices.

    .PARAMETER iOS
    Includes iOS and iPadOS devices.

    .PARAMETER IncludeNetworkDetails
    Adds IP address, subnet, ICCID, eSIM identifier, cellular technology, UDID, battery health and Shared iPad state. Needs one extra request per device, so large tenants take longer.

    .PARAMETER IncludePhoneNumber
    Shows the phone number column. Intune masks part of the number on personally owned devices anyway.

    .PARAMETER IncludeDeviceGroup
    Only devices in this Entra ID group, nested groups included. Leave empty for all mobile devices.

    .PARAMETER IncludeUserGroup
    Only devices whose primary user is in this group, nested groups included. Leave empty for all.

    .PARAMETER EmailTo
    Send the report to these addresses, separated by commas. Leave empty to only show the result in the run output.

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
            "Android": {
                "DisplayName": "Include Android devices?"
            },
            "iOS": {
                "DisplayName": "Include iOS/iPadOS devices?"
            },
            "IncludeNetworkDetails": {
                "DisplayName": "Include network and SIM details?"
            },
            "IncludePhoneNumber": {
                "DisplayName": "Include phone numbers?"
            },
            "IncludeDeviceGroup": {
                "DisplayName": "Limit to devices in group"
            },
            "IncludeUserGroup": {
                "DisplayName": "Limit to primary users in group"
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
                "DisplayName": "Create a download link?",
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
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [bool] $Android = $true,
    [bool] $iOS = $true,
    [bool] $IncludeNetworkDetails = $false,
    [bool] $IncludePhoneNumber = $true,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Limit to devices in group" } )]
    [string] $IncludeDeviceGroup,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Limit to primary users in group" } )]
    [string] $IncludeUserGroup,
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
    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'XLSX only',
    [bool] $CreateDownloadLink = $false,
    [string] $ContainerName = "list-mobile-devices",
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
Write-RjRbLog -Message "Android: $Android" -Verbose
Write-RjRbLog -Message "iOS: $iOS" -Verbose
Write-RjRbLog -Message "IncludeNetworkDetails: $IncludeNetworkDetails" -Verbose
Write-RjRbLog -Message "IncludePhoneNumber: $IncludePhoneNumber" -Verbose
Write-RjRbLog -Message "IncludeDeviceGroup: $IncludeDeviceGroup" -Verbose
Write-RjRbLog -Message "IncludeUserGroup: $IncludeUserGroup" -Verbose
Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
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
if ($Android) { $selectedPlatforms += 'Android' }
if ($iOS) { $selectedPlatforms += 'iOS/iPadOS' }

if ($selectedPlatforms.Count -eq 0) {
    throw "All platform filters are disabled. Enable at least one platform (Android, iOS/iPadOS) to list mobile devices."
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

function Test-PlatformIncluded {
    <#
        .SYNOPSIS
        Checks whether a device's operating system is included by the platform filter parameters.

        .PARAMETER OperatingSystem
        The operatingSystem value of the managed device as reported by Intune.
    #>
    param([string]$OperatingSystem)

    switch -Wildcard ($OperatingSystem) {
        "iOS*" { return $iOS }
        "iPadOS*" { return $iOS }
        "Android*" { return $Android }
        default { return $false }
    }
}

function Get-MobileDeviceDetails {
    <#
        .SYNOPSIS
        Retrieves per-device network and SIM details for a list of managed devices via Graph JSON batching.

        .DESCRIPTION
        Graph returns the hardware details (last reported IP address, subnet, ICCID, UDID, ...) only on a
        single-device GET, so each device has to be queried individually. The requests are sent through the
        Graph $batch endpoint by the module function Invoke-RjRbGraphBatch, which handles the chunking
        (20 requests per call, a partial final chunk works the same way), the transport and the retry of
        throttled inner requests (status 429) with the Retry-After interval reported by Graph. Requests that
        are still throttled after the last retry and other failed requests are reported as warnings and do
        not abort the run.

        .PARAMETER DeviceIds
        The Intune managed device ids to fetch details for.
    #>
    param(
        [array]$DeviceIds
    )

    $details = @{}
    if (-not $DeviceIds -or $DeviceIds.Count -eq 0) {
        return $details
    }

    # The device id doubles as the request id for correlation
    $requests = foreach ($deviceId in $DeviceIds) {
        @{
            id     = "$deviceId"
            method = "GET"
            url    = "/deviceManagement/managedDevices('$deviceId')?`$select=id,iccid,udid,hardwareInformation"
        }
    }

    $responses = Invoke-RjRbGraphBatch -Requests @($requests) -Beta -ProgressLabel "devices" -ProgressInterval 10

    foreach ($item in $responses) {
        if ($item.status -eq 200) {
            $details["$($item.id)"] = $item.body
        }
        elseif ($item.status -eq 429) {
            Write-Warning "Could not retrieve network/SIM details for device id '$($item.id)' (still throttled after retries)."
        }
        else {
            Write-RjRbLog -Message "Device detail request for '$($item.id)' failed with status $($item.status)." -Verbose
            Write-Warning "Could not retrieve network/SIM details for device id '$($item.id)' (HTTP $($item.status))."
        }
    }

    return $details
}

function Limit-DisplayLength {
    <#
        .SYNOPSIS
        Truncates a value for the console table output.

        .PARAMETER Value
        The raw value to display.

        .PARAMETER MaxLength
        Values longer than this are truncated and suffixed with "..".
    #>
    param(
        [string]$Value,
        [int]$MaxLength = 15
    )

    if (-not $Value) { return "N/A" }
    if ($Value.Length -gt $MaxLength) { return $Value.Substring(0, $MaxLength - 1) + ".." }
    return $Value
}

#endregion

########################################################
#region     Connect Part
########################################################

# Connect to Microsoft Graph
Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop

# Get tenant information (used for the report file names, the email subject and the email footer)
$tenantDisplayName = "Unknown Tenant"
if ($EmailTo -or $CreateDownloadLink) {
    Write-Output "## Retrieving tenant information..."
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
}

# Connect RJ RunbookHelper for email reporting
if ($EmailTo) {
    Write-Output "Graph connection for RJ RunbookHelper..."
    Connect-RjRbGraph
}

Write-Output ""

#endregion

########################################################
#region     Data Collection
########################################################

Write-Output "## Listing mobile devices"
Write-Output "Included platforms: $($platformSummary)"
if ($IncludeNetworkDetails) {
    Write-Output "Note: Network/SIM details require one additional Graph request per device (sent in batches of 20)."
    Write-Output "On tenants with many mobile devices this may take a while - use the group filters to narrow the scope."
}
Write-Output ""

# Resolve the optional group scope filters first, using transitiveMembers so nested group memberships
# are included. Group members of type #microsoft.graph.device expose their Entra Device ID via the
# 'deviceId' property, which corresponds to the managedDevice 'azureADDeviceId'.
$includeDeviceIds = @()
if (-not [string]::IsNullOrEmpty($IncludeDeviceGroup)) {
    Write-Output "Retrieving members of the device group (including nested groups)..."
    try {
        $groupUri = "https://graph.microsoft.com/v1.0/groups/$IncludeDeviceGroup/transitiveMembers?`$select=id,deviceId,displayName"
        $groupMembers = Get-GraphPagedResult -Uri $groupUri
        $includeDeviceIds = @($groupMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' -and -not [string]::IsNullOrEmpty($_.deviceId) } | ForEach-Object { $_.deviceId.ToLower() })
        Write-Output "Device group contains $($includeDeviceIds.Count) device(s)."
    }
    catch {
        Write-Error "Failed to retrieve members of the device group ('$IncludeDeviceGroup'): $($_.Exception.Message)" -ErrorAction Continue
        throw "Unable to retrieve device group membership"
    }
}

$includeUserIds = @()
if (-not [string]::IsNullOrEmpty($IncludeUserGroup)) {
    Write-Output "Retrieving members of the user group (including nested groups)..."
    try {
        $groupUri = "https://graph.microsoft.com/v1.0/groups/$IncludeUserGroup/transitiveMembers?`$select=id,userPrincipalName"
        $groupMembers = Get-GraphPagedResult -Uri $groupUri
        $includeUserIds = @($groupMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' -and -not [string]::IsNullOrEmpty($_.id) } | ForEach-Object { $_.id.ToLower() })
        Write-Output "User group contains $($includeUserIds.Count) user(s)."
    }
    catch {
        Write-Error "Failed to retrieve members of the user group ('$IncludeUserGroup'): $($_.Exception.Message)" -ErrorAction Continue
        throw "Unable to retrieve user group membership"
    }
}

# The mobile platforms are filtered server-side; iPads can report either 'iOS' or 'iPadOS'.
$osFilters = @()
if ($Android) { $osFilters += "operatingSystem eq 'Android'" }
if ($iOS) {
    $osFilters += "operatingSystem eq 'iOS'"
    $osFilters += "operatingSystem eq 'iPadOS'"
}
$encodedFilter = [System.Uri]::EscapeDataString("(" + ($osFilters -join " or ") + ")")

$selectProperties = @(
    'id'
    'deviceName'
    'userId'
    'userPrincipalName'
    'userDisplayName'
    'operatingSystem'
    'osVersion'
    'manufacturer'
    'model'
    'serialNumber'
    'imei'
    'subscriberCarrier'
    'wiFiMacAddress'
    'managedDeviceOwnerType'
    'complianceState'
    'jailBroken'
    'isSupervised'
    'isEncrypted'
    'deviceEnrollmentType'
    'enrollmentProfileName'
    'deviceCategoryDisplayName'
    'androidSecurityPatchLevel'
    'partnerReportedThreatState'
    'lastSyncDateTime'
    'enrolledDateTime'
    'freeStorageSpaceInBytes'
    'totalStorageSpaceInBytes'
    'azureADDeviceId'
)
if ($IncludePhoneNumber) {
    $selectProperties += 'phoneNumber'
}
$selectString = ($selectProperties -join ',')

$devicesUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=$selectString&`$filter=$encodedFilter"
$devices = Get-GraphPagedResult -Uri $devicesUri
Write-Output "Mobile devices returned by Intune: $(($devices | Measure-Object).Count)"

#endregion

########################################################
#region     Data Processing
########################################################

$mobileDevices = @()

foreach ($device in $devices) {
    # Safety net in case the server-side filter returned additional platforms
    if (-not (Test-PlatformIncluded -OperatingSystem $device.operatingSystem)) {
        continue
    }

    if ($includeDeviceIds.Count -gt 0) {
        $entraDeviceId = if ($device.azureADDeviceId) { "$($device.azureADDeviceId)".ToLower() } else { "" }
        if ($includeDeviceIds -notcontains $entraDeviceId) { continue }
    }

    if ($includeUserIds.Count -gt 0) {
        $primaryUserId = if ($device.userId) { "$($device.userId)".ToLower() } else { "" }
        if ($includeUserIds -notcontains $primaryUserId) { continue }
    }

    $totalBytes = [double]($device.totalStorageSpaceInBytes)
    $freeBytes = [double]($device.freeStorageSpaceInBytes)

    $mobileDevices += [PSCustomObject]@{
        DeviceName        = $device.deviceName
        PrimaryUser       = $device.userPrincipalName
        UserDisplayName   = $device.userDisplayName
        OperatingSystem   = $device.operatingSystem
        OSVersion         = $device.osVersion
        Manufacturer      = $device.manufacturer
        Model             = $device.model
        SerialNumber      = $device.serialNumber
        IMEI              = $device.imei
        PhoneNumber       = if ($IncludePhoneNumber) { $device.phoneNumber } else { $null }
        Carrier           = $device.subscriberCarrier
        Ownership         = $device.managedDeviceOwnerType
        Compliance        = $device.complianceState
        Jailbroken        = $device.jailBroken
        Supervised        = $device.isSupervised
        Encrypted         = $device.isEncrypted
        ThreatState       = $device.partnerReportedThreatState
        PatchLevel        = $device.androidSecurityPatchLevel
        EnrollmentType    = $device.deviceEnrollmentType
        EnrollmentProfile = $device.enrollmentProfileName
        Category          = $device.deviceCategoryDisplayName
        FreeGB            = if ($totalBytes -gt 0) { [math]::Round($freeBytes / 1GB, 1) } else { $null }
        TotalGB           = if ($totalBytes -gt 0) { [math]::Round($totalBytes / 1GB, 1) } else { $null }
        WiFiMAC           = $device.wiFiMacAddress
        LastSync          = if ($device.lastSyncDateTime) { Get-Date $device.lastSyncDateTime -Format "yyyy-MM-dd HH:mm" } else { "N/A" }
        Enrolled          = if ($device.enrolledDateTime) { Get-Date $device.enrolledDateTime -Format "yyyy-MM-dd" } else { "N/A" }
        DeviceId          = $device.id
        IPv4              = $null
        Subnet            = $null
        ICCID             = $null
        ESIM              = $null
        Cellular          = $null
        UDID              = $null
        BatteryHealth     = $null
        Shared            = $null
    }
}

$devicesWithoutIp = 0
if ($IncludeNetworkDetails -and $mobileDevices.Count -gt 0) {
    Write-Output ""
    Write-Output "## Retrieving network/SIM details for $($mobileDevices.Count) device(s)..."
    $deviceDetails = Get-MobileDeviceDetails -DeviceIds @($mobileDevices.DeviceId)

    foreach ($device in $mobileDevices) {
        $detail = $deviceDetails[$device.DeviceId]
        if ($detail) {
            $hardwareInfo = $detail.hardwareInformation
            $device.IPv4 = $hardwareInfo.ipAddressV4
            $device.Subnet = $hardwareInfo.subnetAddress
            $device.ESIM = $hardwareInfo.esimIdentifier
            $device.Cellular = $hardwareInfo.cellularTechnology
            $device.BatteryHealth = $hardwareInfo.batteryHealthPercentage
            $device.Shared = $hardwareInfo.isSharedDevice
            $device.ICCID = $detail.iccid
            $device.UDID = $detail.udid
        }
        if (-not $device.IPv4) {
            $devicesWithoutIp++
        }
    }
}

$mobileDevices = @($mobileDevices | Sort-Object -Property DeviceName)

$androidCount = @($mobileDevices | Where-Object { $_.OperatingSystem -like "Android*" }).Count
$iosCount = @($mobileDevices | Where-Object { $_.OperatingSystem -like "iOS*" -or $_.OperatingSystem -like "iPadOS*" }).Count
$noncompliantCount = @($mobileDevices | Where-Object { $_.Compliance -eq 'noncompliant' }).Count
$personalCount = @($mobileDevices | Where-Object { $_.Ownership -eq 'personal' }).Count

#endregion

########################################################
#region     Output
########################################################

Write-Output ""
Write-Output "## Summary of mobile devices:"
Write-Output "Mobile devices found: $($mobileDevices.Count)"

if ($Android) { Write-Output "  Android: $($androidCount)" }
if ($iOS) { Write-Output "  iOS/iPadOS: $($iosCount)" }

$mobileDevices | Group-Object -Property Compliance | Sort-Object -Property Name | ForEach-Object {
    Write-Output "Compliance '$($_.Name)': $($_.Count)"
}
$mobileDevices | Group-Object -Property Ownership | Sort-Object -Property Name | ForEach-Object {
    Write-Output "Ownership '$($_.Name)': $($_.Count)"
}

if (-not [string]::IsNullOrEmpty($IncludeDeviceGroup)) { Write-Output "Device group filter applied ($($includeDeviceIds.Count) group member(s))." }
if (-not [string]::IsNullOrEmpty($IncludeUserGroup)) { Write-Output "User group filter applied ($($includeUserIds.Count) group member(s))." }
if ($IncludeNetworkDetails) { Write-Output "Devices without a reported IP address: $($devicesWithoutIp)" }

if ($mobileDevices.Count -eq 0) {
    Write-Output ""
    Write-Output "No mobile devices found matching the selected platforms and filters."
}
else {
    Write-Output ""
    Write-Output "## Inventory:"
    Write-Output ""

    $inventoryRows = @()
    foreach ($device in $mobileDevices) {
        $row = [ordered]@{
            DeviceName   = Limit-DisplayLength -Value $device.DeviceName
            User         = Limit-DisplayLength -Value $device.PrimaryUser -MaxLength 25
            OS           = $device.OperatingSystem
            OSVersion    = $device.OSVersion
            Manufacturer = Limit-DisplayLength -Value $device.Manufacturer
            Model        = Limit-DisplayLength -Value $device.Model -MaxLength 20
            SerialNumber = Limit-DisplayLength -Value $device.SerialNumber -MaxLength 20
            IMEI         = if ($device.IMEI) { $device.IMEI } else { "N/A" }
        }
        if ($IncludePhoneNumber) {
            $row["PhoneNumber"] = if ($device.PhoneNumber) { $device.PhoneNumber } else { "N/A" }
        }
        $row["Carrier"] = Limit-DisplayLength -Value $device.Carrier
        $row["Ownership"] = $device.Ownership
        $row["Compliance"] = $device.Compliance
        $row["LastSync"] = $device.LastSync
        $inventoryRows += [PSCustomObject]$row
    }
    $inventoryRows | Format-Table -AutoSize

    Write-Output ""
    Write-Output "## Security and enrollment:"
    Write-Output ""

    $securityRows = @()
    foreach ($device in $mobileDevices) {
        $securityRows += [PSCustomObject]@{
            DeviceName        = Limit-DisplayLength -Value $device.DeviceName
            Supervised        = $device.Supervised
            Encrypted         = $device.Encrypted
            Jailbroken        = if ($device.Jailbroken) { $device.Jailbroken } else { "N/A" }
            ThreatState       = $device.ThreatState
            PatchLevel        = if ($device.PatchLevel) { $device.PatchLevel } else { "N/A" }
            EnrollmentType    = $device.EnrollmentType
            EnrollmentProfile = Limit-DisplayLength -Value $device.EnrollmentProfile -MaxLength 20
            Category          = Limit-DisplayLength -Value $device.Category
            FreeGB            = $device.FreeGB
            TotalGB           = $device.TotalGB
            Enrolled          = $device.Enrolled
        }
    }
    $securityRows | Format-Table -AutoSize

    if ($IncludeNetworkDetails) {
        Write-Output ""
        Write-Output "## Network and SIM (sorted by subnet):"
        Write-Output ""

        $networkRows = @()
        foreach ($device in ($mobileDevices | Sort-Object -Property Subnet, DeviceName)) {
            $networkRows += [PSCustomObject]@{
                DeviceName    = Limit-DisplayLength -Value $device.DeviceName
                IPv4          = if ($device.IPv4) { $device.IPv4 } else { "N/A" }
                Subnet        = if ($device.Subnet) { $device.Subnet } else { "N/A" }
                WiFiMAC       = if ($device.WiFiMAC) { $device.WiFiMAC } else { "N/A" }
                ICCID         = if ($device.ICCID) { $device.ICCID } else { "N/A" }
                ESIM          = Limit-DisplayLength -Value $device.ESIM -MaxLength 20
                Cellular      = if ($device.Cellular) { $device.Cellular } else { "N/A" }
                UDID          = Limit-DisplayLength -Value $device.UDID -MaxLength 20
                BatteryHealth = $device.BatteryHealth
                Shared        = $device.Shared
                LastSync      = $device.LastSync
            }
        }
        $networkRows | Format-Table -AutoSize
    }
}

#endregion

########################################################
#region     Email Report Content
########################################################

if ($EmailTo) {
    Write-Output ""
    Write-Output "## Preparing email report to send to $($EmailTo)"
}

$scopeSummary = @()
if (-not [string]::IsNullOrEmpty($IncludeDeviceGroup)) { $scopeSummary += "Device group ($($includeDeviceIds.Count) member(s))" }
if (-not [string]::IsNullOrEmpty($IncludeUserGroup)) { $scopeSummary += "User group ($($includeUserIds.Count) member(s))" }
$scopeSummaryText = if ($scopeSummary.Count -gt 0) { $scopeSummary -join ' | ' } else { 'None (all mobile devices)' }
$networkDetailsText = if ($IncludeNetworkDetails) { 'Included' } else { 'Not included' }

$markdownContent = if ($mobileDevices.Count -eq 0) {
    @"
# Mobile Devices Inventory Report

No managed mobile device was found for the selected platforms and scope filters.

## What We Checked

- Platforms: $($platformSummary)
- Scope filters: $($scopeSummaryText)
- Network/SIM details: $($networkDetailsText)

---

*This email was automatically generated. Please do not reply to this email.*
"@
}
else {
    @"
# Mobile Devices Inventory Report

This report lists the Intune managed mobile devices of the selected platforms with their mobile-specific inventory, security and enrollment details.

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Mobile Devices** | $($mobileDevices.Count) |
$(
    $summaryLines = @()
    if ($Android) { $summaryLines += "| **Android** | $androidCount |" }
    if ($iOS) { $summaryLines += "| **iOS/iPadOS** | $iosCount |" }
    $summaryLines += "| **Non-Compliant** | $noncompliantCount |"
    $summaryLines += "| **Personally Owned** | $personalCount |"
    if ($IncludeNetworkDetails) { $summaryLines += "| **Without Reported IP Address** | $devicesWithoutIp |" }
    $summaryLines -join "`n"
)

- Scope filters: $($scopeSummaryText)
- Network/SIM details: $($networkDetailsText)

$(
    # A subexpression joins multiple output strings with $OFS (a space), so the lines are
    # joined explicitly - otherwise the heading and its description end up on one line and
    # Markdown swallows the description into the heading.
    $headingLines = if ($mobileDevices.Count -gt 10) {
        @("## First 10 Devices (by Device Name)", "",
          "This table shows the first ten devices sorted by device name. The attached report file(s) contain the complete inventory.")
    }
    else {
        @("## Mobile Devices", "",
          "This table lists all mobile devices found for the selected platforms and scope filters.")
    }
    $headingLines -join "`n"
)


$(
    $devicesToShow = if ($mobileDevices.Count -gt 10) {
        $mobileDevices | Select-Object -First 10
    } else {
        $mobileDevices
    }

    $table = @"
| Device Name | Primary User | Operating System | Version | Model | Serial Number | Ownership | Compliance | Last Sync |
|-------------|--------------|------------------|---------|-------|---------------|-----------|------------|-----------|
"@

    foreach ($device in $devicesToShow) {
        $table += "`n| $($device.DeviceName) | $($device.PrimaryUser) | $($device.OperatingSystem) | $($device.OSVersion) | $($device.Model) | $($device.SerialNumber) | $($device.Ownership) | $($device.Compliance) | $($device.LastSync) |"
    }

    $table
)

## Data Freshness

All values come from the Intune inventory of each device, which is refreshed with the regular device check-in. They describe the state of the last successful check-in, so please use the Last Sync column to judge how current a row is. Intune does not report the Wi-Fi SSID of a device; the last reported IP address and subnet are the closest network indicator.

## Attachments

The report file(s) attached to this email contain the full mobile device inventory$(if ($IncludeNetworkDetails) { ' including the network and SIM details' }) for further analysis.

---

*This email was automatically generated. Please do not reply to this email.*

"@
}

#endregion

########################################################
#region     Export
########################################################

# Create report files in current location (only needed for the email report and/or download link)
$fileNameBase = "MobileDevicesInventory_$($tenantDisplayName)"
$csvFilePath = $null
$xlsxFilePath = $null
$reportFiles = @()
if (($EmailTo -or $CreateDownloadLink) -and $mobileDevices.Count -gt 0) {
    # Only export the columns that were actually retrieved; the optional columns stay out of the files when disabled.
    $excludedColumns = @()
    if (-not $IncludePhoneNumber) { $excludedColumns += 'PhoneNumber' }
    if (-not $IncludeNetworkDetails) { $excludedColumns += @('IPv4', 'Subnet', 'ICCID', 'ESIM', 'Cellular', 'UDID', 'BatteryHealth', 'Shared') }
    $exportDevices = @($mobileDevices | Select-Object -Property * -ExcludeProperty $excludedColumns)

    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath "$fileNameBase.csv"
        $exportDevices | Export-Csv -Path $csvFilePath -NoTypeInformation
        $reportFiles += $csvFilePath
        Write-RjRbLog -Message "Exported mobile devices to CSV: $($csvFilePath)" -Verbose
    }
    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath "$fileNameBase.xlsx"
        $highlightRules = @(
            @{ Column = 'Compliance'; Value = 'noncompliant'; Color = 'Red' }
            @{ Column = 'Compliance'; Value = 'inGracePeriod'; Color = 'Yellow' }
        )
        $exportDevices | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Mobile Devices" -HighlightRules $highlightRules
        $reportFiles += $xlsxFilePath
        Write-RjRbLog -Message "Exported mobile devices to XLSX: $($xlsxFilePath)" -Verbose
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
elseif ($CreateDownloadLink) {
    Write-Output ""
    Write-Output "No report file was created because no mobile devices were found - download link skipped."
}

#endregion

########################################################
#region     Email Report
########################################################

# Send email report (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
$emailSubject = "Mobile Devices Inventory Report - $($tenantDisplayName) - $($platformSummary)"

$brandingMailParams = @{}
if ($EmailTo) {
    Write-Output "Sending report to '$($EmailTo)'..."

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        if ($reportFiles.Count -gt 0) {
            $markdownFallback = @"
# Mobile Devices Inventory Report

This report lists the Intune managed mobile devices of the selected platforms ($($platformSummary)).

## Summary Statistics

- Mobile devices: **$($mobileDevices.Count)**
- Non-compliant: **$($noncompliantCount)**
- Personally owned: **$($personalCount)**

## Attachments

- **$($fileNameBase).xlsx**: Formatted Excel workbook with the complete mobile device inventory

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
        Write-Output "Mobile devices inventory report generated and sent successfully"
        Write-Output "Recipient: $($EmailTo)"
        Write-Output "Mobile devices: $($mobileDevices.Count)"
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

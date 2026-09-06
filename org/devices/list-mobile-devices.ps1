<#
    .SYNOPSIS
    Lists all managed mobile devices (Android, iOS/iPadOS) with mobile-specific inventory, security and network details.

    .DESCRIPTION
    Lists all Intune managed mobile devices with their mobile-specific inventory such as IMEI, serial number, phone number,
    carrier, ownership, compliance and enrollment details.
    Optionally the last reported IP address and subnet, ICCID, eSIM identifier, cellular technology, UDID, battery health
    and Shared iPad state are added per device, which helps to see in which (Wi-Fi) networks the devices were last active.
    The result can be narrowed down by platform and by an Entra device group and/or a user group of the primary users.

    .NOTES
    Intune does not report the Wi-Fi SSID of a device. The last reported IP address and subnet are the closest network
    indicator and should always be interpreted together with the Last Sync column, because they describe the state of the
    last successful device check-in - which can also have happened over cellular.

    Data source and freshness:
    All values are taken from the Intune inventory of each device, which is refreshed with the regular device check-in.
    They therefore describe the state of the last successful check-in and not necessarily the current state.
    The network and SIM details (IP address, subnet, ICCID, UDID, ...) are not part of the Graph device list response and
    are retrieved with one additional Graph request per device, sent through the Graph batch endpoint in chunks of up to 20.

    Performance:
    With network/SIM details enabled the runtime grows linearly with the number of mobile devices. On tenants with many
    mobile devices, combine the option with the group scope filters or disable it when only inventory data is needed.

    Common Use Cases:
    - Inventory of all mobile devices including IMEI, serial number, phone number and carrier
    - Identifying in which (Wi-Fi) networks mobile devices were last active, e.g. handheld scanners across warehouse locations
    - Reviewing compliance, supervision and encryption state of the mobile fleet
    - SIM/eSIM inventory via ICCID and eSIM identifier

    .PARAMETER Android
    Include Android devices in the results.

    .PARAMETER iOS
    Include iOS and iPadOS devices in the results.

    .PARAMETER IncludeNetworkDetails
    Adds last reported IP address and subnet, ICCID, eSIM identifier, cellular technology, UDID, battery health and Shared
    iPad state to the output. Requires one additional Graph request per device (sent in batches of 20), so the runtime grows
    with the number of devices.

    .PARAMETER IncludePhoneNumber
    Controls whether the phone number is retrieved and shown. When disabled, the phone number column is omitted entirely.
    Note that Intune partially masks the phone number of personally owned devices anyway.

    .PARAMETER IncludeDeviceGroup
    Only include devices that are members of this Entra device group. Nested group memberships are resolved. Leave empty to include all mobile devices.

    .PARAMETER IncludeUserGroup
    Only include devices whose primary user is a member of this Entra user group. Nested group memberships are resolved. Leave empty to include all mobile devices.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Android": {
                "DisplayName": "Include Android Devices"
            },
            "iOS": {
                "DisplayName": "Include iOS/iPadOS Devices"
            },
            "IncludeNetworkDetails": {
                "DisplayName": "Include network/SIM details (one extra Graph call per device - slower on many devices)"
            },
            "IncludePhoneNumber": {
                "DisplayName": "Include phone numbers in the output"
            },
            "IncludeDeviceGroup": {
                "DisplayName": "Limit to devices in group (optional)"
            },
            "IncludeUserGroup": {
                "DisplayName": "Limit to primary users in group (optional)"
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
    [bool] $Android = $true,
    [bool] $iOS = $true,
    [bool] $IncludeNetworkDetails = $true,
    [bool] $IncludePhoneNumber = $true,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Limit to devices in group (optional)" } )]
    [string] $IncludeDeviceGroup,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Limit to primary users in group (optional)" } )]
    [string] $IncludeUserGroup,
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

#endregion

########################################################
#region     Parameter Validation
########################################################

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
        single-device GET, so each device has to be queried individually. The requests are always sent through
        the Graph $batch endpoint in chunks of up to 20 requests - a partial final chunk (e.g. 16 devices as one
        batch of 16 requests) works the same way. Throttled requests are retried once, other failed requests are
        reported as warnings and do not abort the run.

        .PARAMETER DeviceIds
        The Intune managed device ids to fetch details for.
    #>
    param(
        [array]$DeviceIds
    )

    $details = @{}
    $batchSize = 20
    $batchUri = "https://graph.microsoft.com/beta/`$batch"

    $pendingIds = @($DeviceIds)
    $maxAttempts = 2

    for ($attempt = 1; $attempt -le $maxAttempts -and $pendingIds.Count -gt 0; $attempt++) {
        $throttledIds = @()
        $totalBatches = [math]::Ceiling($pendingIds.Count / $batchSize)
        $batchIndex = 0

        for ($offset = 0; $offset -lt $pendingIds.Count; $offset += $batchSize) {
            $batchIndex++
            $lastIndex = [math]::Min($offset + $batchSize, $pendingIds.Count) - 1
            $chunk = @($pendingIds[$offset..$lastIndex])

            $requests = @()
            foreach ($deviceId in $chunk) {
                $requests += @{
                    id     = "$deviceId"
                    method = "GET"
                    url    = "/deviceManagement/managedDevices('$deviceId')?`$select=id,iccid,udid,hardwareInformation"
                }
            }

            $body = @{ requests = $requests } | ConvertTo-Json -Depth 4
            $response = Invoke-MgGraphRequest -Uri $batchUri -Method POST -Body $body -ContentType "application/json"

            foreach ($item in $response.responses) {
                if ($item.status -eq 200) {
                    $details[$item.id] = $item.body
                }
                elseif ($item.status -eq 429) {
                    $throttledIds += $item.id
                }
                else {
                    Write-RjRbLog -Message "Device detail request for '$($item.id)' failed with status $($item.status)." -Verbose
                    Write-Warning "Could not retrieve network/SIM details for device id '$($item.id)' (HTTP $($item.status))."
                }
            }

            if (($batchIndex % 10) -eq 0 -or $batchIndex -eq $totalBatches) {
                Write-Output "Processed detail batch $batchIndex of $totalBatches..."
            }
        }

        if ($throttledIds.Count -gt 0 -and $attempt -lt $maxAttempts) {
            Write-Output "Graph throttled $($throttledIds.Count) request(s), waiting 20 seconds before retrying..."
            Start-Sleep -Seconds 20
        }
        $pendingIds = $throttledIds
    }

    foreach ($deviceId in $pendingIds) {
        Write-Warning "Could not retrieve network/SIM details for device id '$deviceId' (still throttled after retry)."
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

#endregion

########################################################
#region     Output
########################################################

Write-Output ""
Write-Output "## Summary of mobile devices:"
Write-Output "Mobile devices found: $($mobileDevices.Count)"

$androidCount = @($mobileDevices | Where-Object { $_.OperatingSystem -like "Android*" }).Count
$iosCount = @($mobileDevices | Where-Object { $_.OperatingSystem -like "iOS*" -or $_.OperatingSystem -like "iPadOS*" }).Count
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

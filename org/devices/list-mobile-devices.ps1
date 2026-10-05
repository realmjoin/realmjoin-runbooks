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

	.PARAMETER SendEmailReport
	Send the report to the recipient email address.

	.PARAMETER EmailTo
	Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

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
			"CreateDownloadLink": {
				"Hide": true
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
			"SendEmailReport": {
				"Hide": true
			},
			"EmailTo": {
				"DisplayName": "Recipient email address(es)",
				"Hide": true
			},
			"CallerName": {
				"Hide": true
			}
		},
		"ParameterList": [
			{
				"DisplayName": "Report delivery",
				"DisplayAfter": "IncludeUserGroup",
				"Select": {
					"Options": [
						{
							"Display": "Output Data only",
							"ParameterValue": "Output Data only",
							"Customization": {
								"Default": { "SendEmailReport": false, "CreateDownloadLink": false },
								"Hide": [ "EmailTo", "ReportFileFormat" ]
							}
						},
						{
							"Display": "Also email the report",
							"ParameterValue": "Also email the report",
							"Customization": {
								"Default": { "SendEmailReport": true, "CreateDownloadLink": false },
								"Show": [ "EmailTo", "ReportFileFormat" ],
								"Mandatory": [ "EmailTo" ]
							}
						},
						{
							"Display": "Also create a download link",
							"ParameterValue": "Also create a download link",
							"Customization": {
								"Default": { "SendEmailReport": false, "CreateDownloadLink": true },
								"Show": [ "ReportFileFormat" ],
								"Hide": [ "EmailTo" ]
							}
						},
						{
							"Display": "Also email & download link",
							"ParameterValue": "Also email & download link",
							"Customization": {
								"Default": { "SendEmailReport": true, "CreateDownloadLink": true },
								"Show": [ "EmailTo", "ReportFileFormat" ],
								"Mandatory": [ "EmailTo" ]
							}
						}
					]
				},
				"Default": "Output Data only"
			}
		]
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
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string] $EmailFrom,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" } )]
    [string] $BrandingHeaderImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" } )]
    [string] $BrandingFooterImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" } )]
    [string] $BrandingFooterLink,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" } )]
    [string] $BrandingAccentColor,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" } )]
    [string] $BrandingTextColor,
    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'XLSX only',
    [bool] $CreateDownloadLink = $false,
    [string] $ContainerName = "list-mobile-devices",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,
    [bool] $SendEmailReport = $false,
    [Parameter(Mandatory = $false)]
    [string] $EmailTo,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Android: $Android" -Verbose
Write-RjRbLog -Message "iOS: $iOS" -Verbose
Write-RjRbLog -Message "IncludeNetworkDetails: $IncludeNetworkDetails" -Verbose
Write-RjRbLog -Message "IncludePhoneNumber: $IncludePhoneNumber" -Verbose
Write-RjRbLog -Message "IncludeDeviceGroup: $IncludeDeviceGroup" -Verbose
Write-RjRbLog -Message "IncludeUserGroup: $IncludeUserGroup" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
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
Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

# Schedules created before the "Report delivery" choice existed pass a recipient but no SendEmailReport.
# For them the recipient alone keeps the email enabled; every newer run passes SendEmailReport explicitly.
$sendEmail = if ($PSBoundParameters.ContainsKey('SendEmailReport')) { $SendEmailReport } else { [bool]$EmailTo }

# Email delivery needs a recipient
if ($sendEmail -and -not $EmailTo) {
    Write-Error "Email delivery is selected but no recipient email address was provided." -ErrorAction Continue
    throw "Missing recipient email address (EmailTo)"
}

# A configured sender address is required before any mail can be sent
if ($sendEmail -and -not $EmailFrom) {
    Write-Error "The sender email address is missing. Configure the tenant setting RJReport.EmailSender in the runbook customization (https://docs.realmjoin.com/automation/runbooks/runbook-report-settings)." -ErrorAction Continue
    throw "Missing email sender configuration (RJReport.EmailSender)"
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Error "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* tenant settings in the runbook customization (https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) or pass ResourceGroupName and StorageAccountName when starting the runbook." -ErrorAction Continue
    throw "Missing storage account configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)"
}

# At least one platform has to be evaluated
$selectedPlatforms = @()
if ($Android) { $selectedPlatforms += 'Android' }
if ($iOS) { $selectedPlatforms += 'iOS/iPadOS' }

if ($selectedPlatforms.Count -eq 0) {
    Write-Error "All platform filters are disabled. Enable at least one platform (Android, iOS/iPadOS) to list mobile devices." -ErrorAction Continue
    throw "No platform selected"
}

$platformSummary = $selectedPlatforms -join ', '
Write-Output "Included platforms: $($platformSummary)"
Write-Output "Parameter validation passed."

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

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

Write-Output ""
Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity is configured correctly. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

# Tenant display name for the report file names, the email subject and the email footer (needs Organization.Read.All)
$tenantDisplayName = "Unknown Tenant"
if ($sendEmail -or $CreateDownloadLink) {
    try {
        $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
        if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
            $tenantDisplayName = $organizationResponse.value[0].displayName
        }
        Write-Output "Tenant: $tenantDisplayName"
    }
    catch {
        Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
    }
}

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

Write-Output ""
Write-Output "Get Mobile Devices"
Write-Output "---------------------"
if ($IncludeNetworkDetails) {
    Write-Output "Note: Network/SIM details require one additional Graph request per device (sent in batches of 20)."
    Write-Output "On tenants with many mobile devices this may take a while - use the group filters to narrow the scope."
}

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

Write-Output "Retrieving the mobile devices from Intune. This may take a while in large tenants."
$devicesUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=$selectString&`$filter=$encodedFilter"
$devices = Get-GraphPagedResult -Uri $devicesUri
Write-Output "Mobile devices returned by Intune: $(($devices | Measure-Object).Count)"

#endregion Data Collection

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

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
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
Write-RjRbLog -Message "Mobile devices: $($mobileDevices.Count); Android: $androidCount; iOS/iPadOS: $iosCount; non-compliant: $noncompliantCount; personally owned: $personalCount" -Verbose

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$csvFilePath = $null
$xlsxFilePath = $null
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "MobileDevicesInventory_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
# The tenant display name comes from Graph and may contain characters that are illegal in a file name
$safeTenantName = $tenantDisplayName -replace '[\\/:*?"<>|]', '_'
$fileNameBase = "MobileDevicesInventory_$($safeTenantName)"

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if (($sendEmail -or $CreateDownloadLink) -and $mobileDevices.Count -gt 0) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    # Only export the columns that were actually retrieved; the optional columns stay out of the files when disabled.
    $excludedColumns = @()
    if (-not $IncludePhoneNumber) { $excludedColumns += 'PhoneNumber' }
    if (-not $IncludeNetworkDetails) { $excludedColumns += @('IPv4', 'Subnet', 'ICCID', 'ESIM', 'Cellular', 'UDID', 'BatteryHealth', 'Shared') }
    $exportDevices = @($mobileDevices | Select-Object -Property * -ExcludeProperty $excludedColumns)

    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFilePath = Join-Path -Path $tempDir -ChildPath "$fileNameBase.csv"
        $exportDevices | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvFilePath
        Write-RjRbLog -Message "Exported mobile devices to CSV: $($csvFilePath)" -Verbose
    }
    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFilePath = Join-Path -Path $tempDir -ChildPath "$fileNameBase.xlsx"
        $highlightRules = @(
            @{ Column = 'Compliance'; Value = 'noncompliant'; Color = 'Red' }
            @{ Column = 'Compliance'; Value = 'inGracePeriod'; Color = 'Yellow' }
        )
        $exportDevices | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Mobile Devices" -HighlightRules $highlightRules
        $reportFiles += $xlsxFilePath
        Write-RjRbLog -Message "Exported mobile devices to XLSX: $($xlsxFilePath)" -Verbose
    }

    Write-Output ""
    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
}
elseif ($mobileDevices.Count -eq 0) {
    Write-RjRbLog -Message "No mobile devices found - skipping the report file export" -Verbose
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################

if ($CreateDownloadLink) {
    Write-Output ""
    if ($reportFiles.Count -gt 0) {
        Write-Output "## Uploading the report file(s) to the storage account..."

        # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
        # transparently connects the managed identity if no Az context is active.
        try {
            $uploadResults = Publish-RjRbFilesToStorageContainer `
                -FilePaths $reportFiles `
                -ContainerName $ContainerName `
                -ResourceGroupName $ResourceGroupName `
                -StorageAccountName $StorageAccountName `
                -LinkExpiryDays $LinkExpiryDays `
                -AddBlobNamePrefix $true
        }
        catch {
            Write-Error "Failed to upload the report file(s) to storage account '$StorageAccountName': $($_.Exception.Message). The managed identity needs the 'Storage Account Contributor' role on the storage account." -ErrorAction Continue
            throw
        }

        foreach ($uploadResult in $uploadResults) {
            Write-Output ""
            Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }
    else {
        Write-Output "No report file was created because no mobile devices were found - download link skipped."
    }
}

#endregion Upload / Download Link

########################################################
#region     Send Email Report
########################################################

$brandingMailParams = @{}

if (-not $sendEmail) {
    Write-RjRbLog -Message "Email delivery not selected - email report skipped" -Verbose
}
else {
    Write-Output ""
    Write-Output "## Sending the email report to '$EmailTo'..."

    $emailSubject = "Mobile Devices Inventory Report - $($tenantDisplayName) - $($platformSummary)"

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

    $markdownFallback = @"
# Mobile Devices Inventory Report

This report lists the Intune managed mobile devices of the selected platforms ($($platformSummary)).

## Summary Statistics

- Mobile devices: **$($mobileDevices.Count)**
- Non-compliant: **$($noncompliantCount)**
- Personally owned: **$($personalCount)**

## Attachments

- **$($fileNameBase).xlsx**: Formatted Excel workbook with the complete mobile device inventory

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        $emailParams = @{
            EmailFrom             = $EmailFrom
            EmailTo               = $EmailTo
            Subject               = $emailSubject
            MarkdownContent       = $markdownContent
            TenantDisplayName     = $tenantDisplayName
            ReportVersion         = $Version
            UseNativeGraphRequest = $true
        }
        if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFilePath -and (Test-Path -Path $xlsxFilePath)) {
            # Both formats attached; the built-in size guard falls back to the workbook alone if the pair is too large
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFilePath) -FallbackMarkdownContent $markdownFallback
        }
        elseif ($reportFiles.Count -gt 0) {
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles
        }
        else {
            Send-RjRbReportEmail @emailParams @brandingMailParams
        }

        Write-RjRbLog -Message "Email report sent to: $($EmailTo)" -Verbose
        Write-Output "Email report sent to '$($EmailTo)'."
    }
    catch {
        Write-Error "Failed to send the email report: $($_.Exception.Message)" -ErrorAction Continue
        throw
    }
}

#endregion Send Email Report

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the progress output. Every table has its own
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
Write-Output ""

$summaryValues = [ordered]@{
    "Mobile devices" = $mobileDevices.Count
}
if ($Android) { $summaryValues["Android"] = $androidCount }
if ($iOS) { $summaryValues["iOS/iPadOS"] = $iosCount }
$summaryValues["Non-compliant"] = $noncompliantCount
$summaryValues["Personally owned"] = $personalCount
if ($IncludeNetworkDetails) { $summaryValues["Without reported IP address"] = $devicesWithoutIp }
$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($mobileDevices.Count -eq 0) {
    Write-Output "No mobile devices found matching the selected platforms and filters."
}
else {
    $inventoryColumns = @('DeviceName', 'PrimaryUser', 'OperatingSystem', 'OSVersion', 'Manufacturer', 'Model', 'SerialNumber', 'IMEI')
    if ($IncludePhoneNumber) { $inventoryColumns += 'PhoneNumber' }
    $inventoryColumns += @('Carrier', 'Ownership', 'Compliance', 'LastSync')
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Inventory" })
    Write-Output @($mobileDevices | Select-Object -Property $inventoryColumns)

    Write-Output ([PSCustomObject]@{ RjTableTitle = "Security and enrollment" })
    Write-Output @($mobileDevices | Select-Object -Property DeviceName, Supervised, Encrypted, Jailbroken, ThreatState, PatchLevel, EnrollmentType, EnrollmentProfile, Category, FreeGB, TotalGB, Enrolled)

    if ($IncludeNetworkDetails) {
        # Sorted by subnet, so devices group by the network they were last seen in
        Write-Output ([PSCustomObject]@{ RjTableTitle = "Network and SIM" })
        Write-Output @($mobileDevices | Sort-Object -Property Subnet, DeviceName | Select-Object -Property DeviceName, IPv4, Subnet, WiFiMAC, ICCID, ESIM, Cellular, UDID, BatteryHealth, Shared, LastSync)
    }
}

#endregion Structured Output (Output Data)

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
if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-RjRbLog -Message "Removed temporary export directory: $tempDir" -Verbose
}

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

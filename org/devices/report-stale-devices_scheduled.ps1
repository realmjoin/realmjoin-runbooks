<#
	.SYNOPSIS
	Report devices that have been inactive for too long

	.DESCRIPTION
	Lists Intune devices that have not checked in for a given number of days, optionally within a maximum age. The list can be filtered by platform and by the group membership of the primary user. Nothing is changed. The report can be sent by email or provided as a download link.

	.PARAMETER Days
	Devices with no check-in for at least this many days count as stale.

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

	.PARAMETER UseUserScope
	Not used any more. The primary user group filter applies as soon as a group is selected in "Include users from group" or "Exclude users from group". Kept so existing schedules keep working.

	.PARAMETER IncludeUserGroup
	Only devices whose primary user is a direct member of this group. Leave empty for all devices.

	.PARAMETER ExcludeUserGroup
	Skips devices whose primary user is a direct member of this group. Leave empty to skip none.

	.PARAMETER SendEmailReport
	Send the report to the recipient email address.

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
				"DisplayName": "Include iOS/iPadOS devices?"
			},
			"Android": {
				"DisplayName": "Include Android devices?"
			},
			"UseUserScope": {
				"Hide": true
			},
			"SendEmailReport": {
				"Hide": true
			},
			"EmailTo": {
				"DisplayName": "Recipient email address(es)",
				"Hide": true
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
						{ "Display": "CSV & XLSX", "ParameterValue": "CSV & XLSX" },
						{ "Display": "CSV only", "ParameterValue": "CSV only" },
						{ "Display": "XLSX only", "ParameterValue": "XLSX only" }
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
			"CallerName": {
				"Hide": true
			}
		},
		"ParameterList": [
			{
				"DisplayName": "Report delivery",
				"DisplayAfter": "ExcludeUserGroup",
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
    [int] $Days = 30,
    [int] $MaxDays = $null,
    [bool] $Windows = $true,
    [bool] $MacOS = $true,
    [bool] $iOS = $true,
    [bool] $Android = $true,
    [bool] $UseUserScope = $false,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Include users from group" } )]
    [string]$IncludeUserGroup,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclude users from group" } )]
    [string]$ExcludeUserGroup,
    [bool] $SendEmailReport = $false,
    [string] $EmailTo,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom,
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
    [string] $ReportFileFormat = 'CSV & XLSX',
    [bool] $CreateDownloadLink = $false,
    [string] $ContainerName = "report-stale-devices",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.6.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Days: $Days" -Verbose
Write-RjRbLog -Message "MaxDays: $MaxDays" -Verbose
Write-RjRbLog -Message "Windows: $Windows" -Verbose
Write-RjRbLog -Message "MacOS: $MacOS" -Verbose
Write-RjRbLog -Message "iOS: $iOS" -Verbose
Write-RjRbLog -Message "Android: $Android" -Verbose
Write-RjRbLog -Message "UseUserScope: $UseUserScope (not used any more; the user group filter applies as soon as a group is selected)" -Verbose
Write-RjRbLog -Message "IncludeUserGroup: $IncludeUserGroup" -Verbose
Write-RjRbLog -Message "ExcludeUserGroup: $ExcludeUserGroup" -Verbose
Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
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

# A maximum age only applies when it is above the minimum inactivity
$useMaxDays = ($null -ne $MaxDays -and $MaxDays -gt $Days)
$inactivityText = if ($useMaxDays) { "$Days-$MaxDays days" } else { "$Days+ days" }

Write-Output "Inactivity: $inactivityText"
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

function Format-ReportDateTime {
    <#
        .SYNOPSIS
        Formats a Graph timestamp for the report, or returns "N/A" when it is empty.

        .PARAMETER Value
        The timestamp as returned by Graph (DateTime or ISO 8601 string).
    #>
    param(
        $Value
    )

    if ($null -eq $Value -or "$Value" -eq "") { return "N/A" }
    try {
        return ([datetime]$Value).ToString("yyyy-MM-dd HH:mm:ss")
    }
    catch {
        return "$Value"
    }
}

function Get-UserGroupFilter {
    <#
        .SYNOPSIS
        Returns the display name and the user object IDs of the direct members of a group.

        .DESCRIPTION
        Returns an object with Name, UserIds and Error. Error is empty when the members were read.

        .PARAMETER GroupId
        Object ID of the group.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )

    $groupName = $GroupId
    try {
        $group = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$($GroupId)?`$select=displayName" -Method GET -ErrorAction Stop
        if ($group.displayName) { $groupName = $group.displayName }
    }
    catch {
        Write-RjRbLog -Message "Could not resolve the display name of group '$GroupId': $($_.Exception.Message)" -Verbose
    }

    $userIds = @()
    $errorText = $null
    try {
        $members = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$($GroupId)/members?`$select=id,userPrincipalName"
        $userIds = @($members | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' } | ForEach-Object { $_.id })
    }
    catch {
        $errorText = $_.Exception.Message
    }

    return [PSCustomObject]@{ Name = $groupName; UserIds = $userIds; Error = $errorText }
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

# Tenant display name for the email subject, the email body and the report file names (needs Organization.Read.All)
$tenantDisplayName = "Unknown Tenant"
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

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

Write-Output ""
Write-Output "Data Collection"
Write-Output "---------------------"

# Date threshold for stale devices
$beforeDate = (Get-Date).AddDays(-$Days) | Get-Date -Format "yyyy-MM-dd"

if ($useMaxDays) {
    # Devices inactive between Days and MaxDays
    $afterDate = (Get-Date).AddDays(-$MaxDays) | Get-Date -Format "yyyy-MM-dd"
    $filter = "lastSyncDateTime le $($beforeDate)T00:00:00Z and lastSyncDateTime ge $($afterDate)T00:00:00Z"
    Write-Output "Listing devices inactive between $Days and $MaxDays days. This may take a while in large tenants."
}
else {
    # Devices inactive for at least Days
    $filter = "lastSyncDateTime le $($beforeDate)T00:00:00Z"
    Write-Output "Listing devices not active for at least $Days days. This may take a while in large tenants."
}
Write-RjRbLog -Message "Graph filter: $filter" -Verbose

$selectProperties = @(
    'deviceName'
    'lastSyncDateTime'
    'enrolledDateTime'
    'userPrincipalName'
    'userId'
    'id'
    'serialNumber'
    'manufacturer'
    'model'
    'operatingSystem'
    'osVersion'
    'complianceState'
)
$selectString = ($selectProperties -join ',')

$encodedFilter = [uri]::EscapeDataString($filter)
$devicesUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=$selectString&`$filter=$encodedFilter"
$devices = @(Get-GraphPagedResult -Uri $devicesUri)
Write-Output "Retrieved $($devices.Count) stale device(s) from Intune (all platforms)."

#region User group filter
# The filter applies as soon as a group is selected. UseUserScope is kept for existing schedules but has no effect.
$includeUserIds = @()
$excludeUserIds = @()
$includeGroupName = $null
$excludeGroupName = $null

if ($IncludeUserGroup) {
    $includeGroup = Get-UserGroupFilter -GroupId $IncludeUserGroup
    $includeGroupName = $includeGroup.Name
    $includeUserIds = @($includeGroup.UserIds)
    if ($includeGroup.Error) {
        Write-Error "Failed to retrieve the members of the include group '$includeGroupName': $($includeGroup.Error)" -ErrorAction Continue
        throw "Unable to read the include user group - the report scope cannot be determined"
    }
    Write-Output "The include group '$includeGroupName' contains $($includeUserIds.Count) user(s)."
    if ($includeUserIds.Count -eq 0) {
        Write-Output "WARNING: The include group '$includeGroupName' has no user members - no device matches the include filter."
    }
}

if ($ExcludeUserGroup) {
    $excludeGroup = Get-UserGroupFilter -GroupId $ExcludeUserGroup
    $excludeGroupName = $excludeGroup.Name
    $excludeUserIds = @($excludeGroup.UserIds)
    if ($excludeGroup.Error) {
        Write-Error "Failed to retrieve the members of the exclude group '$excludeGroupName': $($excludeGroup.Error)" -ErrorAction Continue
        throw "Unable to read the exclude user group - the report scope cannot be determined"
    }
    Write-Output "The exclude group '$excludeGroupName' contains $($excludeUserIds.Count) user(s)."
}
#endregion User group filter

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

Write-Output ""
Write-Output "Data Processing"
Write-Output "---------------------"

$reportRows = [System.Collections.Generic.List[object]]::new()
$skippedByIncludeGroup = 0
$skippedByExcludeGroup = 0
$userCache = @{}
$now = Get-Date

foreach ($device in $devices) {
    $operatingSystem = "$($device.operatingSystem)"

    # Platform filter (Intune reports iPads as "iPadOS", iPhones as "iOS")
    $include = ($Windows -and $operatingSystem -eq "Windows") -or
    ($MacOS -and $operatingSystem -eq "macOS") -or
    ($iOS -and $operatingSystem -in @("iOS", "iPadOS")) -or
    ($Android -and $operatingSystem -eq "Android")
    if (-not $include) { continue }

    # User group filter on the primary user's object ID; a device without a primary user is never in the include group
    $primaryUserId = "$($device.userId)"
    if ($IncludeUserGroup -and (-not $primaryUserId -or ($primaryUserId -notin $includeUserIds))) {
        Write-RjRbLog -Message "Skipping device '$($device.deviceName)' - primary user '$($device.userPrincipalName)' not in include group" -Verbose
        $skippedByIncludeGroup++
        continue
    }
    if ($ExcludeUserGroup -and $primaryUserId -and ($primaryUserId -in $excludeUserIds)) {
        Write-RjRbLog -Message "Skipping device '$($device.deviceName)' - primary user '$($device.userPrincipalName)' in exclude group" -Verbose
        $skippedByExcludeGroup++
        continue
    }

    $userDisplayName = ""
    $userLocation = ""
    if ($device.userPrincipalName) {
        # Primary user details, looked up once per user
        if ($userCache.ContainsKey($device.userPrincipalName)) {
            $userInfo = $userCache[$device.userPrincipalName]
        }
        else {
            $userInfo = $null
            try {
                $encodedUserPrincipalName = [uri]::EscapeDataString($device.userPrincipalName)
                $userInfo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($encodedUserPrincipalName)?`$select=id,displayName,city,usageLocation" -Method GET -ErrorAction Stop
            }
            catch {
                Write-RjRbLog -Message "Could not retrieve user info for $($device.userPrincipalName): $($_.Exception.Message)" -Verbose
            }
            $userCache[$device.userPrincipalName] = $userInfo
        }

        if ($userInfo) {
            $userDisplayName = "$($userInfo.displayName)"
            $userLocation = "$($userInfo.city), $($userInfo.usageLocation)"
        }
    }

    $daysInactive = $null
    if ($device.lastSyncDateTime) {
        try { $daysInactive = [int][math]::Floor(($now - [datetime]$device.lastSyncDateTime).TotalDays) } catch { $daysInactive = $null }
    }

    $reportRows.Add([PSCustomObject]@{
            DeviceName             = if ($device.deviceName) { $device.deviceName } else { "N/A" }
            LastSync               = Format-ReportDateTime -Value $device.lastSyncDateTime
            DaysInactive           = $daysInactive
            PrimaryUser            = if ($device.userPrincipalName) { $device.userPrincipalName } else { "(none)" }
            PrimaryUserDisplayName = $userDisplayName
            UserLocation           = $userLocation
            OperatingSystem        = $operatingSystem
            OSVersion              = "$($device.osVersion)"
            Manufacturer           = "$($device.manufacturer)"
            Model                  = "$($device.model)"
            SerialNumber           = "$($device.serialNumber)"
            ComplianceState        = "$($device.complianceState)"
            Enrolled               = Format-ReportDateTime -Value $device.enrolledDateTime
            IntuneDeviceId         = "$($device.id)"
        })
}

# Oldest check-in first
$sortedRows = @($reportRows | Sort-Object -Property LastSync)

$platformCounts = [ordered]@{}
if ($Windows) { $platformCounts["Windows"] = @($sortedRows | Where-Object { $_.OperatingSystem -eq "Windows" }).Count }
if ($MacOS) { $platformCounts["macOS"] = @($sortedRows | Where-Object { $_.OperatingSystem -eq "macOS" }).Count }
if ($iOS) { $platformCounts["iOS/iPadOS"] = @($sortedRows | Where-Object { $_.OperatingSystem -in @("iOS", "iPadOS") }).Count }
if ($Android) { $platformCounts["Android"] = @($sortedRows | Where-Object { $_.OperatingSystem -eq "Android" }).Count }
$platformSummary = if ($platformCounts.Count -gt 0) { $platformCounts.Keys -join ', ' } else { 'No platform selected' }

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Tenant: $tenantDisplayName"
Write-Output "Inactivity: $inactivityText"
Write-Output "Stale devices in Intune (all platforms): $($devices.Count)"
foreach ($platform in $platformCounts.Keys) {
    Write-Output "$($platform) devices: $($platformCounts[$platform])"
}
if ($IncludeUserGroup) { Write-Output "Skipped, primary user not in '$includeGroupName': $skippedByIncludeGroup" }
if ($ExcludeUserGroup) { Write-Output "Skipped, primary user in '$excludeGroupName': $skippedByExcludeGroup" }
Write-Output "Stale devices in the report: $($sortedRows.Count)"
Write-RjRbLog -Message "Stale in Intune: $($devices.Count); in report: $($sortedRows.Count); skipped include: $skippedByIncludeGroup; skipped exclude: $skippedByExcludeGroup" -Verbose

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$csvFilePath = $null
$xlsxFilePath = $null
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "StaleDevicesReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$safeTenantName = $tenantDisplayName -replace '[\\/:*?"<>|]', '_'
$fileNameSuffix = if ($useMaxDays) { "$($Days)-$($MaxDays)Days" } else { "$($Days)Days" }
$fileNameBase = "StaleDevicesReport_$($safeTenantName)_$($fileNameSuffix)"

# Report files are only needed when they are attached to an email and/or uploaded for a download link
if (($sendEmail -or $CreateDownloadLink) -and $sortedRows.Count -gt 0) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFilePath = Join-Path $tempDir "$fileNameBase.csv"
        $sortedRows | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvFilePath
        Write-RjRbLog -Message "Exported $($sortedRows.Count) row(s) to CSV: $csvFilePath" -Verbose
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFilePath = Join-Path $tempDir "$fileNameBase.xlsx"
        $sortedRows | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Stale Devices"
        $reportFiles += $xlsxFilePath
        Write-RjRbLog -Message "Exported $($sortedRows.Count) row(s) to XLSX: $xlsxFilePath" -Verbose
    }

    Write-Output ""
    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created."
}
elseif ($sortedRows.Count -eq 0) {
    Write-RjRbLog -Message "No stale devices in the report - skipping the report file export" -Verbose
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
        Write-Output "No stale devices in the report - skipping the upload."
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

    $emailSubject = "Stale Devices Report - $($tenantDisplayName) - $($inactivityText)"
    $inactivityPeriodText = if ($useMaxDays) { "between **$Days and $MaxDays days**" } else { "at least **$Days days**" }

    $groupFilterParts = @()
    if ($IncludeUserGroup) { $groupFilterParts += "include group '$includeGroupName' ($($includeUserIds.Count) users)" }
    if ($ExcludeUserGroup) { $groupFilterParts += "exclude group '$excludeGroupName' ($($excludeUserIds.Count) users)" }
    $groupFilterText = if ($groupFilterParts.Count -gt 0) { "`n**User scope filtering applied:** $($groupFilterParts -join ', ')`n" } else { "" }
    $groupFilterBullet = if ($groupFilterParts.Count -gt 0) { "- User scope filtering: $($groupFilterParts -join ', ')" } else { "" }

    if ($sortedRows.Count -eq 0) {
        $markdownContent = @"
# Stale Devices Report

No managed devices matched the stale device criteria (inactive for $($inactivityPeriodText)) for the selected platforms.

## What We Checked

- Inactivity threshold: $($inactivityPeriodText)
- Platforms evaluated: $($platformSummary)
- Stale devices in Intune (all platforms): $($devices.Count)
$($groupFilterBullet)

## Recommendations

- Continue to monitor this report regularly to spot newly idle devices early
- Keep lifecycle policies and retirement procedures current
- Ensure device owners stay informed about required check-ins

---

*This email was automatically generated. Please do not reply to this email.*
"@
    }
    else {
        $summaryLines = @("| **Total Stale Devices** | $($sortedRows.Count) |")
        foreach ($platform in $platformCounts.Keys) {
            $summaryLines += "| **$($platform) Devices** | $($platformCounts[$platform]) |"
        }

        $maxDisplayDevices = 10
        $previewRows = @($sortedRows | Select-Object -First $maxDisplayDevices)
        $previewHeading = if ($sortedRows.Count -gt $maxDisplayDevices) {
            "## Top $maxDisplayDevices Stale Devices (by Last Sync Date)`n`nThis table lists the $maxDisplayDevices devices that have been inactive the longest, based on the current threshold ($($inactivityPeriodText))."
        }
        else {
            "## Stale Devices`n`nThis table lists all devices matching the inactivity criteria ($($inactivityPeriodText))."
        }
        $previewLines = @("| Last Sync | Device Name | Operating System | Serial Number | Primary User |", "|-----------|-------------|------------------|---------------|--------------|")
        foreach ($row in $previewRows) {
            $previewLines += "| $($row.LastSync.Split(' ')[0]) | $($row.DeviceName) | $($row.OperatingSystem) | $($row.SerialNumber) | $($row.PrimaryUser) |"
        }

        $markdownContent = @"
# Stale Devices Report

This report shows devices that have been inactive for $($inactivityPeriodText).
$($groupFilterText)

## Summary Statistics

| Metric | Count |
|--------|-------|
$($summaryLines -join "`n")

$($previewHeading)

$($previewLines -join "`n")

## Recommendations

### Review and Action

Please review the listed devices and take appropriate action:
- Contact device owners to verify device status
- Consider retiring devices that are no longer in use
- Update device records if devices have been decommissioned
- Ensure compliance with your organization's device lifecycle policy

### Device Lifecycle Management

Regularly reviewing stale devices helps:
- Maintain accurate device inventory
- Reduce security risks from unmanaged devices
- Optimize license utilization
- Ensure compliance with organizational policies

## Attachments

The report file(s) attached to this email contain the full list of stale devices for further analysis.

---

*This email was automatically generated. Please do not reply to this email.*
"@
    }

    $xlsxFileName = if ($xlsxFilePath) { Split-Path -Path $xlsxFilePath -Leaf } else { "the Excel workbook" }
    $markdownFallback = @"
# Stale Devices Report

This report shows devices that have been inactive for $($inactivityPeriodText).

## Summary Statistics

- Total stale devices: **$($sortedRows.Count)**

## Attachments

- **$($xlsxFileName)**: Formatted Excel workbook with the complete stale device list

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Choose a delivery with a download link to obtain the raw CSV file.

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
        else {
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles
        }
        Write-RjRbLog -Message "Email report sent to: $EmailTo" -Verbose
        Write-Output "Email report sent to '$EmailTo'."
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
    "Inactivity"                              = $inactivityText
    "Stale devices in Intune (all platforms)" = $devices.Count
}
foreach ($platform in $platformCounts.Keys) {
    $summaryValues["$platform devices"] = $platformCounts[$platform]
}
if ($IncludeUserGroup) { $summaryValues["Skipped, primary user not in '$includeGroupName'"] = $skippedByIncludeGroup }
if ($ExcludeUserGroup) { $summaryValues["Skipped, primary user in '$excludeGroupName'"] = $skippedByExcludeGroup }
$summaryValues["Stale devices in the report"] = $sortedRows.Count

$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = "$($summaryValues[$metric])" }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($sortedRows.Count -gt 0) {
    $rows = @($sortedRows | Select-Object -Property DeviceName, LastSync, DaysInactive, PrimaryUser, OperatingSystem, OSVersion, Model, SerialNumber, ComplianceState)
    Write-Output "$($sortedRows.Count) stale device(s)"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Stale Devices" })
    Write-Output $rows
}
else {
    Write-Output "No stale devices match the selected criteria."
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

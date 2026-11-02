<#
	.SYNOPSIS
	Delete Intune devices that have been inactive for too long

	.DESCRIPTION
	Finds Intune devices that have not checked in for a given number of days, filtered by platform and optionally by the group membership of their primary user. By default it only lists what it would delete; deletion has to be switched on explicitly. The report can be sent by email or provided as a download link.

	.PARAMETER Days
	Devices with no check-in for at least this many days count as stale.

	.PARAMETER Windows
	Includes Windows devices.

	.PARAMETER MacOS
	Includes macOS devices.

	.PARAMETER iOS
	Includes iOS and iPadOS devices.

	.PARAMETER Android
	Includes Android devices.

	.PARAMETER DeleteDevices
	Delete removes the stale devices from Intune. Report only lists them and changes nothing.

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

	.PARAMETER SubscriptionId
	Subscription ID of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.SubscriptionId; the subscription the managed identity signs in to is used when empty.

	.PARAMETER LinkExpiryDays
	Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

	.PARAMETER UseUserScope
	Whether devices are filtered by the group membership of their primary user. Set by the "Filter by primary user group?" choice.

	.PARAMETER IncludeUserGroup
	Only devices whose primary user is in this group.

	.PARAMETER ExcludeUserGroup
	Skips devices whose primary user is in this group.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"Days": {
				"DisplayName": "Days without activity"
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
			"DeleteDevices": {
				"DisplayName": "Deletion mode",
				"SelectSimple": {
					"Report only - show what would be deleted (simulation)": false,
					"Delete stale devices from Intune": true
				}
			},
			"CallerName": {
				"Hide": true
			},
			"EmailTo": {
				"DisplayName": "Recipient email address(es)"
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
			"SubscriptionId": {
				"Hide": true
			},
			"LinkExpiryDays": {
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
			}
		},
		"ParameterList": [
			{
				"DisplayName": "Filter by primary user group?",
				"DisplayAfter": "EmailFrom",
				"Select": {
					"Options": [
						{
							"Display": "Yes, filter by group membership",
							"ParameterValue": true,
							"Customization": {
								"Hide": [],
								"Show": ["IncludeUserGroup", "ExcludeUserGroup"],
								"Default": {
									"UseUserScope": true
								}
							}
						},
						{
							"Display": "No, include all devices",
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }
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
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" } )]
    [string]$BrandingHeaderImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" } )]
    [string]$BrandingFooterImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" } )]
    [string]$BrandingFooterLink,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" } )]
    [string]$BrandingAccentColor,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" } )]
    [string]$BrandingTextColor,
    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'CSV & XLSX',
    [bool] $CreateDownloadLink = $false,
    [string] $ContainerName = "delete-stale-devices",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.SubscriptionId" } )]
    [string] $SubscriptionId,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,
    [bool] $UseUserScope = $false,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Include users from group" } )]
    [string]$IncludeUserGroup,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclude users from group" } )]
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

$Version = "2.3.0"
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
    Write-RjRbLog -Message "SubscriptionId: $SubscriptionId" -Verbose
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

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

# Connect to Microsoft Graph (the report email is sent through this session as well)
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity is configured correctly. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

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
# Return the devices as PSCustomObjects in the property order of the Graph response instead of hashtables,
# because the deletion status is attached to them with Add-Member below
$PSDefaultParameterValues['Invoke-MgGraphRequest:OutputType'] = 'PSObject'
try {
    $devices = Get-GraphPagedResult -Uri $devicesUri
}
finally {
    $PSDefaultParameterValues.Remove('Invoke-MgGraphRequest:OutputType')
}

#region User Scope Filtering

# Get group membership for filtering if UseUserScope is enabled
$includeUserIds = @()
$excludeUserIds = @()

if ($UseUserScope) {
    Write-Output ""
    Write-Output "## Processing user scope filtering..."

    # The group filter fails closed: when a group cannot be read (or the include group has no users),
    # the run stops here, before any device is deleted, instead of running without the filter.

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
            Write-Error "Failed to retrieve the members of the include group '$IncludeUserGroup': $($_.Exception.Message)" -ErrorAction Continue
            throw "Unable to read the include user group - the deletion scope cannot be determined. No devices were deleted."
        }
        if ($includeUserIds.Count -eq 0) {
            Write-Error "The include group '$IncludeUserGroup' has no user members - no device can match the include filter." -ErrorAction Continue
            throw "The include user group has no user members - the deletion scope cannot be determined. No devices were deleted."
        }
    }

    # Get users from exclude group (an empty exclude group excludes nothing)
    if ($ExcludeUserGroup) {
        Write-Output "Getting members from exclude group..."
        try {
            $excludeGroupUri = "https://graph.microsoft.com/v1.0/groups/$ExcludeUserGroup/members?`$select=id,userPrincipalName"
            $excludeMembers = Get-GraphPagedResult -Uri $excludeGroupUri
            $excludeUserIds = $excludeMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' } | ForEach-Object { $_.id }
            Write-Output "Exclude group contains $($excludeUserIds.Count) users"
        }
        catch {
            Write-Error "Failed to retrieve the members of the exclude group '$ExcludeUserGroup': $($_.Exception.Message)" -ErrorAction Continue
            throw "Unable to read the exclude user group - the deletion scope cannot be determined. No devices were deleted."
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
# Devices that are never deleted because their primary user could not be resolved while a user group filter is active
$skippedDevices = @()
$skippedStatus = "Skipped: primary user could not be resolved"
$groupFilterActive = $UseUserScope -and ($IncludeUserGroup -or $ExcludeUserGroup)

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
            $userLookupFailed = $false
            $userLookupError = $null
            try {
                $encodedUserPrincipalName = [System.Uri]::EscapeDataString($device.userPrincipalName)
                $userUri = "https://graph.microsoft.com/v1.0/users/{0}?`$select=id,displayName,city,usageLocation" -f $encodedUserPrincipalName
                $userInfo = Invoke-MgGraphRequest -Uri $userUri -Method GET -ErrorAction SilentlyContinue -ErrorVariable userLookupError

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
                else {
                    $userLookupFailed = $true
                }
            }
            catch {
                Write-RjRbLog -Message "Could not retrieve user info for $($device.userPrincipalName): $($_.Exception.Message)" -Verbose
                $userLookupFailed = $true
            }

            # Fail closed: without the primary user the group filter cannot be checked, so the device is never deleted
            if ($userLookupFailed -and $groupFilterActive) {
                $lookupErrorText = if ($userLookupError) { " ($(@($userLookupError)[0].Exception.Message))" } else { "" }
                Write-Output "Skipping device '$($device.deviceName)' - primary user '$($device.userPrincipalName)' could not be resolved, so the user group filter cannot be checked"
                Write-RjRbLog -Message "Skipping device '$($device.deviceName)' - primary user '$($device.userPrincipalName)' could not be resolved$($lookupErrorText)" -Verbose
                $device | Add-Member -Name "deletionStatus" -Value $skippedStatus -MemberType "NoteProperty" -Force
                $skippedDevices += $device
                continue
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

if ($skippedDevices.Count -gt 0) {
    Write-Output "Skipped, primary user could not be resolved (not deleted): $($skippedDevices.Count)"
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
#region     Report File Export
########################################################

# Create report files in current location (only needed for the email report and/or download link)
$fileNameBase = "StaleDevicesDeletionReport_$($tenantDisplayName)_$($Days)Days"
$csvFilePath = $null
$xlsxFilePath = $null
$reportFiles = @()
if (($EmailTo -or $CreateDownloadLink) -and ($filteredDevices.Count + $skippedDevices.Count) -gt 0) {
    # Build clean export rows including the deletion status (skipped devices included)
    $exportDevices = @()
    foreach ($device in (@($filteredDevices) + @($skippedDevices))) {
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
        if ($skippedDevices.Count -gt 0) {
            $highlightRules += @{ Column = 'DeletionStatus'; Value = $skippedStatus; Color = 'Yellow' }
        }
        $exportDevices | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Stale Devices" -HighlightRules $highlightRules
        $reportFiles += $xlsxFilePath
        Write-RjRbLog -Message "Exported stale devices to XLSX: $($xlsxFilePath)" -Verbose
    }
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################

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
        -SubscriptionId $SubscriptionId `
        -LinkExpiryDays $LinkExpiryDays `
        -AddBlobNamePrefix $true

    foreach ($uploadResult in $uploadResults) {
        Write-Output ""
        Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
        $uploadResult.SASLink | Out-String | Write-Output
    }
}

#endregion Upload / Download Link

########################################################
#region     Send Email Report
########################################################

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

# Devices skipped because their primary user could not be resolved (only with an active user group filter)
$skippedSection = ""
if ($skippedDevices.Count -gt 0) {
    $skippedSection = "## Skipped Devices`n`nThe following devices are never deleted because their primary user could not be resolved, so the user group filter could not be checked. Review them manually:`n"
    foreach ($skippedDevice in @($skippedDevices | Select-Object -First 10)) {
        $skippedSection += "`n- $($skippedDevice.deviceName) (primary user: $($skippedDevice.userPrincipalName), ID: $($skippedDevice.id))"
    }
    if ($skippedDevices.Count -gt 10) {
        $skippedSection += "`n`nShowing 10 of $($skippedDevices.Count) skipped devices. The report file(s) contain the complete list."
    }
    $skippedSection += "`n`n"
}

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
    "- User scope filtering: $($filterInfo -join ', ')$(if ($skippedDevices.Count -gt 0) { "`n- Skipped, primary user could not be resolved: $($skippedDevices.Count)" })"
})

$($skippedSection)---

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
    if ($skippedDevices.Count -gt 0) {
        $summaryLines += "| **Skipped (Primary User Not Resolved)** | $($skippedDevices.Count) |"
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

$($skippedSection)## Attachments

The report file(s) attached to this email contain the full list of affected devices for further analysis.

---

*This email was automatically generated. Please do not reply to this email.*

"@
}

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
})$(if ($skippedDevices.Count -gt 0) { "`n- Skipped, primary user could not be resolved: **$($skippedDevices.Count)**" })

## Attachments

- **$($fileNameBase).xlsx**: Formatted Excel workbook with the complete device list

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

            $guardParams = @{
                EmailFrom             = $EmailFrom
                EmailTo               = $EmailTo
                Subject               = $emailSubject
                MarkdownContent       = $markdownContent
                TenantDisplayName     = $tenantDisplayName
                ReportVersion         = $Version
                UseNativeGraphRequest = $true
            }
            if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFilePath) {
                Send-RjRbReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFilePath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjRbReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
            }
        }
        else {
            Send-RjRbReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version -UseNativeGraphRequest @brandingMailParams
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

#endregion Send Email Report

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the progress output. Every table has its own
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
$summaryValues = [ordered]@{
    "Run mode"                          = $modeText
    "Inactive for at least"             = "$Days days"
    "Platforms"                         = $platformSummary
    "Devices evaluated (all platforms)" = $totalDevicesEvaluated
}
if ($UseUserScope -and $IncludeUserGroup) { $summaryValues["Users in include group"] = $includeUserIds.Count }
if ($UseUserScope -and $ExcludeUserGroup) { $summaryValues["Users in exclude group"] = $excludeUserIds.Count }
$summaryValues["Stale devices"] = $filteredDevices.Count
if ($groupFilterActive) { $summaryValues["Skipped, primary user not resolved"] = $skippedDevices.Count }
if ($Windows) { $summaryValues["Windows devices"] = $windowsCount }
if ($MacOS) { $summaryValues["macOS devices"] = $macOSCount }
if ($iOS) { $summaryValues["iOS devices"] = $iOSCount }
if ($Android) { $summaryValues["Android devices"] = $androidCount }
if ($DeleteDevices) {
    $summaryValues["Successfully deleted"] = $deletedDevices.Count
    $summaryValues["Failed deletions"] = $failedDeletions.Count
}

$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = "$($summaryValues[$metric])" }
    })
Write-Output ""
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

Write-Output ""
if (($filteredDevices.Count + $skippedDevices.Count) -gt 0) {
    # Oldest check-in first, untruncated values; skipped devices carry their skip reason as status
    $deviceRows = @((@($filteredDevices) + @($skippedDevices)) | Sort-Object -Property lastSyncDateTime | Select-Object -Property @(
            @{ Name = 'DeviceName'; Expression = { "$($_.deviceName)" } }
            @{ Name = 'LastSync'; Expression = { if ($_.lastSyncDateTime) { Get-Date $_.lastSyncDateTime -Format 'yyyy-MM-dd HH:mm:ss' } else { "N/A" } } }
            @{ Name = 'OperatingSystem'; Expression = { "$($_.operatingSystem)" } }
            @{ Name = 'OSVersion'; Expression = { "$($_.osVersion)" } }
            @{ Name = 'Model'; Expression = { "$($_.model)" } }
            @{ Name = 'SerialNumber'; Expression = { "$($_.serialNumber)" } }
            @{ Name = 'PrimaryUser'; Expression = { "$($_.userPrincipalName)" } }
            @{ Name = 'DeletionStatus'; Expression = { "$($_.deletionStatus)" } }
            @{ Name = 'DeviceId'; Expression = { "$($_.id)" } }
        ))
    Write-Output "## Detailed list of stale devices:"
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Stale Devices" })
    Write-Output $deviceRows
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

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
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
if ($skippedDevices.Count -gt 0) {
    Write-Output "Devices skipped (primary user could not be resolved): $($skippedDevices.Count)"
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

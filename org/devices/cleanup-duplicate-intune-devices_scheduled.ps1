<#
	.SYNOPSIS
	Remove duplicate Intune devices, keeping the most recently synced

	.DESCRIPTION
	Finds Intune devices that share a serial number and deletes the older records, keeping the one that synced most recently. Only the Intune record is deleted; the Entra ID device and the Autopilot registration stay. A deleted record cannot be restored. A preview mode lists the records without deleting anything. The report can be sent by email or provided as a download link.

	.PARAMETER WhatIfMode
	List duplicate devices without deleting them. Disable to actually delete the older duplicate records.

	.PARAMETER IncludeWindows
	Include Windows devices in the duplicate detection.

	.PARAMETER IncludeMacOS
	Include macOS devices in the duplicate detection.

	.PARAMETER IncludeIOS
	Include iOS and iPadOS devices in the duplicate detection.

	.PARAMETER IncludeAndroid
	Include Android devices in the duplicate detection.

	.PARAMETER DeviceNamePrefix
	Check only devices whose name starts with this prefix. Leave empty to check all device names.

	.PARAMETER IncludeSerialNumbers
	Check only devices with one of these serial numbers (comma-separated). Leave empty to check all serial numbers.

	.PARAMETER ExcludeSerialNumbers
	Skip devices with any of these serial numbers (comma-separated). Leave empty to exclude none.

	.PARAMETER MinimumDaysSinceLastSync
	An older duplicate record is deleted only when its last sync is at least this many days ago. For a record that never synced, its enrollment date counts instead. The kept record is not subject to this limit.

	.PARAMETER MaxDevicesToRemove
	Whole-run deletion cap. When more than this many devices would be deleted in a single run, nothing is removed and the affected records are listed as "Would not be deleted (limit exceeded)".

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

	.PARAMETER SendEmailReport
	Send the report to the recipient email address when duplicates are or would be removed.

	.PARAMETER EmailTo
	Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

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

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
	    "Parameters": {
	        "WhatIfMode": {
	            "DisplayName": "Only list, do not delete?"
	        },
	        "IncludeWindows": {
	            "DisplayName": "Include Windows devices?"
	        },
	        "IncludeMacOS": {
	            "DisplayName": "Include macOS devices?"
	        },
	        "IncludeIOS": {
	            "DisplayName": "Include iOS/iPadOS devices?"
	        },
	        "IncludeAndroid": {
	            "DisplayName": "Include Android devices?"
	        },
	        "DeviceNamePrefix": {
	            "DisplayName": "Device name prefix"
	        },
	        "IncludeSerialNumbers": {
	            "DisplayName": "Only these serial numbers"
	        },
	        "ExcludeSerialNumbers": {
	            "DisplayName": "Exclude these serial numbers"
	        },
	        "MinimumDaysSinceLastSync": {
	            "DisplayName": "Minimum days since last sync"
	        },
	        "MaxDevicesToRemove": {
	            "DisplayName": "Maximum devices to remove"
	        },
	        "CallerName": { "Hide": true },
	        "EmailFrom": { "Hide": true },
	        "BrandingHeaderImageUrl": { "Hide": true },
	        "BrandingFooterImageUrl": { "Hide": true },
	        "BrandingFooterLink": { "Hide": true },
	        "BrandingAccentColor": { "Hide": true },
	        "BrandingTextColor": { "Hide": true },
	        "ContainerName": { "Hide": true },
	        "ResourceGroupName": { "Hide": true },
	        "StorageAccountName": { "Hide": true },
	        "SubscriptionId": { "Hide": true },
	        "LinkExpiryDays": { "Hide": true },
	        "ReportFileFormat": {
	            "DisplayName": "Report file format",
	            "Select": {
	                "Options": [
	                    { "Display": "CSV & XLSX", "ParameterValue": "CSV & XLSX" },
	                    { "Display": "CSV only", "ParameterValue": "CSV only" },
	                    { "Display": "XLSX only", "ParameterValue": "XLSX only" }
	                ],
	                "ShowValue": false
	            }
	        },
	        "EmailTo": { "DisplayName": "Recipient email address(es)" }
	    },
	    "ParameterList": [
	        {
	            "DisplayName": "Report delivery",
	            "DisplayAfter": "MaxDevicesToRemove",
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
[bool]$WhatIfMode = $true,

[bool]$IncludeWindows = $true,
[bool]$IncludeMacOS = $true,
[bool]$IncludeIOS = $true,
[bool]$IncludeAndroid = $true,

[string]$DeviceNamePrefix = "",
[string]$IncludeSerialNumbers = "",
[string]$ExcludeSerialNumbers = "",

[ValidateRange(1, 3650)]
[int]$MinimumDaysSinceLastSync = 7,
[ValidateRange(1, 10000)]
[int]$MaxDevicesToRemove = 50,

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
[bool]$SendEmailReport = $false,
[string]$EmailTo,
[ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
[string]$ReportFileFormat = 'CSV & XLSX',
[bool]$CreateDownloadLink = $false,
[string]$ContainerName = "cleanup-duplicate-intune-devices",
[ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
[string]$ResourceGroupName,
[ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
[string]$StorageAccountName,
[ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.SubscriptionId" } )]
[string]$SubscriptionId,
[ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" } )]
[ValidateRange(1, 3650)]
[int]$LinkExpiryDays = 6,

# CallerName is tracked purely for auditing purposes
[Parameter(Mandatory = $true)]
[string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "WhatIfMode: $WhatIfMode" -Verbose
Write-RjRbLog -Message "IncludeWindows: $IncludeWindows" -Verbose
Write-RjRbLog -Message "IncludeMacOS: $IncludeMacOS" -Verbose
Write-RjRbLog -Message "IncludeIOS: $IncludeIOS" -Verbose
Write-RjRbLog -Message "IncludeAndroid: $IncludeAndroid" -Verbose
Write-RjRbLog -Message "DeviceNamePrefix: $DeviceNamePrefix" -Verbose
Write-RjRbLog -Message "IncludeSerialNumbers: $IncludeSerialNumbers" -Verbose
Write-RjRbLog -Message "ExcludeSerialNumbers: $ExcludeSerialNumbers" -Verbose
Write-RjRbLog -Message "MinimumDaysSinceLastSync: $MinimumDaysSinceLastSync" -Verbose
Write-RjRbLog -Message "MaxDevicesToRemove: $MaxDevicesToRemove" -Verbose

Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
Write-RjRbLog -Message "SubscriptionId: $SubscriptionId" -Verbose
Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################
if (-not ($IncludeWindows -or $IncludeMacOS -or $IncludeIOS -or $IncludeAndroid)) {
    Write-Error "No platform selected. Enable at least one of Windows, macOS, iOS/iPadOS or Android." -ErrorAction Continue
    throw "No platform selected"
}

# A recipient is required when the report is to be emailed
if ($SendEmailReport -and -not $EmailTo) {
    Write-Error "The report email cannot be sent because no recipient email address was given. Enter at least one address in 'Recipient email address(es)' or choose a delivery option without email." -ErrorAction Continue
    throw "Missing recipient email address (EmailTo)."
}

# A sender address is required before any mail can be sent
if (($SendEmailReport -or $EmailTo) -and -not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. Configure it in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
    throw "Missing email sender configuration (RJReport.EmailSender)."
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook."
    throw "Missing storage account configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
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

function ConvertTo-NullableDateTime {
    param([parameter(ValueFromPipeline)] $value)

    process {
        $parsed = $null

        if ($value -is [datetime]) {
            # Graph timestamps are UTC: a local value is converted, any other kind is read as UTC
            $parsed = if ($value.Kind -eq [System.DateTimeKind]::Local) {
                $value.ToUniversalTime()
            }
            else {
                [datetime]::SpecifyKind($value, [System.DateTimeKind]::Utc)
            }
        }
        elseif ($value -is [string] -and -not [string]::IsNullOrWhiteSpace($value)) {
            try {
                $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
                $parsed = [datetime]::Parse($value, [System.Globalization.CultureInfo]::InvariantCulture, $styles)
            }
            catch {
                # A value that is not a date counts as missing
                $parsed = $null
            }
        }

        # Intune reports 0001-01-01 for "never"; such a value counts as missing
        if ($null -ne $parsed -and $parsed.Year -lt 2000) {
            $parsed = $null
        }

        return $parsed
    }
}

function ConvertTo-NormalizedSerial {
    param([string]$SerialNumber)

    if ([string]::IsNullOrWhiteSpace($SerialNumber)) {
        return $null
    }

    # Whitespace is removed because the same value is reported with and without spaces
    # ("Default string" / "Defaultstring")
    return ($SerialNumber -replace '\s', '').ToUpperInvariant()
}

function Test-PlaceholderSerial {
    param([string]$NormalizedSerial)

    # OEM default values that unrelated machines share - they never identify a device
    $placeholderSerials = @(
        'DEFAULTSTRING', 'TOBEFILLEDBYO.E.M.', 'TOBEFILLEDBYOEM', 'SYSTEMSERIALNUMBER', 'CHASSISSERIALNUMBER',
        'SERIALNUMBER', 'SERIAL', 'NONE', 'N/A', 'NA', 'UNKNOWN', 'INVALID', 'NOTSPECIFIED', 'NOTAPPLICABLE',
        'NOTAVAILABLE', 'O.E.M.', 'OEM', '123456789', '1234567890', '0123456789', '0123456789ABCDEF'
    )

    if ([string]::IsNullOrEmpty($NormalizedSerial)) {
        return $true
    }
    if ($NormalizedSerial -in $placeholderSerials) {
        return $true
    }
    # One repeated character, for example "0", "00000000" or "XXXXXXXX"
    if ($NormalizedSerial -match '^(.)\1*$') {
        return $true
    }

    return $false
}
#endregion Function Definitions

########################################################
#region     Connect Part
########################################################
Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome
}
catch {
    # Managed identity sign-in failed: identity not enabled on the Automation account, or token endpoint unavailable
    Write-Error "Could not sign in to Microsoft Graph with the managed identity. Verify that the system-assigned managed identity is enabled on the Automation account and try again. Details: $($_.Exception.Message)" -ErrorAction Continue
    throw "Connection to Microsoft Graph failed"
}

Write-Output "Validating Graph permissions..."
try {
    $mgContext = Get-MgContext -ErrorAction Stop
    $grantedScopes = $mgContext.Scopes

    # Required Graph app permissions for this runbook (from .permissions.json)
    $requiredPermissions = @(
        "DeviceManagementManagedDevices.ReadWrite.All"
    )
    # "Email report" feature - the permissions marked Optional in .permissions.json
    if ($SendEmailReport -or $EmailTo) {
        $requiredPermissions += @("Mail.Send", "Organization.Read.All")
    }

    # Subsumption: a broader permission implicitly covers a narrower one.
    # Key = required permission, Value = list of broader permissions that satisfy it.
    $subsumptionMap = @{
        "User.Read.All"                           = @("User.ReadWrite.All", "Directory.ReadWrite.All")
        "Group.Read.All"                          = @("Group.ReadWrite.All", "Directory.ReadWrite.All")
        "GroupMember.Read.All"                    = @("GroupMember.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All")
        "Application.Read.All"                    = @("Application.ReadWrite.All", "Directory.ReadWrite.All")
        "AppRoleAssignment.Read.All"              = @("AppRoleAssignment.ReadWrite.All", "Directory.ReadWrite.All")
        "Device.Read.All"                         = @("Device.ReadWrite.All", "Directory.ReadWrite.All")
        "Directory.Read.All"                      = @("Directory.ReadWrite.All")
        "Organization.Read.All"                   = @("Organization.ReadWrite.All", "Directory.ReadWrite.All")
        "DeviceManagementManagedDevices.Read.All" = @("DeviceManagementManagedDevices.ReadWrite.All")
        "DeviceManagementConfiguration.Read.All"  = @("DeviceManagementConfiguration.ReadWrite.All")
        "DeviceManagementApps.Read.All"           = @("DeviceManagementApps.ReadWrite.All")
        "DeviceManagementServiceConfig.Read.All"  = @("DeviceManagementServiceConfig.ReadWrite.All")
        "Policy.Read.All"                         = @("Policy.ReadWrite.All")
        "RoleManagement.Read.Directory"           = @("RoleManagement.ReadWrite.Directory")
        "AuditLog.Read.All"                       = @("Directory.ReadWrite.All")
    }

    $missingPermissions = @()
    foreach ($required in $requiredPermissions) {
        $covered = $grantedScopes -contains $required
        if (-not $covered -and $subsumptionMap.ContainsKey($required)) {
            foreach ($broader in $subsumptionMap[$required]) {
                if ($grantedScopes -contains $broader) {
                    $covered = $true
                    break
                }
            }
        }
        if (-not $covered) {
            $missingPermissions += $required
        }
    }

    if ($missingPermissions.Count -gt 0) {
        Write-Error "Missing required Microsoft Graph permissions: $($missingPermissions -join ', '). Ensure the managed identity has the necessary app role assignments." -ErrorAction Continue
        throw "Insufficient Graph permissions"
    }
    Write-Output "Graph permissions validated."
}
catch {
    # The missing-permission case already logged a specific error above; only add context for unexpected failures
    if ($_.Exception.Message -ne "Insufficient Graph permissions") {
        Write-Error "The Microsoft Graph permissions of the managed identity could not be checked: $($_.Exception.Message)" -ErrorAction Continue
    }
    throw
}

Write-Output "## Retrieving tenant information..."
$tenantDisplayName = "Unknown Tenant"
try {
    $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
    }
    elseif ($organizationResponse.displayName) {
        $tenantDisplayName = $organizationResponse.displayName
    }
    Write-Output "## Tenant: $($tenantDisplayName)"
}
catch {
    Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
}
#endregion Connect Part

########################################################
#region     Data Collection
########################################################
Write-Output ""
Write-Output "Get managed devices"
Write-Output "---------------------"
Write-Output ""

try {
    $baseUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
    $selectQuery = "?`$select=id,deviceName,serialNumber,operatingSystem,osVersion,lastSyncDateTime,enrolledDateTime,userPrincipalName,azureADDeviceId,model,manufacturer"

    $allDevices = Get-GraphPagedResult -Uri ($baseUri + $selectQuery)
    Write-RjRbLog -Message "Retrieved $($allDevices.Count) managed devices from Intune" -Verbose

    # Filter devices by platform and device name prefix
    $managedDevices = [System.Collections.Generic.List[object]]::new()

    foreach ($device in $allDevices) {
        # Check platform filter
        if (-not (
            ($IncludeWindows -and $device.operatingSystem -like 'Windows') -or
            ($IncludeMacOS -and $device.operatingSystem -like 'macOS') -or
            ($IncludeIOS -and ($device.operatingSystem -like 'iOS' -or $device.operatingSystem -like 'iPadOS')) -or
            ($IncludeAndroid -and $device.operatingSystem -like 'Android*')
        )) {
            continue
        }

        # Check device name prefix filter
        if (-not [string]::IsNullOrEmpty($DeviceNamePrefix)) {
            if (-not "$($device.deviceName)".StartsWith($DeviceNamePrefix, [StringComparison]::OrdinalIgnoreCase)) {
                continue
            }
        }

        $managedDevices.Add($device)
    }

    Write-RjRbLog -Message "Filtered to $($managedDevices.Count) devices matching the selected criteria" -Verbose
}
catch {
    $message = $_.Exception.Message
    if ($message -like "*403*" -or $message -like "*Forbidden*") {
        # Managed identity lacks the Intune app role
        Write-Error "Access denied while reading Intune managed devices. Grant the managed identity the Graph application permission DeviceManagementManagedDevices.ReadWrite.All (admin consent required) and run the runbook again." -ErrorAction Continue
        throw "Insufficient Microsoft Graph permissions (DeviceManagementManagedDevices.ReadWrite.All)"
    }
    elseif ($message -like "*401*" -or $message -like "*Unauthorized*") {
        Write-Error "Authentication to Microsoft Graph failed while reading Intune managed devices. Verify that the managed identity is enabled and has been granted its permissions." -ErrorAction Continue
        throw "Authentication to Microsoft Graph failed"
    }
    elseif ($message -like "*429*" -or $message -like "*TooManyRequests*") {
        Write-Error "Microsoft Graph throttled the request for Intune managed devices. Wait a few minutes and run the runbook again." -ErrorAction Continue
        throw "Microsoft Graph throttling"
    }
    else {
        Write-Error "Failed to retrieve managed devices from Intune: $message" -ErrorAction Continue
        throw
    }
}
#endregion Data Collection

########################################################
#region     Data Processing
########################################################
Write-Output "Detecting duplicate devices by serial number..."

$nowUtc = [datetime]::UtcNow

# The include and exclude lists are normalized the same way as the device serial numbers
$includeSerials = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($entry in ("$IncludeSerialNumbers" -split ',')) {
    $entrySerial = ConvertTo-NormalizedSerial -SerialNumber $entry
    if ($entrySerial) {
        [void]$includeSerials.Add($entrySerial)
    }
}

$excludeSerials = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($entry in ("$ExcludeSerialNumbers" -split ',')) {
    $entrySerial = ConvertTo-NormalizedSerial -SerialNumber $entry
    if ($entrySerial) {
        [void]$excludeSerials.Add($entrySerial)
    }
}

# Group the devices by normalized serial number
$devicesBySerial = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new([System.StringComparer]::OrdinalIgnoreCase)
$skippedPlaceholder = 0

foreach ($device in $managedDevices) {
    $serial = ConvertTo-NormalizedSerial -SerialNumber $device.serialNumber

    # Empty and placeholder serial numbers do not identify a device
    if (Test-PlaceholderSerial -NormalizedSerial $serial) {
        $skippedPlaceholder++
        continue
    }

    if ($includeSerials.Count -gt 0 -and -not $includeSerials.Contains($serial)) {
        continue
    }

    # The exclude list takes precedence over the include list
    if ($excludeSerials.Contains($serial)) {
        continue
    }

    if (-not $devicesBySerial.ContainsKey($serial)) {
        $devicesBySerial[$serial] = [System.Collections.Generic.List[object]]::new()
    }
    $devicesBySerial[$serial].Add($device)
}

if ($skippedPlaceholder -gt 0) {
    Write-RjRbLog -Message "Skipped $skippedPlaceholder device(s) with empty or placeholder serial numbers" -Verbose
}

# A serial number with more than one record is a duplicate
$duplicateSerials = [System.Collections.Generic.List[string]]::new()
foreach ($serial in $devicesBySerial.Keys) {
    if ($devicesBySerial[$serial].Count -gt 1) {
        $duplicateSerials.Add($serial)
    }
}
$duplicateSerials.Sort([System.StringComparer]::OrdinalIgnoreCase)
$duplicateSerialCount = $duplicateSerials.Count

Write-RjRbLog -Message "Found $duplicateSerialCount duplicate serial number(s)" -Verbose

$removalCandidateList = [System.Collections.Generic.List[object]]::new()
$skippedDuplicateList = [System.Collections.Generic.List[object]]::new()

foreach ($serial in $duplicateSerials) {
    # Parse the timestamps of every record of this serial number
    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($device in $devicesBySerial[$serial]) {
        $lastSync = $device.lastSyncDateTime | ConvertTo-NullableDateTime
        $enrolled = $device.enrolledDateTime | ConvertTo-NullableDateTime

        $records.Add([PSCustomObject]@{
                Device   = $device
                LastSync = $lastSync
                Enrolled = $enrolled
                # A record that never synced is ranked by its enrollment, the only activity it has
                Activity = if ($null -ne $lastSync) { $lastSync } else { $enrolled }
            })
    }

    # Newest activity first, the enrollment time breaks ties, records without any timestamp come last
    $rankedRecords = $records | Sort-Object -Property @{ Expression = { $_.Activity }; Descending = $true }, @{ Expression = { $_.Enrolled }; Descending = $true }

    $keptRecord = $rankedRecords[0]
    $keptDevice = $keptRecord.Device
    if (-not $keptDevice.id) {
        continue
    }

    $keptDeviceName = if ([string]::IsNullOrEmpty($keptDevice.deviceName)) { "Unknown" } else { $keptDevice.deviceName }
    $keptLastSyncText = if ($null -ne $keptRecord.LastSync) { $keptRecord.LastSync.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
    $keptEnrolledText = if ($null -ne $keptRecord.Enrolled) { $keptRecord.Enrolled.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown" }

    # Checks that apply to the whole serial number: when one fails, no record of it is removed
    $groupSkipReason = $null

    $manufacturers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $models = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $platforms = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($record in $rankedRecords) {
        $manufacturer = "$($record.Device.manufacturer)".Trim()
        $model = "$($record.Device.model)".Trim()
        $platform = "$($record.Device.operatingSystem)".Trim()
        # iOS and iPadOS are one platform (an iPad changes from one to the other with an OS upgrade)
        if ($platform -in @('iOS', 'iPadOS')) {
            $platform = 'iOS'
        }
        elseif ($platform -like 'Android*') {
            $platform = 'Android'
        }

        if ($manufacturer) { [void]$manufacturers.Add($manufacturer) }
        if ($model) { [void]$models.Add($model) }
        if ($platform) { [void]$platforms.Add($platform) }
    }

    if ($rankedRecords[0].Activity -eq $rankedRecords[1].Activity -and $rankedRecords[0].Enrolled -eq $rankedRecords[1].Enrolled) {
        # The two newest records cannot be told apart
        $groupSkipReason = "Same last sync and enrollment time as the newest record"
    }
    elseif ($null -eq $keptRecord.LastSync) {
        # A fresh enrollment that has not checked in yet: wait for its first sync before removing anything
        $groupSkipReason = "The newest record has not synced yet"
    }
    elseif ($manufacturers.Count -gt 1 -or $models.Count -gt 1 -or $platforms.Count -gt 1) {
        # Different machines that share a serial number are not duplicates of one device
        $groupSkipReason = "Records report different hardware or platforms"
    }

    # Every record after the newest one is an older duplicate
    for ($i = 1; $i -lt $rankedRecords.Count; $i++) {
        $record = $rankedRecords[$i]
        $device = $record.Device

        if (-not $device.id) {
            continue
        }

        # Age of the record: whole days since its last sync, or since its enrollment when it never synced
        $ageReference = if ($null -ne $record.LastSync) { $record.LastSync } else { $record.Enrolled }
        $ageInDays = if ($null -ne $ageReference) { [int][math]::Floor(($nowUtc - $ageReference).TotalDays) } else { $null }
        $daysSinceLastSync = if ($null -ne $record.LastSync) { $ageInDays } else { $null }

        $skipReason = $groupSkipReason
        if (-not $skipReason) {
            if ($null -eq $ageReference) {
                $skipReason = "No last sync and no enrollment time"
            }
            elseif ($ageInDays -lt $MinimumDaysSinceLastSync) {
                $skipReason = if ($null -ne $record.LastSync) {
                    "Synced within the last $MinimumDaysSinceLastSync days"
                }
                else {
                    "Never synced and enrolled within the last $MinimumDaysSinceLastSync days"
                }
            }
            elseif ($null -ne $record.Enrolled -and $null -ne $keptRecord.Enrolled -and $record.Enrolled -gt $keptRecord.Enrolled) {
                # Last sync and enrollment time disagree about which record is the newer one
                $skipReason = "Enrolled after the kept record"
            }
        }

        $deviceName = if ([string]::IsNullOrEmpty($device.deviceName)) { "Unknown" } else { $device.deviceName }
        $operatingSystem = if ([string]::IsNullOrEmpty($device.operatingSystem)) { "Unknown" } else { $device.operatingSystem }
        $lastSyncText = if ($null -ne $record.LastSync) { $record.LastSync.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
        $enrolledText = if ($null -ne $record.Enrolled) { $record.Enrolled.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown" }

        if ($skipReason) {
            $hardwareText = "$($device.manufacturer) $($device.model)".Trim()

            $skippedDuplicateList.Add([PSCustomObject]@{
                    SerialNumber    = $serial
                    DeviceName      = $deviceName
                    OperatingSystem = $operatingSystem
                    Model           = if ($hardwareText) { $hardwareText } else { "Unknown" }
                    Enrolled        = $enrolledText
                    LastSync        = $lastSyncText
                    KeptDeviceName  = $keptDeviceName
                    Reason          = $skipReason
                })
        }
        else {
            $removalCandidateList.Add([PSCustomObject]@{
                    SerialNumber       = $serial
                    DeviceName         = $deviceName
                    OperatingSystem    = $operatingSystem
                    OSVersion          = if ([string]::IsNullOrEmpty($device.osVersion)) { "Unknown" } else { $device.osVersion }
                    UserPrincipalName  = if ([string]::IsNullOrEmpty($device.userPrincipalName)) { "None" } else { $device.userPrincipalName }
                    Enrolled           = $enrolledText
                    LastSync           = $lastSyncText
                    DaysSinceLastSync  = $daysSinceLastSync
                    KeptDeviceName     = $keptDeviceName
                    KeptDeviceEnrolled = $keptEnrolledText
                    KeptDeviceLastSync = $keptLastSyncText
                    Result             = "Pending"
                    Details            = ""
                    IntuneDeviceId     = $device.id
                    KeptIntuneDeviceId = $keptDevice.id
                })
        }
    }
}

# Plain arrays for the following regions, ordered by serial number and then newest first
$removalCandidates = $removalCandidateList.ToArray()
$skippedDuplicates = $skippedDuplicateList.ToArray()

# Output summary
Write-Output ""
Write-Output "Duplicate Device Detection Summary"
Write-Output "---------------------"
Write-Output "Duplicate serial numbers found: $duplicateSerialCount"
Write-Output "Removal candidates: $($removalCandidates.Count)"
Write-Output "Skipped duplicates: $($skippedDuplicates.Count)"
Write-Output ""

#region Remove duplicate devices
Write-Output ""
Write-Output "Remove older duplicate records"
Write-Output "---------------------"

$deletedCount = 0
$failedCount = 0
$removalLimitExceeded = $false

if ($removalCandidates.Count -eq 0) {
    Write-Output "No older duplicate records to remove."
}
elseif ($removalCandidates.Count -gt $MaxDevicesToRemove) {
    # The cap is checked before WhatIf, so a preview shows exactly what a live run would do
    $removalLimitExceeded = $true
    $limitResult = if ($WhatIfMode) { 'Would not be deleted (limit exceeded)' } else { 'Not deleted (limit exceeded)' }
    Write-RjRbLog -Message "WARNING: $($removalCandidates.Count) records qualify for removal, which is more than the limit of $MaxDevicesToRemove. Nothing is deleted in this run. Review the list and raise the limit if it is correct." -Verbose
    foreach ($candidate in $removalCandidates) {
        $candidate.Result = $limitResult
    }
}
elseif ($WhatIfMode) {
    Write-Output "WhatIf is enabled - $($removalCandidates.Count) record(s) would be deleted, nothing is changed."
    foreach ($candidate in $removalCandidates) {
        $candidate.Result = 'Would be deleted'
    }
}
else {
    Write-Output "Deleting $($removalCandidates.Count) older duplicate record(s) from Intune..."
    foreach ($candidate in $removalCandidates) {
        try {
            Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$($candidate.IntuneDeviceId)" -Method DELETE -ErrorAction Stop | Out-Null
            $candidate.Result = 'Deleted'
            $deletedCount++
            Write-RjRbLog -Message "Deleted '$($candidate.DeviceName)' (serial $($candidate.SerialNumber), last sync $($candidate.LastSync)); kept '$($candidate.KeptDeviceName)'" -Verbose
        }
        catch {
            # Non-terminating by design: record the failure for this device and continue with the next one
            $deleteError = $_.Exception.Message
            if ($deleteError -like "*403*" -or $deleteError -like "*Forbidden*") {
                $hint = "access denied - the managed identity needs DeviceManagementManagedDevices.ReadWrite.All"
            }
            elseif ($deleteError -like "*404*" -or $deleteError -like "*NotFound*" -or $deleteError -like "*not found*") {
                $hint = "record not found - it was probably already removed from Intune"
            }
            else {
                $hint = $deleteError
            }
            $candidate.Result = 'Failed'
            $candidate.Details = $hint
            $failedCount++
            Write-RjRbLog -Message "WARNING: Failed to delete '$($candidate.DeviceName)' (serial $($candidate.SerialNumber)): $hint" -Verbose
        }
    }
    Write-Output "Deleted: $deletedCount, failed: $failedCount"
}

$removalResults = @($removalCandidates)
#endregion Remove duplicate devices

#region Output Data tables
if ($removalResults.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = 'Duplicate devices' })
    # Both records of a duplicate usually carry the same device name, so the enrollment times and the Intune device IDs tell them apart
    $removalResults | Select-Object SerialNumber, DeviceName, OperatingSystem, OSVersion, UserPrincipalName, Enrolled, LastSync, DaysSinceLastSync, KeptDeviceName, KeptDeviceEnrolled, KeptDeviceLastSync, Result, Details, IntuneDeviceId, KeptIntuneDeviceId
}

if ($skippedDuplicates.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = 'Skipped duplicates' })
    $skippedDuplicates | Select-Object SerialNumber, DeviceName, OperatingSystem, Model, Enrolled, LastSync, KeptDeviceName, Reason
}
#endregion Output Data tables

Write-Output ""
#endregion Data Processing

########################################################
#region     Report File Export
########################################################
$reportFiles = @()
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "DuplicateIntuneDevices_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

if ($ReportFileFormat -ne 'XLSX only') {
    if ($removalResults.Count -gt 0) {
        $fileName_Duplicates = Join-Path $tempDir "DuplicateDevices.csv"
        $removalResults | Select-Object SerialNumber, DeviceName, OperatingSystem, OSVersion, UserPrincipalName, Enrolled, LastSync, DaysSinceLastSync, KeptDeviceName, KeptDeviceEnrolled, KeptDeviceLastSync, Result, Details, IntuneDeviceId, KeptIntuneDeviceId | Export-Csv -Path $fileName_Duplicates -NoTypeInformation -Encoding UTF8
        $reportFiles += $fileName_Duplicates
        Write-RjRbLog -Message "Exported $($removalResults.Count) duplicate device records to: $fileName_Duplicates" -Verbose

        if ($skippedDuplicates.Count -gt 0) {
            $fileName_Skipped = Join-Path $tempDir "SkippedDuplicates.csv"
            $skippedDuplicates | Export-Csv -Path $fileName_Skipped -NoTypeInformation -Encoding UTF8
            $reportFiles += $fileName_Skipped
            Write-RjRbLog -Message "Exported $($skippedDuplicates.Count) skipped duplicate devices to: $fileName_Skipped" -Verbose
        }

        Write-Output "Report file export completed: $($reportFiles.Count) file(s) created"
    }
    else {
        Write-Output "No duplicate devices found - skipping CSV export"
    }
}

$xlsxFile = $null

if ($ReportFileFormat -ne 'CSV only' -and $removalResults.Count -gt 0) {
    Write-Output ""
    Write-Output "Creating XLSX workbook"
    Write-Output "---------------------"

    $xlsxFile = Join-Path $tempDir 'DuplicateDevices.xlsx'

    $duplicateSheet = @($removalResults | Select-Object SerialNumber, DeviceName, OperatingSystem, OSVersion, UserPrincipalName, Enrolled, LastSync, DaysSinceLastSync, KeptDeviceName, KeptDeviceEnrolled, KeptDeviceLastSync, Result, Details, IntuneDeviceId, KeptIntuneDeviceId)

    $workbookSheets = [ordered]@{ 'Duplicate devices' = $duplicateSheet }
    if ($skippedDuplicates.Count -gt 0) {
        $workbookSheets['Skipped duplicates'] = @($skippedDuplicates)
    }

    $workbookMode = if ($WhatIfMode) {
        'WhatIf (nothing deleted)'
    }
    elseif ($removalLimitExceeded) {
        'Live (limit exceeded, nothing deleted)'
    }
    else {
        'Live (records deleted)'
    }

    $workbookCoverSheet = [ordered]@{
        Title                      = 'Duplicate Intune devices'
        Generated                  = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
        'Runbook Version'          = $Version
        Tenant                     = $tenantDisplayName
        Mode                       = $workbookMode
        'Duplicate serial numbers' = $duplicateSerialCount
        'Removal candidates'       = $removalResults.Count
        Deleted                    = $deletedCount
        Failed                     = $failedCount
        'Skipped duplicates'       = $skippedDuplicates.Count
    }

    try {
        Export-RjRbXlsx -Worksheets $workbookSheets `
            -Path $xlsxFile `
            -CoverSheet $workbookCoverSheet `
            -HighlightRules @(
                @{ Column = 'Result'; Value = 'Deleted'; Color = 'Green' }
                @{ Column = 'Result'; Value = 'Failed'; Color = 'Red' }
            )
        $reportFiles += $xlsxFile
        Write-Output "XLSX workbook created: $(Split-Path -Leaf $xlsxFile)"
    }
    catch {
        Write-Error "Failed to create the XLSX workbook: $($_.Exception.Message)" -ErrorAction Continue
        $xlsxFile = $null
    }
}
#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################
$uploadError = $null

if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
    Write-Output ""
    Write-Output "Download link"
    Write-Output "---------------------"

    try {
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
            Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }
    catch {
        # The records are already processed at this point. The email report is still sent and the
        # run fails afterwards, at the end of the Send Email Report region.
        $uploadError = $_.Exception.Message
        Write-Error "The report files could not be uploaded, so no download link was created: $uploadError Verify the RJReport.StorageAccount.* settings and that the managed identity is allowed to write to the storage account." -ErrorAction Continue
    }
}
elseif ($CreateDownloadLink) {
    Write-RjRbLog -Message "No download link created: no report files were generated because no duplicate devices qualified for removal." -Verbose
}
#endregion Upload / Download Link

########################################################
#region     Send Email Report
########################################################
$brandingMailParams = $null

if ($SendEmailReport -and $EmailTo -and $removalResults.Count -gt 0) {
    Write-Output ""
    Write-Output "Send email report"
    Write-Output "---------------------"

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    $emailModeLabel = if ($WhatIfMode) { 'WhatIf - nothing deleted' } else { 'Live' }
    $emailSubject = "Duplicate Intune devices$(if ($WhatIfMode) { ' (WhatIf)' }) - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"
    $removedLabel = if ($WhatIfMode) { 'Records that would be deleted' } else { 'Records deleted' }
    # When the limit is exceeded every row carries '(limit exceeded)', so only rows that would be deleted are counted in WhatIf
    $removedValue = if ($WhatIfMode) { @($removalResults | Where-Object { $_.Result -eq 'Would be deleted' }).Count } else { $deletedCount }

    $limitNote = ''
    if ($removalLimitExceeded) {
        # The limit is all-or-nothing: no record is deleted when more qualify than allowed
        $limitNote = if ($WhatIfMode) {
            "`n> **Note:** More records qualified than the limit of $MaxDevicesToRemove per run. A live run would delete none of them - review the list and raise 'Maximum devices to remove' if it is correct.`n"
        }
        else {
            "`n> **Note:** More records qualified than the limit of $MaxDevicesToRemove per run. Nothing was deleted - review the list and raise 'Maximum devices to remove' if it is correct.`n"
        }
    }

    $previewLimit = 10
    $tableLines = @(
        '| Device name | Serial number | Operating system | Last sync | Kept device | Result |'
        '| --- | --- | --- | --- | --- | --- |'
    )
    foreach ($row in @($removalResults | Select-Object -First $previewLimit)) {
        $resultText = if ($row.Details) { "$($row.Result): $($row.Details)" } else { $row.Result }
        $cells = @($row.DeviceName, $row.SerialNumber, $row.OperatingSystem, $row.LastSync, $row.KeptDeviceName, $resultText) | ForEach-Object { ("$_" -replace '\|', '\|') }
        $tableLines += "| $($cells -join ' | ') |"
    }
    $deviceTable = $tableLines -join "`n"

    $moreLine = ''
    if ($removalResults.Count -gt $previewLimit) {
        $moreSource = if ($reportFiles.Count -gt 0) { 'see attachment' } else { 'see the Output Data of the run' }
        $moreLine = "`n`n... and $($removalResults.Count - $previewLimit) more, $moreSource"
    }

    $summaryBlock = @"
## Duplicate Intune devices

- **Mode:** $emailModeLabel
- **Duplicate serial numbers:** $duplicateSerialCount
- **${removedLabel}:** $removedValue
- **Failed:** $failedCount
- **Skipped duplicates:** $($skippedDuplicates.Count)
$limitNote
$deviceTable$moreLine
"@

    $footerBlock = @"

---

*This email was automatically generated. Please do not reply to this email.*
"@

    $markdownContent = $summaryBlock + $footerBlock
    $markdownFallbackXlsxOnly = $summaryBlock + "`n`n> The CSV file was left out because the attachments exceeded the size limit. The Excel workbook contains the full list.`n" + $footerBlock

    try {
        $emailParams = @{
            EmailFrom             = $EmailFrom
            EmailTo               = $EmailTo
            Subject               = $emailSubject
            MarkdownContent       = $markdownContent
            TenantDisplayName     = $tenantDisplayName
            ReportVersion         = $Version
            UseNativeGraphRequest = $true   # sends through the Connect-MgGraph session (no Connect-RjRbGraph)
        }

        if ($reportFiles.Count -eq 0) {
            Send-RjRbReportEmail @emailParams @brandingMailParams
        }
        elseif ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFile -and (Test-Path -Path $xlsxFile)) {
            # Both formats attached; fall back to the workbook alone if the pair is too large.
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFile) -FallbackMarkdownContent $markdownFallbackXlsxOnly
        }
        else {
            Send-RjRbReportEmail @emailParams @brandingMailParams -Attachments $reportFiles
        }
        Write-Output "Email report sent to $EmailTo"
    }
    catch {
        $mailError = $_.Exception.Message
        if ($mailError -like "*403*" -or $mailError -like "*Forbidden*" -or $mailError -like "*ErrorAccessDenied*") {
            # Mail.Send missing, or the sender mailbox is outside the application access policy
            Write-Error "The report email to '$EmailTo' could not be sent: access denied. Verify that the managed identity has the Graph permission Mail.Send and may send as '$EmailFrom'." -ErrorAction Continue
        }
        elseif ($mailError -like "*404*" -or $mailError -like "*MailboxNotFound*" -or $mailError -like "*ResourceNotFound*") {
            Write-Error "The report email could not be sent: the sender mailbox '$EmailFrom' was not found. Check the tenant setting RJReport.EmailSender." -ErrorAction Continue
        }
        else {
            Write-Error "The report email to '$EmailTo' could not be sent: $mailError" -ErrorAction Continue
        }
        Write-RjRbLog -Message "Error sending email: $mailError" -Verbose
        throw "Failed to send email report: $($_.Exception.Message)"
    }
}
elseif ($SendEmailReport) {
    Write-RjRbLog -Message "No email sent: no duplicate devices qualified for removal." -Verbose
}

# A failed upload must not suppress the email report, so the run fails here, after the send
if ($uploadError) {
    throw "Failed to create the download link: $uploadError"
}
#endregion Send Email Report

########################################################
#region     Cleanup
########################################################
Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

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

if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

Write-Output ""
Write-Output "Done!"
#endregion Cleanup

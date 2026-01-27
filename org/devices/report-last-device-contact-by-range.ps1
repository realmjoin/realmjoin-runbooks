<#
.SYNOPSIS
    Reports devices with last contact within a specified date range.

.DESCRIPTION
    This Runbook retrieves a list of devices from Intune, filtered by their last device contact time (lastSyncDateTime).
    As a dropdown for the date range, you can select from 0-30 days, 30-90 days, 90-180 days, 180-365 days, or 365+ days.

    The output includes the device name, last sync date, Intune device ID, and user principal name.

    Optionally, the report can be sent via email with a CSV attachment containing additional details (Entra ID Device ID, User ID).

.PARAMETER dateRange
    Date range for filtering devices based on their last contact time.

.PARAMETER systemType
    The operating system type of the devices to filter.

.PARAMETER EmailTo
    If specified, an email with the report will be sent to the provided address(es).
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

.PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization

.PARAMETER CallerName
    Internal parameter for tracking purposes

.INPUTS
    RunbookCustomization: {
        "Parameters": {
            "dateRange": {
                "DisplayName": "Select Last Device Contact Range (days)",
                "Description": "Filter devices based on their last contact time.",
                "Required": true,
                "SelectSimple": {
                    "0-30 days": "0-30",
                    "30-90 days": "30-90",
                    "90-180 days": "90-180",
                    "180-365 days": "180-365",
                    "365 days and more": "365+"
                }
            },
            "systemType": {
                "DisplayName": "Select System Type",
                "Description": "Filter devices based on their operating system.",
                "Required": true,
                "SelectSimple": {
                    "All": "all",
                    "Windows": "Windows",
                    "MacOS": "macOS",
                    "Linux": "Linux",
                    "Android": "Android"
                }
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)"
            },
            "EmailFrom": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.34.0" }

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("0-30", "30-90", "90-180", "180-365", "365+")]
    [string]$dateRange,

    [Parameter(Mandatory = $true)]
    [ValidateSet("all", "Windows", "macOS", "Linux", "Android")]
    [string]$systemType = "Windows",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom,

    [Parameter(Mandatory = $false)]
    [string]$EmailTo,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
##
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.1.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "DateRange: $dateRange" -Verbose
Write-RjRbLog -Message "SystemType: $systemType" -Verbose
if ($EmailTo) {
    Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
    Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
}

#endregion

########################################################
#region     Parameter Validation
########################################################

# Validate Email Addresses (only if email is requested)
if ($EmailTo) {
    if (-not $EmailFrom) {
        Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -Verbose
        throw "This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
        exit
    }
}

#endregion

####################################################################
#region Function Definitions
####################################################################

function Get-AllGraphPage {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Get-AllGraphPage takes an initial Microsoft Graph API URI and retrieves all items across
        multiple pages by following the @odata.nextLink property in the response. It aggregates
        all items into a single array and returns it.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/applications".

        .EXAMPLE
        PS C:\> $allApps = Get-AllGraphPage -Uri "https://graph.microsoft.com/v1.0/applications"
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
        elseif ($response.'@odata.context') {
            # Single item response
            $allResults += $response
        }

        if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
            $nextLink = $response.'@odata.nextLink'
        }
        else {
            $nextLink = $null
        }
    } while ($nextLink)

    return $allResults
}

#endregion


####################################################################
#region Connect to Microsoft Graph
####################################################################

try {
    Write-Verbose "Connecting to Microsoft Graph..."
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    Write-Verbose "Successfully connected to Microsoft Graph."
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    throw
}


# Connect RJ RunbookHelper for email reporting
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

#endregion

####################################################################
#region Retrieve Windows Devices by Last Device Contact Date Range
####################################################################

#region Prepare parameters and filters
$now = Get-Date
$startDate = $null
$endDate = $null

switch ($dateRange) {
    "0-30" {
        $startDate = $now.AddDays(-30)
        $endDate = $now
    }
    "30-90" {
        $startDate = $now.AddDays(-90)
        $endDate = $now.AddDays(-30)
    }
    "90-180" {
        $startDate = $now.AddDays(-180)
        $endDate = $now.AddDays(-90)
    }
    "180-365" {
        $startDate = $now.AddDays(-365)
        $endDate = $now.AddDays(-180)
    }
    "365+" {
        # For "365+", $startDate remains $null, meaning no lower bound on age.
        # We will filter for devices with contact date *older than or equal to* 365 days ago.
        $endDate = $now.AddDays(-365)
    }
}

$dateFilter = ""

if ($dateRange -eq "365+") {
    $endDateISO = $endDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $dateFilter = "lastSyncDateTime le $($endDateISO)"
    Write-Verbose "Filtering for devices with last contact on or before $($endDateISO)."
}
else {
    $startDateISO = $startDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endDateISO = $endDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $dateFilter = "lastSyncDateTime ge $($startDateISO) and lastSyncDateTime le $($endDateISO)"
    Write-Verbose "Filtering for devices with last contact between $($startDateISO) and $($endDateISO)."
}

# Base URI for Microsoft Graph API to fetch managed devices
$baseURI = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter='


# Prepare the filter query based on the system type and date range
if ($systemType -ne 'all') {
    $baseFilter = "operatingSystem eq '$($systemType)'"
    $filterQuery = "$($baseFilter) and $($dateFilter)"
}
else {
    $filterQuery = $dateFilter
}

$selectQuery = '&$select='
$selectProperties = "id,azureADDeviceId,lastSyncDateTime,deviceName,userId,userDisplayName,userPrincipalName,operatingSystem"
$selectProperties_Array = $selectProperties -split ',' | ForEach-Object { $_.Trim() }

$fullURI = $baseURI + $filterQuery + $selectQuery + $selectProperties

#endregion

#region Fetch Devices

$allDevices = @()
$currentURI = $fullURI

try {
    Write-Verbose "Retrieving devices from Microsoft Graph with initial filter: $($filterQuery)"
    Write-Verbose "Fetching data from URI: $($currentURI)"
    $allDevices_unfiltered = Get-AllGraphPage -Uri $currentURI -ErrorAction Stop
    $allDevices = $allDevices_unfiltered | Select-Object -Property $selectProperties_Array
    if ($($allDevices_unfiltered.'@odata.count') -notlike 0) {
        Write-Output "Retrieved devices using the current filter: $(($allDevices | Measure-Object).Count)"
    }
    else {
        Write-Output "No devices found using the current filter."
        $allDevices = @()
    }
}
catch {
    Write-Error "Failed to retrieve devices: $($_.Exception.Message)"
    # If an error occurs, $devices might be partially populated or null.
    # Depending on requirements, you might want to clear $devices or handle it.
    # For now, we'll let it be as is and throw the exception.
    throw
}

#endregion
#endregion

######################################################################
#region Output Devices
######################################################################

#Prettify the property names for better readability
$outputDevices = $allDevices | ForEach-Object {
    [PSCustomObject]@{
        DeviceName        = $_.deviceName
        LastSyncDateTime  = $_.lastSyncDateTime
        IntuneDeviceId    = $_.id
        EntraIdDeviceId   = $_.azureADDeviceId
        OperatingSystem   = $_.operatingSystem
        UserDisplayName   = $_.userDisplayName
        UserPrincipalName = $_.userPrincipalName
        UserId            = $_.userId
    }
}

Write-Verbose "Resulting devices: $(($outputDevices | Measure-Object).Count)"

# Console output
if ($(($outputDevices | Measure-Object).Count) -eq 0) {
    Write-Output "No devices found matching the specified date range."
}
else {
    Write-Output "Found $(($outputDevices | Measure-Object).Count) devices matching the criteria."
    # Reduced properties in the output to optimize readability
    $outputDevices | Select-Object DeviceName, LastSyncDateTime, IntuneDeviceId, UserPrincipalName | Format-Table
}

#endregion

######################################################################
#region Send Email Report (if requested)
######################################################################

if ($EmailTo) {
    Write-Output ""
    Write-Output "Preparing email report..."

    # Get tenant information
    try {
        $tenant = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method GET
        if ($tenant.value -and (($(($tenant.value) | Measure-Object).Count) -gt 0)) {
            $tenant = $tenant.value[0]
        }
        $tenantDisplayName = $tenant.displayName
        $tenantId = $tenant.id
        Write-RjRbLog -Message "Tenant: $tenantDisplayName ($tenantId)" -Verbose
    }
    catch {
        Write-RjRbLog -Message "Warning: Could not retrieve tenant information: $($_.Exception.Message)" -Verbose
        $tenantDisplayName = ""
    }

    # Prepare date range description
    $dateRangeDescription = switch ($dateRange) {
        "0-30" { "0-30 days ago" }
        "30-90" { "30-90 days ago" }
        "90-180" { "90-180 days ago" }
        "180-365" { "180-365 days ago" }
        "365+" { "more than 365 days ago" }
    }

    # Check if any devices were found
    $deviceCount = ($outputDevices | Measure-Object).Count
    $csvFiles = @()

    if ($deviceCount -eq 0) {
        # No devices found - send email without attachments
        Write-RjRbLog -Message "No devices found in the specified date range - sending notification email" -Verbose

        $markdownContent = @"
# Device Last Contact Report

## Summary

✅ **No devices found** with last contact in the specified date range.

## Report Parameters

| Parameter | Value |
|-----------|-------|
| **Date Range** | $($dateRangeDescription) |
| **System Type** | $($systemType) |
| **Devices Found** | 0 |
| **Report Date** | $(Get-Date -Format 'yyyy-MM-dd HH:mm') |

## Analysis

This result indicates:
- No devices match the selected criteria ($($systemType), $($dateRangeDescription))
- All devices may be checking in more frequently (if looking at older date ranges)
- Or no devices exist in this category

## Recommendations

### Next Steps

$(if ($dateRange -eq "365+" -or $dateRange -eq "180-365") {
@"
✅ **Good News for Old Devices:**
- No stale devices detected in this time range
- Device management appears healthy
- Continue regular monitoring
"@
} else {
@"
📊 **Recent Activity Check:**
- Consider checking other date ranges
- Verify system type filter is correct
- Review overall device inventory
"@
})

### Suggested Actions

**Verify Search Criteria:**
   - Confirm the date range and system type are correct
   - Try different date ranges to compare results
   - Check if devices exist for the selected system type

**Regular Monitoring:**
   - Schedule periodic reports with different time ranges
   - Track device activity trends over time
   - Set up alerts for unusual patterns

"@

        $emailSubject = "Device Last Contact Report - No Devices Found - $($systemType) ($($dateRangeDescription)) - $(Get-Date -Format 'yyyy-MM-dd')"

    }
    else {
        # Devices found - create CSV file and send detailed report
        Write-RjRbLog -Message "Found $($deviceCount) devices - preparing detailed report" -Verbose

        # Create temporary directory for CSV files
        $tempDir = Join-Path ((Get-Location).Path) "DeviceContactReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

        # Export to CSV
        $csvFile = Join-Path $tempDir "DeviceContactReport_$($systemType)_$($dateRange)days.csv"
        $outputDevices | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        Write-Verbose "Exported device data to: $csvFile"
        $csvFiles += $csvFile

        # Create markdown content for email with detailed findings
        $markdownContent = @"
# Device Last Contact Report

This report provides an overview of devices with their last contact within the specified date range.

## Report Parameters

| Parameter | Value |
|-----------|-------|
| **Date Range** | $($dateRangeDescription) |
| **System Type** | $($systemType) |
| **Total Devices Found** | $($deviceCount) |

## Summary

$(if ($deviceCount -eq 0) {
"No devices were found matching the specified criteria."
} else {
@"
This report contains **$($deviceCount) devices** that last contacted Intune within the specified timeframe.

### Device Statistics by Operating System

$(
    $osByType = $outputDevices | Group-Object OperatingSystem | Sort-Object Count -Descending
    $osByType | ForEach-Object {
        "- **$($_.Name)**: $($_.Count) device(s)"
    }
)

### Top 10 Devices (by Last Sync)

| Device Name | Last Sync | Operating System | User |
|-------------|-----------|------------------|------|
$(
    $outputDevices | Sort-Object LastSyncDateTime -Descending | Select-Object -First 10 | ForEach-Object {
        $lastSync = if ($_.LastSyncDateTime) {
            [DateTime]::Parse($_.LastSyncDateTime).ToString("yyyy-MM-dd HH:mm")
        } else {
            "N/A"
        }
        "| $($_.DeviceName) | $($lastSync) | $($_.OperatingSystem) | $($_.UserPrincipalName) |"
    }
)
"@
})

## Data Export Information

The attached CSV file contains detailed information including:
- Device Name and Intune Device ID
- Last Sync Date and Time
- Entra ID Device ID
- User Display Name and User Principal Name
- Operating System
- User ID

## Recommendations

$(if ($dateRange -eq "365+") {
@"
### ⚠️ Devices Not Seen for Over a Year

These devices have not contacted Intune for over 365 days. Consider:
- Reviewing if these devices are still in use
- Checking if users need assistance reconnecting
- Evaluating for device retirement or cleanup
"@
} elseif ($dateRange -eq "180-365") {
@"
### 🔍 Devices Not Seen for 6-12 Months

These devices haven't checked in for 180-365 days. You may want to:
- Contact device users to verify device status
- Check for potential connectivity or policy issues
- Consider device health evaluation
"@
} else {
@"
### ✅ Recent Device Activity

These devices have contacted Intune recently. This indicates:
- Active device management
- Proper connectivity to Intune services
- Regular policy and app updates
"@
})
"@

        $emailSubject = "Device Last Contact Report - $systemType ($($dateRangeDescription)) - $(Get-Date -Format 'yyyy-MM-dd')"
    }

    # Send email (with or without attachments depending on findings)
    try {
        if ($deviceCount -eq 0) {
            Send-RjReportEmail `
                -EmailFrom $EmailFrom `
                -EmailTo $EmailTo `
                -Subject $emailSubject `
                -MarkdownContent $markdownContent `
                -Attachments $csvFiles `
                -TenantDisplayName $tenantDisplayName `
                -ReportVersion $Version
        }
        else {
            Send-RjReportEmail `
                -EmailFrom $EmailFrom `
                -EmailTo $EmailTo `
                -Subject $emailSubject `
                -MarkdownContent $markdownContent `
                -TenantDisplayName $tenantDisplayName `
                -ReportVersion $Version
        }


        Write-RjRbLog -Message "Email report sent successfully to: $($EmailTo)" -Verbose
        Write-Output "✅ Device contact report generated and sent successfully"
        Write-Output "📧 Recipient: $($EmailTo)"
        if ($deviceCount -gt 0) {
            Write-Output "📊 Devices reported: $deviceCount"
        }
        else {
            Write-Output "✅ No devices found in specified date range"
        }
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to send email report: $($_.Exception.Message)"
    }
    finally {
        # Clean up temporary files (only if they were created)
        if ($deviceCount -gt 0) {
            try {
                if (Test-Path $tempDir) {
                    Remove-Item -Path $tempDir -Recurse -Force
                    Write-RjRbLog -Message "Cleaned up temporary directory: $($tempDir)" -Verbose
                }
            }
            catch {
                Write-RjRbLog -Message "Warning: Could not clean up temporary directory: $($_.Exception.Message)" -Verbose
            }
        }
    }
}

#endregion

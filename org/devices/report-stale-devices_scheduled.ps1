<#
    .SYNOPSIS
    Scheduled report of stale devices based on last activity date and platform.

    .DESCRIPTION
    Identifies and lists devices that haven't been active for a specified number of days.
    Automatically sends a report via email.

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

    .PARAMETER EmailTo
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Days": {
                "DisplayName": "Days Without Activity",
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
            "CallerName": {
                "Hide": true
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)"
            },
            "EmailFrom": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.34.0" }

param(
    [int] $Days = 30,
    [bool] $Windows = $true,
    [bool] $MacOS = $true,
    [bool] $iOS = $true,
    [bool] $Android = $true,
    [Parameter(Mandatory = $true)]
    [string] $EmailTo,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom,
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

$Version = "1.1.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "Days: $Days" -Verbose
Write-RjRbLog -Message "Windows: $Windows" -Verbose
Write-RjRbLog -Message "MacOS: $MacOS" -Verbose
Write-RjRbLog -Message "iOS: $iOS" -Verbose
Write-RjRbLog -Message "Android: $Android" -Verbose

#endregion

########################################################
#region     Parameter Validation
########################################################

# Validate Email Addresses
if (-not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -Verbose
    throw "This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
    exit
}

if (-not $EmailTo) {
    Write-RjRbLog -Message "The recipient email address is required. It could be a single address or multiple comma-separated addresses." -Verbose
    throw "The recipient email address is required."
}

#endregion

########################################################
#region     Email Function Definitions
########################################################

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

# Calculate the date threshold for stale devices
$beforeDate = (Get-Date).AddDays(-$Days) | Get-Date -Format "yyyy-MM-dd"

# Prepare filter for the Graph API query
$filter = "lastSyncDateTime le $($beforeDate)T00:00:00Z"

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
$devices = Get-AllGraphPage -Uri $devicesUri

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
                $userUri = "https://graph.microsoft.com/v1.0/users/{0}?`$select=displayName,city,usageLocation" -f $encodedUserPrincipalName
                $userInfo = Invoke-MgGraphRequest -Uri $userUri -Method GET -ErrorAction SilentlyContinue

                if ($userInfo) {
                    $device | Add-Member -Name "userDisplayName" -Value $userInfo.displayName -MemberType "NoteProperty" -Force
                    $device | Add-Member -Name "userLocation" -Value "$($userInfo.city), $($userInfo.usageLocation)" -MemberType "NoteProperty" -Force
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

Write-Output ""
Write-Output "## Detailed list of stale devices:"
Write-Output ""

# Convert to PSCustomObject array for consistent formatting
$displayDevices = @()
foreach ($device in $filteredDevices) {
    $displayDevices += [PSCustomObject]@{
        LastSync      = if ($device.lastSyncDateTime) { Get-Date $device.lastSyncDateTime -Format yyyy-MM-dd } else { "N/A" }
        DeviceName    = if ($device.deviceName -and $device.deviceName.Length -gt 15) { $device.deviceName.Substring(0, 14) + ".." } elseif ($device.deviceName) { $device.deviceName } else { "N/A" }
        DeviceID      = if ($device.id -and $device.id.Length -gt 15) { $device.id.Substring(0, 14) + ".." } elseif ($device.id) { $device.id } else { "N/A" }
        SerialNumber  = if ($device.serialNumber -and $device.serialNumber.Length -gt 15) { $device.serialNumber.Substring(0, 14) + ".." } elseif ($device.serialNumber) { $device.serialNumber } else { "N/A" }
        PrimaryUser   = if ($device.userPrincipalName -and $device.userPrincipalName.Length -gt 20) { $device.userPrincipalName.Substring(0, 19) + ".." } elseif ($device.userPrincipalName) { $device.userPrincipalName } else { "N/A" }
    }
}

# Display the filtered devices
$displayDevices | Sort-Object -Property LastSync | Format-Table -AutoSize

# Create Markdown content for email
Write-Output ""
Write-Output "## Preparing email report to send to $($EmailTo)"

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
# Build Markdown content
$markdownContent = if ($filteredDevices.Count -eq 0) {
    @"
# Stale Devices Report

Great news — no managed devices matched the stale device criteria (last sync on or before **$($beforeDate)**) for the selected platforms.

## What We Checked

- Inactivity threshold: **$($Days) days**
- Platforms evaluated: $($platformSummary)
- Devices evaluated: $($totalDevicesEvaluated)

## Recommendations

- Continue to monitor this report regularly to spot newly idle devices early
- Keep lifecycle policies and retirement procedures current
- Ensure device owners stay informed about required check-ins
"@
}
else {
    @"
# Stale Devices Report

This report shows devices that have not been active for at least **$($Days) days**.

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Stale Devices** | $($filteredDevices.Count) |
$(if ($Windows) {
    $windowsCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Windows" } | Measure-Object).Count
    "| **Windows Devices** | $($windowsCount) |"
})
$(if ($MacOS) {
    $macOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "macOS" } | Measure-Object).Count
    "| **macOS Devices** | $($macOSCount) |"
})
$(if ($iOS) {
    $iOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "iOS" } | Measure-Object).Count
    "| **iOS Devices** | $($iOSCount) |"
})
$(if ($Android) {
    $androidCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Android" } | Measure-Object).Count
    "| **Android Devices** | $($androidCount) |"
})

$(if ($filteredDevices_moreThan10) {
    "## Top 10 Stale Devices (by Last Sync Date)"
    ""
    "This table lists the top 10 devices that have been inactive the longest, based on the current defined days ($($Days) days) threshold."
    ""
} else {
    "## Stale Devices"
    ""
    "This table lists all devices that have been inactive for at least $($Days) days, based on the current defined days threshold."
    ""
})


$(if ($filteredDevices.Count -gt 0) {
    $sortedDevices = $filteredDevices | Sort-Object -Property lastSyncDateTime

    # Create markdown table
    $table = @"
| Last Sync | Device Name | Operating System | Serial Number | Primary User |
|-----------|-------------|------------------|---------------|--------------|
"@

    foreach ($device in $sortedDevices) {
        $lastSync = Get-Date $device.lastSyncDateTime -Format yyyy-MM-dd
        $deviceName = $device.deviceName
        $os = $device.operatingSystem
        $serialNumber = $device.serialNumber
        $user = $device.userPrincipalName

        $table += "`n| $($lastSync) | $($deviceName) | $($os) | $($serialNumber) | $($user) |"
    }

    $table
} else {
    "No stale devices found matching the selected criteria."
})

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

The .csv-file attached to this email contains the full list of stale devices for further analysis.

"@
}

# Create CSV file in current location
$csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath "StaleDevicesReport_$($tenantDisplayName)_$($Days)Days.csv"
$filteredDevices | Export-Csv -Path $csvFilePath -NoTypeInformation
$attachments = @($csvFilePath)
Write-RjRbLog -Message "Exported stale devices to CSV: $($csvFilePath)" -Verbose

# Send email report
$emailSubject = "Stale Devices Report - $($tenantDisplayName) - $($Days) days"

Write-Output "Sending report to '$($EmailTo)'..."
try {
    Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version -Attachments $attachments

    Write-RjRbLog -Message "Email report sent successfully to: $($EmailTo)" -Verbose
    Write-Output "✅ Stale devices report generated and sent successfully"
    Write-Output "📧 Recipient: $($EmailTo)"
    Write-Output "📊 Total Stale Devices: $($filteredDevices.Count)"
    Write-Output "⏱️ Inactive for: $Days days"
}
catch {
    Write-Output "Error sending email: $_"
    Write-RjRbLog -Message "Error sending email: $_" -Verbose
    throw "Failed to send email report: $($_.Exception.Message)"
}
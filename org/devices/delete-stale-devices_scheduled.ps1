<#
    .SYNOPSIS
    Scheduled deletion of stale devices based on last activity

    .DESCRIPTION
    This runbook identifies Intune managed devices that have not been active for a defined number of days.
    It can optionally delete the matching devices and can send an email report.

    .PARAMETER Days
    Number of days without activity to be considered stale

    .PARAMETER Windows
    Include Windows devices in the results

    .PARAMETER MacOS
    Include macOS devices in the results

    .PARAMETER iOS
    Include iOS devices in the results

    .PARAMETER Android
    Include Android devices in the results

    .PARAMETER DeleteDevices
    If set to true, the script will delete the stale devices. If false, it will only report them.

    .PARAMETER ConfirmDeletion
    If set to true, the script will prompt for confirmation before deleting devices.
    Should be set to false for scheduled runs.

    .PARAMETER sendAlertTo
    Email address to send the report to.

    .PARAMETER sendAlertFrom
    Email address to send the report from.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [int] $Days = 30,
    [bool] $Windows = $true,
    [bool] $MacOS = $true,
    [bool] $iOS = $true,
    [bool] $Android = $true,
    [bool] $DeleteDevices = $false,
    [bool] $ConfirmDeletion = $true,
    [string] $sendAlertTo = "support@glueckkanja.com",
    [string] $sendAlertFrom = "runbook@glueckkanja.com",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

# Connect to Microsoft Graph
Connect-RjRbGraph

# Get tenant information
Write-Output "## Retrieving tenant information..."
$organization = Invoke-RjRbRestMethodGraph -Resource "/organization" -ErrorAction SilentlyContinue
$tenantDisplayName = "Unknown Tenant"

if ($organization -and $organization.Count -gt 0) {
    $tenantDisplayName = $organization[0].displayName
    Write-Output "## Tenant: $tenantDisplayName"
}
Write-Output ""

# Calculate the date threshold for stale devices
$beforeDate = (Get-Date).AddDays(-$Days) | Get-Date -Format "yyyy-MM-dd"

# Prepare filter for the Graph API query
$filter = "lastSyncDateTime le ${beforeDate}T00:00:00Z"

# Define the properties to select
$selectString = "deviceName, lastSyncDateTime, enrolledDateTime, userPrincipalName, id, serialNumber, manufacturer, model, operatingSystem, osVersion, complianceState"

# Get all stale devices
Write-Output "## Listing devices not active for at least $Days days"
Write-Output ""

$devices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdSelect $selectString -OdFilter $filter -FollowPaging

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
        try {
            $userInfo = Invoke-RjRbRestMethodGraph -Resource "/Users/$($device.userPrincipalName)" -OdSelect "displayName, city, usageLocation" -ErrorAction SilentlyContinue

            if ($userInfo) {
                $device | Add-Member -Name "userDisplayName" -Value $userInfo.displayName -MemberType "NoteProperty" -Force
                $device | Add-Member -Name "userLocation" -Value "$($userInfo.city), $($userInfo.usageLocation)" -MemberType "NoteProperty" -Force
            }
        }
        catch {
            Write-RjRbLog -Message "Could not retrieve user info for $($device.userPrincipalName): $_" -Verbose
        }

        $filteredDevices += $device
    }
}

# Display summary counts
Write-Output "## Summary of stale devices for ${tenantDisplayName}:"
Write-Output "Total devices: $($filteredDevices.Count)"

if ($Windows) {
    $windowsCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Windows" }).Count
    Write-Output "Windows devices: $windowsCount"
}

if ($MacOS) {
    $macOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "macOS" }).Count
    Write-Output "macOS devices: $macOSCount"
}

if ($iOS) {
    $iOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "iOS" }).Count
    Write-Output "iOS devices: $iOSCount"
}

if ($Android) {
    $androidCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Android" }).Count
    Write-Output "Android devices: $androidCount"
}

Write-Output ""
Write-Output "## Detailed list of stale devices:"
Write-Output ""

# Display the filtered devices
$filteredDevices | Sort-Object -Property lastSyncDateTime | Format-Table -AutoSize -Property @{
    name       = "LastSync";
    expression = { Get-Date $_.lastSyncDateTime -Format yyyy-MM-dd }
}, @{
    name       = "DeviceName";
    expression = { if ($_.deviceName.Length -gt 15) { $_.deviceName.substring(0, 14) + ".." } else { $_.deviceName } }
}, @{
    name       = "DeviceID";
    expression = { if ($_.id.Length -gt 15) { $_.id.substring(0, 14) + ".." } else { $_.id } }
}, @{
    name       = "SerialNumber";
    expression = { if ($_.serialNumber.Length -gt 15) { $_.serialNumber.substring(0, 14) + ".." } else { $_.serialNumber } }
}, @{
    name       = "PrimaryUser";
    expression = { if ($_.userPrincipalName.Length -gt 20) { $_.userPrincipalName.substring(0, 19) + ".." } else { $_.userPrincipalName } }
}, @{
    name       = "OS";
    expression = { $_.operatingSystem }
}

# Create HTML content for email
Write-Output ""

# Create HTML header
$HTMLBody = "<h2>Stale Devices Report - $tenantDisplayName</h2>"
$HTMLBody += "<p>This report shows devices that have not been active for at least $Days days.</p>"

# Add summary section
$HTMLBody += "<h3>Summary</h3>"
$HTMLBody += "<ul>"
$HTMLBody += "<li>Total devices: $($filteredDevices.Count)</li>"

if ($Windows) {
    $windowsCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Windows" }).Count
    $HTMLBody += "<li>Windows devices: $windowsCount</li>"
}

if ($MacOS) {
    $macOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "macOS" }).Count
    $HTMLBody += "<li>macOS devices: $macOSCount</li>"
}

if ($iOS) {
    $iOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "iOS" }).Count
    $HTMLBody += "<li>iOS devices: $iOSCount</li>"
}

if ($Android) {
    $androidCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Android" }).Count
    $HTMLBody += "<li>Android devices: $androidCount</li>"
}

$HTMLBody += "</ul>"

# Create HTML table
$HTMLBody += "<h3>Detailed List</h3>"

if ($filteredDevices.Count -gt 0) {
    $HTMLBody += "<table border='1' style='border-collapse: collapse; width: 100%;'>"
    $HTMLBody += "<tr style='background-color: #f2f2f2;'>"
    $HTMLBody += "<th style='padding: 8px; text-align: left;'>Last Sync</th>"
    $HTMLBody += "<th style='padding: 8px; text-align: left;'>Device Name</th>"
    $HTMLBody += "<th style='padding: 8px; text-align: left;'>Device ID</th>"
    $HTMLBody += "<th style='padding: 8px; text-align: left;'>Serial Number</th>"
    $HTMLBody += "<th style='padding: 8px; text-align: left;'>Primary User</th>"
    $HTMLBody += "<th style='padding: 8px; text-align: left;'>OS</th>"
    $HTMLBody += "</tr>"

    $sortedDevices = $filteredDevices | Sort-Object -Property lastSyncDateTime

    foreach ($device in $sortedDevices) {
        $lastSync = Get-Date $device.lastSyncDateTime -Format yyyy-MM-dd
        $deviceName = $device.deviceName
        $deviceId = $device.id
        $serialNumber = $device.serialNumber
        $user = $device.userPrincipalName
        $os = $device.operatingSystem

        $HTMLBody += "<tr>"
        $HTMLBody += "<td style='padding: 8px;'>$lastSync</td>"
        $HTMLBody += "<td style='padding: 8px;'>$deviceName</td>"
        $HTMLBody += "<td style='padding: 8px;'>$deviceId</td>"
        $HTMLBody += "<td style='padding: 8px;'>$serialNumber</td>"
        $HTMLBody += "<td style='padding: 8px;'>$user</td>"
        $HTMLBody += "<td style='padding: 8px;'>$os</td>"
        $HTMLBody += "</tr>"
    }

    $HTMLBody += "</table>"
}
else {
    $HTMLBody += "<p>No stale devices found matching the selected criteria.</p>"
}

# Add deletion information if applicable
if ($DeleteDevices) {
    $HTMLBody += "<h3>Deletion Information</h3>"
    $HTMLBody += "<p>The stale devices listed above have been deleted from Intune.</p>"
}

# Process device deletion if requested
$deletedDevices = @()
$failedDeletions = @()

if ($DeleteDevices -and $filteredDevices.Count -gt 0) {
    Write-Output "## Device Deletion"

    # Confirm deletion if required
    $proceedWithDeletion = $true
    if ($ConfirmDeletion) {
        $confirmation = Read-Host "Are you sure you want to delete $($filteredDevices.Count) stale devices? (Y/N)"
        if ($confirmation -ne "Y") {
            $proceedWithDeletion = $false
            Write-Output "Deletion cancelled by user."
        }
    }

    if ($proceedWithDeletion) {
        Write-Output "Deleting $($filteredDevices.Count) stale devices..."

        foreach ($device in $filteredDevices) {
            try {
                Write-Output "Deleting device: $($device.deviceName) (ID: $($device.id))"
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($device.id)" -Method DELETE -ErrorAction Stop
                $deletedDevices += $device
                Write-Output "Successfully deleted device: $($device.deviceName)"
            }
            catch {
                Write-Output "Failed to delete device $($device.deviceName): $_"
                Write-RjRbLog -Message "Failed to delete device $($device.deviceName): $_" -Verbose
                $failedDeletions += $device
            }
        }

        # Add deletion results to HTML
        $HTMLBody += "<h3>Deletion Results</h3>"
        $HTMLBody += "<p>Successfully deleted: $($deletedDevices.Count) devices</p>"

        if ($failedDeletions.Count -gt 0) {
            $HTMLBody += "<p>Failed to delete: $($failedDeletions.Count) devices</p>"
            $HTMLBody += "<h4>Failed Deletions</h4>"
            $HTMLBody += "<ul>"
            foreach ($failedDevice in $failedDeletions) {
                $HTMLBody += "<li>$($failedDevice.deviceName) (ID: $($failedDevice.id))</li>"
            }
            $HTMLBody += "</ul>"
        }
    }
    else {
        $HTMLBody += "<p>Device deletion was cancelled.</p>"
    }
}

# Send email
Write-Output "## Preparing email report to send to $sendAlertTo"
$emailSubject = "[Automated Report] Stale Devices"
if ($DeleteDevices) {
    $emailSubject += " - DELETION"
}
$emailSubject += " - $tenantDisplayName - $Days days"

$message = @{
    subject      = $emailSubject
    body         = @{
        contentType = "HTML"
        content     = $HTMLBody
    }
    toRecipients = @(
        @{
            emailAddress = @{
                address = $sendAlertTo
            }
        }
    )
}

Write-Output "Sending report to '$sendAlertTo'..."
try {
    Invoke-RjRbRestMethodGraph -Resource "/users/$sendAlertFrom/sendMail" -Method POST -Body @{ message = $message } -ContentType "application/json" | Out-Null
    Write-Output "Report successfully sent to '$sendAlertTo'."
}
catch {
    Write-Output "Error sending email: $_"
    Write-RjRbLog -Message "Error sending email: $_" -Verbose
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
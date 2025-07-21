<#
  .SYNOPSIS
  Syncs serial numbers from Intune devices to Azure AD device extension attributes.

  .DESCRIPTION
  This runbook retrieves all managed devices from Intune, extracts their serial numbers,
  and updates the corresponding Azure AD device objects' extension attributes.
  This helps maintain consistency between Intune and Azure AD device records.

  .NOTES
  Permissions (Graph):
  - DeviceManagementManagedDevices.Read.All
  - Directory.ReadWrite.All
  - Device.ReadWrite.All

  .PARAMETER ExtensionAttributeName
  The name of the extension attribute to update with the serial number.

  .PARAMETER ProcessAllDevices
  If true, processes all devices. If false, only processes devices with missing or mismatched serial numbers in AAD.

  .PARAMETER MaxDevicesToProcess
  Maximum number of devices to process in a single run. Use 0 for unlimited.

  .PARAMETER sendReportTo
  Email address to send the report to. If empty, no email will be sent.

  .PARAMETER sendReportFrom
  Email address to send the report from.

  .PARAMETER CallerName
  Caller name for auditing purposes.
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [int] $ExtensionAttributeNumber = 1,
    [bool] $ProcessAllDevices = $false,
    [int] $MaxDevicesToProcess = 0,
    [string] $sendReportTo = "",
    [string] $sendReportFrom = "runbook@glueckkanja.com",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

# Validate extension attribute number
if ($ExtensionAttributeNumber -lt 1 -or $ExtensionAttributeNumber -gt 15) {
    Write-Output "Error: ExtensionAttributeNumber must be between 1 and 15."
    exit 1
}

# Define the extension attribute name based on the number
$ExtensionAttributeName = "extensionAttribute$ExtensionAttributeNumber"

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

# Define the properties to select from Intune devices
$intuneSelectString = "deviceName, id, serialNumber, azureADDeviceId"

# Get all managed devices from Intune
Write-Output "## Retrieving managed devices from Intune..."
$intuneDevices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdSelect $intuneSelectString -FollowPaging

Write-Output "Found $($intuneDevices.Count) devices in Intune."
Write-Output ""

# Get all devices from Azure AD
Write-Output "## Retrieving devices from Azure AD..."
$aadDevices = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdSelect "id,displayName,extensionAttributes" -FollowPaging

Write-Output "Found $($aadDevices.Count) devices in Azure AD."
Write-Output ""

# Initialize counters and arrays for reporting
$processedCount = 0
$updatedCount = 0
$skippedCount = 0
$errorCount = 0
$updatedDevices = @()
$skippedDevices = @()
$errorDevices = @()

# Process each Intune device
Write-Output "## Processing devices..."
foreach ($intuneDevice in $intuneDevices) {
    # Check if we've reached the maximum number of devices to process
    if ($MaxDevicesToProcess -gt 0 -and $processedCount -ge $MaxDevicesToProcess) {
        Write-Output "Reached maximum number of devices to process ($MaxDevicesToProcess). Stopping."
        break
    }

    $processedCount++
    
    # Skip devices without a serial number
    if ([string]::IsNullOrEmpty($intuneDevice.serialNumber)) {
        Write-Output "[$($processedCount)/$($intuneDevices.Count)] Device $($intuneDevice.deviceName) (ID: $($intuneDevice.id)) has no serial number. Skipping."
        $skippedDevices += [PSCustomObject]@{
            DeviceName   = $intuneDevice.deviceName
            IntuneID     = $intuneDevice.id
            AzureADID    = ""
            SerialNumber = "N/A"
            Reason       = "No serial number in Intune"
        }
        $skippedCount++
        continue
    }

    # Find the corresponding Azure AD device by display name
    $matchingAadDevice = $aadDevices | Where-Object { $_.displayName -eq $intuneDevice.deviceName } | Select-Object -First 1

    if (-not $matchingAadDevice) {
        Write-Output "[$($processedCount)/$($intuneDevices.Count)] No matching Azure AD device found for $($intuneDevice.deviceName) (ID: $($intuneDevice.id)). Skipping."
        $skippedDevices += [PSCustomObject]@{
            DeviceName   = $intuneDevice.deviceName
            IntuneID     = $intuneDevice.id
            AzureADID    = "N/A"
            SerialNumber = $intuneDevice.serialNumber
            Reason       = "No matching Azure AD device found"
        }
        $skippedCount++
        continue
    }

    # Get the corresponding Azure AD device
    try {
        $aadDevice = $matchingAadDevice
        
        # Check if the extension attribute already exists and has the correct value
        $currentExtensionValue = $null
        if ($aadDevice.extensionAttributes -and $aadDevice.extensionAttributes.$ExtensionAttributeName) {
            $currentExtensionValue = $aadDevice.extensionAttributes.$ExtensionAttributeName
        }

        # If we're only processing devices with missing or mismatched serial numbers and this one matches, skip it
        if (-not $ProcessAllDevices -and $currentExtensionValue -eq $intuneDevice.serialNumber) {
            Write-Output "[$($processedCount)/$($intuneDevices.Count)] Device $($intuneDevice.deviceName) (ID: $($intuneDevice.id)) already has correct serial number in AAD. Skipping."
            $skippedDevices += [PSCustomObject]@{
                DeviceName   = $intuneDevice.deviceName
                IntuneID     = $intuneDevice.id
                AzureADID    = $aadDevice.id
                SerialNumber = $intuneDevice.serialNumber
                Reason       = "Serial number already matches"
            }
            $skippedCount++
            continue
        }

        # Prepare the update body
        $updateBody = @{
            extensionAttributes = @{
                $ExtensionAttributeName = $intuneDevice.serialNumber
            }
        }

        # Try to update the Azure AD device
        try {
            Invoke-RjRbRestMethodGraph -Resource "/devices/$($aadDevice.id)" -Method PATCH -Body $updateBody -ContentType "application/json" | Out-Null
        }
        catch {
            # If we get an authentication error, try to reconnect and retry
            if ($_.Exception.Message -like "*InvalidAuthenticationToken*") {
                Write-Output "Authentication token expired. Reconnecting to Microsoft Graph..."
                Connect-RjRbGraph
                Invoke-RjRbRestMethodGraph -Resource "/devices/$($aadDevice.id)" -Method PATCH -Body $updateBody -ContentType "application/json" | Out-Null
            }
            else {
                throw
            }
        }
        
        Write-Output "[$($processedCount)/$($intuneDevices.Count)] Updated device $($intuneDevice.deviceName) (ID: $($intuneDevice.id)) with serial number $($intuneDevice.serialNumber)"
        $updatedDevices += [PSCustomObject]@{
            DeviceName    = $intuneDevice.deviceName
            IntuneID      = $intuneDevice.id
            AzureADID     = $aadDevice.id
            SerialNumber  = $intuneDevice.serialNumber
            PreviousValue = $currentExtensionValue
        }
        $updatedCount++
    }
    catch {
        Write-Output "[$($processedCount)/$($intuneDevices.Count)] Error processing device $($intuneDevice.deviceName) (ID: $($intuneDevice.id)): $_"
        Write-RjRbLog -Message "Error processing device $($intuneDevice.deviceName) (ID: $($intuneDevice.id)): $_" -Verbose
        $errorDevices += [PSCustomObject]@{
            DeviceName   = $intuneDevice.deviceName
            IntuneID     = $intuneDevice.id
            AzureADID    = $matchingAadDevice ? $matchingAadDevice.id : "N/A"
            SerialNumber = $intuneDevice.serialNumber
            Error        = $_.Exception.Message
        }
        $errorCount++
    }
}

# Display summary
Write-Output ""
Write-Output "## Summary:"
Write-Output "Total devices in Intune: $($intuneDevices.Count)"
Write-Output "Devices processed: $processedCount"
Write-Output "Devices updated: $updatedCount"
Write-Output "Devices skipped: $skippedCount"
Write-Output "Devices with errors: $errorCount"
Write-Output ""

# Send email report if requested
if (-not [string]::IsNullOrEmpty($sendReportTo)) {
    Write-Output "## Preparing email report to send to $sendReportTo"
    
    # Create HTML content for email
    $HTMLBody = "<h2>Device Serial Number Sync Report - $tenantDisplayName</h2>"
    $HTMLBody += "<p>This report shows the results of syncing serial numbers from Intune devices to Azure AD device extension attributes.</p>"
    
    # Add summary section
    $HTMLBody += "<h3>Summary</h3>"
    $HTMLBody += "<ul>"
    $HTMLBody += "<li>Total devices in Intune: $($intuneDevices.Count)</li>"
    $HTMLBody += "<li>Devices processed: $processedCount</li>"
    $HTMLBody += "<li>Devices updated: $updatedCount</li>"
    $HTMLBody += "<li>Devices skipped: $skippedCount</li>"
    $HTMLBody += "<li>Devices with errors: $errorCount</li>"
    $HTMLBody += "</ul>"
    
    # Add updated devices section
    if ($updatedDevices.Count -gt 0) {
        $HTMLBody += "<h3>Updated Devices</h3>"
        $HTMLBody += "<table border='1' style='border-collapse: collapse; width: 100%;'>"
        $HTMLBody += "<tr style='background-color: #f2f2f2;'>"
        $HTMLBody += "<th style='padding: 8px; text-align: left;'>Device Name</th>"
        $HTMLBody += "<th style='padding: 8px; text-align: left;'>Serial Number</th>"
        $HTMLBody += "<th style='padding: 8px; text-align: left;'>Previous Value</th>"
        $HTMLBody += "</tr>"
        
        foreach ($device in $updatedDevices) {
            $HTMLBody += "<tr>"
            $HTMLBody += "<td style='padding: 8px;'>$($device.DeviceName)</td>"
            $HTMLBody += "<td style='padding: 8px;'>$($device.SerialNumber)</td>"
            $HTMLBody += "<td style='padding: 8px;'>$($device.PreviousValue)</td>"
            $HTMLBody += "</tr>"
        }
        
        $HTMLBody += "</table>"
    }
    
    # Add skipped devices section
    if ($skippedDevices.Count -gt 0) {
        $HTMLBody += "<h3>Skipped Devices</h3>"
        $HTMLBody += "<table border='1' style='border-collapse: collapse; width: 100%;'>"
        $HTMLBody += "<tr style='background-color: #f2f2f2;'>"
        $HTMLBody += "<th style='padding: 8px; text-align: left;'>Device Name</th>"
        $HTMLBody += "<th style='padding: 8px; text-align: left;'>Serial Number</th>"
        $HTMLBody += "<th style='padding: 8px; text-align: left;'>Reason</th>"
        $HTMLBody += "</tr>"
        
        foreach ($device in $skippedDevices) {
            $HTMLBody += "<tr>"
            $HTMLBody += "<td style='padding: 8px;'>$($device.DeviceName)</td>"
            $HTMLBody += "<td style='padding: 8px;'>$($device.SerialNumber)</td>"
            $HTMLBody += "<td style='padding: 8px;'>$($device.Reason)</td>"
            $HTMLBody += "</tr>"
        }
        
        $HTMLBody += "</table>"
    }
    
    # Add error devices section
    if ($errorDevices.Count -gt 0) {
        $HTMLBody += "<h3>Devices with Errors</h3>"
        $HTMLBody += "<table border='1' style='border-collapse: collapse; width: 100%;'>"
        $HTMLBody += "<tr style='background-color: #f2f2f2;'>"
        $HTMLBody += "<th style='padding: 8px; text-align: left;'>Device Name</th>"
        $HTMLBody += "<th style='padding: 8px; text-align: left;'>Serial Number</th>"
        $HTMLBody += "<th style='padding: 8px; text-align: left;'>Error</th>"
        $HTMLBody += "</tr>"
        
        foreach ($device in $errorDevices) {
            $HTMLBody += "<tr>"
            $HTMLBody += "<td style='padding: 8px;'>$($device.DeviceName)</td>"
            $HTMLBody += "<td style='padding: 8px;'>$($device.SerialNumber)</td>"
            $HTMLBody += "<td style='padding: 8px;'>$($device.Error)</td>"
            $HTMLBody += "</tr>"
        }
        
        $HTMLBody += "</table>"
    }
    
    # Send email
    $message = @{
        subject      = "[Automated Report] Device Serial Number Sync - $tenantDisplayName"
        body         = @{
            contentType = "HTML"
            content     = $HTMLBody
        }
        toRecipients = @(
            @{
                emailAddress = @{
                    address = $sendReportTo
                }
            }
        )
    }
    
    Write-Output "Sending report to '$sendReportTo'..."
    try {
        Invoke-RjRbRestMethodGraph -Resource "/users/$sendReportFrom/sendMail" -Method POST -Body @{ message = $message } -ContentType "application/json" | Out-Null
        Write-Output "Report successfully sent to '$sendReportTo'."
    }
    catch {
        Write-Output "Error sending email: $_"
        Write-RjRbLog -Message "Error sending email: $_" -Verbose
    }
}

Write-Output "## Operation completed."
<#
  .SYNOPSIS
  Get FileVault recovery key for a macOS device

  .DESCRIPTION
  This runbook retrieves the FileVault recovery key for a specified macOS device from Intune.

  .NOTES
  Permissions (Graph):
  - Device.Read.All
  - DeviceManagementManagedDevices.Read.All

  .PARAMETER DeviceId
  The Azure AD device ID of the macOS device.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
        "DeviceId": {
            "Hide": true
        },
        "CallerName": {
            "Hide": true
        }
    }
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

# Connect to Microsoft Graph
Connect-RjRbGraph -Force

# Get Intune device details directly
try {
    # Get Intune device to get serial number and Intune device ID
    $intuneDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
    
    if ($intuneDevice) {
        Write-Output "## Device Details:"
        Write-Output "- Device Name: $($intuneDevice.deviceName)"
        Write-Output "- Serial Number: $($intuneDevice.serialNumber)"
        $intuneDeviceId = $intuneDevice.id
        
        # Check if it's a macOS device
        if ($intuneDevice.operatingSystem -ne "macOS") {
            Write-Output "## Warning: This device does not appear to be a macOS device (OS: $($intuneDevice.operatingSystem))"
            Write-Output "## FileVault is only available on macOS devices."
        }
    }
    else {
        Write-Output "## Error: Device not found in Intune. FileVault key cannot be retrieved."
        exit
    }
}
catch {
    Write-Output "## Error retrieving device details: $_"
    exit
}

# Get FileVault recovery key for the device
Write-Output ""
Write-Output "## Getting FileVault recovery key for device: $($intuneDevice.deviceName)"

try {
    # Use the Intune device ID to get the FileVault key
    $fileVaultKeyResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$intuneDeviceId/getFileVaultKey" -Method POST -Beta
    
    if ($fileVaultKeyResponse -and $fileVaultKeyResponse.value) {
        Write-Output "## FileVault Recovery Key:"
        Write-Output "- Recovery Key: $($fileVaultKeyResponse.value)"
    }
    else {
        Write-Output "## No FileVault recovery key found for this device."
    }
}
catch {
    $errorResponse = $_
    if ($errorResponse -match '404') {
        Write-Output "## No FileVault recovery key found."
        Write-RjRbLog -Message "## Error: $($errorResponse)" -Verbose
    }
    elseif ($errorResponse -match '403' -or $errorResponse -match 'authorization_error') {
        Write-Output "## Forbidden. Check Graph permissions of automation account."
        Write-Output "## Required permissions: DeviceManagementManagedDevices.Read.All"
        Write-Output "## Note: These permissions must be granted with admin consent."
        Write-Output "## Verify in Azure Portal: Azure Active Directory > App registrations > Your App > API permissions"
        Write-RjRbLog -Message "## Error: $($errorResponse)" -Verbose
    }
    elseif ($errorResponse -match 'The device is not a Mac OS device') {
        Write-Output "## Error: This device is not a macOS device. FileVault is only available on macOS devices."
        Write-RjRbLog -Message "## Error: $($errorResponse)" -Verbose
    }
    else {
        Write-Output "## Error retrieving FileVault recovery key."
        Write-Output "## Error: $($errorResponse)"
    }
}

Write-Output ""
Write-Output "## Troubleshooting Notes:"
Write-Output "1. Ensure the device is a macOS device"
Write-Output "2. Ensure FileVault is enabled on the device"
Write-Output "3. Ensure the device is enrolled in Intune"
Write-Output "4. Ensure the enterprise app has DeviceManagementManagedDevices.Read.All permission"
Write-Output "5. If you're seeing authentication errors, try running the script again"
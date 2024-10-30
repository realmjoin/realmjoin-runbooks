<#
  .SYNOPSIS
  Check if a device is onboarded to Windows Update for Business.

  .DESCRIPTION
  This script checks if single device is onboarded to Windows Update for Business.

  .NOTES
  Permissions (Graph):
  - Device.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementApps.Read.All
  - WindowsUpdates.ReadWrite.All

  .PARAMETER DeviceName
  Device Name of the device to check onboarding status for.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .INPUTS
  DeviceName and CallerName
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [Parameter(Mandatory = $true)]
    [string] $DeviceId
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph -Force

Write-RjRbLog -Message "Checking onboarding status for device: $DeviceId" -Verbose

# Get Device ID from Microsoft Entra based on Device Name
Write-RjRbLog -Message "Fetching Device Details for $DeviceId" -Verbose

# $deviceDetailsUri = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$DeviceName'"
$deviceResponse = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if (-not $deviceResponse) {
    "Device ID: $DeviceId not found in Entra ID."
    throw "DeviceId not found."
}
$deviceName = $deviceResponse.displayName
"Found device '$deviceName' (ID: $DeviceId) in Entra ID."

# Check if device is onboarded
Write-RjRbLog -Message "Checking onboarding status for Device ID: $DeviceId" -Verbose
# $onboardingUri = "https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets/$DeviceId"
try {
    $onboardingResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets/$DeviceId" -Method GET -Beta -ErrorAction SilentlyContinue
    if ($onboardingResponse) {
        $status = "Onboarded"
        $updateCategories = $onboardingResponse.enrollments.updateCategory -join ", "
        $errors = if ($onboardingResponse.errors) { 
                ($onboardingResponse.errors | ForEach-Object { $_.reason }) -join ", "
        }
        else { 
            "None"
        }
        Write-Output "Device '$DeviceName' (ID: $DeviceId) is $status."
        Write-Output "Update Categories: $updateCategories"
        Write-Output "Errors: $errors"
    }
    else {
        Write-Output "Device '$DeviceName' (ID: $DeviceId) is not onboarded."
    }
}
catch {
    $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
    if ($errorResponse.error.code -eq 'NotFound') {
        Write-Output "Device '$DeviceName' (ID: $DeviceId) is not found. (possibly a non-Windows device)."
    }
    else {
        Write-Output "Device '$DeviceName' (ID: $DeviceId) is not onboarded."
        Write-Output "Error: $($errorResponse.error.message)"
    }
}

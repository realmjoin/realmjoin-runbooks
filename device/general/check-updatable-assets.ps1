<#
  .SYNOPSIS
  Check if a device is onboarded to Windows Update for Business.

  .DESCRIPTION
  This script checks if devices are onboarded to Windows Update for Business.

  .NOTES
  Permissions (Graph):
  - Device.Read.All
  - WindowsUpdates.ReadWrite.All

  .PARAMETER DeviceId
  DeviceId of the device to check onboarding status for.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .INPUTS
  DeviceId and CallerName
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [Parameter(Mandatory = $true)]
    [string] $DeviceId
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph -Force

Write-RjRbLog -Message "Checking onboarding status for device: $DeviceId" -Verbose

Write-RjRbLog -Message "Fetching Device Details for $DeviceId" -Verbose

$deviceResponse = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
$deviceName = $deviceResponse.displayName
Write-RjRbLog -Message "Found device '$deviceName' (ID: $DeviceId) in Entra ID." -Verbose

# Check if device is onboarded
Write-Output "Checking onboarding status for '$deviceName' (ID: $DeviceId)."

try {
    $onboardingResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets/$DeviceId" -Method GET -Beta
    Write-RjRbLog -Message "- onboardingResponse: $onboardingResponse" -Verbose
    if ($onboardingResponse) {
        $status = "Onboarded"
        $updateCategories = $onboardingResponse.enrollments.updateCategory -join ", "
        $errors = if ($onboardingResponse.errors) { 
                ($onboardingResponse.errors | ForEach-Object { $_.reason }) -join ", "
        }
        else { 
            "None"
        }
        Write-Output "- Status: $status"
        Write-Output "- Update categories: $updateCategories"
        Write-Output "- Errors: $errors"
    }
    else {
        Write-Output "- Device '$DeviceName' (ID: $DeviceId) is not onboarded."
    }
}
catch {
    $errorResponse = $_
    if ($errorResponse -match '404') {
        Write-Output "- Device is not onboarded / not found (404)."
        Write-RjRbLog -Message "- Error: $($errorResponse)" -Verbose
    }
    else {
        Write-Output "- Device is not onboarded - see details in the following."
        Write-Output "- Error: $($errorResponse)"
    }
}
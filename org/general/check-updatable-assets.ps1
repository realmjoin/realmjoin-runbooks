<#
  .SYNOPSIS
  Check if devices are onboarded to Windows Update for Business.

  .DESCRIPTION
  This script checks if single or multiple devices (by Device Name or Group Object ID) are onboarded to Windows Update for Business.

  .NOTES
  Permissions (Graph):
  - Device.Read.All
  - Group.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementApps.Read.All
  - WindowsUpdates.ReadWrite.All

  .PARAMETER DeviceName
  Device Name of the device to check onboarding status for.

  .PARAMETER GroupObjectId
  Object ID of the group to check onboarding status for its members.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .INPUTS
  DeviceName, GroupObjectId, and CallerName
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $false)]
    [string] $CallerName,
    [Parameter(Mandatory = $false)]
    [string] $DeviceName,
    [Parameter(Mandatory = $false)]
    [string] $GroupObjectId
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph -Force

if ($DeviceName) {
    Write-RjRbLog -Message "Checking onboarding status for device: $DeviceName" -Verbose
    "## Checking onboarding status for device: $DeviceName"

    # Get Device ID from Microsoft Entra based on Device Name
    Write-RjRbLog -Message "Fetching Device Details for $DeviceName" -Verbose

    # $deviceDetailsUri = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$DeviceName'"
    $deviceResponse = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "displayName eq '$DeviceName'" -ErrorAction SilentlyContinue
    $deviceId = $deviceResponse.deviceId
    if ($deviceId) {
        Write-RjRbLog -Message "Device Found! -> Device ID: $deviceId" -Verbose
    } else {
        Write-RjRbLog -Message "Device not found: $DeviceName" -ErrorAction Stop
    }

    # Check if device is onboarded
    Write-RjRbLog -Message "Checking onboarding status for Device ID: $deviceId" -Verbose
    # $onboardingUri = "https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets/$deviceId"
    try {
        $onboardingResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets/$deviceId" -Method GET -Beta -ErrorAction SilentlyContinue
        if ($onboardingResponse) {
            $status = "Onboarded"
            $updateCategories = $onboardingResponse.enrollments.updateCategory -join ", "
            $errors = if ($onboardingResponse.errors) { 
                ($onboardingResponse.errors | ForEach-Object { $_.reason }) -join ", "
            } else { 
                "None"
            }
            Write-Output "Device '$DeviceName' (ID: $deviceId) is $status."
            Write-Output "Update Categories: $updateCategories"
            Write-Output "Errors: $errors"
        } else {
            Write-Output "Device '$DeviceName' (ID: $deviceId) is not onboarded."
        }
    } catch {
        $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
        if ($errorResponse.error.code -eq 'NotFound') {
            Write-Output "Device '$DeviceName' (ID: $deviceId) is not found. (possibly a non-Windows device)."
        } else {
            Write-Output "Device '$DeviceName' (ID: $deviceId) is not onboarded."
            Write-Output "Error: $($errorResponse.error.message)"
        }
    }
} elseif ($GroupObjectId) {
    Write-RjRbLog -Message "Checking onboarding status for group members of Group ID: $GroupObjectId" -Verbose
    "## Checking onboarding status for group members of Group ID: $GroupObjectId"

    # Get Group Members
    Write-RjRbLog -Message "Fetching Group Members for Group ID: $GroupObjectId" -Verbose
    "## Fetching Group Members for Group ID: $GroupObjectId"

    # $groupMembersUri = "https://graph.microsoft.com/v1.0/groups/$GroupObjectId/members"
    $groupMembersResponse = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupObjectId/members" -Method GET
    $deviceObjects = $groupMembersResponse | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' } | Select-Object deviceId, displayName

    foreach ($deviceObject in $deviceObjects) {
        $deviceId = $deviceObject.deviceId
        $deviceName = $deviceObject.displayName

        Write-RjRbLog -Message "Checking onboarding status for Device ID: $deviceId" -Verbose
        "## Checking onboarding status for Device ID: $deviceId"
        # $onboardingUri = "https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets/$deviceId"
        try {
            $onboardingResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets/$deviceId" -Method GET -Beta -ErrorAction SilentlyContinue
            if ($onboardingResponse) {
                $status = "Onboarded"
                $updateCategories = $onboardingResponse.enrollments.updateCategory -join ", "
                $errors = if ($onboardingResponse.errors) { 
                    ($onboardingResponse.errors | ForEach-Object { $_.reason }) -join ", "
                } else { 
                    "None"
                }
                Write-Output "Device '$deviceName' (ID: $deviceId) is $status."
                Write-Output "Update Categories: $updateCategories"
                Write-Output "Errors: $errors"
            } else {
                Write-Output "Device ID: $deviceId is not onboarded."
            }
        } catch {
            $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
            if ($errorResponse.error.code -eq 'NotFound') {
                Write-Output "Device '$deviceName' (ID: $deviceId) not found (possibly a non-Windows device)."
            } else {
                Write-Output "Device '$deviceName' (ID: $deviceId) is not onboarded."
                Write-Output "Error: $($errorResponse.error.message)"
            }
        }
    
    }
} else {
    Write-Output "Please specify either a DeviceName or a GroupObjectId."
}
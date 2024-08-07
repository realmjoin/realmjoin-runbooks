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

    # Get Device ID from Microsoft Entra based on Device Name
    Write-RjRbLog -Message "Fetching Device Details for $DeviceName" -Verbose
    "## Fetching Device Details for $DeviceName"
    $deviceDetailsUri = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$DeviceName'"
    $deviceResponse = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "displayName eq '$DeviceName'"
    $deviceId = $deviceResponse.id
    if ($deviceId) {
        Write-RjRbLog -Message "Device Found! -> Device ID: $deviceId" -Verbose
    } else {
        Write-RjRbLog -Message "Device Not Found: $DeviceName" -ErrorAction Stop
    }

      # Check if device is onboarded
    Write-RjRbLog -Message "Checking onboarding status for Device ID: $deviceId" -Verbose
    "## Checking onboarding status for Device ID: $deviceId"
    $onboardingUri = "https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets"
    try {
        $onboardingResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets" -Method GET -Beta
        $isOnboarded = $onboardingResponse | Where-Object { $_.id -eq $deviceId }
        if ($isOnboarded) {
            Write-Output "Device '$DeviceName' (ID: $deviceId) is onboarded."
        } else {
            Write-Output "Device '$DeviceName' (ID: $deviceId) is not onboarded."
        }
    } catch {
        Write-Output "Device '$DeviceName' (ID: $deviceId) is not onboarded."
    }
} elseif ($GroupObjectId) {
    Write-RjRbLog -Message "Checking onboarding status for group members of Group ID: $GroupObjectId" -Verbose

    # Get Group Members
    Write-RjRbLog -Message "Fetching Group Members for Group ID: $GroupObjectId" -Verbose
    $groupMembersUri = "https://graph.microsoft.com/v1.0/groups/$GroupObjectId/members"
    $groupMembersResponse = Invoke-RjRbRestMethodGraph -Resource $groupMembersUri
    $deviceIds = $groupMembersResponse | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' } | Select-Object -ExpandProperty id

    foreach ($deviceId in $deviceIds) {
        Write-RjRbLog -Message "Checking onboarding status for Device ID: $deviceId" -Verbose
        "## Checking onboarding status for Device ID: $deviceId"
        $onboardingUri = "https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets?`$filter=deviceId eq '$deviceId'"
        try {
            $onboardingResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets" -OdFilter "deviceId eq '$deviceId'" -Method GET -Beta
            if ($onboardingResponse) {
                Write-Output "Device ID: $deviceId is onboarded."
            } else {
                Write-Output "Device ID: $deviceId is not onboarded."
            }
        } catch {
            Write-Output "Device ID: $deviceId is stMethodnot onboarded."
        }
    }
} else {
    Write-Output "Please specify either a DeviceName or a GroupObjectId."
}

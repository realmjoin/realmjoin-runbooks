<#
  .SYNOPSIS
  Enroll devices into Windows Update for Business.

  .DESCRIPTION
  This script enrolls single or multiple devices (by Device Name or Group Object ID) into Windows Update for Business.

  .NOTES
  Permissions (Graph):
  - Device.Read.All
  - Group.Read.All
  - WindowsUpdates.ReadWrite.All

  .PARAMETER DeviceName
  Device Name of the device to enroll.

  .PARAMETER GroupObjectId
  Object ID of the group to enroll its members.

  .PARAMETER UpdateCategory
  Category of updates to enroll for. Possible values are: driver, feature, quality.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .INPUTS
  DeviceName, GroupObjectId, UpdateCategory, and CallerName
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $false)]
    [string] $CallerName,
    [Parameter(Mandatory = $false)]
    [string] $DeviceName,
    [Parameter(Mandatory = $false)]
    [string] $GroupObjectId,
    [Parameter(Mandatory = $true)]
    [ValidateSet("driver", "feature", "quality")]
    [string] $UpdateCategory
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph -Force

function Enroll-Device {
    param (
        [string]$DeviceId,
        [string]$DeviceName,
        [string]$UpdateCategory
    )

    Write-RjRbLog -Message "Enrolling device: $DeviceName (ID: $DeviceId) for $UpdateCategory updates" -Verbose

    $enrollBody = @{
        updateCategory = $UpdateCategory
        assets = @(
            @{
                "@odata.type" = "#microsoft.graph.windowsUpdates.azureADDevice"
                id = $DeviceId
            }
        )
    } | ConvertTo-Json

    try {
        $enrollResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets/enrollAssets" -Method POST -Body $enrollBody -Beta
        Write-Output "Device '$DeviceName' (ID: $DeviceId) successfully enrolled for $UpdateCategory updates."
    }
    catch {
        $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
        Write-Output "Failed to enroll device '$DeviceName' (ID: $DeviceId)."
        Write-Output "Error: $($errorResponse.error.message)"
    }
}

if ($DeviceName) {
    Write-RjRbLog -Message "Enrolling device: $DeviceName" -Verbose
    "## Enrolling device: $DeviceName"

    # Get Device ID from Microsoft Entra based on Device Name
    Write-RjRbLog -Message "Fetching Device Details for $DeviceName" -Verbose

    $deviceResponse = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "displayName eq '$DeviceName'" -ErrorAction SilentlyContinue
    $deviceId = $deviceResponse.deviceId
    if ($deviceId) {
        Write-RjRbLog -Message "Device Found! -> Device ID: $deviceId" -Verbose
        Enroll-Device -DeviceId $deviceId -DeviceName $DeviceName -UpdateCategory $UpdateCategory
    } else {
        Write-RjRbLog -Message "Device not found: $DeviceName" -ErrorAction Stop
    }
} 
elseif ($GroupObjectId) {
    Write-RjRbLog -Message "Enrolling group members of Group ID: $GroupObjectId" -Verbose
    "## Enrolling group members of Group ID: $GroupObjectId"

    # Get Group Members
    Write-RjRbLog -Message "Fetching Group Members for Group ID: $GroupObjectId" -Verbose
    "## Fetching Group Members for Group ID: $GroupObjectId"

    $groupMembersResponse = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupObjectId/members" -Method GET
    $deviceObjects = $groupMembersResponse | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' } | Select-Object deviceId, displayName

    foreach ($deviceObject in $deviceObjects) {
        $deviceId = $deviceObject.deviceId
        $deviceName = $deviceObject.displayName

        Enroll-Device -DeviceId $deviceId -DeviceName $deviceName -UpdateCategory $UpdateCategory
    }
} 
else {
    Write-Output "Please specify either a DeviceName or a GroupObjectId."
}


<#
  .SYNOPSIS
  Unenroll devices from Windows Update for Business.

  .DESCRIPTION
  This script unenrolls single or multiple devices (by Device Name or Group Object ID) from Windows Update for Business.

  .NOTES
  Permissions (Graph):
  - Device.Read.All
  - WindowsUpdates.ReadWrite.All

  .PARAMETER DeviceName
  Device Name of the device to unenroll.

  .PARAMETER UpdateCategory
  Category of updates to unenroll from. Possible values are: driver, feature, quality.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .INPUTS
  DeviceName, UpdateCategory, and CallerName
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [Parameter(Mandatory = $true)]
    [ValidateSet("driver", "feature", "quality")]
    [string] $UpdateCategory
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph -Force

function Unenroll-Device {
    param (
        [string]$DeviceId,
        [string]$DeviceName,
        [string]$UpdateCategory
    )

    Write-RjRbLog -Message "Unenrolling device: $DeviceName (ID: $DeviceId) from $UpdateCategory updates" -Verbose

    $unenrollBody = @{
        updateCategory = $UpdateCategory
        assets         = @(
            @{
                "@odata.type" = "#microsoft.graph.windowsUpdates.azureADDevice"
                id            = $DeviceId
            }
        )
    } 

    try {
        $unenrollResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets/unenrollAssets" -Method POST -Body $unenrollBody -Beta
        Write-Output "Device '$DeviceName' (ID: $DeviceId) successfully unenrolled from $UpdateCategory updates."
    }
    catch {
        $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
        Write-Output "Failed to unenroll device '$DeviceName' (ID: $DeviceId)."
        Write-Output "Error: $($errorResponse.error.message)"
    }
}

Write-RjRbLog -Message "Unenrolling device: $DeviceId" -Verbose
"## Unenrolling device: $DeviceId"

# Get Device ID from Microsoft Entra based on Device Name
Write-RjRbLog -Message "Fetching Device Details for $DeviceId" -Verbose

$deviceResponse = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "displayName eq '$DeviceId'" -ErrorAction SilentlyContinue

if ($deviceResponse) {
    $deviceName = $deviceResponse.displayName
    Write-RjRbLog -Message "Device $deviceName Found!" -Verbose
    Unenroll-Device -DeviceId $DeviceId -DeviceName $DeviceName -UpdateCategory $UpdateCategory
}
else {
    "Device not found: $DeviceId"
    throw "DeviceId $DeviceId not found."
}



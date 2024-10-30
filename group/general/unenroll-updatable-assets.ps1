<#
  .SYNOPSIS
  Unenroll devices from Windows Update for Business.

  .DESCRIPTION
  This script unenrolls single or multiple devices (by Group Object ID) from Windows Update for Business.

  .NOTES
  Permissions (Graph):
  - Device.Read.All
  - Group.Read.All
  - WindowsUpdates.ReadWrite.All

  .PARAMETER GroupId
  Object ID of the group to unenroll its members.

  .PARAMETER UpdateCategory
  Category of updates to unenroll from. Possible values are: driver, feature, quality.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .INPUTS
  GroupId, UpdateCategory, and CallerName
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [Parameter(Mandatory = $true)]
    [string] $GroupId,
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

Write-RjRbLog -Message "Unenrolling group members of Group ID: $GroupId" -Verbose
"## Unenrolling group members of Group ID: $GroupId"

# Get Group Members
Write-RjRbLog -Message "Fetching Group Members for Group ID: $GroupId" -Verbose
"## Fetching Group Members for Group ID: $GroupId"

$groupMembersResponse = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId/members" -Method GET
$deviceObjects = $groupMembersResponse | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' } | Select-Object deviceId, displayName

foreach ($deviceObject in $deviceObjects) {
    $DeviceId = $deviceObject.deviceId
    $deviceName = $deviceObject.displayName

    Unenroll-Device -DeviceId $DeviceId -DeviceName $deviceName -UpdateCategory $UpdateCategory
}


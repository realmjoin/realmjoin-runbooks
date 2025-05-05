<#
  .SYNOPSIS
  Enroll device into Windows Update for Business.

  .DESCRIPTION
  This script enrolls devices into Windows Update for Business.

  .NOTES
  Permissions (Graph):
  - WindowsUpdates.ReadWrite.All

  .PARAMETER DeviceId
  DeviceId of the device to unenroll.

  .PARAMETER UpdateCategory
  Category of updates to enroll into. Possible values are: driver, feature or quality.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .INPUTS
  DeviceId, UpdateCategory, and CallerName
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [Parameter(Mandatory = $true)]
    [ValidateSet("driver", "feature", "quality")]
    [string] $UpdateCategory = "feature"
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph -Force

function Enroll-Device {
    param (
        [string]$DeviceId,
        [string]$UpdateCategory
    )

    Write-Output "Enrolling device with ID $DeviceId into $UpdateCategory updates"

    $enrollBody = @{
        updateCategory = $UpdateCategory
        assets         = @(
            @{
                "@odata.type" = "#microsoft.graph.windowsUpdates.azureADDevice"
                id            = $DeviceId
            }
        )
    }

    try {
        $enrollResponse = $null
        $enrollResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets/enrollAssets" -Method POST -Body $enrollBody -Beta
        Write-Output "- Triggered enroll into updatableAssets for category $UpdateCategory."
        if (!$enrollResponse) {
            Write-Output "- Note: Empty Graph response (normally OK)."
        }
    }
    catch {
        $errorResponse = $_
        Write-Output "- Failed to enroll device."
        Write-Output "- Error: $($errorResponse)"
    }
}

Enroll-Device -DeviceId $DeviceId -UpdateCategory $UpdateCategory
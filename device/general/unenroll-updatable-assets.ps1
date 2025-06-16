<#
  .SYNOPSIS
  Unenroll device from Windows Update for Business.

  .DESCRIPTION
  This script unenrolls devices from Windows Update for Business.

  .PARAMETER DeviceId
  DeviceId of the device to unenroll.

  .PARAMETER UpdateCategory
  Category of updates to unenroll from. Possible values are: driver, feature, quality or all (delete).

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
    [ValidateSet("driver", "feature", "quality", "all")]
    [string] $UpdateCategory = "all"
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph -Force

function Unenroll-Device {
    param (
        [string]$DeviceId,
        [string]$UpdateCategory
    )

    Write-Output "Unenrolling device with ID $DeviceId from $UpdateCategory updates"

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
        $unenrollResponse = $null
        if ($UpdateCategory -eq "all") {
            $unenrollResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets/$DeviceId" -Method DELETE -Beta
            Write-Output "- Triggered unenroll from updatableAssets via deletion."
        }
        else {
            $unenrollResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets/unenrollAssets" -Method POST -Body $unenrollBody -Beta
            Write-Output "- Triggered unenroll from updatableAssets for category $UpdateCategory."
        }
        if (!$unenrollResponse) {
            Write-Output "- Note: Empty Graph response (device probably already offboarded)"
        }
    }
    catch {
        $errorResponse = $_
        Write-Output "- Failed to unenroll device."
        Write-Output "- Error: $($errorResponse)"
    }
}

Unenroll-Device -DeviceId $DeviceId -UpdateCategory $UpdateCategory
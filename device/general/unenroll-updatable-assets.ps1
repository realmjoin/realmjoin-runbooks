<#
    .SYNOPSIS
    Unenroll this device from Windows Update for Business

    .DESCRIPTION
    Removes this device from Windows Update for Business for the chosen update category. Choosing all removes the device as an updatable asset altogether, so Intune no longer manages driver, feature or quality updates for it through the deployment service.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .PARAMETER DeviceId
    Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

    .PARAMETER UpdateCategory
    Update category to unenroll the device from. Choosing all removes the device from Windows Update for Business entirely.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "DeviceId": {
                "Hide": true
            },
            "UpdateCategory": {
                "DisplayName": "Update category"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

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

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph -Force

function Unregister-Device {
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

Unregister-Device -DeviceId $DeviceId -UpdateCategory $UpdateCategory
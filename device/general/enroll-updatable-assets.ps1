<#
    .SYNOPSIS
    Enroll this device in Windows Update for Business

    .DESCRIPTION
    Registers this device as an updatable asset in Windows Update for Business for the chosen update category, so Intune can manage driver, feature or quality updates for it. All enrolls it in driver, feature and quality updates.

    .PARAMETER DeviceId
    Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

    .PARAMETER UpdateCategory
    Update category to enroll the device in. All enrolls it in driver, feature and quality updates.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

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
    [string] $DeviceId,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Driver", "Feature", "Quality", "All")]
    [string] $UpdateCategory = "Feature",
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "DeviceId: $DeviceId" -Verbose
Write-RjRbLog -Message "UpdateCategory: $UpdateCategory" -Verbose

#endregion RJ Log Part

########################################################
#region     Connect Part
########################################################

Connect-RjRbGraph -Force

#endregion Connect Part

########################################################
#region     Main Part
########################################################

function Register-Device {
    param (
        [string]$DeviceId,
        [string]$UpdateCategory
    )

    Write-Output "Enrolling device with ID $DeviceId into $UpdateCategory updates"

    $enrollBody = @{
        updateCategory = $UpdateCategory.ToLower()
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

if ($UpdateCategory -eq "All") {
    foreach ($category in @("Driver", "Feature", "Quality")) {
        Register-Device -DeviceId $DeviceId -UpdateCategory $category
    }
}
else {
    Register-Device -DeviceId $DeviceId -UpdateCategory $UpdateCategory
}

#endregion Main Part

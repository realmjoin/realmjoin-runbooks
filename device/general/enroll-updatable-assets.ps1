<#
    .SYNOPSIS
    Enroll device into Windows Update for Business

    .DESCRIPTION
    This script enrolls a device into Windows Update for Business by registering it as an updatable asset for the specified update category.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .PARAMETER DeviceId
    DeviceId of the device to enroll.

    .PARAMETER UpdateCategory
    Category of updates to enroll into. Possible values are: Driver, Feature, Quality or All. Selecting All will enroll the device into all three categories sequentially.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "DeviceId": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Driver", "Feature", "Quality", "All")]
    [string] $UpdateCategory = "Feature"
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
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

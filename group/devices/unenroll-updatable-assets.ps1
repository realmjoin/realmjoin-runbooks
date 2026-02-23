<#
    .SYNOPSIS
    Unenroll devices from Windows Update for Business.

    .DESCRIPTION
    This runbook unenrolls all device members of a Microsoft Entra ID group from Windows Update for Business updatable assets.
    You can remove a specific update category enrollment or delete the updatable asset registration entirely.
    Use this to offboard devices from WUfB reporting or to reset their enrollment state.

    .PARAMETER GroupId
    Object ID of the group whose device members will be unenrolled.

    .PARAMETER UpdateCategory
    The update category to unenroll from. Supported values are driver, feature, quality, or all.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "GroupId": {
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
    [string] $GroupId,
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
        [string]$DeviceName,
        [string]$UpdateCategory
    )

    Write-Output "Unenrolling device '$DeviceName' (ID: $DeviceId) from $UpdateCategory updates"

    $unenrollBody = @{
        updateCategory = $UpdateCategory
        assets         = @(
            @{
                "@odata.type" = "#microsoft.graph.windowsUpdates.azureADDevice"
                id            = $DeviceId
            }
        )
    }

    if ($UpdateCategory -eq "all") {
        $unenrollResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets/$DeviceId" -Method DELETE -Beta -ErrorAction SilentlyContinue -ErrorVariable errorGraph
        Write-Output "- Triggered unenroll from updatableAssets via deletion."
        if ($errorGraph) {
            Write-Output "- Error: $($errorGraph.message)"
            Write-RjRbLog -Message "- Error: $($errorGraph)" -Verbose
        }
    }
    else {
        $unenrollResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets/unenrollAssets" -Method POST -Body $unenrollBody -Beta -ErrorAction SilentlyContinue -ErrorVariable errorGraph
        Write-Output "- Triggered unenroll from updatableAssets for category $UpdateCategory."
        if ($errorGraph) {
            Write-Output "- Error: $($errorGraph.message)"
            Write-RjRbLog -Message "- Error: $($errorGraph)" -Verbose
        }
        if (!$unenrollResponse) {
            Write-Output "- Note: Empty Graph response (device probably already offboarded)"
        }
    }
}

Write-Output "Unenrolling group members of Group ID: $GroupId"

# Get Group Members
Write-Output "Fetching Group Members for Group ID: $GroupId"

$groupMembersResponse = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId/members" -Method GET
$deviceObjects = $groupMembersResponse | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' } | Select-Object deviceId, displayName

foreach ($deviceObject in $deviceObjects) {
    $DeviceId = $deviceObject.deviceId
    $deviceName = $deviceObject.displayName

    Unenroll-Device -DeviceId $DeviceId -DeviceName $deviceName -UpdateCategory $UpdateCategory
}
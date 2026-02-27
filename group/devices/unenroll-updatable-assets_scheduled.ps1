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

    .PARAMETER IncludeUserOwnedDevices
    When enabled, the runbook also resolves all user members of the group (including nested groups) and unenrolls every device the user is owner of.

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
    [string] $UpdateCategory = "all",

    [Parameter(Mandatory = $false)]
    [bool] $IncludeUserOwnedDevices = $false
)

############################################################
#region RJ Log Part
#
############################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "GroupId: $GroupId" -Verbose
Write-RjRbLog -Message "UpdateCategory: $UpdateCategory" -Verbose
Write-RjRbLog -Message "IncludeUserOwnedDevices: $IncludeUserOwnedDevices" -Verbose

#endregion RJ Log Part

############################################################
#region Connect Part
#
############################################################

Connect-RjRbGraph -Force

#endregion Connect Part

############################################################
#region Function Definitions
#
############################################################

function Get-RjRbGroupTransitiveMembers {
    param(
        [Parameter(Mandatory = $true)]
        [string] $GroupId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $GraphTypeCast,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Select
    )

    $transitiveResource = "/groups/$GroupId/transitiveMembers/$GraphTypeCast"

    try {
        Write-RjRbLog -Message "Fetching group members via transitiveMembers ($GraphTypeCast)." -Verbose
        return Invoke-RjRbRestMethodGraph -Resource $transitiveResource -Method GET -OdSelect $Select -FollowPaging -ErrorAction Stop
    }
    catch {
        Write-RjRbLog -Message "transitiveMembers query failed. Falling back to members endpoint. Error: $_" -Verbose

        $membersResource = "/groups/$GroupId/members"
        $members = Invoke-RjRbRestMethodGraph -Resource $membersResource -Method GET -FollowPaging
        return @($members) | Where-Object { $_.'@odata.type' -eq "#$GraphTypeCast" }
    }
}

function Remove-RjRbUpdatableAssetEnrollment {
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

function Get-RjRbDeviceObjectId {
    param(
        [Parameter(Mandatory = $true)]
        $DeviceObject
    )

    if ($DeviceObject.id) {
        return [string] $DeviceObject.id
    }
    if ($DeviceObject.deviceId) {
        return [string] $DeviceObject.deviceId
    }
    return $null
}

#endregion Function Definitions

############################################################
#region Main Part
#
############################################################

Write-Output "Unenrolling group members of Group ID: $GroupId"

# Get Group Members (Devices)
Write-Output "Fetching device members for Group ID: $GroupId"

$processedDeviceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

$deviceObjects = Get-RjRbGroupTransitiveMembers -GroupId $GroupId -GraphTypeCast "microsoft.graph.device" -Select "id,displayName"
foreach ($deviceObject in @($deviceObjects)) {
    $DeviceId = Get-RjRbDeviceObjectId -DeviceObject $deviceObject
    $deviceName = [string] $deviceObject.displayName

    if (-not $DeviceId) {
        Write-RjRbLog -Message "Skipping device object without id/deviceId." -Verbose
        continue
    }

    if ($processedDeviceIds.Add($DeviceId)) {
        Remove-RjRbUpdatableAssetEnrollment -DeviceId $DeviceId -DeviceName $deviceName -UpdateCategory $UpdateCategory
    }
}

if ($IncludeUserOwnedDevices) {
    # Get Group Members (Users)
    Write-Output "Fetching user members for Group ID: $GroupId"

    $userObjects = Get-RjRbGroupTransitiveMembers -GroupId $GroupId -GraphTypeCast "microsoft.graph.user" -Select "id,displayName,userPrincipalName"

    foreach ($userObject in @($userObjects)) {
        $userId = [string] $userObject.id
        $userDisplay = if ($userObject.userPrincipalName) { [string] $userObject.userPrincipalName } else { [string] $userObject.displayName }

        if (-not $userId) {
            Write-RjRbLog -Message "Skipping user object without id." -Verbose
            continue
        }

        Write-Output "Fetching owned devices for user '$userDisplay' (ID: $userId)"

        $errorGraph = $null
        $ownedDevices = Invoke-RjRbRestMethodGraph -Resource "/users/$userId/ownedDevices/microsoft.graph.device" -Method GET -OdSelect "id,displayName" -FollowPaging -ErrorAction SilentlyContinue -ErrorVariable errorGraph
        if ($errorGraph) {
            Write-Output "- Error fetching ownedDevices for user '$userDisplay'"
            Write-RjRbLog -Message "- Error: $($errorGraph)" -Verbose
            continue
        }

        foreach ($ownedDevice in @($ownedDevices)) {
            $ownedDeviceId = Get-RjRbDeviceObjectId -DeviceObject $ownedDevice
            $ownedDeviceName = [string] $ownedDevice.displayName

            if (-not $ownedDeviceId) {
                Write-RjRbLog -Message "Skipping owned device object without id/deviceId." -Verbose
                continue
            }

            if ($processedDeviceIds.Add($ownedDeviceId)) {
                Remove-RjRbUpdatableAssetEnrollment -DeviceId $ownedDeviceId -DeviceName $ownedDeviceName -UpdateCategory $UpdateCategory
            }
        }
    }
}

#endregion Main Part
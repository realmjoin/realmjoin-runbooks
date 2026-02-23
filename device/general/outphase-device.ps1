<#
    .SYNOPSIS
    Remove/Outphase a windows device

    .DESCRIPTION
    Remove/Outphase a windows device. You can choose if you want to wipe the device and/or delete it from Intune an AutoPilot.

    .PARAMETER DeviceId
    The device ID of the target device.

    .PARAMETER intuneAction
    Determines the Intune action to perform (wipe, delete, or none).

    .PARAMETER aadAction
    Determines the Entra ID (Azure AD) action to perform (delete, disable, or none).

    .PARAMETER wipeDevice
    If set to true, triggers a wipe action in Intune.

    .PARAMETER removeIntuneDevice
    If set to true, deletes the Intune device object.

    .PARAMETER removeAutopilotDevice
    "Delete device from AutoPilot database?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will delete the device from the AutoPilot database, which also allows the device to leave the tenant. If set to false, the device will remain in the AutoPilot database and can be re-assigned to another user/device in the tenant.

    .PARAMETER removeAADDevice
    "Delete device from EntraID?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will delete the device object from Entra ID (Azure AD). If set to false, the device object will remain in Entra ID (Azure AD).

    .PARAMETER disableAADDevice
    "Disable device in EntraID?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will disable the device object in Entra ID (Azure AD). If set to false, the device object will remain enabled in Entra ID (Azure AD).

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
    "Parameters": {
        "DeviceId": {
            "Hide": true
        },
        "intuneAction": {
            "DisplayName": "Wipe this device?",
            "Select": {
                "Options": [
                    {
                        "Display": "Completely wipe device (not keeping user or enrollment data)",
                        "Value": 2
                    },
                    {
                        "Display": "Delete device from Intune (only if device is already wiped or destroyed)",
                        "Value": 1
                    },                    {
                        "Display": "Do not wipe or remove device from Intune",
                        "Value": 0
                    }
                ],
                "ShowValue": false
            }
        },
        "wipeDevice": {
            "Hide":true
        },
        "removeIntuneDevice": {
            "Hide":true
        },
        "removeAutopilotDevice": {
            "DisplayName": "Delete device from AutoPilot database?",
            "SelectSimple": {
                "Remove the device from AutoPilot (the device can leave the tenant)": true,
                "Keep device / do not care": false
            }
        },
        "aadAction": {
            "DisplayName": "Delete device from EntraID?",
            "Select": {
                "Options": [
                    {
                        "Display": "Delete device in EntraID",
                        "Value": 2
                    },
                    {
                        "Display": "Disable device in EntraID",
                        "Value": 1
                    },
                    {
                        "Display": "Do not delete EntraID device / do not care",
                        "Value": 0
                    }
                ],
                "ShowValue": false
            }
        },
        "removeAADDevice": {
            "Hide":true
        },
        "disableAADDevice": {
            "Hide":true
        },
        "CallerName": {
            "Hide": true
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param (
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [int] $intuneAction = 2,
    [int] $aadAction = 2,
    [bool] $wipeDevice = $true,
    [bool] $removeIntuneDevice = $false,
    [bool] $removeAutopilotDevice = $true,
    [bool] $removeAADDevice = $true,
    [bool] $disableAADDevice = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# only modify parameters, if "actions" are set to non-default values
switch ($intuneAction) {
    1 {
        $wipeDevice = $false
        $removeIntuneDevice = $true
    }
    0 {
        $wipeDevice = $false
        $removeIntuneDevice = $false
    }
}
switch ($aadAction) {
    1 {
        $removeAADDevice = $false
        $disableAADDevice = $true
    }
    0 {
        $removeAADDevice = $false
        $disableAADDevice = $false
    }
}

Connect-RjRbGraph

# "Searching DeviceId $DeviceID."
$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if (-not $targetDevice) {
    throw ("DeviceId $DeviceId not found in EntraID.")
}
$owner = Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)/registeredOwners" -ErrorAction SilentlyContinue

"## Outphasing device '$($targetDevice.displayName)' (DeviceId '$DeviceId')"
if ($owner) {
    "## Device owner: '$($owner.UserPrincipalName)'"
}

if ($disableAADDevice) {
    # Currentls MS Graph only allows to update windows devices when used "as App" (vs "delegated").
    if ($targetDevice.operatingSystem -eq "Windows") {
        "## Disabling $($targetDevice.displayName) (Object ID $($targetDevice.id)) in EntraID"
        try {
            $body = @{
                "accountEnabled" = $false
            }
            Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method Patch -Body $body | Out-Null
        }
        catch {
            "## Error Message: $($_.Exception.Message)"
            "## Please see 'All logs' for more details."
            "## Execution stopped."
            throw "Disabling Object ID $($targetDevice.id) in EntraID failed!"
        }
    }
    else {
        "## Disabling non-windows devices in EntraID is currently not supported. Skipping."
    }
}

if ($removeAADDevice) {
    "## Deleting $($targetDevice.displayName) (Object ID $($targetDevice.id)) from EntraID"
    try {
        Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method Delete | Out-Null
    }
    catch {
        "## Error Message: $($_.Exception.Message)"
        "## Please see 'All logs' for more details."
        "## Execution stopped."
        throw "Deleting Object ID $($targetDevice.id) from EntraID failed!"

    }
}

if ((-not $disableAADDevice) -and (-not $removeAADDevice)) {
    "## Skipping EntraID object operations."
}

$mgdDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if ($mgdDevice) {
    if ($wipeDevice) {
        "## Wiping DeviceId $DeviceID (Intune ID: $($mgdDevice.id))"
        $body = @{
            "keepEnrollmentData" = $false
            "keepUserData"       = $false
        }
        try {
            Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($mgdDevice.id)/wipe" -Method Post -Body $body | Out-Null
        }
        catch {
            "## Error Message: $($_.Exception.Message)"
            "## Please see 'All logs' for more details."
            "## Execution stopped."
            throw "Wiping DeviceID $DeviceID (Intune ID: $($mgdDevice.id)) failed!"
        }
    }
    elseif ($removeIntuneDevice) {
        "## Deleting DeviceId $DeviceID (Intune ID: $($mgdDevice.id)) from Intune"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($mgdDevice.id)" -Method Delete | Out-Null
        }
        catch {
            "## Error Message: $($_.Exception.Message)"
            "## Please see 'All logs' for more details."
            "## Execution stopped."
            throw "Deleting Intune ID: $($mgdDevice.id) from Intune failed!"
        }
    }
    else {
        "## Skipping Intune operations."
    }
}
else {
    "## Device not found in Intune. Skipping."
}

if ($removeAutopilotDevice) {
    $apDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -OdFilter "azureActiveDirectoryDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
    if ($apDevice) {
        "## Deleting DeviceId $DeviceID (Autopilot ID: $($apDevice.id)) from Autopilot"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$($apDevice.id)" -Method Delete | Out-Null
        }
        catch {
            "## Error Message: $($_.Exception.Message)"
            "## Please see 'All logs' for more details."
            "## Execution stopped."
            throw "Deleting Autopilot ID: $($apDevice.id) from Autopilot failed!"
        }
    }
    else {
        "## Device not found in AutoPilot database. Skipping."
    }
}
else {
    "## Skipping AutoPilot operations."
}

""
"## Device $($targetDevice.displayName) with DeviceId $DeviceId successfully removed/outphased."
<#
  .SYNOPSIS
  Remove/Outphase a windows device

  .DESCRIPTION
  Remove/Outphase a windows device. You can choose if you want to wipe the device and/or delete it from Intune an AutoPilot.

  .NOTES
  PERMISSIONS
   DeviceManagementManagedDevices.PrivilegedOperations.All (Wipe,Retire / seems to allow us to delete from AzureAD)
   DeviceManagementManagedDevices.ReadWrite.All (Delete Inunte Device)
   DeviceManagementServiceConfig.ReadWrite.All (Delete Autopilot enrollment)

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
        "DeviceId": {
            "Hide": true
        },
        "removeAADDevice": {
            "Hide": true
        },
        "disableAADDevice": {
            "DisplayName": "Disable AzureAD device object?",
            "SelectSimple": {
                "Disable device in AzureAD": true,
                "Do not modify AzureAD device / do not care": false
            }
        },
        "wipeDevice": {
            "DisplayName": "Wipe this device?",
            "Select": {
                "Options": [
                    {
                        "Display": "Completely wipe device (not keeping user or enrollment data)",
                        "Value": true,
                        "Customization": {
                            "Hide": [
                                "removeIntuneDevice"
                            ]
                        }
                    },
                    {
                        "Display": "Do not wipe device",
                        "Value": false
                    }
                ],
                "ShowValue": false
            }
        },
        "removeIntuneDevice": {
            "DisplayName": "Delete device from Intune?",
            "SelectSimple": {
                "Delete device from Intune (only if device is already wiped or destroyed)": true,
                "Do not modify the Intune object / do not care": false
            }
        },
        "removeAutopilotDevice": {
            "DisplayName": "Delete device from AutoPilot database?",
            "SelectSimple": {
                "Remove the device from AutoPilot (the device can leave the tenant)": true,
                "Keep device / do not care": false
            }
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param (
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [bool] $wipeDevice = $true,
    [bool] $removeIntuneDevice = $true,
    [bool] $removeAutopilotDevice = $true,
    [bool] $removeAADDevice = $false,
    [bool] $disableAADDevice = $true

)

Connect-RjRbGraph

# "Searching DeviceId $DeviceID."
$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if (-not $targetDevice) {
    throw ("DeviceId $DeviceId not found in AzureAD.")
} 

if ($disableAADDevice) {
    "## Disabling $($targetDevice.displayName) (Object ID $($targetDevice.id)) in AzureAD"

    try {
        $body = @{
            "accountEnabled" = $false
        }
        Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method Patch -Body $body | Out-Null
    }
    catch {
        throw "Disabling Object ID $($targetDevice.id) in AzureAD failed!"
    }
}

if ($removeAADDevice) {
    "## Deleting $($targetDevice.displayName) (Object ID $($targetDevice.id)) from AzureAD"
    try {
        Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method Delete | Out-Null
    }
    catch {
        throw "Deleting Object ID $($targetDevice.id) from AzureAD failed!"
    }
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
            Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($mgdDevice.id)/wipe" -Method Post -Body $body
        }
        catch {
            throw "Wiping DeviceID $DeviceID (Intune ID: $($mgdDevice.id)) failed!"
        }
    }
    elseif ($removeIntuneDevice) {
        "## Deleting DeviceId $DeviceID (Intune ID: $($mgdDevice.id)) from Intune"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($mgdDevice.id)" -Method Delete | Out-Null
        }
        catch {
            throw "Deleting Intune ID: $($mgdDevice.id) from Intune failed!"
        }
    }
}

if ($removeAutopilotDevice) {
    $apDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -OdFilter "azureActiveDirectoryDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
    if ($apDevice) {
        "## Deleting DeviceId $DeviceID (Autopilot ID: $($apDevice.id)) from Autopilot"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$($apDevice.id)" -Method Delete | Out-Null
        }
        catch {
            throw "Deleting Autopilot ID: $($apDevice.id) from Autopilot failed!"
        }
    }
}

""
"## Device $($targetDevice.displayName) with DeviceId $DeviceId successfully removed/outphased."
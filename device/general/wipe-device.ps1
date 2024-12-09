<#
  .SYNOPSIS
  Wipe a Windows or MacOS device

  .DESCRIPTION
  Wipe a Windows or MacOS device. 

  .NOTES
  PERMISSIONS
   DeviceManagementManagedDevices.PrivilegedOperations.All (Wipe,Retire / seems to allow us to delete from AzureAD)
   DeviceManagementManagedDevices.ReadWrite.All (Delete Inunte Device)
   DeviceManagementServiceConfig.ReadWrite.All (Delete Autopilot enrollment)
   Device.Read.All
  ROLES
   Cloud device administrator

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
                        "Display": "Completely wipe device (Windows: not keeping user or enrollment data)",
                        "Value": true,
                        "Customization": {
                            "Hide": [
                                "removeIntuneDevice"
                            ]
                        }
                    },
                    {
                        "Display": "Do not wipe device",
                        "Value": false,
                        "Customization": {
                            "Hide": [
                                "useProtectedWipe"
                            ]
                        }
                    }
                ],
                "ShowValue": false
            }
        },
        "useProtectedWipe": {
            "DisplayName": "Windows: Use protected wipe?"
        },
        "removeIntuneDevice": {
            "DisplayName": "Delete device from Intune?",
            "SelectSimple": {
                "Delete device from Intune (only if device is already wiped or destroyed)": true,
                "Do not modify the Intune object / do not care": false
            }
        },
        "removeAutopilotDevice": {
            "DisplayName": "Windows: Delete device from AutoPilot database?",
            "SelectSimple": {
                "Remove the device from AutoPilot (the device can leave the tenant)": true,
                "Keep device / do not care": false
            }
        },
        "macOsRecevoryCode": {
            "DisplayName": "MacOS: Recovery Code - not needed for newer devices",
            "Hide": true
        },
        "macOsObliterationBehavior": {
            "DisplayName": "MacOS: OS Obliteration Behavior",
            "SelectSimple": {
                "Default: Try to erase user date (EACS), obliterate OS if this fails": "default",
                "Try to erase user data (EACS), do not obliterate the OS": "doNotObliterate",
                "Try to erase user data (EACS), else warn and obliterate the OS": "obliterateWithWarning",
                "Always obliterate OS": "always"
            }
        },
        "CallerName": {
            "Hide": true
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param (
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [bool] $wipeDevice = $true,
    [bool] $useProtectedWipe = $false,
    [bool] $removeIntuneDevice = $false,
    [bool] $removeAutopilotDevice = $false,
    [bool] $removeAADDevice = $false,
    [bool] $disableAADDevice = $false,
    # Only for old MacOS devices. Newer devices can be wiped without a recovery code.
    [string] $macOsRecevoryCode = "123456",
    # "default": Use EACS to wipe user data, reatining the OS. Will wipe the OS, if EACS fails.
    [string] $macOsObliterationBehavior = "default",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# "Searching DeviceId $DeviceID."
$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if (-not $targetDevice) {
    throw ("DeviceId $DeviceId not found in AzureAD.")
} 
$owner = Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)/registeredOwners" -ErrorAction SilentlyContinue

"## Processing device '$($targetDevice.displayName)' (DeviceId '$DeviceId')"
if ($owner) {
    "## Device owner: '$($owner.UserPrincipalName)'"
}


if ($disableAADDevice) {
    # Currentls MS Graph only allows to update windows devices when used "as App" (vs "delegated").
    if ($targetDevice.operatingSystem -eq "Windows") {
        "## Disabling $($targetDevice.displayName) (Object ID $($targetDevice.id)) in AzureAD"
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
            throw "Disabling Object ID $($targetDevice.id) in AzureAD failed!" 
        }
    }
    else {
        "## Disabling non-windows devices in AzureAD is currently not supported. Skipping."
    }
}

if ($removeAADDevice) {
    "## Deleting $($targetDevice.displayName) (Object ID $($targetDevice.id)) from AzureAD"
    try {
        Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method Delete | Out-Null
    }
    catch {
        "## Error Message: $($_.Exception.Message)"
        "## Please see 'All logs' for more details."
        "## Execution stopped." 
        throw "Deleting Object ID $($targetDevice.id) from AzureAD failed!"
        
    }
}

if ((-not $disableAADDevice) -and (-not $removeAADDevice)) {
    "## Skipping AzureAD object operations."
}

$mgdDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if ($mgdDevice) {
    if ($wipeDevice) {
        "## Wiping DeviceId $DeviceID (Intune ID: $($mgdDevice.id))"
        $body = @{
            "keepEnrollmentData" = "false"
            "keepUserData"       = "false"
        }
        if ($mgdDevice.operatingSystem -eq "macOS") {
            "## MacOS device detected."
            $body["macOsUnlockCode"] = $macOsRecevoryCode
            $body["obliterationBehavior"] = $macOsObliterationBehavior
        }
        if ($mgdDevice.operatingSystem -eq "Windows") {
            "## Windows device detected."
            $body["useProtectedWipe"] = $useProtectedWipe
        }
        try {
            Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($mgdDevice.id)/wipe" -Method Post -Body $body -Beta | Out-Null
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
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
   Device.Read.All
  ROLES
   Cloud device administrator

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
            "DisplayName": "Delete device from AzureAD?",
            "Select": {
                "Options": [
                    {
                        "Display": "Delete device in AzureAD",
                        "Value": 2
                    },
                    {
                        "Display": "Disable device in AzureAD",
                        "Value": 1
                    },
                    {
                        "Display": "Do not delete AzureAD device / do not care",
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.1" }

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
    throw ("DeviceId $DeviceId not found in AzureAD.")
} 
$owner = Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)/registeredOwners" -ErrorAction SilentlyContinue

"## Outphasing device '$($targetDevice.displayName)' (DeviceId '$DeviceId')"
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
    } else {
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
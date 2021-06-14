# This runbook will remove a windows device from Intune, AzureAD and Autopilot.
# This will NOT wipe a device. (although company user data and configs are removed from the client when it checks in.)
# 
# Permissions, Graph, API:
# - DeviceManagementManagedDevices.PrivilegedOperations.All (Wipe,Retire / seems to allow us to delete from AzureAD)
# - DeviceManagementManagedDevices.ReadWrite.All (Delete Inunte Device)
# - DeviceManagementServiceConfig.ReadWrite.All (Delete Autopilot enrollment)

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

param (
    [Parameter(Mandatory = $true)]
    [string] $DeviceId
)

Connect-RjRbGraph

# "Searching DeviceId $DeviceID."
$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if (-not $targetDevice) {
    throw ("DeviceId $DeviceId not found in AzureAD.")
} 

# Remove from AzureAD - we could wipe the device, but we could not continue the process here immediately -> different runbook.
"Deleting $($targetDevice.displayName) (Object ID $($targetDevice.id)) from AzureAD"
try {
    Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method Delete | Out-Null
}
catch {
    throw "Deleting Object ID $($targetDevice.id) from AzureAD failed!"
}

# Remove from Intune
# "Searching DeviceId $DeviceID in Intune."
$mgdDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if ($mgdDevice) {
    "Deleting DeviceId $DeviceID (Intune ID: $($mgdDevice.id)) from Intune"
    try {
        Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($mgdDevice.id)" -Method Delete | Out-Null
    }
    catch {
        throw "Deleting Intune ID: $($mgdDevice.id) from Intune failed!"
    }
}

# Remove from Autopilot
# "Searching DeviceId $DeviceID in Autopilot."
$apDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -OdFilter "azureActiveDirectoryDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if ($apDevice) {
    "Deleting DeviceId $DeviceID (Autopilot ID: $($apDevice.id)) from Autopilot"
    try {
        Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$($apDevice.id)" -Method Delete | Out-Null
    }
    catch {
        throw "Deleting Autopilot ID: $($apDevice.id) from Autopilot failed!"
    }
}

""

"Device $($targetDevice.displayName) with DeviceId $DeviceId successfully removed."
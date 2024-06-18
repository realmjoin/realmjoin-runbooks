<#
  .SYNOPSIS
  Mass-Delete Autopilot objects based on Serial Number.

  .DESCRIPTION
  This runbook deletes Autopilot objects in bulk based on a list of serial numbers.

  .NOTES
  Permissions:
  MS Graph (API)
  - DeviceManagementServiceConfig.ReadWrite.All

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.0" }

param(
    [Parameter(Mandatory = $true)]
    [string] $SerialNumbers
)

# Split the comma-separated serial numbers into an array
$SerialNumberArray = $SerialNumbers -split ","

Connect-RjRbGraph

# Retrieve all Autopilot devices
$autopilotDevices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -ErrorAction SilentlyContinue

if ($autopilotDevices) {
    foreach ($device in $autopilotDevices) {
        if ($SerialNumberArray -contains $device.serialNumber) {
            "Deleting Autopilot device with Serial Number: $($device.serialNumber)"
            $deviceId = $device.id
            try {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$deviceId" -Method DELETE -ErrorAction Stop
                "Deleted Autopilot device with Serial Number: $($device.serialNumber) and Device ID: $deviceId"
            }
            catch {
                "Failed to delete Autopilot device with Serial Number: $($device.serialNumber). Error: $($_.Exception.Message)"
            }
        }
    }
} else {
    "No Autopilot devices found."
}

"Mass deletion of Autopilot objects based on Serial Number is complete."
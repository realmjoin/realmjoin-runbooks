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
    [string[]] $SerialNumbers
)

# Azure Automation does not support string array parameters, split them up
$SerialNumbers = $SerialNumbers -split ","

Connect-RjRbGraph

# Retrieve all Autopilot devices
$autopilotDevices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -ErrorAction SilentlyContinue

if ($autopilotDevices.value) {
    foreach ($device in $autopilotDevices.value) {
        if ($SerialNumbers -contains $device.serialNumber) {
            "Deleting Autopilot device with Serial Number: $($device.serialNumber)"
            $deviceId = $device.id
            try {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$deviceId" -Method DELETE -ErrorAction Stop
                "Deleted Autopilot device with Serial Number: $($device.serialNumber)"
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

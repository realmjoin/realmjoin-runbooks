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

if ($autopilotDevices.value) {
    foreach ($serialNumber in $SerialNumberArray) {
        $device = $autopilotDevices.value | Where-Object { $_.serialNumber -eq $serialNumber }
        if ($device) {
            "Deleting Autopilot device with Serial Number: $($serialNumber)"
            $deviceId = $device.id
            try {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$deviceId" -Method DELETE -ErrorAction Stop
                "Deleted Autopilot device with Serial Number: $($serialNumber) and Device ID: $deviceId"
            }
            catch {
                "Failed to delete Autopilot device with Serial Number: $($serialNumber). Error: $($_.Exception.Message)"
            }
        }
        else {
            "Autopilot device with Serial Number: $($serialNumber) not found."
        }
    }
} else {
    "No Autopilot devices found."
}

"Mass deletion of Autopilot objects based on Serial Number is complete."

# https://gitlab.c4a8.net/modern-workplace-code/RJRunbookBacklog/-/issues/89

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
    [string[]] $SerialNumbers
)

# Azure Automation does not string array parameters, split them up
$SerialNumbers = $SerialNumbers -split ","

Connect-RjRbGraph

# Retrieve all Autopilot devices
$autopilotDevices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -ErrorAction SilentlyContinue

if ($autopilotDevices.value) {
    foreach ($device in $autopilotDevices.value) {
        if ($SerialNumbers -contains $device.serialNumber) {
            "Deleting Autopilot device with Serial Number: $($device.serialNumber)"
            $deviceId = $device.id
            Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$deviceId" -Method DELETE -ErrorAction SilentlyContinue
        }
    }
}

"Mass deletion of Autopilot objects based on Serial Number is complete."

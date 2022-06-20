<#
  .SYNOPSIS
  Assign a new AutoPilot GroupTag to this device.

  .DESCRIPTION
  Assign a new AutoPilot GroupTag to this device.

  .NOTES
  Permissions: 
  MS Graph (API):
  - Device.Read.All
  - DeviceManagementServiceConfig.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
      "DeviceId": {
          "Hide": true
      }
    }
  }
#>

param (
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [Parameter(Mandatory = $true)]
    [string] $newGroupTag
)

Connect-RjRbGraph

$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'"

"## Assigning AutoPilot GroupTag '$newGroupTag' to '$($targetDevice.displayName)'"

$apDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -OdFilter "azureActiveDirectoryDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue

if (-not $apDevice) {
  "## AutoPilot Device for $($targetDevice.displayName) not found. Stopping."
  throw "not found"
}

$body = @{
  groupTag = $newGroupTag
}

Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$($apDevice.id)/UpdateDeviceProperties" -Method Post -Body $body

"## Successfully updated device '$($targetDevice.displayName)'"
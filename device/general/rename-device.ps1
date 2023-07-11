<#
  .SYNOPSIS
  Rename a device.

  .DESCRIPTION
  Rename a device (in Intune and Autopilot).

  .NOTES
  Permissions: 
  MS Graph (API):

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
      "DeviceId": {
          "Hide": true
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
    [Parameter(Mandatory = $true)]
    [string] $NewDeviceName = "",
    [Parameter(Mandatory = $true)]
    [string]$CallerName 
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

"## Getting AzureAD device '$DeviceId'"

$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'"
if (-not $targetDevice) {
    throw ("DeviceId $DeviceId not found in AzureAD.")
}

"## Getting Intune Device for '$($targetDevice.displayName)'"

$intuneDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$DeviceId'" 
if (-not $intuneDevice) {
    "## No Intune device for '$($targetDevice.displayName)' found."
} else {
  $body = @{
    deviceName = $NewDeviceName
  }
  "## Renaming device '$($targetDevice.displayName)' to '$NewDeviceName' in Intune"
  "## This will trigger a local rename of the client."
  Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($intuneDevice.id)/setDeviceName" -Method Post -Body $body -Beta | Out-Null
}

"## Getting AutoPilot device for '$($targetDevice.displayName)'"

$apDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -OdFilter "azureActiveDirectoryDeviceId eq '$DeviceId'" 
if (-not $apDevice) {
  "## No AutoPilot Device for $($targetDevice.displayName) found."
} else {
  $body = @{
    displayName = $NewDeviceName
  }
  "## Renaming device '$($targetDevice.displayName)' to '$NewDeviceName' in AutoPilot"
  Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$($apDevice.id)/updateDeviceProperties" -Method Post -Body $body | Out-Null
}
""
"## Successfully triggered rename of device '$($targetDevice.displayName)' to '$NewDeviceName'."
"## Please check the Intune and AutoPilot portals for the status of the rename operation, as this does not happen immediately."
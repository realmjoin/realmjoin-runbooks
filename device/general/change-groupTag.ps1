<#
  .SYNOPSIS
  Assign a new AutoPilot GroupTag to this device.

  .DESCRIPTION
  This Runbook assigns a new AutoPilot GroupTag to the device. This can be used to trigger a new deployment with different policies and applications for the device.

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
      "DeviceId": {
          "Hide": true
      }
    }
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param (
  [Parameter(Mandatory = $true)]
  [string] $DeviceId,
  [string] $newGroupTag = "",
  [Parameter(Mandatory = $true)]
  [string]$CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

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
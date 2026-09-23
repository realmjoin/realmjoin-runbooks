<#
  .SYNOPSIS
  Assign a new Autopilot group tag to this device

  .DESCRIPTION
  Sets a new Windows Autopilot group tag on this device. The group tag decides which Autopilot profile and, through dynamic groups, which policies and apps the device gets, so changing it prepares the device for a different deployment. Nothing else on the device is changed.

  .PARAMETER DeviceId
  Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

  .PARAMETER newGroupTag
  Group tag that decides which Autopilot profile and dynamic groups the device gets.

  .PARAMETER CallerName
  Name of the user who started the runbook. Set by the portal and recorded for auditing.

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
      "DeviceId": {
          "Hide": true
      },
      "newGroupTag": {
          "DisplayName": "New group tag"
      },
      "CallerName": {
          "Hide": true
      }
    }
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param (
  [Parameter(Mandatory = $true)]
  [string] $DeviceId,
  [string] $newGroupTag = "",
  [Parameter(Mandatory = $true)]
  [string]$CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
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
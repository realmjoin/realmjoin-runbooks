<#
  .SYNOPSIS
  Rename a device.

  .DESCRIPTION
  Rename a device (in Intune and Autopilot).

  .PARAMETER DeviceId
  The device ID of the target device.

  .PARAMETER NewDeviceName
  The new device name to set. This runbook validates the name against common Windows hostname constraints.

  .PARAMETER CallerName
  Caller name for auditing purposes.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param (
  [Parameter(Mandatory = $true)]
  [string] $DeviceId,
  [Parameter(Mandatory = $true)]
  [string] $NewDeviceName = "",
  [Parameter(Mandatory = $true)]
  [string]$CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

# parameter validation
$NewDeviceName = ($NewDeviceName ?? "").Trim()

# Windows hostname / Intune SetDeviceName: assume max 15 chars
if ($NewDeviceName.Length -gt 15) {
  throw "Parameter 'NewDeviceName' must be max. 15 characters (Windows hostname limit). Provided length: $($NewDeviceName.Length)."
}

# Must not contain spaces
if ($NewDeviceName -match '\s') {
  throw "Parameter 'NewDeviceName' must not contain whitespace. Provided value: '$($NewDeviceName)'."
}

# Allowed characters: A-Z, a-z, 0-9, '-' (no leading/trailing '-')
if ($NewDeviceName -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,13}[A-Za-z0-9])?$') {
  throw "Parameter 'NewDeviceName' contains invalid characters. Allowed: letters, digits, hyphen (-); must start/end with alphanumeric; max 15 chars. Provided value: '$($NewDeviceName)'."
}

# Must not be only digits (DNS restriction in AD domains / Intune rule)
if ($NewDeviceName -match '^\d+$') {
  throw "Parameter 'NewDeviceName' must not consist of digits only. Provided value: '$($NewDeviceName)'."
}


Connect-RjRbGraph

[bool]$isRenamed = $false

"## Getting AzureAD device '$DeviceId'"

$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'"
if (-not $targetDevice) {
  throw ("DeviceId $DeviceId not found in AzureAD.")
}

"## Getting Intune Device for '$($targetDevice.displayName)'"

$intuneDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$DeviceId'"
if (-not $intuneDevice) {
  "## No Intune device for '$($targetDevice.displayName)' found."
}
else {
  $body = @{
    deviceName = $NewDeviceName
  }
  "## Renaming device '$($targetDevice.displayName)' to '$NewDeviceName' in Intune"
  "## This will trigger a local rename of the client."
  Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($intuneDevice.id)/setDeviceName" -Method Post -Body $body -Beta | Out-Null
  $isRenamed = $true
}

"## Getting AutoPilot device for '$($targetDevice.displayName)'"

$apDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -OdFilter "azureActiveDirectoryDeviceId eq '$DeviceId'"
if (-not $apDevice) {
  "## No AutoPilot Device for $($targetDevice.displayName) found."
}
else {
  $body = @{
    displayName = $NewDeviceName
  }
  "## Renaming device '$($targetDevice.displayName)' to '$NewDeviceName' in AutoPilot"
  Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$($apDevice.id)/updateDeviceProperties" -Method Post -Body $body | Out-Null
  $isRenamed = $true
}
""
if ($isRenamed) {
  "## Successfully triggered rename of device '$($targetDevice.displayName)' to '$NewDeviceName'."
  "## Please check the Intune and AutoPilot portals for the status of the rename operation, as this does not happen immediately."
}
else {
  "## No rename operation triggered."
}
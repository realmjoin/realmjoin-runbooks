<#
  .SYNOPSIS
  Bulk retire devices from Intune using serial numbers

  .DESCRIPTION
  This runbook retires multiple devices from Intune based on a list of serial numbers.

  .NOTES
  Permissions:
  MS Graph (API):
  - DeviceManagementManagedDevices.ReadWrite.All
  - Device.Read.All

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
      "SerialNumbers": {
        "DisplayName": "List of Serial Numbers (comma-separated)"
      },
      "CallerName": {
        "Hide": true
      }
    }
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }

param(
  [Parameter(Mandatory = $true)]
  [string] $SerialNumbers,
  [Parameter(Mandatory = $true)]
  [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$serialNumberList = $SerialNumbers -split ',' | ForEach-Object { $_.Trim() }

foreach ($serialNumber in $serialNumberList) {
  "## Processing device with serial number: $serialNumber"

  # Find the device in Intune using serial number
  $mgdDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "serialNumber eq '$serialNumber'" -ErrorAction SilentlyContinue

  if ($mgdDevice) {
    "## Retiring device $($mgdDevice.deviceName) (Intune ID: $($mgdDevice.id))"
    try {
      Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($mgdDevice.id)/retire" -Method Post
      "## Successfully retired device $($mgdDevice.deviceName)"
    }
    catch {
      "## Error retiring device $($mgdDevice.deviceName): $($_.Exception.Message)"
    }
  }
  else {
    "## Device not found with serial number: $serialNumber"
  }
}

"## Bulk retire process completed."
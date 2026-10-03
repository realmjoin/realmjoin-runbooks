<#
  .SYNOPSIS
  Retire several Intune devices by serial number

  .DESCRIPTION
  Retires the Intune devices with the given serial numbers. A retire removes company data and management from each device but leaves personal data in place. Serial numbers that are not found are reported and skipped.

  .PARAMETER SerialNumbers
  Serial numbers of the devices to retire, separated by commas.

  .PARAMETER CallerName
  Name of the user who started the runbook. Set by the portal and recorded for auditing.

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
      "SerialNumbers": {
        "DisplayName": "Serial numbers"
      },
      "CallerName": {
        "Hide": true
      }
    }
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
  [Parameter(Mandatory = $true)]
  [string] $SerialNumbers,
  [Parameter(Mandatory = $true)]
  [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
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
<#
  .SYNOPSIS
  Isolate this device.

  .DESCRIPTION
  Isolate this device using Defender for Endpoint.

  .NOTES
  Permissions (WindowsDefenderATP, Application):
  - Machine.Read.All
  - Machine.Isolate

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
      "DeviceId": {
        "Hide": true
      },
      "CallerName": {
        "Hide": true
      },
      "IsolationType": {
        "Hide": true
      },
      "Release": {
        "DisplayName": "Action",
        "SelectSimple": {
          "Isolate Device": false,
          "Release Device from Isolation": true
        }
      },
      "Comment": {
        "DisplayName": "Reason for (Un)Isolation"
      }
    }
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.7.0" }

param(
  [Parameter(Mandatory = $true)]
  [string] $DeviceId,
  [Parameter(Mandatory = $true)]
  [bool] $Release = $false,
  [string] $IsolationType = "Full",
  [Parameter(Mandatory = $true)]
  [string] $Comment = "Possible security risk.",
  # CallerName is tracked purely for auditing purposes
  [Parameter(Mandatory = $true)]
  [string] $CallerName
)

Connect-RjRbDefenderATP

# Find the machine in DefenderATP. From experience - the first result seems to be the "freshest"
$atpDevice = (Invoke-RjRbRestMethodDefenderATP -Resource "/machines" -OdFilter "aadDeviceId eq $DeviceId")[0]
if (-not $atpDevice) {
  "## Device $DeviceId not found in DefenderATP Service. Cannot isolate. "
  throw ("device not found")
}

$body = @{
  Comment = $Comment
}

if ($Release) {
  "## Releasing device $($atpDevice.computerDnsName) (DeviceId $DeviceId) from isolation"
  try {
    $response = Invoke-RjRbRestMethodDefenderATP -Method Post -Resource "/machines/$($atpDevice.id)/unisolate" -Body $body
  }
  catch {
    "## ... failed. Not isolated?"
    ""
    "Error details:"
    $_
    throw "unisolation failed"
  }

  if ($response.type -eq "Unisolate") {
    "## Successfully triggered release of device $($atpDevice.computerDnsName) (DeviceId $DeviceId)"
  }
  else {
    "## Unknown Response from DefenderATP"
    ""
    $response
  }
}
else {
  # Isolate device
  $body += @{   IsolationType = $IsolationType }
  "## Isolating device $($atpDevice.computerDnsName) (DeviceId $DeviceId)"
  try {
    $response = Invoke-RjRbRestMethodDefenderATP -Method Post -Resource "/machines/$($atpDevice.id)/isolate" -Body $body
  }
  catch {
    "## ... failed. Already isolated?"
    ""
    "Error details:"
    $_
    throw "isolation failed"
  }

  if ($response.type -eq "Isolate") {
    "## Successfully triggered isolation of device $($atpDevice.computerDnsName) (DeviceId $DeviceId)"
  }
  else {
    "## Unknown Response from DefenderATP"
    ""
    $response
  }
}


<#
  .SYNOPSIS
  Isolate this device.

  .DESCRIPTION
  This runbook isolates a device in Microsoft Defender for Endpoint to reduce the risk of lateral movement and data exfiltration.
  Optionally, it can release a previously isolated device.
  Provide a short reason so the action is documented in the service.

  .PARAMETER DeviceId
  The device ID of the target device.

  .PARAMETER Release
  "Isolate Device" (final value: false) or "Release Device from Isolation" (final value: true) can be selected as action to perform. If set to false, the runbook will isolate the device in Defender for Endpoint. If set to true, it will release a previously isolated device from isolation in Defender for Endpoint.

  .PARAMETER IsolationType
  The isolation type to use when isolating the device.

  .PARAMETER Comment
  A short reason for the (un)isolation action.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

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

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbDefenderATP

# Find the machine in DefenderATP. From experience - the first result seems to be the "freshest"
$atpDeviceCandidates = Invoke-RjRbRestMethodDefenderATP -Resource "/machines" -OdFilter "aadDeviceId eq $DeviceId"
if (-not $atpDeviceCandidates) {
  "## Device $DeviceId not found in DefenderATP Service. Cannot isolate. "
  throw ("device not found")
}
$atpDevice = $atpDeviceCandidates[0]

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


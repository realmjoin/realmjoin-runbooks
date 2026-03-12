<#
  .SYNOPSIS
  Only allow Microsoft-signed code to run on a device, or remove an existing restriction.

  .DESCRIPTION
  This runbook restricts code execution on a device via Microsoft Defender for Endpoint so that only Microsoft-signed code can run.
  Optionally, it can remove an existing restriction.
  Provide a short reason so the action is documented in the service.

  .PARAMETER DeviceId
  The device ID of the target device.

  .PARAMETER Release
  "Restrict Code Execution" (final value: false) or "Remove Code Restriction" (final value: true) can be selected as action to perform. If set to false, the runbook will restrict code execution on the device in Defender for Endpoint. If set to true, it will remove an existing code execution restriction on the device in Defender for Endpoint.

  .PARAMETER Comment
  A short reason for the (un)restriction action.

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
          "Restrict Code Execution": false,
          "Remove Code Restriction": true
        }
      },
      "Comment": {
        "DisplayName": "Reason for (Un)Restriction"
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
  "## Removing code execution restrictions from device $($atpDevice.computerDnsName) (DeviceId $DeviceId)"
  try {
    $response = Invoke-RjRbRestMethodDefenderATP -Method Post -Resource "/machines/$($atpDevice.id)/unrestrictCodeExecution" -Body $body
  }
  catch {
    "## ... failed. Not restricted?"
    ""
    "Error details:"
    $_
    throw "unrestriction failed"
  }

  if ($response.type -eq "UnrestrictCodeExecution") {
    "## Successfully triggered unrestriction of device $($atpDevice.computerDnsName) (DeviceId $DeviceId)"
  }
  else {
    "## Unknown Response from DefenderATP"
    ""
    $response
  }
}
else {
  "## Restricting code execution on device $($atpDevice.computerDnsName) (DeviceId $DeviceId)"
  try {
    $response = Invoke-RjRbRestMethodDefenderATP -Method Post -Resource "/machines/$($atpDevice.id)/restrictCodeExecution" -Body $body
  }
  catch {
    "## ... failed. Already restricted?"
    ""
    "Error details:"
    $_
    throw "restriction failed"
  }

  if ($response.type -eq "RestrictCodeExecution") {
    "## Successfully triggered restriction of device $($atpDevice.computerDnsName) (DeviceId $DeviceId)"
  }
  else {
    "## Unknown Response from DefenderATP"
    ""
    $response
  }
}


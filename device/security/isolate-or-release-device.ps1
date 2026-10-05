<#
  .SYNOPSIS
  Isolate this device from the network or release it

  .DESCRIPTION
  Isolates this device in Microsoft Defender for Endpoint so that, with full isolation, it can only talk to the Defender service. That limits lateral movement and data theft during an incident. It can also release a previously isolated device. Give a short reason; it is recorded with the action in Defender.

  .PARAMETER DeviceId
  Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

  .PARAMETER Release
  Isolate cuts the device off from the network, with full isolation except for the Defender service. Release restores its normal connectivity.

  .PARAMETER IsolationType
  Full blocks all traffic except to Defender; Selective keeps Outlook, Teams and Skype for Business working. Preset in the runbook customization.

  .PARAMETER Comment
  Short reason for the isolation or release. It is stored with the action in Defender for Endpoint.

  .PARAMETER CallerName
  Name of the user who started the runbook. Set by the portal and recorded for auditing.

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
          "Isolate device": false,
          "Release device from isolation": true
        }
      },
      "Comment": {
        "DisplayName": "Reason"
      }
    }
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

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

$Version = "1.0.1"
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


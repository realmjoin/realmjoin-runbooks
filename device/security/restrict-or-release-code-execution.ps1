<#
  .SYNOPSIS
  Restrict code execution.

  .DESCRIPTION
  Only allow Microsoft signed code to be executed.

  .NOTES
  Permissions (WindowsDefenderATP, Application):
  - Machine.Read.All
  - Machine.RestrictExecution

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.7.0" }

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

Connect-RjRbDefenderATP

# Find the machine in DefenderATP. From experience - the first result seems to be the "freshest"
$atpDevice = (Invoke-RjRbRestMethodDefenderATP -Resource "/machines" -OdFilter "aadDeviceId eq $DeviceId")[0]
if (-not $atpDevice) {
  "## DeviceId $DeviceId not found in DefenderATP Service. Cannot restrict code execution. "
  throw ("device not found")
}

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
  "## Resctricting code execution on device $($atpDevice.computerDnsName) (DeviceId $DeviceId)"
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


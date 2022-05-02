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

# Find the machine in DefenderATP
$atpDevice = Invoke-RjRbRestMethodDefenderATP -Resource "machines" -OdFilter "aadDeviceId eq $DeviceId"
if (-not $atpDevice) {
  "## Device $DeviceId not found in DefenderATP Service. Cannot isolate. "
  throw ("device not found")
}

$body = @{
  Comment = $Comment
}

if ($Release) {
  # Remove App Restriction
  try {
    $response = Invoke-RjRbRestMethodDefenderATP -Method Post -Resource "machines/$($atpDevice.id)/unrestrictCodeExecution" -Body $body
  }
  catch {
    "## Removing code restriction from device $DeviceID failed. Not restricted?"
    ""
    "Error details:"
    $_
    throw "unrestriction failed"
  }

  if ($response.type -eq "UnrestrictCodeExecution") {
    "## Successfully triggered unrestriction of device $DeviceID"
  }
  else {
    "## Unknown Response from DefenderATP"
    ""
    $response
  }
}
else {
  # Restrict Code Execution
  try {
    $response = Invoke-RjRbRestMethodDefenderATP -Method Post -Resource "machines/$($atpDevice.id)/restrictCodeExecution" -Body $body
  }
  catch {
    "## Restricting code execution on device $DeviceID failed. Already restricted?"
    ""
    "Error details:"
    $_
    throw "restriction failed"
  }

  if ($response.type -eq "RestrictCodeExecution") {
    "## Successfully triggered restriction of device $DeviceID"
  }
  else {
    "## Unknown Response from DefenderATP"
    ""
    $response
  }
}


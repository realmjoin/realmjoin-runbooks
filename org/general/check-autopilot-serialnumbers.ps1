<#
  .SYNOPSIS
  Check if given serial numbers are present in AutoPilot.

  .DESCRIPTION
  Check if given serial numbers are present in AutoPilot.

  .NOTES
  Permissions (Graph):
  - DeviceManagementServiceConfig.Read.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Serial Numbers of the Devices, separated by ','" } )]
    [Parameter(Mandatory = $true)]
    [string] $SerialNumbers,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph 

$SerialNumberobject = $SerialNumbers.Split(',')
$presentSerials = @()
$missingSerials = @()
foreach ($SerialNumber in $SerialNumberobject) {
    $SerialNumber = $SerialNumber.TrimStart()
    $autopilotdevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -OdFilter "contains(serialNumber,'$($SerialNumber)')" -ErrorAction SilentlyContinue 
    if ($autopilotdevice) {
        $presentSerials += $autopilotdevice
    }
    else {
        $missingSerials += $SerialNumber
    }
}

"## The following devices are present:"
$autopilotdevice | Select-Object -Property SerialNumber,Manufacturer,Model | Out-String

""
"## The following serial numbers are not present:"
foreach ($missingSerial in $missingSerials) {
    "$missingSerial"
}



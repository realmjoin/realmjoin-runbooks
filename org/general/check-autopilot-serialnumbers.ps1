<#
    .SYNOPSIS
    Check which serial numbers are registered in Autopilot

    .DESCRIPTION
    Checks for a list of serial numbers whether a Windows Autopilot registration exists and reports which were found and which are missing. Nothing is changed.

    .PARAMETER SerialNumbers
    Serial numbers to check, separated by commas.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "SerialNumbers": {
                "DisplayName": "Serial numbers"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [string] $SerialNumbers,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

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
$presentSerials | Select-Object -Property SerialNumber, Manufacturer, Model | Out-String

""
"## The following serial numbers are not present:"
$missingSerials



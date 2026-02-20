<#
    .SYNOPSIS
    Check if given serial numbers are present in Autopilot

    .DESCRIPTION
    This runbook checks whether Windows Autopilot device identities exist for the provided serial numbers.
    It returns the serial numbers found and lists any missing serial numbers.

    .PARAMETER SerialNumbers
    Serial numbers of the devices, separated by commas.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "SerialNumbers": {
                "DisplayName": "Serial numbers of the devices (comma-separated)"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [string] $SerialNumbers,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
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



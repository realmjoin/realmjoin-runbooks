<#
	.SYNOPSIS
	Delete several Autopilot registrations by serial number

	.DESCRIPTION
	Removes the Windows Autopilot registrations of the devices with the given serial numbers, for example before a device is handed to another tenant or disposed of. Serial numbers that are not found are reported and skipped.

	.PARAMETER SerialNumbers
	Serial numbers of the devices to remove, separated by commas.

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
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Split the comma-separated serial numbers into an array and trim whitespace
$SerialNumberArray = $SerialNumbers -split "," | ForEach-Object { $_.Trim() }

Connect-RjRbGraph

foreach ($SerialNumber in $SerialNumberArray) {
    $autopilotdevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -OdFilter "contains(serialNumber,'$SerialNumber')" -ErrorAction SilentlyContinue
    if ($autopilotdevice) {
        "Deleting Autopilot device with Serial Number: $($serialNumber)"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$($autopilotdevice.id)" -Method DELETE -ErrorAction Stop
            "Deleted Autopilot device with Serial Number: $($serialNumber) and Device ID: $($autopilotdevice.id)"
        }
        catch {
            "Failed to delete Autopilot device with Serial Number: $($serialNumber). Error: $($_.Exception.Message)"
        }
    }
    else {
        "# $SerialNumber not found."
    }
}

"Mass deletion of Autopilot objects based on Serial Number is complete."

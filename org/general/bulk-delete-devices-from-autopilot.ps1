<#
	.SYNOPSIS
	Bulk delete Autopilot objects by serial number

	.DESCRIPTION
	This runbook deletes Windows Autopilot device identities based on a comma-separated list of serial numbers.
	It searches for each serial number and deletes the matching Autopilot object if found.

	.PARAMETER SerialNumbers
	Comma-separated list of serial numbers to delete from Autopilot.

	.PARAMETER CallerName
	Caller name for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"SerialNumbers": {
				"DisplayName": "Comma separated serial numbers"
			},
			"CallerName": {
				"Hide": true
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

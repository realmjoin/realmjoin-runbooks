<#
	.SYNOPSIS
	Display macOS FileVault recovery key

	.DESCRIPTION
	Retrieves and displays the FileVault recovery key for a macOS device enrolled in Intune. This key is used to unlock the device if the user forgets their password or the device becomes locked.

	.PARAMETER DeviceId
	The Azure AD Device ID of the macOS device

	.PARAMETER CallerName
	The name of the person running this runbook

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"DeviceId": {
				"Hide": true
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1" }

param(
	[Parameter(Mandatory = $true)]
	[string]$DeviceId,
	# CallerName is tracked purely for auditing purposes
	[Parameter(Mandatory = $true)]
	[string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "DeviceId: $DeviceId" -Verbose
#endregion

########################################################
#region     Connect Part
########################################################
try {
	Write-RjRbLog -Message "Connecting to Microsoft Graph..." -Verbose
	Connect-MgGraph -Identity -NoWelcome
	Write-RjRbLog -Message "Successfully connected to Microsoft Graph" -Verbose
}
catch {
	Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
	throw "Graph connection failed"
}
#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################
Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

# $DeviceId from portal is the Azure AD Device ID (azureADDeviceId in Intune)
# Need to resolve to Intune managed device ID first
try {
	Write-RjRbLog -Message "Looking up Intune managed device for Azure AD Device ID '$DeviceId'..." -Verbose
	$intuneResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$DeviceId'&`$select=id,deviceName,operatingSystem,osVersion,lastSyncDateTime" -Method GET -ErrorAction Stop
	$intuneDevice = $intuneResult.value | Select-Object -First 1

	if (-not $intuneDevice) {
		Write-Error "No Intune managed device found for Azure AD Device ID '$DeviceId'. The device may not be Intune-enrolled." -ErrorAction Continue
		throw "Device '$DeviceId' not found in Intune"
	}

	Write-RjRbLog -Message "Found Intune device: $($intuneDevice.deviceName) (Intune ID: $($intuneDevice.id))" -Verbose

	# Verify it's a macOS device
	if ($intuneDevice.operatingSystem -ne "macOS") {
		Write-Error "Device '$($intuneDevice.deviceName)' is not a macOS device (OS: $($intuneDevice.operatingSystem)). FileVault recovery keys are only available for macOS devices." -ErrorAction Continue
		throw "Device is not macOS"
	}

	Write-Output "Device Name: $($intuneDevice.deviceName)"
	Write-Output "Operating System: $($intuneDevice.operatingSystem) $($intuneDevice.osVersion)"
	Write-Output "Last Sync: $($intuneDevice.lastSyncDateTime)"
}
catch {
	Write-Error "Failed to retrieve device information: $($_.Exception.Message)" -ErrorAction Continue
	throw
}
#endregion

########################################################
#region     Main Part
########################################################
Write-Output ""
Write-Output "Retrieve FileVault Recovery Key"
Write-Output "---------------------"

try {
	Write-RjRbLog -Message "Retrieving FileVault recovery key for Intune device ID: $($intuneDevice.id)..." -Verbose

	# Use beta endpoint as getFileVaultKey is only available in beta
	$fileVaultResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$($intuneDevice.id)')/getFileVaultKey" -Method GET -ErrorAction Stop

	if ($fileVaultResult -and $fileVaultResult.value) {
		Write-Output ""
		Write-Output "FileVault Recovery Key: $($fileVaultResult.value)"
		Write-Output ""
		Write-RjRbLog -Message "Successfully retrieved FileVault recovery key" -Verbose
	}
	else {
		Write-Output ""
		Write-Output "No FileVault recovery key found for this device."
		Write-Output "This may occur if:"
		Write-Output "  - FileVault is not enabled on the device"
		Write-Output "  - The device has not synced the key to Intune yet"
		Write-Output "  - The device does not support FileVault key escrow"
		Write-Output ""
		Write-RjRbLog -Message "No FileVault recovery key available" -Verbose
	}
}
catch {
	if ($_.Exception.Message -like "*403*" -or $_.Exception.Message -like "*Forbidden*") {
		Write-Error "Permission denied. The managed identity requires the 'DeviceManagementManagedDevices.Read.All' or 'DeviceManagementManagedDevices.PrivilegedOperations.All' permission to retrieve FileVault recovery keys." -ErrorAction Continue
	}
	elseif ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
		Write-Error "FileVault recovery key endpoint not found. Ensure the device is properly enrolled and FileVault is enabled." -ErrorAction Continue
	}
	else {
		Write-Error "Failed to retrieve FileVault recovery key: $($_.Exception.Message)" -ErrorAction Continue
	}
	throw
}
#endregion

########################################################
#region     Cleanup
########################################################
try {
	Write-RjRbLog -Message "Disconnecting from Microsoft Graph..." -Verbose
	Disconnect-MgGraph | Out-Null
}
catch {
	Write-Warning "Failed to disconnect from Microsoft Graph: $($_.Exception.Message)"
}

Write-Output ""
Write-Output "Done!"
#endregion

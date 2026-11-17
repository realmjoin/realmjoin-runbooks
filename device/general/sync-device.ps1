<#
	.SYNOPSIS
	Trigger an Intune sync on this device

	.DESCRIPTION
	Asks this device to check in with Intune, so pending policies, apps and configuration are applied without waiting for the next regular check-in. The device name, operating system, primary user and last check-in are shown first. If this device is offline, it syncs when it comes back online. The device must be enrolled in Intune.

	.PARAMETER DeviceId
	Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

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
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }

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

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "DeviceId: $DeviceId" -Verbose

#endregion RJ Log Part

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity of the Automation account is enabled. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw "Connection to Microsoft Graph failed"
}

#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

# The portal passes the Entra device ID. The sync action needs the Intune managed device id, so the device is
# resolved via azureADDeviceId and $DeviceId is never used as a path segment.
$deviceFilter = "azureADDeviceId eq '$DeviceId'"
$lookupUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=$([uri]::EscapeDataString($deviceFilter))&`$select=id,deviceName,operatingSystem,osVersion,userPrincipalName,complianceState,lastSyncDateTime"

try {
    $lookupResponse = Invoke-MgGraphRequest -Method GET -Uri $lookupUri -ErrorAction Stop
}
catch {
    $errorText = "$($_.Exception.Message)"
    if ($errorText -match '403|Forbidden|Authorization_RequestDenied') {
        Write-Error "Access denied while reading this device from Intune. The managed identity of the Automation account needs the application permission DeviceManagementManagedDevices.Read.All. Error: $errorText" -ErrorAction Continue
    }
    else {
        Write-Error "Could not read this device from Intune. Error: $errorText" -ErrorAction Continue
    }
    throw "Intune device lookup failed"
}

$intuneDevices = @($lookupResponse.value)
if ($intuneDevices.Count -eq 0) {
    Write-Error "This device was not found in Intune. Only devices enrolled in Intune can be synced; check the enrollment in the Intune admin center." -ErrorAction Continue
    throw "Device not found in Intune"
}

# A re-enrolled device can leave more than one record behind; the one that synced last is the live one.
$StatusQuo = $intuneDevices | Sort-Object { if ($_.lastSyncDateTime) { [datetime]$_.lastSyncDateTime } else { [datetime]::MinValue } } -Descending | Select-Object -First 1

$CurrentDeviceName = "$($StatusQuo.deviceName)"
$CurrentOsVersion = if ($StatusQuo.osVersion) { "$($StatusQuo.osVersion)" } else { "unknown" }
$CurrentPrimaryUser = if ($StatusQuo.userPrincipalName) { "$($StatusQuo.userPrincipalName)" } else { "(none)" }
$CurrentComplianceState = if ($StatusQuo.complianceState) { "$($StatusQuo.complianceState)" } else { "unknown" }

# Intune reports devices that never checked in with the minimum date.
$CurrentLastSync = "never"
if ($StatusQuo.lastSyncDateTime) {
    $lastSyncUtc = ([datetime]$StatusQuo.lastSyncDateTime).ToUniversalTime()
    if ($lastSyncUtc.Year -gt 1) {
        $CurrentLastSync = "$($lastSyncUtc.ToString('yyyy-MM-dd HH:mm:ss')) UTC"
    }
}

Write-Output "Device name: $CurrentDeviceName"
Write-Output "Operating system: $($StatusQuo.operatingSystem) $CurrentOsVersion"
Write-Output "Primary user: $CurrentPrimaryUser"
Write-Output "Compliance state: $CurrentComplianceState"
Write-Output "Last Intune check-in: $CurrentLastSync"

if ($intuneDevices.Count -gt 1) {
    Write-RjRbLog -Message "WARNING: Intune holds $($intuneDevices.Count) records for this device. The sync request goes to the record that checked in last; remove the stale records in the Intune admin center." -Verbose
}

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Trigger Intune sync"
Write-Output "---------------------"

try {
    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$($StatusQuo.id)/syncDevice" -ErrorAction Stop | Out-Null
}
catch {
    $errorText = "$($_.Exception.Message)"
    if ($errorText -match '403|Forbidden|Authorization_RequestDenied') {
        Write-Error "Access denied while sending the sync request to '$CurrentDeviceName'. The managed identity of the Automation account needs the application permission DeviceManagementManagedDevices.PrivilegedOperations.All. Error: $errorText" -ErrorAction Continue
    }
    else {
        Write-Error "Could not send the sync request to '$CurrentDeviceName'. Error: $errorText" -ErrorAction Continue
    }
    throw "Intune sync request failed"
}

Write-Output "Sync request sent to '$CurrentDeviceName'."
Write-Output "The device checks in with Intune the next time it is online. The last check-in time changes once the check-in has completed."

#endregion Main Part

########################################################
#region     Cleanup
########################################################

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

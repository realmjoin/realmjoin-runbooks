<#
	.SYNOPSIS
	Enable or disable Lost Mode on this supervised iOS or iPadOS device

	.DESCRIPTION
	Locks this supervised iPhone or iPad with Apple Lost Mode, showing a message and callback number on the lock screen, or lifts Lost Mode once the device is back. Optionally the device is asked for its position after it is locked. Only supervised iOS and iPadOS devices are accepted. The command reaches the device with its next check-in; if it is offline, it is locked as soon as it connects again.

	.PARAMETER DeviceId
	Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

	.PARAMETER LostModeAction
	Enable Lost Mode locks the device and shows the lock screen texts. Disable Lost Mode lifts the lock again so the device can be used as usual.

	.PARAMETER Message
	Text shown on the lock screen while the device is locked, for example who the device belongs to. Anyone who finds the device can read it. At least one of "Lock screen message" and "Callback phone number" is needed.

	.PARAMETER PhoneNumber
	Phone number shown on the lock screen. The finder can call it from the locked device without unlocking it. Leave empty to show the message only.

	.PARAMETER Footer
	Additional line at the bottom of the lock screen, for example an asset tag or a reward note. Leave empty for no footer.

	.PARAMETER LocateDevice
	Also asks the locked device for its current position and shows the coordinates when they arrive within a minute. A device that is offline answers later; its position is then shown in the Intune admin center.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"DeviceId": {
				"Hide": true
			},
			"LostModeAction": {
				"DisplayName": "Action",
				"Select": {
					"Options": [
						{
							"Display": "Enable Lost Mode",
							"ParameterValue": "Enable",
							"Customization": {
								"Show": [
									"Message",
									"PhoneNumber",
									"Footer",
									"LocateDevice"
								]
							}
						},
						{
							"Display": "Disable Lost Mode",
							"ParameterValue": "Disable",
							"Customization": {
								"Hide": [
									"Message",
									"PhoneNumber",
									"Footer",
									"LocateDevice"
								]
							}
						}
					],
					"ShowValue": false
				}
			},
			"Message": {
				"DisplayName": "Lock screen message"
			},
			"PhoneNumber": {
				"DisplayName": "Callback phone number"
			},
			"Footer": {
				"DisplayName": "Lock screen footer"
			},
			"LocateDevice": {
				"DisplayName": "Locate the device after locking?",
				"SelectSimple": {
					"Yes, request the current position": true,
					"No": false
				}
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,

    [ValidateSet("Enable", "Disable")]
    [string] $LostModeAction = "Enable",

    [string] $Message = "",

    [string] $PhoneNumber = "",

    [string] $Footer = "",

    [bool] $LocateDevice = $false,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "DeviceId: $DeviceId" -Verbose
Write-RjRbLog -Message "LostModeAction: $LostModeAction" -Verbose
Write-RjRbLog -Message "Message: $Message" -Verbose
Write-RjRbLog -Message "PhoneNumber: $PhoneNumber" -Verbose
Write-RjRbLog -Message "Footer: $Footer" -Verbose
Write-RjRbLog -Message "LocateDevice: $LocateDevice" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

$Message = $Message.Trim()
$PhoneNumber = $PhoneNumber.Trim()
$Footer = $Footer.Trim()

if ($LostModeAction -eq "Enable") {
    # A locked device without any text or number gives the finder nothing to act on.
    if (-not $Message -and -not $PhoneNumber) {
        Write-Error "Enabling Lost Mode needs a lock screen message, a callback phone number or both. Both are empty." -ErrorAction Continue
        throw "Provide a lock screen message or a callback phone number to enable Lost Mode."
    }
}
else {
    if ($Message -or $PhoneNumber -or $Footer) {
        Write-Output "Note: the lock screen texts are only used when Lost Mode is enabled and are ignored for this run."
    }
    if ($LocateDevice) {
        Write-Output "Note: the device is only located after Lost Mode is enabled and is not located in this run."
        $LocateDevice = $false
    }
}

Write-Output "Parameter validation passed."

#endregion Parameter Validation

########################################################
#region     Function Definitions
########################################################

function Get-GraphErrorHint {
    <#
        .SYNOPSIS
        Turns a Graph error into a short hint on the likely cause.

        .PARAMETER ErrorRecord
        The error record thrown by Invoke-MgGraphRequest.

        .PARAMETER Permission
        The application permission the failed call needs, named in the hint for a 403.

        .PARAMETER BadRequestHint
        Hint returned for a 400 instead of the default one, for actions where an unsupported device is not the likely cause.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord,
        [string] $Permission = "",
        [string] $BadRequestHint = ""
    )

    $text = "$($ErrorRecord.Exception.Message)"
    if ($text -match '403|Forbidden|Authorization_RequestDenied') {
        return "Access denied. The managed identity is missing the application permission '$Permission' or admin consent was not granted."
    }
    if ($text -match '401|Unauthorized') {
        return "Authentication to Microsoft Graph failed. Verify that the managed identity of the Automation Account is enabled."
    }
    if ($text -match '404|NotFound|ResourceNotFound') {
        return "The Intune device could not be found. It may have been retired or deleted since the runbook started."
    }
    if ($text -match '400|BadRequest') {
        if ($BadRequestHint) {
            return $BadRequestHint
        }
        return "Intune rejected the action for this device. Lost Mode needs a supervised iOS or iPadOS device that is enrolled in Intune."
    }
    return "Unexpected error: $text"
}

function Get-LatestLocateResult {
    <#
        .SYNOPSIS
        Reads the newest locateDevice action result of an Intune device.

        .DESCRIPTION
        The location is delivered asynchronously: the locateDevice action is queued and the device reports its
        position with its next check-in. Intune keeps the outcome in the deviceActionResults collection of the
        managed device (beta), from which the newest locateDevice entry is returned.

        .PARAMETER ManagedDeviceId
        The Intune managed device id.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string] $ManagedDeviceId
    )

    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$ManagedDeviceId`?`$select=id,deviceActionResults"
    $device = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
    $locateResults = @($device.deviceActionResults | Where-Object { "$($_.actionName)" -eq "locateDevice" })
    if ($locateResults.Count -eq 0) {
        return $null
    }
    return $locateResults | Sort-Object { if ($_.lastUpdatedDateTime) { [datetime]$_.lastUpdatedDateTime } else { [datetime]::MinValue } } -Descending | Select-Object -First 1
}

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

Write-Output ""
Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity is configured correctly. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw "Connection to Microsoft Graph failed"
}
Write-Output "Connected."

#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

# The portal passes the Entra device ID. Intune actions need the managed device id, so the device is resolved
# via azureADDeviceId. Lost Mode state and the action endpoints only exist on the beta endpoint.
$deviceFilter = "azureADDeviceId eq '$DeviceId'"
$lookupUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=$([uri]::EscapeDataString($deviceFilter))"

try {
    $lookupResponse = Invoke-MgGraphRequest -Method GET -Uri $lookupUri -ErrorAction Stop
}
catch {
    $hint = Get-GraphErrorHint -ErrorRecord $_ -Permission "DeviceManagementManagedDevices.Read.All"
    Write-Error "Could not look up the Intune device for Entra device ID '$DeviceId'. $hint" -ErrorAction Continue
    throw "Intune device lookup failed"
}

$intuneDevices = @($lookupResponse.value)
if ($intuneDevices.Count -eq 0) {
    Write-Error "No Intune device found for Entra device ID '$DeviceId'. The device is not enrolled in Intune, so Lost Mode cannot be managed for it." -ErrorAction Continue
    throw "Device '$DeviceId' not found in Intune"
}

# A re-enrolled device can leave more than one record behind; the one that synced last is the live one.
$StatusQuo = $intuneDevices | Sort-Object { if ($_.lastSyncDateTime) { [datetime]$_.lastSyncDateTime } else { [datetime]::MinValue } } -Descending | Select-Object -First 1
$managedDeviceId = "$($StatusQuo.id)"
$CurrentDeviceName = "$($StatusQuo.deviceName)"
$CurrentOperatingSystem = "$($StatusQuo.operatingSystem)"
$CurrentOsVersion = if ($StatusQuo.osVersion) { "$($StatusQuo.osVersion)" } else { "unknown" }
$CurrentSerialNumber = if ($StatusQuo.serialNumber) { "$($StatusQuo.serialNumber)" } else { "unknown" }
$CurrentOwnerType = if ($StatusQuo.managedDeviceOwnerType) { "$($StatusQuo.managedDeviceOwnerType)" } else { "unknown" }
$CurrentIsSupervised = [bool]$StatusQuo.isSupervised
$CurrentLostModeState = if ($StatusQuo.lostModeState) { "$($StatusQuo.lostModeState)" } else { "unknown" }
$CurrentUserPrincipalName = if ($StatusQuo.userPrincipalName) { "$($StatusQuo.userPrincipalName)" } else { "(none)" }
$CurrentLastSyncDateTime = if ($StatusQuo.lastSyncDateTime) { ([datetime]$StatusQuo.lastSyncDateTime).ToString("yyyy-MM-dd HH:mm:ss") } else { "never" }

Write-Output "Device name: $CurrentDeviceName"
Write-Output "Operating system: $CurrentOperatingSystem $CurrentOsVersion"
Write-Output "Serial number: $CurrentSerialNumber"
Write-Output "Ownership: $CurrentOwnerType"
Write-Output "User: $CurrentUserPrincipalName"
Write-Output "Supervised: $(if ($CurrentIsSupervised) { 'Yes' } else { 'No' })"
Write-Output "Current Lost Mode state: $CurrentLostModeState"
Write-Output "Last Intune sync: $CurrentLastSyncDateTime"

Write-Output ""
Write-Output "Preflight-Check"
Write-Output "---------------------"

# Lost Mode is an Apple MDM feature; Intune reports iPhones and iPads as iOS or iPadOS.
if ($CurrentOperatingSystem -notmatch '^(iOS|iPadOS)$') {
    Write-Error "Device '$CurrentDeviceName' runs '$CurrentOperatingSystem'. Lost Mode is only available for iOS and iPadOS devices." -ErrorAction Continue
    throw "Device '$CurrentDeviceName' is not an iOS or iPadOS device"
}
Write-Output "Operating system check passed ($CurrentOperatingSystem)."

# Apple only allows Lost Mode on supervised devices (Automated Device Enrollment or Apple Configurator).
if (-not $CurrentIsSupervised) {
    Write-Error "Device '$CurrentDeviceName' is not supervised. Lost Mode is only available for supervised devices enrolled through Apple Business Manager, Apple School Manager or Apple Configurator." -ErrorAction Continue
    throw "Device '$CurrentDeviceName' is not supervised"
}
Write-Output "Supervision check passed."

Write-Output "Preflight checks passed. Requested action: $LostModeAction Lost Mode."

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

$actionBase = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$managedDeviceId"
$actionSent = $false

if ($LostModeAction -eq "Enable") {
    Write-Output ""
    Write-Output "Enable Lost Mode"
    Write-Output "---------------------"

    if ($CurrentLostModeState -eq "enabled") {
        Write-Output "Lost Mode is already enabled on this device. The request is sent again so the lock screen texts are updated."
    }

    $lostModeBody = @{
        message     = $Message
        phoneNumber = $PhoneNumber
        footer      = $Footer
    }
    Write-RjRbLog -Message "Sending enableLostMode to managed device '$managedDeviceId'." -Verbose

    try {
        Invoke-MgGraphRequest -Method POST -Uri "$actionBase/enableLostMode" -Body ($lostModeBody | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop | Out-Null
        $actionSent = $true
    }
    catch {
        $hint = Get-GraphErrorHint -ErrorRecord $_ -Permission "DeviceManagementManagedDevices.PrivilegedOperations.All"
        Write-Error "Enabling Lost Mode on '$CurrentDeviceName' failed. $hint" -ErrorAction Continue
        throw "Lost Mode could not be enabled on device '$CurrentDeviceName'"
    }

    Write-Output "Lost Mode has been requested for device '$CurrentDeviceName'."
    if ($Message) { Write-Output "Lock screen message: $Message" }
    if ($PhoneNumber) { Write-Output "Callback phone number: $PhoneNumber" }
    if ($Footer) { Write-Output "Lock screen footer: $Footer" }
}
else {
    Write-Output ""
    Write-Output "Disable Lost Mode"
    Write-Output "---------------------"

    if ($CurrentLostModeState -eq "disabled") {
        Write-Output "Intune already reports Lost Mode as disabled. The request is sent anyway, because the reported state can lag behind the device."
    }

    Write-RjRbLog -Message "Sending disableLostMode to managed device '$managedDeviceId'." -Verbose
    try {
        Invoke-MgGraphRequest -Method POST -Uri "$actionBase/disableLostMode" -ErrorAction Stop | Out-Null
        $actionSent = $true
    }
    catch {
        # A rejected request on a device Intune already reports as disabled confirms that Lost Mode is not active.
        if ($CurrentLostModeState -eq "disabled" -and "$($_.Exception.Message)" -match '400|BadRequest') {
            Write-RjRbLog -Message "disableLostMode was rejected: $($_.Exception.Message)" -Verbose
            Write-Output "Intune rejected the request because Lost Mode is not active on this device. Nothing has changed."
        }
        else {
            $hint = Get-GraphErrorHint -ErrorRecord $_ -Permission "DeviceManagementManagedDevices.PrivilegedOperations.All" -BadRequestHint "Intune rejected the request. Lost Mode is most likely not active on this device; check the Lost Mode state in the Intune admin center."
            Write-Error "Disabling Lost Mode on '$CurrentDeviceName' failed. $hint" -ErrorAction Continue
            throw "Lost Mode could not be disabled on device '$CurrentDeviceName'"
        }
    }

    if ($actionSent) {
        Write-Output "Disabling Lost Mode has been requested for device '$CurrentDeviceName'."
    }
}

if ($actionSent) {
    Write-Output ""
    Write-Output "The action is queued in Intune and applied when the device checks in next. A device that is offline picks it up as soon as it connects again; the Lost Mode state in Intune can take a few minutes to update."
}

#endregion Main Part

########################################################
#region     Locate Device (optional)
########################################################

if ($LostModeAction -eq "Enable" -and $LocateDevice) {
    Write-Output ""
    Write-Output "Locate Device"
    Write-Output "---------------------"

    $locateRequested = $false
    Write-RjRbLog -Message "Sending locateDevice to managed device '$managedDeviceId'." -Verbose
    try {
        Invoke-MgGraphRequest -Method POST -Uri "$actionBase/locateDevice" -ErrorAction Stop | Out-Null
        $locateRequested = $true
        Write-Output "Location request sent."
    }
    catch {
        # Lost Mode is already in place at this point, so a failed location request only warns.
        $hint = Get-GraphErrorHint -ErrorRecord $_ -Permission "DeviceManagementManagedDevices.ReadWrite.All"
        Write-Warning "The location request for '$CurrentDeviceName' failed. $hint"
    }

    if ($locateRequested) {
        # The device answers with its next check-in. Poll for about a minute, then leave the result to Intune.
        $pollIntervalSeconds = 10
        $maxPolls = 6
        $locationShown = $false
        $requestTime = (Get-Date).ToUniversalTime()

        for ($poll = 1; $poll -le $maxPolls; $poll++) {
            Start-Sleep -Seconds $pollIntervalSeconds
            try {
                $locateResult = Get-LatestLocateResult -ManagedDeviceId $managedDeviceId
            }
            catch {
                Write-RjRbLog -Message "Reading the location result failed (attempt $poll): $($_.Exception.Message)" -Verbose
                continue
            }
            if (-not $locateResult) { continue }

            $actionState = "$($locateResult.actionState)"
            $location = $locateResult.deviceLocation
            $collectedAt = $null
            if ($location -and $location.lastCollectedDateTime) {
                $collectedAt = ([datetime]$location.lastCollectedDateTime).ToUniversalTime()
            }

            # Only a position collected after this request counts; older entries belong to earlier requests.
            if ($actionState -eq "done" -and $location -and $null -ne $location.latitude -and $collectedAt -and $collectedAt -ge $requestTime.AddMinutes(-5)) {
                $latitude = [double]$location.latitude
                $longitude = [double]$location.longitude
                Write-Output "Position reported by the device:"
                Write-Output "Latitude: $($latitude.ToString([System.Globalization.CultureInfo]::InvariantCulture))"
                Write-Output "Longitude: $($longitude.ToString([System.Globalization.CultureInfo]::InvariantCulture))"
                if ($null -ne $location.horizontalAccuracy) {
                    Write-Output "Horizontal accuracy (m): $([math]::Round([double]$location.horizontalAccuracy, 0))"
                }
                Write-Output "Collected at (UTC): $($collectedAt.ToString('yyyy-MM-dd HH:mm:ss'))"
                Write-Output "Map: https://www.google.com/maps?q=$($latitude.ToString([System.Globalization.CultureInfo]::InvariantCulture)),$($longitude.ToString([System.Globalization.CultureInfo]::InvariantCulture))"
                $locationShown = $true
                break
            }
            if ($actionState -in @("failed", "notSupported")) {
                Write-Warning "The device reported the location request as '$actionState'. Location services may be disabled on the device."
                $locationShown = $true
                break
            }
        }

        if (-not $locationShown) {
            Write-Output "The device has not reported its position yet. It answers with its next check-in; the position is then shown in the Intune admin center under the device's hardware details and in the device action results."
        }
    }
}

#endregion Locate Device (optional)

########################################################
#region     Summary
########################################################

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Device: $CurrentDeviceName ($CurrentOperatingSystem $CurrentOsVersion)"
Write-Output "User: $CurrentUserPrincipalName"
Write-Output "Lost Mode state before: $CurrentLostModeState"
if ($actionSent) {
    Write-Output "Requested state: $(if ($LostModeAction -eq 'Enable') { 'enabled' } else { 'disabled' })"
}
else {
    Write-Output "Requested state: $(if ($LostModeAction -eq 'Enable') { 'enabled' } else { 'disabled' }) (no change needed)"
}

#endregion Summary

########################################################
#region     Cleanup
########################################################

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

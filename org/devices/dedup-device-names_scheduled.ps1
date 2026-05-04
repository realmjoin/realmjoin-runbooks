<#
	.SYNOPSIS
		Detect and rename duplicate Intune device display names using a prefix and random suffix

	.DESCRIPTION
		This scheduled runbook queries all Intune managed devices and identifies devices that share the same display name.
		For each set of duplicates, the most recently enrolled device is renamed to a generated name consisting of a configurable prefix followed by random digits padded to the specified total length, and that name is persisted in the matching Windows Autopilot device object.
		An optional OS filter restricts processing to a specific platform (Windows, macOS, or other); when set to All, devices of every platform are evaluated.

	.NOTES
		Prerequisites:
		- The managed identity must have DeviceManagementManagedDevices.ReadWrite.All and DeviceManagementServiceConfig.ReadWrite.All Graph application permissions assigned.
		- Autopilot display name changes via updateDeviceProperties take effect at the next device sync and may not reflect immediately in the portal.

		Parameter Interactions:
		- NameLength must be strictly greater than the character count of NamePrefix. The difference determines how many random digits are appended (e.g., NamePrefix "CORP" with NameLength 8 produces names like "CORP4271").
		- The runbook validates this constraint at startup and fails fast if violated.

		Common Use Cases:
		- Schedule weekly to automatically resolve duplicate device names that arise from re-enrollment, OS reimaging, or cloning workflows.
		- The idempotent Autopilot sync path ensures that unique devices are also normalized in Autopilot even on the first run.

	.PARAMETER NamePrefix
		The fixed prefix used at the start of every generated device name. All renamed devices will begin with this string.

	.PARAMETER NameLength
		The total character length of the generated device name, including the prefix. Must be greater than the length of NamePrefix so there is room for the random digit suffix.

	.PARAMETER OsFilter
		Restricts which devices are evaluated for duplicate detection and renaming. All includes every platform; Windows and MacOS process only those platforms; Other covers Android, iOS, ChromeOS, and any unrecognized OS. Defaults to All.

	.PARAMETER CallerName
		The identity of the person or automation account that triggered this runbook, used for auditing purposes only.

	.INPUTS
		RunbookCustomization: {
			"Parameters": {
				"NamePrefix": {
					"DisplayName": "Device Name Prefix"
				},
				"NameLength": {
					"DisplayName": "Total Name Length (including prefix)"
				},
				"OsFilter": {
					"DisplayName": "Operating System Filter",
					"Select": {
						"Options": [
							{
								"Display": "All Platforms",
								"ParameterValue": "All",
								"Parameters": {}
							},
							{
								"Display": "Windows only",
								"ParameterValue": "Windows",
								"Parameters": {}
							},
							{
								"Display": "macOS only",
								"ParameterValue": "MacOS",
								"Parameters": {}
							},
							{
								"Display": "Other (Android, iOS, ChromeOS)",
								"ParameterValue": "Other",
								"Parameters": {}
							}
						]
					}
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
    [string]$NamePrefix,

    [Parameter(Mandatory = $true)]
    [int]$NameLength,

    [Parameter(Mandatory = $false)]
    [ValidateSet("All", "Windows", "MacOS", "Other")]
    [string]$OsFilter = "All",

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

function Get-GraphPagedResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )
    $results = @()
    $nextLink = $Uri
    do {
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        if ($response.value) {
            $results += $response.value
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)
    return $results
}

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "NamePrefix: $NamePrefix" -Verbose
Write-RjRbLog -Message "NameLength: $NameLength" -Verbose
Write-RjRbLog -Message "OsFilter: $OsFilter" -Verbose

#endregion

########################################################
#region     Parameter Validation
########################################################

Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

if ($NameLength -le $NamePrefix.Length) {
    Write-Error "NameLength ($NameLength) must be greater than the length of NamePrefix ('$NamePrefix', length $($NamePrefix.Length)). There must be room for at least one random digit suffix character." -ErrorAction Continue
    throw "Invalid parameter: NameLength must be greater than NamePrefix.Length"
}

Write-Output "NamePrefix: '$NamePrefix' (length $($NamePrefix.Length))"
Write-Output "NameLength: $NameLength (suffix digits: $($NameLength - $NamePrefix.Length))"
Write-Output "OsFilter: $OsFilter"
Write-Output "Parameter validation passed."

#endregion

########################################################
#region     Connect Part
########################################################

Write-Output ""
Write-Output "Connect Part"
Write-Output "---------------------"

try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    Write-RjRbLog -Message "Connected to Microsoft Graph via managed identity." -Verbose
}
catch {
    Write-Error "Failed to connect to Microsoft Graph using the managed identity. Ensure that 'Connect-MgGraph -Identity' is supported in this Azure Automation account and that the system-assigned managed identity is enabled. Required Graph application permissions: DeviceManagementManagedDevices.Read.All and DeviceManagementManagedDevices.ReadWrite.All. Error: $_" -ErrorAction Continue
    throw $_
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

try {
    $countResponse = Invoke-MgGraphRequest `
        -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$count=true&`$top=1&`$select=id" `
        -Method GET `
        -Headers @{ "ConsistencyLevel" = "eventual" } `
        -ErrorAction Stop
    $totalDeviceCount = $countResponse."@odata.count"
}
catch {
    Write-Error "Failed to retrieve the managed device count from Intune (GET /deviceManagement/managedDevices). If the error is 403 Forbidden, grant the managed identity the 'DeviceManagementManagedDevices.Read.All' application permission in Entra ID and wait up to 10 minutes for propagation. Error: $_" -ErrorAction Continue
    throw $_
}

Write-RjRbLog -Message "Total managed devices in Intune: $totalDeviceCount" -Verbose
Write-Output "Total managed devices: $totalDeviceCount"

if ($totalDeviceCount -eq 0) {
    Write-Error "No managed devices found in Intune. Nothing to process." -ErrorAction Continue
    throw "Preflight failed: no managed devices found"
}

#endregion

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Main Part"
Write-Output "---------------------"

# Retrieve all managed devices with pagination
Write-Output ""
Write-Output "Retrieving all Intune managed devices..."
Write-Output "---------------------"
Write-RjRbLog -Message "Retrieving all Intune managed devices via pagination." -Verbose

try {
    $allDevices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=id,deviceName,operatingSystem,managedDeviceOwnerType,enrolledDateTime,azureADDeviceId"
    Write-RjRbLog -Message "Retrieved $($allDevices.Count) managed devices." -Verbose
    Write-Output "Retrieved $($allDevices.Count) managed devices."
}
catch {
    Write-Error "Failed to retrieve the full list of Intune managed devices via pagination (GET /deviceManagement/managedDevices). If the error is 403 Forbidden, grant the managed identity the 'DeviceManagementManagedDevices.Read.All' application permission in Entra ID and wait up to 10 minutes for propagation. Error: $_" -ErrorAction Continue
    throw $_
}

# Pre-fetch all Autopilot device identities for in-memory lookup (avoids per-device filter queries that return 500)
Write-Output ""
Write-Output "Retrieving all Windows Autopilot device identities..."
Write-Output "---------------------"
Write-RjRbLog -Message "Retrieving all Windows Autopilot device identities via pagination." -Verbose

$autopilotLookup = @{}
try {
    $allAutopilotDevices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"
    foreach ($ap in $allAutopilotDevices) {
        if ($ap.azureActiveDirectoryDeviceId) {
            $autopilotLookup[$ap.azureActiveDirectoryDeviceId] = $ap
        }
    }
    Write-RjRbLog -Message "Retrieved $($allAutopilotDevices.Count) Autopilot device identities." -Verbose
    Write-Output "Retrieved $($allAutopilotDevices.Count) Autopilot device identities."
}
catch {
    Write-RjRbLog -Message "WARNING: Failed to retrieve Windows Autopilot device identities. Autopilot display name sync will be skipped for this run. Error: $_" -Verbose
    Write-Output "WARNING: Autopilot device retrieval failed — Autopilot sync skipped for this run. Error: $_"
}

# Apply OS filter
$filteredDevices = switch ($OsFilter) {
    'Windows' { $allDevices | Where-Object { $_.operatingSystem -eq 'Windows' } }
    'MacOS'   { $allDevices | Where-Object { $_.operatingSystem -eq 'macOS' } }
    'Other'   { $allDevices | Where-Object { $_.operatingSystem -notin @('Windows', 'macOS') } }
    default   { $allDevices }
}
if ($OsFilter -ne 'All') {
    Write-RjRbLog -Message "Devices after OS filter ($OsFilter): $($filteredDevices.Count) of $($allDevices.Count)." -Verbose
    Write-Output "Devices after OS filter ($OsFilter): $($filteredDevices.Count) of $($allDevices.Count)."
}

# Group devices by deviceName to detect duplicates
$deviceGroups = $filteredDevices | Group-Object -Property deviceName

$renamedCount = 0
$syncedCount = 0

$suffixLength = $NameLength - $NamePrefix.Length
$maxSuffix = [long][Math]::Pow(10, $suffixLength) - 1
$usedNames = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]($allDevices | ForEach-Object { $_.deviceName }),
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($group in $deviceGroups) {
    if ($group.Count -gt 1) {
        # Duplicate group — sort by enrolledDateTime descending, rename the most recently enrolled
        $sortedDevices = $group.Group | Sort-Object -Property enrolledDateTime -Descending
        $deviceToRename = $sortedDevices[0]

        $attempts = 0
        do {
            $randomSuffix = (Get-Random -Minimum 0 -Maximum ($maxSuffix + 1)).ToString().PadLeft($suffixLength, '0')
            $newName = "$NamePrefix$randomSuffix"
            $attempts++
            if ($attempts -gt 100) {
                Write-Error "Could not generate a unique device name after 100 attempts for device '$($deviceToRename.deviceName)' (id: $($deviceToRename.id))." -ErrorAction Continue
                throw "Failed to generate unique name for device $($deviceToRename.id)"
            }
        } while ($usedNames.Contains($newName))
        $usedNames.Add($newName) | Out-Null

        Write-Output "Renaming duplicate device '$($deviceToRename.deviceName)' (id: $($deviceToRename.id)) -> '$newName'"
        Write-RjRbLog -Message "Renaming duplicate device '$($deviceToRename.deviceName)' (id: $($deviceToRename.id)) to '$newName'." -Verbose

        # Rename the Intune managed device (setDeviceName supported on Windows and macOS via beta, corporate-owned only)
        if ($deviceToRename.managedDeviceOwnerType -ne 'company') {
            Write-RjRbLog -Message "Skipping setDeviceName for personal device '$($deviceToRename.deviceName)' (ownership: $($deviceToRename.managedDeviceOwnerType))." -Verbose
            Write-Output "  WARNING: Device '$($deviceToRename.deviceName)' is personally owned — setDeviceName is only supported on corporate-owned devices. Intune rename skipped."
        }
        elseif ($deviceToRename.operatingSystem -in @('Windows', 'macOS')) {
            # Check for an already-pending rename action before queuing another
            $skipRename = $false
            try {
                $actionCheck = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$($deviceToRename.id)?`$select=deviceActionResults" -Method GET -ErrorAction Stop
                $pendingRename = $actionCheck.deviceActionResults | Where-Object { $_.actionName -eq 'setDeviceName' -and $_.actionState -in @('pending', 'active') }
                if ($pendingRename) {
                    $skipRename = $true
                    Write-RjRbLog -Message "Rename action already $($pendingRename.actionState) for '$($deviceToRename.deviceName)' (started: $($pendingRename.startDateTime)). Skipping." -Verbose
                    Write-Output "  INFO: Rename action already $($pendingRename.actionState) for '$($deviceToRename.deviceName)' (queued: $($pendingRename.startDateTime)). Skipping duplicate."
                }
            }
            catch {
                Write-RjRbLog -Message "WARNING: Could not check pending actions for '$($deviceToRename.deviceName)'. Proceeding with rename. Error: $_" -Verbose
            }

            if (-not $skipRename) {
                try {
                    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($deviceToRename.id)/setDeviceName" -Method POST -Body (@{ deviceName = $newName } | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
                    Write-RjRbLog -Message "Intune device rename queued successfully (takes effect at next check-in)." -Verbose
                    Write-Output "  Intune rename queued (takes effect at next device check-in and reboot)."
                }
                catch {
                    Write-Error "Failed to rename Intune managed device '$($deviceToRename.deviceName)' (Intune id: $($deviceToRename.id)) via POST beta/deviceManagement/managedDevices/$($deviceToRename.id)/setDeviceName. If the error is 403 Forbidden, the managed identity requires the 'DeviceManagementManagedDevices.ReadWrite.All' application permission in Entra ID. Note: the rename is applied at next device check-in — it does not take effect immediately. Error: $_" -ErrorAction Continue
                    throw $_
                }
            }
        }
        else {
            Write-RjRbLog -Message "Skipping setDeviceName for unsupported OS device '$($deviceToRename.deviceName)' (OS: $($deviceToRename.operatingSystem))." -Verbose
            Write-Output "  WARNING: Device '$($deviceToRename.deviceName)' is $($deviceToRename.operatingSystem) — setDeviceName not supported on this platform. Intune rename skipped."
        }

        # Persist new name in matching Autopilot device object
        if ($deviceToRename.azureADDeviceId) {
            $autopilotDevice = $autopilotLookup[$deviceToRename.azureADDeviceId]
            if ($autopilotDevice) {
                try {
                    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$($autopilotDevice.id)/updateDeviceProperties" -Method POST -Body (@{ displayName = $newName } | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
                    Write-RjRbLog -Message "Autopilot device display name updated to '$newName'." -Verbose
                    Write-Output "  Autopilot display name updated to '$newName'."
                }
                catch {
                    Write-Error "Failed to update the Windows Autopilot device display name for '$($deviceToRename.deviceName)' (Azure AD Device ID: $($deviceToRename.azureADDeviceId)) via POST /deviceManagement/windowsAutopilotDeviceIdentities/.../updateDeviceProperties. If the error is 403 Forbidden, the managed identity requires the 'DeviceManagementServiceConfig.ReadWrite.All' application permission in Entra ID. Error: $_" -ErrorAction Continue
                    throw $_
                }
            }
            else {
                Write-RjRbLog -Message "No matching Autopilot device found for azureADDeviceId '$($deviceToRename.azureADDeviceId)'. Skipping Autopilot sync." -Verbose
                Write-Output "  WARNING: No Autopilot device found for '$($deviceToRename.deviceName)'. Autopilot sync skipped."
            }
        }

        $renamedCount++
    }
    else {
        # Unique device — persist current name in Autopilot object (idempotent sync)
        $device = $group.Group[0]
        if ($device.azureADDeviceId) {
            $autopilotDevice = $autopilotLookup[$device.azureADDeviceId]
            if ($autopilotDevice -and $autopilotDevice.displayName -ne $device.deviceName) {
                try {
                    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$($autopilotDevice.id)/updateDeviceProperties" -Method POST -Body (@{ displayName = $device.deviceName } | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
                    Write-RjRbLog -Message "Synced Autopilot display name for unique device '$($device.deviceName)'." -Verbose
                    $syncedCount++
                }
                catch {
                    Write-Error "Failed to sync the Windows Autopilot device display name for unique device '$($device.deviceName)' (Azure AD Device ID: $($device.azureADDeviceId)) via POST /deviceManagement/windowsAutopilotDeviceIdentities/.../updateDeviceProperties. If the error is 403 Forbidden, the managed identity requires the 'DeviceManagementServiceConfig.ReadWrite.All' application permission in Entra ID. Error: $_" -ErrorAction Continue
                    throw $_
                }
            }
        }
    }
}

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Devices renamed (duplicate resolution): $renamedCount"
Write-Output "Autopilot display names synced (unique devices): $syncedCount"
Write-RjRbLog -Message "Run complete. Renamed: $renamedCount, Synced: $syncedCount." -Verbose

#endregion

########################################################
#region     Cleanup
########################################################

Write-Output ""
Write-Output "Cleanup"
Write-Output "---------------------"

try {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    Write-RjRbLog -Message "Disconnected from Microsoft Graph." -Verbose
}
catch {
    Write-Warning "Could not cleanly disconnect from Microsoft Graph: $_"
}

Write-Output ""
Write-Output "Done!"

#endregion

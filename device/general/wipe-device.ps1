<#
    .SYNOPSIS
    Wipe this Windows or macOS device and clean up its records

    .DESCRIPTION
    Wipes this Windows or macOS device. Optionally it also cleans up what is left of it: the Intune record, the Autopilot registration and the Entra ID object can be deleted or disabled. For Windows you can choose a protected wipe and a longer compliance grace period after re-enrollment, for macOS a recovery code and how the OS is erased. A wipe removes all data on the device and cannot be undone. The wipe can be skipped when Defender for Endpoint rates the device as medium or high risk.

    .PARAMETER DeviceId
    Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

    .PARAMETER wipeDevice
    Completely wipe erases all user and enrollment data on the device. Do not wipe leaves the device untouched and only runs the selected cleanup steps.

    .PARAMETER useProtectedWipe
    Keeps trying to wipe even if the device is switched off in between, so the wipe cannot be dodged by powering off. Windows only.

    .PARAMETER removeIntuneDevice
    Deletes the device record in Intune. Only sensible when the device is already wiped or destroyed.

    .PARAMETER removeAutopilotDevice
    Removing the device from the Autopilot database lets it leave the tenant and be registered elsewhere. Keeping it allows a later redeployment in this tenant. Windows only.

    .PARAMETER removeAADDevice
    Whether the Entra ID device object is deleted after the wipe. Preset in the runbook customization.

    .PARAMETER disableAADDevice
    Disabling blocks sign-ins from the device but keeps its object in Entra ID. Keep leaves the Entra ID object unchanged.

    .PARAMETER skipWipeIfAtRisk
    Skips the wipe when Microsoft Defender for Endpoint rates the device as medium or high risk. That keeps evidence intact on a device that may be part of a security incident.

    .PARAMETER addToExclusionGroup
    Adds the device to the compliance exclusion group so it gets a longer compliance grace period when it is re-enrolled through Autopilot. Windows only.

    .PARAMETER exclusionGroupName
    Display name of the exclusion group the device is added to. An object ID preset in the runbook customization takes precedence.

    .PARAMETER exclusionGroupId
    Object ID of the exclusion group. Preset in the runbook customization and used instead of the group name to avoid name clashes.

    .PARAMETER macOsRecoveryCode
    Recovery code for older Macs that need one to be wiped. Newer devices ignore it. Preset in the runbook customization.

    .PARAMETER macOsObliterationBehavior
    How a Mac is erased: erase user data first and fall back to erasing the OS, never erase the OS, warn before erasing the OS, or always erase the OS.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "DeviceId": {
                "Hide": true
            },
            "removeAADDevice": {
                "Hide": true
            },
            "disableAADDevice": {
                "DisplayName": "Disable Entra ID device object?",
                "SelectSimple": {
                    "Disable device in Entra ID": true,
                    "Keep the Entra ID device unchanged": false
                }
            },
            "wipeDevice": {
                "DisplayName": "Wipe this device?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Completely wipe device (Windows: not keeping user or enrollment data)",
                            "Value": true,
                            "Customization": {
                                "Hide": [
                                    "removeIntuneDevice"
                                ]
                            }
                        },
                        {
                            "Display": "Do not wipe device",
                            "Value": false,
                            "Customization": {
                                "Hide": [
                                    "useProtectedWipe",
                                    "skipWipeIfAtRisk"
                                ]
                            }
                        }
                    ],
                    "ShowValue": false
                }
            },
            "useProtectedWipe": {
                "DisplayName": "Use protected wipe (Windows)?"
            },
            "skipWipeIfAtRisk": {
                "DisplayName": "Only wipe if the device is not at risk?",
                "SelectSimple": {
                    "Only wipe if the Defender risk score is not medium or high": true,
                    "Wipe regardless of the Defender risk score": false
                }
            },
            "addToExclusionGroup": {
                "DisplayName": "Add to compliance exclusion group (Windows)?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Add device to the compliance exclusion group",
                            "Value": true
                        },
                        {
                            "Display": "Do not add to the exclusion group",
                            "Value": false,
                            "Customization": {
                                "Hide": [
                                    "exclusionGroupName"
                                ]
                            }
                        }
                    ],
                    "ShowValue": false
                }
            },
            "exclusionGroupName": {
                "DisplayName": "Compliance exclusion group name"
            },
            "exclusionGroupId": {
                "DisplayName": "Compliance exclusion group object ID",
                "Hide": true
            },
            "removeIntuneDevice": {
                "DisplayName": "Delete device from Intune?",
                "SelectSimple": {
                    "Delete device from Intune (only if device is already wiped or destroyed)": true,
                    "Keep the Intune record": false
                }
            },
            "removeAutopilotDevice": {
                "DisplayName": "Delete from Autopilot database (Windows)?",
                "SelectSimple": {
                    "Remove from Autopilot (the device can leave the tenant)": true,
                    "Keep the device in Autopilot": false
                }
            },
            "macOsRecoveryCode": {
                "DisplayName": "Recovery code (macOS)",
                "Hide": true
            },
            "macOsObliterationBehavior": {
                "DisplayName": "Obliteration behavior (macOS)",
                "SelectSimple": {
                    "Erase user data (EACS), erase the OS if that fails": "default",
                    "Erase user data (EACS), never erase the OS": "doNotObliterate",
                    "Erase user data (EACS), else warn and erase the OS": "obliterateWithWarning",
                    "Always erase the OS": "always"
                }
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param (
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [bool] $wipeDevice = $true,
    [bool] $useProtectedWipe = $false,
    [bool] $removeIntuneDevice = $false,
    [bool] $removeAutopilotDevice = $false,
    [bool] $removeAADDevice = $false,
    [bool] $disableAADDevice = $false,
    # If true, only wipe the device when its Defender risk score is not Medium or High (protects forensic data of devices involved in a security incident).
    [bool] $skipWipeIfAtRisk = $false,
    # Windows-only. If true, add the device to the compliance exclusion group for a longer grace period after re-enrollment.
    [bool] $addToExclusionGroup = $false,
    # EntraID exclusion group granting a longer compliance grace period to freshly (re)enrolled Autopilot devices.
    [string] $exclusionGroupName = "cfg - Intune - Windows - Compliance for unenrolled Autopilot devices (devices)",
    # Optional. Object ID of the exclusion group. If set, it overrides $exclusionGroupName (avoids name conflicts). Hidden by default; set via Runbook Customization.
    [string] $exclusionGroupId = "",
    # Only for old MacOS devices. Newer devices can be wiped without a recovery code.
    [string] $macOsRecoveryCode = "123456",
    # "default": Use EACS to wipe user data, reatining the OS. Will wipe the OS, if EACS fails.
    [string] $macOsObliterationBehavior = "default",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

############################################################
#region     RJ Log Part
#
############################################################

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "DeviceId: $DeviceId" -Verbose
Write-RjRbLog -Message "wipeDevice: $wipeDevice" -Verbose
Write-RjRbLog -Message "useProtectedWipe: $useProtectedWipe" -Verbose
Write-RjRbLog -Message "removeIntuneDevice: $removeIntuneDevice" -Verbose
Write-RjRbLog -Message "removeAutopilotDevice: $removeAutopilotDevice" -Verbose
Write-RjRbLog -Message "removeAADDevice: $removeAADDevice" -Verbose
Write-RjRbLog -Message "disableAADDevice: $disableAADDevice" -Verbose
Write-RjRbLog -Message "skipWipeIfAtRisk: $skipWipeIfAtRisk" -Verbose
Write-RjRbLog -Message "addToExclusionGroup: $addToExclusionGroup" -Verbose
Write-RjRbLog -Message "exclusionGroupName: $exclusionGroupName" -Verbose
Write-RjRbLog -Message "exclusionGroupId: $exclusionGroupId" -Verbose
Write-RjRbLog -Message "macOsObliterationBehavior: $macOsObliterationBehavior" -Verbose

#endregion RJ Log Part

############################################################
#region     Connect Part
#
############################################################

Connect-RjRbGraph

# Defender for Endpoint is only required when the risk-based wipe protection is enabled.
if ($wipeDevice -and $skipWipeIfAtRisk) {
    Connect-RjRbDefenderATP
}

#endregion Connect Part

############################################################
#region     Defender Risk Preflight (runs first, may abort)
#
############################################################

# Evaluate the device's Defender for Endpoint risk score before doing anything else.
# If the device is at risk (Medium/High), abort immediately to protect forensic data
# (e.g. logs) of a device that may be involved in a security incident.
if ($wipeDevice -and $skipWipeIfAtRisk) {
    "## 'Skip wipe if at risk' is enabled. Checking Microsoft Defender for Endpoint risk score..."
    try {
        # From experience the first result seems to be the "freshest" candidate.
        $atpDevice = Invoke-RjRbRestMethodDefenderATP -Resource "/machines" -OdFilter "aadDeviceId eq $DeviceId" -ErrorAction Stop |
            Sort-Object { [datetime]$_.lastSeen } -Descending |
            Select-Object -First 1
    }
    catch {
        "## Error Message: $($_.Exception.Message)"
        "## Please see 'All logs' for more details."
        "## Execution stopped."
        throw "Could not determine the device's Defender risk score. Aborting to avoid wiping a potentially at-risk device."
    }

    if ($atpDevice) {
        "## Defender risk score: '$($atpDevice.riskScore)'"
        if ($atpDevice.riskScore -in @('Medium', 'High')) {
            ""
            "!!!!! Warning !!!!!"
            "Defender risk score of this device is '$($atpDevice.riskScore)'."
            "The device may be involved in a security incident. Wiping it now could destroy forensic data (e.g. logs)."
            "Please align with your security team before wiping this device."
            "To wipe it anyway, disable 'Only wipe if device is not at risk' and re-run this runbook."
            "!!!!!!!!!!!!!!!!!!!!!!!!!!"
            ""
            throw "Execution stopped: Defender risk score is '$($atpDevice.riskScore)'. Wipe cancelled to protect forensic data. Align with security or disable 'Only wipe if device is not at risk'."
        }
    }
    else {
        "## Device not found in Defender for Endpoint. Risk score could not be determined; proceeding with wipe."
    }
}

#endregion Defender Risk Preflight

############################################################
#region     StatusQuo & Preflight-Check Part
#
############################################################

    #region Resolve Target Device
    ##############################

    # "Searching DeviceId $DeviceID."
    $targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
    if (-not $targetDevice) {
        throw ("DeviceId $DeviceId not found in AzureAD.")
    }
    $owner = Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)/registeredOwners" -ErrorAction SilentlyContinue

    "## Processing device '$($targetDevice.displayName)' (DeviceId '$DeviceId')"
    if ($owner) {
        "## Device owner: '$($owner.UserPrincipalName)'"
    }

    #endregion Resolve Target Device

    #region Exclusion Group Preflight
    ##############################

    # Resolve the exclusion group upfront so the runbook fails BEFORE any destructive action
    # (wipe / delete / disable) if the group is missing. This avoids leaving the device in a
    # "half-baked" state (e.g. wiped but never added to the compliance exclusion group).
    $exclusionGroup = $null
    if ($addToExclusionGroup) {
        if ($targetDevice.operatingSystem -ne "Windows") {
            "## The compliance exclusion group is intended for Windows devices only. It will be skipped for this '$($targetDevice.operatingSystem)' device."
        }
        elseif ($removeAADDevice) {
            "## Device is being deleted from EntraID. Adding it to the exclusion group is not possible; it will be skipped."
        }
        else {
            if ($exclusionGroupId) {
                # An explicit Object ID always overrides the display name to avoid ambiguity from name conflicts.
                "## An exclusion group Object ID was provided; it overrides the group name."
                $exclusionGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$exclusionGroupId" -ErrorAction SilentlyContinue
                if (-not $exclusionGroup) {
                    "## Error: Exclusion group with Object ID '$exclusionGroupId' not found in EntraID."
                    "## Execution stopped before any destructive action to avoid leaving the device in an inconsistent state."
                    throw "Exclusion group with Object ID '$exclusionGroupId' not found in EntraID. Aborting before wipe/delete. Please verify the group Object ID or disable 'Add device to compliance exclusion group'."
                }
                "## Preflight OK: exclusion group '$($exclusionGroup.displayName)' (Object ID '$exclusionGroupId') found."
            }
            else {
                $exclusionGroup = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$exclusionGroupName'" -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $exclusionGroup) {
                    "## Error: Exclusion group '$exclusionGroupName' not found in EntraID."
                    "## Execution stopped before any destructive action to avoid leaving the device in an inconsistent state."
                    throw "Exclusion group '$exclusionGroupName' not found in EntraID. Aborting before wipe/delete. Please verify the group name or disable 'Add device to compliance exclusion group'."
                }
                "## Preflight OK: exclusion group '$exclusionGroupName' found."
            }
        }
    }

    #endregion Exclusion Group Preflight

#endregion StatusQuo & Preflight-Check Part

############################################################
#region     Main Part
#
############################################################

    #region Exclusion Group Operations
    ##############################

    # Add the device to the compliance exclusion group so it receives a longer grace period
    # after it is re-enrolled via Autopilot. The group was already resolved (and validated to
    # exist) in the preflight above; $exclusionGroup is only set when an add should be attempted.
    if ($exclusionGroup) {
        # "Is device already member of the group?"
        if (Invoke-RjRbRestMethodGraph -Resource "/groups/$($exclusionGroup.id)/members/$($targetDevice.id)" -ErrorAction SilentlyContinue) {
            "## Device '$($targetDevice.displayName)' is already a member of '$($exclusionGroup.displayName)'. No action taken."
        }
        else {
            "## Adding device '$($targetDevice.displayName)' to exclusion group '$($exclusionGroup.displayName)'"
            try {
                $body = @{
                    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($targetDevice.id)"
                }
                Invoke-RjRbRestMethodGraph -Resource "/groups/$($exclusionGroup.id)/members/`$ref" -Method Post -Body $body | Out-Null
                "## Device successfully added to exclusion group."
            }
            catch {
                "## Error Message: $($_.Exception.Message)"
                "## Please see 'All logs' for more details."
                "## Execution stopped."
                throw "Adding device $($targetDevice.id) to exclusion group '$($exclusionGroup.displayName)' failed!"
            }
        }
    }
    else {
        "## Skipping exclusion group operations."
    }

    #endregion Exclusion Group Operations

    #region AzureAD Object Operations
    ##############################

    if ($disableAADDevice) {
        # Currentls MS Graph only allows to update windows devices when used "as App" (vs "delegated").
        if ($targetDevice.operatingSystem -eq "Windows") {
            "## Disabling $($targetDevice.displayName) (Object ID $($targetDevice.id)) in AzureAD"
            try {
                $body = @{
                    "accountEnabled" = $false
                }
                Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method Patch -Body $body | Out-Null
            }
            catch {
                "## Error Message: $($_.Exception.Message)"
                "## Please see 'All logs' for more details."
                "## Execution stopped."
                throw "Disabling Object ID $($targetDevice.id) in AzureAD failed!"
            }
        }
        else {
            "## Disabling non-windows devices in AzureAD is currently not supported. Skipping."
        }
    }

    if ($removeAADDevice) {
        "## Deleting $($targetDevice.displayName) (Object ID $($targetDevice.id)) from AzureAD"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method Delete | Out-Null
        }
        catch {
            "## Error Message: $($_.Exception.Message)"
            "## Please see 'All logs' for more details."
            "## Execution stopped."
            throw "Deleting Object ID $($targetDevice.id) from AzureAD failed!"

        }
    }

    if ((-not $disableAADDevice) -and (-not $removeAADDevice)) {
        "## Skipping AzureAD object operations."
    }

    #endregion AzureAD Object Operations

    #region Intune Operations
    ##############################

    $mgdDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
    if ($mgdDevice) {
        if ($wipeDevice) {
            "## Wiping DeviceId $DeviceID (Intune ID: $($mgdDevice.id))"
            $body = @{
                "keepEnrollmentData" = "false"
                "keepUserData"       = "false"
            }
            if ($mgdDevice.operatingSystem -eq "macOS") {
                "## MacOS device detected."
                $body["macOsUnlockCode"] = $macOsRecoveryCode
                $body["obliterationBehavior"] = $macOsObliterationBehavior
            }
            if ($mgdDevice.operatingSystem -eq "Windows") {
                "## Windows device detected."
                $body["useProtectedWipe"] = $useProtectedWipe
            }
            try {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($mgdDevice.id)/wipe" -Method Post -Body $body -Beta | Out-Null
            }
            catch {
                "## Error Message: $($_.Exception.Message)"
                "## Please see 'All logs' for more details."
                "## Execution stopped."
                throw "Wiping DeviceID $DeviceID (Intune ID: $($mgdDevice.id)) failed!"
            }
        }
        elseif ($removeIntuneDevice) {
            "## Deleting DeviceId $DeviceID (Intune ID: $($mgdDevice.id)) from Intune"
            try {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($mgdDevice.id)" -Method Delete | Out-Null
            }
            catch {
                "## Error Message: $($_.Exception.Message)"
                "## Please see 'All logs' for more details."
                "## Execution stopped."
                throw "Deleting Intune ID: $($mgdDevice.id) from Intune failed!"
            }
        }
        else {
            "## Skipping Intune operations."
        }
    }
    else {
        "## Device not found in Intune. Skipping."
    }

    #endregion Intune Operations

    #region Autopilot Operations
    ##############################

    if ($removeAutopilotDevice) {
        $apDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -OdFilter "azureActiveDirectoryDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
        if ($apDevice) {
            "## Deleting DeviceId $DeviceID (Autopilot ID: $($apDevice.id)) from Autopilot"
            try {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$($apDevice.id)" -Method Delete | Out-Null
            }
            catch {
                "## Error Message: $($_.Exception.Message)"
                "## Please see 'All logs' for more details."
                "## Execution stopped."
                throw "Deleting Autopilot ID: $($apDevice.id) from Autopilot failed!"
            }
        }
        else {
            "## Device not found in AutoPilot database. Skipping."
        }
    }
    else {
        "## Skipping AutoPilot operations."
    }

    #endregion Autopilot Operations

#endregion Main Part

############################################################
#region     Cleanup
#
############################################################

""
"## Device $($targetDevice.displayName) with DeviceId $DeviceId successfully removed/outphased."

#endregion Cleanup
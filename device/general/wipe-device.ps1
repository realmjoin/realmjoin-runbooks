<#
    .SYNOPSIS
    Wipe a Windows or MacOS device

    .DESCRIPTION
    Wipe a Windows or MacOS device. For Windows devices, you can choose between a regular wipe and a protected wipe. For MacOS devices, you can provide a recovery code if needed and specify the obliteration behavior.

    .PARAMETER DeviceId
    The device ID of the target device.

    .PARAMETER wipeDevice
    "Wipe this device?" (final value: true) or "Do not wipe device" (final value: false) can be selected as action to perform. If set to true, the runbook will trigger a wipe action for the device in Intune. If set to false, no wipe action will be triggered for the device in Intune.

    .PARAMETER useProtectedWipe
    Windows-only. If set to true, uses protected wipe.

    .PARAMETER removeIntuneDevice
    If set to true, deletes the Intune device object.

    .PARAMETER removeAutopilotDevice
    Windows-only. "Delete device from AutoPilot database?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will delete the device from the AutoPilot database, which also allows the device to leave the tenant. If set to false, the device will remain in the AutoPilot database and can be re-assigned to another user/device in the tenant.

    .PARAMETER removeAADDevice
    "Delete device from EntraID?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will delete the device object from Entra ID (Azure AD). If set to false, the device object will remain in Entra ID (Azure AD).

    .PARAMETER disableAADDevice
    "Disable device in EntraID?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will disable the device object in Entra ID (Azure AD). If set to false, the device object will remain enabled in Entra ID (Azure AD).

    .PARAMETER skipWipeIfAtRisk
    If set to true, the wipe is only performed when the device's Microsoft Defender for Endpoint risk score is not Medium or High. This protects forensic data (e.g. logs) of devices that may be involved in a security incident from being destroyed by the wipe.

    .PARAMETER macOsRecoveryCode
    MacOS-only. Recovery code for older devices; newer devices may not require this.

    .PARAMETER macOsObliterationBehavior
    MacOS-only. Controls the OS obliteration behavior during wipe.

    .PARAMETER CallerName
    Caller name for auditing purposes.

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
                "DisplayName": "Disable AzureAD device object?",
                "SelectSimple": {
                    "Disable device in AzureAD": true,
                    "Do not modify AzureAD device / do not care": false
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
                "DisplayName": "Windows: Use protected wipe?"
            },
            "skipWipeIfAtRisk": {
                "DisplayName": "Only wipe if device is not at risk (Defender Medium/High)?",
                "SelectSimple": {
                    "Only wipe if Defender risk score is not Medium/High": true,
                    "Wipe regardless of Defender risk score": false
                }
            },
            "removeIntuneDevice": {
                "DisplayName": "Delete device from Intune?",
                "SelectSimple": {
                    "Delete device from Intune (only if device is already wiped or destroyed)": true,
                    "Do not modify the Intune object / do not care": false
                }
            },
            "removeAutopilotDevice": {
                "DisplayName": "Windows: Delete device from AutoPilot database?",
                "SelectSimple": {
                    "Remove the device from AutoPilot (the device can leave the tenant)": true,
                    "Keep device / do not care": false
                }
            },
            "macOsRecoveryCode": {
                "DisplayName": "MacOS: Recovery Code - not needed for newer devices",
                "Hide": true
            },
            "macOsObliterationBehavior": {
                "DisplayName": "MacOS: OS Obliteration Behavior",
                "SelectSimple": {
                    "Default: Try to erase user date (EACS), obliterate OS if this fails": "default",
                    "Try to erase user data (EACS), do not obliterate the OS": "doNotObliterate",
                    "Try to erase user data (EACS), else warn and obliterate the OS": "obliterateWithWarning",
                    "Always obliterate OS": "always"
                }
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }

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
    # Only for old MacOS devices. Newer devices can be wiped without a recovery code.
    [string] $macOsRecoveryCode = "123456",
    # "default": Use EACS to wipe user data, reatining the OS. Will wipe the OS, if EACS fails.
    [string] $macOsObliterationBehavior = "default",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.2"
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

    #region Defender Risk Preflight
    ##############################

    # Evaluate the device's Defender for Endpoint risk score before wiping, if requested.
    # This protects forensic data (e.g. logs) of devices that may be involved in a security incident.
    $deviceIsAtRisk = $false
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
                $deviceIsAtRisk = $true
            }
        }
        else {
            "## Device not found in Defender for Endpoint. Risk score could not be determined; proceeding with wipe."
        }
    }

    #endregion Defender Risk Preflight

#endregion StatusQuo & Preflight-Check Part

############################################################
#region     Main Part
#
############################################################

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
            if ($skipWipeIfAtRisk -and $deviceIsAtRisk) {
                "## Device risk score is Medium or High. Skipping wipe to preserve forensic data (e.g. logs) for the ongoing security investigation."
                "## Disable 'Only wipe if device is not at risk' to wipe this device anyway."
            }
            else {
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
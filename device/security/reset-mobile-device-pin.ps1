<#
    .SYNOPSIS
    Reset a mobile device's password/PIN code.

    .DESCRIPTION
    This runbook triggers an Intune reset passcode action for a managed mobile device.
    The action is only supported for certain, corporate-owned device types and will be rejected for personal or unsupported devices.
    Optionally, the passcode is only reset when the device's Microsoft Defender for Endpoint risk score is not Medium or High.

    .PARAMETER DeviceId
    The device ID of the target device.

    .PARAMETER skipIfAtRisk
    If set to true, the passcode is only reset when the device's Microsoft Defender for Endpoint risk score is not Medium or High. This prevents a passcode reset on a device that may be involved in a security incident, which could grant access to the device or interfere with the investigation. Devices that are not found in Defender for Endpoint are not blocked.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "DeviceId": {
                "Hide": true
            },
            "skipIfAtRisk": {
                "DisplayName": "Only reset passcode if device is not at risk (Defender Medium/High)?",
                "SelectSimple": {
                    "Only reset if Defender risk score is not Medium/High": true,
                    "Reset regardless of Defender risk score": false
                }
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
    [String] $DeviceId,
    # If true, only reset the passcode when the device's Defender risk score is not Medium or High (protects devices involved in a security incident).
    [bool] $skipIfAtRisk = $false,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "DeviceId: $DeviceId" -Verbose
Write-RjRbLog -Message "skipIfAtRisk: $skipIfAtRisk" -Verbose

Connect-RjRbGraph

############################################################
#region     Defender Risk Preflight (runs first, may abort)
#
############################################################

# Evaluate the device's Defender for Endpoint risk score before doing anything else.
# If the device is at risk (Medium/High), abort immediately so the passcode of a device
# that may be involved in a security incident is not reset.
if ($skipIfAtRisk) {
    "## 'Skip if at risk' is enabled. Checking Microsoft Defender for Endpoint risk score..."
    try {
        # Defender for Endpoint is only required for this check.
        Connect-RjRbDefenderATP

        # From experience the first result seems to be the "freshest" candidate.
        $atpDevice = Invoke-RjRbRestMethodDefenderATP -Resource "/machines" -OdFilter "aadDeviceId eq $DeviceId" -ErrorAction Stop |
            Sort-Object { [datetime]$_.lastSeen } -Descending |
            Select-Object -First 1
    }
    catch {
        "## Error Message: $($_.Exception.Message)"
        "## Please see 'All logs' for more details."
        "## Maybe the 'Machine.Read.All' permission on WindowsDefenderATP is missing?"
        "## Execution stopped."
        throw "Could not determine the device's Defender risk score. Aborting to avoid resetting the passcode of a potentially at-risk device."
    }

    if ($atpDevice -and $atpDevice.riskScore) {
        "## Defender risk score: '$($atpDevice.riskScore)'"
        if ($atpDevice.riskScore -in @('Medium', 'High')) {
            ""
            "!!!!! Warning !!!!!"
            "Defender risk score of this device is '$($atpDevice.riskScore)'."
            "The device may be involved in a security incident. Resetting its passcode now could grant access to the device or interfere with the investigation."
            "Please align with your security team before resetting the passcode."
            "To reset it anyway, disable 'Only reset passcode if device is not at risk' and re-run this runbook."
            "!!!!!!!!!!!!!!!!!!!!!!!!!!"
            ""
            throw "Execution stopped: Defender risk score is '$($atpDevice.riskScore)'. Passcode reset cancelled to protect a potentially compromised device. Align with security or disable 'Only reset passcode if device is not at risk'."
        }
    }
    elseif ($atpDevice) {
        "## Device found in Defender for Endpoint, but no risk score is reported yet; proceeding with passcode reset."
    }
    else {
        "## Device not found in Defender for Endpoint. Risk score could not be determined; proceeding with passcode reset."
    }
}

#endregion Defender Risk Preflight

$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$DeviceId'" -Beta
## Checking device has been found
if ($null -eq $targetDevice) {
    ## Highly unlikely
    throw "## Device not found. "
}

## Checking the device's Owner Type. Reset Passcode works only with corporate-owned devices.
if ($targetDevice.managedDeviceOwnerType -eq "personal" -or $targetDevice.managedDeviceOwnerType -eq "unknown" ) {
    throw "## Device '$($targetDevice.deviceName)' is not corporate-owned. Cannot reset Passcode. `n## Aborting..."
}

## Post the resetPasscode action and if possible it will execute, otherwise will result in an exception
try {
    Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices('$($targetDevice.id)')/resetPasscode" -Method Post -Beta

    "## Device Passcode has been reset."
}
catch {
    throw "## Device type does not allow for a passcode reset.  `n## Aborting..."
}

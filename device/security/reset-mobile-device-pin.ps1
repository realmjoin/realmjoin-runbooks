<#
    .SYNOPSIS
    Reset a mobile device's password/PIN code.

    .DESCRIPTION
    This runbook triggers an Intune reset passcode action for a managed mobile device.
    The action is only supported for certain, corporate-owned device types and will be rejected for personal or unsupported devices.

    .PARAMETER DeviceId
    The device ID of the target device.

    .PARAMETER CallerName
    Caller name for auditing purposes.

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

param(
    [Parameter(Mandatory = $true)]
    [String] $DeviceId,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

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

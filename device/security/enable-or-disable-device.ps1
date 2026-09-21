<#
    .SYNOPSIS
    Enable or disable this device in Entra ID

    .DESCRIPTION
    Disables or re-enables the Entra ID object of this device. A disabled device can no longer be used to sign in, which blocks a lost or compromised device; enabling it again lifts the block. Nothing on the device itself is changed.

    .PARAMETER DeviceId
    Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

    .PARAMETER Enable
    Disable blocks sign-ins from the device. Enable again lifts an earlier block.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Enable": {
                "DisplayName": "Disable or enable this device",
                "SelectSimple": {
                    "Disable device": false,
                    "Enable device again": true
                }
            },
            "DeviceId": {
                "Hide": true
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
    [string] $DeviceId,
    [bool] $Enable = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# "Searching DeviceId $DeviceID."
$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if (-not $targetDevice) {
    throw ("DeviceId $DeviceId not found.")
}

if ($targetDevice.operatingSystem -ne "Windows") {
    # Currentls MS Graph only allows to update windows devices when used "as App" (vs "delegated").
    "## Can not en-/disable non-windows devices currently in EntraID. "
    throw ("OS not supported")
}

$body = @{ accountEnabled = $Enable }

if ($targetDevice.accountEnabled) {
    if ($Enable) {
        "## Device $($targetDevice.displayName) with DeviceId $DeviceId is already enabled in EntraID."
    }
    else {
        "## Disabling device $($targetDevice.displayName) with DeviceId $DeviceId in EntraID."
        try {
            Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method "Patch" -body $body | Out-Null
        }
        catch {
            write-error $_
            throw "Disabling of device $($targetDevice.displayName) failed"
        }
    }
}
else {
    if ($Enable) {
        "## Enabling device $($targetDevice.displayName) with DeviceId $DeviceId in EntraID."
        try {
            Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method "Patch" -body $body | Out-Null
        }
        catch {
            write-error $_
            throw "Enabling of device $($targetDevice.displayName) failed"
        }
    }
    else {
        "## Device $($targetDevice.displayName) with DeviceId $DeviceId is already disabled in EntraID."
    }
}

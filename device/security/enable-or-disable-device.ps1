<#
    .SYNOPSIS
    Enable or disable a device in Entra ID

    .DESCRIPTION
    This runbook enables or disables a Windows device object in Entra ID (Azure AD) based on the provided device ID.
    Use it to temporarily block sign-ins from a compromised or lost device, or to re-enable the device after remediation.

    .PARAMETER DeviceId
    The device ID of the target device.

    .PARAMETER Enable
    Set to true to enable the device, or false to disable the device.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Enable": {
                "DisplayName": "Disable or Enable Device",
                "SelectSimple": {
                    "Disable Device": false,
                    "Enable Device again": true
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [bool] $Enable = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# "Searching DeviceId $DeviceID."
$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if (-not $targetDevice) {
    throw ("DeviceId $DeviceId not found.")
}

if ($targetDevice.operatingSystem -ne "Windows") {
    # Currentls MS Graph only allows to update windows devices when used "as App" (vs "delegated").
    "## Can not en-/disable non-windows devices currently in AzureAD. "
    throw ("OS not supported")
}

$body = @{ accountEnabled = $Enable }

if ($targetDevice.accountEnabled) {
    if ($Enable) {
        "## Device $($targetDevice.displayName) with DeviceId $DeviceId is already enabled in AzureAD."
    }
    else {
        "## Disabling device $($targetDevice.displayName) with DeviceId $DeviceId in AzureAD."
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
        "## Enabling device $($targetDevice.displayName) with DeviceId $DeviceId in AzureAD."
        try {
            Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method "Patch" -body $body | Out-Null
        }
        catch {
            write-error $_
            throw "Enabling of device $($targetDevice.displayName) failed"
        }
    }
    else {
        "## Device $($targetDevice.displayName) with DeviceId $DeviceId is already disabled in AzureAD."
    }
}

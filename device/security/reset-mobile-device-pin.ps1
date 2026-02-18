<#
  .SYNOPSIS
  Reset a mobile device's password/PIN code.

  .DESCRIPTION
  Reset a mobile device's password/PIN code. Warning: Not possible for all types of devices.

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

## Checking the device's Owner Type. Reset Passcode works only with corporate-owned deivces.
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

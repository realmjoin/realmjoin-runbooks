# Permissions (Graph):
# - Device.Read.All
#
# Roles (AzureAD):
# - Cloud Device Administrator

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

<#
  .SYNOPSIS
  Disable a device in AzureAD.

  .DESCRIPTION
  Disable a device in AzureAD.

#>

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [bool] $EnableDevice = $false
)

Connect-RjRbGraph

# "Searching DeviceId $DeviceID."
$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if (-not $targetDevice) {
    throw ("DeviceId $DeviceId not found.")
} 

$body = @{ accountEnabled = $EnableDevice }

if ($targetDevice.accountEnabled) {
    if ($EnableDevice) {
        "Device $($targetDevice.displayName) with DeviceId $DeviceId is already enabled in AzureAD."
    }
    else {
        # "Disabling device $($targetDevice.displayName) in AzureAD."
        try {
            # Set-AzureADDevice -AccountEnabled $false -ObjectId $targetDevice.id -ErrorAction Stop | Out-Null
            Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method "Patch" -body $body | Out-Null
            "Device $($targetDevice.displayName) with DeviceId $DeviceId is disabled."
        }
        catch {
            write-error $_
            throw "Disabling of device $($targetDevice.displayName) failed"
        }
    }
}
else {
    if ($EnableDevice) { 
        # "Enabling device $($targetDevice.displayName) in AzureAD."
        try {
            # Set-AzureADDevice -AccountEnabled $true -ObjectId $targetDevice.id -ErrorAction Stop | Out-Null
            Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method "Patch" -body $body | Out-Null
            "Device $($targetDevice.displayName) with DeviceId $DeviceId is enabled."
        }
        catch {
            write-error $_
            throw "Enabling of device $($targetDevice.displayName) failed"
        }
    } else {
        "Device $($targetDevice.displayName) with DeviceId $DeviceId is already disabled in AzureAD."        
    }
}

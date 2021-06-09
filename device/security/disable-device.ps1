# This runbook will will disable a device in AzureAD. 
#
# This runbook uses both AzureAD- and Graph-modules to avoid performance-issues with large directories.
# 
# Permissions (Graph):
# - Device.Read.All
#
# Roles (AzureAD):
# - Cloud Device Administrator

#Requires -Module AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId
)

Connect-RjRbAzureAD
Connect-RjRbGraph

# "Searching DeviceId $DeviceID."
$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if (-not $targetDevice) {
    throw ("DeviceId $DeviceId not found.")
} 

if ($targetDevice.accountEnabled) {
    "Disabling device $($targetDevice.displayName) in AzureAD."
    # Sadly, MS Graph does not allow to disable a device using app credentials. Using AzureAD.
    try {
        Set-AzureADDevice -AccountEnabled $false -ObjectId $targetDevice.id -ErrorAction Stop | Out-Null
    }
    catch {
        write-error $_
        throw "Disabling of device $($targetDevice.displayName) failed"
    }
}
else {
    "Device $($targetDevice.displayName) is already disabled in AzureAD."
}

# "Disconnecting from AzureAD"
Disconnect-AzureAD

"Device $($targetDevice.displayName) with DeviceId $DeviceId is disabled."


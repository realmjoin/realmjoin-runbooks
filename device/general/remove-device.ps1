# This runbook will remove a windows device from Intune, AzureAD and Autopilot.
# This will NOT wipe a device. (although company user data and configs are removed from the client when it checks in.)
# 
# Be aware 
# - this runbook uses MS Graph "Beta" functionality and might break at some point.
# - https://docs.microsoft.com/en-us/graph/api/device-delete?view=graph-rest-1.0&tabs=http says we can not use API permissions to delete AzureAD devices, but it works (now). Might break.
#
# Permissions (API):
# - DeviceManagementManagedDevices.PrivilegedOperations.All (Wipe,Retire / seems to allow us to delete from AzureAD)
# - DeviceManagementManagedDevices.ReadWrite.All (Delete Inunte Device)
# - DeviceManagementServiceConfig.ReadWrite.All (Delete Autopilot enrollment)

#Requires -Module RealmJoin.RunbookHelper, MEMPSToolkit

param (
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [Parameter(Mandatory = $true)]
    [string] $OrganizationId
)

#region module check
$neededModule = "MEMPSToolkit"

if (-not (Get-Module -ListAvailable $neededModule)) {
    throw ($neededModule + " is not available and can not be installed automatically. Please check.")
}
else {
    Import-Module $neededModule
    Write-Output ("Module " + $neededModule + " is available.")
}
#endregion

#region Authentication
$automationCredsName = "realmjoin-automation-cred"

Write-Output "Connect to Graph API..."
$token = Get-AzAutomationCredLoginToken -tenant $OrganizationID -automationCredName $automationCredsName
#endregion

Write-Output ""

write-output "Searching DeviceId $DeviceID."
$targetDevice = Get-AadDevices -deviceId $DeviceId -authToken $token
if ($null -eq $targetDevice) {
    throw ("DeviceId $DeviceId not found in AzureAD.")
} 

# Remove from AzureAD - we could wipe the device, but we could not continue the process here immediately -> different runbook.
Write-Output "Deleting $($targetDevice.displayName) (Object ID $($targetDevice.id)) from AzureAD"
try {
    Remove-AadDevice -ObjectId $targetDevice.id -authToken $token | Out-Null
}
catch {
    throw "Deleting Object ID $($targetDevice.id) from AzureAD failed!"
}

Write-Output ""

# Remove from Intune
Write-Output "Searching DeviceId $DeviceID in Intune."
$mgdDevice = Get-ManagedDeviceByDeviceId -azureAdDeviceId $DeviceId -authToken $token
if ($null -eq $mgdDevice) {
    Write-Output ("DeviceId $DeviceId not found in Intune.")
}
else {
    Write-Output "Deleting DeviceId $DeviceID (Intune ID: $($mgdDevice.id)) from Intune"
    try {
        Remove-ManagedDevice -id $mgdDevice.id -authToken $token | Out-Null
    }
    catch {
        throw "Deleting Intune ID: $($mgdDevice.id) from Intune failed!"
    }
}

Write-Output ""

# Remove from Autopilot
Write-Output "Searching DeviceId $DeviceID in Autopilot."
$apDevice = Get-WindowsAutopilotDeviceByDeviceId -azureAdDeviceId $DeviceId -authToken $token
if ($null -eq $apDevice) {
    throw ("DeviceId $DeviceId not found in Autopilot.")
}
else {
    Write-Output "Deleting DeviceId $DeviceID (Autopilot ID: $($apDevice.id)) from Autopilot"
    try {
        Remove-WindowsAutopilotDevice -id $apDevice.id -authToken $token | Out-Null
    }
    catch {
        throw "Deleting Autopilot ID: $($apDevice.id) from Autopilot failed!"
    }
}

Write-Output ""

Write-Output "Device $($targetDevice.displayName) with DeviceId $DeviceId successfully removed."
# This runbook will will disable a device in AzureAD. 
#
# This runbook uses both AzureAD- and Graph-modules to avoid performance-issues with large directories.
# 
# Permissions (Graph):
# - Device.Read.All
#
# Roles (AzureAD):
# - Cloud Device Administrator

#Requires -Module AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }, MEMPSToolkit

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [Parameter(Mandatory = $true)]
    [string] $OrganizationId
)


#region Module check
function Test-ModulePresent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$neededModule
    )
    if (-not (Get-Module -ListAvailable $neededModule)) {
        throw ($neededModule + " is not available and can not be installed automatically. Please check.")
    }
    else {
        Import-Module $neededModule
        # "Module " + $neededModule + " is available."
    }
}

Test-ModulePresent "RealmJoin.RunbookHelper"
Test-ModulePresent "MEMPSToolkit"
Test-ModulePresent "AzureAD"
#endregion

#region Authentication
# "Connecting to AzureAD"
Connect-RjRbAzureAD

# "Connect to Graph API..."
Connect-RjRbGraph
#endregion

# "Searching DeviceId $DeviceID."
# Sadly, Get-AzureADDevices can not filter by deviceId. Will use MS Graph / MEMPSToolkit.
$targetDevice = Get-AadDevices -deviceId $DeviceId -authToken $Global:RjRbGraphAuthHeaders
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


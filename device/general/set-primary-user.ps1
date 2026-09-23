<#
    .SYNOPSIS
    Set a new primary user on this device

    .DESCRIPTION
    Assigns the chosen user as the new primary user of this device in Intune and replaces the current one. The output shows the previous and the new assignment.

    .PARAMETER DeviceId
    Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

    .PARAMETER NewPrimaryUserId
    User to assign. The current primary user is replaced; both are shown in the output.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "DeviceId": {
                "Hide": true
            },
            "NewPrimaryUserId": {
                "DisplayName": "New primary user"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param (
    [Parameter(Mandatory = $true)]
    [string]$DeviceId,

    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "New primary user" } )]
    [string]$NewPrimaryUserId,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "DeviceId (Entra Object ID): $DeviceId" -Verbose
Write-RjRbLog -Message "NewPrimaryUserId: $NewPrimaryUserId" -Verbose

#endregion

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    throw
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

# DeviceId from the portal is the Entra Object ID.
# Resolve the matching Intune managed device via azureADDeviceId.
try {
    $intuneDevices = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$DeviceId'&`$select=id,deviceName,serialNumber,operatingSystem,osVersion,lastSyncDateTime,userId,userPrincipalName,userDisplayName" -Method GET -ErrorAction Stop
    $device = $intuneDevices.value | Select-Object -First 1
}
catch {
    Write-Error "Failed to query Intune for device with Entra Object ID '$DeviceId': $($_.Exception.Message)" -ErrorAction Continue
    throw "Intune query failed for device '$DeviceId'"
}

if (-not $device) {
    Write-Error "No Intune managed device found for Entra Object ID '$DeviceId'. The device may not be enrolled in Intune or the ID is incorrect." -ErrorAction Continue
    throw "Device '$DeviceId' not found in Intune"
}

# Use the Intune managed device ID for all subsequent operations
$IntuneDeviceId = $device.id

Write-Output "Device Name:    $($device.deviceName)"
Write-Output "Serial Number:  $($device.serialNumber)"
Write-Output "OS:             $($device.operatingSystem) $($device.osVersion)"
Write-Output "Last Sync:      $($device.lastSyncDateTime)"
Write-Output ""

# Determine current primary user from device object
if (-not [string]::IsNullOrEmpty($device.userId)) {
    $CurrentPrimaryUserId = $device.userId
    $CurrentPrimaryUserUPN = $device.userPrincipalName
    $CurrentPrimaryUserDisplay = $device.userDisplayName
    Write-Output "Current Primary User: $CurrentPrimaryUserDisplay ($CurrentPrimaryUserUPN)"
}
else {
    $CurrentPrimaryUserId = $null
    $CurrentPrimaryUserUPN = "None"
    $CurrentPrimaryUserDisplay = "None"
    Write-Output "Current Primary User: None"
}

# Get new user information
try {
    $newUser = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$NewPrimaryUserId" -Method GET -ErrorAction Stop
    $NewPrimaryUserUPN = $newUser.userPrincipalName
    $NewPrimaryUserDisplay = $newUser.displayName
    Write-Output "New Primary User:     $NewPrimaryUserDisplay ($NewPrimaryUserUPN)"
}
catch {
    Write-Error "User with ID '$NewPrimaryUserId' was not found. Please verify the user exists in the tenant." -ErrorAction Continue
    throw "User '$NewPrimaryUserId' not found"
}

# Check if already assigned
if ($CurrentPrimaryUserId -eq $NewPrimaryUserId) {
    Write-Output ""
    Write-Output "'$NewPrimaryUserDisplay' is already the primary user of '$($device.deviceName)'. No changes needed."
    Write-Output ""
    Write-Output "Done!"
    exit
}

#endregion

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Set new primary user"
Write-Output "---------------------"

# Step 1: Remove current primary user if one is assigned
if ($CurrentPrimaryUserId) {
    Write-Output "Removing current primary user '$CurrentPrimaryUserDisplay'..."
    try {
        Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$IntuneDeviceId')/users/`$ref" -Method DELETE -ErrorAction Stop | Out-Null
        Write-Output "Current primary user removed."
    }
    catch {
        Write-Error "Failed to remove current primary user '$CurrentPrimaryUserDisplay' from device '$($device.deviceName)': $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to remove current primary user"
    }
}

# Step 2: Assign new primary user
Write-Output "Assigning '$NewPrimaryUserDisplay' as new primary user..."
try {
    $body = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/users/$NewPrimaryUserId"
    }
    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$IntuneDeviceId')/users/`$ref" -Method POST -Body $body -ErrorAction Stop | Out-Null
    Write-Output "New primary user assigned successfully."
}
catch {
    Write-Error "Failed to assign '$NewPrimaryUserDisplay' as primary user on device '$($device.deviceName)': $($_.Exception.Message)" -ErrorAction Continue
    throw "Failed to assign new primary user"
}

#endregion

########################################################
#region     Cleanup
########################################################

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Device:            $($device.deviceName)"
Write-Output "Previous User:     $CurrentPrimaryUserDisplay ($CurrentPrimaryUserUPN)"
Write-Output "New Primary User:  $NewPrimaryUserDisplay ($NewPrimaryUserUPN)"

Disconnect-MgGraph | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion

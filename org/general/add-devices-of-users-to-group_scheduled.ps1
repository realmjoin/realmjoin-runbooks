<#
  .SYNOPSIS
  Sync devices of users in a specific group to another device group.

  .DESCRIPTION
  This runbook reads accounts from a specified Users group and adds their devices to a specified Devices group. It ensures new devices are also added.

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserGroup": {
                "DisplayName": "Name or Object ID of the Users Group"
            },
            "DeviceGroup": {
                "DisplayName": "Name or Object ID of the Devices Group"
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $UserGroup,
    [Parameter(Mandatory = $true)]
    [string] $DeviceGroup,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

"Syncing devices from User Group: '$UserGroup' to Device Group: '$DeviceGroup'" 

Connect-RjRbGraph

# Get user group members
"Retrieving members of the user group: $UserGroup" 
$UserGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$UserGroup/members" -FollowPaging

if ($UserGroupMembers.Count -eq 0) {
    "No members found in the user group: $UserGroup" -ErrorAction Stop
} else {
    "Found $($UserGroupMembers.Count) members in the user group: $UserGroup" 
}

# Get current devices in the device group
"Retrieving current members of the device group: $DeviceGroup" 
$DeviceGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$DeviceGroup/members" -FollowPaging

$DeviceGroupMemberIds = $DeviceGroupMembers | ForEach-Object { $_.id }

# Process each user in the user group
foreach ($User in $UserGroupMembers) {
    $UserId = $User.id

    "Retrieving owned devices for user: $($User.displayName), ID: $UserId" 
    $UserDevices = Invoke-RjRbRestMethodGraph -Resource "/users/$UserId/ownedDevices" -FollowPaging | Where-Object {
        ($_.operatingSystem -eq "Windows" -and $_.trustType -eq "AzureAd") -or 
        ($_.operatingSystem -eq "MacMDM")
    }

    if ($UserDevices.Count -eq 0) {
        "No devices found for user: $($User.displayName)" 
        continue
    } else {
        "Found $($UserDevices.Count) devices for user: $($User.displayName)" 
    }

    foreach ($Device in $UserDevices) {
        if ($DeviceGroupMemberIds -notcontains $Device.id) {
             "DeviceID: $($Device.id)"
            "Adding device $($Device.displayName) of user $($User.displayName) to device group" 
            $body = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($Device.id)"
            }
            try {
                Invoke-RjRbRestMethodGraph -Resource "/groups/$DeviceGroup/members/`$ref" -Method POST -Body $body 
                "Successfully added device $($Device.displayName) to device group" 
            } catch {
                "Failed to add device $($Device.displayName) to device group. Error: $_" 
            }
        } else {
            "Device $($Device.displayName) of user $($User.displayName) already in device group" 
        }
    }
}

"Device sync completed successfully" 

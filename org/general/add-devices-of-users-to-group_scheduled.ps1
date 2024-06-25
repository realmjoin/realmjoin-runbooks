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

Connect-RjRbGraph

# Function to resolve group name to ID
function Resolve-GroupId($Group) {
    if ($Group -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        return $Group
        "Input Group Name: '$Group'"
    } else {
        $encodedGroupName = [System.Web.HttpUtility]::UrlEncode($Group)
        Write-RjRbLog -Message "Encoded Group Name: '$encodedGroupName'" -Verbose
        $resolvedGroup = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$encodedGroupName'" -FollowPaging
        if ($resolvedGroup.Count -eq 1) {
            return $resolvedGroup[0].id
        } elseif ($resolvedGroup.Count -gt 1) {
            throw "Multiple groups found with name '$Group'. Please specify the Object ID."
        } else {
            throw "No group found with name '$Group'."
        }
    }
}

# Resolve group IDs
$UserGroupId = Resolve-GroupId $UserGroup
$DeviceGroupId = Resolve-GroupId $DeviceGroup

# Get user group members
"Retrieving members of the user group: $UserGroupId" 
$UserGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$UserGroupId/members" -FollowPaging

if ($UserGroupMembers.Count -eq 0) {
    "No members found in the user group: $UserGroupId"
} else {
    "Found $($UserGroupMembers.Count) members in the user group: $UserGroupId" 
}

# Get current devices in the device group
"Retrieving current members of the device group: $DeviceGroupId" 
$DeviceGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$DeviceGroupId/members" -FollowPaging

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
                Invoke-RjRbRestMethodGraph -Resource "/groups/$DeviceGroupId/members/`$ref" -Method POST -Body $body
                "Successfully added device $($Device.displayName) to device group" 
            } catch {
                "Failed to add device $($Device.displayName) to device group. Error: $_" 
            }
        } else {
            "Device $($Device.displayName) of user $($User.displayName) already in device group" 
        }
    }
}

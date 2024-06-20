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
    [string] $DeviceGroup
)

Write-Host -Message "Syncing devices from User Group: '$UserGroup' to Device Group: '$DeviceGroup'" -Verbose

Connect-RjRbGraph

# Get user group members
Write-Host -Message "Retrieving members of the user group: $UserGroup" -Verbose
$UserGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$UserGroup/members" -FollowPaging

if ($UserGroupMembers.Count -eq 0) {
    Write-Host -Message "No members found in the user group: $UserGroup" -ErrorAction Stop
} else {
    Write-Host -Message "Found $($UserGroupMembers.Count) members in the user group: $UserGroup" -Verbose
}

# Get current devices in the device group
Write-Host -Message "Retrieving current members of the device group: $DeviceGroup" -Verbose
$DeviceGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$DeviceGroup/members" -FollowPaging

$DeviceGroupMemberIds = $DeviceGroupMembers | ForEach-Object { $_.deviceId }

# Process each user in the user group
foreach ($User in $UserGroupMembers) {
    $UserId = $User.id

    Write-Host -Message "Retrieving owned devices for user: $($User.displayName), ID: $UserId" -Verbose
    $UserDevices = Invoke-RjRbRestMethodGraph -Resource "/users/$UserId/ownedDevices" -FollowPaging | Where-Object {
        ($_.operatingSystem -eq "Windows" -and $_.trustType -eq "AzureAd") -or 
        ($_.operatingSystem -eq "MacMDM")
    }

    if ($UserDevices.Count -eq 0) {
        Write-Host -Message "No devices found for user: $($User.displayName)" -Verbose
        continue
    } else {
        Write-Host -Message "Found $($UserDevices.Count) devices for user: $($User.displayName)" -Verbose
    }

    foreach ($Device in $UserDevices) {
        if ($DeviceGroupMemberIds -notcontains $Device.id) {
            Write-Host "DeviceID: $($Device.id)"
            Write-Host -Message "Adding device $($Device.displayName) of user $($User.displayName) to device group" -Verbose
            $body = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($Device.id)"
            }
            $jsonBody = $body | ConvertTo-Json -Depth 4
            try {
                Invoke-RjRbRestMethodGraph -Method POST -Resource "/groups/$DeviceGroup/members/\$ref" -Body $jsonBody
                Write-Host -Message "Successfully added device $($Device.displayName) to device group" -Verbose
            } catch {
                Write-Host -Message "Failed to add device $($Device.displayName) to device group. Error: $_" -Verbose
            }
        } else {
            Write-Host -Message "Device $($Device.displayName) of user $($User.displayName) already in device group" -Verbose
        }
    }
}

Write-Host -Message "Device sync completed successfully" -Verbose

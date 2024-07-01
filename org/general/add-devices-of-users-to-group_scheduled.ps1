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
            },
            "IncludeWindowsDevice": {
                "DisplayName": "Include Windows Devices (Default: False)"
            },
            "IncludeMacOSDevice": {
                "DisplayName": "Include MacOS-Devices (Default: False)"
            },
            "IncludeLinuxDevice": {
                "DisplayName": "Include Linux Devices (Default: False)"
            },
            "IncludeAndroidDevice": {
                "DisplayName": "Include Android Devices (Default: False)"
            },
            "IncludeIOSDevice": {
                "DisplayName": "Include iOS-Devices (Default: False)"
            },
            "IncludeIPadOSDevice": {
                "DisplayName": "Include iPadOS-Devices (Default: False)"
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
    [string] $CallerName,
    [bool] $IncludeWindowsDevice = $false,
    [bool] $IncludeMacOSDevice = $false,
    [bool] $IncludeLinuxDevice = $false,
    [bool] $IncludeAndroidDevice = $false,
    [bool] $IncludeIOSDevice = $false,
    [bool] $IncludeIPadOSDevice = $false
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

# Log the selected OS options
if ($IncludeWindowsDevice) { Write-RjRbLog -Message "Selected OS: Windows" -Verbose }
if ($IncludeMacOSDevice) { Write-RjRbLog -Message "Selected OS: MacOS" -Verbose }
if ($IncludeLinuxDevice) { Write-RjRbLog -Message "Selected OS: Linux" -Verbose }
if ($IncludeAndroidDevice) { Write-RjRbLog -Message "Selected OS: Android" -Verbose }
if ($IncludeIOSDevice) { Write-RjRbLog -Message "Selected OS: iOS" -Verbose }
if ($IncludeIPadOSDevice) { Write-RjRbLog -Message "Selected OS: iPadOS" -Verbose }

Connect-RjRbGraph

# Function to resolve group name to ID
function Resolve-GroupId {
    param (
        [string]$Group
    )
    
    if ($Group -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        return $Group
    } else {
        $resolvedGroups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$Group'" -FollowPaging
        #Write-RjRbLog -Message "Resolved group details: $(ConvertTo-Json $resolvedGroups)" -Verbose
        
        if ($resolvedGroups -is [System.Collections.IEnumerable]) {
            if ($resolvedGroups.Count -eq 1) {
                return $resolvedGroups[0].id
            } elseif ($resolvedGroups.Count -gt 1) {
                throw "Multiple groups found with name '$Group'. Please specify the Object ID."
            } else {
                throw "No group found with name '$Group'."
            }
        } else {
            if ($resolvedGroups.id) {
                return $resolvedGroups.id
            } else {
                throw "No group found with name '$Group'."
            }
        }
    }
}

# Resolve group IDs
$UserGroupId = Resolve-GroupId $UserGroup
$DeviceGroupId = Resolve-GroupId $DeviceGroup

# Get user group members
$UserGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$UserGroupId/members" -FollowPaging

if ($UserGroupMembers.Count -eq 0) {
    Write-RjRbLog -Message "No members found in the user group: $UserGroupId" -Verbose
} else {
    "## Found $($UserGroupMembers.Count) members in the user group: $UserGroupId"
    Write-RjRbLog -Message "Found $($UserGroupMembers.Count) members in the user group: $UserGroupId" -Verbose
}

# Get current devices in the device group
$DeviceGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$DeviceGroupId/members" -FollowPaging
$DeviceGroupMemberIds = $DeviceGroupMembers | ForEach-Object { $_.id }

# Process each user in the user group
foreach ($User in $UserGroupMembers) {
    $UserId = $User.id

    Write-RjRbLog -Message "Retrieving owned devices for user: $($User.displayName), ID: $UserId" -Verbose
    $UserDevices = Invoke-RjRbRestMethodGraph -Resource "/users/$UserId/ownedDevices" -FollowPaging | Where-Object {
        ($IncludeWindowsDevice -and $_.operatingSystem -eq "Windows" -and $_.trustType -eq "AzureAd") -or 
        ($IncludeMacOSDevice -and $_.operatingSystem -eq "MacMDM") -or 
        ($IncludeLinuxDevice -and $_.operatingSystem -eq "Linux") -or 
        ($IncludeAndroidDevice -and $_.operatingSystem -eq "Android") -or 
        ($IncludeIOSDevice -and $_.operatingSystem -eq "iOS") -or
        ($IncludeIPadOSDevice -and $_.operatingSystem -eq "iOS" -and $_.deviceType -eq "iPad")
    }

    if ($UserDevices.Count -eq 0) {
        Write-RjRbLog -Message "No devices found for user: $($User.displayName)" -Verbose
        continue
    } else {
        "## Found $($UserDevices.Count) devices for user: $($User.displayName)"
        Write-RjRbLog -Message "Found $($UserDevices.Count) devices for user: $($User.displayName)" -Verbose
    }

    foreach ($Device in $UserDevices) {
        if ($DeviceGroupMemberIds -notcontains $Device.id) {
            Write-RjRbLog -Message "Adding device $($Device.displayName) of user $($User.displayName) to device group" -Verbose
            $body = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($Device.id)"
            }
            try {
                Invoke-RjRbRestMethodGraph -Resource "/groups/$DeviceGroupId/members/`$ref" -Method POST -Body $body
                "## Successfully added device $($Device.displayName) to device group"
                Write-RjRbLog -Message "Successfully added device $($Device.displayName) to device group" -Verbose
            } catch {
                Write-RjRbLog -Message "Failed to add device $($Device.displayName) to device group. Error: $_" -Verbose
            }
        } else {
            "## Device $($Device.displayName) of user $($User.displayName) already in device group"
            Write-RjRbLog -Message "Device $($Device.displayName) of user $($User.displayName) already in device group" -Verbose
        }
    }
}

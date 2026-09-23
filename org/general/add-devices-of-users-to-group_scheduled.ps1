<#
    .SYNOPSIS
    Add the devices of a user group's members to a device group

    .DESCRIPTION
    Adds the devices of all users in a user group to a device group on every run, so device-based policies can follow user membership. Devices already in the group are skipped, and nothing is removed.

    .PARAMETER UserGroup
    Name or object ID of the group whose members' devices are collected.

    .PARAMETER DeviceGroup
    Name or object ID of the group the devices are added to.

    .PARAMETER IncludeWindowsDevice
    Includes Windows devices.

    .PARAMETER IncludeMacOSDevice
    Includes macOS devices.

    .PARAMETER IncludeLinuxDevice
    Includes Linux devices.

    .PARAMETER IncludeAndroidDevice
    Includes Android devices.

    .PARAMETER IncludeIOSDevice
    Includes iOS devices.

    .PARAMETER IncludeIPadOSDevice
    Includes iPadOS devices.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "UserGroup": {
                "DisplayName": "User group"
            },
            "DeviceGroup": {
                "DisplayName": "Device group"
            },
            "IncludeWindowsDevice": {
                "DisplayName": "Include Windows devices?"
            },
            "IncludeMacOSDevice": {
                "DisplayName": "Include macOS devices?"
            },
            "IncludeLinuxDevice": {
                "DisplayName": "Include Linux devices?"
            },
            "IncludeAndroidDevice": {
                "DisplayName": "Include Android devices?"
            },
            "IncludeIOSDevice": {
                "DisplayName": "Include iOS devices?"
            },
            "IncludeIPadOSDevice": {
                "DisplayName": "Include iPadOS devices?"
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [string] $UserGroup,
    [Parameter(Mandatory = $true)]
    [string] $DeviceGroup,
    [bool] $IncludeWindowsDevice = $false,
    [bool] $IncludeMacOSDevice = $false,
    [bool] $IncludeLinuxDevice = $false,
    [bool] $IncludeAndroidDevice = $false,
    [bool] $IncludeIOSDevice = $false,
    [bool] $IncludeIPadOSDevice = $false,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

############################################################
#region Variables
#
############################################################
    $Version = "1.1.1"
#endregion Variables

############################################################
#region Functions
#
############################################################

    #region Resolve Group Id
    ##############################
    function Resolve-GroupId {
        <#
            .SYNOPSIS
            Resolves a group hint to a single object identifier.
            .DESCRIPTION
            Validates if the provided value already is an object identifier or queries Microsoft Graph by display name.
        #>
        param (
            [Parameter(Mandatory = $true)]
            [string] $Group
        )

        if ($Group -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
            return $Group
        }
        else {
            $resolvedGroups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$Group'" -FollowPaging

            if ($resolvedGroups -is [System.Collections.IEnumerable]) {
                if ($resolvedGroups.Count -eq 1) {
                    return $resolvedGroups[0].id
                }
                elseif ($resolvedGroups.Count -gt 1) {
                    throw "Multiple groups found with name '$Group'. Please specify the Object ID."
                }
                else {
                    throw "No group found with name '$Group'."
                }
            }
            else {
                if ($resolvedGroups.id) {
                    return $resolvedGroups.id
                }
                else {
                    throw "No group found with name '$Group'."
                }
            }
        }
    }
    ##############################
    #endregion Resolve Group Id

    #region Get User Group Members
    ##############################
    function Get-UserGroupMember {
        <#
            .SYNOPSIS
            Retrieves all user members of a group including nested memberships.
            .DESCRIPTION
            Calls the transitiveMembers endpoint with a user cast so nested groups do not stop processing.
        #>
        param (
            [Parameter(Mandatory = $true)]
            [string] $GroupId
        )

        $resourcePath = "/groups/$GroupId/transitiveMembers/microsoft.graph.user"
        $members = Invoke-RjRbRestMethodGraph -Resource $resourcePath -FollowPaging

        if (-not $members) {
            return @()
        }

        return $members
    }
    ##############################
    #endregion Get User Group Members

#endregion Functions

############################################################
#region Main Logic
#
############################################################

    #region Initialization
    ##############################
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
    Write-RjRbLog -Message "Version: $Version" -Verbose

    if ($IncludeWindowsDevice) { Write-RjRbLog -Message "Selected OS: Windows" -Verbose }
    if ($IncludeMacOSDevice) { Write-RjRbLog -Message "Selected OS: MacOS" -Verbose }
    if ($IncludeLinuxDevice) { Write-RjRbLog -Message "Selected OS: Linux" -Verbose }
    if ($IncludeAndroidDevice) { Write-RjRbLog -Message "Selected OS: Android" -Verbose }
    if ($IncludeIOSDevice) { Write-RjRbLog -Message "Selected OS: iOS" -Verbose }
    if ($IncludeIPadOSDevice) { Write-RjRbLog -Message "Selected OS: iPadOS" -Verbose }

    Connect-RjRbGraph
    ##############################
    #endregion Initialization

    #region Resolve Group Identifiers
    ##############################
    $UserGroupId = Resolve-GroupId -Group $UserGroup
    $DeviceGroupId = Resolve-GroupId -Group $DeviceGroup
    ##############################
    #endregion Resolve Group Identifiers

    #region Retrieve Group Members
    ##############################
    $UserGroupMembers = Get-UserGroupMember -GroupId $UserGroupId
    $UserGroupMemberCount = @($UserGroupMembers).Count

    if ($UserGroupMemberCount -eq 0) {
        Write-RjRbLog -Message "No members found in the user group hierarchy: $UserGroupId" -Verbose
    }
    else {
        "## Found $UserGroupMemberCount members in the user group hierarchy: $UserGroupId"
        Write-RjRbLog -Message "Found $UserGroupMemberCount members in the user group hierarchy: $UserGroupId" -Verbose
    }

    $DeviceGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$DeviceGroupId/members" -FollowPaging
    $DeviceGroupMemberIds = $DeviceGroupMembers | ForEach-Object { $_.id }
    ##############################
    #endregion Retrieve Group Members

    #region Process Users
    ##############################
    foreach ($User in $UserGroupMembers) {
        $UserId = $User.id

        Write-RjRbLog -Message "Retrieving owned devices for user: $($User.displayName), ID: $UserId" -Verbose

        $UserDevices = Invoke-RjRbRestMethodGraph -Resource "/users/$UserId/ownedDevices" -FollowPaging | Where-Object {
            # Filter by allowed OS types and trust type if the caller requested specific platforms.
            ($IncludeWindowsDevice -and $_.operatingSystem -eq "Windows" -and $_.trustType -eq "AzureAd") -or
            ($IncludeMacOSDevice -and $_.operatingSystem -eq "MacMDM") -or
            ($IncludeLinuxDevice -and $_.operatingSystem -eq "Linux") -or
            ($IncludeAndroidDevice -and $_.operatingSystem -eq "Android") -or
            ($IncludeAndroidDevice -and $_.operatingSystem -eq "AndroidForWork") -or
            ($IncludeIOSDevice -and ($_.operatingSystem -eq "iOS" -or $_.operatingSystem -eq "IPhone")) -or
            ($IncludeIPadOSDevice -and ($_.operatingSystem -eq "iPadOS" -or $_.operatingSystem -eq "IPad"))
        }

        $UserDeviceCount = @($UserDevices).Count

        if ($UserDeviceCount -eq 0) {
            Write-RjRbLog -Message "No devices found for user: $($User.displayName)" -Verbose
            continue
        }
        else {
            "## Found $UserDeviceCount devices for user: $($User.displayName)"
            Write-RjRbLog -Message "Found $UserDeviceCount devices for user: $($User.displayName)" -Verbose
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
                }
                catch {
                    Write-RjRbLog -Message "Failed to add device $($Device.displayName) to device group. Error: $_" -Verbose
                }
            }
            else {
                "## Device $($Device.displayName) of user $($User.displayName) already in device group"
                Write-RjRbLog -Message "Device $($Device.displayName) of user $($User.displayName) already in device group" -Verbose
            }
        }
    }
    ##############################
    #endregion Process Users

#endregion Main Logic

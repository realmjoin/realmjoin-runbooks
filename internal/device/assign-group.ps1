<#
    .SYNOPSIS
    Add this device and its primary user to Windows 11 upgrade groups

    .DESCRIPTION
    Adds this device to an Entra ID group and, optionally, its primary user from Intune to a second group. Built for self-service Windows 11 upgrades. The groups are usually preset in the runbook customization.

    .PARAMETER DeviceId
    Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

    .PARAMETER AddDeviceToGroup
    Adds the device to the "Device group". Turn off to add only the primary user.

    .PARAMETER GroupID
    Object ID of the group the device is added to. Usually preset in the runbook customization.

    .PARAMETER AddUserToGroup
    Also adds the device's primary user from Intune to the "User group".

    .PARAMETER UserGroupID
    Object ID of the group the primary user is added to. Usually preset in the runbook customization.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "DeviceId": {
                "Hide": true
            },
            "AddDeviceToGroup": {
                "DisplayName": "Add the device to the device group?"
            },
            "GroupID": {
                "DisplayName": "Device group"
            },
            "AddUserToGroup": {
                "DisplayName": "Add the primary user to the user group?"
            },
            "UserGroupID": {
                "DisplayName": "User group"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    # RJ will pass the "DeviceID" != AAD "ObjectID". Be aware :)
    [Parameter(Mandatory = $true)]
    [String] $DeviceId,
    # Add device to a specific group? (Win11 Devices)
    [bool] $AddDeviceToGroup = $true,
    [String] $GroupID = "9d7b59ac-89dd-4b6b-a37a-22a94f886904",
    # Add the prim. user of the device to a specific group? (Win11 Users)
    [bool] $AddUserToGroup = $false,
    [String] $UserGroupID = "9d7b59ac-89dd-4b6b-a37a-22a94f886905",
    # Track
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# "Find the device object "
$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'"
if (-not $targetDevice) {
    throw ("Device ID '$DeviceId' not found.")
}

if ($AddDeviceToGroup) {
    $targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID" -ErrorAction SilentlyContinue
    if (-not $targetGroup) {
        throw ("Group ID '$GroupID' not found.")
    }

    # Work on AzureAD based groups
    if (($targetGroup.GroupTypes -contains "Unified") -or (-not $targetGroup.MailEnabled)) {
        "## Group type: AzureAD"
        # Prepare Request
        $body = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($targetDevice.id)"
        }

        # "Is device member of the the group?"
        if (Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/$($targetDevice.id)" -ErrorAction SilentlyContinue) {
            "## Device '$($targetDevice.DisplayName)' is already a member of '$($targetGroup.DisplayName)'. No action taken."
        }
        else {
            Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/`$ref" -Method Post -Body $body | Out-Null
            "## '$($targetDevice.DisplayName)' is added to '$($targetGroup.DisplayName)'."
        }
    }
    else {
        "## Group '$($targetGroup.DisplayName)' is not an AzureAD group. Exiting."
    }
}

if ($AddUserToGroup) {
    $targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$UserGroupID" -ErrorAction SilentlyContinue
    if (-not $targetGroup) {
        throw ("Group ID '$GroupID' not found.")
    }

    # Work on AzureAD based groups
    if (($targetGroup.GroupTypes -contains "Unified") -or (-not $targetGroup.MailEnabled)) {
        "## Group type: AzureAD"

        $mgdDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
        if (-not $mgdDevice) {
            throw ("Device '$($targetDevice.displayName)' not found in Intune!")
        }
        $targetUserId = $mgdDevice.userId
        if (-not $targetUserId) {
            throw "No primary user found for device '$($targetDevice.displayName)'."
        }

        # Prepare Request
        $body = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$targetUserId"
        }

        # "Is user member of the the group?"
        if (Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/$targetUserId" -ErrorAction SilentlyContinue) {
            "## User '$($mgdDevice.UserPrincipalName)' is already a member of '$($targetGroup.DisplayName)'. No action taken."
        }
        else {
            Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/`$ref" -Method Post -Body $body | Out-Null
            "## '$($mgdDevice.UserPrincipalName)' is added to '$($targetGroup.DisplayName)'."
        }
    }
    else {
        "## Group '$($targetGroup.DisplayName)' is not an AzureAD group. Exiting."
    }
}
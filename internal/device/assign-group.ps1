<#
  .SYNOPSIS
  Add a device to a group.

  .DESCRIPTION
  Add a device to a group. Primarily intended for Windows 11 Self Service upgrades.

  .NOTES
  Permissions: 
  MS Graph (API)
  - Group.ReadWrite.All
  - Directory.ReadWrite.All

  if "UserGroupId"/"AddUserToGroup" is used:
  - DeviceManagementManagedDevices.Read.All

  .EXAMPLE 
          "rjgit-internal_device_assign-group": {
            "Parameters": {
                "AddDeviceToGroup": {
                    "Default": true
                },
                "GroupId": {
                    "Default": "9d7b59ac-89dd-4b6b-a37a-22a94f886904"
                },
                "AddUserToGroup": {
                    "Default": true
                },
                "UserGroupId": {
                    "Default": "9d7b59ac-89dd-4b6b-a37a-22a94f886905"
                }
            }
        }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

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

$Version = "1.0.0"
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
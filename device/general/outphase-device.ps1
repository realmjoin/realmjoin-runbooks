<#
    .SYNOPSIS
    Wipe this Windows device and clean up Intune, Autopilot and Entra ID

    .DESCRIPTION
    Takes this Windows device out of service. You choose whether the device is wiped or only deleted from Intune, and whether it leaves the Autopilot database. Its Entra ID object can be deleted, disabled or kept. Optionally the device is tagged in Microsoft Defender for Endpoint so rules that use the tag can exclude it from automated remediation. A wipe removes all user and enrollment data from the device and cannot be undone.

    .PARAMETER DeviceId
    Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

    .PARAMETER intuneAction
    Completely wipe erases all user and enrollment data on the device. Delete from Intune only removes the device record, for devices that are already wiped or destroyed. Do not wipe or remove leaves Intune untouched.

    .PARAMETER aadAction
    Delete removes the device object from Entra ID, Disable keeps it but blocks sign-ins from the device, and Keep leaves Entra ID untouched.

    .PARAMETER wipeDevice
    Legacy switch kept for compatibility. The choice under "Intune action" decides whether the device is wiped.

    .PARAMETER removeIntuneDevice
    Legacy switch kept for compatibility. The choice under "Intune action" decides whether the Intune record is deleted.

    .PARAMETER removeAutopilotDevice
    Removing the device from the Autopilot database lets it leave the tenant and be registered elsewhere. Keeping it allows a later redeployment in this tenant.

    .PARAMETER removeAADDevice
    Legacy switch kept for compatibility. The choice under "Entra ID object" decides whether the Entra ID object is deleted.

    .PARAMETER disableAADDevice
    Legacy switch kept for compatibility. The choice under "Entra ID object" decides whether the Entra ID object is disabled.

    .PARAMETER excludeFromDefender
    Tags the device in Microsoft Defender for Endpoint with the exclusion tag so rules that use the tag can exclude it from automated remediation. Skip leaves Defender untouched.

    .PARAMETER defenderExclusionTag
    Tag name written to the device in Defender for Endpoint, for use in your exclusion rules.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "DeviceId": {
                "Hide": true
            },
            "intuneAction": {
                "DisplayName": "Intune action",
                "Select": {
                    "Options": [
                        {
                            "Display": "Completely wipe device (not keeping user or enrollment data)",
                            "Value": 2
                        },
                        {
                            "Display": "Delete device from Intune (only if device is already wiped or destroyed)",
                            "Value": 1
                        },
                        {
                            "Display": "Do not wipe or remove device from Intune",
                            "Value": 0
                        }
                    ],
                    "ShowValue": false
                }
            },
            "wipeDevice": {
                "Hide": true
            },
            "removeIntuneDevice": {
                "Hide": true
            },
            "removeAutopilotDevice": {
                "DisplayName": "Delete device from Autopilot database?",
                "SelectSimple": {
                    "Remove from Autopilot (the device can leave the tenant)": true,
                    "Keep the device in Autopilot": false
                }
            },
            "aadAction": {
                "DisplayName": "Entra ID object",
                "Select": {
                    "Options": [
                        {
                            "Display": "Delete device in Entra ID",
                            "Value": 2
                        },
                        {
                            "Display": "Disable device in Entra ID",
                            "Value": 1
                        },
                        {
                            "Display": "Keep the Entra ID device",
                            "Value": 0
                        }
                    ],
                    "ShowValue": false
                }
            },
            "removeAADDevice": {
                "Hide": true
            },
            "disableAADDevice": {
                "Hide": true
            },
            "excludeFromDefender": {
                "DisplayName": "Tag as excluded in Defender for Endpoint?",
                "SelectSimple": {
                    "Tag device as excluded in Defender for Endpoint": true,
                    "Skip Defender operations": false
                }
            },
            "defenderExclusionTag": {
                "DisplayName": "Defender exclusion tag",
                "Default": "ExcludeFromRemediation"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param (
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [int] $intuneAction = 2,
    [int] $aadAction = 2,
    [bool] $wipeDevice = $true,
    [bool] $removeIntuneDevice = $false,
    [bool] $removeAutopilotDevice = $true,
    [bool] $removeAADDevice = $true,
    [bool] $disableAADDevice = $false,
    [bool] $excludeFromDefender = $false,
    [string] $defenderExclusionTag = "ExcludeFromRemediation",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

############################################################
#region RJ Log Part
#
############################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "DeviceId: $DeviceId" -Verbose
Write-RjRbLog -Message "intuneAction: $intuneAction" -Verbose
Write-RjRbLog -Message "aadAction: $aadAction" -Verbose
Write-RjRbLog -Message "removeAutopilotDevice: $removeAutopilotDevice" -Verbose
Write-RjRbLog -Message "excludeFromDefender: $excludeFromDefender" -Verbose
Write-RjRbLog -Message "defenderExclusionTag: $defenderExclusionTag" -Verbose

#endregion RJ Log Part

############################################################
#region Parameter Validation
#
############################################################

# Only modify parameters if "actions" are set to non-default values
switch ($intuneAction) {
    1 {
        $wipeDevice = $false
        $removeIntuneDevice = $true
    }
    0 {
        $wipeDevice = $false
        $removeIntuneDevice = $false
    }
}
switch ($aadAction) {
    1 {
        $removeAADDevice = $false
        $disableAADDevice = $true
    }
    0 {
        $removeAADDevice = $false
        $disableAADDevice = $false
    }
}

#endregion Parameter Validation

############################################################
#region Connect Part
#
############################################################

Connect-RjRbGraph
if ($excludeFromDefender) {
    Connect-RjRbDefenderATP
}

#endregion Connect Part

############################################################
#region StatusQuo & Preflight-Check Part
#
############################################################

# Search for device in Entra ID
$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
if (-not $targetDevice) {
    throw ("DeviceId $DeviceId not found in EntraID.")
}
$owner = Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)/registeredOwners" -ErrorAction SilentlyContinue

"## Outphasing device '$($targetDevice.displayName)' (DeviceId '$DeviceId')"
if ($owner) {
    "## Device owner: '$($owner.UserPrincipalName)'"
}

# Find device in Defender for Endpoint
# From experience - the first result seems to be the "freshest"
if ($excludeFromDefender) {
    $atpDeviceCandidates = Invoke-RjRbRestMethodDefenderATP -Resource "/machines" -OdFilter "aadDeviceId eq $DeviceId" -ErrorAction SilentlyContinue
    if ($atpDeviceCandidates) {
        $atpDevice = $atpDeviceCandidates[0]
        "## Device found in Defender for Endpoint: '$($atpDevice.computerDnsName)' (MDE ID: $($atpDevice.id))"
    }
    else {
        "## Device not found in Defender for Endpoint. Defender exclusion tag will be skipped."
    }
}
else {
    "## Defender operations are disabled. Skipping."
}

#endregion StatusQuo & Preflight-Check Part

############################################################
#region Main Part
#
############################################################

    #region Defender for Endpoint - Exclusion Tag
    ##############################

    if ($atpDevice) {
        "## Adding exclusion tag '$defenderExclusionTag' to device in Defender for Endpoint"
        $tagBody = @{
            Value  = $defenderExclusionTag
            Action = "Add"
        }
        try {
            Invoke-RjRbRestMethodDefenderATP -Method Post -Resource "/machines/$($atpDevice.id)/tags" -Body $tagBody | Out-Null
            "## Successfully added tag '$defenderExclusionTag' to device '$($atpDevice.computerDnsName)' in Defender for Endpoint"
            "## Note: The tag is applied to the device, but it only shows up in the Defender portal's 'Tags' filter once it has been"
            "##       created once via the portal (Device > Manage tags > 'Create new tag'). The tag is effective for automation/"
            "##       remediation rules regardless of this. See https://learn.microsoft.com/defender-endpoint/machine-tags#create-tags"
        }
        catch {
            "## Error Message: $($_.Exception.Message)"
            "## Please see 'All logs' for more details."
            "## Execution stopped."
            throw "Adding Defender exclusion tag to device '$($atpDevice.computerDnsName)' (MDE ID: $($atpDevice.id)) failed!"
        }
    }

    #endregion Defender for Endpoint - Exclusion Tag

    #region Entra ID Operations
    ##############################

    if ($disableAADDevice) {
        # Currently MS Graph only allows to update windows devices when used "as App" (vs "delegated").
        if ($targetDevice.operatingSystem -eq "Windows") {
            "## Disabling $($targetDevice.displayName) (Object ID $($targetDevice.id)) in EntraID"
            try {
                $body = @{
                    "accountEnabled" = $false
                }
                Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method Patch -Body $body | Out-Null
            }
            catch {
                "## Error Message: $($_.Exception.Message)"
                "## Please see 'All logs' for more details."
                "## Execution stopped."
                throw "Disabling Object ID $($targetDevice.id) in EntraID failed!"
            }
        }
        else {
            "## Disabling non-windows devices in EntraID is currently not supported. Skipping."
        }
    }

    if ($removeAADDevice) {
        "## Deleting $($targetDevice.displayName) (Object ID $($targetDevice.id)) from EntraID"
        try {
            Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method Delete | Out-Null
        }
        catch {
            "## Error Message: $($_.Exception.Message)"
            "## Please see 'All logs' for more details."
            "## Execution stopped."
            throw "Deleting Object ID $($targetDevice.id) from EntraID failed!"
        }
    }

    if ((-not $disableAADDevice) -and (-not $removeAADDevice)) {
        "## Skipping EntraID object operations."
    }

    #endregion Entra ID Operations

    #region Intune Operations
    ##############################

    $mgdDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
    if ($mgdDevice) {
        if ($wipeDevice) {
            "## Wiping DeviceId $DeviceID (Intune ID: $($mgdDevice.id))"
            $body = @{
                "keepEnrollmentData" = $false
                "keepUserData"       = $false
            }
            try {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($mgdDevice.id)/wipe" -Method Post -Body $body | Out-Null
            }
            catch {
                "## Error Message: $($_.Exception.Message)"
                "## Please see 'All logs' for more details."
                "## Execution stopped."
                throw "Wiping DeviceID $DeviceID (Intune ID: $($mgdDevice.id)) failed!"
            }
        }
        elseif ($removeIntuneDevice) {
            "## Deleting DeviceId $DeviceID (Intune ID: $($mgdDevice.id)) from Intune"
            try {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($mgdDevice.id)" -Method Delete | Out-Null
            }
            catch {
                "## Error Message: $($_.Exception.Message)"
                "## Please see 'All logs' for more details."
                "## Execution stopped."
                throw "Deleting Intune ID: $($mgdDevice.id) from Intune failed!"
            }
        }
        else {
            "## Skipping Intune operations."
        }
    }
    else {
        "## Device not found in Intune. Skipping."
    }

    #endregion Intune Operations

    #region AutoPilot Operations
    ##############################

    if ($removeAutopilotDevice) {
        $apDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -OdFilter "azureActiveDirectoryDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
        if ($apDevice) {
            "## Deleting DeviceId $DeviceID (Autopilot ID: $($apDevice.id)) from Autopilot"
            try {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$($apDevice.id)" -Method Delete | Out-Null
            }
            catch {
                "## Error Message: $($_.Exception.Message)"
                "## Please see 'All logs' for more details."
                "## Execution stopped."
                throw "Deleting Autopilot ID: $($apDevice.id) from Autopilot failed!"
            }
        }
        else {
            "## Device not found in AutoPilot database. Skipping."
        }
    }
    else {
        "## Skipping AutoPilot operations."
    }

    #endregion AutoPilot Operations

#endregion Main Part

""
"## Device $($targetDevice.displayName) with DeviceId $DeviceId successfully removed/outphased."

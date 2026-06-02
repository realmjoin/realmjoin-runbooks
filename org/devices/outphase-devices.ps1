<#
    .SYNOPSIS
    Remove or outphase multiple devices

    .DESCRIPTION
    This runbook outphases multiple devices based on a comma-separated list of device IDs or serial numbers.
    It can optionally wipe devices in Intune and delete or disable the corresponding Entra ID device objects.
    Optionally, each device can be tagged in Microsoft Defender for Endpoint to mark it as excluded from remediation.
    NOTE: The Exclusion Tag is applied to the device, but it only appears in the Defender portal's "Tags" filter once it has been created once via the portal (Device > Manage tags > "Create new tag").

    .PARAMETER DeviceListChoice
    Determines whether the list contains device IDs or serial numbers.

    .PARAMETER DeviceList
    Comma-separated list of device IDs or serial numbers.

    .PARAMETER intuneAction
    Determines whether to wipe the device, delete it from Intune, or skip Intune actions.

    .PARAMETER aadAction
    Determines whether to delete the Entra ID device, disable it, or skip Entra ID actions.

    .PARAMETER wipeDevice
    Internal flag derived from intuneAction.

    .PARAMETER removeIntuneDevice
    Internal flag derived from intuneAction.

    .PARAMETER removeAutopilotDevice
    "Remove the device from Autopilot" (final value: true) or "Keep device in Autopilot" (final value: false) handles whether to delete the device from the Autopilot database.

    .PARAMETER removeAADDevice
    Internal flag derived from aadAction.

    .PARAMETER disableAADDevice
    Internal flag derived from aadAction.

    .PARAMETER excludeFromDefender
    If set to true, each device will be tagged in Microsoft Defender for Endpoint with the specified exclusion tag. If set to false, the Defender step will be skipped entirely.

    .PARAMETER defenderExclusionTag
    The tag that will be added to the device in Microsoft Defender for Endpoint to mark it as excluded. Defaults to "ExcludeFromRemediation".

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "DeviceListChoice": {
                "DisplayName": "Select list type",
                "Select": {
                    "Options": [
                        {
                            "Display": "Comma separated list by Device IDs",
                            "Value": 0
                        },
                        {
                            "Display": "Comma separated list by Serial Numbers",
                            "Value": 1
                        }
                    ]
                }
            },
            "DeviceList": {
                "DisplayName": "Comma separated list"
            },
            "intuneAction": {
                "DisplayName": "Wipe this device?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Completely wipe device (not keeping user or enrollment data)",
                            "Value": 2
                        },
                        {
                            "Display": "Delete device from Intune",
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
                "DisplayName": "Delete device from Autopilot database",
                "SelectSimple": {
                    "Remove the device from Autopilot": true,
                    "Keep device": false
                }
            },
            "aadAction": {
                "DisplayName": "Delete device from Entra ID?",
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
                            "Display": "Do not delete or disable Entra ID device",
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
                "DisplayName": "Exclude devices from Defender for Endpoint?",
                "SelectSimple": {
                    "Tag devices as excluded in Defender for Endpoint": true,
                    "Skip Defender operations": false
                }
            },
            "defenderExclusionTag": {
                "DisplayName": "Defender Exclusion Tag",
                "Default": "ExcludeFromRemediation"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.6" }

# Suppress false positive from PSScriptAnalyzer - variable is assigned inside ForEach-Object but used in a later if-condition
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "FoundDeviceSerialNotInIntune")]
param (
    [Parameter(Mandatory = $true)]
    [int] $DeviceListChoice = 0,
    [Parameter(Mandatory = $true)]
    [string] $DeviceList,
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

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.2.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "excludeFromDefender: $excludeFromDefender" -Verbose
Write-RjRbLog -Message "defenderExclusionTag: $defenderExclusionTag" -Verbose

# only modify parameters, if "actions" are set to non-default values
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

Connect-RjRbGraph
if ($excludeFromDefender) {
    Connect-RjRbDefenderATP
    "## Note: Defender exclusion tags are applied to the devices, but a tag only shows up in the Defender portal's 'Tags' filter"
    "##       once it has been created once via the portal (Device > Manage tags > 'Create new tag'). The tag is effective for"
    "##       automation/remediation rules regardless of this. See https://learn.microsoft.com/defender-endpoint/machine-tags#create-tags"
    ""
}

$DeviceIds = @()
$FoundDeviceSerialNotInIntune = $false
$DeviceSerialNotInIntune = @()
if ($DeviceListChoice -eq 1) {
    $DeviceList.Split(",") | ForEach-Object {
        $DeviceSerial = $_.Trim()
        if ($DeviceSerial) {
            "## Searching Serialnumber '$DeviceSerial' ..."
            $targetDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "serialNumber eq '$DeviceSerial'" -ErrorAction SilentlyContinue
            if (-not $targetDevice) {
                "## Warning Message: Serialnumber '$DeviceSerial' not found in Intune."
                $FoundDeviceSerialNotInIntune = $true
                $DeviceSerialNotInIntune += $DeviceSerial
            }
            else {
                "## Found device '$($targetDevice.deviceName)' (Serialnumber '$DeviceSerial') with DeviceId $($targetDevice.azureADDeviceId)"
                $DeviceIds += $targetDevice.azureADDeviceId
            }
        }
    }
    $DeviceList = @()
    $DeviceList = $DeviceIds -join ","
}

$DeviceList.Split(",") | ForEach-Object {
    $DeviceId = $_.Trim()
    if ($DeviceId) {
        "## Searching DeviceId '$DeviceID' ..."
        $targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
        if (-not $targetDevice) {
            "## Warning Message: DeviceId '$DeviceId' not found in AzureAD."
            return
        }
        $owner = Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)/registeredOwners" -ErrorAction SilentlyContinue

        "## Outphasing device '$($targetDevice.displayName)' (DeviceId '$DeviceId')"
        if ($owner) {
            "## Device owner: '$($owner.UserPrincipalName)'"
        }

        if ($excludeFromDefender) {
            # Find device in Defender for Endpoint
            # From experience - the first result seems to be the "freshest"
            $atpDeviceCandidates = Invoke-RjRbRestMethodDefenderATP -Resource "/machines" -OdFilter "aadDeviceId eq $DeviceId" -ErrorAction SilentlyContinue
            if ($atpDeviceCandidates) {
                $atpDevice = $atpDeviceCandidates[0]
                "## Device found in Defender for Endpoint: '$($atpDevice.computerDnsName)' (MDE ID: $($atpDevice.id))"
                "## Adding exclusion tag '$defenderExclusionTag' to device in Defender for Endpoint"
                $tagBody = @{
                    Value  = $defenderExclusionTag
                    Action = "Add"
                }
                try {
                    Invoke-RjRbRestMethodDefenderATP -Method Post -Resource "/machines/$($atpDevice.id)/tags" -Body $tagBody | Out-Null
                    "## Successfully added tag '$defenderExclusionTag' to device '$($atpDevice.computerDnsName)' in Defender for Endpoint"
                }
                catch {
                    "## Error Message: $($_.Exception.Message)"
                    "## Please see 'All logs' for more details."
                    "## Warning Message: Adding Defender exclusion tag to device '$($atpDevice.computerDnsName)' (MDE ID: $($atpDevice.id)) failed!"
                }
            }
            else {
                "## Device not found in Defender for Endpoint. Defender exclusion tag will be skipped."
            }
        }

        if ($disableAADDevice) {
            # Currentls MS Graph only allows to update windows devices when used "as App" (vs "delegated").
            if ($targetDevice.operatingSystem -eq "Windows") {
                "## Disabling $($targetDevice.displayName) (Object ID $($targetDevice.id)) in AzureAD"
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
                    "## Warning Message: Disabling Object ID $($targetDevice.id) in AzureAD failed!"
                }
            }
            else {
                "## Disabling non-windows devices in AzureAD is currently not supported. Skipping."
            }
        }

        if ($removeAADDevice) {
            "## Deleting $($targetDevice.displayName) (Object ID $($targetDevice.id)) from AzureAD"
            try {
                Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method Delete | Out-Null
            }
            catch {
                "## Error Message: $($_.Exception.Message)"
                "## Please see 'All logs' for more details."
                "## Execution stopped."
                "## Warning Message: Deleting Object ID $($targetDevice.id) from AzureAD failed!"

            }
        }

        if ((-not $disableAADDevice) -and (-not $removeAADDevice)) {
            "## Skipping AzureAD object operations."
        }

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
                    "## Warning Message: Wiping DeviceID $DeviceID (Intune ID: $($mgdDevice.id)) failed!"
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
                    "## Warning Message: Deleting Intune ID: $($mgdDevice.id) from Intune failed!"
                }
            }
            else {
                "## Skipping Intune operations."
            }
        }
        else {
            "## Device not found in Intune. Skipping."
        }

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
                    "## Warning Message: Deleting Autopilot ID: $($apDevice.id) from Autopilot failed!"
                }
            }
            else {
                "## Device not found in AutoPilot database. Skipping."
            }
        }
        else {
            "## Skipping AutoPilot operations."
        }

        ""
        "## Device $($targetDevice.displayName) with DeviceId $DeviceId successfully removed/outphased."
        ""
    }
}

# If "Remove the device from AutoPilot" and a serialnumber was not found in Intune, search for it in AutoPilot database and remove it from there
if ($removeAutopilotDevice -and $FoundDeviceSerialNotInIntune) {
    foreach ($DeviceSerial in $DeviceSerialNotInIntune) {
        ""
        "## Searching Serialnumber '$DeviceSerial' in AutoPilot database ..."
        $apDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -OdFilter "contains(serialNumber,'$($DeviceSerial)')" -ErrorAction SilentlyContinue
        if ($apDevice) {
            "## Deleting Serialnumber '$DeviceSerial' (Autopilot ID: $($apDevice.id)) from Autopilot"
            try {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$($apDevice.id)" -Method Delete | Out-Null
            }
            catch {
                "## Error Message: $($_.Exception.Message)"
                "## Please see 'All logs' for more details."
                "## Execution stopped."
                "## Warning Message: Deleting Autopilot ID: $($apDevice.id) from Autopilot failed!"
            }
        }
        else {
            "## Serialnumber '$DeviceSerial' not found in AutoPilot database. Skipping."
        }
    }
}
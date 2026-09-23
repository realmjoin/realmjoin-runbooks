<#
    .SYNOPSIS
    Wipe and clean up several devices at once

    .DESCRIPTION
    Takes several devices out of service in one go, given as a list of device IDs or serial numbers. You choose whether the devices are wiped or only deleted from Intune, and whether their Autopilot registration is removed. Their Entra ID objects can be deleted, disabled or kept. Optionally the devices are tagged in Microsoft Defender for Endpoint so rules that use the tag can exclude them from automated remediation. A wipe removes all data and cannot be undone.

    .PARAMETER DeviceListChoice
    Whether the list holds Entra ID device IDs or serial numbers.

    .PARAMETER DeviceList
    Device IDs or serial numbers, separated by commas.

    .PARAMETER intuneAction
    Completely wipe erases all user and enrollment data on the devices. Delete from Intune only removes the device records, for devices that are already wiped or destroyed. Do not wipe or remove leaves Intune untouched.

    .PARAMETER aadAction
    Delete removes the device objects from Entra ID, Disable keeps them but blocks sign-ins from the devices, and Keep leaves Entra ID untouched.

    .PARAMETER wipeDevice
    Legacy switch kept for compatibility. The choice under "Intune action" decides whether the devices are wiped.

    .PARAMETER removeIntuneDevice
    Legacy switch kept for compatibility. The choice under "Intune action" decides whether the Intune records are deleted.

    .PARAMETER removeAutopilotDevice
    Removing the devices from the Autopilot database lets them leave the tenant and be registered elsewhere. Keeping them allows a later redeployment in this tenant.

    .PARAMETER removeAADDevice
    Legacy switch kept for compatibility. The choice under "Entra ID object" decides whether the Entra ID objects are deleted.

    .PARAMETER disableAADDevice
    Legacy switch kept for compatibility. The choice under "Entra ID object" decides whether the Entra ID objects are disabled.

    .PARAMETER excludeFromDefender
    Tags the devices in Microsoft Defender for Endpoint with the exclusion tag so rules that use the tag can exclude them from automated remediation. Skip leaves Defender untouched.

    .PARAMETER defenderExclusionTag
    Tag name written to the devices in Defender for Endpoint, for use in your exclusion rules.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "DeviceListChoice": {
                "DisplayName": "List contains",
                "Select": {
                    "Options": [
                        {
                            "Display": "Device IDs",
                            "Value": 0
                        },
                        {
                            "Display": "Serial numbers",
                            "Value": 1
                        }
                    ]
                }
            },
            "DeviceList": {
                "DisplayName": "Device list"
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
                "DisplayName": "Delete from Autopilot database?",
                "SelectSimple": {
                    "Remove the device from Autopilot": true,
                    "Keep device": false
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
                    "Tag devices as excluded in Defender for Endpoint": true,
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

$Version = "1.2.1"
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
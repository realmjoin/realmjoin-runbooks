<#
  .SYNOPSIS
  Remove/Outphase windows devices in bulk

  .DESCRIPTION
  Remove/Outphase windows devices based on a list of serial numbers. You can choose if you want to wipe the devices and/or delete them from Intune and AutoPilot.

  .NOTES
  PERMISSIONS
   DeviceManagementManagedDevices.PrivilegedOperations.All (Wipe,Retire / seems to allow us to delete from AzureAD)
   DeviceManagementManagedDevices.ReadWrite.All (Delete Intune Device)
   DeviceManagementServiceConfig.ReadWrite.All (Delete Autopilot enrollment)
   Device.Read.All
  ROLES
   Cloud device administrator

  .INPUTS
  RunbookCustomization: {
    
    "Parameters": {
        "SerialNumbers": {
            "DisplayName": "Serial Numbers",
            "Type": "String",
            "IsMultiValue": true,
            "Required": true
        },
        "intuneAction": {
            "DisplayName": "Wipe these devices?",
            "Select": {
                "Options": [
                    {
                        "Display": "Completely wipe devices (not keeping user or enrollment data)",
                        "Value": 2
                    },
                    {
                        "Display": "Delete devices from Intune (only if devices are already wiped or destroyed)",
                        "Value": 1
                    },
                    {
                        "Display": "Do not wipe or remove devices from Intune",
                        "Value": 0
                    }
                ],
                "ShowValue": false
            }
        },
        "wipeDevices": {
            "Hide":true
        },
        "removeIntuneDevices": {
            "Hide":true
        },
        "removeAutopilotDevices": {
            "DisplayName": "Delete devices from AutoPilot database?",
            "SelectSimple": {
                "Remove the devices from AutoPilot (the devices can leave the tenant)": true,
                "Keep devices / do not care": false
            }
        },
        "aadAction": {
            "DisplayName": "Delete devices from AzureAD?",
            "Select": {
                "Options": [
                    {
                        "Display": "Delete devices in AzureAD",
                        "Value": 2
                    },
                    {
                        "Display": "Disable devices in AzureAD",
                        "Value": 1
                    },
                    {
                        "Display": "Do not delete AzureAD devices / do not care",
                        "Value": 0
                    }
                ],
                "ShowValue": false
            }
        },
        "removeAADDevices": {
            "Hide":true
        },
        "disableAADDevices": {
            "Hide":true
        },
        "CallerName": {
            "Hide": true
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param (
    [Parameter(Mandatory = $true)]
    [string[]] $SerialNumbers,
    [int] $intuneAction = 2,
    [int] $aadAction = 2,
    [bool] $wipeDevices = $true,
    [bool] $removeIntuneDevices = $false,
    [bool] $removeAutopilotDevices = $true,
    [bool] $removeAADDevices = $true,
    [bool] $disableAADDevices = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

# only modify parameters, if "actions" are set to non-default values
switch ($intuneAction) {
    1 {
        $wipeDevices = $false
        $removeIntuneDevices = $true
    }
    0 {
        $wipeDevices = $false
        $removeIntuneDevices = $false
    }
}
switch ($aadAction) {
    1 {
        $removeAADDevices = $false
        $disableAADDevices = $true
    } 
    0 {
        $removeAADDevices = $false
        $disableAADDevices = $false
    }
}

Connect-RjRbGraph

foreach ($serialNumber in $SerialNumbers) {
    # Searching Device by Serial Number
    $targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "serialNumber eq '$serialNumber'" -ErrorAction SilentlyContinue
    if (-not $targetDevice) {
        Write-RjRbLog -Message "Device with Serial Number $serialNumber not found in AzureAD." -Verbose
        continue
    }
    $owner = Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)/registeredOwners" -ErrorAction SilentlyContinue

    Write-RjRbLog -Message "## Outphasing device '$($targetDevice.displayName)' (Serial Number '$serialNumber')" -Verbose
    if ($owner) {
        Write-RjRbLog -Message "## Device owner: '$($owner.UserPrincipalName)'" -Verbose
    }

    if ($disableAADDevices) {
        # Currently MS Graph only allows updating windows devices when used "as App" (vs "delegated").
        if ($targetDevice.operatingSystem -eq "Windows") {
            Write-RjRbLog -Message "## Disabling $($targetDevice.displayName) (Object ID $($targetDevice.id)) in AzureAD" -Verbose
            try {
                $body = @{
                    "accountEnabled" = $false
                }
                Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method Patch -Body $body | Out-Null
            }
            catch {
                Write-RjRbLog -Message "## Error Message: $($_.Exception.Message)" -Verbose
                Write-RjRbLog -Message "## Please see 'All logs' for more details." -Verbose
                Write-RjRbLog -Message "## Execution stopped." -Verbose
                throw "Disabling Object ID $($targetDevice.id) in AzureAD failed!" 
            }
        } else {
            Write-RjRbLog -Message "## Disabling non-windows devices in AzureAD is currently not supported. Skipping." -Verbose
        }
    }

    if ($removeAADDevices) {
        Write-RjRbLog -Message "## Deleting $($targetDevice.displayName) (Object ID $($targetDevice.id)) from AzureAD" -Verbose
        try {
            Invoke-RjRbRestMethodGraph -Resource "/devices/$($targetDevice.id)" -Method Delete | Out-Null
        }
        catch {
            Write-RjRbLog -Message "## Error Message: $($_.Exception.Message)" -Verbose
            Write-RjRbLog -Message "## Please see 'All logs' for more details." -Verbose
            Write-RjRbLog -Message "## Execution stopped." -Verbose
            throw "Deleting Object ID $($targetDevice.id) from AzureAD failed!"
        }
    }

    if ((-not $disableAADDevices) -and (-not $removeAADDevices)) {
        Write-RjRbLog -Message "## Skipping AzureAD object operations." -Verbose
    }

    $mgdDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$($targetDevice.id)'" -ErrorAction SilentlyContinue
    if ($mgdDevice) {
        if ($wipeDevices) {
            Write-RjRbLog -Message "## Wiping DeviceId $($targetDevice.id) (Intune ID: $($mgdDevice.id))" -Verbose
            $body = @{
                "keepEnrollmentData" = $false
                "keepUserData"       = $false
            }
            try {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($mgdDevice.id)/wipe" -Method Post -Body $body | Out-Null
            }
            catch {
                Write-RjRbLog -Message "## Error Message: $($_.Exception.Message)" -Verbose
                Write-RjRbLog -Message "## Please see 'All logs' for more details." -Verbose
                Write-RjRbLog -Message "## Execution stopped." -Verbose     
                throw "Wiping DeviceID $($targetDevice.id) (Intune ID: $($mgdDevice.id)) failed!"
            }
        }
        elseif ($removeIntuneDevices) {
            Write-RjRbLog -Message "## Deleting DeviceId $($targetDevice.id) (Intune ID: $($mgdDevice.id)) from Intune" -Verbose
            try {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($mgdDevice.id)" -Method Delete | Out-Null
            }
            catch {
                Write-RjRbLog -Message "## Error Message: $($_.Exception.Message)" -Verbose
                Write-RjRbLog -Message "## Please see 'All logs' for more details." -Verbose
                Write-RjRbLog -Message "## Execution stopped." -Verbose     
                throw "Deleting Intune ID: $($mgdDevice.id) from Intune failed!"
            }
        }
        else {
            Write-RjRbLog -Message "## Skipping Intune operations." -Verbose
        }
    }
    else {
        Write-RjRbLog -Message "## Device not found in Intune. Skipping." -Verbose
    }

    if ($removeAutopilotDevices) {
        $apDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -OdFilter "azureActiveDirectoryDeviceId eq '$($targetDevice.id)'" -ErrorAction SilentlyContinue
        if ($apDevice) {
            Write-RjRbLog -Message "## Deleting DeviceId $($targetDevice.id) (Autopilot ID: $($apDevice.id)) from Autopilot" -Verbose
            try {
                Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities/$($apDevice.id)" -Method Delete | Out-Null
            }
            catch {
                Write-RjRbLog -Message "## Error Message: $($_.Exception.Message)" -Verbose
                Write-RjRbLog -Message "## Please see 'All logs' for more details." -Verbose
                Write-RjRbLog -Message "## Execution stopped." -Verbose     
                throw "Deleting Autopilot ID: $($apDevice.id) from Autopilot failed!"
            }
        }
        else {
            Write-RjRbLog -Message "## Device not found in AutoPilot database. Skipping." -Verbose
        }
    }
    else {
        Write-RjRbLog -Message "## Skipping AutoPilot operations." -Verbose
    }

    Write-RjRbLog -Message "" -Verbose
    Write-RjRbLog -Message "## Device $($targetDevice.displayName) with Serial Number $serialNumber successfully removed/outphased." -Verbose
}

Write-RjRbLog -Message "## Bulk Outphase process completed." -Verbose

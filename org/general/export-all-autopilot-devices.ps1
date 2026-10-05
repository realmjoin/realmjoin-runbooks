<#
    .SYNOPSIS
    List or export all Windows Autopilot devices

    .DESCRIPTION
    Lists every Windows Autopilot registration with its details, either in the run output or as a CSV file uploaded to an Azure Storage account with a time-limited download link. Nothing is changed.

    .PARAMETER ExportToFile
    List in the run output, or export to a CSV file with a download link.

    .PARAMETER ContainerName
    Storage container the CSV file is uploaded to. Taken from the tenant setting IntuneDevicesReport.Container.

    .PARAMETER ResourceGroupName
    Resource group of the storage account. Taken from the tenant setting IntuneDevicesReport.ResourceGroup.

    .PARAMETER StorageAccountName
    Storage account for the export. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Name.

    .PARAMETER StorageAccountLocation
    Azure region used when the storage account has to be created. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Location.

    .PARAMETER StorageAccountSku
    Performance tier used when the storage account has to be created. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Sku.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "ContainerName": {
                "Hide": true
            },
            "ResourceGroupName": {
                "Hide": true
            },
            "StorageAccountName": {
                "Hide": true
            },
            "StorageAccountLocation": {
                "Hide": true
            },
            "StorageAccountSku": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            },
            "ExportToFile": {
                "Select": {
                    "Options": [
                        {
                            "Display": "Export to a CSV file",
                            "ParameterValue": true
                        },
                        {
                            "Display": "List in the run output",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": [
                                    "ContainerName",
                                    "ResourceGroupName",
                                    "StorageAccountName",
                                    "StorageAccountLocation",
                                    "StorageAccountSku"
                                ]
                            }
                        }
                    ],
                    "ShowValue": false
                }
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [bool] $ExportToFile = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

if ((-not $ContainerName)) {
    $ContainerName = "autopilot-devices-list"
}

# "Getting Process configuration"
if ((-not $ResourceGroupName) -or (-not $StorageAccountName) -or (-not $StorageAccountLocation) -or (-not $StorageAccountSku)) {
    $processConfigRaw = Get-AutomationVariable -name "SettingsExports" -ErrorAction SilentlyContinue

    $processConfig = $processConfigRaw | ConvertFrom-Json

    if (-not $ResourceGroupName) {
        $ResourceGroupName = $processConfig.exportResourceGroupName
    }

    if (-not $StorageAccountName) {
        $StorageAccountName = $processConfig.exportStorAccountName
    }

    if (-not $StorageAccountLocation) {
        $StorageAccountLocation = $processConfig.exportStorAccountLocation
    }

    if (-not $StorageAccountSku) {
        $StorageAccountSku = $processConfig.exportStorAccountSKU
    }
}

if ($ExportToFile -and ((-not $ResourceGroupName) -or (-not $StorageAccountName) -or (-not $StorageAccountSku) -or (-not $StorageAccountLocation))) {
    "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
    ""
    "## Configure the following attributes:"
    "## - IntuneDevices.ResourceGroup"
    "## - IntuneDevices.StorageAccount.Name"
    "## - IntuneDevices.StorageAccount.Location"
    "## - IntuneDevices.StorageAccount.Sku"
    ""
    "## Skipping file export."
    $ExportToFile = $false
}

Connect-RjRbGraph

# Get all Autopilot devices
#$SelectString = "id, azureActiveDirectoryDeviceId, managedDeviceId, groupTag, purchaseOrderIdentifier, serialNumber, model, manufacturer, enrollmentState, userPrincipalName, systemFamily"
$APDevices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -Beta -FollowPaging

$Exportdevices = @()

foreach ($apDevice in $APDevices) {
    # Get properties for each device from Intune and AutoPilot
    $result = @{}
    $result["autoPilotId"] = $apDevice.id
    $result["azureActiveDirectoryDeviceId"] = $apDevice.azureActiveDirectoryDeviceId
    $result["managedDeviceId"] = $apDevice.managedDeviceId
    $result["groupTag"] = $apDevice.groupTag
    $result["purchaseOrderIdentifier"] = $apDevice.purchaseOrderIdentifier
    $result["serialNumber"] = $apDevice.serialNumber
    $result["model"] = $apDevice.model
    $result["manufacturer"] = $apDevice.manufacturer
    $result["autoPilotIdEnrollmentState"] = $apDevice.enrollmentState
    #$result["autoPilotIdUserPrincipalName"] = $apDevice.userPrincipalName
    $result["systemFamily"] = $apDevice.systemFamily
    $result["deploymentProfileAssignmentStatus"] = $apDevice.deploymentProfileAssignmentStatus
    $result["remediationState"] = $apDevice.remediationState
    $result["deploymentProfileAssignmentDate"] = $apDevice.deploymentProfileAssignedDateTime
    $result["lastContactedDateTime"] = $apDevice.lastContactedDateTime


    $azureActiveDirectoryDeviceId = $apDevice.azureActiveDirectoryDeviceId
    if ($azureActiveDirectoryDeviceId) {
        $SelectString = "deviceName, lastSyncDateTime, enrolledDateTime, userPrincipalName, id, serialNumber, manufacturer, model, imei, managedDeviceOwnerType, operatingSystem, osVersion, complianceState"
        $IntuneDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$azureActiveDirectoryDeviceId'" -OdSelect $SelectString -FollowPaging
        $result["deviceName"] = $IntuneDevice.deviceName
        $result["intuneLastSyncDateTime"] = $IntuneDevice.lastSyncDateTime
        $result["intuneEnrolledDateTime"] = $IntuneDevice.enrolledDateTime
        $result["UserPrincipalName"] = $IntuneDevice.userPrincipalName
        $result["iemi"] = $IntuneDevice.imei
        $result["managedDeviceOwnerType"] = $IntuneDevice.managedDeviceOwnerType
        $result["operatingSystem"] = $IntuneDevice.operatingSystem
        $result["osVersion"] = $IntuneDevice.osVersion
        $result["complianceState"] = $IntuneDevice.complianceState
    }

    if (-not $ExportToFile) {
        "## AutoPilot Device $($apDevice.id)"
        $tempresult = foreach ($key in $result.keys) {
            "$($key): $($result[$key])"
        }
        $tempresult | Format-List | Out-String
        ""
        #$result | Format-List | Out-String
    }
    else {
        $Exportdevices += $result
    }
}

if ($ExportToFile) {
    try {
        Connect-RjRbAzAccount

        $storAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
        if (-not $storAccount) {
            "## Creating Azure Storage Account $($StorageAccountName)"
            $storAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $StorageAccountLocation -SkuName $StorageAccountSku
        }

        # Get access to the Storage Account
        $keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
        $context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $keys[0].Value

        # Make sure, container exists
        $container = Get-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction SilentlyContinue
        if (-not $container) {
            "## Creating Azure Storage Account Container $($ContainerName)"
            $container = New-AzStorageContainer -Name $ContainerName -Context $context
        }

        $FileName = "$(Get-Date -Format "yyyy-MM-dd")-autopilot-devices.csv"
        #$Exportdevices | ConvertTo-Csv -Delimiter ";" > $FileName
        $ExportDevices | foreach-object {
            New-Object PSObject -Property $_
        } | ConvertTo-Csv -Delimiter ";" > $FileName

        $content = Get-Content -Path $FileName
        set-content -Path $FileName -Value $content -Encoding utf8

        # Upload
        Set-AzStorageBlobContent -File $FileName -Container $ContainerName -Blob $FileName -Context $context -Force | Out-Null

        $EndTime = (Get-Date).AddDays(6)
        $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $FileName -FullUri -ExpiryTime $EndTime

        "## Inactive Devices Export created."
        "## Expiry of Link: $EndTime"
        $SASLink | Out-String
    }
    catch {
        $_
    }
    finally {
        Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
    }
}
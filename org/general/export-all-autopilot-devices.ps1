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
	Resource group of the storage account. Taken from the tenant setting IntuneDevicesReport.ResourceGroup; when it is not set, RJReport.StorageAccount.ResourceGroup is used.

	.PARAMETER StorageAccountName
	Storage account for the export. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Name; when it is not set, RJReport.StorageAccount.StorageAccountName is used.

	.PARAMETER SubscriptionId
	Subscription ID of the storage account given in ResourceGroupName and StorageAccountName. Not taken from a tenant setting; the subscription the managed identity signs in to is used when empty.

	.PARAMETER StorageAccountLocation
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER StorageAccountSku
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER RJReportResourceGroupName
	Resource group of the storage account. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when IntuneDevicesReport.ResourceGroup is not set.

	.PARAMETER RJReportStorageAccountName
	Storage account for the export. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when IntuneDevicesReport.StorageAccount.Name is not set.

	.PARAMETER RJReportSubscriptionId
	Subscription ID of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.SubscriptionId and used when the storage account comes from RJReport.StorageAccount.

	.PARAMETER LinkExpiryDays
	Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

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
			"SubscriptionId": {
				"Hide": true
			},
			"StorageAccountLocation": {
				"Hide": true
			},
			"StorageAccountSku": {
				"Hide": true
			},
			"RJReportResourceGroupName": {
				"Hide": true
			},
			"RJReportStorageAccountName": {
				"Hide": true
			},
			"RJReportSubscriptionId": {
				"Hide": true
			},
			"LinkExpiryDays": {
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
									"SubscriptionId",
									"StorageAccountLocation",
									"StorageAccountSku",
									"RJReportResourceGroupName",
									"RJReportStorageAccountName",
									"RJReportSubscriptionId",
									"LinkExpiryDays"
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [bool] $ExportToFile = $false,
    # Legacy report settings: IntuneDevicesReport.* - rebind to RJReport.StorageAccount.* (ContainerName: unbind) when it is switched off
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    # Legacy report settings: set only explicitly for now - bind to RJReport.StorageAccount.SubscriptionId when it is switched off
    [string] $SubscriptionId,
    # Legacy report settings: deprecated and ignored, kept so existing schedules and API calls keep starting
    [string] $StorageAccountLocation,
    [string] $StorageAccountSku,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
    [string] $RJReportResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
    [string] $RJReportStorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.SubscriptionId" } )]
    [string] $RJReportSubscriptionId,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

########################################################
#region     Parameter Validation
########################################################

if (-not $ContainerName) {
    $ContainerName = "autopilot-devices-list"
}

# Legacy report settings: the Automation variable SettingsExports fills in what IntuneDevicesReport.* leaves empty
if ((-not $ResourceGroupName) -or (-not $StorageAccountName)) {
    $processConfigRaw = Get-AutomationVariable -name "SettingsExports" -ErrorAction SilentlyContinue
    if ($processConfigRaw) {
        $processConfig = $processConfigRaw | ConvertFrom-Json

        if (-not $ResourceGroupName) {
            $ResourceGroupName = $processConfig.exportResourceGroupName
        }

        if (-not $StorageAccountName) {
            $StorageAccountName = $processConfig.exportStorAccountName
        }
    }
}

# Legacy report settings: IntuneDevicesReport.* stays bound to the original parameters, so explicit values, existing schedules
# and API calls behave as before and the legacy settings win. RJReport.StorageAccount.* fills in when neither they nor
# SettingsExports are set.
if (-not ($ResourceGroupName -and $StorageAccountName) -and $RJReportResourceGroupName -and $RJReportStorageAccountName) {
    Write-RjRbLog -Message "Using RJReport.StorageAccount.* - IntuneDevicesReport.* and SettingsExports are not configured" -Verbose
    $ResourceGroupName = $RJReportResourceGroupName
    $StorageAccountName = $RJReportStorageAccountName
    $SubscriptionId = $RJReportSubscriptionId
}

# Legacy report settings: remove with StorageAccountLocation / StorageAccountSku in the switch-off release
if ($PSBoundParameters.ContainsKey('StorageAccountLocation') -or $PSBoundParameters.ContainsKey('StorageAccountSku')) {
    $deprecationMessage = "StorageAccountLocation and StorageAccountSku are deprecated and ignored - the storage account is no longer created automatically. Re-create this schedule or drop both parameters from the API call; a later version removes them."
    Write-RjRbLog -Message "WARNING: $deprecationMessage"
    Write-Warning $deprecationMessage
}

if ($ExportToFile -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
    ""
    "## Configure the following attributes (see https://docs.realmjoin.com/automation/runbooks/runbook-report-settings):"
    "## - RJReport.StorageAccount.ResourceGroup"
    "## - RJReport.StorageAccount.StorageAccountName"
    "## The runbook-specific IntuneDevicesReport.ResourceGroup and IntuneDevicesReport.StorageAccount.Name are still read and take precedence."
    ""
    "## Skipping file export."
    $ExportToFile = $false
}

#endregion Parameter Validation

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

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
if ($ExportToFile) {
    # The local file name becomes the blob name, so uploads keep the blob names of earlier versions
    $reportFile = Join-Path ([System.IO.Path]::GetTempPath()) "$(Get-Date -Format "yyyy-MM-dd")-autopilot-devices.csv"
    $ExportDevices | foreach-object {
        New-Object PSObject -Property $_
    } | ConvertTo-Csv -Delimiter ";" > $reportFile

    $content = Get-Content -Path $reportFile
    set-content -Path $reportFile -Value $content -Encoding utf8
    $reportFiles += $reportFile
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################

if ($ExportToFile) {
    try {
        Connect-RjRbAzAccount

        Write-RjRbLog -Message "Upload" -Verbose
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths $reportFiles `
            -ContainerName $ContainerName `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -SubscriptionId $SubscriptionId `
            -LinkExpiryDays $LinkExpiryDays `
            -AddBlobNamePrefix $false

        foreach ($uploadResult in $uploadResults) {
            "## Autopilot Devices Export created."
            "## Expiry of Link: $($uploadResult.EndTime)"
            $uploadResult.SASLink | Out-String
        }
    }
    catch {
        Write-RjRbLog -Message "Upload to storage account '$StorageAccountName' failed: $($_.Exception.Message). The managed identity needs the 'Reader and Data Access' role on the storage account." -Verbose
        $_
    }
    finally {
        Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
    }
}

#endregion Upload / Download Link

########################################################
#region     Cleanup
########################################################

foreach ($reportFile in $reportFiles) {
    Remove-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
}

#endregion Cleanup
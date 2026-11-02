<#
	.SYNOPSIS
	List devices with no recent sign-in or Intune sync

	.DESCRIPTION
	Lists the devices whose last Intune sync, or whose last sign-in recorded in Entra ID, is older than the chosen number of days. The result can be shown in the run output or exported as a CSV file to an Azure Storage account. Nothing is changed.

	.PARAMETER Days
	Devices with no sync or sign-in for at least this many days are listed.

	.PARAMETER Sync
	Last Intune sync looks at managed devices and their last check-in; Last sign-in looks at Entra ID device objects and their approximate last sign-in date.

	.PARAMETER ExportToFile
	List in the run output, or export to a CSV file in the storage account configured in the tenant settings.

	.PARAMETER ContainerName
	Storage container the report files are uploaded to. Taken from the tenant setting InactiveDevices.Container, otherwise set per runbook.

	.PARAMETER ResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting InactiveDevices.ResourceGroup; when it is not set, the Automation variable SettingsExports is read, then RJReport.StorageAccount.ResourceGroup.

	.PARAMETER StorageAccountName
	Storage account for report uploads. Taken from the tenant setting InactiveDevices.StorageAccount.Name; when it is not set, the Automation variable SettingsExports is read, then RJReport.StorageAccount.StorageAccountName.

	.PARAMETER SubscriptionId
	Subscription ID of the storage account given in ResourceGroupName and StorageAccountName. Not taken from a tenant setting; the subscription the managed identity signs in to is used when empty.

	.PARAMETER StorageAccountLocation
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER StorageAccountSku
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER RJReportResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when neither InactiveDevices.ResourceGroup nor the Automation variable SettingsExports sets one.

	.PARAMETER RJReportStorageAccountName
	Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when neither InactiveDevices.StorageAccount.Name nor the Automation variable SettingsExports sets one.

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
			"Sync": {
				"DisplayName": "Measure inactivity by",
				"Select": {
					"Options": [
						{
							"Display": "Last Intune sync",
							"ParameterValue": true
						},
						{
							"Display": "Last sign-in",
							"ParameterValue": false
						}
					],
					"ShowValue": false
				}
			},
			"CallerName": {
				"Hide": true
			},
			"ExportToFile": {
				"DisplayName": "Output",
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
    [ValidateScript( { Use-RJInterface -DisplayName "Inactive for at least (days)" } )]
    [int] $Days = 30,
    [ValidateScript( { Use-RJInterface -DisplayName "Measure inactivity by" } )]
    [bool] $Sync = $true,
    [bool] $ExportToFile = $false,
    # Legacy report settings: InactiveDevices.* - rebind to RJReport.StorageAccount.* (ContainerName: unbind) when it is switched off
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "InactiveDevices.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "InactiveDevices.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "InactiveDevices.StorageAccount.Name" } )]
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

if ((-not $ContainerName) -and $Sync) {
    $ContainerName = "stale-sync-device-list"
}
elseif (-not $ContainerName) {
    $ContainerName = "stale-login-device-list"
}

# Legacy report settings: fallback to the Az Automation variable SettingsExports, as in earlier versions
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

# Legacy report settings: InactiveDevices.* stays bound to the original parameters, so explicit values, existing schedules
# and API calls behave as before and the legacy settings win, followed by SettingsExports. RJReport.StorageAccount.* fills in
# when neither is set.
if (-not ($ResourceGroupName -and $StorageAccountName) -and $RJReportResourceGroupName -and $RJReportStorageAccountName) {
    Write-RjRbLog -Message "Using RJReport.StorageAccount.* - InactiveDevices.* and SettingsExports are not configured" -Verbose
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
    "## The runbook-specific InactiveDevices.ResourceGroup and InactiveDevices.StorageAccount.Name are still read and take precedence."
    ""
    "## Skipping file export."
    $ExportToFile = $false
}

#endregion Parameter Validation

Connect-RjRbGraph

# Calculate "last sign in date"
$beforedate = (Get-Date).AddDays(-$Days) | Get-Date -Format "yyyy-MM-dd"
$filter = 'approximateLastSignInDateTime le ' + $beforedate + 'T00:00:00Z'

$Exportdevices = @()
if ($Sync) {
    $SelectString = "deviceName, lastSyncDateTime, enrolledDateTime, userPrincipalName, id, serialNumber, manufacturer, model, imei, managedDeviceOwnerType, operatingSystem, osVersion, complianceState"
    $filter = 'lastSyncDateTime le ' + $beforedate + 'T00:00:00Z'
    "## Listing inactive devices (no Intune sync since at least $Days days)"
    ""
    $Devices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdSelect $SelectString -OdFilter $filter -FollowPaging
}
else {
    $SelectString = "displayName,deviceId,approximateLastSignInDateTime,createdDateTime,id,manufacturer,model,deviceOwnership,operatingSystem,operatingSystemVersion,isCompliant"
    $filter = 'approximateLastSignInDateTime le ' + $beforedate + 'T00:00:00Z'
    "## Listing inactive devices (no SignIn since at least $Days days)"
    ""
    $Devices = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter $filter -OdSelect $SelectString -FollowPaging
}

foreach ($Device in $Devices) {
    $primaryOwner = $null
    if ($Sync) {
        try {
            $primaryOwner = Invoke-RjRbRestMethodGraph -Resource "/Users/$($Device.userPrincipalName)" -OdSelect "city, country, department, usageLocation"
        }
        catch {
            "## User '$($Device.userPrincipalName)' not found. Maybe deleted?"
        }
    }
    else {
        try {
            $primaryOwner = Invoke-RjRbRestMethodGraph -Resource "/devices/$($Device.id)/registeredOwners" -OdSelect "userPrincipalName,city,department,usageLocation"
        }
        catch {
            "## Querying registered owners failed. Skipping."
        }
    }
    $Exportdevice = @()
    $Exportdevice += $Device
    if ($primaryOwner) {
        if (!$Sync) {
            $Exportdevice | Add-Member -Name "userPrincipalName" -Value $primaryOwner.userPrincipalName -MemberType "NoteProperty"
        }
        $Exportdevice | Add-Member -Name "city" -Value $primaryOwner.city -MemberType "NoteProperty"
        $Exportdevice | Add-Member -Name "country" -Value $primaryOwner.country -MemberType "NoteProperty"
        $Exportdevice | Add-Member -Name "department" -Value $primaryOwner.department -MemberType "NoteProperty"
        $Exportdevice | Add-Member -Name "usageLocation" -Value $primaryOwner.usageLocation -MemberType "NoteProperty"
    }
    $Exportdevices += $Exportdevice
}

if (-not $ExportToFile) {
    if ($Sync) {
        $Exportdevices | Sort-Object -Property lastSyncDateTime | Format-Table -AutoSize -Property @{name = "LastSync"; expression = { get-date $_.lastSyncDateTime -Format yyyy-MM-dd } }, @{name = "deviceName"; expression = { if ($_.deviceName.Length -gt 15) { $_.deviceName.substring(0, 14) + ".." } else { $_.deviceName } } }, userPrincipalName, @{name = "serialNumber"; expression = { if ($_.serialNumber.Length -gt 15) { $_.serialNumber.substring(0, 14) + ".." } else { $_.serialNumber } } }, manufacturer, model, complianceState | Out-String
    }
    else {
        $Exportdevices | Sort-Object -Property approximateLastSignInDateTime | Format-Table -AutoSize -Property @{name = "LastSignIn"; expression = { get-date $_.approximateLastSignInDateTime -Format yyyy-MM-dd } }, @{name = "displayName"; expression = { if ($_.displayName.Length -gt 15) { $_.displayName.substring(0, 14) + ".." } else { $_.displayName } } }, deviceId, manufacturer, model, isCompliant  | Out-String
    }
}

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
if ($ExportToFile) {
    # The local file name becomes the blob name, so uploads keep the blob names of earlier versions
    if ($Sync) {
        $FileName = "$(Get-Date -Format "yyyy-MM-dd")-stale-sync-devices.csv"
    }
    else {
        $FileName = "$(Get-Date -Format "yyyy-MM-dd")-stale-login-devices.csv"
    }
    $reportFile = Join-Path ([System.IO.Path]::GetTempPath()) $FileName
    $Exportdevices | ConvertTo-Csv -Delimiter ";" > $reportFile
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
            "## Inactive Devices Export created."
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

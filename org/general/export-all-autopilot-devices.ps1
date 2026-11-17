<#
	.SYNOPSIS
	List or export all Windows Autopilot devices

	.DESCRIPTION
	Lists every Windows Autopilot registration with its details in the Output Data tables of the run. The list can also be exported as a CSV file to an Azure Storage account with a time-limited download link. Nothing is changed.

	.PARAMETER ExportToFile
	The list is always shown in the Output Data tables of the run. "Also export to a CSV file" also uploads it as a CSV file and returns a download link.

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
							"Display": "Also export to a CSV file",
							"ParameterValue": true
						},
						{
							"Display": "Output Data only",
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
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }
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

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "ExportToFile: $ExportToFile" -Verbose
Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
Write-RjRbLog -Message "SubscriptionId: $SubscriptionId" -Verbose
Write-RjRbLog -Message "StorageAccountLocation: $StorageAccountLocation" -Verbose
Write-RjRbLog -Message "StorageAccountSku: $StorageAccountSku" -Verbose
Write-RjRbLog -Message "RJReportResourceGroupName: $RJReportResourceGroupName" -Verbose
Write-RjRbLog -Message "RJReportStorageAccountName: $RJReportStorageAccountName" -Verbose
Write-RjRbLog -Message "RJReportSubscriptionId: $RJReportSubscriptionId" -Verbose
Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose

#endregion RJ Log Part

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

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response. Logs progress for slow or
        large pulls and surfaces Graph errors with the failing URI for easier troubleshooting.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/healthOverviews".

        .EXAMPLE
        PS C:\> $allIssues = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/issues"
    #>
    param(
        [string]$Uri
    )

    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    $pageCount = 0

    do {
        try {
            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to retrieve paged data from '$nextLink': $($_.Exception.Message)" -ErrorAction Continue
            throw
        }

        $pageCount++
        if ($response.value) {
            $allResults.AddRange([object[]]$response.value)
        }

        if ($pageCount % 5 -eq 0) {
            Write-RjRbLog -Message "Pagination progress: $pageCount pages, $($allResults.Count) items retrieved so far" -Verbose
        }

        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    if ($pageCount -gt 1) {
        Write-RjRbLog -Message "Pagination complete: $pageCount pages, $($allResults.Count) total items" -Verbose
    }

    return $allResults.ToArray()
}

function ConvertTo-DisplayValue {
    <#
        .SYNOPSIS
        Turns a report value into the text shown in the Output Data table.

        .DESCRIPTION
        Timestamps become "yyyy-MM-dd HH:mm:ss", several values (an Autopilot device linked to more than one
        Intune device) are joined with ", " and empty values are left out.

        .PARAMETER Value
        The value as stored for the CSV export.
    #>
    param(
        $Value
    )

    $parts = @(foreach ($item in @($Value)) {
            if ($null -eq $item -or "$item" -eq "") { continue }
            if ($item -is [datetime]) { $item.ToString("yyyy-MM-dd HH:mm:ss") } else { "$item" }
        })
    return ($parts -join ", ")
}

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

Write-RjRbLog -Message "Connecting to Microsoft Graph" -Verbose
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity is configured correctly. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

# Invoke-MgGraphRequest returns PSCustomObjects in the property order of the Graph response, as the earlier RunbookHelper calls did;
# the default is removed again after the collection
$PSDefaultParameterValues['Invoke-MgGraphRequest:OutputType'] = 'PSObject'
try {
    # Get all Autopilot devices
    $APDevices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"
    Write-RjRbLog -Message "Autopilot devices retrieved: $(@($APDevices).Count)" -Verbose

    $IntuneSelectString = "deviceName,lastSyncDateTime,enrolledDateTime,userPrincipalName,id,serialNumber,manufacturer,model,imei,managedDeviceOwnerType,operatingSystem,osVersion,complianceState"
    $Exportdevices = @()

    foreach ($apDevice in $APDevices) {
        # Get properties for each device from Intune and Autopilot
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
        $result["systemFamily"] = $apDevice.systemFamily
        $result["deploymentProfileAssignmentStatus"] = $apDevice.deploymentProfileAssignmentStatus
        $result["remediationState"] = $apDevice.remediationState
        $result["deploymentProfileAssignmentDate"] = $apDevice.deploymentProfileAssignedDateTime
        $result["lastContactedDateTime"] = $apDevice.lastContactedDateTime

        $azureActiveDirectoryDeviceId = $apDevice.azureActiveDirectoryDeviceId
        if ($azureActiveDirectoryDeviceId) {
            $intuneFilter = [uri]::EscapeDataString("azureADDeviceId eq '$azureActiveDirectoryDeviceId'")
            $IntuneDevice = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=$intuneFilter&`$select=$IntuneSelectString"
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

        $Exportdevices += $result
    }
}
catch {
    # Fail the run: without a catch, an error that only ends its statement would leave the collection incomplete
    throw
}
finally {
    $PSDefaultParameterValues.Remove('Invoke-MgGraphRequest:OutputType')
}

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

# One row per Autopilot device for the Output Data table, with the column names of the CSV export
$deviceColumns = @(
    'serialNumber', 'deviceName', 'UserPrincipalName', 'groupTag', 'purchaseOrderIdentifier', 'manufacturer', 'model', 'systemFamily',
    'autoPilotIdEnrollmentState', 'deploymentProfileAssignmentStatus', 'deploymentProfileAssignmentDate', 'remediationState',
    'lastContactedDateTime', 'intuneEnrolledDateTime', 'intuneLastSyncDateTime', 'managedDeviceOwnerType', 'operatingSystem',
    'osVersion', 'complianceState', 'iemi', 'autoPilotId', 'azureActiveDirectoryDeviceId', 'managedDeviceId'
)
$deviceRows = @(foreach ($exportDevice in $Exportdevices) {
        $row = [ordered]@{}
        foreach ($column in $deviceColumns) {
            $row[$column] = ConvertTo-DisplayValue -Value $exportDevice[$column]
        }
        [PSCustomObject]$row
    })

$linkedCount = @($deviceRows | Where-Object { $_.deviceName }).Count

#endregion Data Processing

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

$uploadError = $null
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
        # The upload is the delivery of this runbook: remove the local report files, write the Output Data, then fail the job
        foreach ($reportFile in $reportFiles) {
            Remove-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
        }
        $uploadError = $_
    }
    finally {
        Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
    }
}

#endregion Upload / Download Link

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the progress output. Every table has its own
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
Write-Output ""

$summaryRows = @(
    [PSCustomObject]@{ Metric = "Autopilot devices"; Value = "$($deviceRows.Count)" }
    [PSCustomObject]@{ Metric = "Linked to an Intune device"; Value = "$linkedCount" }
    [PSCustomObject]@{ Metric = "Without an Intune device"; Value = "$($deviceRows.Count - $linkedCount)" }
)
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($deviceRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Autopilot devices" })
    Write-Output $deviceRows
}
else {
    Write-Output "No Autopilot devices found."
}

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################

foreach ($reportFile in $reportFiles) {
    Remove-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
}
if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

# Fail the run only now that the Output Data is written and the sessions are closed
if ($uploadError) {
    throw $uploadError
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup
<#
	.SYNOPSIS
	List devices with no recent sign-in or Intune sync

	.DESCRIPTION
	Lists the devices whose last Intune sync, or whose last sign-in recorded in Entra ID, is older than the chosen number of days. The result is shown in the Output Data tables of the run and can also be exported as a CSV file to an Azure Storage account. Nothing is changed.

	.PARAMETER Days
	Devices with no sync or sign-in for at least this many days are listed.

	.PARAMETER Sync
	Last Intune sync looks at managed devices and their last check-in; Last sign-in looks at Entra ID device objects and their approximate last sign-in date.

	.PARAMETER ExportToFile
	The list is always shown in the Output Data tables of the run. "Also export to a CSV file" also uploads it as a CSV file to the storage account configured in the tenant settings and returns a download link.

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
				"SelectSimple": {
					"Last Intune sync": true,
					"Last sign-in": false
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

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Days: $Days" -Verbose
Write-RjRbLog -Message "Sync: $Sync" -Verbose
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

function Format-ReportDate {
    <#
        .SYNOPSIS
        Formats a Graph timestamp as "yyyy-MM-dd" for the Output Data table, or returns an empty string.

        .PARAMETER Value
        The timestamp as returned by Graph (DateTime or ISO 8601 string).
    #>
    param(
        $Value
    )

    if ($null -eq $Value -or "$Value" -eq "") { return "" }
    try {
        return ([datetime]$Value).ToString("yyyy-MM-dd")
    }
    catch {
        return "$Value"
    }
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

# Calculate "last sign in date"
$beforedate = (Get-Date).AddDays(-$Days) | Get-Date -Format "yyyy-MM-dd"

# Invoke-MgGraphRequest returns PSCustomObjects in the property order of the Graph response, as the earlier RunbookHelper calls did,
# so the CSV keeps its columns; the default is removed again after the collection
$PSDefaultParameterValues['Invoke-MgGraphRequest:OutputType'] = 'PSObject'
try {
    if ($Sync) {
        $SelectString = "deviceName,lastSyncDateTime,enrolledDateTime,userPrincipalName,id,serialNumber,manufacturer,model,imei,managedDeviceOwnerType,operatingSystem,osVersion,complianceState"
        $filter = 'lastSyncDateTime le ' + $beforedate + 'T00:00:00Z'
        "## Listing inactive devices (no Intune sync since at least $Days days)"
        ""
        $Devices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=$SelectString&`$filter=$([uri]::EscapeDataString($filter))"
    }
    else {
        $SelectString = "displayName,deviceId,approximateLastSignInDateTime,createdDateTime,id,manufacturer,model,deviceOwnership,operatingSystem,operatingSystemVersion,isCompliant"
        $filter = 'approximateLastSignInDateTime le ' + $beforedate + 'T00:00:00Z'
        "## Listing inactive devices (no SignIn since at least $Days days)"
        ""
        $Devices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=$([uri]::EscapeDataString($filter))&`$select=$SelectString"
    }

    $Exportdevices = @()
    foreach ($Device in $Devices) {
        $primaryOwner = $null
        if ($Sync) {
            try {
                $ownerResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString([string]$Device.userPrincipalName))?`$select=city,country,department,usageLocation" -Method GET -ErrorAction Stop
                # As with the earlier RunbookHelper call, a collection response is unwrapped to its items: a device without a
                # primary user addresses /users itself
                $primaryOwner = if ($ownerResponse.PSObject.Properties['value']) { $ownerResponse.value } else { $ownerResponse }
            }
            catch {
                "## User '$($Device.userPrincipalName)' not found. Maybe deleted?"
            }
        }
        else {
            try {
                $primaryOwner = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/devices/$($Device.id)/registeredOwners?`$select=userPrincipalName,city,department,usageLocation"
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

# Output Data rows: the columns of the earlier run output table, oldest activity first, names no longer shortened
if ($Sync) {
    $inactivityText = "Last Intune sync"
    $deviceRows = @($Exportdevices | Sort-Object -Property lastSyncDateTime | Select-Object -Property @{ Name = "LastSync"; Expression = { Format-ReportDate -Value $_.lastSyncDateTime } }, deviceName, userPrincipalName, serialNumber, manufacturer, model, complianceState)
}
else {
    $inactivityText = "Last sign-in"
    $deviceRows = @($Exportdevices | Sort-Object -Property approximateLastSignInDateTime | Select-Object -Property @{ Name = "LastSignIn"; Expression = { Format-ReportDate -Value $_.approximateLastSignInDateTime } }, displayName, deviceId, manufacturer, model, isCompliant)
}

#endregion Data Processing

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
            "## Inactive Devices Export created."
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
    [PSCustomObject]@{ Metric = "Inactivity measured by"; Value = $inactivityText }
    [PSCustomObject]@{ Metric = "Inactive for at least (days)"; Value = "$Days" }
    [PSCustomObject]@{ Metric = "No activity since"; Value = $beforedate }
    [PSCustomObject]@{ Metric = "Inactive devices"; Value = "$($deviceRows.Count)" }
)
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($deviceRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Inactive devices" })
    Write-Output $deviceRows
}
else {
    Write-Output "No inactive devices found."
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

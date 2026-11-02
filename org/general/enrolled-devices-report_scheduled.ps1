<#
	.SYNOPSIS
	Report first-time device enrollments of the last weeks

	.DESCRIPTION
	Lists devices that enrolled for the first time within the chosen number of weeks. They are grouped by an attribute of your choice, such as country or department, so you can see where new devices show up. The report can be exported as CSV to an Azure Storage account and downloaded from there.

	.PARAMETER Weeks
	How many weeks back to look for first enrollments.

	.PARAMETER dataSource
	Date of Autopilot profile assignment counts a device from the day its Autopilot profile was assigned, Date of Intune enrollment from the day it enrolled in Intune.

	.PARAMETER groupingSource
	Where the grouping attribute comes from: no grouping, Entra ID user or device properties, Intune device properties, or Autopilot device properties.

	.PARAMETER groupingAttribute
	Name of the attribute the devices are grouped by, for example country or department.

	.PARAMETER exportCsv
	Uploads the report as CSV to the storage account and returns a download link. Needs a configured storage account.

	.PARAMETER ContainerName
	Storage container the report is uploaded to. Taken from the tenant setting EnrolledDevicesReport.Container, otherwise set per runbook.

	.PARAMETER ResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting EnrolledDevicesReport.ResourceGroup; when it is not set, RJReport.StorageAccount.ResourceGroup is used.

	.PARAMETER StorageAccountName
	Storage account for report uploads. Taken from the tenant setting EnrolledDevicesReport.StorageAccount.Name; when it is not set, RJReport.StorageAccount.StorageAccountName is used.

	.PARAMETER SubscriptionId
	Subscription ID of the storage account given in ResourceGroupName and StorageAccountName. Not taken from a tenant setting; the subscription the managed identity signs in to is used when empty.

	.PARAMETER StorageAccountLocation
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER StorageAccountSku
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER RJReportResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when EnrolledDevicesReport.ResourceGroup is not set.

	.PARAMETER RJReportStorageAccountName
	Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when EnrolledDevicesReport.StorageAccount.Name is not set.

	.PARAMETER RJReportSubscriptionId
	Subscription ID of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.SubscriptionId and used when the storage account comes from RJReport.StorageAccount.

	.PARAMETER LinkExpiryDays
	Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"ParameterList": [
			{
				"Name": "Weeks",
				"DisplayName": "Time range (weeks)"
			},
			{
				"Name": "dataSource",
				"DisplayName": "First enrollment criterion",
				"SelectSimple": {
					"Date of Autopilot profile assignment": 0,
					"Date of Intune enrollment": 1
				}
			},
			{
				"Name": "groupingSource",
				"DisplayName": "Group by data from",
				"Select": {
					"Options": [
						{
							"Display": "No grouping",
							"ParameterValue": 0,
							"Customization": {
								"Hide": [
									"groupingAttribute"
								]
							}
						},
						{
							"Display": "Entra ID user properties",
							"ParameterValue": 1,
							"Customization": {
								"Default": {
									"groupingAttribute": "country"
								}
							}
						},
						{
							"Display": "Entra ID device properties",
							"ParameterValue": 2,
							"Customization": {
								"Default": {
									"groupingAttribute": "accountEnabled"
								}
							}
						},
						{
							"Display": "Intune device properties",
							"ParameterValue": 3,
							"Customization": {
								"Default": {
									"groupingAttribute": "manufacturer"
								}
							}
						},
						{
							"Display": "Autopilot device properties",
							"ParameterValue": 4,
							"Customization": {
								"Default": {
									"groupingAttribute": "groupTag"
								}
							}
						}
					],
					"ShowValue": false
				}
			},
			{
				"Name": "exportCsv",
				"DisplayName": "Export as CSV?"
			},
			{
				"Name": "groupingAttribute",
				"DisplayName": "Attribute to group by"
			},
			{
				"Name": "ContainerName",
				"Hide": true
			},
			{
				"Name": "ResourceGroupName",
				"Hide": true
			},
			{
				"Name": "StorageAccountName",
				"Hide": true
			},
			{
				"Name": "SubscriptionId",
				"Hide": true
			},
			{
				"Name": "StorageAccountLocation",
				"Hide": true
			},
			{
				"Name": "StorageAccountSku",
				"Hide": true
			},
			{
				"Name": "RJReportResourceGroupName",
				"Hide": true
			},
			{
				"Name": "RJReportStorageAccountName",
				"Hide": true
			},
			{
				"Name": "RJReportSubscriptionId",
				"Hide": true
			},
			{
				"Name": "LinkExpiryDays",
				"Hide": true
			},
			{
				"Name": "CallerName",
				"Hide": true
			}
		]
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
  [int] $Weeks = 4,
  ## Where to look for a devices "birthday"?
  # 0 - AutoPilot profile assignment date
  # 1 - Intune object creation date
  [int] $dataSource = 0,
  ## How to group results?
  # 0 - no grouping
  # 1 - EntraID User properties
  # 2 - EntraID Device properties
  # 3 - Intune device properties
  # 4 - AutoPilot properties
  [int] $groupingSource = 1,
  # Examples:
  #
  # Autopilot:
  # - "groupTag"
  # - "systemFamily"
  # - "skuNumber"
  #
  # EntraID User:
  # - "city"
  # - "companyName"
  # - "department"
  # - "officeLocation"
  # - "preferredLanguage"
  # - "state"
  # - "usageLocation"
  # - "manager"?
  #
  # EntraID Device:
  # - "manufacturer"
  # - "model"
  #
  # Intune Device:
  # - "isEncrypted"
  [string] $groupingAttribute = "country",
  # StorageAccount info, if exporting a CSV
  [bool] $exportCsv = $true,
  # Legacy report settings: EnrolledDevicesReport.* - rebind to RJReport.StorageAccount.* (ContainerName: unbind) when it is switched off
  [ValidateScript( { Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.Container" } )]
  [string] $ContainerName,
  [ValidateScript( { Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.ResourceGroup" } )]
  [string] $ResourceGroupName,
  [ValidateScript( { Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.StorageAccount.Name" } )]
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

# Legacy report settings: EnrolledDevicesReport.* stays bound to the original parameters, so explicit values, existing schedules
# and API calls behave as before and the legacy settings win. RJReport.StorageAccount.* fills in when they are not set.
if (-not ($ResourceGroupName -and $StorageAccountName) -and $RJReportResourceGroupName -and $RJReportStorageAccountName) {
  Write-RjRbLog -Message "Using RJReport.StorageAccount.* - EnrolledDevicesReport.* is not configured" -Verbose
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

if ($exportCsv -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
  "## To export to a CSV, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
  ""
  "## Configure the following attributes (see https://docs.realmjoin.com/automation/runbooks/runbook-report-settings):"
  "## - RJReport.StorageAccount.ResourceGroup"
  "## - RJReport.StorageAccount.StorageAccountName"
  "## The runbook-specific EnrolledDevicesReport.ResourceGroup and EnrolledDevicesReport.StorageAccount.Name are still read and take precedence."
  ""
  "## Disabling CSV export."
  $exportCsv = $false
  ""
}

#endregion Parameter Validation

Connect-RjRbGraph

# find cutoff point in time
$date = (Get-Date) - (New-TimeSpan -Days ($Weeks * 7))

# Get AutoPilot-Devices newer than cutoff
# $devices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -Beta | Where-Object { ([datetime]$_.deploymentProfileAssignedDateTime) -ge $date }
try {
  $devices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -Beta

  $data = $devices | ForEach-Object {
    if (($dataSource -eq 1) -or (([datetime]$_.deploymentProfileAssignedDateTime) -ge $date)) {
      # Only process this device if either Intune datasource is used, or Autopilot assignment is not too old.
      $intuneDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($_.managedDeviceId)" -ErrorAction SilentlyContinue
      if (($dataSource -eq 0) -or ($intuneDevice -and ([datetime]$intuneDevice.enrolledDateTime) -ge $date)) {
        # Only process this device if either Autopilot datasource is used, or Intune enrollment is not too old.
        $output = [PSCustomObject]@{
          apDevice           = $_
          intuneDevice       = $intuneDevice
          Serial             = $_.serialNumber
          User               = ""
          Model              = $_.model
          APAssignmentDate   = (get-date -Date ($_.deploymentProfileAssignedDateTime) -Format "yyyy-MM-ddTHH:mmK" )
          IntuneEnrolledDate = ""
          $groupingAttribute = ""
        }
        if ($intuneDevice) {
          $output.IntuneEnrolledDate = (get-date -Date ($intuneDevice.enrolledDateTime) -Format "yyyy-MM-ddTHH:mmK" )
          if ($intuneDevice.userPrincipalName) {
            $output.User = $intuneDevice.userPrincipalName
          }
        }

        # Take this device into account / print data
        $output
      }
    }
  }

  $sortingAttribute = "APAssignmentDate"
  if ($groupingSource -eq 1) {
    $sortingAttribute = "IntuneEnrolledDate"
  }

  "## Grouping by:"

  if ($groupingSource -eq 0) {
    "## - no grouping"
    ""
    $data | Sort-Object -Property $sortingAttribute | Format-Table -AutoSize -Property "Serial", "User", "Model", $sortingAttribute | Out-String

  }

  if ($groupingSource -eq 1) {
    "## - EntraID User: $groupingAttribute"
    ""
    $data | ForEach-Object {
      if ($_.intuneDevice -and $_.intuneDevice.userId ) {
        $azureADUser = Invoke-RjRbRestMethodGraph -Resource "/users/$($_.intuneDevice.userId)" -OdSelect $groupingAttribute -ErrorAction SilentlyContinue

        if ($azureADUser) {
          $_.$groupingAttribute = $azureADUser.$groupingAttribute
        }

        $_
      }
    } | Sort-Object -Property $groupingAttribute, $sortingAttribute | Format-Table -AutoSize -Property "Serial", "User", "Model", $sortingAttribute -GroupBy $groupingAttribute | Out-String
  }

  if ($groupingSource -eq 2) {
    "## - EntraID Device: $groupingAttribute"
    ""
    $data | ForEach-Object {
      $azureADDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$($_.apDevice.azureAdDeviceId)'" -ErrorAction SilentlyContinue

      if ($azureADDevice) {
        $_.$groupingAttribute = $azureADDevice.$groupingAttribute
      }

      $_
    } | Sort-Object -Property $groupingAttribute, $sortingAttribute | Format-Table -AutoSize -Property "Serial", "User", "Model", $sortingAttribute -GroupBy $groupingAttribute | Out-String
  }

  if ($groupingSource -eq 3) {
    "## - Intune Device: $groupingAttribute"
    ""
    $data | ForEach-Object {
      if ($_.intuneDevice) {
        $_.$groupingAttribute = $_.intuneDevice.$groupingAttribute
      }

      $_
    } | Sort-Object -Property $groupingAttribute, $sortingAttribute | Format-Table -AutoSize -Property "Serial", "User", "Model", $sortingAttribute -GroupBy $groupingAttribute | Out-String
  }

  if ($groupingSource -eq 4) {
    "## - AutoPilot Device: $groupingAttribute"
    ""
    $data | ForEach-Object {
      $_.$groupingAttribute = $_.apDevice.$groupingAttribute

      $_
    } | Sort-Object -Property $groupingAttribute, $sortingAttribute | Format-Table -AutoSize -Property "Serial", "User", "Model", $sortingAttribute -GroupBy $groupingAttribute | Out-String
  }
}
catch {
  "## Something went wrong. Probably missing MS Graph API permissions."
  write-error $_
  throw ("failed")
}

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
if ($exportCsv) {
  # The local file name becomes the blob name, so uploads keep the blob name of earlier versions
  $reportFile = Join-Path ([System.IO.Path]::GetTempPath()) "enrolled-devices.csv"
  if ($groupingSource -eq 0) {
    $data | Sort-Object -Property $sortingAttribute | Select-Object -Property "Serial", "User", "Model", $sortingAttribute | ConvertTo-Csv -NoTypeInformation -Delimiter ";" > $reportFile
  }
  else {
    $data | Sort-Object -Property $groupingAttribute, $sortingAttribute | Select-Object -Property "Serial", "User", "Model", $sortingAttribute, $groupingAttribute | ConvertTo-Csv -NoTypeInformation -Delimiter ";" > $reportFile
  }
  $content = Get-Content -Path $reportFile
  Set-Content -Path $reportFile -Value $content -Encoding UTF8
  $reportFiles += $reportFile

  ""
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################

if ($exportCsv) {
  # An upload error fails the run with the same output as before, when the upload was part of the Graph block
  try {
    Connect-RjRbAzAccount

    if (-not $ContainerName) {
      $ContainerName = "enrolled-devices-$($Weeks)w-" + (get-date -Format "yyyy-MM-dd")
    }

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
      ""
      "## Enrolled devices CSV report created."
      "## Expiry of Link: $($uploadResult.EndTime)"
      $uploadResult.SASLink | Out-String
    }
  }
  catch {
    Write-RjRbLog -Message "Upload to storage account '$StorageAccountName' failed: $($_.Exception.Message). The managed identity needs the 'Reader and Data Access' role on the storage account." -Verbose
    "## Something went wrong. Probably missing MS Graph API permissions."
    write-error $_
    throw ("failed")
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

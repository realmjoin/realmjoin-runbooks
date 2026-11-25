<#
	.SYNOPSIS
	Report recent first-time enrollments of Windows Autopilot devices

	.DESCRIPTION
	Lists Windows devices registered in Autopilot that enrolled for the first time within the chosen number of weeks. They are grouped by an attribute of your choice, such as country or department, so you can see where new devices show up. iOS, Android and macOS devices and Windows devices enrolled without Autopilot are not included. The report can be exported as CSV to an Azure Storage account and downloaded from there.

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
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }
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

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Weeks: $Weeks" -Verbose
Write-RjRbLog -Message "dataSource: $dataSource" -Verbose
Write-RjRbLog -Message "groupingSource: $groupingSource" -Verbose
Write-RjRbLog -Message "groupingAttribute: $groupingAttribute" -Verbose
Write-RjRbLog -Message "exportCsv: $exportCsv" -Verbose
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

# The grouping attribute becomes a property of its own next to the fixed properties of a device row, so it cannot be empty
# or take one of their names (Serial, User and Model are handled separately). Without grouping it is not used.
if ($groupingSource -ne 0) {
  $reservedGroupingAttributes = @("apDevice", "intuneDevice", "APAssignmentDate", "IntuneEnrolledDate")
  if ([string]::IsNullOrEmpty($groupingAttribute) -or ($groupingAttribute -in $reservedGroupingAttributes)) {
    Write-Error "The attribute to group by ('$groupingAttribute') cannot be used: it must not be empty or one of the names the report uses itself ($($reservedGroupingAttributes -join ', ')). Enter the name of a property of the chosen object, for example country, department, manufacturer or groupTag." -ErrorAction Continue
    throw "Invalid attribute to group by: '$groupingAttribute'"
  }
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

function Test-GraphNotFound {
  <#
    .SYNOPSIS
    Tells whether a failed Invoke-MgGraphRequest call was answered with 404 Not Found.
  #>
  param(
    [System.Management.Automation.ErrorRecord]$ErrorRecord
  )

  $response = $ErrorRecord.Exception.Response
  if ($response -and $response.StatusCode) {
    return ([int]$response.StatusCode -eq 404)
  }
  return ($ErrorRecord.Exception.Message -match 'NotFound|\b404\b')
}

function Add-LookupFailure {
  <#
    .SYNOPSIS
    Records a per-device Graph lookup that failed for another reason than "not found" and writes it to the log.
  #>
  param(
    [string]$Lookup,
    [string]$Permission,
    [System.Management.Automation.ErrorRecord]$ErrorRecord
  )

  $lookupFailures.Add([PSCustomObject]@{
      Lookup     = $Lookup
      Permission = $Permission
      Message    = $ErrorRecord.Exception.Message
    })
  Write-RjRbLog -Message "Lookup failed - $($Lookup): $($ErrorRecord.Exception.Message)" -Verbose
}

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

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

# find cutoff point in time
$date = (Get-Date) - (New-TimeSpan -Days ($Weeks * 7))

# Per-device lookups that fail for another reason than "not found" (e.g. 403, 429, 5xx); the run fails after delivery
$lookupFailures = [System.Collections.Generic.List[object]]::new()

# Invoke-MgGraphRequest returns PSCustomObjects in the property order of the Graph response, as the earlier RunbookHelper
# calls did, so properties are read the same way (case-insensitive); the default is removed again after each block
$PSDefaultParameterValues['Invoke-MgGraphRequest:OutputType'] = 'PSObject'
try {
  # Get all AutoPilot-Devices (filtered by the cutoff below)
  $devices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"

  $data = $devices | ForEach-Object {
    $apDevice = $_
    if (($dataSource -eq 1) -or (([datetime]$apDevice.deploymentProfileAssignedDateTime) -ge $date)) {
      # Only process this device if either Intune datasource is used, or Autopilot assignment is not too old.
      # A device without Intune object (404) counts as not enrolled, as before; any other error is recorded.
      $intuneDevice = $null
      if ($apDevice.managedDeviceId) {
        try {
          $intuneDevice = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$($apDevice.managedDeviceId)" -Method GET -ErrorAction Stop
        }
        catch {
          $intuneDevice = $null
          if (-not (Test-GraphNotFound -ErrorRecord $_)) {
            Add-LookupFailure -Lookup "Intune device of serial '$($apDevice.serialNumber)'" -Permission "DeviceManagementManagedDevices.Read.All" -ErrorRecord $_
          }
        }
      }
      if (($dataSource -eq 0) -or ($intuneDevice -and ([datetime]$intuneDevice.enrolledDateTime) -ge $date)) {
        # Only process this device if either Autopilot datasource is used, or Intune enrollment is not too old.
        $output = [PSCustomObject]@{
          apDevice           = $apDevice
          intuneDevice       = $intuneDevice
          Serial             = $apDevice.serialNumber
          User               = ""
          Model              = $apDevice.model
          APAssignmentDate   = (get-date -Date ($apDevice.deploymentProfileAssignedDateTime) -Format "yyyy-MM-ddTHH:mmK" )
          IntuneEnrolledDate = ""
        }
        if ($groupingSource -ne 0) {
          $output | Add-Member -NotePropertyName $groupingAttribute -NotePropertyValue ""
        }
        if ($intuneDevice) {
          $output.IntuneEnrolledDate = (get-date -Date ($intuneDevice.enrolledDateTime) -Format "yyyy-MM-ddTHH:mmK" )
          if ($intuneDevice.userPrincipalName) {
            $output.User = $intuneDevice.userPrincipalName
          }
        }

        # Take this device into account
        $output
      }
    }
  }
}
catch {
  "## Something went wrong. Probably missing MS Graph API permissions."
  write-error $_
  throw ("failed")
}
finally {
  $PSDefaultParameterValues.Remove('Invoke-MgGraphRequest:OutputType')
}

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

$PSDefaultParameterValues['Invoke-MgGraphRequest:OutputType'] = 'PSObject'
try {
  $sortingAttribute = "APAssignmentDate"
  if ($groupingSource -eq 1) {
    $sortingAttribute = "IntuneEnrolledDate"
  }

  "## Grouping by:"

  if ($groupingSource -eq 0) {
    "## - no grouping"
    ""
  }

  if ($groupingSource -eq 1) {
    "## - EntraID User: $groupingAttribute"
    ""
    foreach ($entry in $data) {
      if ($entry.intuneDevice -and $entry.intuneDevice.userId ) {
        $azureADUser = $null
        try {
          $azureADUser = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($entry.intuneDevice.userId)?`$select=$([System.Uri]::EscapeDataString($groupingAttribute))" -Method GET -ErrorAction Stop
        }
        catch {
          # A deleted user (404) leaves the attribute empty, as before; any other error is recorded
          $azureADUser = $null
          if (-not (Test-GraphNotFound -ErrorRecord $_)) {
            Add-LookupFailure -Lookup "User of serial '$($entry.Serial)' (attribute '$groupingAttribute')" -Permission "User.Read.All" -ErrorRecord $_
          }
        }

        if ($azureADUser) {
          $entry.$groupingAttribute = $azureADUser.$groupingAttribute
        }
      }
    }
  }

  if ($groupingSource -eq 2) {
    "## - EntraID Device: $groupingAttribute"
    ""
    foreach ($entry in $data) {
      $azureADDevice = $null
      try {
        $deviceFilter = [System.Uri]::EscapeDataString("deviceId eq '$($entry.apDevice.azureAdDeviceId)'")
        $deviceResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=$deviceFilter" -Method GET -ErrorAction Stop
        # Unrolled as before: no match gives nothing, a single match the device itself
        $azureADDevice = $deviceResponse.value | ForEach-Object { $_ }
      }
      catch {
        $azureADDevice = $null
        Add-LookupFailure -Lookup "Entra ID device of serial '$($entry.Serial)'" -Permission "Device.ReadWrite.All" -ErrorRecord $_
      }

      if ($azureADDevice) {
        $entry.$groupingAttribute = $azureADDevice.$groupingAttribute
      }
    }
  }

  if ($groupingSource -eq 3) {
    "## - Intune Device: $groupingAttribute"
    ""
    foreach ($entry in $data) {
      if ($entry.intuneDevice) {
        $entry.$groupingAttribute = $entry.intuneDevice.$groupingAttribute
      }
    }
  }

  if ($groupingSource -eq 4) {
    "## - AutoPilot Device: $groupingAttribute"
    ""
    foreach ($entry in $data) {
      $entry.$groupingAttribute = $entry.apDevice.$groupingAttribute
    }
  }
}
catch {
  "## Something went wrong. Probably missing MS Graph API permissions."
  write-error $_
  throw ("failed")
}
finally {
  $PSDefaultParameterValues.Remove('Invoke-MgGraphRequest:OutputType')
}

if ($lookupFailures.Count -gt 0) {
  $lookupWarning = "$($lookupFailures.Count) device lookup(s) in Microsoft Graph failed, so the report is incomplete: devices may be missing or have empty columns. The report is delivered, then the run fails."
  Write-RjRbLog -Message "WARNING: $lookupWarning"
  Write-Warning $lookupWarning
}

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
$reportDir = $null
if ($exportCsv) {
  # A folder of its own keeps concurrent runs on one Hybrid Worker apart. The local file name becomes the blob name,
  # so uploads keep the blob name of earlier versions.
  $reportDir = Join-Path ([System.IO.Path]::GetTempPath()) "enrolled-devices-report-$([guid]::NewGuid())"
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
  $reportFile = Join-Path $reportDir "enrolled-devices.csv"
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
    # The run fails, but the report with serial numbers and user names does not stay behind on the worker
    Remove-Item -LiteralPath $reportDir -Recurse -Force -ErrorAction SilentlyContinue
    write-error $_
    throw ("failed")
  }
}

#endregion Upload / Download Link

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the progress output. Every table has its own
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
Write-Output ""

# Same rows, columns and order as the CSV export
if ($groupingSource -eq 0) {
  $deviceRows = @($data | Sort-Object -Property $sortingAttribute | Select-Object -Property "Serial", "User", "Model", $sortingAttribute)
}
else {
  $deviceRows = @($data | Sort-Object -Property $groupingAttribute, $sortingAttribute | Select-Object -Property "Serial", "User", "Model", $sortingAttribute, $groupingAttribute)
}

$criterionText = switch ($dataSource) {
  0 { "Date of Autopilot profile assignment" }
  1 { "Date of Intune enrollment" }
  default { "$dataSource" }
}
$groupingText = switch ($groupingSource) {
  0 { "No grouping" }
  1 { "Entra ID user properties: $groupingAttribute" }
  2 { "Entra ID device properties: $groupingAttribute" }
  3 { "Intune device properties: $groupingAttribute" }
  4 { "Autopilot device properties: $groupingAttribute" }
  default { "$groupingSource" }
}
$groupRows = @()
if ($groupingSource -ne 0 -and $deviceRows.Count -gt 0) {
  # One row per group in the order of the device table; an empty or missing attribute value is shown as "(not set)"
  $groupRows = @($deviceRows | Group-Object -Property { "$($_.$groupingAttribute)" } | ForEach-Object {
      $groupRow = [ordered]@{}
      $groupRow[$groupingAttribute] = if ([string]::IsNullOrEmpty($_.Name)) { "(not set)" } else { $_.Name }
      $groupRow["Device count"] = $_.Count
      [PSCustomObject]$groupRow
    })
}

$summaryValues = [ordered]@{
  "Time range (weeks)"         = $Weeks
  "First enrollment criterion" = $criterionText
  "Grouped by"                 = $groupingText
  "Enrolled devices"           = $deviceRows.Count
}
if ($groupingSource -ne 0) { $summaryValues["Groups"] = $groupRows.Count }
if ($lookupFailures.Count -gt 0) { $summaryValues["Failed device lookups"] = $lookupFailures.Count }
$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
    [PSCustomObject]@{ Metric = $metric; Value = "$($summaryValues[$metric])" }
  })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($deviceRows.Count -gt 0) {
  Write-Output ([PSCustomObject]@{ RjTableTitle = "Enrolled devices" })
  Write-Output $deviceRows

  if ($groupRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Devices per group" })
    Write-Output $groupRows
  }
}
elseif ($lookupFailures.Count -gt 0) {
  Write-Output "No first-time enrollments found in the last $Weeks week(s), but $($lookupFailures.Count) device lookup(s) failed, so the result is incomplete."
}
else {
  Write-Output "No first-time enrollments in the last $Weeks week(s)."
}

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################

foreach ($reportFile in $reportFiles) {
  Remove-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
}
if ($reportDir) {
  Remove-Item -LiteralPath $reportDir -Recurse -Force -ErrorAction SilentlyContinue
}

if (Get-MgContext -ErrorAction SilentlyContinue) {
  Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

# Failed lookups leave the delivered report incomplete, so the run ends as failed
if ($lookupFailures.Count -gt 0) {
  $missingPermissions = ($lookupFailures | Select-Object -ExpandProperty Permission -Unique) -join ", "
  $failureMessage = "$($lookupFailures.Count) device lookup(s) in Microsoft Graph failed, so the report is incomplete. First error - $($lookupFailures[0].Lookup): $($lookupFailures[0].Message)"
  $failureMessage += " A 403 Forbidden means the managed identity is missing a Graph permission ($missingPermissions); other errors are usually temporary, so run the report again."
  Write-Error $failureMessage -ErrorAction Continue
  throw "Device lookups failed - the report is incomplete."
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

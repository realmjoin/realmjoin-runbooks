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
  Storage container the report is uploaded to. Taken from the tenant setting EnrolledDevicesReport.Container.

  .PARAMETER ResourceGroupName
  Resource group of the storage account. Taken from the tenant setting EnrolledDevicesReport.ResourceGroup.

  .PARAMETER StorageAccountName
  Storage account for the export. Taken from the tenant setting EnrolledDevicesReport.StorageAccount.Name.

  .PARAMETER StorageAccountLocation
  Azure region used when the storage account has to be created. Taken from the tenant setting EnrolledDevicesReport.StorageAccount.Location.

  .PARAMETER StorageAccountSku
  Performance tier used when the storage account has to be created. Taken from the tenant setting EnrolledDevicesReport.StorageAccount.Sku.

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
        "Name": "StorageAccountLocation",
        "Hide": true
      },
      {
        "Name": "StorageAccountSku",
        "Hide": true
      },
      {
        "Name": "CallerName",
        "Hide": true
      }
    ]
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

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
  [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.Container" } )]
  [string] $ContainerName,
  [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.ResourceGroup" } )]
  [string] $ResourceGroupName,
  [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.StorageAccount.Name" } )]
  [string] $StorageAccountName,
  [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.StorageAccount.Location" } )]
  [string] $StorageAccountLocation,
  [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.StorageAccount.Sku" } )]
  [string] $StorageAccountSku,
  # CallerName is tracked purely for auditing purposes
  [Parameter(Mandatory = $true)]
  [string] $CallerName

)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Sanity checks
if ($exportCsv -and ((-not $ResourceGroupName) -or (-not $StorageAccountLocation) -or (-not $StorageAccountName) -or (-not $StorageAccountSku))) {
  "## To export to a CSV, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
  ""
  "## Please configure the following attributes in the RJ central datastore:"
  "## - EnrolledDevicesReport.ResourceGroup"
  "## - EnrolledDevicesReport.StorageAccount.Name"
  "## - EnrolledDevicesReport.StorageAccount.Location"
  "## - EnrolledDevicesReport.StorageAccount.Sku"
  ""
  "## Disabling CSV export."
  $exportCsv = $false
  ""
}

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

  if ($exportCsv) {
    Connect-RjRbAzAccount

    if (-not $ContainerName) {
      $ContainerName = "enrolled-devices-$($Weeks)w-" + (get-date -Format "yyyy-MM-dd")
    }

    if ($groupingSource -eq 0) {
      $data | Sort-Object -Property $sortingAttribute | Select-Object -Property "Serial", "User", "Model", $sortingAttribute | ConvertTo-Csv -NoTypeInformation -Delimiter ";" > enrolled-devices.csv
    }
    else {
      $data | Sort-Object -Property $groupingAttribute, $sortingAttribute | Select-Object -Property "Serial", "User", "Model", $sortingAttribute, $groupingAttribute | ConvertTo-Csv -NoTypeInformation -Delimiter ";" > enrolled-devices.csv
    }

    ""

    # Make sure storage account exists
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

    # Upload
    $content = get-content -Path "enrolled-devices.csv"
    Set-Content -Path "enrolled-devices.csv" -Value $content -Encoding UTF8
    Set-AzStorageBlobContent -File "enrolled-devices.csv" -Container $ContainerName -Blob "enrolled-devices.csv" -Context $context -Force | Out-Null

    #Create signed (SAS) link
    $EndTime = (Get-Date).AddDays(6)
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob "enrolled-devices.csv" -FullUri -ExpiryTime $EndTime

    ""
    "## Enrolled devices CSV report created."
    "## Expiry of Link: $EndTime"
    $SASLink | Out-String

  }
}
catch {
  "## Something went wrong. Probably missing MS Graph API permissions."
  write-error $_
  throw ("failed")
}

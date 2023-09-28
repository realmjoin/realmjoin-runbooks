<#
  .SYNOPSIS
  Show recent first-time device enrollments.

  .DESCRIPTION
  Show recent first-time device enrollments, grouped by a category/attribute.

  .PARAMETER exportCsv
  Please configure an Azure Storage Account to use this feature.

  .NOTES
  Permissions: 
  MS Graph (API):
  - DeviceManagementServiceConfig.Read.All
  - DeviceManagementManagedDevices.Read.All
  - User.Read.All
  - Device.ReadWrite.All
  Azure Subscription (for Storage Account)
  - Contributor on Storage Account


  .EXAMPLE
  Example of Azure Storage Account configuration for RJ central datastore
  {
    "Settings": {
        "EnrolledDevicesReport": {
            "ResourceGroup": "rj-test-runbooks-01",
            "StorageAccount": {
                "Name": "rjrbexports01",
                "Location": "West Europe",
                "Sku": "Standard_LRS"
            }
        }
    }
  }

  .INPUTS
  RunbookCustomization: {
    "ParameterList": [
        {
            "Name": "Weeks",
            "DisplayName": "Time range (in weeks)"
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
            "DisplayName": "Data source for the grouping attribute",
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
                        "Display": "AzureAD User properties",
                        "ParameterValue": 1,
                        "Customization": {
                            "Default": {
                                "groupingAttribute": "country"
                            }
                        }
                    },
                    {
                        "Display": "AzureAD Device properties",
                        "ParameterValue": 2,
                        "Customization": {
                            "Default": {
                                "groupingAttribute": "accountEnabled"
                            }
                        }
                    },
                    {
                        "Display": "Intune Device properties",
                        "ParameterValue": 3,
                        "Customization": {
                            "Default": {
                                "groupingAttribute": "manufacturer"
                            }
                        }
                    },
                    {
                        "Display": "AutoPilot Device properties",
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
            "DisplayName": "Export report as downloadable CSV?"
        },
        {
            "Name": "groupingAttribute",
            "DisplayName": "Attribute/Category to group by"
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
  [int] $Weeks = 4,
  ## Where to look for a devices "birthday"?
  # 0 - AutoPilot profile assignment date
  # 1 - Intune object creation date
  [int] $dataSource = 0,
  ## How to group results?
  # 0 - no grouping
  # 1 - AzureAD User properties
  # 2 - AzureAD Device properties
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
  # AzureAD User:
  # - "city"
  # - "companyName"
  # - "department"
  # - "officeLocation"
  # - "preferredLanguage"
  # - "state"
  # - "usageLocation"
  # - "manager"?
  #
  # AzureAD Device:
  # - "manufacturer"
  # - "model"
  #
  # Intune Device:
  # - "isEncrypted"
  [string] $groupingAttribute = "country",
  # StorageAccount info, if exporting a CSV
  [bool] $exportCsv = $true,
  [ValidateScript( { Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.Container" } )]
  [string] $ContainerName,
  [ValidateScript( { Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.ResourceGroup" } )]
  [string] $ResourceGroupName,
  [ValidateScript( { Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.StorageAccount.Name" } )]
  [string] $StorageAccountName,
  [ValidateScript( { Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.StorageAccount.Location" } )]
  [string] $StorageAccountLocation,
  [ValidateScript( { Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.StorageAccount.Sku" } )]
  [string] $StorageAccountSku,
  # CallerName is tracked purely for auditing purposes
  [Parameter(Mandatory = $true)]
  [string] $CallerName

)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

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
    "## - AzureAD User: $groupingAttribute"
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
    "## - AzureAD Device: $groupingAttribute"
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

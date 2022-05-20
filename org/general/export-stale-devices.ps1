<#
  .SYNOPSIS
  List devices which haven't Synced with Intune or had a login in a certain number of Days.

  .DESCRIPTION
  List devices which haven't Synced with Intune or had a login in a certain number of Days.

  .NOTES
  Permissions
   MS Graph (API): 
   - DeviceManagementManagedDevices.Read.All

  .INPUTS
  RunbookCustomization: {
      "Parameters": { 
          "Sync": {
              "DisplayName": "Last Login or Last Intune Sync"
              "Select":{
                  Options:[
                      {
                          "Display": "Show by Last Intune Sync",
                          "ParameterValue": true,
                          "Customization": {
                                "Hide": [
                                    "CallerName",
                                    "Sync"
                                ]
                            }
                      },
                      {
                          "Display": "Show by Last Login",
                          "ParameterValue": false,
                          "Customization": {
                                "Hide": [
                                    "CallerName",
                                    "Sync"
                                ]
                            }
                      },
                  ],
                  "ShowValue": false
              }
          },
          "CallerName": {
                "Hide": true
          }
        }
    }

#>
#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param (
    [ValidateScript( { Use-RJInterface -DisplayName "Number of days without Contact before a Device is considered Stale" } )]
    [int] $Days,
    [ValidateScript( { Use-RJInterface -DisplayName "Last Login or Last Intune Sync" } )]
    [bool] $Sync = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "Devices.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "Devices.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "Devices.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "Devices.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "Devices.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

if ((-not $ContainerName) -and $Sync) {
    $ContainerName = "stale-sync-device-list-" + (get-date -Format "yyyy-MM-dd")
}
elseif (-not $ContainerName) {
    $ContainerName = "stale-login-device-list-" + (get-date -Format "yyyy-MM-dd")
}
$beforedate = (Get-Date).AddDays(-$Days) | Get-Date -Format "yyyy-MM-dd"

Connect-RjRbGraph
Connect-RjRbAzAccount
try {
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

    if ((-not $ResourceGroupName) -or (-not $StorageAccountName) -or (-not $StorageAccountSku) -or (-not $StorageAccountLocation)) {
        "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
        "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
        ""
        "## Configure the following attributes:"
        "## - Devices.ResourceGroup"
        "## - Devices.StorageAccount.Name"
        "## - Devices.StorageAccount.Location"
        "## - Devices.StorageAccount.Sku"
        ""
        "## Stopping execution."
        throw "Missing Storage Account Configuration."
    }

    $Exportdevices = @()
    $Devices = [psobject]
    if ($Sync) {
        $SelectString = "deviceName, lastSyncDateTime, enrolledDateTime, userPrincipalName, id, serialNumber, manufacturer, model, imei, managedDeviceOwnerType, operatingSystem, osVersion, complianceState"
        $filter = 'lastSyncDateTime le ' + $beforedate + 'T00:00:00Z'
        $Devices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdSelect $SelectString -OdFilter $filter
    }
    else {
        $filter = 'approximateLastSignInDateTime le ' + $beforedate + 'T00:00:00Z'
        $SelectString = "displayName,deviceId,approximateLastSignInDateTime,createdDateTime,id,manufacturer,deviceOwnership,operatingSystem,operatingSystemVersion"
        "## Inactive Devices (No SignIn since at least $Days days):"
        ""
    
        $Devices = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter $filter -OdSelect $SelectString | Sort-Object -Property approximateLastSignInDateTime
    }
    foreach ($Device in $Devices) {
        if ($Sync) {
            $primaryOwner = Invoke-RjRbRestMethodGraph -Resource "/Users/$($Device.userPrincipalName)" -OdSelect "city, country, department, usageLocation"
        }
        else {
            $primaryOwner = Invoke-RjRbRestMethodGraph -Resource "/devices/$($Device.id)/registeredOwners" -OdSelect "userPrincipalName,city,department,usageLocation"
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

    #zugang zu Az storage um csv zu speichern
    #oder per mail attachment schicken vgl notify-changed-Conditional-Access-Policies.ps1 und notify-changed-CA-policies.ps1

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

    if ($Sync) {
        $Exportdevices | ConvertTo-Csv > stale-sync-devices.csv
        $FileName = "stale-sync-devices.csv"
    }
    else {
        $Exportdevices | ConvertTo-Csv > stale-login-devices.csv
        $FileName = "stale-login-devices.csv"
    }
    # Upload
    Set-AzStorageBlobContent -File $FileName -Container $ContainerName -Blob $FileName -Context $context -Force | Out-Null

    $EndTime = (Get-Date).AddDays(6)
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $FileName -FullUri -ExpiryTime $EndTime

    "## App Owner/User List Export created."
    "## Expiry of Link: $EndTime"
    $SASLink | Out-String

}
catch {
    $_
}
finally {
    Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
}
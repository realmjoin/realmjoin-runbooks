<#
  .SYNOPSIS
  List/export inactive evices, which had no recent user logons.

  .DESCRIPTION
  Collect devices based on the date of last user logon or last Intune sync.

  .NOTES
  Permissions
  MS Graph (API):
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All
  - Device.Read.All

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
        "Sync": {
            "DisplayName": "Last Login or Last Intune Sync",
            "Select": {
                "Options": [
                    {
                        "Display": "Show by Last Intune Sync",
                        "ParameterValue": true
                    },
                    {
                        "Display": "Show by Last Login",
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
            "Select": {
                "Options": [
                    {
                        "Display": "Export to a CSV file",
                        "ParameterValue": true
                    },
                    {
                        "Display": "List in Console",
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Number of days without Sync/Login being considered inactive." } )]
    [int] $Days = 30,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Last Login or Last Intune Sync" } )]
    [bool] $Sync = $true,
    [bool] $ExportToFile = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "InactiveDevices.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "InactiveDevices.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "InactiveDevices.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "InactiveDevices.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "InactiveDevices.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

if ((-not $ContainerName) -and $Sync) {
    $ContainerName = "stale-sync-device-list"
}
elseif (-not $ContainerName) {
    $ContainerName = "stale-login-device-list"
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
    "## - InactiveDevices.ResourceGroup"
    "## - InactiveDevices.StorageAccount.Name"
    "## - InactiveDevices.StorageAccount.Location"
    "## - InactiveDevices.StorageAccount.Sku"
    ""
    "## Skipping file export."
    $ExportToFile = $false
}

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
    
        if ($Sync) {
            $FileName = "$(Get-Date -Format "yyyy-MM-dd")-stale-sync-devices.csv"
            $Exportdevices | ConvertTo-Csv -Delimiter ";" > $FileName
        }
        else {
            $FileName = "$(Get-Date -Format "yyyy-MM-dd")-stale-login-devices.csv"
            $Exportdevices | ConvertTo-Csv -Delimiter ";" > $FileName
        }
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
else {
    if ($Sync) {
        $Exportdevices | Sort-Object -Property lastSyncDateTime | Format-Table -AutoSize -Property @{name = "LastSync"; expression = { get-date $_.lastSyncDateTime -Format yyyy-MM-dd } }, @{name = "deviceName"; expression = { if ($_.deviceName.Length -gt 15) { $_.deviceName.substring(0, 14) + ".." } else { $_.deviceName } } }, userPrincipalName, @{name = "serialNumber"; expression = { if ($_.serialNumber.Length -gt 15) { $_.serialNumber.substring(0, 14) + ".." } else { $_.serialNumber } } }, manufacturer, model, complianceState | Out-String
    }
    else {
        $Exportdevices | Sort-Object -Property approximateLastSignInDateTime | Format-Table -AutoSize -Property @{name = "LastSignIn"; expression = { get-date $_.approximateLastSignInDateTime -Format yyyy-MM-dd } }, @{name = "displayName"; expression = { if ($_.displayName.Length -gt 15) { $_.displayName.substring(0, 14) + ".." } else { $_.displayName } } }, deviceId, manufacturer, model, isCompliant  | Out-String
    }
}



<#
  .SYNOPSIS
  Export a list of all Intune devices and where they are registered.

  .DESCRIPTION
  Export all Intune devices and metadata based on their owner, like usageLocation.

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param (
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.SubscriptionId" } )]
    [string] $SubscriptionId,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

"## Trying to export all Intune devices and metadata based on their owner, like usageLocation."

if (-not $ContainerName) {
    $ContainerName = "intune-devices-list"
}

if ((-not $ResourceGroupName) -or (-not $StorageAccountName) -or (-not $StorageAccountSku) -or (-not $StorageAccountLocation)) {
    "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
    ""
    "## Configure the following attributes:"
    "## - IntuneDevicesReport.ResourceGroup"
    "## - IntuneDevicesReport.StorageAccount.Name"
    "## - IntuneDevicesReport.StorageAccount.Location"
    "## - IntuneDevicesReport.StorageAccount.Sku"
    ""
    "## Stopping execution."
    throw "Missing Storage Account Configuration."
}

# Manually import this ahead of MgGraph module to avoid conflicts
Import-Module Az.Accounts

Connect-RjRbGraph
Connect-RjRbAzAccount
if ($SubscriptionId) {
    Set-AzContext -Subscription $SubscriptionId | Out-Null
}
try {
    $Exportdevices = @()
    Write-RjRbLog "Fetching all Intune devices."
    $Devices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdSelect "deviceName, lastSyncDateTime, enrolledDateTime, userPrincipalName, id, serialNumber, manufacturer, model, imei, managedDeviceOwnerType, operatingSystem, osVersion, complianceState" -FollowPaging

    foreach ($Device in $Devices) {
        $primaryOwner = Invoke-RjRbRestMethodGraph -Resource "/Users/$($Device.userPrincipalName)" -OdSelect "city, country, companyName, department, jobTitle, usageLocation" -ErrorAction SilentlyContinue
        $Exportdevice = @()
        $Exportdevice += $Device
        if ($primaryOwner) {
            $Exportdevice | Add-Member -Name "city" -Value $primaryOwner.city -MemberType "NoteProperty"
            $Exportdevice | Add-Member -Name "country" -Value $primaryOwner.country -MemberType "NoteProperty"
            $Exportdevice | Add-Member -Name "companyName" -Value $primaryOwner.companyName -MemberType "NoteProperty"
            $Exportdevice | Add-Member -Name "department" -Value $primaryOwner.department -MemberType "NoteProperty"
            $Exportdevice | Add-Member -Name "jobTitle" -Value $primaryOwner.jobTitle -MemberType "NoteProperty"
            $Exportdevice | Add-Member -Name "usageLocation" -Value $primaryOwner.usageLocation -MemberType "NoteProperty"
        }
        $Exportdevices += $Exportdevice
    }

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

    $fileName = "intune-devices-$(get-date -Format "yyyy-MM-dd").csv"
    $Exportdevices | ConvertTo-Csv -Delimiter ";" -NoTypeInformation > $fileName
    $content = Get-Content $fileName
    Set-Content -Path $fileName -Value $content -Encoding utf8

    Write-RjRbLog "Upload"
    Set-AzStorageBlobContent -File $fileName -Container $ContainerName -Blob $fileName -Context $context -Force | Out-Null

    $EndTime = (Get-Date).AddDays(6)
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $fileName -FullUri -ExpiryTime $EndTime

    "## Export of all Intune devices created."
    "## Expiry of Link: $EndTime"
    $SASLink | Out-String

}
catch {
    $_
}
finally {
    Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
}
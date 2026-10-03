<#
    .SYNOPSIS
    Export all Intune devices with their primary users' usage location

    .DESCRIPTION
    Exports every Intune managed device together with details of its primary user, such as the usage location, as a CSV file to an Azure Storage account. Optionally only devices whose primary user is in a given group are exported. Nothing is changed.

    .PARAMETER ContainerName
    Storage container the CSV file is uploaded to. Taken from the tenant setting IntuneDevicesReport.Container.

    .PARAMETER ResourceGroupName
    Resource group of the storage account. Taken from the tenant setting IntuneDevicesReport.ResourceGroup.

    .PARAMETER StorageAccountName
    Storage account for the export. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Name.

    .PARAMETER StorageAccountLocation
    Azure region used when the storage account has to be created. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Location.

    .PARAMETER StorageAccountSku
    Performance tier used when the storage account has to be created. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Sku.

    .PARAMETER SubscriptionId
    Azure subscription that holds the storage account. Taken from the tenant setting IntuneDevicesReport.SubscriptionId.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .PARAMETER FilterGroupID
    Only devices whose primary user is in this group. Leave empty for all devices.

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
            "StorageAccountLocation": {
                "Hide": true
            },
            "StorageAccountSku": {
                "Hide": true
            },
            "SubscriptionId": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            },
            "FilterGroupID": {
                "DisplayName": "Limit to primary users in group"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

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
    [Parameter(Mandatory = $false)][ValidateScript({ Use-RjRbInterface -Type Graph -Entity Group })]
    [string] $FilterGroupID = $null,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

"## Trying to export all Intune devices and metadata based on their owner, like usageLocation."

############################################################
#region Variables
#
############################################################

$OwnerMetadataSelect = "city, country, companyName, department, jobTitle, usageLocation, onPremisesExtensionAttributes"

#endregion Variables

############################################################
#region Main Logic
#
############################################################

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

$groupUserLookup = $null
if ($FilterGroupID) {
    Write-RjRbLog -Message "FilterGroupID provided: '$FilterGroupID'" -Verbose

    Write-RjRbLog -Message "Fetching transitive user members for group filter." -Verbose
    $userIdSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $upnSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $members = Invoke-RjRbRestMethodGraph -Resource "/groups/$FilterGroupID/transitiveMembers/microsoft.graph.user" -OdSelect "id,userPrincipalName" -FollowPaging
    foreach ($member in @($members)) {
        if ($member.id) {
            [void] $userIdSet.Add([string] $member.id)
        }
        if ($member.userPrincipalName) {
            [void] $upnSet.Add([string] $member.userPrincipalName)
        }
    }

    $groupUserLookup = @{ UserIds = $userIdSet; UserPrincipalNames = $upnSet }
    Write-RjRbLog -Message ("FilterGroupID user members loaded. IDs: {0}, UPNs: {1}" -f $groupUserLookup.UserIds.Count, $groupUserLookup.UserPrincipalNames.Count) -Verbose
}

try {
    $Exportdevices = @()
    Write-RjRbLog "Fetching all Intune devices."
    $Devices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdSelect "deviceName, lastSyncDateTime, enrolledDateTime, userPrincipalName, userId, id, serialNumber, manufacturer, model, imei, managedDeviceOwnerType, operatingSystem, osVersion, complianceState" -FollowPaging

    foreach ($Device in $Devices) {
        if ($groupUserLookup) {
            $deviceUserId = [string] $Device.userId
            $deviceUpn = [string] $Device.userPrincipalName

            $isOwnerInGroup = $false
            if ($deviceUserId -and $groupUserLookup.UserIds.Contains($deviceUserId)) {
                $isOwnerInGroup = $true
            }
            elseif ($deviceUpn -and $groupUserLookup.UserPrincipalNames.Contains($deviceUpn)) {
                $isOwnerInGroup = $true
            }

            if (-not $isOwnerInGroup) {
                continue
            }
        }

        $Exportdevice = $Device | Select-Object *

        for ($i = 1; $i -le 15; $i++) {
            $Exportdevice | Add-Member -Name "extensionAttribute$i" -Value $null -MemberType "NoteProperty" -Force
        }

        $hasOwnerReference = ($Device.userId -and ([string] $Device.userId) -ne "") -or ($Device.userPrincipalName -and ([string] $Device.userPrincipalName) -ne "")
        if ($hasOwnerReference) {
            # Only enrich device data if there is a user reference assigned to the device
            $userResource = $null
            if ($Device.userId) {
                $userResource = "/Users/$($Device.userId)"
            }
            else {
                $userResource = "/Users/$($Device.userPrincipalName)"
            }

            $primaryOwner = Invoke-RjRbRestMethodGraph -Resource $userResource -OdSelect $OwnerMetadataSelect -ErrorAction SilentlyContinue

            if ($primaryOwner) {
                $Exportdevice | Add-Member -Name "city" -Value $primaryOwner.city -MemberType "NoteProperty" -Force
                $Exportdevice | Add-Member -Name "country" -Value $primaryOwner.country -MemberType "NoteProperty" -Force
                $Exportdevice | Add-Member -Name "companyName" -Value $primaryOwner.companyName -MemberType "NoteProperty" -Force
                $Exportdevice | Add-Member -Name "department" -Value $primaryOwner.department -MemberType "NoteProperty" -Force
                $Exportdevice | Add-Member -Name "jobTitle" -Value $primaryOwner.jobTitle -MemberType "NoteProperty" -Force
                $Exportdevice | Add-Member -Name "usageLocation" -Value $primaryOwner.usageLocation -MemberType "NoteProperty" -Force

                for ($i = 1; $i -le 15; $i++) {
                    $attributeName = "extensionAttribute$i"
                    $attributeValue = $null

                    if ($primaryOwner.onPremisesExtensionAttributes) {
                        $attributeValue = $primaryOwner.onPremisesExtensionAttributes.$attributeName
                    }

                    $Exportdevice | Add-Member -Name $attributeName -Value $attributeValue -MemberType "NoteProperty" -Force
                }
            }
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

#endregion Main Logic
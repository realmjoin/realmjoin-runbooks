<#
.SYNOPSIS
    Report on non-compliant devices and policies

.DESCRIPTION
    Report on non-compliant devices and policies

.NOTES
    Permissions
    MS Graph
    - DeviceManagementConfiguration.Read.All
    Storage Account (optional)
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Create SAS Tokens / Links?" -Type Setting -Attribute "IntuneDevicesReport.CreateLinks" } )]
    [bool] $produceLinks = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.Container" } )]
    [string] $ContainerName = "rjrb-device-compliance-report-v2",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

if ($produceLinks -and ((-not $ResourceGroupName) -or (-not $StorageAccountName) -or (-not $StorageAccountSku) -or (-not $StorageAccountLocation))) {
    "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
    ""
    "## Configure the following attributes:"
    "## - IntuneDevicesReport.ResourceGroup"
    "## - IntuneDevicesReport.StorageAccount.Name"
    "## - IntuneDevicesReport.StorageAccount.Location"
    "## - IntuneDevicesReport.StorageAccount.Sku"
    ""
    "## Will not produce files / links."
    $produceLinks = $false
}

Connect-RjRbGraph
if ($produceLinks) {
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
}

"## Find non-compliant devices"
$devices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -Method GET -ODfilter "complianceState eq 'noncompliant' or complianceState eq 'inGracePeriod'" -FollowPaging
"## ..found $($devices.count) 'non compliant' or 'in grace period' devices"
""

[int]$counter = 0
"## Get Compliance Report for each device"
$deviceToPolicy = @{}
foreach ($id in $devices.id) {
    $body = @{
        select  = @(
        )
        skip    = 0
        top     = 100
        filter  = "(DeviceId eq '$id')"
        orderBy = @(
            "PolicyName asc"
        )
        search  = ""
    }
    #"## DeviceId: $id"
    $result = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/reports/getDevicePoliciesComplianceReport" -Method POST -Body $body -Beta -FollowPaging
    $policies = @{}
    foreach ($row in $result.Values) {
        $properties = @{}
        for ($i = 0; $i -lt $result.Schema.Column.count; $i++) {
            $properties.add($result.Schema.Column[$i], $row[$i])
        }
        # Exclude compliant policies and not applicable policies
        if ($properties.PolicyStatus -notin @(1, 2)) {
            $settingsBody = @{
                select  = @(
                )
                skip    = 0
                top     = 100
                filter  = "(DeviceId eq '$id') and (PolicyId eq '$($properties.PolicyId)')"
                orderBy = @(
                    "SettingName asc"
                )
                search  = ""
            }
            $settingsResult = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/reports/getDevicePolicySettingsComplianceReport" -Method POST -Body $settingsBody -Beta -FollowPaging
            $settings = @{}
            foreach ($settingsRow in $settingsResult.Values) {
                $settingsProperties = @{}
                for ($i = 0; $i -lt $settingsResult.Schema.Column.count; $i++) {
                    $settingsProperties.add($settingsResult.Schema.Column[$i], $settingsRow[$i])
                }
                #$settingsProperties | Format-Table | Out-String
                if ($settingsProperties.SettingStatus -notin @(1, 2)) {
                    #"## Adding '$($settingsProperties.SettingName)' ($($settingsProperties.SettingId)) to list of settings for policy '$($properties.PolicyName)' ($($properties.PolicyId))"
                    # Avoid duplicate settings
                    if (-not $settings.ContainsKey($settingsProperties.SettingId)) {
                        $settings.add($settingsProperties.SettingId, $settingsProperties)
                    }
                }
            }
            $properties.add("Settings", $settings)
            #"## Adding '$($properties.PolicyName)' ($($properties.PolicyId)) to list of policies"
            $policies.add($properties.PolicyId, $properties)

        }
    }
    $deviceToPolicy.Add($id, $policies)
    $counter++
    if ($counter % 50 -eq 0) {
        "## ..processed $counter devices"
    }
}
""

"## Create full CSV - listing every device, policy and setting individually"
$fullCsv = @()
foreach ($device in $deviceToPolicy.Keys) {
    foreach ($policy in $deviceToPolicy[$device].Keys) {
        $row = "" | Select-Object DeviceName, UPN, ManagedDeviceOwnerType, OperatingSystem, PolicyName, PolicyStatus_loc, SettingName, SettingStatus_loc, LastContact, SerialNumber, PolicyId, SettingId, DeviceId 
        $deviceObject = $devices | Where-Object { $_.id -eq $device }
        $row.DeviceId = $device
        $row.SerialNumber = $deviceObject.serialNumber
        $row.DeviceName = $deviceObject.deviceName
        $row.ManagedDeviceOwnerType = $deviceObject.managedDeviceOwnerType
        $row.PolicyId = $policy
        $row.PolicyName = $deviceToPolicy[$device][$policy].PolicyName
        $row.PolicyStatus_loc = $deviceToPolicy[$device][$policy].PolicyStatus_loc
        $row.UPN = $deviceToPolicy[$device][$policy].UPN
        $row.LastContact = $deviceToPolicy[$device][$policy].LastContact
        $row.OperatingSystem = $deviceObject.operatingSystem
        foreach ($setting in $deviceToPolicy[$device][$policy].Settings.Keys) {
            $row.SettingId = $setting
            $row.SettingName = $deviceToPolicy[$device][$policy].Settings[$setting].SettingName
            $row.SettingStatus_loc = $deviceToPolicy[$device][$policy].Settings[$setting].SettingStatus_loc
            $fullCsv += $row
        }
        if ($deviceToPolicy[$device][$policy].Settings.Count -eq 0) {
            $row.SettingId = ""
            $row.SettingName = ""
            $row.SettingStatus_loc = ""
            $fullCsv += $row
        }
    }
}
# Output full CSV
if ($produceLinks) {
    $filename = "$(get-date -Format "yyyy-MM-dd")-non-compliant-devices.csv"
    $fullCsv | convertto-csv -NoTypeInformation -Delimiter ";" > $filename
    $content = Get-Content $filename
    Set-Content -Path $filename -Value $content -Encoding UTF8
    
    Write-RjRbLog "Upload Full CSV Report"
    Set-AzStorageBlobContent -File $fileName -Container $ContainerName -Blob $fileName -Context $context -Force | Out-Null

    $EndTime = (Get-Date).AddDays(6)
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $fileName -FullUri -ExpiryTime $EndTime

    "## Export of all Intune non-compliant and in-grace-period devices created."
    "## Expiry of Link: $EndTime"
    $SASLink | Out-String
}
else {
    $fullCsv | convertto-csv -NoTypeInformation -Delimiter ";" | Out-String
}
""

"## Create statistics - count number of non-compliant devices per policy"
$policyStatistics = @{}
foreach ($device in $deviceToPolicy.Keys) {
    foreach ($policy in $deviceToPolicy[$device].Keys) {
        if ($policyStatistics.ContainsKey($policy)) {
            $policyStatistics[$policy][1] += 1
        }
        else {
            $policyObject = $deviceToPolicy[$device][$policy]
            $policyStatistics.Add($policy, @($policyObject, 1))
        }
    }
}
# Output statistics, sorted by number of non-compliant devices
if ($produceLinks) {
    $filename = "$(get-date -Format "yyyy-MM-dd")-non-compliant-policies.csv"
    "PolicyName;NonCompliantDevices;PolicyId" > $filename
    foreach ($policy in $policyStatistics.Keys | Sort-Object { $policyStatistics[$_][1] } -Descending) {
        $policyObject = $policyStatistics[$policy][0]
        "$($policyObject.PolicyName);$($policyStatistics[$policy][1]);$($policyObject.PolicyId)" >> $filename
    }
    $content = Get-Content $filename
    Set-Content -Path $filename -Value $content -Encoding UTF8

    Write-RjRbLog "Upload Policy CSV Report"
    Set-AzStorageBlobContent -File $fileName -Container $ContainerName -Blob $fileName -Context $context -Force | Out-Null
    
    $EndTime = (Get-Date).AddDays(6)
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $fileName -FullUri -ExpiryTime $EndTime
    
    "## Export of policy statistics created."
    "## Expiry of Link: $EndTime"
    $SASLink | Out-String
}
else {
    "PolicyName;NonCompliantDevices;PolicyId"
    foreach ($policy in $policyStatistics.Keys | Sort-Object { $policyStatistics[$_][1] } -Descending) {
        $policyObject = $policyStatistics[$policy][0]
        "$($policyObject.PolicyName);$($policyStatistics[$policy][1]);$($policyObject.PolicyId)"
    }
}
""

"## Create statistics - count number of non-compliant devices per setting"
$settingStatistics = @{}
foreach ($device in $deviceToPolicy.Keys) {
    foreach ($policy in $deviceToPolicy[$device].Keys) {
        foreach ($setting in $deviceToPolicy[$device][$policy].Settings.Keys) {
            
            if ($settingStatistics.ContainsKey($setting)) {
                $settingStatistics[$setting][1] += 1
            }
            else {
                $settingsObject = $deviceToPolicy[$device][$policy].Settings[$setting]
                $settingStatistics.Add($setting, @($settingsObject, 1))
            }
        }
    }
}
# Output statistics, sorted by number of non-compliant devices
if ($produceLinks) {
    $filename = "$(get-date -Format "yyyy-MM-dd")-non-compliant-settings.csv"
    "SettingName;NonCompliantDevices;SettingId" > $filename
    foreach ($setting in $settingStatistics.Keys | Sort-Object { $settingStatistics[$_][1] } -Descending) {
        $settingObject = $settingStatistics[$setting][0]
        "$($settingObject.SettingName);$($settingStatistics[$setting][1]);$($settingObject.SettingId)" >> $filename
    }
    $content = Get-Content $filename
    Set-Content -Path $filename -Value $content -Encoding UTF8

    Write-RjRbLog "Upload Settings CSV Report"
    Set-AzStorageBlobContent -File $fileName -Container $ContainerName -Blob $fileName -Context $context -Force | Out-Null
    
    $EndTime = (Get-Date).AddDays(6)
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $fileName -FullUri -ExpiryTime $EndTime
    
    "## Export of settings statistics created."
    "## Expiry of Link: $EndTime"
    $SASLink | Out-String
}
else {
    "SettingName;NonCompliantDevices;SettingId"
    foreach ($setting in $settingStatistics.Keys | Sort-Object { $settingStatistics[$_][1] } -Descending) {
        $settingObject = $settingStatistics[$setting][0]
        "$($settingObject.SettingName);$($settingStatistics[$setting][1]);$($settingObject.SettingId)"
    }
}
""
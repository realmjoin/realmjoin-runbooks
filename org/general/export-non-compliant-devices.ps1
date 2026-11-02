<#
	.SYNOPSIS
	Export non-compliant Intune devices with their failing settings

	.DESCRIPTION
	Lists the Intune devices that are non-compliant or in a grace period, together with the policies and the individual settings that fail on each of them. The results can be exported as CSV files to an Azure Storage account with time-limited download links. Nothing is changed.

	.PARAMETER produceLinks
	Uploads the CSV files to the storage account configured in the tenant settings and returns download links.

	.PARAMETER ContainerName
	Storage container the report files are uploaded to. Taken from the tenant setting IntuneDevicesReport.Container.

	.PARAMETER ResourceGroupName
	Resource group of the storage account. Taken from the tenant setting IntuneDevicesReport.ResourceGroup; when it is not set, RJReport.StorageAccount.ResourceGroup is used.

	.PARAMETER StorageAccountName
	Storage account for the export. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Name; when it is not set, RJReport.StorageAccount.StorageAccountName is used.

	.PARAMETER StorageAccountLocation
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER StorageAccountSku
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER SubscriptionId
	Subscription ID of the storage account for report uploads. Taken from the tenant setting IntuneDevicesReport.SubscriptionId and only used with IntuneDevicesReport.*; empty means the subscription the managed identity signs in to.

	.PARAMETER RJReportResourceGroupName
	Resource group of the storage account. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when IntuneDevicesReport.ResourceGroup is not set.

	.PARAMETER RJReportStorageAccountName
	Storage account for the export. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when IntuneDevicesReport.StorageAccount.Name is not set.

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
			"StorageAccountLocation": {
				"Hide": true
			},
			"StorageAccountSku": {
				"Hide": true
			},
			"SubscriptionId": {
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
			"CallerName": {
				"Hide": true
			}
		}
	}

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    # Legacy report settings: IntuneDevicesReport.CreateLinks has no RJReport counterpart - unbind it (default: create links) when it is switched off
    [ValidateScript( { Use-RJInterface -DisplayName "Create download links?" -Type Setting -Attribute "IntuneDevicesReport.CreateLinks" } )]
    [bool] $produceLinks = $true,
    # Legacy report settings: IntuneDevicesReport.* - rebind to RJReport.StorageAccount.* (ContainerName: unbind) when it is switched off
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.Container" } )]
    [string] $ContainerName = "rjrb-device-compliance-report-v2",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    # Legacy report settings: deprecated and ignored, kept so existing schedules and API calls keep starting
    [string] $StorageAccountLocation,
    [string] $StorageAccountSku,
    # Legacy report settings: IntuneDevicesReport.SubscriptionId - rebind to RJReport.StorageAccount.SubscriptionId when it is switched off
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.SubscriptionId" } )]
    [string] $SubscriptionId,
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

# Legacy report settings: IntuneDevicesReport.* stays bound to the original parameters, so explicit values, existing schedules
# and API calls behave as before and the legacy settings win. RJReport.StorageAccount.* fills in when they are not set.
if (-not ($ResourceGroupName -and $StorageAccountName) -and $RJReportResourceGroupName -and $RJReportStorageAccountName) {
    Write-RjRbLog -Message "Using RJReport.StorageAccount.* - IntuneDevicesReport.* is not configured" -Verbose
    $ResourceGroupName = $RJReportResourceGroupName
    $StorageAccountName = $RJReportStorageAccountName
    # IntuneDevicesReport.SubscriptionId belongs to the legacy storage account
    $SubscriptionId = $RJReportSubscriptionId
}

# Legacy report settings: remove with StorageAccountLocation / StorageAccountSku in the switch-off release
if ($PSBoundParameters.ContainsKey('StorageAccountLocation') -or $PSBoundParameters.ContainsKey('StorageAccountSku')) {
    $deprecationMessage = "StorageAccountLocation and StorageAccountSku are deprecated and ignored - the storage account is no longer created automatically. Re-create this schedule or drop both parameters from the API call; a later version removes them."
    Write-RjRbLog -Message "WARNING: $deprecationMessage"
    Write-Warning $deprecationMessage
}

if ($produceLinks -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
    ""
    "## Configure the following attributes (see https://docs.realmjoin.com/automation/runbooks/runbook-report-settings):"
    "## - RJReport.StorageAccount.ResourceGroup"
    "## - RJReport.StorageAccount.StorageAccountName"
    "## The runbook-specific IntuneDevicesReport.ResourceGroup and IntuneDevicesReport.StorageAccount.Name are still read and take precedence."
    ""
    "## Will not produce files / links."
    $produceLinks = $false
}

#endregion Parameter Validation

# Manually import this ahead of MgGraph module to avoid conflicts
Import-Module Az.Accounts

Connect-RjRbGraph
$reportFiles = @()
if ($produceLinks) {
    Connect-RjRbAzAccount
    $uploadParameters = @{
        ContainerName      = $ContainerName
        ResourceGroupName  = $ResourceGroupName
        StorageAccountName = $StorageAccountName
        SubscriptionId     = $SubscriptionId
        LinkExpiryDays     = $LinkExpiryDays
        AddBlobNamePrefix  = $false
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
        skip    = 0
        top     = 100
        filter  = "(DeviceId eq '$id')"
        orderBy = @(
            "PolicyName asc"
        )
        search  = ""
    }
    #"## DeviceId: $id"
    $result = $null
    try {
        $result = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/reports/getDevicePoliciesComplianceReport" -Method POST -Body $body -Beta -FollowPaging
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 429) {
            "## Throttling exceeded - Waiting/Cooldown 2min"
            Start-Sleep -Seconds 120
            Connect-RjRbGraph -Force
            $result = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/reports/getDevicePoliciesComplianceReport" -Method POST -Body $body -Beta -FollowPaging
        }
        else {
            throw $_
        }
    }
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
            $settingsResult = $null
            try {
                $settingsResult = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/reports/getDevicePolicySettingsComplianceReport" -Method POST -Body $settingsBody -Beta -FollowPaging
            }
            catch {
                if ($_.Exception.Response.StatusCode.value__ -eq 429) {
                    "## Throttling exceeded - Waiting/Cooldown 2min"
                    Start-Sleep -Seconds 120
                    Connect-RjRbGraph -Force
                    $settingsResult = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/reports/getDevicePolicySettingsComplianceReport" -Method POST -Body $settingsBody -Beta -FollowPaging
                }
                else {
                    throw $_
                }
            }
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
    # The local file name becomes the blob name, so uploads keep the blob names of earlier versions
    $filename = Join-Path ([System.IO.Path]::GetTempPath()) "$(get-date -Format "yyyy-MM-dd")-non-compliant-devices.csv"
    $reportFiles += $filename
    $fullCsv | convertto-csv -NoTypeInformation -Delimiter ";" > $filename
    $content = Get-Content $filename
    Set-Content -Path $filename -Value $content -Encoding UTF8

    Write-RjRbLog "Upload Full CSV Report"
    try {
        $uploadResult = Publish-RjRbFilesToStorageContainer -FilePaths $filename @uploadParameters

        "## Export of all Intune non-compliant and in-grace-period devices created."
        "## Expiry of Link: $($uploadResult.EndTime)"
        $uploadResult.SASLink | Out-String
    }
    catch {
        Write-RjRbLog -Message "Upload to storage account '$StorageAccountName' failed: $($_.Exception.Message). The managed identity needs the 'Reader and Data Access' role on the storage account." -Verbose
        $_
    }
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
    $filename = Join-Path ([System.IO.Path]::GetTempPath()) "$(get-date -Format "yyyy-MM-dd")-non-compliant-policies.csv"
    $reportFiles += $filename
    "PolicyName;NonCompliantDevices;PolicyId" > $filename
    foreach ($policy in $policyStatistics.Keys | Sort-Object { $policyStatistics[$_][1] } -Descending) {
        $policyObject = $policyStatistics[$policy][0]
        "$($policyObject.PolicyName);$($policyStatistics[$policy][1]);$($policyObject.PolicyId)" >> $filename
    }
    $content = Get-Content $filename
    Set-Content -Path $filename -Value $content -Encoding UTF8

    Write-RjRbLog "Upload Policy CSV Report"
    try {
        $uploadResult = Publish-RjRbFilesToStorageContainer -FilePaths $filename @uploadParameters

        "## Export of policy statistics created."
        "## Expiry of Link: $($uploadResult.EndTime)"
        $uploadResult.SASLink | Out-String
    }
    catch {
        Write-RjRbLog -Message "Upload to storage account '$StorageAccountName' failed: $($_.Exception.Message). The managed identity needs the 'Reader and Data Access' role on the storage account." -Verbose
        $_
    }
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
    $filename = Join-Path ([System.IO.Path]::GetTempPath()) "$(get-date -Format "yyyy-MM-dd")-non-compliant-settings.csv"
    $reportFiles += $filename
    "SettingName;NonCompliantDevices;SettingId" > $filename
    foreach ($setting in $settingStatistics.Keys | Sort-Object { $settingStatistics[$_][1] } -Descending) {
        $settingObject = $settingStatistics[$setting][0]
        "$($settingObject.SettingName);$($settingStatistics[$setting][1]);$($settingObject.SettingId)" >> $filename
    }
    $content = Get-Content $filename
    Set-Content -Path $filename -Value $content -Encoding UTF8

    Write-RjRbLog "Upload Settings CSV Report"
    try {
        $uploadResult = Publish-RjRbFilesToStorageContainer -FilePaths $filename @uploadParameters

        "## Export of settings statistics created."
        "## Expiry of Link: $($uploadResult.EndTime)"
        $uploadResult.SASLink | Out-String
    }
    catch {
        Write-RjRbLog -Message "Upload to storage account '$StorageAccountName' failed: $($_.Exception.Message). The managed identity needs the 'Reader and Data Access' role on the storage account." -Verbose
        $_
    }
}
else {
    "SettingName;NonCompliantDevices;SettingId"
    foreach ($setting in $settingStatistics.Keys | Sort-Object { $settingStatistics[$_][1] } -Descending) {
        $settingObject = $settingStatistics[$setting][0]
        "$($settingObject.SettingName);$($settingStatistics[$setting][1]);$($settingObject.SettingId)"
    }
}
""

########################################################
#region     Cleanup
########################################################

foreach ($reportFile in $reportFiles) {
    Remove-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
}

#endregion Cleanup
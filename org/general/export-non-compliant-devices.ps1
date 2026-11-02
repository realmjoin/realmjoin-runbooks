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
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }
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

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "produceLinks: $produceLinks" -Verbose
Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
Write-RjRbLog -Message "StorageAccountLocation: $StorageAccountLocation" -Verbose
Write-RjRbLog -Message "StorageAccountSku: $StorageAccountSku" -Verbose
Write-RjRbLog -Message "SubscriptionId: $SubscriptionId" -Verbose
Write-RjRbLog -Message "RJReportResourceGroupName: $RJReportResourceGroupName" -Verbose
Write-RjRbLog -Message "RJReportStorageAccountName: $RJReportStorageAccountName" -Verbose
Write-RjRbLog -Message "RJReportSubscriptionId: $RJReportSubscriptionId" -Verbose
Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose

#endregion RJ Log Part

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

function Invoke-ComplianceReportRequest {
    <#
        .SYNOPSIS
        Calls an Intune compliance report action and returns its result table.

        .DESCRIPTION
        The report actions under /deviceManagement/reports answer with a JSON document as a file stream
        (application/octet-stream), which Invoke-MgGraphRequest only writes to a file. The response is saved to a
        temporary file, read as JSON (Schema with the column names, Values with the rows) and the file is deleted again.

        .PARAMETER Uri
        Full URI of the report action, e.g. "https://graph.microsoft.com/beta/deviceManagement/reports/getDevicePoliciesComplianceReport".

        .PARAMETER Body
        The request body (filter, paging and sort order of the report).
    #>
    param(
        [string]$Uri,
        [hashtable]$Body
    )

    $responseFile = Join-Path ([System.IO.Path]::GetTempPath()) "compliance-report-$([guid]::NewGuid()).json"
    try {
        Invoke-MgGraphRequest -Uri $Uri -Method POST -Body ($Body | ConvertTo-Json -Depth 20) -ContentType "application/json; charset=UTF-8" -OutputFilePath $responseFile -ErrorAction Stop
        return (Get-Content -LiteralPath $responseFile -Raw -Encoding utf8 | ConvertFrom-Json)
    }
    finally {
        Remove-Item -LiteralPath $responseFile -Force -ErrorAction SilentlyContinue
    }
}

function ConvertTo-DisplayValue {
    <#
        .SYNOPSIS
        Turns a report value into the text shown in the Output Data table.

        .DESCRIPTION
        Timestamps become "yyyy-MM-dd HH:mm:ss", an empty value becomes an empty string, everything else its text.

        .PARAMETER Value
        The value as stored for the CSV export.
    #>
    param(
        $Value
    )

    if ($null -eq $Value) { return "" }
    if ($Value -is [datetime]) { return $Value.ToString("yyyy-MM-dd HH:mm:ss") }
    return "$Value"
}

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

Write-RjRbLog -Message "Connecting to Microsoft Graph" -Verbose
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity is configured correctly. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

if ($produceLinks) {
    Connect-RjRbAzAccount
}

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

$reportsUri = "https://graph.microsoft.com/beta/deviceManagement/reports"

# Invoke-MgGraphRequest returns PSCustomObjects in the property order of the Graph response, as the earlier RunbookHelper calls did;
# the default is removed again after the collection
$PSDefaultParameterValues['Invoke-MgGraphRequest:OutputType'] = 'PSObject'
try {
    "## Find non-compliant devices"
    $deviceFilter = [uri]::EscapeDataString("complianceState eq 'noncompliant' or complianceState eq 'inGracePeriod'")
    $devices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=$deviceFilter"
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
        $result = $null
        try {
            $result = Invoke-ComplianceReportRequest -Uri "$reportsUri/getDevicePoliciesComplianceReport" -Body $body
        }
        catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 429) {
                "## Throttling exceeded - Waiting/Cooldown 2min"
                Start-Sleep -Seconds 120
                $result = Invoke-ComplianceReportRequest -Uri "$reportsUri/getDevicePoliciesComplianceReport" -Body $body
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
                    $settingsResult = Invoke-ComplianceReportRequest -Uri "$reportsUri/getDevicePolicySettingsComplianceReport" -Body $settingsBody
                }
                catch {
                    if ($_.Exception.Response.StatusCode.value__ -eq 429) {
                        "## Throttling exceeded - Waiting/Cooldown 2min"
                        Start-Sleep -Seconds 120
                        $settingsResult = Invoke-ComplianceReportRequest -Uri "$reportsUri/getDevicePolicySettingsComplianceReport" -Body $settingsBody
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
                    if ($settingsProperties.SettingStatus -notin @(1, 2)) {
                        # Avoid duplicate settings
                        if (-not $settings.ContainsKey($settingsProperties.SettingId)) {
                            $settings.add($settingsProperties.SettingId, $settingsProperties)
                        }
                    }
                }
                $properties.add("Settings", $settings)
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
}
finally {
    $PSDefaultParameterValues.Remove('Invoke-MgGraphRequest:OutputType')
}

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

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
""

# Output Data rows: the rows and columns of the three CSV files, statistics sorted by number of non-compliant devices
$deviceRows = @($fullCsv | Select-Object -Property DeviceName, UPN, ManagedDeviceOwnerType, OperatingSystem, PolicyName, PolicyStatus_loc, SettingName, SettingStatus_loc, @{ Name = "LastContact"; Expression = { ConvertTo-DisplayValue -Value $_.LastContact } }, SerialNumber, PolicyId, SettingId, DeviceId)
$policyRows = @(foreach ($policy in $policyStatistics.Keys | Sort-Object { $policyStatistics[$_][1] } -Descending) {
        $policyObject = $policyStatistics[$policy][0]
        [PSCustomObject]@{ PolicyName = "$($policyObject.PolicyName)"; NonCompliantDevices = $policyStatistics[$policy][1]; PolicyId = "$($policyObject.PolicyId)" }
    })
$settingRows = @(foreach ($setting in $settingStatistics.Keys | Sort-Object { $settingStatistics[$_][1] } -Descending) {
        $settingObject = $settingStatistics[$setting][0]
        [PSCustomObject]@{ SettingName = "$($settingObject.SettingName)"; NonCompliantDevices = $settingStatistics[$setting][1]; SettingId = "$($settingObject.SettingId)" }
    })

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
if ($produceLinks) {
    # The local file names become the blob names, so uploads keep the blob names of earlier versions
    $fullCsvFile = Join-Path ([System.IO.Path]::GetTempPath()) "$(get-date -Format "yyyy-MM-dd")-non-compliant-devices.csv"
    $reportFiles += $fullCsvFile
    $fullCsv | convertto-csv -NoTypeInformation -Delimiter ";" > $fullCsvFile
    $content = Get-Content $fullCsvFile
    Set-Content -Path $fullCsvFile -Value $content -Encoding UTF8

    # Policy statistics, sorted by number of non-compliant devices
    $policyCsvFile = Join-Path ([System.IO.Path]::GetTempPath()) "$(get-date -Format "yyyy-MM-dd")-non-compliant-policies.csv"
    $reportFiles += $policyCsvFile
    "PolicyName;NonCompliantDevices;PolicyId" > $policyCsvFile
    foreach ($policy in $policyStatistics.Keys | Sort-Object { $policyStatistics[$_][1] } -Descending) {
        $policyObject = $policyStatistics[$policy][0]
        "$($policyObject.PolicyName);$($policyStatistics[$policy][1]);$($policyObject.PolicyId)" >> $policyCsvFile
    }
    $content = Get-Content $policyCsvFile
    Set-Content -Path $policyCsvFile -Value $content -Encoding UTF8

    # Setting statistics, sorted by number of non-compliant devices
    $settingCsvFile = Join-Path ([System.IO.Path]::GetTempPath()) "$(get-date -Format "yyyy-MM-dd")-non-compliant-settings.csv"
    $reportFiles += $settingCsvFile
    "SettingName;NonCompliantDevices;SettingId" > $settingCsvFile
    foreach ($setting in $settingStatistics.Keys | Sort-Object { $settingStatistics[$_][1] } -Descending) {
        $settingObject = $settingStatistics[$setting][0]
        "$($settingObject.SettingName);$($settingStatistics[$setting][1]);$($settingObject.SettingId)" >> $settingCsvFile
    }
    $content = Get-Content $settingCsvFile
    Set-Content -Path $settingCsvFile -Value $content -Encoding UTF8
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################

if ($produceLinks) {
    $uploadParameters = @{
        ContainerName      = $ContainerName
        ResourceGroupName  = $ResourceGroupName
        StorageAccountName = $StorageAccountName
        SubscriptionId     = $SubscriptionId
        LinkExpiryDays     = $LinkExpiryDays
        AddBlobNamePrefix  = $false
    }
    # One upload per file, each with its own link
    $uploads = @(
        @{ File = $fullCsvFile; Log = "Upload Full CSV Report"; Created = "## Export of all Intune non-compliant and in-grace-period devices created." }
        @{ File = $policyCsvFile; Log = "Upload Policy CSV Report"; Created = "## Export of policy statistics created." }
        @{ File = $settingCsvFile; Log = "Upload Settings CSV Report"; Created = "## Export of settings statistics created." }
    )
    foreach ($upload in $uploads) {
        Write-RjRbLog $upload.Log
        try {
            $uploadResult = Publish-RjRbFilesToStorageContainer -FilePaths $upload.File @uploadParameters

            $upload.Created
            "## Expiry of Link: $($uploadResult.EndTime)"
            $uploadResult.SASLink | Out-String
        }
        catch {
            Write-RjRbLog -Message "Upload to storage account '$StorageAccountName' failed: $($_.Exception.Message). The managed identity needs the 'Reader and Data Access' role on the storage account." -Verbose
            $_
        }
        ""
    }
}

#endregion Upload / Download Link

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the progress output. Every table has its own
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
Write-Output ""

$summaryRows = @(
    [PSCustomObject]@{ Metric = "Non-compliant or in grace period devices"; Value = "$($devices.count)" }
    [PSCustomObject]@{ Metric = "Devices with non-compliant policies"; Value = "$(@($deviceToPolicy.Values | Where-Object { $_.Count -gt 0 }).Count)" }
    [PSCustomObject]@{ Metric = "Non-compliant policies"; Value = "$($policyRows.Count)" }
    [PSCustomObject]@{ Metric = "Non-compliant settings"; Value = "$($settingRows.Count)" }
)
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($deviceRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Non-compliant devices" })
    Write-Output $deviceRows
}
else {
    Write-Output "No non-compliant policies found on the devices."
}

if ($policyRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Policy statistics" })
    Write-Output $policyRows
}

if ($settingRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Setting statistics" })
    Write-Output $settingRows
}
else {
    Write-Output "No non-compliant settings found."
}

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################

foreach ($reportFile in $reportFiles) {
    Remove-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
}
if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}
if ($produceLinks) {
    Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup
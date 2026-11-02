<#
	.SYNOPSIS
	Export all Intune devices with their primary users' usage location

	.DESCRIPTION
	Exports every Intune managed device together with details of its primary user, such as the usage location, as a CSV file to an Azure Storage account. Optionally only devices whose primary user is in a given group are exported. Nothing is changed.

	.PARAMETER ContainerName
	Storage container the CSV file is uploaded to. Taken from the tenant setting IntuneDevicesReport.Container.

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
			},
			"FilterGroupID": {
				"DisplayName": "Limit to primary users in group"
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param (
    # Legacy report settings: IntuneDevicesReport.* - rebind to RJReport.StorageAccount.* (ContainerName: unbind) when it is switched off
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneDevicesReport.Container" } )]
    [string] $ContainerName,
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
    [Parameter(Mandatory = $false)][ValidateScript( { Use-RJInterface -Type Graph -Entity Group } )]
    [string] $FilterGroupID = $null,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.2.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

"## Trying to export all Intune devices and metadata based on their owner, like usageLocation."

########################################################
#region     Variables
########################################################

$OwnerMetadataSelect = "city, country, companyName, department, jobTitle, usageLocation, onPremisesExtensionAttributes"

#endregion Variables

########################################################
#region     Parameter Validation
########################################################

if (-not $ContainerName) {
    $ContainerName = "intune-devices-list"
}

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

if ((-not $ResourceGroupName) -or (-not $StorageAccountName)) {
    "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
    ""
    "## Configure the following attributes (see https://docs.realmjoin.com/automation/runbooks/runbook-report-settings):"
    "## - RJReport.StorageAccount.ResourceGroup"
    "## - RJReport.StorageAccount.StorageAccountName"
    "## The runbook-specific IntuneDevicesReport.ResourceGroup and IntuneDevicesReport.StorageAccount.Name are still read and take precedence."
    ""
    "## Stopping execution."
    throw "Missing Storage Account Configuration."
}

#endregion Parameter Validation

########################################################
#region     Main Logic
########################################################

# Manually import this ahead of MgGraph module to avoid conflicts
Import-Module Az.Accounts

Connect-RjRbGraph
Connect-RjRbAzAccount

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

$collectionFailed = $false
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
}
catch {
    $collectionFailed = $true
    $_
}

#endregion Main Logic

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
if (-not $collectionFailed) {
    # The local file name becomes the blob name, so uploads keep the blob names of earlier versions
    $reportFile = Join-Path ([System.IO.Path]::GetTempPath()) "intune-devices-$(Get-Date -Format "yyyy-MM-dd").csv"
    $Exportdevices | ConvertTo-Csv -Delimiter ";" -NoTypeInformation > $reportFile
    $content = Get-Content $reportFile
    Set-Content -Path $reportFile -Value $content -Encoding utf8
    $reportFiles += $reportFile
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################

if ($reportFiles) {
    try {
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
            "## Export of all Intune devices created."
            "## Expiry of Link: $($uploadResult.EndTime)"
            $uploadResult.SASLink | Out-String
        }
    }
    catch {
        Write-RjRbLog -Message "Upload to storage account '$StorageAccountName' failed: $($_.Exception.Message). The managed identity needs the 'Reader and Data Access' role on the storage account." -Verbose
        $_
    }
}

#endregion Upload / Download Link

########################################################
#region     Cleanup
########################################################

foreach ($reportFile in $reportFiles) {
    Remove-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
}
Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null

#endregion Cleanup
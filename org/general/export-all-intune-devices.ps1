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
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }
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

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.2.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

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
Write-RjRbLog -Message "FilterGroupID: $FilterGroupID" -Verbose

"## Trying to export all Intune devices and metadata based on their owner, like usageLocation."

#endregion RJ Log Part

########################################################
#region     Variables
########################################################

$OwnerMetadataSelect = "city,country,companyName,department,jobTitle,usageLocation,onPremisesExtensionAttributes"

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

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

# Invoke-MgGraphRequest returns PSCustomObjects in the property order of the Graph response, as the earlier RunbookHelper calls did,
# so the CSV keeps its columns; the default is removed again after the collection
$PSDefaultParameterValues['Invoke-MgGraphRequest:OutputType'] = 'PSObject'
try {
    $groupUserLookup = $null
    if ($FilterGroupID) {
        Write-RjRbLog -Message "FilterGroupID provided: '$FilterGroupID'" -Verbose

        Write-RjRbLog -Message "Fetching transitive user members for group filter." -Verbose
        $userIdSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $upnSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        $members = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$FilterGroupID/transitiveMembers/microsoft.graph.user?`$select=id,userPrincipalName"
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

    $Exportdevices = @()
    Write-RjRbLog "Fetching all Intune devices."
    $Devices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=deviceName,lastSyncDateTime,enrolledDateTime,userPrincipalName,userId,id,serialNumber,manufacturer,model,imei,managedDeviceOwnerType,operatingSystem,osVersion,complianceState"

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
            $ownerReference = $null
            if ($Device.userId) {
                $ownerReference = [string] $Device.userId
            }
            else {
                $ownerReference = [string] $Device.userPrincipalName
            }

            # A missing or unreadable owner only leaves the owner columns empty
            $primaryOwner = $null
            try {
                $primaryOwner = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($ownerReference))?`$select=$OwnerMetadataSelect" -Method GET -ErrorAction Stop
            }
            catch {
                Write-RjRbLog -Message "Owner '$ownerReference' of device '$($Device.id)' could not be read: $($_.Exception.Message)" -Verbose
            }

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
    # Fail the run: an incomplete device list (wrong FilterGroupID, missing permission) must not end as a finished export
    throw
}
finally {
    $PSDefaultParameterValues.Remove('Invoke-MgGraphRequest:OutputType')
}

#endregion Data Collection

########################################################
#region     Report File Export
########################################################

# The local file name becomes the blob name, so uploads keep the blob names of earlier versions
$reportFiles = @()
$reportFile = Join-Path ([System.IO.Path]::GetTempPath()) "intune-devices-$(Get-Date -Format "yyyy-MM-dd").csv"
$Exportdevices | ConvertTo-Csv -Delimiter ";" -NoTypeInformation > $reportFile
$content = Get-Content $reportFile
Set-Content -Path $reportFile -Value $content -Encoding utf8
$reportFiles += $reportFile

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
        # The upload is the delivery of this runbook: fail the job, but remove the local report files first
        foreach ($reportFile in $reportFiles) {
            Remove-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

#endregion Upload / Download Link

########################################################
#region     Cleanup
########################################################

foreach ($reportFile in $reportFiles) {
    Remove-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
}
if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}
Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion Cleanup
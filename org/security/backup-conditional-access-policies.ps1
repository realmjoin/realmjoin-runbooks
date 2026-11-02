<#
	.SYNOPSIS
	Back up all Conditional Access policies to Azure Storage

	.DESCRIPTION
	Exports every Conditional Access policy of the tenant as JSON and uploads them as one ZIP archive to an Azure Storage account. The backup lets you compare or restore policies later. Without a container name, a container named after the current date is used. Nothing is changed in the tenant.

	.PARAMETER ContainerName
	Storage container the archive is uploaded to. Taken from the tenant setting CaPoliciesExport.Container; empty means a container named after the current date.

	.PARAMETER ResourceGroupName
	Resource group of the storage account for the backup. Taken from the tenant setting CaPoliciesExport.ResourceGroup; when it is not set, the Automation variable SettingsExports is read, then RJReport.StorageAccount.ResourceGroup.

	.PARAMETER StorageAccountName
	Storage account for the backup. Taken from the tenant setting CaPoliciesExport.StorageAccount.Name; when it is not set, the Automation variable SettingsExports is read, then RJReport.StorageAccount.StorageAccountName.

	.PARAMETER SubscriptionId
	Subscription ID of the storage account given in ResourceGroupName and StorageAccountName. Not taken from a tenant setting; the subscription the managed identity signs in to is used when empty.

	.PARAMETER StorageAccountLocation
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER StorageAccountSku
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER RJReportResourceGroupName
	Resource group of the storage account for the backup. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when neither CaPoliciesExport.ResourceGroup nor the Automation variable SettingsExports sets one.

	.PARAMETER RJReportStorageAccountName
	Storage account for the backup. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when neither CaPoliciesExport.StorageAccount.Name nor the Automation variable SettingsExports sets one.

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
			"SubscriptionId": {
				"Hide": true
			},
			"StorageAccountLocation": {
				"Hide": true
			},
			"StorageAccountSku": {
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
    # Legacy report settings: CaPoliciesExport.* - rebind to RJReport.StorageAccount.* (ContainerName: unbind) when it is switched off
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "CaPoliciesExport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "CaPoliciesExport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "CaPoliciesExport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    # Legacy report settings: set only explicitly for now - bind to RJReport.StorageAccount.SubscriptionId when it is switched off
    [string] $SubscriptionId,
    # Legacy report settings: deprecated and ignored, kept so existing schedules and API calls keep starting
    [string] $StorageAccountLocation,
    [string] $StorageAccountSku,
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

# Write a JSON file from a Policy / group description object
function Export-PolicyObject {
    param (
        [Parameter(Mandatory = $true)]
        [array]$policies
    )

    $policies | ForEach-Object {
        $name = $_.displayName -replace "[$([RegEx]::Escape([string][IO.Path]::GetInvalidFileNameChars()))]+", "_"
        if (-not (Test-Path ($name + ".json"))) {
            $_ | ConvertTo-Json -Depth 6 > ($name + ".json")
        }
        else {
            "## Will not overwrite " + ($name + ".json") + ". Skipping."
        }

    }

}

########################################################
#region     Parameter Validation
########################################################

if (-not $ContainerName) {
    $ContainerName = "conditional-policy-backup-" + (get-date -Format "yyyy-MM-dd")
}

# Legacy report settings: fallback to the Az Automation variable SettingsExports, as in earlier versions
if ((-not $ResourceGroupName) -or (-not $StorageAccountName)) {
    $processConfigRaw = Get-AutomationVariable -name "SettingsExports" -ErrorAction SilentlyContinue
    if ($processConfigRaw) {
        $processConfig = $processConfigRaw | ConvertFrom-Json

        if (-not $ResourceGroupName) {
            $ResourceGroupName = $processConfig.exportResourceGroupName
        }

        if (-not $StorageAccountName) {
            $StorageAccountName = $processConfig.exportStorAccountName
        }
    }
}

# Legacy report settings: CaPoliciesExport.* stays bound to the original parameters, so explicit values, existing schedules
# and API calls behave as before and the legacy settings win, followed by SettingsExports. RJReport.StorageAccount.* fills in
# when neither is set.
if (-not ($ResourceGroupName -and $StorageAccountName) -and $RJReportResourceGroupName -and $RJReportStorageAccountName) {
    Write-RjRbLog -Message "Using RJReport.StorageAccount.* - CaPoliciesExport.* and SettingsExports are not configured" -Verbose
    $ResourceGroupName = $RJReportResourceGroupName
    $StorageAccountName = $RJReportStorageAccountName
    $SubscriptionId = $RJReportSubscriptionId
}

# Legacy report settings: remove with StorageAccountLocation / StorageAccountSku in the switch-off release
if ($PSBoundParameters.ContainsKey('StorageAccountLocation') -or $PSBoundParameters.ContainsKey('StorageAccountSku')) {
    $deprecationMessage = "StorageAccountLocation and StorageAccountSku are deprecated and ignored - the storage account is no longer created automatically. Re-create this schedule or drop both parameters from the API call; a later version removes them."
    Write-RjRbLog -Message "WARNING: $deprecationMessage"
    Write-Warning $deprecationMessage
}

if ((-not $ResourceGroupName) -or (-not $StorageAccountName)) {
    "## To backup cond. access policies to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
    ""
    "## Configure the following attributes (see https://docs.realmjoin.com/automation/runbooks/runbook-report-settings):"
    "## - RJReport.StorageAccount.ResourceGroup"
    "## - RJReport.StorageAccount.StorageAccountName"
    "## The runbook-specific CaPoliciesExport.ResourceGroup and CaPoliciesExport.StorageAccount.Name are still read and take precedence."
    ""
    "## Stopping execution."
    throw "Missing Storage Account Configuration."
}

#endregion Parameter Validation

$reportFiles = @()
$exportFolder = Join-Path ([System.IO.Path]::GetTempPath()) "conditional-policy-backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

try {

    Connect-RjRbGraph
    Connect-RjRbAzAccount

    # fetch the policies
    $pols = Invoke-RjRbRestMethodGraph -Resource "/identity/conditionalAccess/policies"

    # Write policy export as files
    $policyFolder = Join-Path $exportFolder "CAPols"
    New-Item -Path $policyFolder -ItemType Directory -Force | Out-Null
    Push-Location -Path $policyFolder
    Export-PolicyObject -policies $pols
    Pop-Location

    # Compressed Archive mode - the archive name becomes the blob name, as in earlier versions
    $reportFile = Join-Path $exportFolder "$ContainerName.zip"
    Compress-Archive -Path (Join-Path $policyFolder "*") -DestinationPath $reportFile | Out-Null
    $reportFiles += $reportFile

    # Upload and create signed (SAS) link
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
    }
    catch {
        Write-RjRbLog -Message "Upload to storage account '$StorageAccountName' failed: $($_.Exception.Message). The managed identity needs the 'Reader and Data Access' role on the storage account." -Verbose
        throw $_
    }

    foreach ($uploadResult in $uploadResults) {
        "## Successfully created Conditional Access Export."
        "## Expiry of the Link: $($uploadResult.EndTime)"
        $uploadResult.SASLink | Out-String
    }

}
catch {
    throw $_
}
finally {
    Disconnect-AzAccount -Confirm:$false | Out-Null
}

########################################################
#region     Cleanup
########################################################

Remove-Item -LiteralPath $exportFolder -Recurse -Force -ErrorAction SilentlyContinue

#endregion Cleanup
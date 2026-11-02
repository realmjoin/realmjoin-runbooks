<#
	.SYNOPSIS
	List app registrations possibly affected by CVE-2021-42306

	.DESCRIPTION
	Checks the key credentials of every app registration in Entra ID for signs of CVE-2021-42306, where private key material was stored in the credential by mistake. App registrations that may be affected are listed. The result can be shown in the run output or exported as a CSV file to an Azure Storage account. Nothing is changed.

	.PARAMETER ExportToFile
	List in the run output, or export to a CSV file in the storage account configured in the tenant settings.

	.PARAMETER ContainerName
	Storage container the report files are uploaded to. Taken from the tenant setting VulnAppRegExport.Container, otherwise set per runbook.

	.PARAMETER ResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting VulnAppRegExport.ResourceGroup; when it is not set, RJReport.StorageAccount.ResourceGroup is used.

	.PARAMETER StorageAccountName
	Storage account for report uploads. Taken from the tenant setting VulnAppRegExport.StorageAccount.Name; when it is not set, RJReport.StorageAccount.StorageAccountName is used.

	.PARAMETER SubscriptionId
	Subscription ID of the storage account given in ResourceGroupName and StorageAccountName. Not taken from a tenant setting; the subscription the managed identity signs in to is used when empty.

	.PARAMETER StorageAccountLocation
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER StorageAccountSku
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER RJReportResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when VulnAppRegExport.ResourceGroup is not set.

	.PARAMETER RJReportStorageAccountName
	Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when VulnAppRegExport.StorageAccount.Name is not set.

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
			},
			"ExportToFile": {
				"Select": {
					"Options": [
						{
							"Display": "Export to a CSV file",
							"ParameterValue": true
						},
						{
							"Display": "List in the run output",
							"ParameterValue": false,
							"Customization": {
								"Hide": [
									"ContainerName",
									"ResourceGroupName",
									"StorageAccountName",
									"SubscriptionId",
									"StorageAccountLocation",
									"StorageAccountSku",
									"RJReportResourceGroupName",
									"RJReportStorageAccountName",
									"RJReportSubscriptionId",
									"LinkExpiryDays"
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Output" } )]
    [bool] $ExportToFile = $false,
    # Legacy report settings: VulnAppRegExport.* - rebind to RJReport.StorageAccount.* (ContainerName: unbind) when it is switched off
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "VulnAppRegExport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "VulnAppRegExport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "VulnAppRegExport.StorageAccount.Name" } )]
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

########################################################
#region     Parameter Validation
########################################################

if (-not $ContainerName) {
    $ContainerName = "list-vulnerableappreg"
}

# Legacy report settings: VulnAppRegExport.* stays bound to the original parameters, so explicit values, existing schedules
# and API calls behave as before and the legacy settings win. RJReport.StorageAccount.* fills in when they are not set.
if (-not ($ResourceGroupName -and $StorageAccountName) -and $RJReportResourceGroupName -and $RJReportStorageAccountName) {
    Write-RjRbLog -Message "Using RJReport.StorageAccount.* - VulnAppRegExport.* is not configured" -Verbose
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

if ($ExportToFile -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
    ""
    "## Configure the following attributes (see https://docs.realmjoin.com/automation/runbooks/runbook-report-settings):"
    "## - RJReport.StorageAccount.ResourceGroup"
    "## - RJReport.StorageAccount.StorageAccountName"
    "## The runbook-specific VulnAppRegExport.ResourceGroup and VulnAppRegExport.StorageAccount.Name are still read and take precedence."
    ""
    "## Stopping execution."
    throw "Missing Storage Account Configuration."
}

#endregion Parameter Validation

Connect-RjRbGraph

"## AzureAD App. Registrations possibly vulnerable to CVE-2021-42306:"

$beforedate = "2021-12-06T00:00:00Z"
#$appregs = Invoke-RjRbRestMethodGraph -Resource "/applications" -OdSelect "displayName,id,appId,createdDateTime,keyCredentials" -OdFilter "createdDateTime ge $beforedate"
$appregs = Invoke-RjRbRestMethodGraph -Resource "/applications" -OdSelect "displayName,id,appId,createdDateTime,keyCredentials" -FollowPaging

$AffectedAppRegs = @()
foreach ($appreg in $appregs) {
    if ($appreg.displayName) {
        $DisplayName = $appreg.displayName
    }
    else {
        $DisplayName = "$(AppId) ($appreg.AppId)"
    }
    $appID = $appReg.AppId

    $ErrorActionPreference = 'SilentlyContinue'

    Write-RjRbLog "Trying - $displayName - $appId"
    foreach ($cred in $appReg.keyCredentials) {
        if ($cred.Key.Length -gt 2000) {

            $isBefore = $false
            $certResults = $null

            # Only interested in "old" credentials
            if (get-date($cred.startdate) -le get-date($beforedate)) {
                $isBefore = $true

                $outputBase = "$PWD\$appID"
                $outputFile = "$PWD\$appID.pfx"
                $iter = 1
                while (Test-Path $outputFile) {
                    $outputFile = ( -join ($outputBase, '-', ([string]$iter), '.pfx'))
                    $iter += 1
                }
                Write-RjRbLog "Testing keyId $($cred.keyId)"
                [IO.File]::WriteAllBytes($outputFile, [Convert]::FromBase64String($cred.Key))
                $certResults = Get-PfxData $outputFile
            }

            if (($null -ne $certResults) -and $isBefore) {
                if ($ExportToFile) {
                    Write-RjRbLog "`t$displayName - $appID - has a potentially vulnerable stored credentials"
                }
                else {
                    "## $DisplayName - $appID - $appID - has a potentially vulnerable stored credentials"
                }
                $AffectedAppRegs += "$displayName `t $appID"
            }
            if (Test-Path $outputFile) {
                Remove-Item $outputFile | Out-Null
            }
        }
    }
}

########################################################
#region     Report File Export
########################################################

$reportFiles = @()
if ($ExportToFile) {
    # The local file name becomes the blob name, so uploads keep the blob names of earlier versions
    $reportFile = Join-Path ([System.IO.Path]::GetTempPath()) "$(Get-Date -Format yyyy-MM-dd)-AffectedAppRegs.csv"
    $AffectedAppRegs | ConvertTo-Csv -Delimiter ";" > $reportFile
    $content = Get-Content -Path $reportFile
    Set-Content -Value $content -Path $reportFile -Encoding UTF8
    $reportFiles += $reportFile
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################

if ($ExportToFile) {
    Connect-RjRbAzAccount
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
            "## Export of Vulnerable App registrations created."
            "## Expiry of Link: $($uploadResult.EndTime)"
            $uploadResult.SASLink | Out-String
        }
    }
    catch {
        Write-RjRbLog -Message "Upload to storage account '$StorageAccountName' failed: $($_.Exception.Message). The managed identity needs the 'Reader and Data Access' role on the storage account." -Verbose
        "## Upload of report failed. Please see log."
        ""
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

#endregion Cleanup
<#
	.SYNOPSIS
	Export the owners and users of all enterprise applications

	.DESCRIPTION
	Lists all enterprise applications, or all service principals, with their owners and the users and groups assigned to them, for reviews and audits. Nothing is changed. The report can be sent by email or provided as a download link.

	.PARAMETER entAppsOnly
	Enterprise applications only, or every service principal in the tenant.

	.PARAMETER ReportFileFormat
	Deliver the report as CSV, as an Excel workbook, or both.

	.PARAMETER CreateDownloadLink
	Also upload the report and return a download link that expires after a few days.

	.PARAMETER ContainerName
	Storage container the report files are uploaded to. Taken from the tenant setting EntAppsReport.Container.

	.PARAMETER ResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting EntAppsReport.ResourceGroup; when it is not set, RJReport.StorageAccount.ResourceGroup is used.

	.PARAMETER StorageAccountName
	Storage account for report uploads. Taken from the tenant setting EntAppsReport.StorageAccount.Name; when it is not set, RJReport.StorageAccount.StorageAccountName is used.

	.PARAMETER SubscriptionId
	Subscription ID of the storage account given in ResourceGroupName and StorageAccountName. Not taken from a tenant setting; the subscription the managed identity signs in to is used when empty.

	.PARAMETER LinkExpiryDays
	Number of days a download link stays valid. Taken from the tenant setting EntAppsReport.LinkExpiryDays; when it is not set, RJReport.StorageAccount.LinkExpiryDays is used.

	.PARAMETER RJReportResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when EntAppsReport.ResourceGroup is not set.

	.PARAMETER RJReportStorageAccountName
	Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when EntAppsReport.StorageAccount.Name is not set.

	.PARAMETER RJReportSubscriptionId
	Subscription ID of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.SubscriptionId and used when the storage account comes from RJReport.StorageAccount.

	.PARAMETER RJReportLinkExpiryDays
	Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays and used when EntAppsReport.LinkExpiryDays is not set.

	.PARAMETER EmailTo
	Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

	.PARAMETER EmailFrom
	Sender address of the report email. Taken from the tenant setting RJReport.EmailSender.

	.PARAMETER BrandingHeaderImageUrl
	Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty.

	.PARAMETER BrandingFooterImageUrl
	Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty.

	.PARAMETER BrandingFooterLink
	Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty.

	.PARAMETER BrandingAccentColor
	Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid.

	.PARAMETER BrandingTextColor
	Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid.

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
			"LinkExpiryDays": {
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
			"RJReportLinkExpiryDays": {
				"Hide": true
			},
			"entAppsOnly": {
				"DisplayName": "Scope",
				"SelectSimple": {
					"List only Enterprise Apps": true,
					"List all Service Principals / Apps": false
				}
			},
			"ReportFileFormat": {
				"DisplayName": "Report file format",
				"Select": {
					"Options": [
						{
							"Display": "CSV & XLSX",
							"ParameterValue": "CSV & XLSX"
						},
						{
							"Display": "CSV only",
							"ParameterValue": "CSV only"
						},
						{
							"Display": "XLSX only",
							"ParameterValue": "XLSX only"
						}
					],
					"ShowValue": false
				}
			},
			"CreateDownloadLink": {
				"DisplayName": "Create a download link?",
				"SelectSimple": {
					"Yes - upload report and return a download link": true,
					"No - do not create a download link": false
				}
			},
			"EmailTo": {
				"DisplayName": "Recipient email address(es)"
			},
			"EmailFrom": {
				"Hide": true
			},
			"BrandingHeaderImageUrl": {
				"Hide": true
			},
			"BrandingFooterImageUrl": {
				"Hide": true
			},
			"BrandingFooterLink": {
				"Hide": true
			},
			"BrandingAccentColor": {
				"Hide": true
			},
			"BrandingTextColor": {
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
    [ValidateScript( { Use-RJInterface -DisplayName "Scope" } )]
    [bool] $entAppsOnly = $true,
    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'CSV & XLSX',
    [bool] $CreateDownloadLink = $true,
    # Legacy report settings: EntAppsReport.* - rebind to RJReport.StorageAccount.* (ContainerName: unbind) when it is switched off
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "EntAppsReport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "EntAppsReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "EntAppsReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    # Legacy report settings: set only explicitly for now - bind to RJReport.StorageAccount.SubscriptionId when it is switched off
    [string] $SubscriptionId,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "EntAppsReport.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
    [string] $RJReportResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
    [string] $RJReportStorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.SubscriptionId" } )]
    [string] $RJReportSubscriptionId,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int] $RJReportLinkExpiryDays,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string] $EmailFrom,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" } )]
    [string] $BrandingHeaderImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" } )]
    [string] $BrandingFooterImageUrl,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" } )]
    [string] $BrandingFooterLink,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" } )]
    [string] $BrandingAccentColor,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" } )]
    [string] $BrandingTextColor,
    [string] $EmailTo,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

############################################################
#region     RJ Log Part
############################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.5.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "entAppsOnly: $entAppsOnly" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
Write-RjRbLog -Message "SubscriptionId: $SubscriptionId" -Verbose
Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
Write-RjRbLog -Message "RJReportResourceGroupName: $RJReportResourceGroupName" -Verbose
Write-RjRbLog -Message "RJReportStorageAccountName: $RJReportStorageAccountName" -Verbose
Write-RjRbLog -Message "RJReportSubscriptionId: $RJReportSubscriptionId" -Verbose
Write-RjRbLog -Message "RJReportLinkExpiryDays: $RJReportLinkExpiryDays" -Verbose
if ($EmailTo) {
    Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
    Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
    Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
}

#endregion RJ Log Part

############################################################
#region     Parameter Validation
############################################################

# Validate Email Addresses (only if email is requested)
if ($EmailTo) {
    if (-not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -Verbose
    throw "This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings"
    exit
    }
}

#endregion Parameter Validation

############################################################
#region     Function Definitions
############################################################

#endregion Function Definitions

############################################################
#region     Connect Part
############################################################

Connect-RjRbGraph
Connect-RjRbAzAccount

# Get tenant information for the email report
$TenantDisplayName = "Unknown Tenant"
if ($EmailTo) {
    try {
        $tenantInfo = Invoke-RjRbRestMethodGraph -Resource "/organization" -OdSelect "displayName"
        if ($tenantInfo -and $tenantInfo[0].displayName) {
            $TenantDisplayName = $tenantInfo[0].displayName
        }
    }
    catch {
        Write-RjRbLog -Message "Failed to retrieve tenant display name: $($_.Exception.Message)" -Verbose
    }
}

#endregion Connect Part

############################################################
#region     Main Part
############################################################

$brandingMailParams = @{}

try {

    #region Configuration
    ##############################

    if (-not $ContainerName) {
        $ContainerName = "enterprise-apps-users"
    }

    # Storage account configuration is only required when a download link is requested
    if ($CreateDownloadLink) {
        # Legacy report settings: EntAppsReport.* stays bound to the original parameters, so explicit values, existing schedules
        # and API calls behave as before and the legacy settings win. Next comes the Az Automation Variable "SettingsExports",
        # then RJReport.StorageAccount.* fills in when neither is set.
        # Configuration import - fallback to Az Automation Variable
        if ((-not $ResourceGroupName) -or (-not $StorageAccountName)) {
            $processConfigRaw = Get-AutomationVariable -name "SettingsExports" -ErrorAction SilentlyContinue
            #if (-not $processConfigRaw) {
            ## production default - use this as template to create the Az. Automation Variable "SettingsExports"
            #    $processConfigURL = "https://raw.githubusercontent.com/realmjoin/realmjoin-runbooks/production/setup/defaults/settings-org-policies-export.json"
            #    $webResult = Invoke-WebRequest -UseBasicParsing -Uri $processConfigURL
            #    $processConfigRaw = $webResult.Content        ## staging default
            #}
            # Write-RjRbDebug "Process Config URL is $($processConfigURL)"

            # "Getting Process configuration"
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

        if (-not ($ResourceGroupName -and $StorageAccountName) -and $RJReportResourceGroupName -and $RJReportStorageAccountName) {
            Write-RjRbLog -Message "Using RJReport.StorageAccount.* - EntAppsReport.* is not configured" -Verbose
            $ResourceGroupName = $RJReportResourceGroupName
            $StorageAccountName = $RJReportStorageAccountName
            $SubscriptionId = $RJReportSubscriptionId
        }

        # Legacy report settings: EntAppsReport.LinkExpiryDays wins, RJReport.StorageAccount.LinkExpiryDays fills in when it is not set
        if (-not $PSBoundParameters.ContainsKey('LinkExpiryDays') -and $RJReportLinkExpiryDays) {
            Write-RjRbLog -Message "Using RJReport.StorageAccount.LinkExpiryDays - EntAppsReport.LinkExpiryDays is not configured" -Verbose
            $LinkExpiryDays = $RJReportLinkExpiryDays
        }

        if ((-not $ResourceGroupName) -or (-not $StorageAccountName)) {
            "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
            "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
            ""
            "## Configure the following attributes (see https://docs.realmjoin.com/automation/runbooks/runbook-report-settings):"
            "## - RJReport.StorageAccount.ResourceGroup"
            "## - RJReport.StorageAccount.StorageAccountName"
            "## The runbook-specific EntAppsReport.ResourceGroup and EntAppsReport.StorageAccount.Name are still read and take precedence."
            ""
            "## Stopping execution."
            throw "Missing Storage Account Configuration."
        }
    }

    #endregion Configuration

    #region Data Collection
    ##############################

    $invokeParams = @{
        resource = "/servicePrincipals"
    }

    if ($entAppsOnly) {
        $invokeParams += @{
            OdFilter = "tags/any(t:t eq 'WindowsAzureActiveDirectoryIntegratedApp')"
        }
    }
    # Get Ent. Apps / Service Principals
    $servicePrincipals = Invoke-RjRbRestMethodGraph @invokeParams

    #endregion Data Collection

    #region Report Data
    ##############################

    $reportData = @($servicePrincipals | ForEach-Object {
            $AppId = $_.appId
            $AppDisplayName = $_.displayName
            $AccountEnabled = $_.accountEnabled
            $HideApp = $_.tags -contains "hideapp"
            $AssignmentRequired = $_.appRoleAssignmentRequired

            if ($_.notes) {
                $Notes = [string]::join(" ", ($_.notes.Split("`n") -replace (';', ',')))
            }
            else {
                $Notes = ""
            }

            # Get Owners
            $owners = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($_.id)/owners"
            if ($owners) {
                $owners | ForEach-Object {
                    [PSCustomObject]@{
                        AppId              = $AppId
                        AppDisplayName     = $AppDisplayName
                        AccountEnabled     = $AccountEnabled
                        HideApp            = $HideApp
                        AssignmentRequired = $AssignmentRequired
                        PrincipalRole      = "Owner"
                        PrincipalType      = "User"
                        PrincipalId        = $_.userPrincipalName
                        Notes              = $Notes
                    }
                }
            }
            else {
                # Make sure to list apps missing an owner
                [PSCustomObject]@{
                    AppId              = $AppId
                    AppDisplayName     = $AppDisplayName
                    AccountEnabled     = $AccountEnabled
                    HideApp            = $HideApp
                    AssignmentRequired = $AssignmentRequired
                    PrincipalRole      = "Owner"
                    PrincipalType      = "User"
                    PrincipalId        = ""
                    Notes              = $Notes
                }
            }

            # Get App Role assignments
            $users = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($_.id)/appRoleAssignedTo"
            $users | ForEach-Object {
                if ($_.principalType -eq "User") {
                    $userobject = Invoke-RjRbRestMethodGraph -Resource "/users/$($_.principalId)"
                    [PSCustomObject]@{
                        AppId              = $AppId
                        AppDisplayName     = $AppDisplayName
                        AccountEnabled     = $AccountEnabled
                        HideApp            = $HideApp
                        AssignmentRequired = $AssignmentRequired
                        PrincipalRole      = "Member"
                        PrincipalType      = "User"
                        PrincipalId        = $userobject.userPrincipalName
                        Notes              = $Notes
                    }
                }
                elseif ($_.principalType -eq "Group") {
                    $groupobject = Invoke-RjRbRestMethodGraph -Resource "/groups/$($_.principalId)"
                    [PSCustomObject]@{
                        AppId              = $AppId
                        AppDisplayName     = $AppDisplayName
                        AccountEnabled     = $AccountEnabled
                        HideApp            = $HideApp
                        AssignmentRequired = $AssignmentRequired
                        PrincipalRole      = "Member"
                        PrincipalType      = "Group"
                        PrincipalId        = "$($groupobject.mailNickname) ($($groupobject.displayName))"
                        Notes              = $Notes
                    }
                }
                elseif ($_.principalType -eq "ServicePrincipal") {
                    [PSCustomObject]@{
                        AppId              = $AppId
                        AppDisplayName     = $AppDisplayName
                        AccountEnabled     = $AccountEnabled
                        HideApp            = $HideApp
                        AssignmentRequired = $AssignmentRequired
                        PrincipalRole      = "Member"
                        PrincipalType      = "ServicePrincipal"
                        PrincipalId        = $_.principalId
                        Notes              = $Notes
                    }
                }
            }
        })

    $totalRows = $reportData.Count
    $appCount = ($servicePrincipals | Measure-Object).Count

    #endregion Report Data

    #region Report File Export
    ##############################

    $reportFiles = @()
    $csvPath = $null
    $xlsxPath = $null
    $fileNameCsv = "enterpriseApps.csv"
    $fileNameXlsx = "enterpriseApps.xlsx"

    if (($EmailTo -or $CreateDownloadLink) -and $totalRows -gt 0) {
        if ($ReportFileFormat -ne 'XLSX only') {
            $csvPath = Join-Path -Path $((Get-Location).Path) -ChildPath $fileNameCsv
            $reportData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            $reportFiles += $csvPath
            Write-Output "Exported $totalRows rows to: $csvPath"
        }

        if ($ReportFileFormat -ne 'CSV only') {
            $xlsxPath = Join-Path -Path $((Get-Location).Path) -ChildPath $fileNameXlsx
            $reportData | Export-RjRbXlsx -Path $xlsxPath -WorksheetName "Enterprise App Users"
            $reportFiles += $xlsxPath
            Write-Output "Exported $totalRows rows to: $xlsxPath"
        }
    }
    elseif (($EmailTo -or $CreateDownloadLink) -and $totalRows -eq 0) {
        Write-Output "## No report data found - no report file to send or upload."
    }
    else {
        Write-Output "## Neither an email recipient (EmailTo) nor a download link (CreateDownloadLink) was requested - no report files are generated."
        Write-Output "## Report data ($totalRows rows):"
        $reportData | Format-Table -AutoSize | Out-String | Write-Output
    }

    #endregion Report File Export

    #region Upload
    ##############################

    if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths $reportFiles `
            -ContainerName $ContainerName `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -SubscriptionId $SubscriptionId `
            -LinkExpiryDays $LinkExpiryDays `
            -AddBlobNamePrefix $true

        "## App Owner/User List Export created."
        foreach ($uploadResult in $uploadResults) {
            "## Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String
        }
    }

    #endregion Upload

    #region Send Email Report
    ##############################

    if ($EmailTo -and $reportFiles.Count -gt 0) {
        Write-Output ""
        Write-Output "## Preparing email report to send to '$($EmailTo)'..."

        $scopeDescription = if ($entAppsOnly) { "Enterprise Applications" } else { "All Service Principals / Applications" }

        $emailSubject = "Enterprise Application Users Report - $(Get-Date -Format 'yyyy-MM-dd')"

        $markdownContent = @"
# Enterprise Application Users Report

**Scope:** $scopeDescription
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary
- Applications / service principals: **$appCount**
- Report rows (owners and assignments): **$totalRows**

## Data Files

The following file(s) are attached to this email:

$(if ($ReportFileFormat -ne 'XLSX only') { "- **$($fileNameCsv)**: Complete list of application owners and assigned users/groups (CSV)" })
$(if ($ReportFileFormat -ne 'CSV only') { "- **$($fileNameXlsx)**: The same list as a formatted Excel workbook" })

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $markdownFallback = @"
# Enterprise Application Users Report

**Scope:** $scopeDescription
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary
- Applications / service principals: **$appCount**
- Report rows (owners and assignments): **$totalRows**

## Data Files

- **$($fileNameXlsx)**: Formatted Excel workbook with the complete report

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

        # Resolve optional tenant email branding once per run (never fails the send)
        $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

        # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
        try {
            $guardParams = @{
                EmailFrom         = $EmailFrom
                EmailTo           = $EmailTo
                Subject           = $emailSubject
                MarkdownContent   = $markdownContent
                TenantDisplayName = $TenantDisplayName
                ReportVersion     = $Version
            }
            if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxPath) {
                Send-RjRbReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjRbReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
            }
        }
        catch {
            Write-Error "Failed to send email report: $($_.Exception.Message)"
            throw
        }
    }

    #endregion Send Email Report

    Write-Output ""
    Write-Output "Done!"

}
catch {
    throw $_
}
finally {
    #region Cleanup
    ##############################

    # Remove the downloaded branding images, if any were used.
    foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
        if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
            Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
        }
    }

    Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null

    #endregion Cleanup
}

#endregion Main Part

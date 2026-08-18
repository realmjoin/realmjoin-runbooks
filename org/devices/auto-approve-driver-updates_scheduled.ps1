<#
	.SYNOPSIS
	Auto-approve new driver updates in Intune driver update policies

	.DESCRIPTION
	This scheduled runbook automatically approves pending driver updates in one or more Intune driver update policies. It can filter driver updates by display name pattern, driver class, or manufacturer. Optional email notifications can be sent after approval operations complete.
	The notification email includes CSV and/or Excel (xlsx) report files listing every driver approval action (policy, driver, version, manufacturer, driver class, release date and outcome).
	The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
	The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
	When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

	.NOTES
	Prerequisites:
	- Microsoft Graph BETA API access (driver update endpoints are in beta)
	- RJReport.EmailSender setting configured (if email notifications are used)

	Common Use Cases:
	- Test filters first: Use WhatIf parameter to preview which drivers would be approved
	- Auto-approve all drivers: Run without any filter parameters
	- Approve specific manufacturers: Use DriverManufacturer to target vendors like "Intel" or "AMD"
	- Target specific policies: Use PolicyNames or PolicyIds to scope to test policies first
	- Monitor approvals: Configure EmailTo to receive detailed reports after each run

	Parameter Interactions:
	- If no policy filter is specified, ALL driver update policies are processed
	- If no driver filter is specified, ALL pending drivers in selected policies are approved
	- PolicyNames and PolicyIds can be combined - both filters apply independently
	- Email notifications require RJReport.EmailSender setting and Connect-RjRbGraph
	- WhatIf mode simulates approvals without making changes - useful for testing filters

	.PARAMETER PolicyNames
	(Optional) Comma-separated list of driver update policy names to scope the approval (e.g., "Policy1, Policy2, Policy3"). If not specified, all policies are processed.

	.PARAMETER PolicyIds
	(Optional) Comma-separated list of driver update policy IDs to scope the approval (e.g., "id1, id2, id3"). If not specified, all policies are processed.

	.PARAMETER DriverDisplayNamePattern
	(Optional) Filter driver updates by display name pattern (supports wildcards). Only matching drivers will be approved.

	.PARAMETER DriverClass
	(Optional) Filter by driver class IDs (comma-separated). Example: "Bluetooth,Networking,Firmware" for specific driver classes.

	.PARAMETER DriverManufacturer
	(Optional) Filter by driver manufacturer name. Only drivers from the specified manufacturer will be approved.

	.PARAMETER MaximumDriverAge
	(Optional) Maximum age in days for drivers to be approved. Only drivers released within the last X days will be approved. Example: 30 to only approve drivers released in the last 30 days.

	.PARAMETER ReportFileFormat
	Controls which report file formats are generated and delivered: "CSV only", "CSV & XLSX" (default) or "XLSX only".

	.PARAMETER CreateDownloadLink
	If enabled, the report files are uploaded to an Azure Storage Account and time-limited download links are returned. Disabled by default.

	.PARAMETER ContainerName
	Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

	.PARAMETER ResourceGroupName
	Resource group that contains the storage account. Sourced from the RJReport tenant settings.

	.PARAMETER StorageAccountName
	Storage account name used for the upload. Sourced from the RJReport tenant settings.

	.PARAMETER LinkExpiryDays
	Number of days until the generated download link expires. Sourced from the RJReport tenant settings.

	.PARAMETER EmailFrom
	Sender email address for notifications. This parameter is backed by a setting and should not be modified directly.

	.PARAMETER BrandingHeaderImageUrl
	Optional public HTTPS URL of a custom header image (PNG/JPEG/GIF, max. 200 KB) for the report email.
	Sourced from the RJReport.Branding.HeaderImageUrl tenant setting. When empty, the default RealmJoin header graphic is used.

	.PARAMETER BrandingFooterImageUrl
	Optional public HTTPS URL of a custom footer image (PNG/JPEG/GIF, max. 200 KB) for the report email.
	Sourced from the RJReport.Branding.FooterImageUrl tenant setting. When empty, the default RealmJoin footer graphic is used.

	.PARAMETER BrandingFooterLink
	Optional URL the footer image links to. Sourced from the RJReport.Branding.FooterLink tenant setting.
	When empty, the default link (https://www.realmjoin.com) is used.

	.PARAMETER EmailTo
	(Optional) Recipient email address for approval notifications. If not specified, no email is sent.

	.PARAMETER OnlyNeedsReview
	When enabled (default), only drivers with status "needsReview" are approved. Drivers with status "suspended" or "declined" are skipped. Disable to also re-approve suspended or declined drivers.

	.PARAMETER WhatIf
	(Optional) When enabled, simulates driver approvals without making actual changes. Shows which drivers would be approved and sends a report to EmailTo if configured.

	.PARAMETER CallerName
	Name of the user or system initiating the runbook. Used for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"PolicyNames": {
				"DisplayName": "Driver Update Policy Names",
				"Description": "(Optional) Comma-separated policy names to process (e.g., 'Policy1, Policy2'), leave empty for all policies"
			},
			"PolicyIds": {
				"DisplayName": "Driver Update Policy IDs",
				"Description": "(Optional) Comma-separated policy IDs to process (e.g., 'id1, id2'), leave empty for all policies"
			},
			"DriverDisplayNamePattern": {
				"DisplayName": "Driver Name Filter",
				"Description": "(Optional) Filter drivers by display name (supports wildcards)"
			},
			"DriverClass": {
				"DisplayName": "Driver Class Filter",
				"Description": "(Optional) Comma-separated driver class IDs (e.g., 'Bluetooth,Networking,Firmware')"
			},
			"DriverManufacturer": {
				"DisplayName": "Manufacturer Filter",
				"Description": "(Optional) Filter drivers by manufacturer name"
			},
			"MaximumDriverAge": {
				"DisplayName": "Maximum Driver Age (Days)",
				"Description": "(Optional) Only approve drivers released within the last X days (e.g., 30 = only drivers from the last 30 days)"
			},
			"EmailTo": {
				"DisplayName": "Notification Recipient",
				"Description": "(Optional) Email address to receive approval notifications"
			},
			"OnlyNeedsReview": {
				"DisplayName": "Only approve 'Needs Review' drivers",
				"Description": "When enabled (default), skip suspended and declined drivers - only approve drivers in 'needsReview' status"
			},
			"WhatIf": {
				"DisplayName": "What-If Mode (Dry Run)",
				"Description": "(Optional) Simulate approvals without making changes - useful for testing filters"
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
				"DisplayName": "Create a file download link (upload report to storage)?",
				"SelectSimple": {
					"Yes - upload report and return a download link": true,
					"No - do not create a download link": false
				}
			},
			"ContainerName": {
				"Hide": true
			},
			"ResourceGroupName": {
				"Hide": true
			},
			"StorageAccountName": {
				"Hide": true
			},
			"LinkExpiryDays": {
				"Hide": true
			},
			"CallerName": {
				"Hide": true
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
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param(
    [Parameter(Mandatory = $false)]
    [string]$PolicyNames,
    [Parameter(Mandatory = $false)]
    [string]$PolicyIds,
    [Parameter(Mandatory = $false)]
    [string]$DriverDisplayNamePattern,
    [Parameter(Mandatory = $false)]
    [string]$DriverClass,
    [Parameter(Mandatory = $false)]
    [string]$DriverManufacturer,
    [Parameter(Mandatory = $false)]
    [int]$MaximumDriverAge,
    [Parameter(Mandatory = $false)]
    [bool]$OnlyNeedsReview = $true,
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',
    [Parameter(Mandatory = $false)]
    [bool]$CreateDownloadLink = $false,
    [Parameter(Mandatory = $false)]
    [string]$ContainerName = "auto-approve-driver-updates",
    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ })]
    [string]$ResourceGroupName,
    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ })]
    [string]$StorageAccountName,
    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ })]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,
    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ })]
    [string]$EmailFrom,
    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ })]
    [string]$BrandingHeaderImageUrl,
    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ })]
    [string]$BrandingFooterImageUrl,
    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ })]
    [string]$BrandingFooterLink,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" -Value $_ } )]
    [string]$BrandingAccentColor,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" -Value $_ } )]
    [string]$BrandingTextColor,
    [Parameter(Mandatory = $false)]
    [string]$EmailTo,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.3.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "PolicyNames: $PolicyNames" -Verbose
Write-RjRbLog -Message "PolicyIds: $PolicyIds" -Verbose
Write-RjRbLog -Message "DriverDisplayNamePattern: $DriverDisplayNamePattern" -Verbose
Write-RjRbLog -Message "DriverClass: $DriverClass" -Verbose
Write-RjRbLog -Message "DriverManufacturer: $DriverManufacturer" -Verbose
Write-RjRbLog -Message "MaximumDriverAge: $MaximumDriverAge" -Verbose
Write-RjRbLog -Message "OnlyNeedsReview: $OnlyNeedsReview" -Verbose
Write-RjRbLog -Message "WhatIf: $WhatIf" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose

#endregion

########################################################
#region     Parameter Validation
########################################################

# Convert comma-separated strings to arrays (use separate variables to avoid typed-param coercion)
$PolicyNameList = @()
if ($PolicyNames) {
    $PolicyNameList = @($PolicyNames -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    Write-RjRbLog -Message "PolicyNames converted: $($PolicyNameList -join ', ')" -Verbose
}

$PolicyIdList = @()
if ($PolicyIds) {
    $PolicyIdList = @($PolicyIds -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    Write-RjRbLog -Message "PolicyIds converted: $($PolicyIdList -join ', ')" -Verbose
}

# Validate that at least one policy selection method is provided
if ($PolicyNameList.Count -eq 0 -and $PolicyIdList.Count -eq 0) {
    Write-RjRbLog -Message "No policy filter specified - will process all driver update policies" -Verbose
}

# Validate driver filter criteria
if (-not $DriverDisplayNamePattern -and -not $DriverClass -and -not $DriverManufacturer -and -not $MaximumDriverAge) {
    Write-RjRbLog -Message "WARNING: No driver filter specified - will approve ALL pending drivers in selected policies" -Verbose
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

#endregion

########################################################
#region     Function Definitions
########################################################

#endregion

########################################################
#region     Connect Part
########################################################

Write-RjRbLog -Message "Connecting to Microsoft Graph using Managed Identity..." -Verbose

try {
    Connect-MgGraph -Identity -NoWelcome
    Write-RjRbLog -Message "Successfully connected to Microsoft Graph" -Verbose
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $_" -ErrorAction Continue
    throw
}

# Connect to RealmJoin RunbookHelper (required for Send-RjReportEmail if EmailTo is provided)
if ($EmailTo) {
    Write-RjRbLog -Message "Email notification requested - connecting to RJ RunbookHelper Graph..." -Verbose
    try {
        Connect-RjRbGraph
        Write-RjRbLog -Message "Successfully connected to RJ RunbookHelper Graph" -Verbose
    }
    catch {
        Write-Error "Failed to connect to RJ RunbookHelper Graph: $_" -ErrorAction Continue
        throw
    }
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get Driver Update Policies"
Write-Output "---------------------"

# Retrieve all driver update policies
Write-RjRbLog -Message "Retrieving Windows Driver Update Profiles from Intune..." -Verbose

try {
    $uri = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles"
    $allPolicies = @()

    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $allPolicies += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)

    Write-RjRbLog -Message "Retrieved $($allPolicies.Count) driver update policy/policies" -Verbose
}
catch {
    Write-Error "Failed to retrieve driver update policies: $_" -ErrorAction Continue
    throw
}

# Filter policies based on PolicyNames or PolicyIds if provided
$targetPolicies = $allPolicies

if ($PolicyIdList.Count -gt 0) {
    Write-RjRbLog -Message "Filtering by Policy IDs: $($PolicyIdList -join ', ')" -Verbose
    $targetPolicies = $targetPolicies | Where-Object { $PolicyIdList -contains $_.id }
}

if ($PolicyNameList.Count -gt 0) {
    Write-RjRbLog -Message "Filtering by Policy Names: $($PolicyNameList -join ', ')" -Verbose
    $targetPolicies = $targetPolicies | Where-Object { $PolicyNameList -contains $_.displayName }
}

if ($targetPolicies.Count -eq 0) {
    Write-Error "No driver update policies found matching the specified criteria." -ErrorAction Continue
    throw "No policies found to process"
}

Write-Output "Processing $($targetPolicies.Count) driver update policy/policies:"
foreach ($policy in $targetPolicies) {
    Write-Output "  - $($policy.displayName) (ID: $($policy.id))"
}

#endregion

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Process Driver Updates"
Write-Output "---------------------"

if ($WhatIf) {
    Write-Output ""
    Write-Output "*** WHAT-IF MODE ENABLED ***"
    Write-Output "No actual approvals will be made. This is a simulation only."
    Write-Output ""
    Write-RjRbLog -Message "Running in WhatIf mode - no approvals will be performed" -Verbose
}

$approvalSummary = @{
    TotalPoliciesProcessed = 0
    TotalDriversReviewed = 0
    TotalDriversApproved = 0
    FailedApprovals = 0
    Details = @()
}

# Detailed per-driver report rows (used for the CSV/XLSX report files)
$driverReportRows = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($policy in $targetPolicies) {
    Write-Output ""
    Write-Output "Processing policy: $($policy.displayName)"
    $approvalSummary.TotalPoliciesProcessed++

    $policyDetails = @{
        PolicyName = $policy.displayName
        PolicyId = $policy.id
        DriversReviewed = 0
        DriversApproved = 0
        ApprovedDrivers = @()
    }

    # Get driver updates for this policy
    try {
        $driversUri = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$($policy.id)/driverInventories"
        $allDrivers = @()

        do {
            $driverResponse = Invoke-MgGraphRequest -Method GET -Uri $driversUri
            if ($driverResponse.value) {
                $allDrivers += $driverResponse.value
            }
            $driversUri = $driverResponse.'@odata.nextLink'
        } while ($driversUri)

        Write-RjRbLog -Message "Found $($allDrivers.Count) driver(s) in policy '$($policy.displayName)'" -Verbose
        $policyDetails.DriversReviewed = $allDrivers.Count
        $approvalSummary.TotalDriversReviewed += $allDrivers.Count

        # Filter drivers based on criteria
        $driversToApprove = $allDrivers

        # Filter by display name pattern
        if ($DriverDisplayNamePattern) {
            Write-RjRbLog -Message "Filtering by display name pattern: $DriverDisplayNamePattern" -Verbose
            $driversToApprove = $driversToApprove | Where-Object { $_.name -like $DriverDisplayNamePattern }
        }

        # Filter by driver class
        if ($DriverClass) {
            $classIds = $DriverClass -split ',' | ForEach-Object { $_.Trim() }
            Write-RjRbLog -Message "Filtering by driver class IDs: $($classIds -join ', ')" -Verbose
            $driversToApprove = $driversToApprove | Where-Object { $classIds -contains $_.driverClass }
        }

        # Filter by manufacturer
        if ($DriverManufacturer) {
            Write-RjRbLog -Message "Filtering by manufacturer: $DriverManufacturer" -Verbose
            $driversToApprove = $driversToApprove | Where-Object { $_.manufacturer -like $DriverManufacturer }
        }

        # Filter by maximum driver age (release date)
        if ($MaximumDriverAge) {
            $cutoffDate = (Get-Date).AddDays(-$MaximumDriverAge)
            Write-RjRbLog -Message "Filtering by maximum driver age: $MaximumDriverAge days (released after $(Get-Date $cutoffDate -Format 'yyyy-MM-dd'))" -Verbose
            $driversToApprove = $driversToApprove | Where-Object {
                $releaseDate = $null
                if ($_.releaseDateTime) {
                    $releaseDate = [DateTime]::Parse($_.releaseDateTime)
                }
                $releaseDate -and $releaseDate -ge $cutoffDate
            }
        }

        # Filter drivers by approval status
        if ($OnlyNeedsReview) {
            $driversNeedingApproval = $driversToApprove | Where-Object { $_.approvalStatus -eq 'needsReview' }
            $skippedCount = $driversToApprove.Count - $driversNeedingApproval.Count
        }
        else {
            $driversNeedingApproval = $driversToApprove | Where-Object { $_.approvalStatus -ne 'approved' }
            $skippedCount = $driversToApprove.Count - $driversNeedingApproval.Count
        }

        Write-Output "  Drivers matching filter criteria: $($driversToApprove.Count)"
        if ($skippedCount -gt 0) {
            if ($OnlyNeedsReview) {
                Write-Output "  Skipped (not in 'needsReview' status - suspended/declined/approved): $skippedCount"
            }
            else {
                Write-Output "  Already approved (will skip): $skippedCount"
            }
            Write-Output "  Drivers to approve: $($driversNeedingApproval.Count)"
        }

        if ($driversNeedingApproval.Count -eq 0) {
            Write-Output "  No drivers to approve in this policy."
        }
        elseif ($WhatIf) {
            foreach ($driver in $driversNeedingApproval) {
                Write-Output "    [WHATIF] Would approve: $($driver.name) (v$($driver.version)) - $($driver.manufacturer)"
                Write-RjRbLog -Message "[WhatIf] Would approve driver: $($driver.name) (ID: $($driver.id))" -Verbose
                $policyDetails.DriversApproved++
                $policyDetails.ApprovedDrivers += $driver.name
                $approvalSummary.TotalDriversApproved++
                $driverReportRows.Add([PSCustomObject]@{
                    Policy       = $policy.displayName
                    DriverName   = $driver.name
                    Version      = $driver.version
                    Manufacturer = $driver.manufacturer
                    DriverClass  = $driver.driverClass
                    ReleaseDate  = $driver.releaseDateTime
                    Action       = "Would approve"
                })
            }
        }
        else {
            # Approve all matching drivers in a single bulk call
            try {
                $approvalUri = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$($policy.id)/ExecuteAction"
                $approvalBody = @{
                    actionName     = "approve"
                    driverIds      = @($driversNeedingApproval | Select-Object -ExpandProperty id)
                    deploymentDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                } | ConvertTo-Json

                $result = Invoke-MgGraphRequest -Method POST -Uri $approvalUri -Body $approvalBody -ContentType "application/json"

                $succeeded = @($result.successfulDriverIds)
                $failed    = @($result.failedDriverIds)
                $notFound  = @($result.notFoundDriverIds)

                foreach ($driver in $driversNeedingApproval) {
                    if ($succeeded -contains $driver.id) {
                        Write-Output "    [OK] Approved: $($driver.name) (v$($driver.version)) - $($driver.manufacturer)"
                        Write-RjRbLog -Message "Approved driver: $($driver.name) (ID: $($driver.id))" -Verbose
                        $policyDetails.DriversApproved++
                        $policyDetails.ApprovedDrivers += $driver.name
                        $approvalSummary.TotalDriversApproved++
                        $driverReportRows.Add([PSCustomObject]@{
                            Policy       = $policy.displayName
                            DriverName   = $driver.name
                            Version      = $driver.version
                            Manufacturer = $driver.manufacturer
                            DriverClass  = $driver.driverClass
                            ReleaseDate  = $driver.releaseDateTime
                            Action       = "Approved"
                        })
                    }
                    elseif ($failed -contains $driver.id) {
                        Write-Warning "    [FAIL] Failed to approve: $($driver.name) (ID: $($driver.id))"
                        $approvalSummary.FailedApprovals++
                        $driverReportRows.Add([PSCustomObject]@{
                            Policy       = $policy.displayName
                            DriverName   = $driver.name
                            Version      = $driver.version
                            Manufacturer = $driver.manufacturer
                            DriverClass  = $driver.driverClass
                            ReleaseDate  = $driver.releaseDateTime
                            Action       = "Failed"
                        })
                    }
                    elseif ($notFound -contains $driver.id) {
                        Write-Warning "    [NOTFOUND] Driver not found during approval: $($driver.name) (ID: $($driver.id))"
                        $approvalSummary.FailedApprovals++
                        $driverReportRows.Add([PSCustomObject]@{
                            Policy       = $policy.displayName
                            DriverName   = $driver.name
                            Version      = $driver.version
                            Manufacturer = $driver.manufacturer
                            DriverClass  = $driver.driverClass
                            ReleaseDate  = $driver.releaseDateTime
                            Action       = "Not found"
                        })
                    }
                }
            }
            catch {
                Write-Warning "Failed to approve drivers for policy '$($policy.displayName)': $_"
                Write-RjRbLog -Message "Failed to approve drivers for policy '$($policy.displayName)': $_" -Verbose
                $approvalSummary.FailedApprovals += $driversNeedingApproval.Count
                foreach ($driver in $driversNeedingApproval) {
                    $driverReportRows.Add([PSCustomObject]@{
                        Policy       = $policy.displayName
                        DriverName   = $driver.name
                        Version      = $driver.version
                        Manufacturer = $driver.manufacturer
                        DriverClass  = $driver.driverClass
                        ReleaseDate  = $driver.releaseDateTime
                        Action       = "Failed"
                    })
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to process policy '$($policy.displayName)': $_"
        Write-RjRbLog -Message "Failed to process policy '$($policy.displayName)': $_" -Verbose
    }

    $approvalSummary.Details += $policyDetails
}

Write-Output ""
Write-Output "Approval Summary"
Write-Output "---------------------"
if ($WhatIf) {
    Write-Output "Mode: WHAT-IF (Simulation - No actual changes made)"
}
Write-Output "Policies processed: $($approvalSummary.TotalPoliciesProcessed)"
Write-Output "Total drivers reviewed: $($approvalSummary.TotalDriversReviewed)"
if ($WhatIf) {
    Write-Output "Total drivers that would be approved: $($approvalSummary.TotalDriversApproved)"
}
else {
    Write-Output "Total drivers approved: $($approvalSummary.TotalDriversApproved)"
}
if ($approvalSummary.FailedApprovals -gt 0) {
    Write-Output "Failed approvals: $($approvalSummary.FailedApprovals)"
}

#endregion

########################################################
#region     Report File Export (if needed for download link or email)
########################################################

$reportFiles = @()
$xlsxPath = $null
$tempDir = $null
$fileName_Details = "driver-approvals.csv"
$fileName_DetailsXlsx = "driver-approvals.xlsx"

if (($EmailTo -or $CreateDownloadLink) -and $driverReportRows.Count -gt 0) {
    $tempDir = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "DriverApprovals_$(Get-Date -Format 'yyyyMMdd_HHmmss')"))

    if ($ReportFileFormat -ne 'XLSX only') {
        $csvPath = Join-Path $tempDir.FullName $fileName_Details
        $driverReportRows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvPath
        Write-Output "Exported driver approval report to: $csvPath"
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxPath = Join-Path $tempDir.FullName $fileName_DetailsXlsx
        $driverReportRows | Export-RjRbXlsx -Path $xlsxPath -WorksheetName "Driver Approvals"
        $reportFiles += $xlsxPath
        Write-Output "Exported driver approval report to: $xlsxPath"
    }
}

#endregion

########################################################
#region     Upload / Download Link (if CreateDownloadLink is enabled)
########################################################

if ($CreateDownloadLink) {
    Write-Output ""
    if ($reportFiles.Count -gt 0) {
        Write-Output "Uploading report to storage account..."

        # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
        # transparently connects the managed identity if no Az context is active.
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths $reportFiles `
            -ContainerName $ContainerName `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -LinkExpiryDays $LinkExpiryDays `
            -AddBlobNamePrefix $true

        foreach ($uploadResult in $uploadResults) {
            Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }
    else {
        Write-Output "No driver approval actions were recorded - skipping report upload."
    }
}

#endregion

########################################################
#region     Email Notification (if EmailTo is provided)
########################################################

# Send email notification if configured
$brandingMailParams = @{}
if ($EmailTo) {
    Write-Output ""
    Write-Output "Sending Email Notification"
    Write-Output "---------------------"

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        $tenantDisplayName = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization").value[0].displayName

        # Build email content
        if ($WhatIf) {
            $emailSubject = "Intune Driver Update Auto-Approval Report [WHAT-IF] - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"
        }
        else {
            $emailSubject = "Intune Driver Update Auto-Approval Report - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"
        }

        $emailBody = @"
# Driver Update Auto-Approval Report$(if ($WhatIf) { " [WHAT-IF MODE]" })

**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Tenant:** $tenantDisplayName
$(if ($WhatIf) { "**Mode:** WHAT-IF (Simulation - No actual changes were made)" })

## Summary

- **Policies Processed:** $($approvalSummary.TotalPoliciesProcessed)
- **Drivers Reviewed:** $($approvalSummary.TotalDriversReviewed)
- **Drivers $(if ($WhatIf) { "That Would Be " })Approved:**$($approvalSummary.TotalDriversApproved)
$(if ($approvalSummary.FailedApprovals -gt 0) { "- **Failed Approvals:** $($approvalSummary.FailedApprovals)" })

## Policy Details

"@

        foreach ($detail in $approvalSummary.Details) {
            $emailBody += @"

### $($detail.PolicyName)

- **Drivers Reviewed:** $($detail.DriversReviewed)
- **Drivers $(if ($WhatIf) { "That Would Be " })Approved:** $($detail.DriversApproved)

"@
            if ($detail.ApprovedDrivers.Count -gt 0) {
                if ($WhatIf) {
                    $emailBody += "`n**Drivers That Would Be Approved:**`n"
                }
                else {
                    $emailBody += "`n**Approved Drivers:**`n"
                }
                # Cap the per-policy driver list to keep the email readable - the full list is in the attached report
                $maxListedDrivers = 15
                foreach ($driverName in ($detail.ApprovedDrivers | Select-Object -First $maxListedDrivers)) {
                    $emailBody += "- $driverName`n"
                }
                if ($detail.ApprovedDrivers.Count -gt $maxListedDrivers -and $reportFiles.Count -gt 0) {
                    $emailBody += "- ... and $($detail.ApprovedDrivers.Count - $maxListedDrivers) more (see attached report)`n"
                }
            }
        }

        $emailBody += @"

## Filters Applied

$(if ($PolicyNameList.Count -gt 0) { "- **Policy Names:** $($PolicyNameList -join ', ')" })
$(if ($PolicyIdList.Count -gt 0) { "- **Policy IDs:** $($PolicyIdList -join ', ')" })
$(if ($DriverDisplayNamePattern) { "- **Driver Name Pattern:** $DriverDisplayNamePattern" })
$(if ($DriverClass) { "- **Driver Class:** $DriverClass" })
$(if ($DriverManufacturer) { "- **Manufacturer:** $DriverManufacturer" })
$(if ($MaximumDriverAge) { "- **Maximum Driver Age:** $MaximumDriverAge days" })
"@

        if ($reportFiles.Count -gt 0) {
            $emailBody += @"


## Report Files

The following file(s) are attached to this email:

$(if ($ReportFileFormat -ne 'XLSX only') { "- **$($fileName_Details)**: Complete list of all driver approval actions (CSV)" })
$(if ($ReportFileFormat -ne 'CSV only') { "- **$($fileName_DetailsXlsx)**: The same list as a formatted Excel workbook" })
"@
        }

        $emailBody += @"


---

*This email was automatically generated. Please do not reply to this email.*
"@

        # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
        if ($reportFiles.Count -gt 0) {
            $markdownFallback = @"
# Driver Update Auto-Approval Report$(if ($WhatIf) { " [WHAT-IF MODE]" })

**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Tenant:** $tenantDisplayName
$(if ($WhatIf) { "**Mode:** WHAT-IF (Simulation - No actual changes were made)" })

## Summary

- **Policies Processed:** $($approvalSummary.TotalPoliciesProcessed)
- **Drivers Reviewed:** $($approvalSummary.TotalDriversReviewed)
- **Drivers $(if ($WhatIf) { "That Would Be " })Approved:** $($approvalSummary.TotalDriversApproved)
$(if ($approvalSummary.FailedApprovals -gt 0) { "- **Failed Approvals:** $($approvalSummary.FailedApprovals)" })

## Report Files

- **$($fileName_DetailsXlsx)**: Formatted Excel workbook with the complete list of driver approval actions

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

            $guardParams = @{
                EmailFrom         = $EmailFrom
                EmailTo           = $EmailTo
                Subject           = $emailSubject
                MarkdownContent   = $emailBody
                TenantDisplayName = $tenantDisplayName
                ReportVersion     = $Version
            }
            if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxPath) {
                Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
            }
        }
        else {
            Send-RjReportEmail `
                -EmailFrom $EmailFrom `
                -EmailTo $EmailTo `
                -Subject $emailSubject `
                -MarkdownContent $emailBody `
                -TenantDisplayName $tenantDisplayName `
                -ReportVersion $Version `
                @brandingMailParams

            Write-Output "Email notification sent to: $EmailTo"
        }
        Write-RjRbLog -Message "Email notification sent successfully to: $EmailTo" -Verbose
    }
    catch {
        Write-Warning "Failed to send email notification: $_"
        Write-RjRbLog -Message "Failed to send email notification: $_" -Verbose
    }
}

#endregion

########################################################
#region     Cleanup
########################################################

# Cleanup temporary report files
if ($tempDir -and (Test-Path $tempDir.FullName)) {
    Remove-Item -Path $tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Write-RjRbLog -Message "Cleaned up temporary report files" -Verbose
}

# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

Write-RjRbLog -Message "Disconnecting from Microsoft Graph..." -Verbose
Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
Write-RjRbLog -Message "Successfully disconnected from Microsoft Graph" -Verbose

Write-Output ""
Write-Output "Done!"

#endregion
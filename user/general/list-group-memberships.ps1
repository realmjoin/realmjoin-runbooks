<#
	.SYNOPSIS
	List the group memberships of this user

	.DESCRIPTION
	Lists the groups this user is a member of, with filters for group type, membership type, role assignability, Teams, source and writeback. The result is shown as CSV text and as Output Data tables. The report can also be sent by email or provided as a download link. Nothing is changed.

	.PARAMETER UserName
	User principal name of the user the runbook acts on. Set by the portal from the selected user.

	.PARAMETER GroupType
	Security groups only, Microsoft 365 groups only, or all groups.

	.PARAMETER MembershipType
	Assigned memberships, dynamic memberships, or all.

	.PARAMETER RoleAssignable
	Yes limits the list to groups that can be assigned Entra ID roles.

	.PARAMETER TeamsEnabled
	Yes limits the list to groups that back a Microsoft Teams team.

	.PARAMETER Source
	Cloud-only groups, groups synchronized from on-premises Active Directory, or all.

	.PARAMETER WritebackEnabled
	Groups with writeback to on-premises Active Directory, groups without, or all.

	.PARAMETER SendMail
	Send the report to the recipient email address. Set from the "Report delivery" choice in the portal.

	.PARAMETER ReportFileFormat
	Deliver the report as CSV, as an Excel workbook, or both. Shown when "Report delivery" includes an email or a download link.

	.PARAMETER EmailTo
	Send the report to these addresses. Separate several with commas; each recipient gets a separate email. Required when "Report delivery" includes an email.

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

	.PARAMETER CreateDownloadLink
	Also upload the report and return a download link that expires after a few days. Set from the "Report delivery" choice in the portal.

	.PARAMETER ContainerName
	Storage container the report files are uploaded to. Set per runbook.

	.PARAMETER ResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup.

	.PARAMETER StorageAccountName
	Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName.

	.PARAMETER SubscriptionId
	Subscription ID of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.SubscriptionId; the subscription the managed identity signs in to is used when empty.

	.PARAMETER LinkExpiryDays
	Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"UserName": {
				"Hide": true
			},
			"SendMail": {
				"Hide": true
			},
			"CreateDownloadLink": {
				"Hide": true
			},
			"ReportFileFormat": {
				"DisplayName": "Report file format",
				"Hide": true,
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
			"EmailTo": {
				"DisplayName": "Recipient email address(es)",
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
			"SubscriptionId": {
				"Hide": true
			},
			"LinkExpiryDays": {
				"Hide": true
			},
			"CallerName": {
				"Hide": true
			}
		},
		"ParameterList": [
			{
				"DisplayName": "Report delivery",
				"DisplayAfter": "WritebackEnabled",
				"Select": {
					"Options": [
						{
							"Display": "Output Data only",
							"ParameterValue": "Output Data only",
							"Customization": {
								"Default": { "SendMail": false, "CreateDownloadLink": false },
								"Hide": [ "EmailTo", "ReportFileFormat" ]
							}
						},
						{
							"Display": "Also email the report",
							"ParameterValue": "Also email the report",
							"Customization": {
								"Default": { "SendMail": true, "CreateDownloadLink": false },
								"Show": [ "EmailTo", "ReportFileFormat" ],
								"Mandatory": [ "EmailTo" ]
							}
						},
						{
							"Display": "Also create a download link",
							"ParameterValue": "Also create a download link",
							"Customization": {
								"Default": { "SendMail": false, "CreateDownloadLink": true },
								"Show": [ "ReportFileFormat" ],
								"Hide": [ "EmailTo" ]
							}
						},
						{
							"Display": "Also email & download link",
							"ParameterValue": "Also email & download link",
							"Customization": {
								"Default": { "SendMail": true, "CreateDownloadLink": true },
								"Show": [ "EmailTo", "ReportFileFormat" ],
								"Mandatory": [ "EmailTo" ]
							}
						}
					]
				},
				"Default": "Output Data only"
			}
		]
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [ValidateSet("Security", "M365", "All")]
    [string] $GroupType = "All",
    [ValidateSet("Assigned", "Dynamic", "All")]
    [string] $MembershipType = "All",
    [ValidateSet("Yes", "NotSet")]
    [string] $RoleAssignable = "NotSet",
    [ValidateSet("Yes", "NotSet")]
    [string] $TeamsEnabled = "NotSet",
    [ValidateSet("Cloud", "OnPrem", "All")]
    [string] $Source = "All",
    [ValidateSet("Yes", "No", "All")]
    [string] $WritebackEnabled = "All",

    [bool] $SendMail = $false,

    [Parameter(Mandatory = $false)]
    [string] $EmailTo,

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

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'CSV & XLSX',

    [bool] $CreateDownloadLink = $false,

    [string] $ContainerName = "user-group-memberships",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.SubscriptionId" } )]
    [string] $SubscriptionId,
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

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.8.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "GroupType: $GroupType" -Verbose
Write-RjRbLog -Message "MembershipType: $MembershipType" -Verbose
Write-RjRbLog -Message "RoleAssignable: $RoleAssignable" -Verbose
Write-RjRbLog -Message "TeamsEnabled: $TeamsEnabled" -Verbose
Write-RjRbLog -Message "Source: $Source" -Verbose
Write-RjRbLog -Message "WritebackEnabled: $WritebackEnabled" -Verbose
Write-RjRbLog -Message "SendMail: $SendMail" -Verbose
if ($SendMail) {
    Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
    Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
    Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
    Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
    Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
    Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
}
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "SubscriptionId: $SubscriptionId" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

# A recipient and a configured sender are required to send an email report
if ($SendMail) {
    if (-not $EmailTo) {
        throw "A recipient email address (EmailTo) is required when 'Send the report via email' is enabled."
    }
    if (-not $EmailFrom) {
        Write-Warning -Message "The sender email address is required to send an email report. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -Verbose
        throw "The sender email address (EmailFrom) needs to be configured in the runbook customization."
    }
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
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

function Invoke-ReportCleanup {
    <#
        .SYNOPSIS
        Removes the local report files and the downloaded branding images and closes the sessions.

        .DESCRIPTION
        Runs in the Cleanup region and, before the error is rethrown, when the report export, the upload or the
        email fails, so a failed run leaves no files in the working directory (e.g. on a Hybrid Runbook Worker).
    #>

    # Remove the local report files, including one that a failed export left behind
    foreach ($reportFilePath in @($csvFilePath, $xlsxFilePath)) {
        if ($reportFilePath -and (Test-Path -LiteralPath $reportFilePath)) {
            try {
                Remove-Item -LiteralPath $reportFilePath -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not remove temporary report file '$reportFilePath': $_"
            }
        }
    }

    # Remove the downloaded branding images, if any were used.
    foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
        if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
            Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
        }
    }

    if ($CreateDownloadLink) {
        Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
    }

    if (Get-MgContext -ErrorAction SilentlyContinue) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
}

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

try {
    Write-Output "Connecting to Microsoft Graph (RealmJoin)..."
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph (RealmJoin): $($_.Exception.Message)" -ErrorAction Continue
    throw
}

# Tenant display name for the header of the report email
$tenantDisplayName = "Unknown Tenant"
if ($SendMail) {
    try {
        $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
        if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0 -and $organizationResponse.value[0].displayName) {
            $tenantDisplayName = $organizationResponse.value[0].displayName
        }
    }
    catch {
        Write-RjRbLog -Message "Failed to retrieve tenant display name: $($_.Exception.Message)" -Verbose
    }
}

if ($CreateDownloadLink) {
    try {
        Write-Output "Connecting to Azure (RealmJoin)..."
        Connect-RjRbAzAccount
    }
    catch {
        Write-Error "Failed to connect to Azure (RealmJoin): $_"
        throw $_
    }
}

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

try {
    $User = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($UserName))" -Method GET -ErrorAction Stop
}
catch {
    Write-Error "Failed to retrieve the user '$($UserName)': $($_.Exception.Message)" -ErrorAction Continue
    throw
}

# Get all group memberships with all needed fields
$memberGroupsSelect = "id,displayName,mailEnabled,securityEnabled,groupTypes,membershipRule,isAssignableToRole,resourceProvisioningOptions,onPremisesSyncEnabled,writebackConfiguration"
$MemberGroups = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users/$($User.id)/memberOf/microsoft.graph.group?`$select=$memberGroupsSelect"
$memberGroupCount = if ($MemberGroups) { @($MemberGroups).Count } else { 0 }

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

if ($MemberGroups) {
    $FilteredGroups = $MemberGroups | Where-Object {
        $group = $_

        # Determine if it's a Security or M365 group
        $isSecurityGroup = $group.securityEnabled -and -not $group.mailEnabled
        $isM365Group = $group.mailEnabled -and ($group.groupTypes -contains "Unified")

        # Determine if it's Assigned or Dynamic
        $isDynamic = $null -ne $group.membershipRule -and $group.membershipRule -ne ""
        $isAssigned = -not $isDynamic

        # Apply Group Type filter
        $groupTypeMatch = $false
        switch ($GroupType) {
            "Security" { $groupTypeMatch = $isSecurityGroup }
            "M365" { $groupTypeMatch = $isM365Group }
            "All" { $groupTypeMatch = $true }
        }

        # Apply Membership Type filter
        $membershipTypeMatch = $false
        switch ($MembershipType) {
            "Assigned" { $membershipTypeMatch = $isAssigned }
            "Dynamic" { $membershipTypeMatch = $isDynamic }
            "All" { $membershipTypeMatch = $true }
        }

        # Apply RoleAssignable filter
        $roleAssignableMatch = $true
        if ($RoleAssignable -eq "Yes") {
            $roleAssignableMatch = $group.isAssignableToRole -eq $true
        }

        # Apply TeamsEnabled filter
        $teamsEnabledMatch = $true
        if ($TeamsEnabled -eq "Yes") {
            $teamsEnabledMatch = $group.resourceProvisioningOptions -contains "Team"
        }

        # Apply Source filter
        $sourceMatch = $true
        switch ($Source) {
            "Cloud" { $sourceMatch = -not $group.onPremisesSyncEnabled }
            "OnPrem" { $sourceMatch = $group.onPremisesSyncEnabled -eq $true }
            "All" { $sourceMatch = $true }
        }

        # Apply WritebackEnabled filter
        $writebackMatch = $true
        switch ($WritebackEnabled) {
            "Yes" { $writebackMatch = $group.writebackConfiguration.isEnabled -eq $true }
            "No" { $writebackMatch = -not $group.writebackConfiguration.isEnabled }
            "All" { $writebackMatch = $true }
        }

        return $groupTypeMatch -and $membershipTypeMatch -and $roleAssignableMatch -and $teamsEnabledMatch -and $sourceMatch -and $writebackMatch
    }

    if ($FilteredGroups) {
        # Store filtered groups in a variable to prevent pipeline issues
        $GroupsList = @($FilteredGroups)

        # Build a structured report object per group (used for console output, CSV file, email and Output Data)
        $reportData = foreach ($Group in $GroupsList) {
            # Determine group type for display
            $displayGroupType = ""
            if ($Group.securityEnabled -and -not $Group.mailEnabled) {
                $displayGroupType = "Security"
            } elseif ($Group.mailEnabled -and ($Group.groupTypes -contains "Unified")) {
                $displayGroupType = "M365"
            } elseif ($Group.mailEnabled) {
                $displayGroupType = "Distribution"
            } else {
                $displayGroupType = "Other"
            }

            [PSCustomObject]@{
                DisplayName      = $Group.displayName
                ID               = $Group.id
                Type             = $displayGroupType
                MembershipType   = if ($Group.membershipRule) { "Dynamic" } else { "Assigned" }
                RoleAssignable   = if ($Group.isAssignableToRole) { "Yes" } else { "No" }
                TeamsEnabled     = if ($Group.resourceProvisioningOptions -contains "Team") { "Yes" } else { "No" }
                Source           = if ($Group.onPremisesSyncEnabled) { "OnPrem" } else { "Cloud" }
                WritebackEnabled = if ($Group.writebackConfiguration.isEnabled) { "Yes" } else { "No" }
            }
        }
        $reportData = @($reportData)

        "## Listing group memberships for '$($User.userPrincipalName)' with applied filters:"
        "## Filters Applied: Group Type: $($GroupType); Membership Type: $($MembershipType); Role Assignable: $($RoleAssignable); Teams Enabled: $($TeamsEnabled); Source: $($Source); Writeback: $($WritebackEnabled)"
        "## Found $($reportData.Count) group(s) matching the selected filters."
        ""
        # CSV Header - always include all columns
        "DisplayName,ID,Type,MembershipType,RoleAssignable,TeamsEnabled,Source,WritebackEnabled"

        foreach ($item in $reportData) {
            # Escape quotes in displayName if needed
            $escapedName = $item.DisplayName -replace '"', '""'
            if ($escapedName -match '[,"]') {
                $escapedName = "`"$escapedName`""
            }

            "$escapedName,$($item.ID),$($item.Type),$($item.MembershipType),$($item.RoleAssignable),$($item.TeamsEnabled),$($item.Source),$($item.WritebackEnabled)"
        }

    } else {
        $reportData = @()
        "## No groups found matching the selected filters."
    }
} else {
    $reportData = @()
    "## User is not a member of any groups."
}

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

# The report files are only needed when they will be uploaded and/or attached to an email
$csvFilePath = $null
$xlsxFilePath = $null
$reportFiles = @()
$brandingMailParams = @{}
if (($SendMail -or $CreateDownloadLink) -and $reportData.Count -gt 0) {
    try {
        if ($ReportFileFormat -ne 'XLSX only') {
            $csvFileName = "group-memberships_$($User.userPrincipalName)_$(Get-Date -Format 'yyyyMMdd').csv"
            $csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath $csvFileName
            $reportData | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
            $reportFiles += $csvFilePath
            Write-RjRbLog -Message "Exported $($reportData.Count) groups to CSV: $csvFilePath" -Verbose
        }

        if ($ReportFileFormat -ne 'CSV only') {
            $xlsxFileName = "group-memberships_$($User.userPrincipalName)_$(Get-Date -Format 'yyyyMMdd').xlsx"
            $xlsxFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath $xlsxFileName
            $reportData | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Group Memberships"
            $reportFiles += $xlsxFilePath
            Write-RjRbLog -Message "Exported $($reportData.Count) groups to XLSX: $xlsxFilePath" -Verbose
        }
    }
    catch {
        # Leave no report file behind; the run fails with the original error
        Invoke-ReportCleanup
        throw
    }
}
elseif (($SendMail -or $CreateDownloadLink) -and $reportData.Count -eq 0) {
    Write-Output ""
    Write-Output "## No groups found - skipping report export, upload and email."
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################

if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
    Write-Output ""
    Write-Output "## Uploading report to storage account..."

    # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
    # transparently connects the managed identity if no Az context is active.
    try {
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths $reportFiles `
            -ContainerName $ContainerName `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -SubscriptionId $SubscriptionId `
            -LinkExpiryDays $LinkExpiryDays `
            -AddBlobNamePrefix $true
    }
    catch {
        # Leave no report file behind; the run fails with the original error
        Invoke-ReportCleanup
        throw
    }

    Write-Output "## Report uploaded to storage account."
    foreach ($uploadResult in $uploadResults) {
        Write-Output "## Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
        $uploadResult.SASLink | Out-String | Write-Output
    }
}

#endregion Upload / Download Link

########################################################
#region     Send Email Report
########################################################

if ($SendMail -and $reportFiles.Count -gt 0) {
    Write-Output ""
    Write-Output "## Preparing email report to send to '$($EmailTo)'..."

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    $subject = "Group Memberships - $($User.userPrincipalName) - $(Get-Date -Format 'yyyy-MM-dd')"

    $markdownContent = @"
# Group Memberships Report

**User:** $($User.userPrincipalName)
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Filters Applied
- Group Type: **$($GroupType)**
- Membership Type: **$($MembershipType)**
- Role Assignable: **$($RoleAssignable)**
- Teams Enabled: **$($TeamsEnabled)**
- Source: **$($Source)**
- Writeback: **$($WritebackEnabled)**

## Summary
- Groups matching the selected filters: **$($reportData.Count)**

The report file(s) are attached for your review.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    $markdownFallback = @"
# Group Memberships Report

**User:** $($User.userPrincipalName)
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary
- Groups matching the selected filters: **$($reportData.Count)**

- **$($xlsxFileName)**: Formatted Excel workbook with the complete report

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    try {
        # -UseNativeGraphRequest sends through the Connect-MgGraph session of the Connect Part
        $guardParams = @{
            EmailFrom             = $EmailFrom
            EmailTo               = $EmailTo
            Subject               = $subject
            MarkdownContent       = $markdownContent
            TenantDisplayName     = $tenantDisplayName
            ReportVersion         = $Version
            UseNativeGraphRequest = $true
        }
        if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFilePath) {
            Send-RjRbReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFilePath) -FallbackMarkdownContent $markdownFallback
        }
        else {
            Send-RjRbReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
        }
    }
    catch {
        # Leave no report file or branding image behind; the run fails as before
        Invoke-ReportCleanup
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to send email report: $($_.Exception.Message)"
    }
}

#endregion Send Email Report

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last so the tables are not interleaved with the CSV text and the progress output. Every table has its own
# RjTableTitle marker and its own column set; a marker is only written when rows follow it.
Write-Output ""

$summaryRows = @(
    [PSCustomObject]@{ Metric = "User"; Value = "$($User.userPrincipalName)" }
    [PSCustomObject]@{ Metric = "Group type"; Value = $GroupType }
    [PSCustomObject]@{ Metric = "Membership type"; Value = $MembershipType }
    [PSCustomObject]@{ Metric = "Role assignable"; Value = $RoleAssignable }
    [PSCustomObject]@{ Metric = "Teams enabled"; Value = $TeamsEnabled }
    [PSCustomObject]@{ Metric = "Source"; Value = $Source }
    [PSCustomObject]@{ Metric = "Writeback"; Value = $WritebackEnabled }
    [PSCustomObject]@{ Metric = "Direct group memberships"; Value = "$memberGroupCount" }
    [PSCustomObject]@{ Metric = "Groups matching the filters"; Value = "$($reportData.Count)" }
)
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($reportData.Count -gt 0) {
    # Same rows and columns as the CSV file and the "Group Memberships" worksheet
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Group Memberships" })
    Write-Output $reportData
}
elseif ($memberGroupCount -eq 0) {
    Write-Output "The user is not a member of any groups."
}
else {
    Write-Output "No groups match the selected filters."
}

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################

# Report files, branding images and sessions; a failed export, upload or email runs the same cleanup before rethrowing
Invoke-ReportCleanup

Write-Output ""
Write-Output "Done!"

#endregion Cleanup
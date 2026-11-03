<#
	.SYNOPSIS
	Report Microsoft 365 license usage and availability

	.DESCRIPTION
	Creates a report of the Microsoft 365 licenses in the tenant, how many are in use and how many are free. Exchange Online details such as shared mailbox licensing can be added. The report files can be uploaded to an Azure Storage account, as single files or as one ZIP, with download links. Nothing is changed unless real user data is requested, which briefly switches off the report privacy setting and restores it afterwards.

	.PARAMETER printOverview
	Prints a table per license SKU with total, used, available and suspended counts in the run output.

	.PARAMETER includeExchange
	Adds Exchange Online reports such as shared mailbox licensing.

	.PARAMETER includeUserData
	Shows real user names in the activity reports by switching off the report privacy setting for the run; it is restored afterwards. The reports then contain personal data, so check your data protection rules first.

	.PARAMETER exportToFile
	Uploads the report files to the Azure Storage account configured in the tenant settings.

	.PARAMETER exportAsZip
	Uploads one ZIP file instead of the single report files.

	.PARAMETER produceLinks
	Returns time-limited download links for the uploaded files.

	.PARAMETER ContainerName
	Storage container the report files are uploaded to. Taken from the tenant setting OfficeLicensingReport.Container.

	.PARAMETER ResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting OfficeLicensingReport.ResourceGroup; when it is not set, RJReport.StorageAccount.ResourceGroup is used.

	.PARAMETER StorageAccountName
	Storage account for report uploads. Taken from the tenant setting OfficeLicensingReport.StorageAccount.Name; when it is not set, RJReport.StorageAccount.StorageAccountName is used.

	.PARAMETER SubscriptionId
	Subscription ID of the storage account for report uploads. Taken from the tenant setting OfficeLicensingReport.SubscriptionId and only used with OfficeLicensingReport.*; empty means the subscription the managed identity signs in to.

	.PARAMETER RJReportResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when OfficeLicensingReport.ResourceGroup is not set.

	.PARAMETER RJReportStorageAccountName
	Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when OfficeLicensingReport.StorageAccount.Name is not set.

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
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

# Suppress false positive from PSScriptAnalyzer - printOverview is used in conditions and passed to Get-LicenseOverviewReport
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "printOverview")]
param(
    [ValidateScript( { Use-RJInterface -DisplayName "Show a usage overview?" -Type Setting -Attribute "OfficeLicensingReport.PrintLicOverview" } )]
    [bool] $printOverview = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Include Exchange Online reports?" -Type Setting -Attribute "OfficeLicensingReport.InlcudeEXOReport" } )]
    [bool] $includeExchange = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Include real user data?" -Type Setting -Attribute "OfficeLicensingReport.IncludeUserData" } )]
    [bool] $includeUserData = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Export to storage?" -Type Setting -Attribute "OfficeLicensingReport.ExportToFile" } )]
    [bool] $exportToFile = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Export as one ZIP file?" -Type Setting -Attribute "OfficeLicensingReport.ExportToZIPFile" } )]
    [bool] $exportAsZip = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Create download links?" -Type Setting -Attribute "OfficeLicensingReport.CreateLinks" } )]
    [bool] $produceLinks = $true,
    # Legacy report settings: OfficeLicensingReport.Container / .ResourceGroup / .StorageAccount.Name / .SubscriptionId - rebind to
    # RJReport.StorageAccount.* (ContainerName: unbind) when it is switched off
    # Make a persistent container the default, so you can simply update PowerBI's report from the same source
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReport.Container" } )]
    [string] $ContainerName = "rjrb-licensing-report-v2",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReport.SubscriptionId" } )]
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

############################################################
#region     RJ Log Part
############################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.2.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "printOverview: $printOverview" -Verbose
Write-RjRbLog -Message "includeExchange: $includeExchange" -Verbose
Write-RjRbLog -Message "includeUserData: $includeUserData" -Verbose
Write-RjRbLog -Message "exportToFile: $exportToFile" -Verbose
Write-RjRbLog -Message "exportAsZip: $exportAsZip" -Verbose
Write-RjRbLog -Message "produceLinks: $produceLinks" -Verbose
Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
Write-RjRbLog -Message "SubscriptionId: $SubscriptionId" -Verbose
Write-RjRbLog -Message "RJReportResourceGroupName: $RJReportResourceGroupName" -Verbose
Write-RjRbLog -Message "RJReportStorageAccountName: $RJReportStorageAccountName" -Verbose
Write-RjRbLog -Message "RJReportSubscriptionId: $RJReportSubscriptionId" -Verbose
Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose

#endregion RJ Log Part

############################################################
#region     Parameter Validation
############################################################

# Legacy report settings: OfficeLicensingReport.* stays bound to the original parameters, so explicit values, existing schedules
# and API calls behave as before and the legacy settings win. RJReport.StorageAccount.* fills in when they are not set.
if (-not ($ResourceGroupName -and $StorageAccountName) -and $RJReportResourceGroupName -and $RJReportStorageAccountName) {
    Write-RjRbLog -Message "Using RJReport.StorageAccount.* - OfficeLicensingReport.* is not configured" -Verbose
    $ResourceGroupName = $RJReportResourceGroupName
    $StorageAccountName = $RJReportStorageAccountName
    # OfficeLicensingReport.SubscriptionId belongs to the runbook-specific storage account
    if ($SubscriptionId) {
        Write-RjRbLog -Message "Ignoring OfficeLicensingReport.SubscriptionId - it only applies to the OfficeLicensingReport storage account" -Verbose
    }
    $SubscriptionId = $RJReportSubscriptionId
}

if ($exportToFile -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    "## To export to a CSV, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    ""
    "## Please configure the following attributes in the RJ central datastore (see https://docs.realmjoin.com/automation/runbooks/runbook-report-settings):"
    "## - RJReport.StorageAccount.ResourceGroup"
    "## - RJReport.StorageAccount.StorageAccountName"
    "## The runbook-specific OfficeLicensingReport.ResourceGroup and OfficeLicensingReport.StorageAccount.Name (with OfficeLicensingReport.SubscriptionId) are still read and take precedence."
    ""
    "## Note: The Storage Account must exist before running this report."
    ""
    "## Disabling CSV export..."
    $exportToFile = $false
    ""
}

if ((-not $exportToFile) -and (-not $printOverview)) {
    "## Not exporting/saving a report and not printing overview."
    "## Nothing to do. Exiting."
    exit
}

#endregion Parameter Validation

############################################################
#region     Function Definitions
############################################################

#region Helper Functions
##############################

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

# The Graph errors of the report functions are written as non-terminating errors and the run goes on with the next
# report, as with the earlier RunbookHelper Graph calls: one missing permission or license must not cost the other reports.

# Returns $null when the setting cannot be read
function Get-ReportPrivacySetting {
    try {
        (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/admin/reportSettings" -Method GET -ErrorAction Stop).displayConcealedNames
    }
    catch {
        Write-Error "Failed to read the report privacy setting: $($_.Exception.Message)" -ErrorAction Continue
    }
}

# Returns $true when the setting was changed
function Set-ReportPrivacySetting {
    param([bool]$concealNames)
    try {
        $body = @{ displayConcealedNames = $concealNames } | ConvertTo-Json
        Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/admin/reportSettings" -Method PATCH -Body $body -ContentType "application/json" -ErrorAction Stop | Out-Null
        $true
    }
    catch {
        Write-Error "Failed to set the report privacy setting to concealed names '$concealNames': $($_.Exception.Message)" -ErrorAction Continue
        $false
    }
}

#endregion Helper Functions

#region Report Functions
##############################

function Get-LicenseOverviewReport {
    param(
        [string]$TXTPath,
        [bool]$printOverview
    )

    # List of well known SKUs - please update/add more when needed.
    $SkuNames = @{
        "EXCHANGESTANDARD"           = "Exchange Online Plan1"
        "EXCHANGEENTERPRISE"         = "Exchange Online Plan2"
        "STANDARDPACK"               = "Office365 Enterprise E1"
        "ENTERPRISEPACK"             = "Office365 Enterprise E3"
        "O365_BUSINESS_PREMIUM"      = "Microsoft 365 Business Standard"
        "SPE_E3"                     = "Microsoft 365 E3"
        "CRMPLAN2"                   = "Microsoft Dynamics CRM Online Basic"
        "CRMSTANDARD"                = "Microsoft Dynamics CRM Online Professional"
        "CRMINSTANCE"                = "Microsoft Dynamics CRM Online Instance"
        "POWER_BI_STANDARD"          = "Power BI (free)"
        "POWER_BI_PRO"               = "Power BI Pro"
        "ATP_ENTERPRISE"             = "Exchange Online Advance Thread Protection"
        "MDATP_XPLAT"                = "Microsoft Defender For Endpoint"
        "PROJECTESSENTIALS"          = "Project Online Essentials"
        "PROJECTPREMIUM"             = "Project Online Premium"
        "POWERAPPS_VIRAL"            = "Microsoft Power Apps and Flow"
        "STREAM"                     = "Microsoft Stream"
        "IDENTITY_THREAT_PROTECTION" = "Microsoft 365 E5 Security"
        "MCOEV"                      = "Microsoft 365 Phone System"
        "MCOMEETADV"                 = "Audioconferencing in Microsoft 365"
        "MEETING_ROOM"               = "Teams Meeting Room"
        "FLOW_FREE"                  = "Microsoft Flow (free)"
        "RMSBASIC"                   = "Rights Management Basic"
        "MCOPSTNC"                   = "Communications Credits"
        "PHONESYSTEM_VIRTUALUSER"    = "Microsoft 365 Phone System - Virtual User"
        "SPE_E5"                     = "Microsoft 365 E5"
    }

    # SKUs to ignore
    $ignoreListe = (
        "TEAMS_EXPLORATORY",
        "WINDOWS_STORE"
    )

    # Prepare results
    $results = @()

    class LicReportObject {
        [string] $Name
        [int] $Total
        [int] $Used
        [int] $Available
        [int] $Suspended
    }

    $SKUs | ForEach-Object {
        # Only look at active and relevant licenses
        if (($_.prepaidUnits.enabled -gt 0) -and (-not $ignoreListe.contains($_.skuPartNumber))) {
            $entry = [LicReportObject]::new()

            if ($SkuNames.contains($_.skuPartNumber)) {
                $entry.Name = $SkuNames[$_.skuPartNumber]
            }
            else {
                $entry.Name = $_.skuPartNumber
            }
            $entry.Total = $_.prepaidUnits.enabled
            $entry.Used = $_.consumedUnits
            $entry.Available = $_.prepaidUnits.enabled - $_.consumedUnits
            $entry.Suspended = $_.prepaidUnits.suspended

            $results += $entry
        }
    }

    if ($TXTPath) {
        $results | Sort-Object -Property Name | Export-Csv -LiteralPath "$($TXTPath)\office-licensing.csv" -NoTypeInformation -Delimiter ";"
        $content = Get-Content -Path "$($TXTPath)\office-licensing.csv"
        Set-Content -Path "$($TXTPath)\office-licensing.csv" -Value $content -Encoding utf8
    }

    # The rows are written as an Output Data table at the end of the run
    return @($results | Sort-Object -Property Name)
}

function Get-UnusedLicenseReport {
    param(
        [parameter(Mandatory = $true)][string]$CSVPath
    )
    try {
        $Path = $CSVPath + "\unusedlicense.csv"
        '"skuPartNumber";"ActiveUnits";"ConsumedUnits";"LockedOutUnits"' > $Path
        $SKUs | ForEach-Object {
            $_.skuPartNumber + ";" + $_.prepaidUnits.enabled + ";" + $_.consumedUnits + ";" + $_.prepaidUnits.suspended >> $Path
        }
        $content = Get-Content -Path $Path
        Set-Content -Path $Path -Value $content -Encoding utf8
    }
    catch {
        "## Error fetching unused licenses"
        "$($_.Exception.Message)"
        "## Maybe missing MS Graph permission: Reports.Read.All"
    }
}

function Get-SharedMailboxLicensing {
    param(
        [parameter(Mandatory = $true)][string]$CSVPath
    )
    $CSVPath = $CSVPath + "\SharedMailboxLicensing.csv"
    $mailbox = Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox
    foreach ($mail in $mailbox) {
        $licenseDetails = $null
        try {
            $licenseDetails = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$([System.Uri]::EscapeDataString($mail.UserPrincipalName))/licenseDetails" -Method GET -ErrorAction Stop).value
        }
        catch {
            # As before, a shared mailbox whose license details cannot be read counts as unlicensed
            Write-RjRbLog -Message "Could not read the license details of '$($mail.UserPrincipalName)': $($_.Exception.Message)" -Verbose
        }
        if ($licenseDetails) {
            Get-EXOMailbox -Identity $mail.UserPrincipalName | Export-Csv -LiteralPath $CSVPath -Append -NoTypeInformation -Delimiter ";"
        }
    }
    if (Test-Path -Path $CSVPath) {
        $content = Get-Content -Path $CSVPath
        Set-Content -Path $CSVPath -Value $content -Encoding utf8
    }
}

function Get-GraphReport {
    param(
        [parameter(Mandatory = $true)][string]$CSVPath,
        $graphUris = ("/reports/getOffice365ServicesUserCounts(period='D90')",
            "/reports/getOffice365ActivationsUserDetail",
            "/reports/getOffice365ActivationsUserCounts",
            "/reports/getMailboxUsageDetail(period='D90')",
            "/reports/getSharePointActivityUserDetail(period='D90')",
            "/reports/getEmailActivityUserDetail(period='D90')",
            "/reports/getOneDriveActivityUserDetail(period='D90')",
            "/reports/getTeamsUserActivityUserDetail(period='D90')",
            "/reports/getSkypeForBusinessActivityUserDetail(period='D90')",
            "/reports/getYammerActivityUserDetail(period='D90')",
            "/reports/getOffice365ActiveUserDetail(period='D90')")
    )

    try {
        foreach ($Uri in $graphUris) {
            $reportname = ($uri.Replace("/reports/", "").split('('))[0]
            $Path = $CSVPath + "\" + $reportname + ".csv"
            $Results = $null
            # The report endpoints redirect to a CSV download, which Invoke-MgGraphRequest only returns as a file
            $downloadPath = Join-Path ([System.IO.Path]::GetTempPath()) "$reportname-$([guid]::NewGuid()).csv"
            try {
                Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0$Uri" -Method GET -OutputFilePath $downloadPath -ErrorAction Stop
                if (Test-Path -LiteralPath $downloadPath) {
                    # Decoded as UTF-8 with the byte order mark kept, as the earlier RunbookHelper call returned it, so the
                    # Remove(0, 3) below and the exported files stay as before
                    $Results = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($downloadPath))
                }
            }
            catch {
                Write-Error "Failed to retrieve the report '$reportname': $($_.Exception.Message)" -ErrorAction Continue
                continue
            }
            finally {
                Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
            }

            if ($Results) {
                $Results = $Results.Remove(0, 3)
                $Results = ConvertFrom-Csv -InputObject $Results
                $Results | Export-Csv -Path $Path -NoTypeInformation
            }
        }
    }
    catch {
        "## Error while fetching MS Graph Reports"
        "$($_.Exception.Message)"
    }
}

function Get-LoginLog {
    param(
        [parameter(Mandatory = $true)][string]$CSVPath,
        $Applications = ("Power BI Premium",
            "Microsoft Planner",
            "Office Sway",
            "Microsoft To-Do",
            "Microsoft Stream",
            "Microsoft Forms",
            "Microsoft Cloud App Security",
            "Project Online",
            "Dynamics CRM Online",
            "Azure Advanced Threat Protection",
            "Microsoft Flow"),
        $PastDays = 90
    )

    $today = Get-Date -Format "yyyy-MM-dd"
    $PastPeriod = ("{0:s}" -f (Get-Date).AddDays( - ($PastDays))).Split("T")[0]

    foreach ($app in $Applications) {
        "## ... $app"
        $appFileName = $app.Replace(" ", "")
        # Slow down to avoid http 429 errors
        Start-Sleep -Seconds 5
        $filter = "createdDateTime ge " + $PastPeriod + "T00:00:00Z and createdDateTime le " + $today + "T00:00:00Z and (appId eq '" + $app + "' or startswith(appDisplayName,'" + $app + "'))"
        try {
            $logs = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/auditLogs/signIns?`$filter=$([System.Uri]::EscapeDataString($filter))"
        }
        catch {
            # Get-GraphPagedResult has written the error; go on with the next application as before
            Write-RjRbLog -Message "Sign-in logs of '$app' skipped: $($_.Exception.Message)" -Verbose
            $logs = $null
        }
        $outputFile = $CSVPath + "\" + "Audit-" + $appFileName + ".csv"
        $logs | ConvertTo-Csv -NoTypeInformation -Delimiter ";" | Add-Content -Path $outputFile -Encoding utf8
    }
}

function Get-AssignedPlan {
    [cmdletbinding()]
    param(
        [parameter(Mandatory = $true)][string]$CSVPath
    )
    $reportname = "\assignedPlans"
    $Path = $CSVPath + $reportname + ".csv"
    try {
        $users = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users"
    }
    catch {
        # Get-GraphPagedResult has written the error; the report goes on without users as before
        Write-RjRbLog -Message "Users for the assigned plans skipped: $($_.Exception.Message)" -Verbose
        $users = $null
    }

    $users | ForEach-Object {
        $thisUser = $_
        (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($_.id)/licenseDetails" -Method GET).value | Select-Object -Property @{name = "licenses"; expression = { $_.skuPartNumber } }, @{name = "UserPrincipalName"; expression = { $thisUser.userPrincipalName } }
    } | ConvertTo-Csv -NoTypeInformation -Delimiter ";" | Out-File $Path -Append -Encoding utf8
}

function Get-LicenseAssignmentPath {
    [cmdletbinding()]
    param(
        [parameter(Mandatory = $true)][string]$CSVPath
    )
    $reportname = "\LicenseAssignmentPath"
    $Path = $CSVPath + $reportname + ".csv"
    try {
        $users = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users?`$select=licenseAssignmentStates,userPrincipalName"
    }
    catch {
        # Get-GraphPagedResult has written the error; the report goes on without users as before
        Write-RjRbLog -Message "Users for the license assignment paths skipped: $($_.Exception.Message)" -Verbose
        $users = $null
    }

    foreach ($user in $users) {
        foreach ($sku in $user.licenseAssignmentStates) {
            $skuPartNumber = $SkuHashtable[$sku.skuId]

            $UserHasLicenseAssignedDirectly = $null -eq $sku.assignedByGroup
            $UserHasLicenseAssignedFromGroup = -not $UserHasLicenseAssignedDirectly

            $obj = $user
            $obj | Add-Member -MemberType NoteProperty -Name "SKU" -Value $skuPartNumber -Force
            $obj | Add-Member -MemberType NoteProperty -Name "AssignedDirectly" -Value $UserHasLicenseAssignedDirectly -Force
            $obj | Add-Member -MemberType NoteProperty -Name "AssignedFromGroup" -Value $UserHasLicenseAssignedFromGroup -Force
            $obj | Select-Object -Property ObjectId, UserPrincipalName, AssignedDirectly, AssignedFromGroup, SKU | Export-Csv -Path $path -Append -NoTypeInformation -Delimiter ";"
        }
    }
    $content = Get-Content $Path
    Set-Content -Path $Path -Value $content -Encoding utf8
}

function Get-LicensingGroup {
    [cmdletbinding()]
    param(
        [parameter(Mandatory = $true)][string]$CSVPath
    )
    $reportname = "\LicensingGroups"
    $Path = $CSVPath + $reportname + ".csv"
    try {
        $groups = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups?`$select=assignedLicenses,id,displayName" | Where-Object { $_.assignedLicenses }
    }
    catch {
        # Get-GraphPagedResult has written the error; the report goes on without groups as before
        Write-RjRbLog -Message "Licensing groups skipped: $($_.Exception.Message)" -Verbose
        $groups = $null
    }
    foreach ($group in $groups) {
        $LicenseString = ""
        foreach ($assignedLicense in  $group.assignedLicenses) {
            $LicenseString += $SkuHashtable[$assignedLicense.skuId] + ", "
        }
        $obj = New-Object pscustomobject -Property @{
            GroupLicense = $LicenseString
            GroupName    = $group.displayName
            GroupId      = $group.id
        }
        $obj | Export-Csv $Path -Append -NoTypeInformation -Delimiter ";"
        $content = Get-Content $Path
        Set-Content -Path $Path -Value $content -Encoding utf8
    }
}

function Get-AdminReport {
    [cmdletbinding()]
    param(
        [parameter(Mandatory = $true)][string]$CSVPath
    )
    $reportname = "\AdminReport"
    $Path = $CSVPath + $reportname + ".csv"

    $AllAdminRole = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?`$filter=$([System.Uri]::EscapeDataString('isBuiltIn eq true'))"

    $msolUserResults = [System.Collections.ArrayList]@()
    foreach ($Role in $AllAdminRole) {
        $RoleID = $Role.id
        $Admins = $null
        try {
            $Admins = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=$([System.Uri]::EscapeDataString("roleDefinitionId eq '$RoleId'"))"
        }
        catch {
            Write-RjRbLog -Message "Role assignments of '$($role.displayName)' skipped: $($_.Exception.Message)" -Verbose
        }
        foreach ($AdminCandidate in $Admins) {
            # Principals that are not users (groups, service principals) are skipped
            $user = $null
            try {
                $user = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($AdminCandidate.principalId)" -Method GET -ErrorAction Stop
            }
            catch {
                Write-RjRbLog -Message "Principal '$($AdminCandidate.principalId)' is not a readable user: $($_.Exception.Message)" -Verbose
            }
            if ($user.mail) {
                [string]$licensesString = ""
                $Licenses = $null
                $Licenses = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($user.id)?`$select=licenseAssignmentStates" -Method GET
                $Licenses | ForEach-Object {
                    if ($licensesString) {
                        $licensesString += "+"
                    }
                    $licensesString += $SkuHashtable[$Licenses.licenseAssignmentStates.skuId]
                }
                $msolUserResults += New-Object psobject -Property @{
                    DisplayName = $user.displayName
                    UPN         = $user.userPrincipalName
                    IsLicensed  = ($Licenses.licenseAssignmentStates.count -gt 0)
                    Licenses    = $licensesString
                    Adminrole   = $role.displayName
                }
            }
        }
    }
    $msolUserResults | Select-Object -Property * | Export-Csv -NoTypeInformation -Path $Path -Delimiter ";"
    $content = Get-Content $Path
    Set-Content -Path $Path -Value $content -Encoding utf8
}

#endregion Report Functions

#endregion Function Definitions

############################################################
#region     Connect Part
############################################################

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity is configured correctly. Error: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

# Exchange Online is only connected when actually needed for the Shared Mailbox report.
if ($includeExchange) {
    Write-Output "Connecting to Exchange Online..."
    Connect-RjRbExchangeOnline
}

#endregion Connect Part

############################################################
#region     Data Collection
############################################################

# Invoke-MgGraphRequest returns PSCustomObjects in the property order of the Graph response, as the earlier RunbookHelper
# calls did, so the exported CSV files keep their columns. Set without try/finally on purpose: an enclosing try would turn
# a failing statement into an abort of all remaining reports. The entry is removed at the end of this region.
$PSDefaultParameterValues['Invoke-MgGraphRequest:OutputType'] = 'PSObject'

# Get SKUs and build a lookup table for SKU IDs
$SkuHashtable = @{}
try {
    $SKUs = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/subscribedSkus"
}
catch {
    # Get-GraphPagedResult has written the error; the reports go on without SKUs as before
    Write-RjRbLog -Message "Subscribed SKUs skipped: $($_.Exception.Message)" -Verbose
    $SKUs = $null
}
$SKUs | ForEach-Object {
    $SkuHashtable.Add($_.skuId, $_.skuPartNumber)
}

$OutPutPath = "CloudEconomics\"

if (-not (Test-Path -Path $OutPutPath)) {
    New-Item -ItemType directory -Path $OutPutPath | Out-Null
}
else {
    "## Deleting old reports"
    Get-ChildItem -Path $OutPutPath -Filter *.csv | Remove-Item | Out-Null
    Get-ChildItem -Path $OutPutPath -Filter *.txt | Remove-Item | Out-Null
}

"## Collecting: License Usage Overview"
$licenseOverview = @(Get-LicenseOverviewReport -TXTPath $OutPutPath -printOverview $printOverview)

if ($exportToFile) {

    if ($includeExchange) {
        "## Collecting: Shared Mailbox licensing"
        Get-SharedMailboxLicensing -CSVPath $OutPutPath
    }

    "## Collecting: MS Graph Reports"
    $settingWasChanged = $false
    try {
        if ($includeUserData) {
            $currentConcealSetting = Get-ReportPrivacySetting
            if ($null -eq $currentConcealSetting) {
                # Without the current value the setting is left alone, so it cannot be restored to a value it never had
                $privacyMessage = "The report privacy setting could not be read and is left unchanged - the activity reports may show concealed user names."
                Write-RjRbLog -Message "WARNING: $privacyMessage"
                Write-Warning $privacyMessage
            }
            elseif ($currentConcealSetting -eq $false) {
                "## Report privacy setting is already disabled - no changes needed."
            }
            elseif (Set-ReportPrivacySetting -concealNames $false) {
                "## Temporarily disabling report privacy setting to include user data..."
                $settingWasChanged = $true
            }
            else {
                $privacyMessage = "The report privacy setting could not be disabled - the activity reports show concealed user names."
                Write-RjRbLog -Message "WARNING: $privacyMessage"
                Write-Warning $privacyMessage
            }
        }
        Get-GraphReport -CSVPath $OutPutPath
    }
    finally {
        if ($settingWasChanged) {
            "## Restoring report privacy setting..."
            if (-not (Set-ReportPrivacySetting -concealNames $true)) {
                $privacyMessage = "The report privacy setting could not be restored - the reports of the tenant show real user names until it is switched on again in the Microsoft 365 admin center."
                Write-RjRbLog -Message "WARNING: $privacyMessage"
                Write-Warning $privacyMessage
            }
        }
    }

    "## Collecting: Login Logs"
    Get-LoginLog -CSVPath $OutPutPath

    "## Collecting: All user objects"
    try {
        Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users?`$select=UserType,UserPrincipalName,AccountEnabled,city,companyName,country,creationType,department,displayName,givenName,surname,jobTitle,mail" | Export-Csv -Path $OutPutPath"\AllUser.csv" -NoTypeInformation -Delimiter ";"
    }
    catch {
        # Get-GraphPagedResult has written the error; go on with the next report as before
        Write-RjRbLog -Message "All user objects skipped: $($_.Exception.Message)" -Verbose
    }
    $content = Get-Content $OutPutPath"\AllUser.csv"
    Set-Content -Path $OutPutPath"\AllUser.csv" -Value $content -Encoding utf8

    "## Collecting: Assigned License Plans"
    Get-AssignedPlan -CSVPath $OutPutPath

    "## Collecting: Licensing Groups"
    Get-LicensingGroup -CSVPath $OutPutPath

    "## Collecting: Directly vs. Group assigned Licenses"
    Get-LicenseAssignmentPath -CSVPath $OutPutPath

    #"## Collecting: Licensed Admin Accounts"
    #Get-AdminReport -CSVPath $OutPutPath
}

$PSDefaultParameterValues.Remove('Invoke-MgGraphRequest:OutputType')

#endregion Data Collection

############################################################
#region     Report File Export
############################################################

$reportFiles = @()
if ($exportToFile) {
    if ($exportAsZip) {
        $zipFileName = "office-licensing-v2-" + (Get-Date -Format "yyyy-MM-dd") + ".zip"
        Compress-Archive -Path $OutPutPath -DestinationPath $zipFileName | Out-Null
        $reportFiles = @($zipFileName)
    }
    else {
        $reportFiles = (Get-ChildItem -Path $OutPutPath -File).FullName
    }
}

#endregion Report File Export

############################################################
#region     Upload / Download Link
############################################################

if ($exportToFile) {
    ""
    if (-not $ContainerName) {
        $ContainerName = "office-licensing-v2-" + (Get-Date -Format "yyyy-MM-dd")
    }

    "## Upload"
    $uploadResults = Publish-RjRbFilesToStorageContainer `
        -FilePaths $reportFiles `
        -ContainerName $ContainerName `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -SubscriptionId $SubscriptionId `
        -LinkExpiryDays $LinkExpiryDays `
        -AddBlobNamePrefix $false

    foreach ($r in $uploadResults) {
        if ($produceLinks) {
            "## $($r.BlobName)"
            " $($r.SASLink)"
            ""
        }
    }
    "## Upload successful ($($uploadResults.Count) file(s))."
    if ($produceLinks -and $uploadResults) {
        ""
        "## Expiry of Links: $($uploadResults[0].EndTime)"
    }
}

#endregion Upload / Download Link

############################################################
#region     Structured Output (Output Data)
############################################################

# Emitted last so the tables are not interleaved with the progress output. A marker is only written when rows follow it.
""
$summaryRows = [System.Collections.Generic.List[object]]::new()
$summaryRows.Add([PSCustomObject]@{ Metric = "License SKUs"; Value = "$($licenseOverview.Count)" })
$summaryRows.Add([PSCustomObject]@{ Metric = "SKUs with available licenses"; Value = "$(@($licenseOverview | Where-Object { $_.Available -gt 0 }).Count)" })
$summaryRows.Add([PSCustomObject]@{ Metric = "SKUs with suspended licenses"; Value = "$(@($licenseOverview | Where-Object { $_.Suspended -gt 0 }).Count)" })
$summaryRows.Add([PSCustomObject]@{ Metric = "Report files uploaded"; Value = "$(if ($exportToFile) { @($uploadResults).Count } else { 0 })" })
Write-Output ([PSCustomObject]@{ RjTableTitle = 'Summary' })
Write-Output $summaryRows

if ($printOverview) {
    if ($licenseOverview.Count -gt 0) {
        "## Totals of licenses we have:"
        Write-Output ([PSCustomObject]@{ RjTableTitle = 'License overview' })
        Write-Output ($licenseOverview | Select-Object -Property Name, Total, Used, Available, Suspended)
    }
    else {
        "## No active license SKUs found."
    }
}

#endregion Structured Output (Output Data)

############################################################
#region     Cleanup
############################################################

foreach ($reportFile in $reportFiles) {
    Remove-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
}

if ($includeExchange) {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}
if (Get-AzContext -ErrorAction SilentlyContinue) {
    Disconnect-AzAccount -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

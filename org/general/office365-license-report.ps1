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
    Resource group of the storage account. Taken from the tenant setting OfficeLicensingReport.ResourceGroup.

    .PARAMETER StorageAccountName
    Storage account for the export. Taken from the tenant setting OfficeLicensingReport.StorageAccount.Name.

    .PARAMETER SubscriptionId
    Azure subscription that holds the storage account. Taken from the tenant setting OfficeLicensingReport.SubscriptionId.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"ParameterList": [
			{
				"Name": "ContainerName",
				"Hide": true
			},
			{
				"Name": "ResourceGroupName",
				"Hide": true
			},
			{
				"Name": "StorageAccountName",
				"Hide": true
			},
			{
				"Name": "SubscriptionId",
				"Hide": true
			},
			{
				"Name": "CallerName",
				"Hide": true
			}
		]
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

# Suppress false positive from PSScriptAnalyzer - printOverview is used in conditions and passed to Get-LicenseOverviewReport
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "printOverview")]
param(
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Show a usage overview?" -Type Setting -Attribute "OfficeLicensingReport.PrintLicOverview" } )]
    [bool] $printOverview = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Include Exchange Online reports?" -Type Setting -Attribute "OfficeLicensingReport.InlcudeEXOReport" } )]
    [bool] $includeExchange = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Include real user data?" -Type Setting -Attribute "OfficeLicensingReport.IncludeUserData" } )]
    [bool] $includeUserData = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Export to storage?" -Type Setting -Attribute "OfficeLicensingReport.ExportToFile" } )]
    [bool] $exportToFile = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Export as one ZIP file?" -Type Setting -Attribute "OfficeLicensingReport.ExportToZIPFile" } )]
    [bool] $exportAsZip = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Create download links?" -Type Setting -Attribute "OfficeLicensingReport.CreateLinks" } )]
    [bool] $produceLinks = $true,
    # Make a persistent container the default, so you can simply update PowerBI's report from the same source
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OfficeLicensingReport.Container" } )]
    [string] $ContainerName = "rjrb-licensing-report-v2",
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OfficeLicensingReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OfficeLicensingReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "OfficeLicensingReport.SubscriptionId" } )]
    [string] $SubscriptionId,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

############################################################
#region     RJ Log Part
#
############################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.1.3"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "printOverview: $printOverview" -Verbose
Write-RjRbLog -Message "includeExchange: $includeExchange" -Verbose
Write-RjRbLog -Message "includeUserData: $includeUserData" -Verbose
Write-RjRbLog -Message "exportToFile: $exportToFile" -Verbose
Write-RjRbLog -Message "exportAsZip: $exportAsZip" -Verbose
Write-RjRbLog -Message "produceLinks: $produceLinks" -Verbose

#endregion RJ Log Part

############################################################
#region     Parameter Validation
#
############################################################

if ($exportToFile -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    "## To export to a CSV, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    ""
    "## Please configure the following attributes in the RJ central datastore:"
    "## - OfficeLicensingReport.ResourceGroup"
    "## - OfficeLicensingReport.SubscriptionId"
    "## - OfficeLicensingReport.StorageAccount.Name"
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
#
############################################################

#region Helper Functions
##############################

function Get-ReportPrivacySetting {
    (Invoke-RjRbRestMethodGraph -Resource "/admin/reportSettings" -Beta).displayConcealedNames
}

function Set-ReportPrivacySetting {
    param([bool]$concealNames)
    Invoke-RjRbRestMethodGraph -Resource "/admin/reportSettings" -Beta -Method Patch -Body @{ displayConcealedNames = $concealNames } | Out-Null
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

    "## Totals of licenses we have:"
    ""
    $results | Sort-Object -Property Name | Format-Table | Out-String
    ""
    if ($TXTPath) {
        $results | Sort-Object -Property Name | Export-Csv -LiteralPath "$($TXTPath)\office-licensing.csv" -NoTypeInformation -Delimiter ";"
        $content = Get-Content -Path "$($TXTPath)\office-licensing.csv"
        Set-Content -Path "$($TXTPath)\office-licensing.csv" -Value $content -Encoding utf8
    }
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
        if (Invoke-RjRbRestMethodGraph -Resource "/users/$($mail.UserPrincipalName)/licenseDetails" -ErrorAction SilentlyContinue) {
            Get-EXOMailbox $mailbox.UserPrincipalName | Export-Csv -LiteralPath $CSVPath -Append -NoTypeInformation -Delimiter ";"
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
            $Results = Invoke-RjRbRestMethodGraph -Resource $Uri

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
        $logs = Invoke-RjRbRestMethodGraph -Resource "/auditLogs/signIns" -FollowPaging -OdFilter $filter
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
    $users = Invoke-RjRbRestMethodGraph -FollowPaging -Resource "/users"

    $users | ForEach-Object {
        $thisUser = $_
        (Invoke-RjRbRestMethodGraph -Resource "/users/$($_.id)/licenseDetails") | Select-Object -Property @{name = "licenses"; expression = { $_.skuPartNumber } }, @{name = "UserPrincipalName"; expression = { $thisUser.userPrincipalName } }
    } | ConvertTo-Csv -NoTypeInformation -Delimiter ";" | Out-File $Path -Append -Encoding utf8
}

function Get-LicenseAssignmentPath {
    [cmdletbinding()]
    param(
        [parameter(Mandatory = $true)][string]$CSVPath
    )
    $reportname = "\LicenseAssignmentPath"
    $Path = $CSVPath + $reportname + ".csv"
    $users = Invoke-RjRbRestMethodGraph -Resource "/users" -OdSelect "licenseAssignmentStates,userPrincipalName" -FollowPaging

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
    $groups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdSelect "assignedLicenses,id,displayName" -FollowPaging | Where-Object { $_.assignedLicenses }
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

    $AllAdminRole = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleDefinitions" -OdFilter "isBuiltIn eq true"

    $msolUserResults = [System.Collections.ArrayList]@()
    foreach ($Role in $AllAdminRole) {
        $RoleID = $Role.id
        $Admins = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleAssignments" -OdFilter "roleDefinitionId eq '$RoleId'" -ErrorAction SilentlyContinue
        foreach ($AdminCandidate in $Admins) {
            $user = Invoke-RjRbRestMethodGraph -Resource "/users/$($AdminCandidate.principalId)" -ErrorAction SilentlyContinue
            if ($user.mail) {
                [string]$licensesString = ""
                $Licenses = Invoke-RjRbRestMethodGraph -Resource "/users/$($user.id)" -OdSelect "licenseAssignmentStates"
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
#
############################################################

Write-Output "Connecting to Microsoft Graph..."
Connect-RjRbGraph

# Exchange Online is only connected when actually needed for the Shared Mailbox report.
if ($includeExchange) {
    Write-Output "Connecting to Exchange Online..."
    Connect-RjRbExchangeOnline
}

#endregion Connect Part

############################################################
#region     Data Collection
#
############################################################

# Get SKUs and build a lookup table for SKU IDs
$SkuHashtable = @{}
$SKUs = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus"
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
Get-LicenseOverviewReport -TXTPath $OutPutPath -printOverview $printOverview

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
            if ($currentConcealSetting -eq $false) {
                "## Report privacy setting is already disabled - no changes needed."
            }
            else {
                "## Temporarily disabling report privacy setting to include user data..."
                Set-ReportPrivacySetting -concealNames $false
                $settingWasChanged = $true
            }
        }
        Get-GraphReport -CSVPath $OutPutPath
    }
    finally {
        if ($settingWasChanged) {
            "## Restoring report privacy setting..."
            Set-ReportPrivacySetting -concealNames $true
        }
    }

    "## Collecting: Login Logs"
    Get-LoginLog -CSVPath $OutPutPath

    "## Collecting: All user objects"
    Invoke-RjRbRestMethodGraph -Resource "/users" -FollowPaging -OdSelect "UserType,UserPrincipalName,AccountEnabled,city,companyName,country,creationType,department,displayName,givenName,surname,jobTitle,mail" | Export-Csv -Path $OutPutPath"\AllUser.csv" -NoTypeInformation -Delimiter ";"
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

#endregion Data Collection

############################################################
#region     Output/Export
#
############################################################

if ($exportToFile) {
    ""
    if (-not $ContainerName) {
        $ContainerName = "office-licensing-v2-" + (Get-Date -Format "yyyy-MM-dd")
    }

    "## Upload"
    if ($exportAsZip) {
        $zipFileName = "office-licensing-v2-" + (Get-Date -Format "yyyy-MM-dd") + ".zip"
        Compress-Archive -Path $OutPutPath -DestinationPath $zipFileName | Out-Null
        $filesToUpload = @($zipFileName)
    }
    else {
        $filesToUpload = (Get-ChildItem -Path $OutPutPath -File).FullName
    }

    $uploadResults = Publish-RjRbFilesToStorageContainer `
        -FilePaths $filesToUpload `
        -ContainerName $ContainerName `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -SubscriptionId $SubscriptionId `
        -LinkExpiryDays 6 `
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

#endregion Output/Export

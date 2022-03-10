<#
  .SYNOPSIS
  Generate an Office 365 licensing report.

  .DESCRIPTION
  Generate an Office 365 licensing report.

  .EXAMPLE
  Example of Azure Storage Account configuration for RJ central datastore
  {
    "Settings": {
        "OfficeLicensingReport": {
            "ResourceGroup": "rj-test-runbooks-01",
            "StorageAccount": {
                "Name": "rbexports01",
                "Location": "West Europe",
                "Sku": "Standard_LRS"
            }
        }
    }
  }

  .NOTES
  New permission: 
  MSGraph 
  - Reports.Read.All

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
            "Name": "StorageAccountLocation",
            "Hide": true
        },
        {
            "Name": "StorageAccountSku",
            "Hide": true
        },
        {   
            "Name": "CallerName",
            "Hide": true
        }
    ]
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Print a short license usage overview?" -Type Setting -Attribute "OfficeLicensingReport.PrintLicOverview"} )]
    [bool] $printOverview = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Include Exchange Reports?" -Type Setting -Attribute "OfficeLicensingReport.InlcudeEXOReport"} )]
    [bool] $includeExhange = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Export reports to Az Storage Account?" -Type Setting -Attribute "OfficeLicensingReport.ExportToFile" } )]
    [bool] $exportToFile = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Export reports as single ZIP file?" -Type Setting -Attribute "OfficeLicensingReport.ExportToZIPFile" } )]
    [bool] $exportAsZip = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Create SAS Tokens / Links?" -Type Setting -Attribute "OfficeLicensingReport.CreateLinks" } )]
    [bool] $produceLinks = $true,
    # Make a persistent container the default, so you can simply update PowerBI's report from the same source
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReport.Container" } )]
    [string] $ContainerName = "rjrb-licensing-report-v2",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

# Sanity checks
if ($exportToFile -and ((-not $ResourceGroupName) -or (-not $StorageAccountLocation) -or (-not $StorageAccountName) -or (-not $StorageAccountSku))) {
    "## To export to a CSV, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    ""
    "## Please configure the following attributes in the RJ central datastore:"
    "## - OfficeLicensingReport.ResourceGroup"
    "## - OfficeLicensingReport.StorageAccount.Name"
    "## - OfficeLicensingReport.StorageAccount.Location"
    "## - OfficeLicensingReport.StorageAccount.Sku"
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

# Static / internal defaults
$OutPutPath = "CloudEconomics\"

Connect-RjRbExchangeOnline
Connect-RjRbGraph

# "Get SKUs and build a lookuptable for SKU IDs"
$SkuHashtable = @{}
$SKUs = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus" 
$SKUs | ForEach-Object {
    $SkuHashtable.Add($_.skuId, $_.skuPartNumber)
}

function Get-LicenseOverviewReport {
    param(
        [string]$TXTPath,
        [bool]$printOverview
    )

    # "List of well known SKUs - please update/add more when needed."
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

    # "Prepare results"
    $results = @()

    class LicReportObject {
        [string] $Name
        [int] $Total
        [int] $Used
        [int] $Available
        [int] $Suspended
    }

    $SKUs | ForEach-Object {
        #only look at active and relevant licenses
        if (($_.prepaidUnits.enabled -gt 0) -and (-not $ignoreListe.contains($_.skuPartNumber))) {
            $entry = [LicReportObject]::new() 

            if ($SkuNames.contains($_.skuPartNumber)) {
                # "Well known SKU found: $($SkuNames[$_.SkuPartNumber])"
                $entry.Name = $SkuNames[$_.skuPartNumber]
            }
            else {
                # "Fallback if unknown SKU: $($_.SkuPartNumber)"
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
    $results | sort-object -property Name | format-table | out-string
    ""
    if ($TXTPath) {
        $results | sort-object -property Name | format-table > "$($TXTPath)\office-licensing.txt"
    }
}

function Get-UnusedLicenseReport {
    param(
        [parameter(Mandatory = $true)][string]$CSVPath
    )
    try {
        $Path = $CSVPath + "\unusedlicense.csv"
        '"skuPartNumber","ActiveUnits","ConsumedUnits","LockedOutUnits"' > $Path
        $SKUs | ForEach-Object {
            $_.skuPartNumber + "," + $_.prepaidUnits.enabled + "," + $_.consumedUnits + "," + $_.prepaidUnits.suspended >> $Path
        } 
    }
    catch {
        "## Error fetching unused licenses"
        $_.Exception.Message 
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
            Get-EXOMailbox $mailbox.UserPrincipalName | Export-Csv -LiteralPath $CSVPath -Append -NoTypeInformation
        }
    }
}

function Get-GraphReports {
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
            $Results = Invoke-RjRbRestMethodGraph -resource $Uri 
              
            if ($Results) {
                $Results = $Results.Remove(0, 3)        
                $Results = ConvertFrom-Csv -InputObject $Results
                $Results | Export-Csv -Path $Path -NoTypeInformation
            }
        }
    }
    catch {
        Write-Host "## Error while fetching MS Graph Reports"
        Write-Host $_.Exception.Message
    }
}

function Get-LoginLogs {
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
    $PastPeriod = ("{0:s}" -f (get-date).AddDays( - ($PastDays))).Split("T")[0]

    foreach ($app in $Applications) {
        "## ... $app"
        # Slow down to avoid http 429 errors
        Start-Sleep -Seconds 5
        $filter = "createdDateTime ge " + $PastPeriod + "T00:00:00Z and createdDateTime le " + $today + "T00:00:00Z and (appId eq '" + $app + "' or startswith(appDisplayName,'" + $app + "'))"        
        $logs = Invoke-RjRbRestMethodGraph -Resource "/auditLogs/signIns" -FollowPaging -OdFilter $filter 
        $outputFile = $CSVPath + "\" + "Audit-" + $app + ".csv"
        $logs | ConvertTo-Csv -NoTypeInformation | Add-Content -Path $outputFile
    }
}

function Get-AssignedPlans {
    [cmdletbinding()]
    param(
        [parameter(Mandatory = $true)][string]$CSVPath
    )
    $reportname = "\assignedPlans"
    $Path = $CSVPath + $reportname + ".csv"
    #alle lizenzierten Benutzer
    $users = Invoke-RjRbRestMethodGraph -FollowPaging -Resource "/users"  

    $users | ForEach-Object {
        $thisUser = $_
        (Invoke-RjRbRestMethodGraph -Resource "/users/$($_.id)/licenseDetails").servicePlans | Select-Object -Property @{name = "licenses"; expression = { $_.servicePlanName } }, @{name = "UserPrincipalName"; expression = { $thisUser.userPrincipalName } }
    } | ConvertTo-Csv -NoTypeInformation | Out-File $Path -Append
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
            $obj | Add-Member -MemberType NoteProperty -Name "SKU" -value $skuPartNumber -Force 
            $obj | Add-Member -MemberType NoteProperty -Name "AssignedDirectly" -value $UserHasLicenseAssignedDirectly -Force
            $obj | Add-Member -MemberType NoteProperty -Name "AssignedFromGroup" -value $UserHasLicenseAssignedFromGroup -Force
            $obj | Select-Object -Property ObjectId, UserPrincipalName, AssignedDirectly, AssignedFromGroup, SKU | Export-Csv -Path $path -Append -NoTypeInformation
        }
    }
}  
function Get-LicensingGroups {
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
            $LicenseString += $SkuHashtable[$assignedLicense.skuId] + "; "
        }
        $obj = New-Object pscustomobject -Property @{
            GroupLicense = $LicenseString
            GroupName    = $group.displayName
            GroupId      = $group.id
        }
        $obj | Export-Csv $Path -Append -NoTypeInformation
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
    $msolUserResults | Select-Object -Property * | Export-Csv -notypeinformation -Path $Path 
}

# start of main script

if (-Not (Test-Path -Path $OutPutPath)) {
    New-Item -ItemType directory -Path $OutPutPath | Out-Null
}
else {
    "## Deleting old reports"
    Get-ChildItem -Path $OutPutPath -Filter *.csv  | Remove-Item | Out-Null
    Get-ChildItem -Path $OutPutPath -Filter *.txt  | Remove-Item | Out-Null
}

if ($printOverview) {
    "## Collecting: License Usage Overview"
    Get-LicenseOverviewReport -TXTPath $OutPutPath -printOverview $printOverview
}

if ($exportToFile) {  

    if ($includeExchange) {
        "## Collecting: Shared Mailbox licensing"
        Get-SharedMailboxLicensing -CSVPath $OutPutPath
    }

    "## Collecting: MS Graph Reports"
    Get-GraphReports -CSVPath $OutPutPath

    "## Collecting: Login Logs"
    Get-LoginLogs -CSVPath $OutPutPath

    "## Collecting: All user objects"
    Invoke-RjRbRestMethodGraph -Resource "/users" -FollowPaging | Export-Csv -Path $OutPutPath"\AllUser.csv" -NoTypeInformation

    "## Collecting: Assigned License Plans"
    Get-AssignedPlans -CSVPath $OutPutPath

    "## Collecting: Licensing Groups"
    Get-LicensingGroups -CSVPath $OutPutPath

    "## Collecting: Directly vs. Group assigned Licenses"
    Get-LicenseAssignmentPath -CSVPath $OutPutPath

    "## Collecting: Licensed Admin Accounts"
    Get-AdminReport -CSVPath $OutPutPath

    ""
    Connect-RjRbAzAccount
  
    if (-not $ContainerName) {
        $ContainerName = "office-licensing-v2-" + (get-date -Format "yyyy-MM-dd")
    }
  
    # Make sure storage account exists
    $storAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
    if (-not $storAccount) {
        "## Creating Azure Storage Account $($StorageAccountName)"
        $storAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $StorageAccountLocation -SkuName $StorageAccountSku 
    }
   
    # Get access to the Storage Account
    $keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    $context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $keys[0].Value
  
    # Make sure, container exists
    $container = Get-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction SilentlyContinue
    if (-not $container) {
        "## Creating Azure Storage Account Container $($ContainerName)"
        $container = New-AzStorageContainer -Name $ContainerName -Context $context 
    }
   
    $EndTime = (Get-Date).AddDays(6)

    "## Upload"
    if ($exportAsZip) {
        $zipFileName = "office-licensing-v2-" + (get-date -Format "yyyy-MM-dd") + ".zip"
        Compress-Archive -Path $OutPutPath -DestinationPath $zipFileName | Out-Null
        Set-AzStorageBlobContent -File $zipFileName -Container $ContainerName -Blob $zipFileName -Context $context -Force | Out-Null
        if ($produceLinks) {
            #Create signed (SAS) link
            $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $zipFileName -FullUri -ExpiryTime $EndTime
            "$SASLink"
        }
        "## '$zipFileName' upload successful."
    }
    else {
        # Upload all files individually
        Get-ChildItem -Path $OutPutPath | ForEach-Object {
            Set-AzStorageBlobContent -File $_.FullName -Container $ContainerName -Blob $_.Name -Context $context -Force | Out-Null
            if ($produceLinks) {
                #Create signed (SAS) link
                $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $_.Name -FullUri -ExpiryTime $EndTime
                "## $($_.Name)"
                " $SASLink"
                ""
            }
        }
        "## upload of CSVs successful."
    }
    if ($produceLinks) {
        ""
        "## Expiry of Links: $EndTime"
    }
}

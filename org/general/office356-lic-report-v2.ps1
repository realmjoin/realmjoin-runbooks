<#
  .SYNOPSIS
  Generate an Office 365 licensing report.

  .DESCRIPTION
  Generate an Office 365 licensing report.

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param(
    [bool] $includeExhange = $false,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReportv2.ExportToFile" } )]
    [bool] $exportToFile = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReportv2.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReportv2.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReportv2.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReportv2.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "OfficeLicensingReportv2.StorageAccount.Sku" } )]
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
    "## - OfficeLicensingReportv2.ResourceGroup"
    "## - OfficeLicensingReportv2.StorageAccount.Name"
    "## - OfficeLicensingReportv2.StorageAccount.Location"
    "## - OfficeLicensingReportv2.StorageAccount.Sku"
    ""
    "## Disabling CSV export..."
    $exportToFile = $false
    ""
}

# Static / internal defaults
$OutPutPath = "CloudEconomics\"

Connect-RjRbExchangeOnline
Connect-RjRbGraph

function Get-UnusedLicenseReport {
    param(
        [parameter(Mandatory = $true)][string]$CSVPath
    )
    try {
        $Path = $CSVPath + "\unusedlicense.csv"
        '"AccountSkuId","ActiveUnits","ConsumedUnits","LockedOutUnits"' > $Path
        $lictemp = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus"
        $lictemp | ForEach-Object {
            $_.id + "," + $_.prepaidUnits.enabled + "," + $_.consumedUnits + "," + $_.prepaidUnits.suspended >> $Path
        } 
    }
    catch {
        Write-Host "Fehler bei Abruf der nicht genutzten Lizenzen"
        Write-Host $_.Exception.Message
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
        Write-Host "Fehler beim Export der Graph Reports"
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

    $filter = "createdDateTime ge " + $PastPeriod + "T00:00:00Z and createdDateTime le " + $today + "T00:00:00Z"
    $allLogs = Invoke-RjRbRestMethodGraph -Resource "/auditLogs/signIns" -FollowPaging -OdFilter $filter

    foreach ($app in $Applications) {
        $outputFile = $CSVPath + "\" + "Audit-" + $app + ".csv"
        $allLogs | Where-Object { ($_.appId -eq $app) -or ($_.appDisplayName -eq $app) } | ConvertTo-Csv -NoTypeInformation | Add-Content -Path $outputFile
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

        ## Variant - go for accountskuid
        #Invoke-RjRbRestMethodGraph -Resource "/users/$($_.id)/licenseDetails" | Select-Object -Property @{name = "licenses"; expression = { $_.id } }, @{name = "UserPrincipalName"; expression = { $thisUser.userPrincipalName } }

        ## Variant - use MS Graph license / plan representation
        (Invoke-RjRbRestMethodGraph -Resource "/users/$($_.id)/licenseDetails").servicePlans | Select-Object -Property @{name = "licenses"; expression = { $_.servicePlanId } }, @{name = "UserPrincipalName"; expression = { $thisUser.userPrincipalName } }
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
            $UserHasLicenseAssignedDirectly = $null -eq $sku.assignedByGroup
            $UserHasLicenseAssignedFromGroup = -not $UserHasLicenseAssignedDirectly

            $obj = $user
            $obj | Add-Member -MemberType NoteProperty -Name "SKU" -value $sku.skuId -Force 
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
            $License = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus" -FollowPaging | Where-Object { $_.skuId -eq $assignedLicense.skuId }
            $LicenseString += $License.skuPartNumber + "; "
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
                $Licenses = Invoke-RjRbRestMethodGraph -Resource "/users/$($user.id)" -OdSelect "licenseAssignmentStates"
                $msolUserResults += New-Object psobject -Property @{
                    DisplayName = $user.displayName
                    UPN         = $user.userPrincipalName
                    IsLicensed  = ($Licenses.licenseAssignmentStates.count -gt 0)
                    Licenses    = ($Licenses.licenseAssignmentStates.skuId | ForEach-Object { "$_;" } )
                    Adminrole   = $role.displayName
                }
            }
        }
    }
    $msolUserResults | Select-Object -Property * | Export-Csv -notypeinformation -Path $Path 
}

#region main

if (-Not (Test-Path -Path $OutPutPath)) {
    New-Item -ItemType directory -Path $OutPutPath | Out-Null
}
else {
    "## Deleting old reports"
    Get-ChildItem -Path $OutPutPath -Filter *.csv  | Remove-Item | Out-Null
}

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

#endregion

#region export to file

if ($exportToFile) {  
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

    # Upload
    Get-ChildItem -Path $OutPutPath | ForEach-Object {
        Set-AzStorageBlobContent -File $_.FullName -Container $ContainerName -Blob $_.Name -Context $context -Force | Out-Null
        #Create signed (SAS) link
        $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $_.Name -FullUri -ExpiryTime $EndTime
        "$($_.Name): $SASLink"

    }
  
    ""
    "## Reports created."
    "## Expiry of Links: $EndTime"
    $SASLink | Out-String
  
}
#endregion

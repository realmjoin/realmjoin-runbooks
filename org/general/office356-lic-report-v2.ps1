# New Permission: Reports.Read.All

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
    $url = "/auditLogs/signIns" 
    foreach ($app in $Applications) {
        $filter = "createdDateTime ge " + $PastPeriod + "T00:00:00Z and createdDateTime le " + $today + "T00:00:00Z and (appId eq '" + $app + "' or startswith(appDisplayName,'" + $app + "'))"        
        $outputFile = $CSVPath + "\" + "Audit-" + $app + ".csv"
        Invoke-RjRbRestMethodGraph -Resource $url -OdFilter $filter -FollowPaging | ConvertTo-Csv -NoTypeInformation | Add-Content -Path $outputFile
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
function Get-LicensingGroups{
    [cmdletbinding()]
    param(
        [parameter(Mandatory = $true)][string]$CSVPath
    )
    $reportname = "\LicensingGroups"
    $Path = $CSVPath + $reportname + ".csv"
    $groups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdSelect "assignedLicenses,id,displayName" -FollowPaging| Where-Object {$_.assignedLicenses}
    foreach($group in $groups){
    $LicenseString= ""
    $obj=@()
    $Member =Get-MsolGroupMember -GroupObjectId $group.ObjectId -All 
    $obj = $Member
    foreach ($License in  $group.AssignedLicenses.AccountSkuId.SkuPartNumber){
        $LicenseString += $License+"; "
    }

    $obj | Add-Member -MemberType NoteProperty -Name "GroupLicense" -value $LicenseString
    $obj | Add-Member -MemberType NoteProperty -Name "GroupName" -value $group.DisplayName
    $obj | Add-Member -MemberType NoteProperty -Name "GroupId" -value $group.ObjectId
    $obj | Select -Property * | Export-Csv $Path -Append -NoTypeInformation
    } 
    }   


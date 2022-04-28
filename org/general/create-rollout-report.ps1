<#
  .SYNOPSIS
  Generate an modern workplace rollout report

  .DESCRIPTION
  Generate an modern workplace rollout report

  .EXAMPLE
  Example of Azure Storage Account configuration for RJ central datastore
  {
    "Settings": {
        "RolloutReport": {
            "ResourceGroup": "rj-test-runbooks-01",
            "StorageAccount": {
                "Name": "rbexports01",
                "Location": "West Europe",
                "Sku": "Standard_LRS"
            }
        }
    }
  }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    # Make a persistent container the default, so you can simply update PowerBI's report from the same source
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RolloutReport.Container" } )]
    [string] $ContainerName = "rjrb-licensing-report-v2",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RolloutReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RolloutReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RolloutReport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RolloutReport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName,

    [ValidateScript( { Use-RJInterface -DisplayName "Export reports to Az Storage Account?" -Type Setting -Attribute "RolloutReport.ExportToFile" } )]
    [bool] $exportToFile = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Export reports as single ZIP file?" -Type Setting -Attribute "RolloutReport.ExportToZIPFile" } )]
    [bool] $exportAsZip = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Create SAS Tokens / Links?" -Type Setting -Attribute "RolloutReport.CreateLinks" } )]
    [bool] $produceLinks = $true
)

# Sanity checks
if ($exportToFile -and ((-not $ResourceGroupName) -or (-not $StorageAccountLocation) -or (-not $StorageAccountName) -or (-not $StorageAccountSku))) {
    "## To export to a CSV, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    ""
    "## Please configure the following attributes in the RJ central datastore:"
    "## - RolloutReport.ResourceGroup"
    "## - RolloutReport.StorageAccount.Name"
    "## - RolloutReport.StorageAccount.Location"
    "## - RolloutReport.StorageAccount.Sku"
    ""
    "## Stopping..."
    throw("no storage specified")
    ""
}




# Static / internal defaults
$OutPutPath = "RolloutReport\"

Connect-RjRbGraph
Connect-RjRbExchangeOnline

# "Get SKUs and build a lookuptable for SKU IDs"
$SkuHashtable = @{}
$SKUs = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus" 
$SKUs | ForEach-Object {
    $SkuHashtable.Add($_.skuId, $_.skuPartNumber)
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
        #        (Invoke-RjRbRestMethodGraph -Resource "/users/$($_.id)/licenseDetails").servicePlans | Select-Object -Property @{name = "licenses"; expression = { $_.servicePlanName } }, @{name = "UserPrincipalName"; expression = { $thisUser.userPrincipalName } }
        (Invoke-RjRbRestMethodGraph -Resource "/users/$($_.id)/licenseDetails") | Select-Object -Property @{name = "licenses"; expression = { $_.skuPartNumber } }, @{name = "UserPrincipalName"; expression = { $thisUser.userPrincipalName } }
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

# start of main script

if (-Not (Test-Path -Path $OutPutPath)) {
    New-Item -ItemType directory -Path $OutPutPath | Out-Null
}
else {
    "## Deleting old reports"
    Get-ChildItem -Path $OutPutPath -Filter *.csv  | Remove-Item | Out-Null
    Get-ChildItem -Path $OutPutPath -Filter *.txt  | Remove-Item | Out-Null
}

if ($exportToFile) {  

    "userPrincipalName;userType;accountEnabled;surname;givenName;companyName;department;jobTitle;mail;onPremisesSamAccountName;MFA;MFAMobilePhone;MFAOATH;MFAFido2;MFAApp" > ($OutPutPath + "users.csv")
    "userPrincipalName;manufacturer;model;OS;OSVersion;RegistrationDate" > ($OutPutPath + "devices.csv")
    "userPrincipalName;GroupName;onPremisesSamAccountName" > ($OutPutPath + "groups.csv")
    "userPrincipalName;LicenseName;DirectAssignment;GroupName" > ($OutPutPath + "licenses.csv")


    # Collecting: All user objects
    Invoke-RjRbRestMethodGraph -Resource "/users" -FollowPaging -OdSelect "id,userPrincipalName,userType,accountEnabled,surname,givenName,companyName,department,jobTitle,mail,licenseAssignmentStates,onPremisesSamAccountName" | ForEach-Object {
        $user = $_

        # Filter Exchange special objects...
        $exoUser = Get-EXOMailbox -Identity $user.userPrincipalName -ErrorAction SilentlyContinue
        if ($exoUser -and ($exoUser.RecipientTypeDetails -eq "UserMailbox")) {
        
            # This is a regular user
            
            # Check MFAs.
            # "Find phone auth. methods for user $user.userPrincipalName"
            $phoneAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$($user.userPrincipalName)/authentication/phoneMethods" -Beta

            # "Find Classic OATH App auth methods for user $user.userPrincipalName"
            $OATHAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$($user.userPrincipalName)/authentication/softwareOathMethods" -Beta

            # "Find FIDO2 auth methods for user $user.userPrincipalName"
            $fido2AMs = Invoke-RjRbRestMethodGraph -Resource "/users/$($user.userPrincipalName)/authentication/fido2Methods" -Beta

            # "Find Authenticator App auth methods for user $user.userPrincipalName"
            $appAMs = Invoke-RjRbRestMethodGraph -Resource "/users/$($user.userPrincipalName)/authentication/microsoftAuthenticatorMethods" -Beta
            
            if ($phoneAMs -or $OATHAMs -or $fido2AMs -or $appAMs) {
                $user | Add-Member -NotePropertyName "MFA" -NotePropertyValue "True"
            }
            else {
                $user | Add-Member -NotePropertyName "MFA" -NotePropertyValue "False"
            }

            if ($phoneAMs) {
                $user | Add-Member -NotePropertyName "MFAMobilePhone" -NotePropertyValue $phoneAMs[0].phoneNumber
            }
            else {
                $user | Add-Member -NotePropertyName "MFAMobilePhone" -NotePropertyValue ""
            }

            $user | Add-Member -NotePropertyName "MFAOATH" -NotePropertyValue ([string]($null -ne $OATHAMs))
            $user | Add-Member -NotePropertyName "MFAFido2" -NotePropertyValue ([string]($null -ne $fido2AMs))
            $user | Add-Member -NotePropertyName "MFAApp" -NotePropertyValue ([string]($null -ne $appAMs))
      
            $user.userPrincipalName + ";" + $user.userType + ";" + $user.accountEnabled + ";" + $user.surname + ";" + $user.givenName + ";" + $user.companyName + ";" + $user.department + ";" + $user.jobTitle + ";" + $user.mail + ";" + $user.onPremisesSamAccountName + ";" + $user.MFA + ";" + $user.MFAMobilePhone + ";" + $user.MFAOATH + ";" + $user.MFAFido2 + ";" + $user.MFAApp >> ($OutPutPath + "users.csv") 

            # Check Devices.
            Invoke-RjRbRestMethodGraph -Resource "/users/$($user.userPrincipalName)/ownedDevices" | ForEach-Object {
                $device = Invoke-RjRbRestMethodGraph -Resource "/devices/$($_.id)" 
                $user.userPrincipalName + ";" + $device.manufacturer + ";" + $device.model + ";" + $device.operatingSystem + ";" + $device.operatingSystemVersion + ";" + (get-date $device.registrationDateTime -Format "dd.MM.yyyy") >> ($OutPutPath + "devices.csv")
            }

            # Check Groups.
            Invoke-RjRbRestMethodGraph -Resource "/users/$($user.userPrincipalName)/getMemberGroups" -Method POST -Body @{ "securityEnabledOnly" = $false } | ForEach-Object {
                $group = Invoke-RjRbRestMethodGraph -Resource "/groups/$($_)" -OdSelect "displayName,onPremisesSamAccountName"
                $user.userPrincipalName + ";" + $group.displayName + ";" + $group.onPremisesSamAccountName >> ($OutPutPath + "groups.csv")
            }

            # Check Licenses.
            $user.licenseAssignmentStates | ForEach-Object {
                $sku=$_
                $groupName = ""
                $skuPartNumber = $SkuHashtable[$sku.skuId]
                if ($sku.assignedByGroup) {
                    $groupName = (Invoke-RjRbRestMethodGraph -Resource "/groups/$($sku.assignedByGroup)").displayName
                }

                $user.userPrincipalName + ";" + $skuPartNumber + ";" + ([string]($null -eq $sku.assignedByGroup)) + ";" + $groupName >> ($OutPutPath + "licenses.csv")
            }
        } 
    } 


    ###

    ""
    Connect-RjRbAzAccount
  
    if (-not $ContainerName) {
        #$ContainerName = "rollout-report-" + (get-date -Format "yyyy-MM-dd")
        $ContainerName = "rollout-report" 
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

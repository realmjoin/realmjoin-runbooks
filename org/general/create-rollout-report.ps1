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

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }


#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    # Make a persistent container the default, so you can simply update PowerBI's report from the same source
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RolloutReport.Container" } )]
    [string] $ContainerName = "rjrb-rollout-report",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RolloutReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RolloutReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RolloutReport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RolloutReport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    [ValidateScript( { Use-RJInterface -DisplayName "Export reports to Az Storage Account?" -Type Setting -Attribute "RolloutReport.ExportToFile" } )]
    [bool] $exportToFile = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Export reports as single ZIP file?" -Type Setting -Attribute "RolloutReport.ExportToZIPFile" } )]
    [bool] $exportAsZip = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Create SAS Tokens / Links?" -Type Setting -Attribute "RolloutReport.CreateLinks" } )]
    [bool] $produceLinks = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
    
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
$SKUs = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus" -FollowPaging
$SKUs | ForEach-Object {
    $SkuHashtable.Add($_.skuId, $_.skuPartNumber)
}

# Group Hashtable - build ID->DisplayName lookup over time.
$GroupNameHashtable = @{}
$GroupSamHashtable = @{}

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

    $intervalAuth = New-TimeSpan -Minutes 30
    $timerAuth = Get-Date
    $intervalProgress = New-TimeSpan -Minutes 1
    $timerProgress = Get-Date
    $userCount = 0

    "userPrincipalName;userType;accountEnabled;surname;givenName;companyName;department;jobTitle;mail;onPremisesSamAccountName;MFA;MFAMobilePhone;MFAOATH;MFAFido2;MFAApp" > ($OutPutPath + "users.csv")
    # switched to intune as sole data source for devices
    ##"userPrincipalName;manufacturer;model;OS;OSVersion;RegistrationDate;trustType;mdmAppId;isCompliant;deviceId;serialNumber" > ($OutPutPath + "devices.csv")
    "userPrincipalName;deviceName;manufacturer;model;OS;OSVersion;RegistrationDate;isCompliant;deviceId;serialNumber" > ($OutPutPath + "devices.csv")
    "userPrincipalName;GroupName;onPremisesSamAccountName" > ($OutPutPath + "groups.csv")
    "userPrincipalName;LicenseName;DirectAssignment;GroupName" > ($OutPutPath + "licenses.csv")
    "currentDate;currentTime" > ($OutPutPath + "currentDate.csv")

    # Writing current date - how fresh is our current report?
    "$(get-date -Format "yyyy-MM-dd");$(get-date -Format "HH:mm")" >> ($OutPutPath + "currentDate.csv")

    "## Collecting: All Intune Devices"
    $IntuneDevices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -FollowPaging
    foreach ($device in $IntuneDevices) {
        $result = "$($device.userPrincipalName);$($device.deviceName);$($device.manufacturer);$($device.model);$($device.operatingSystem);$($device.osVersion);"
        if ($device.enrolledDateTime) {
            $result += "$(get-date $device.enrolledDateTime -Format "yyyy-MM-dd")"
        }
        else {
            $result += ";"
        }
        if ($Device.complianceState -eq "compliant") {
            $result += "$($true);"
        } else {
            $result += "$($false);"
        }
        $result += "$($device.azureADDeviceId);$($device.serialNumber)"
        $result >> ($OutPutPath + "devices.csv")
    }


    "## Collecting: All User Objects"
    Invoke-RjRbRestMethodGraph -Resource "/users" -FollowPaging -OdSelect "id,userPrincipalName,userType,accountEnabled,surname,givenName,companyName,department,jobTitle,mail,licenseAssignmentStates,onPremisesSamAccountName" -OdFilter "userType eq 'Member'" | ForEach-Object {
        if ((get-date) -gt ($timerAuth + $intervalAuth)) {
            "## Reauthenticating..."
            Disconnect-ExchangeOnline -Confirm:$false
            Connect-RjRbGraph -Force
            Connect-RjRbExchangeOnline
            $timerAuth = get-date
        }
        
        if ((get-date) -gt ($timerProgress + $intervalProgress)) {
            "## Users processed: $userCount"
            $timerProgress = Get-Date
        }
        $userCount++;

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

            # switched to Intune as sole source for devices
            <#
            # Check Devices.
            $userDevices = @()
            if ($trackOwnedDevices) {
                $userDevices=Invoke-RjRbRestMethodGraph -Resource "/users/$($user.userPrincipalName)/ownedDevices" -FollowPaging
            } else {
                $userDevices=Invoke-RjRbRestMethodGraph -Resource "/users/$($user.userPrincipalName)/registeredDevices" -FollowPaging
            }
            $userDevices | ForEach-Object {
                #$device = Invoke-RjRbRestMethodGraph -Resource "/devices/$($_.id)" 
                $device = $_
                if ($device.registrationDateTime) {
                    $regDate = (get-date $device.registrationDateTime -Format "yyyy-MM-dd")
                }
                else {
                    $regDate = ""
                }
                $serial = (Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$($userDevices.deviceId)'" -ErrorAction SilentlyContinue).serialNumber
                $user.userPrincipalName + ";" + $device.manufacturer + ";" + $device.model + ";" + $device.operatingSystem + ";" + $device.operatingSystemVersion + ";" + $regDate + ";" + $device.trustType + ";" + $device.mdmAppId + ";" + $device.isCompliant + ";" + $device.deviceId + ";" + $serial >> ($OutPutPath + "devices.csv")
            }
            #>

            # Check Groups.
            Invoke-RjRbRestMethodGraph -Resource "/users/$($user.userPrincipalName)/getMemberGroups" -Method POST -Body @{ "securityEnabledOnly" = $false } -FollowPaging | ForEach-Object {
                if ($GroupNameHashtable.Contains("$_")) {
                    $user.userPrincipalName + ";" + $GroupNameHashtable["$_"] + ";" + $GroupSamHashtable["$_"] >> ($OutPutPath + "groups.csv")
                }
                else {
                    $group = Invoke-RjRbRestMethodGraph -Resource "/groups/$($_)" -OdSelect "displayName,onPremisesSamAccountName"
                    $GroupNameHashtable["$_"] = $group.displayName
                    $GroupSamHashtable["$_"] = $group.onPremisesSamAccountName
                    $user.userPrincipalName + ";" + $group.displayName + ";" + $group.onPremisesSamAccountName >> ($OutPutPath + "groups.csv")
                }
            }

            # Check Licenses.
            $user.licenseAssignmentStates | ForEach-Object {
                $sku = $_
                $groupName = ""
                $skuPartNumber = $SkuHashtable[$sku.skuId]
                if ($sku.assignedByGroup) {
                    $groupName = (Invoke-RjRbRestMethodGraph -Resource "/groups/$($sku.assignedByGroup)" -FollowPaging).displayName
                }

                $user.userPrincipalName + ";" + $skuPartNumber + ";" + ([string]($null -eq $sku.assignedByGroup)) + ";" + $groupName >> ($OutPutPath + "licenses.csv")
            }
        } 
    } 

    Disconnect-ExchangeOnline -Confirm:$false | Out-Null

    Invoke-RjRbRestMethodGraph -Resource "/devices" -FollowPaging | ConvertTo-Csv > ($OutPutPath + "devicesRaw.csv")

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
        $zipFileName = "rollout-report-" + (get-date -Format "yyyy-MM-dd") + ".zip"
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

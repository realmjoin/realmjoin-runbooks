<#
  .SYNOPSIS
  Export a CSV of all (entprise) app owners and users

  .DESCRIPTION
  Export a CSV of all (entprise) app owners and users
#>

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

param(
    [ValidateScript( { Use-RJInterface -DisplayName "List only Enterprise Apps" } )]
    [bool] $entAppsOnly = $true
)

if (-not $ContainerName) {
    $ContainerName = "enterprise-apps-" + (get-date -Format "yyyy-MM-dd")
}

Connect-RjRbGraph
Connect-RjRbAzAccount

try {
    #region configuration import
    # "Getting Process configuration - JSON in Az Automation Variable"
    $processConfigRaw = Get-AutomationVariable -name "SettingsExports" -ErrorAction SilentlyContinue
    if (-not $processConfigRaw) {
        ## production default
        $processConfigURL = "https://raw.githubusercontent.com/realmjoin/realmjoin-runbooks/production/setup/defaults/settings-org-policies-export.json"
        $webResult = Invoke-WebRequest -UseBasicParsing -Uri $processConfigURL 
        $processConfigRaw = $webResult.Content        ## staging default
        #$processConfigURL = "https://raw.githubusercontent.com/realmjoin/realmjoin-runbooks/master/setup/defaults/settings-org-policies-export.json"
    }
    # Write-RjRbDebug "Process Config URL is $($processConfigURL)"

    # "Getting Process configuration"
    $processConfig = $processConfigRaw | ConvertFrom-Json

    if (-not $ResourceGroupName) {
        $ResourceGroupName = $processConfig.exportResourceGroupName
    }

    if (-not $StorageAccountName) {
        $StorageAccountName = $processConfig.exportStorAccountName
    }

    if (-not $StorageAccountLocation) {
        $StorageAccountLocation = $processConfig.exportStorAccountLocation
    }

    if (-not $StorageAccountSku) {
        $StorageAccountSku = $processConfig.exportStorAccountSKU
    }
    #endregion


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

    'AppId;AppDisplayName;AccountEnabled;HideApp;AssignmentRequired;PrincipalRole;PrincipalType;PrincipalId' > enterpriseApps.csv

    $servicePrincipals | ForEach-Object {
        $AppId = $_.appId
        $AppDisplayName = $_.displayName
        $AccountEnabled = $_.accountEnabled | Out-String
        $HideApp = $_.tags -contains "hideapp" | Out-String
        $AssignmentRequired = $_.appRoleAssignmentRequired | Out-String

        # Get Owners
        $owners = Invoke-RjRbRestMethodGraph -resource "/servicePrincipals/$($_.id)/owners"
        if ($owners) {
        $owners | ForEach-Object {
            #"Owner: $($_.userPrincipalName)"
            "$AppId;$AppDisplayName;$AccountEnabled;$HideApp;$AssignmentRequired;Owner;User;$($_.userPrincipalName)" >> enterpriseApps.csv
        } } else {
            # Make sure to list apps missing an owner
            "$AppId;$AppDisplayName;$AccountEnabled;$HideApp;$AssignmentRequired;Owner;User;;" >> enterpriseApps.csv
        }
    
        # Get App Role assignments
        $users = Invoke-RjRbRestMethodGraph -resource "/servicePrincipals/$($_.id)/appRoleAssignedTo"
        $users | ForEach-Object {
            if ($_.principalType -eq "User") {
                $userobject = Invoke-RjRbRestMethodGraph -resource "/users/$($_.principalId)"
                #"Assigned to User: $($userobject.userPrincipalName)"
                "$AppId;$AppDisplayName;$AccountEnabled;$HideApp;$AssignmentRequired;Member;User;$($userobject.userPrincipalName)" >> enterpriseApps.csv
            }
            elseif ($_.principalType -eq "Group") {
                $groupobject = $userobject = Invoke-RjRbRestMethodGraph -resource "/groups/$($_.principalId)"
                #"Assigned to Group: $($groupobject.mailNickname)"
                "$AppId;$AppDisplayName;$AccountEnabled;$HideApp;$AssignmentRequired;Member;Group;$($groupobject.mailNickname) ($($groupobject.displayName))" >> enterpriseApps.csv
            }
            elseif ($_.principalType -eq "ServicePrincipal") {
                #"Assigned to ServicePrincipal: $($_.principalId)"
                "$AppId;$AppDisplayName;$AccountEnabled;$HideApp;$AssignmentRequired;Member;ServicePrincipal;$($_.principalId)" >> enterpriseApps.csv
            }
        
        }
    }

    # Make sure storage account exists
    $storAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
    if (-not $storAccount) {
        "Creating Azure Storage Account $($StorageAccountName)"
        $storAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $StorageAccountLocation -SkuName $StorageAccountSku 
    }
 
    # Get access to the Storage Account
    $keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    $context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $keys[0].Value

    # Make sure, container exists
    $container = Get-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction SilentlyContinue
    if (-not $container) {
        "Creating Azure Storage Account Container $($ContainerName)"
        $container = New-AzStorageContainer -Name $ContainerName -Context $context 
    }
 
    # Upload
    Set-AzStorageBlobContent -File "enterpriseApps.csv" -Container $ContainerName -Blob "enterpriseApps.csv" -Context $context -Force | Out-Null
 
    #Create signed (SAS) link
    $EndTime = (Get-Date).AddDays(6)
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob "enterpriseApps.csv" -FullUri -ExpiryTime $EndTime

    "App Owner/User List Export created."
    "Expiry of Link: $EndTime"
    $SASLink | Out-String
    
}
catch {
    throw $_
}
finally {
    Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
}
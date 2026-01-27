<#
    .SYNOPSIS
    Export a CSV of all (enterprise) application owners and users

    .DESCRIPTION
    This runbook exports a comprehensive list of all enterprise applications (or all service principals)
    in your Azure AD tenant along with their owners and assigned users/groups. Afterwards the CSV file is uploaded
    to an Azure Storage Account, from where it can be downloaded.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "entAppsOnly": {
                "DisplayName": "Scope",
                "SelectSimple": {
                    "List only Enterprise Apps": true,
                    "List all Service Principals / Apps": false
                }
            },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "List only Enterprise Apps" } )]
    [bool] $entAppsOnly = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EntAppsReport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EntAppsReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EntAppsReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EntAppsReport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EntAppsReport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

if (-not $ContainerName) {
    $ContainerName = "enterprise-apps-" + (get-date -Format "yyyy-MM-dd")
}

Connect-RjRbGraph
Connect-RjRbAzAccount

try {
    # Configuration import - fallback to Az Automation Variable
    if ((-not $ResourceGroupName) -or (-not $StorageAccountName) -or (-not $StorageAccountLocation) -or (-not $StorageAccountSku)) {
        $processConfigRaw = Get-AutomationVariable -name "SettingsExports" -ErrorAction SilentlyContinue
        #if (-not $processConfigRaw) {
        ## production default - use this as template to create the Az. Automation Variable "SettingsExports"
        #    $processConfigURL = "https://raw.githubusercontent.com/realmjoin/realmjoin-runbooks/production/setup/defaults/settings-org-policies-export.json"
        #    $webResult = Invoke-WebRequest -UseBasicParsing -Uri $processConfigURL
        #    $processConfigRaw = $webResult.Content        ## staging default
        #}
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
    }

    if ((-not $ResourceGroupName) -or (-not $StorageAccountName) -or (-not $StorageAccountSku) -or (-not $StorageAccountLocation)) {
        "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
        "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
        ""
        "## Configure the following attributes:"
        "## - EntAppsReport.ResourceGroup"
        "## - EntAppsReport.StorageAccount.Name"
        "## - EntAppsReport.StorageAccount.Location"
        "## - EntAppsReport.StorageAccount.Sku"
        ""
        "## Stopping execution."
        throw "Missing Storage Account Configuration."
    }

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

    'AppId;AppDisplayName;AccountEnabled;HideApp;AssignmentRequired;PrincipalRole;PrincipalType;PrincipalId;Notes' > enterpriseApps.csv

    $servicePrincipals | ForEach-Object {
        $AppId = $_.appId
        $AppDisplayName = $_.displayName
        $AccountEnabled = $_.accountEnabled
        $HideApp = $_.tags -contains "hideapp"
        $AssignmentRequired = $_.appRoleAssignmentRequired

        if ($_.notes) {
            $Notes = [string]::join(" ", ($_.notes.Split("`n") -replace (';', ',')))
        }
        else {
            $Notes = ""
        }

        # Get Owners
        $owners = Invoke-RjRbRestMethodGraph -resource "/servicePrincipals/$($_.id)/owners"
        if ($owners) {
            $owners | ForEach-Object {
                #"Owner: $($_.userPrincipalName)"
                "$AppId;$AppDisplayName;$AccountEnabled;$HideApp;$AssignmentRequired;Owner;User;$($_.userPrincipalName);$Notes" >> enterpriseApps.csv
            }
        }
        else {
            # Make sure to list apps missing an owner
            "$AppId;$AppDisplayName;$AccountEnabled;$HideApp;$AssignmentRequired;Owner;User;;$Notes" >> enterpriseApps.csv
        }

        # Get App Role assignments
        $users = Invoke-RjRbRestMethodGraph -resource "/servicePrincipals/$($_.id)/appRoleAssignedTo"
        $users | ForEach-Object {
            if ($_.principalType -eq "User") {
                $userobject = Invoke-RjRbRestMethodGraph -resource "/users/$($_.principalId)"
                #"Assigned to User: $($userobject.userPrincipalName)"
                "$AppId;$AppDisplayName;$AccountEnabled;$HideApp;$AssignmentRequired;Member;User;$($userobject.userPrincipalName);$Notes" >> enterpriseApps.csv
            }
            elseif ($_.principalType -eq "Group") {
                $groupobject = $userobject = Invoke-RjRbRestMethodGraph -resource "/groups/$($_.principalId)"
                #"Assigned to Group: $($groupobject.mailNickname)"
                "$AppId;$AppDisplayName;$AccountEnabled;$HideApp;$AssignmentRequired;Member;Group;$($groupobject.mailNickname) ($($groupobject.displayName));$Notes" >> enterpriseApps.csv
            }
            elseif ($_.principalType -eq "ServicePrincipal") {
                #"Assigned to ServicePrincipal: $($_.principalId)"
                "$AppId;$AppDisplayName;$AccountEnabled;$HideApp;$AssignmentRequired;Member;ServicePrincipal;$($_.principalId);$Notes" >> enterpriseApps.csv
            }

        }
    }
    $content = Get-Content -Path "enterpriseApps.csv"
    set-content -Path "enterpriseApps.csv" -Value $content -Encoding UTF8

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

    # Upload
    Set-AzStorageBlobContent -File "enterpriseApps.csv" -Container $ContainerName -Blob "enterpriseApps.csv" -Context $context -Force | Out-Null

    #Create signed (SAS) link
    $EndTime = (Get-Date).AddDays(6)
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob "enterpriseApps.csv" -FullUri -ExpiryTime $EndTime

    "## App Owner/User List Export created."
    "## Expiry of Link: $EndTime"
    $SASLink | Out-String

}
catch {
    throw $_
}
finally {
    Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
}
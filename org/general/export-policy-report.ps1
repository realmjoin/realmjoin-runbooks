<#
.SYNOPSIS 
    Create a report of a tenant's polcies from Intune and AAD and write them to a markdown file.
#>

#Requires -Modules Microsoft.Graph.Authentication

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Create SAS Tokens / Links?" -Type Setting -Attribute "TenantPolicyReport.CreateLinks" } )]
    [bool] $produceLinks = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TenantPolicyReport.Container" } )]
    [string] $ContainerName = "rjrb-licensing-report-v2",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TenantPolicyReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TenantPolicyReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TenantPolicyReport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TenantPolicyReport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

function ConvertToMarkdown-CompliancePolicy {
    # https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies

    # https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceconfig-windows10compliancepolicy?view=graph-rest-1.0
    # https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceconfig-ioscompliancepolicy?view=graph-rest-1.0
    # ... More if needed according to BluePrint

    # Still missing:
    # - grace period (scheduled actions)
    # - assignments

    param(
        $policy
    )

    "### $($policy.displayName)"
    ""

    # This can be MASSIVELY improved :)
    "|Setting|Value|Description|"
    "|-------|-----|-----------|"
    foreach ($key in $policy.keys) { 
        if ($($null -ne $policy.$key) -and ($key -notin ("@odata.type","id","createdDateTime","lastModifiedDateTime","displayName","version"))) {
            "|$key|$($policy.$key)||" 
        }
    }
    ""

}

function ConvertToMarkdown-ConditionalAccessPolicy {
    param(
        $policy
    )

    "### $($policy.displayName)"
    ""

    "#### Conditions"
    ""
    "|Setting|Value|Description|"
    "|-------|-----|-----------|"
    if ($policy.conditions.applications.includeApplications) {
        "|Include applications|$(foreach ($app in $policy.conditions.applications.includeApplications) { $app + "<br/>"})||"
    }
    if ($policy.conditions.applications.excludeApplications) {
        "|Exclude applications|$(foreach ($app in $policy.conditions.applications.excludeApplications) { $app + "<br/>"})||"
    }
    if ($policy.conditions.applications.includeUserActions) {
        "|Include user actions|$(foreach ($app in $policy.conditions.applications.includeUserActions) { $app + "<br/>"})||"
    }
    if ($policy.conditions.applications.excludeUserActions) {
        "|Exclude user actions|$(foreach ($app in $policy.conditions.applications.excludeUserActions) { $app + "<br/>"})||"
    }
    if ($policy.conditions.platforms.includePlatforms) {
        "|Include platforms|$(foreach ($platform in $policy.conditions.platforms.includePlatforms) { $platform + "<br/>"})||"
    }
    if ($policy.conditions.platforms.excludePlatforms) {
        "|Exclude platforms|$(foreach ($platform in $policy.conditions.platforms.excludePlatforms) { $platform + "<br/>"})||"
    }
    if ($policy.conditions.locations.includeLocations) {
        "|Include locations|$(foreach ($location in $policy.conditions.locations.includeLocations) { $location + "<br/>"})||"
    }
    if ($policy.conditions.locations.excludeLocations) {
        "|Exclude locations|$(foreach ($location in $policy.conditions.locations.excludeLocations) { $location + "<br/>"})||"
    }
    if ($policy.conditions.users.includeGroups) {
        "|Include groups|$(foreach ($group in $policy.conditions.users.includeGroups) { $group + "<br/>"})||"
    }
    if ($policy.conditions.users.excludeGroups) {
        "|Exclude groups|$(foreach ($group in $policy.conditions.users.excludeGroups) { $group + "<br/>"})||"
    }
    if ($policy.conditions.users.includeRoles) {
        "|Include roles|$(foreach ($role in $policy.conditions.users.includeRoles) { $role + "<br/>"})||"
    }  
    if ($policy.conditions.users.excludeRoles) {
        "|Exclude roles|$(foreach ($role in $policy.conditions.users.excludeRoles) { $role + "<br/>"})||"
    }  
    if ($policy.conditions.users.includeUsers) {
        "|Include users|$(foreach ($user in $policy.conditions.users.includeUsers) { $user + "<br/>"})||"
    }
    if ($policy.conditions.users.excludeUsers) {
        "|Exclude users|$(foreach ($user in $policy.conditions.users.excludeUsers) { $user + "<br/>"})||"
    }
    if ($policy.conditions.clientAppTypes) {
        "|Client app types|$(foreach ($app in $policy.conditions.clientAppTypes) { $app + "<br/>"})||"
    }
    if ($policy.conditions.servicePrincipalRiskLevels) {
        "|Service principal risk levels|$(foreach ($risklevel in $policy.conditions.servicePrincipalRiskLevels) { $risklevel + "<br/>"})||"
    }
    if ($policy.conditions.signInRiskLevels) {
        "|Sign-in risk levels|$(foreach ($risklevel in $policy.conditions.signInRiskLevels) { $risklevel + "<br/>"})||"
    }
    if ($policy.conditions.userRiskLevels) {
        "|User risk levels|$(foreach ($risklevel in $policy.conditions.userRiskLevels) { $risklevel + "<br/>"})||"
    }
    ""

}

function ConvertToMarkdown-ConfigurationPolicy {
    # Still missing
    # - assignments

    param(
        $policy
    )

    "### $($policy.name)"
    ""
    "$($policy.description)"
    $settings = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($policy.id)/settings`?`$expand=settingDefinitions`&top=1000"
    foreach ($setting in $settings.value) {

        if ($setting.settingInstance."@odata.type" -eq "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance") {
            $definition = $setting.settingdefinitions | Where-Object { $_.id -eq $setting.settingInstance.settingDefinitionId }
            $displayValue = ($definition.options | Where-Object { $_.itemId -eq $setting.settingInstance.choiceSettingValue.value }).displayName
            $setting.settingInstance.choiceSettingValue.children.simpleSettingCollectionValue.value | ForEach-Object {
                $displayValue += "<br/>$_"
            }
            ""
            "|Setting|Value|Description|"
            "|-------|-----|-----------|"
            "|$($definition.displayName)|$displayValue|$($definition.description.split("`n").split("`r") -join "<br/>" -replace "<br/><br/>","<br/>" -replace "<br/><br/>","<br/>")|"
            ""
        }
        elseif ($setting.settingInstance."@odata.type" -eq "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance") {
            foreach ($groupSetting in $setting.settingInstance.groupSettingCollectionValue.children) {
                if ($groupSetting."@odata.type" -eq "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance") {
                    $definition = $setting.settingdefinitions | Where-Object { $_.id -eq $groupSetting.settingDefinitionId }
                    $displayValue = ($definition.options | Where-Object { $_.itemId -eq $groupSetting.choiceSettingValue.value }).displayName
                    $groupSetting.choiceSettingValue.children.simpleSettingCollectionValue.value | ForEach-Object {
                        $displayValue += "<br/>$_"
                    }
                    ""
                    "|Setting|Value|Description|"
                    "|-------|-----|-----------|"
                    "|$($definition.displayName)|$displayValue|$($definition.description.split("`n").split("`r") -join "<br/>" -replace "<br/><br/>","<br/>" -replace "<br/><br/>","<br/>")|"
                    ""
                }

                if ($groupSetting."@odata.type" -eq "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance") {
                    foreach ($group2Setting in $groupSetting.groupSettingCollectionValue.children) {
                        $definition = $setting.settingdefinitions | Where-Object { $_.id -eq $group2Setting.settingDefinitionId }
                        if ($group2Setting."@odata.type" -eq "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance") {
                            $displayValue = ($definition.options | Where-Object { $_.itemId -eq $group2Setting.choiceSettingValue.value }).displayName
                            $group2Setting.choiceSettingValue.children.simpleSettingCollectionValue.value | ForEach-Object {
                                $displayValue += "<br/>$_"
                            }
                            ""
                            "|Setting|Value|Description|"
                            "|-------|-----|-----------|"
                            "|$($definition.displayName)|$displayValue|$($definition.description.split("`n").split("`r") -join "<br/>" -replace "<br/><br/>","<br/>" -replace "<br/><br/>","<br/>")|"
                            ""
                        }
                        elseif ($group2Setting."@odata.type" -eq "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance") {
                            #"TYPE: DEBUG: Choice Setting Collection"
                            "|Setting|Value|Description|"
                            "|-------|-----|-----------|"
                            "|$($definition.displayName)|$(
                            foreach ($value in $group2Setting.choiceSettingCollectionValue.value) {
                                ($definition.options | Where-Object { $_.itemId -eq $value }).displayName
                            }
                            )|$($definition.description.split("`n").split("`r") -join "<br/>" -replace "<br/><br/>","<br/>" -replace "<br/><br/>","<br/>")"
                        }
                        else {
                            "TYPE: $($group2Setting."@odata.type") not yet supported"
                        }
                    }
                }
            }
        }
        else {
            "TYPE: $($setting.settingInstance."@odata.type") not yet supported"
        }
    }
    ""
}

function ConvertToMarkdown-DeviceConfiguration {
    param(
        [Parameter(Mandatory = $true)]
        $policy
    )

    "### $($policy.displayName)" 
    ""

    "| Setting | Value | Description |"
    "| ------- | ----- | ----------- |"
    foreach ($key in $policy.keys) {
        if ($key -notin @("id", "displayName", "version", "lastModifiedDateTime", "createdDateTime", "@odata.type")) {
            if ($null -ne $policy.$key) {
                "| $($key) | $(foreach ($value in $policy.$key) { 
                        if (($value -is [System.Collections.Hashtable]))
                        {
                            # Handle encryption of SiteToZone Assignments
                            if ($value.omaUri -eq "./User/Vendor/MSFT/Policy/Config/InternetExplorer/AllowSiteToZoneAssignmentList") {
                                $decryptedValue = invoke-mggraphrequest -uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($policy.id)/getOmaSettingPlainTextValue(secretReferenceValueId='$($value.secretReferenceValueId)')"
                                $decryptedValue = ($decryptedValue.value.split('"')[3]) -replace '&#xF000;',';'
                                "displayName : $($value.displayName)<br/>"
                                [array]$pairs = $decryptedValue.Split(';')
                                if (($pairs.Count % 2) -eq 0) {
                                    [int]$i = 0;
                                    do {
                                        switch ($pairs[$i + 1]) {
                                            0 { $value = "My Computer (0)" }
                                            1 { $value = "Local Intranet Zone (1)" }
                                            2 { $value = "Trusted sites Zone (2)" }
                                            3 { $value = "Internet Zone (3)" }
                                            4 { $value = "Restricted Sites Zone (4)" }
                                            Default { $value = $pairs[$i + 1] }
                                        }
                                        "$($pairs[$i]) : $value<br/>"
                                        $i = $i + 2
                                    } while ($i -lt $pairs.Count)
                                } else {
                                    "Error in parsing SiteToZone Assignments"
                                }
                            } else { 
                            foreach ($subkey in $value.keys) {
                                if ($null -ne $value.$subkey) {
                                    "$subkey : $($value.$subkey)<br/>"
                                }
                            }  
                        }
                        }
                        else
                        {
                            "$value<br/>" 
                        }
                    }) | |"
            }
            
        }
    }
    ""
}

function ConvertToMarkdown-GroupPolicyConfiguration {
    param(
        $policy
    )

    # Process the policy and its definitions like https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/a53d6338-37b3-4964-b732-16cb68eb3a21/definitionValues/dacb5076-5625-4a6f-b93b-3906c3e113eb/definition
    # to create a table with the settings and their values
    #
    # Maybe "https://graph.microsoft.com/beta/deviceManagement/groupPolicyCategories?$expand=parent($select=id,displayName,isRoot),definitions($select=id,displayName,categoryPath,classType,policyType,version,hasRelatedDefinitions)&$select=id,displayName,isRoot,ingestionSource&$filter=ingestionSource eq 'builtIn'" helps

    "### $($policy.displayName)"
    ""
    if ($policy.description) {
        "$($policy.description)"
        ""
    }

    $definitionValues = (Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policy.id)/definitionValues").value
    $definitionValues | ForEach-Object {
        $definitionValue = $_
        $definition = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policy.id)/definitionValues/$($definitionValue.id)/definition"
        "#### $($definition.displayName)"
        ""
        #"$($definition.explainText)"
        #""
        "|Setting|Value|Description|"
        "|---|---|---|"
        # replace newlines in $($definition.explainText) with `<br/>` to get a proper markdown table
        "| Enabled | $($_.enabled) | $($definition.explainText.split("`n").split("`r") -join "<br/>" -replace "<br/><br/>","<br/>" -replace "<br/><br/>","<br/>") |"
        $presentationValues = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policy.id)/definitionValues/$($definitionValue.id)/presentationValues"
        foreach ($presentationValue in $presentationValues.value) {
            $presentation = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policy.id)/definitionValues/$($definitionValue.id)/presentationValues/$($presentationValue.id)/presentation"
            # "Label: " + $($presentation.label)
            $item = ($presentation.items | Where-Object { $_.value -eq $presentationValue.value })
            if ($item) {
                "| $($presentation.label) | $($item.displayName) ||"
                #"Value: " + $($item.displayName)
            }
            else {
                "| $($presentation.label) | $($presentationValue.value) ||"
                #"Value: " + $($presentationValue.value)
            }
        }
        ""
    }
}

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

# Sanity checks
if ($exportToFile -and ((-not $ResourceGroupName) -or (-not $StorageAccountLocation) -or (-not $StorageAccountName) -or (-not $StorageAccountSku))) {
    "## To export to a CSV, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    ""
    "## Please configure the following attributes in the RJ central datastore:"
    "## - TenantPolicyReport.ResourceGroup"
    "## - TenantPolicyReport.StorageAccount.Name"
    "## - TenantPolicyReport.StorageAccount.Location"
    "## - TenantPolicyReport.StorageAccount.Sku"
    ""
    "## Disabling CSV export..."
    $exportToFile = $false
    ""
}

"## Authenticating to Microsoft Graph..."

# Temporary file for markdown output
$outputFileMarkdown = "$env:TEMP\policy-report.md"

## Auth (directly calling auth endpoint)
$resourceURL = "https://graph.microsoft.com/" 
$authUri = $env:IDENTITY_ENDPOINT
$headers = @{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"}

$AuthResponse = Invoke-WebRequest -UseBasicParsing -Uri "$($authUri)?resource=$($resourceURL)" -Method 'GET' -Headers $headers
$accessToken = ($AuthResponse.content | ConvertFrom-Json).access_token

Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All,Policy.Read.All" -AccessToken $accessToken

"## Creating Report..."

# Header
"# Report" > $outputFileMarkdown
"" >> $outputFileMarkdown

#region Configuration Policy (Settings Catalog, Endpoint Sec.)
"## Configuration Policies (Settings Catalog)" >> $outputFileMarkdown
"" >> $outputFileMarkdown

$policies = Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" 

foreach ($policy in $policies.value) {
    (ConvertToMarkdown-ConfigurationPolicy -policy $policy).replace('\','\\') >> $outputFileMarkdown    
    # TODO: Assignments
}
#endregion

#region Device Configurations
"## Device Configurations" >> $outputFileMarkdown
"" >> $outputFileMarkdown

$deviceConfigurations = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations"

foreach ($policy in $deviceConfigurations.value) {
    ConvertToMarkdown-DeviceConfiguration -policy $policy >> $outputFileMarkdown
}
#endregion

#region Group Policy Configurations
"## Group Policy Configurations" >> $outputFileMarkdown
"" >> $outputFileMarkdown

$groupPolicyConfigurations = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations"

foreach ($policy in $groupPolicyConfigurations.value) {
    ConvertToMarkdown-GroupPolicyConfiguration -policy $policy >> $outputFileMarkdown
}
#endregion

#region Compliance Policies
"## Compliance Policies" >> $outputFileMarkdown
"" >> $outputFileMarkdown

$compliancePolicies = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies"

foreach ($policy in $compliancePolicies.value) {
    ConvertToMarkdown-CompliancePolicy -policy $policy >> $outputFileMarkdown
}
#endregion

#region Conditional Access Policies
"## Conditional Access Policies" >> $outputFileMarkdown
"" >> $outputFileMarkdown

$conditionalAccessPolicies = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies"

foreach ($policy in $conditionalAccessPolicies.value) {
    ConvertToMarkdown-ConditionalAccessPolicy -policy $policy >> $outputFileMarkdown
}
#endregion

# Footer
"" >> $outputFileMarkdown

"## Uploading to Azure Storage Account..."

Connect-RjRbAzAccount

if (-not $ContainerName) {
    $ContainerName = "tenant-policy-report-" + (get-date -Format "yyyy-MM-dd")
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

# Upload markdown file
$blobname = "policy-report.md"
$blob = Set-AzStorageBlobContent -File $outputFileMarkdown -Container $ContainerName -Blob $blobname -Context $context -Force
if ($produceLinks) {
    #Create signed (SAS) link
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $blobname -FullUri -ExpiryTime $EndTime
    "## $($_.Name)"
    " $SASLink"
    ""
}

Disconnect-AzAccount
Disconnect-MgGraph

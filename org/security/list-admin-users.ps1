<#
  .SYNOPSIS
  List AzureAD role holders and their MFA state.

  .DESCRIPTION
  Will list users and service principals that hold a builtin AzureAD role. 
  Admins will be queried for valid MFA methods.

  .NOTES
  Permissions: MS Graph
  - User.Read.All
  - Directory.Read.All
  - RoleManagement.Read.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "ContainerName": {
                "Hide": true
            },
            "ResourceGroupName": {
                "Hide": true
            },
            "StorageAccountName": {
                "Hide": true
            },
            "StorageAccountLocation": {
                "Hide": true
            },
            "StorageAccountSku": {
                "Hide": true
            },
            "QueryMfaState": {
                "Select" : {
                    "Options": [
                        {
                            "Display": "Check and report every admin's MFA state",
                            "Value": true
                        },
                        {
                            "Display": "Do not check admin MFA states",
                            "Value": false,                        
                            "Customization": {
                                "Hide": [
                                    "TrustEmailMfa",
                                    "TrustPhoneMfa",
                                    "TrustSoftwareOathMfa",
                                    "TrustWinHelloMFA"
                                ]
                            }
                        }
                    ]
                }
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Export Admin-to-Role Report to Az Storage Account?" } )]
    [bool] $exportToFile = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "ListAdminsReport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "ListAdminsReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "ListAdminsReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "ListAdminsReport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "ListAdminsReport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Check every admin's MFA state" } )]
    [bool]$QueryMfaState = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Regard eMail as a valid MFA Method" } )]
    [bool]$TrustEmailMfa = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Regard Phone/SMS as a valid MFA Method" } )]
    [bool]$TrustPhoneMfa = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Regard Software OATH Token as a valid MFA Method" } )]
    [bool]$TrustSoftwareOathMfa = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Regard Win. Hello f.B. as a valid MFA Method" } )]
    [bool]$TrustWinHelloMFA = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

## Get builtin AzureAD Roles
$roles = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleDefinitions" -OdFilter "isBuiltIn eq true" -FollowPaging

if ([array]$roles.count -eq 0) {
    "## Error - No AzureAD roles found. Missing permissions?"
    throw("no roles found")
}

## Performance issue - Get all role assignments at once
$allRoleHolders = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleAssignments" -FollowPaging -ErrorAction SilentlyContinue
$allPimHolders = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleEligibilitySchedules" -Beta -FollowPaging -ErrorAction SilentlyContinue

$AdminUsers = @()

$roles | ForEach-Object {
    $roleDefinitionId = $_.id
    $pimHolders = $allPimHolders | Where-Object { $_.roleDefinitionId -eq $roleDefinitionId }
    $roleHolders = $allRoleHolders | Where-Object { $_.roleDefinitionId -eq $roleDefinitionId }

    if ((([array]$roleHolders).count -gt 0) -or (([array]$pimHolders).count -gt 0)) {
        "## Role: $($_.displayName)"
        "## - Active Assignments"

        $roleHolders | ForEach-Object {
            $principal = Invoke-RjRbRestMethodGraph -Resource "/directoryObjects/$($_.principalId)" -ErrorAction SilentlyContinue
            if (-not $principal) {
                "  $($_.principalId) (Unknown principal)"
            }
            else {
                if ($principal."@odata.type" -eq "#microsoft.graph.user") {
                    "  $($principal.userPrincipalName)"
                    if (-not $AdminUsers.Contains($principal.userPrincipalName)) {
                        $AdminUsers += $principal.userPrincipalName
                    }
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.servicePrincipal") {
                    "  $($principal.displayName) (ServicePrincipal)"
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.group") {
                    "  $($principal.displayName) (Group)"
                }
                else {
                    "  $($principal.displayName) $($principal."@odata.type")"
                }
            }
        }

        "## - PIM eligbile"

        $pimHolders | ForEach-Object {
            $principal = Invoke-RjRbRestMethodGraph -Resource "/directoryObjects/$($_.principalId)" -ErrorAction SilentlyContinue
            if (-not $principal) {
                "  $($_.principalId) (Unknown principal)"
            }
            else {
                if ($principal."@odata.type" -eq "#microsoft.graph.user") {
                    "  $($principal.userPrincipalName)"
                    if (-not $AdminUsers.Contains($principal.userPrincipalName)) {
                        $AdminUsers += $principal.userPrincipalName
                    }
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.servicePrincipal") {
                    "  $($principal.displayName) (ServicePrincipal)"
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.group") {
                    "  $($principal.displayName) (Group)"
                }
                else {
                    "  $($principal.displayName) $($principal."@odata.type")"
                }
            }
        }


        ""
    }

}

if ($exportToFile) {
    if ((-not $StorageAccountName) -or (-not $StorageAccountLocation) -or (-not $StorageAccountSku) -or (-not $ResourceGroupName)) {
        $exportToFile = $false
        "## AZ Storage configuration incomplete, will not export to AZ Storage."
        "## Make sure StorageAccountName, StorageAccountLocation, StorageAccountSku, ResourceGroupName are set."
    }
}

if ($exportToFile) {
    $filename = "AdminRoleOverview.csv"
    [string]$output = "UPN,"
    $roles | ForEach-Object {
        $output += $_.displayName + ";"
    }
    $output > $filename

    $AdminUsers | ForEach-Object {
        $AdminUPN = $_
        $AdminObject = Invoke-RjRbRestMethodGraph -Resource "/users/$AdminUPN"
        [string]$output = $AdminUPN + ";"
        $roles | ForEach-Object {
            $roleDefinitionId = $_.id
            if ($allRoleHolders | Where-Object { ($_.roleDefinitionId -eq $roleDefinitionId) -and ($_.principalId -eq $AdminObject.id) }) {
                $output += "x;"
            }
            elseif ($allPimHolders | Where-Object { ($_.roleDefinitionId -eq $roleDefinitionId) -and ($_.principalId -eq $AdminObject.id) }) {
                $output += "p;"
            }
            else {
                $output += ";"
            }
        }
        $output >> $filename
    }
    $content = Get-Content $filename
    set-content -Path $filename -Value $content -Encoding utf8

    Connect-RjRbAzAccount
  
    if (-not $ContainerName) {
        $ContainerName = "adminoverview-" + (get-date -Format "yyyy-MM-dd")
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
   
    Set-AzStorageBlobContent -File $filename -Container $ContainerName -Blob $_.Name -Context $context -Force | Out-Null

    #Create signed (SAS) link
    $EndTime = (Get-Date).AddDays(6)
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $filename -FullUri -ExpiryTime $EndTime
    "## $filename"
    " $SASLink"
    ""
    "## upload of CSVs successful."
    "## Expiry of Links: $EndTime"
}

if ($QueryMfaState) {
    ""
    "## MFA State of each Admin:"
    $NoMFAAdmins = @()
    $AdminUsers | Sort-Object -Unique | ForEach-Object {
        $AdminUPN = $_
        $AuthenticationMethods = @()
        [array]$MFAData = Invoke-RjRbRestMethodGraph -Resource "/users/$AdminUPN/authentication/methods"
        foreach ($MFA in $MFAData) { 
            Switch ($MFA."@odata.type") { 
                "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                    $AuthenticationMethods += "- MS Authenticator App"
                }
                "#microsoft.graph.phoneAuthenticationMethod" {
                    if ($TrustPhoneMfa) {
                        $AuthenticationMethods += "- Phone authentication"
                    } 
                }
                "#microsoft.graph.fido2AuthenticationMethod" {
                    $AuthenticationMethods += "- FIDO2 key"
                }  
                "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                    if ($TrustWinHelloMFA) {
                        $AuthenticationMethods += "- Windows Hello"
                    }                        
                }
                "#microsoft.graph.emailAuthenticationMethod" {
                    if ($TrustEmailMfa) {
                        $AuthenticationMethods += "- Email Authentication"
                    }
                }               
                "#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod" {
                    $AuthenticationMethods += "- MS Authenticator App (passwordless)"
                }      
                "#microsoft.graph.softwareOathAuthenticationMethod" { 
                    if ($TrustSoftwareOathMfa) {
                        $AuthenticationMethods += "- SoftwareOath"          
                    }
                }
            }
        }
        if ($AuthenticationMethods.count -eq 0) {
            $NoMFAAdmins += $AdminUPN
        }
        else {
            "'$AdminUPN':"
            $AuthenticationMethods | Sort-Object -Unique
            ""
        }
    }

    if ($NoMFAAdmins.count -ne 0) {
        ""
        "## Admins without valid MFA:"
        $NoMFAAdmins | Sort-Object -Unique
    }
}


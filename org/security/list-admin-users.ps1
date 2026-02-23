<#
    .SYNOPSIS
    List Entra ID role holders and optionally evaluate their MFA methods

    .DESCRIPTION
    Lists users and service principals holding built-in Entra ID roles and produces an admin-to-role report. Optionally queries each admin for registered authentication methods to assess MFA coverage.

    .PARAMETER ExportToFile
    If set to true, exports the report to an Azure Storage Account.

    .PARAMETER PimEligibleUntilInCSV
    If set to true, includes PIM eligible until information in the CSV report.

    .PARAMETER ContainerName
    Name of the Azure Storage container to upload the CSV report to.

    .PARAMETER ResourceGroupName
    Name of the Azure Resource Group containing the Storage Account.

    .PARAMETER StorageAccountName
    Name of the Azure Storage Account used for upload.

    .PARAMETER StorageAccountLocation
    Azure region for the Storage Account if it needs to be created.

    .PARAMETER StorageAccountSku
    SKU name for the Storage Account if it needs to be created.

    .PARAMETER QueryMfaState
    "Check and report every admin's MFA state" (final value: $true) or "Do not check admin MFA states" (final value: $false) can be selected as action to perform.

    .PARAMETER TrustEmailMfa
    If set to true, regards email as a valid MFA method.

    .PARAMETER TrustPhoneMfa
    If set to true, regards phone/SMS as a valid MFA method.

    .PARAMETER TrustSoftwareOathMfa
    If set to true, regards software OATH token as a valid MFA method.

    .PARAMETER TrustWinHelloMFA
    If set to true, regards Windows Hello for Business as a valid MFA method.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

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
                "Select": {
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1" }

param(
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Export Admin-to-Role Report to Az Storage Account?" } )]
    [bool] $ExportToFile = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Include PIM eligible until date in CSV" } )]
    [bool] $PimEligibleUntilInCSV = $false,
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

############################################################
#region RJ Log Part
############################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "ExportToFile: $ExportToFile" -Verbose
Write-RjRbLog -Message "PimEligibleUntilInCSV: $PimEligibleUntilInCSV" -Verbose
Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
Write-RjRbLog -Message "StorageAccountLocation: $StorageAccountLocation" -Verbose
Write-RjRbLog -Message "StorageAccountSku: $StorageAccountSku" -Verbose
Write-RjRbLog -Message "QueryMfaState: $QueryMfaState" -Verbose
Write-RjRbLog -Message "TrustEmailMfa: $TrustEmailMfa" -Verbose
Write-RjRbLog -Message "TrustPhoneMfa: $TrustPhoneMfa" -Verbose
Write-RjRbLog -Message "TrustSoftwareOathMfa: $TrustSoftwareOathMfa" -Verbose
Write-RjRbLog -Message "TrustWinHelloMFA: $TrustWinHelloMFA" -Verbose

#endregion RJ Log Part

############################################################
#region Functions
############################################################

#region Helper Functions
##############################

function Get-AllGraphPage {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Get-AllGraphPage takes an initial Microsoft Graph API URI and retrieves all items across
        multiple pages by following the @odata.nextLink property in the response. It aggregates
        all items into a single array and returns it.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/applications".

        .EXAMPLE
        PS C:\> $allApps = Get-AllGraphPage -Uri "https://graph.microsoft.com/v1.0/applications"
#>
    param(
        [string]$Uri
    )

    $allResults = @()
    $nextLink = $Uri

    do {
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET

        if ($response.value) {
            $allResults += $response.value
        }
        elseif ($response.'@odata.context') {
            # Single item response
            $allResults += $response
        }

        if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
            $nextLink = $response.'@odata.nextLink'
        }
        else {
            $nextLink = $null
        }
    } while ($nextLink)

    return $allResults
}

#endregion Helper Functions

#endregion Functions

############################################################
#region Connect Part
############################################################

Write-Output "Connecting to Microsoft Graph..."

try {
    $mgContext = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $mgContext) {
        Connect-MgGraph -Identity -ContextScope Process -NoWelcome -ErrorAction Stop | Out-Null
    }
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the runbook identity has the required Graph permissions and Microsoft.Graph.Authentication is available." -ErrorAction Continue
    throw
}

#endregion Connect Part

############################################################
#region Data Collection
############################################################

## Get builtin AzureAD Roles
$roles = Get-AllGraphPage -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?`$filter=isBuiltIn eq true"

if ([array]$roles.count -eq 0) {
    "## Error - No AzureAD roles found. Missing permissions?"
    throw("no roles found")
}

## Performance issue - Get all role assignments at once
try {
    $allRoleHolders = Get-AllGraphPage -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments"
}
catch {
    $allRoleHolders = @()
}

try {
    $allPimHolders = Get-AllGraphPage -Uri "https://graph.microsoft.com/beta/roleManagement/directory/roleEligibilitySchedules"
}
catch {
    $allPimHolders = @()
}

$getPimEligibleUntilText = {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Schedules
    )

    if (-not $Schedules -or $Schedules.Count -eq 0) {
        return $null
    }

    $expirationTypes = $Schedules | ForEach-Object { $_.scheduleInfo.expiration.type }
    if ($expirationTypes -contains 'noExpiration') {
        return 'Permanent'
    }

    $endDates = @()
    $maxDays = $null

    foreach ($schedule in $Schedules) {
        $expiration = $schedule.scheduleInfo.expiration
        $expirationType = $expiration.type

        if ($expirationType -eq 'endDateTime' -and $expiration.endDateTime) {
            try {
                $endDates += [datetime]$expiration.endDateTime
            }
            catch {
            }
            continue
        }

        if ($schedule.endDateTime) {
            try {
                $endDates += [datetime]$schedule.endDateTime
            }
            catch {
            }
            continue
        }

        if ($expirationType -eq 'afterDuration' -and $expiration.duration) {
            $durationText = [string]$expiration.duration
            $startText = $schedule.scheduleInfo.startDateTime
            if (-not $startText) {
                $startText = $schedule.startDateTime
            }

            if ($startText) {
                try {
                    $timeSpan = [System.Xml.XmlConvert]::ToTimeSpan($durationText)
                    $endDates += ([datetime]$startText).Add($timeSpan)
                    continue
                }
                catch {
                }

                if ($durationText -match '^P(?<days>\d+)D$') {
                    $endDates += ([datetime]$startText).AddDays([int]$Matches.days)
                    continue
                }
            }

            if ($durationText -match '^P(?<days>\d+)D$') {
                $days = [int]$Matches.days
                if ($null -eq $maxDays -or $days -gt $maxDays) {
                    $maxDays = $days
                }
                continue
            }
        }
    }

    if ($endDates.Count -gt 0) {
        $latest = $endDates | Sort-Object | Select-Object -Last 1
        return (Get-Date $latest -Format 'yyyy-MM-dd')
    }

    if ($null -ne $maxDays) {
        if ($maxDays -eq 1) {
            return 'in 1 day'
        }
        return "in $maxDays days"
    }

    return 'Unknown'
}

$pimEligibleUntilByPrincipalRole = @{}

if ($allPimHolders -and ([array]$allPimHolders).Count -gt 0) {
    $allPimHolders | Group-Object -Property { "$($_.principalId)|$($_.roleDefinitionId)" } | ForEach-Object {
        $key = $_.Name
        $value = & $getPimEligibleUntilText $_.Group
        if ($value) {
            $pimEligibleUntilByPrincipalRole[$key] = $value
        }
    }
}

$AdminUsers = @{}

$roles | ForEach-Object {
    $roleDefinitionId = $_.id
    $pimHolders = $allPimHolders | Where-Object { $_.roleDefinitionId -eq $roleDefinitionId }
    $roleHolders = $allRoleHolders | Where-Object { $_.roleDefinitionId -eq $roleDefinitionId }

    if ((([array]$roleHolders).count -gt 0) -or (([array]$pimHolders).count -gt 0)) {
        "## Role: $($_.displayName)"
        "## - Active Assignments"

        $roleHolders | ForEach-Object {
            try {
                $principal = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/directoryObjects/$($_.principalId)" -Method GET -OutputType PSObject -ErrorAction Stop
            }
            catch {
                $principal = $null
            }
            if (-not $principal) {
                "  $($_.principalId) (Unknown principal)"
            }
            else {
                if ($principal."@odata.type" -eq "#microsoft.graph.user") {
                    "  $($principal.userPrincipalName)"
                    if (-not $AdminUsers.ContainsKey($principal.id)) {
                        $AdminUsers[$principal.id] = $principal.userPrincipalName
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

        $pimHolders | Group-Object -Property principalId | ForEach-Object {
            $principalId = $_.Name
            $eligibleUntilText = & $getPimEligibleUntilText $_.Group
            $eligibleSuffix = " (PIM eligible until: $eligibleUntilText)"

            try {
                $principal = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/directoryObjects/$principalId" -Method GET -OutputType PSObject -ErrorAction Stop
            }
            catch {
                $principal = $null
            }

            if (-not $principal) {
                "  $principalId (Unknown principal)$eligibleSuffix"
            }
            else {
                if ($principal."@odata.type" -eq "#microsoft.graph.user") {
                    "  $($principal.userPrincipalName)$eligibleSuffix"
                    if (-not $AdminUsers.ContainsKey($principal.id)) {
                        $AdminUsers[$principal.id] = $principal.userPrincipalName
                    }
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.servicePrincipal") {
                    "  $($principal.displayName) (ServicePrincipal)$eligibleSuffix"
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.group") {
                    "  $($principal.displayName) (Group)$eligibleSuffix"
                }
                else {
                    "  $($principal.displayName) $($principal."@odata.type")$eligibleSuffix"
                }
            }
        }


        ""
    }

}

#endregion Data Collection

############################################################
#region Output/Export
############################################################

if ($exportToFile) {
    if ((-not $StorageAccountName) -or (-not $StorageAccountLocation) -or (-not $StorageAccountSku) -or (-not $ResourceGroupName)) {
        $exportToFile = $false
        "## AZ Storage configuration incomplete, will not export to AZ Storage."
        "## Make sure StorageAccountName, StorageAccountLocation, StorageAccountSku, ResourceGroupName are set."
    }
}

if ($exportToFile) {
    $filename = "AdminRoleOverview.csv"
    [string]$output = "UPN;"
    $roles | ForEach-Object {
        $output += $_.displayName + ";"
        if ($pimEligibleUntilInCSV) {
            $output += ($_.displayName + "_PIMEligibleUntil;")
        }
    }
    $output > $filename

    $AdminUsers.GetEnumerator() | Sort-Object -Property Value | ForEach-Object {
        $AdminId = $_.Key
        $AdminUPN = $_.Value
        [string]$output = $AdminUPN + ";"
        $roles | ForEach-Object {
            $roleDefinitionId = $_.id
            if ($allRoleHolders | Where-Object { ($_.roleDefinitionId -eq $roleDefinitionId) -and ($_.principalId -eq $AdminId) }) {
                $output += "x;"
            }
            elseif ($pimEligibleUntilByPrincipalRole.ContainsKey("$AdminId|$roleDefinitionId")) {
                $output += "p;"
            }
            else {
                $output += ";"
            }

            if ($pimEligibleUntilInCSV) {
                $key = "$AdminId|$roleDefinitionId"
                if ($pimEligibleUntilByPrincipalRole.ContainsKey($key)) {
                    $output += ($pimEligibleUntilByPrincipalRole[$key] + ";")
                }
                else {
                    $output += ";"
                }
            }
        }
        $output >> $filename
    }
    $content = Get-Content $filename
    Set-Content -Path $filename -Value $content -Encoding utf8

    Connect-RjRbAzAccount

    if (-not $ContainerName) {
        $ContainerName = "adminoverview-" + (Get-Date -Format "yyyy-MM-dd")
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

#endregion Output/Export

############################################################
#region Main Part
############################################################

if ($QueryMfaState) {
    ""
    "## MFA State of each Admin:"
    $NoMFAAdmins = @()
    $AdminUsers.GetEnumerator() | Sort-Object -Property Value | ForEach-Object {
        $AdminId = $_.Key
        $AdminUPN = $_.Value
        $AuthenticationMethods = @()
        [array]$MFAData = Get-AllGraphPage -Uri "https://graph.microsoft.com/v1.0/users/$AdminId/authentication/methods"
        foreach ($MFA in $MFAData) {
            switch ($MFA."@odata.type") {
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

#endregion Main Part


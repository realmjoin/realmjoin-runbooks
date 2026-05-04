<#
    .SYNOPSIS
    Export a CSV of all (enterprise) application owners and users

    .DESCRIPTION
    This runbook exports a CSV report of enterprise applications (or all service principals) including owners and assigned users or groups.
    It uploads the generated CSV file to an Azure Storage Account and returns a time-limited download link.

    .PARAMETER entAppsOnly
    Determines whether to export only enterprise applications (final value: true) or all service principals/applications (final value: false).

    .PARAMETER ContainerName
    Storage container name used for the upload.

    .PARAMETER ResourceGroupName
    Resource group that contains the storage account.

    .PARAMETER StorageAccountName
    Storage account name used for the upload.

    .PARAMETER LinkExpiryDays
    Number of days until the generated download link expires.

    .PARAMETER CallerName
    Caller name for auditing purposes.

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
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param(
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "List only Enterprise Apps" } )]
    [bool] $entAppsOnly = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EntAppsReport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EntAppsReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EntAppsReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EntAppsReport.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

function Publish-RjRbFilesToStorageContainer {
    <#
        .SYNOPSIS
        Upload one or more local files to an Azure Storage container, returning SAS
        download links.

        .DESCRIPTION
        Performs blob upload and SAS token generation using the Azure Storage REST API
        directly, avoiding the Az.Storage module entirely. This eliminates the well-known
        assembly conflict between Az.Storage and ExchangeOnlineManagement.

        Storage account keys are retrieved via ARM REST API (Invoke-AzRestMethod from
        Az.Accounts). Blob operations (container creation, upload, SAS generation) use
        the Azure Storage REST API with SharedKey authentication.

        Required Azure RBAC on the storage account:
        - Microsoft.Storage/storageAccounts/read
        - Microsoft.Storage/storageAccounts/listKeys/action
        Built-in role: 'Storage Account Contributor'.

        .PARAMETER FilePaths
        Array of local file paths to upload.

        .PARAMETER ContainerName
        Target blob container. Created automatically if missing.

        .PARAMETER ResourceGroupName
        Resource group containing the storage account.

        .PARAMETER StorageAccountName
        Target storage account name.

        .PARAMETER SubscriptionId
        Optional Azure subscription ID. Sets context before storage operations.

        .PARAMETER LinkExpiryDays
        SAS link validity in days (default 6, range 1-3650).

        .PARAMETER AddBlobNamePrefix
        When $true, prefixes blob names with yyyyMMdd-HHmmss (default $false).

        .OUTPUTS
        Array of PSCustomObject with BlobName, EndTime, SASLink for each uploaded file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string[]] $FilePaths,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $ContainerName,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $ResourceGroupName,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $StorageAccountName,
        [Parameter(Mandatory = $false)][string] $SubscriptionId,
        [Parameter(Mandatory = $false)][ValidateRange(1, 3650)][int] $LinkExpiryDays = 6,
        [Parameter(Mandatory = $false)][bool] $AddBlobNamePrefix = $false
    )

    foreach ($p in $FilePaths) {
        if (-not (Test-Path -Path $p -PathType Leaf)) {
            throw "File '$p' was not found."
        }
    }

    # Ensure Az context is connected
    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if ((-not $azContext) -or (-not $azContext.Account)) {
        Connect-RjRbAzAccount
    }
    if ($SubscriptionId) { Set-AzContext -Subscription $SubscriptionId | Out-Null }

    # Get storage account key via ARM REST API
    $subscriptionId = (Get-AzContext).Subscription.Id
    $armPath = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName/listKeys?api-version=2023-05-01"
    $keysResponse = Invoke-AzRestMethod -Path $armPath -Method POST
    if ($keysResponse.StatusCode -ne 200) {
        throw "Failed to retrieve storage account keys for '$StorageAccountName' in resource group '$ResourceGroupName'. Status: $($keysResponse.StatusCode)"
    }
    $storageKey = ($keysResponse.Content | ConvertFrom-Json).keys[0].value
    $keyBytes = [Convert]::FromBase64String($storageKey)

    # Helper: Generate SharedKey Authorization header
    function Get-StorageAuthHeader {
        param([string]$Method, [string]$CanonicalizedResource, [hashtable]$Headers, [string]$ContentType = "", [int]$ContentLength = 0)

        $rfcDate = $Headers["x-ms-date"]
        $msHeaders = ($Headers.GetEnumerator() | Where-Object { $_.Key -like "x-ms-*" } | Sort-Object Key | ForEach-Object { "$($_.Key):$($_.Value)" }) -join "`n"

        $contentLengthStr = if ($ContentLength -gt 0) { "$ContentLength" } else { "" }

        $stringToSign = "$Method`n`n`n$contentLengthStr`n`n$ContentType`n`n`n`n`n`n`n$msHeaders`n$CanonicalizedResource"

        $hmac = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key = $keyBytes
        $sig = [Convert]::ToBase64String($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))
        return "SharedKey ${StorageAccountName}:$sig"
    }

    # Helper: Generate Blob SAS token
    function New-BlobSasToken {
        param([string]$Container, [string]$Blob, [datetime]$ExpiryTime)

        $startTime = (Get-Date).ToUniversalTime().AddMinutes(-5).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $expiryStr = $ExpiryTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $permissions = "r"
        $signedVersion = "2023-11-03"
        $signedResource = "b"
        $signedProtocol = "https"

        # StringToSign for Blob SAS
        $canonicalizedResource = "/blob/$StorageAccountName/$Container/$Blob"
        $stringToSign = "$permissions`n$startTime`n$expiryStr`n$canonicalizedResource`n`n`n$signedProtocol`n$signedVersion`n$signedResource`n`n`n`n`n`n`n"

        $hmac = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key = $keyBytes
        $sig = [Convert]::ToBase64String($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))

        $sasToken = "sp=$permissions&st=$startTime&se=$expiryStr&spr=$signedProtocol&sv=$signedVersion&sr=$signedResource&sig=$([Uri]::EscapeDataString($sig))"
        return "https://$StorageAccountName.blob.core.windows.net/$Container/${Blob}?$sasToken"
    }

    $baseUri = "https://$StorageAccountName.blob.core.windows.net"

    # Create container if it does not exist (using HttpClient to bypass Azure Automation's
    # Invoke-RestMethod interceptor that strips required headers)
    $dateStr = [DateTime]::UtcNow.ToString("R")
    $containerHeaders = @{
        "x-ms-date"    = $dateStr
        "x-ms-version" = "2023-11-03"
    }
    $canonResource = "/$StorageAccountName/$ContainerName`nrestype:container"
    $containerHeaders["Authorization"] = Get-StorageAuthHeader -Method "PUT" -CanonicalizedResource $canonResource -Headers $containerHeaders

    $httpClient = [System.Net.Http.HttpClient]::new()
    try {
        $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Put, "$baseUri/$ContainerName`?restype=container")
        foreach ($h in $containerHeaders.GetEnumerator()) {
            $request.Headers.TryAddWithoutValidation($h.Key, $h.Value) | Out-Null
        }
        $response = $httpClient.SendAsync($request).GetAwaiter().GetResult()
        $statusCode = [int]$response.StatusCode
        if ($statusCode -ne 201 -and $statusCode -ne 409) {
            $errBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            throw "Container creation failed ($statusCode): $errBody"
        }
    }
    finally {
        $httpClient.Dispose()
    }

    # Upload files and generate SAS links
    $endTime = (Get-Date).AddDays($LinkExpiryDays)
    $results = @()
    foreach ($filePath in $FilePaths) {
        $blobName = Split-Path -Path $filePath -Leaf
        if ($AddBlobNamePrefix) {
            $prefix = (Get-Date).ToString("yyyyMMdd-HHmmss")
            $blobName = "$prefix-$blobName"
        }

        $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
        $contentLength = $fileBytes.Length

        $dateStr = [DateTime]::UtcNow.ToString("R")
        $blobHeaders = @{
            "x-ms-date"      = $dateStr
            "x-ms-version"   = "2023-11-03"
            "x-ms-blob-type" = "BlockBlob"
        }
        $canonResource = "/$StorageAccountName/$ContainerName/$blobName"
        $blobHeaders["Authorization"] = Get-StorageAuthHeader -Method "PUT" -CanonicalizedResource $canonResource -Headers $blobHeaders -ContentType "application/octet-stream" -ContentLength $contentLength

        # Use HttpClient directly to ensure all custom headers (x-ms-blob-type) are sent.
        # Invoke-RestMethod in hosted PowerShell can strip custom headers with binary bodies.
        $httpClient = [System.Net.Http.HttpClient]::new()
        try {
            $content = [System.Net.Http.ByteArrayContent]::new($fileBytes)
            $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::new("application/octet-stream")
            $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Put, "$baseUri/$ContainerName/$blobName")
            $request.Content = $content
            foreach ($h in $blobHeaders.GetEnumerator()) {
                $request.Headers.TryAddWithoutValidation($h.Key, $h.Value) | Out-Null
            }
            $response = $httpClient.SendAsync($request).GetAwaiter().GetResult()
            if (-not $response.IsSuccessStatusCode) {
                $errBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                throw "Blob upload failed ($($response.StatusCode)): $errBody"
            }
        }
        finally {
            $httpClient.Dispose()
        }

        $sasLink = New-BlobSasToken -Container $ContainerName -Blob $blobName -ExpiryTime $endTime
        $results += [PSCustomObject]@{ BlobName = $blobName; EndTime = $endTime; SASLink = $sasLink }
    }
    return $results
}

if (-not $ContainerName) {
    $ContainerName = "enterprise-apps-users"
}

Connect-RjRbGraph
Connect-RjRbAzAccount

try {
    # Configuration import - fallback to Az Automation Variable
    if ((-not $ResourceGroupName) -or (-not $StorageAccountName)) {
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

        #endregion
    }

    if ((-not $ResourceGroupName) -or (-not $StorageAccountName)) {
        "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
        "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
        ""
        "## Configure the following attributes:"
        "## - EntAppsReport.ResourceGroup"
        "## - EntAppsReport.StorageAccount.Name"
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

    $uploadResults = Publish-RjRbFilesToStorageContainer `
        -FilePaths @("enterpriseApps.csv") `
        -ContainerName $ContainerName `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -LinkExpiryDays $LinkExpiryDays `
        -AddBlobNamePrefix $true

    $uploadResult = $uploadResults[0]
    "## App Owner/User List Export created."
    "## Expiry of Link: $($uploadResult.EndTime)"
    $uploadResult.SASLink | Out-String

}
catch {
    throw $_
}
finally {
    Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
}
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

function Publish-RjRbFileToStorageContainer {
    <#
        .SYNOPSIS
        Upload a local file to an Azure Storage container and create a SAS download link

        .DESCRIPTION
        This helper uploads a file to a blob container in an existing Azure Storage Account. It can automatically prepend
        a prefix to the blob name to reduce overwrite risk. The prefix can either be a timestamp in 24-hour format or an
        alphanumeric random string.

        .PARAMETER FilePath
        Full or relative path to the local file that should be uploaded.

        .PARAMETER BlobName
        Target blob name inside the container. If omitted, the local file name is used.

        .PARAMETER ContainerName
        Blob container name where the file is uploaded.

        .PARAMETER ResourceGroupName
        Resource group containing the target Storage Account.

        .PARAMETER StorageAccountName
        Name of the target Storage Account.

        .PARAMETER LinkExpiryDays
        Number of days until the generated SAS link expires.

        .PARAMETER AddBlobNamePrefix
        When true, adds a prefix to the blob name before upload.

        .PARAMETER UseRandomPrefix
        When used together with AddBlobNamePrefix, a 6-character alphanumeric prefix is used instead of a timestamp prefix.

        .OUTPUTS
        PSCustomObject with upload metadata including final blob name, expiry time, and SAS link.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string] $BlobName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ContainerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $StorageAccountName,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 3650)]
        [int] $LinkExpiryDays = 6,

        [Parameter(Mandatory = $false)]
        [bool] $AddBlobNamePrefix = $true,

        [Parameter(Mandatory = $false)]
        [ValidateScript({
                if ($_ -and (-not $AddBlobNamePrefix)) {
                    throw "UseRandomPrefix cannot be used when AddBlobNamePrefix is set to false."
                }
                $true
            })]
        [switch] $UseRandomPrefix
    )

    $connectedByFunction = $false

    try {
        if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
            throw "File '$FilePath' was not found."
        }

        if (-not $BlobName) {
            $BlobName = Split-Path -Path $FilePath -Leaf
        }

        if ([string]::IsNullOrWhiteSpace($BlobName)) {
            throw "BlobName cannot be empty or whitespace."
        }

        if ($BlobName.Length -gt 1024) {
            throw "BlobName must not exceed 1024 characters."
        }

        if ($BlobName -match '[\\\x00-\x1F\x7F]') {
            throw "BlobName contains invalid characters."
        }

        if ($BlobName.EndsWith(".") -or $BlobName.EndsWith("/")) {
            throw "BlobName must not end with '.' or '/'."
        }

        if ($AddBlobNamePrefix) {
            if ($UseRandomPrefix) {
                $prefixChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                $prefix = -join (1..6 | ForEach-Object { $prefixChars[(Get-Random -Minimum 0 -Maximum $prefixChars.Length)] })
            }
            else {
                # Timestamp format: yyyyMMdd-HHmmss-
                $prefix = (Get-Date).ToString("yyyyMMdd-HHmmss")
            }

            $BlobName = "$prefix-$BlobName"
        }

        if ($BlobName.Length -gt 1024) {
            throw "Final BlobName must not exceed 1024 characters after prefixing."
        }

        $azContext = Get-AzContext -ErrorAction SilentlyContinue
        if ((-not $azContext) -or (-not $azContext.Account)) {
            Connect-RjRbAzAccount
            $connectedByFunction = $true

            $azContext = Get-AzContext -ErrorAction SilentlyContinue
            if ((-not $azContext) -or (-not $azContext.Account)) {
                throw "Connect-RjRbAzAccount did not produce a usable Azure context."
            }
        }

        # Make sure storage account exists
        $storAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
        if (-not $storAccount) {
            throw "Storage account '$StorageAccountName' in resource group '$ResourceGroupName' was not found."
        }

        # Get access to the Storage Account
        $keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop

        if ((-not $keys) -or (-not $keys[0].Value)) {
            throw "Could not retrieve a valid key for storage account '$StorageAccountName'."
        }

        $context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $keys[0].Value -ErrorAction Stop

        # Make sure container exists
        $container = Get-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction SilentlyContinue
        if (-not $container) {
            Write-Verbose "## Creating Azure Storage Account Container $($ContainerName)"
            try {
                $container = New-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction Stop
            }
            catch {
                # Handle race conditions from parallel runs creating the same container
                if ($_.Exception.Message -match 'ContainerAlreadyExists|already exists') {
                    $container = Get-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction SilentlyContinue
                }
                else {
                    throw
                }
            }
        }

        if (-not $container) {
            throw "Storage container '$ContainerName' is not available."
        }

        # Upload
        Set-AzStorageBlobContent -File $FilePath -Container $ContainerName -Blob $BlobName -Context $context -Force -ErrorAction Stop | Out-Null

        # Create signed (SAS) link
        $EndTime = (Get-Date).AddDays($LinkExpiryDays)
        $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $BlobName -FullUri -ExpiryTime $EndTime -ErrorAction Stop

        return [PSCustomObject]@{
            FilePath          = $FilePath
            BlobName          = $BlobName
            ContainerName     = $ContainerName
            StorageAccountName = $StorageAccountName
            EndTime           = $EndTime
            SASLink           = $SASLink
            ConnectedByFunction = $connectedByFunction
            AddBlobNamePrefix = $AddBlobNamePrefix
            UseRandomPrefix   = [bool]$UseRandomPrefix
            UploadSucceeded   = $true
        }
    }
    catch {
        throw "Failed to publish file '$FilePath' to container '$ContainerName'. Details: $($_.Exception.Message)"
    }
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

    $uploadResult = Publish-RjRbFileToStorageContainer `
        -FilePath "enterpriseApps.csv" `
        -BlobName "enterpriseApps.csv" `
        -ContainerName $ContainerName `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -LinkExpiryDays $LinkExpiryDays

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
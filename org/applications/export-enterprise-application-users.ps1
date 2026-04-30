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
#Requires -Modules @{ModuleName = "Az.Storage"; ModuleVersion = "9.6.0" }
#Requires -Modules @{ModuleName = "Microsoft.PowerShell.ThreadJob"; ModuleVersion = "2.2.0" }

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
        download links. Self-adapts to avoid the ExchangeOnlineManagement / Az.Storage
        assembly conflict.

        .DESCRIPTION
        Performs the actual upload via Az.Storage cmdlets. The execution path is
        selected automatically based on the current PowerShell session state:

        1. DIRECT PATH (fast, default for runbooks without Exchange Online):
           If ExchangeOnlineManagement is NOT loaded in the current session, all
           Az.Storage cmdlets run directly in-process. No job overhead.

        2. ISOLATED PATH (minimal overhead, only when needed):
           If ExchangeOnlineManagement IS loaded, all Az.Storage cmdlets are executed
           inside a single Start-ThreadJob ScriptBlock - a separate PowerShell runspace.

        Detection is done via Get-Module -Name ExchangeOnlineManagement, which returns
        the loaded module instance (or $null if not yet imported). The module being
        merely available in the runtime environment (Get-Module -ListAvailable) is NOT
        sufficient to trigger the isolated path - only an actual import does. This
        keeps the fast path active for runbooks that have EXO available but never use it.

        Why Start-ThreadJob instead of Start-Job?
        Start-Job spawns a new pwsh child process, which is NOT supported in hosted
        PowerShell environments (e.g. Azure Automation, Azure Functions). Start-ThreadJob
        uses a separate runspace within the same process, which is supported everywhere
        and avoids the startup cost of a new process.

        Authentication:
        Both paths authenticate via Connect-RjRbAzAccount. In Azure Automation, the
        managed identity is available within the same process to all runspaces.

        Required Azure RBAC on the storage account:
        - Microsoft.Storage/storageAccounts/read
        - Microsoft.Storage/storageAccounts/listKeys/action
        Built-in role: 'Storage Account Contributor'.

        .NOTES
        CALLING ORDER MATTERS in runbooks that use BOTH this function AND
        ExchangeOnlineManagement:

        The conflict between Az.Storage and ExchangeOnlineManagement is bidirectional.
        If this function takes the Direct Path (no EXO loaded yet), Az.Storage will be
        loaded into the current process. After that, ExchangeOnlineManagement CANNOT
        be loaded in the same session.

        Safe usage patterns:
          A) EXO first, then storage: Connect-RjRbExchangeOnline before this function
             -> isolation kicks in automatically.
          B) Storage only, no EXO in the runbook -> Direct Path is safe.
          C) Unsure / dynamic flow -> pass -ForceJobIsolation to opt into the isolated
             path regardless of session state.

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

        .PARAMETER ForceJobIsolation
        Optional switch. Forces the Start-ThreadJob isolated path even when EXO is not loaded.
        Useful when the runbook may load EXO later in its flow.

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
        [Parameter(Mandatory = $false)][bool] $AddBlobNamePrefix = $false,
        [Parameter(Mandatory = $false)][switch] $ForceJobIsolation
    )

    foreach ($p in $FilePaths) {
        if (-not (Test-Path -Path $p -PathType Leaf)) {
            throw "File '$p' was not found."
        }
    }

    $exoLoaded = $null -ne (Get-Module -Name ExchangeOnlineManagement)
    $useJob = $exoLoaded -or $ForceJobIsolation.IsPresent

    if ($useJob) {
        $reason = if ($ForceJobIsolation.IsPresent) { "ForceJobIsolation" } else { "EXO loaded" }
        Write-Verbose "Publish-RjRbFilesToStorageContainer: using Start-ThreadJob isolation (reason: $reason)."

        $job = Start-ThreadJob -ScriptBlock {
            param($FilePaths, $ContainerName, $ResourceGroupName, $StorageAccountName, $SubscriptionId, $LinkExpiryDays, $AddBlobNamePrefix)
            Import-Module RealmJoin.RunbookHelper -ErrorAction Stop
            Import-Module Az.Accounts -ErrorAction Stop
            Import-Module Az.Storage -ErrorAction Stop

            Connect-RjRbAzAccount
            if ($SubscriptionId) { Set-AzContext -Subscription $SubscriptionId | Out-Null }

            $storAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
            if (-not $storAccount) {
                throw "Storage account '$StorageAccountName' in resource group '$ResourceGroupName' was not found."
            }
            $keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop
            $context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $keys[0].Value -ErrorAction Stop

            $container = Get-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction SilentlyContinue
            if (-not $container) {
                try { $container = New-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction Stop }
                catch {
                    if ($_.Exception.Message -match 'ContainerAlreadyExists|already exists') {
                        $container = Get-AzStorageContainer -Name $ContainerName -Context $context
                    }
                    else { throw }
                }
            }

            $endTime = (Get-Date).AddDays($LinkExpiryDays)
            $results = @()
            foreach ($filePath in $FilePaths) {
                $blobName = Split-Path -Path $filePath -Leaf
                if ($AddBlobNamePrefix) {
                    $prefix = (Get-Date).ToString("yyyyMMdd-HHmmss")
                    $blobName = "$prefix-$blobName"
                }
                Set-AzStorageBlobContent -File $filePath -Container $ContainerName -Blob $blobName -Context $context -Force -ErrorAction Stop | Out-Null
                $sasLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $blobName -FullUri -ExpiryTime $endTime -ErrorAction Stop
                $results += [PSCustomObject]@{ BlobName = $blobName; EndTime = $endTime; SASLink = $sasLink }
            }
            return $results
        } -ArgumentList $FilePaths, $ContainerName, $ResourceGroupName, $StorageAccountName, $SubscriptionId, $LinkExpiryDays, $AddBlobNamePrefix

        try {
            Wait-Job -Job $job | Out-Null
            return Receive-Job -Job $job -ErrorAction Stop
        }
        finally {
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        Write-Verbose "Publish-RjRbFilesToStorageContainer: ExchangeOnlineManagement not loaded - using direct in-process path."

        $azContext = Get-AzContext -ErrorAction SilentlyContinue
        if ((-not $azContext) -or (-not $azContext.Account)) {
            Connect-RjRbAzAccount
        }
        if ($SubscriptionId) { Set-AzContext -Subscription $SubscriptionId | Out-Null }

        $storAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
        if (-not $storAccount) {
            throw "Storage account '$StorageAccountName' in resource group '$ResourceGroupName' was not found."
        }
        $keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop
        $context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $keys[0].Value -ErrorAction Stop

        $container = Get-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction SilentlyContinue
        if (-not $container) {
            try { $container = New-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction Stop }
            catch {
                if ($_.Exception.Message -match 'ContainerAlreadyExists|already exists') {
                    $container = Get-AzStorageContainer -Name $ContainerName -Context $context
                }
                else { throw }
            }
        }

        $endTime = (Get-Date).AddDays($LinkExpiryDays)
        $results = @()
        foreach ($filePath in $FilePaths) {
            $blobName = Split-Path -Path $filePath -Leaf
            if ($AddBlobNamePrefix) {
                $prefix = (Get-Date).ToString("yyyyMMdd-HHmmss")
                $blobName = "$prefix-$blobName"
            }
            Set-AzStorageBlobContent -File $filePath -Container $ContainerName -Blob $blobName -Context $context -Force -ErrorAction Stop | Out-Null
            $sasLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $blobName -FullUri -ExpiryTime $endTime -ErrorAction Stop
            $results += [PSCustomObject]@{ BlobName = $blobName; EndTime = $endTime; SASLink = $sasLink }
        }
        return $results
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
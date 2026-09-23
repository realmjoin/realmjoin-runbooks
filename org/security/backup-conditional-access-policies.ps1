<#
    .SYNOPSIS
    Back up all Conditional Access policies to Azure Storage

    .DESCRIPTION
    Exports every Conditional Access policy of the tenant as JSON and uploads them as one ZIP archive to an Azure Storage account. The backup lets you compare or restore policies later. Without a container name, a container named after the current date is used. Nothing is changed in the tenant.

    .PARAMETER ContainerName
    Storage container the archive is uploaded to. Taken from the tenant setting CaPoliciesExport.Container; empty means a container named after the current date.

    .PARAMETER ResourceGroupName
    Resource group of the storage account. Taken from the tenant setting CaPoliciesExport.ResourceGroup.

    .PARAMETER StorageAccountName
    Storage account for the backup. Taken from the tenant setting CaPoliciesExport.StorageAccount.Name.

    .PARAMETER StorageAccountLocation
    Azure region used when the storage account has to be created. Taken from the tenant setting CaPoliciesExport.StorageAccount.Location.

    .PARAMETER StorageAccountSku
    Performance tier used when the storage account has to be created. Taken from the tenant setting CaPoliciesExport.StorageAccount.Sku.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
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
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ ModuleName = "Az.Storage"; ModuleVersion = "9.7.2" }

param(
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "CaPoliciesExport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "CaPoliciesExport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "CaPoliciesExport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "CaPoliciesExport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "CaPoliciesExport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Write a JSON file from a Policy / group description object
function Export-PolicyObject {
    param (
        [Parameter(Mandatory = $true)]
        [array]$policies
    )

    $policies | ForEach-Object {
        $name = $_.displayName -replace "[$([RegEx]::Escape([string][IO.Path]::GetInvalidFileNameChars()))]+", "_"
        if (-not (Test-Path ($name + ".json"))) {
            $_ | ConvertTo-Json -Depth 6 > ($name + ".json")
        }
        else {
            "## Will not overwrite " + ($name + ".json") + ". Skipping."
        }

    }

}

if (-not $ContainerName) {
    $ContainerName = "conditional-policy-backup-" + (get-date -Format "yyyy-MM-dd")
}

try {

    # Configuration import - fallback to Az Automation Variable
    if ((-not $ResourceGroupName) -or (-not $StorageAccountName) -or (-not $StorageAccountLocation) -or (-not $StorageAccountSku)) {
        $processConfigRaw = Get-AutomationVariable -name "SettingsExports" -ErrorAction SilentlyContinue
        #if (-not $processConfigRaw) {
        ## production default
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
        "## To backup cond. access policies to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
        "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
        ""
        "## Configure the following attributes:"
        "## - CaPoliciesExport.ResourceGroup"
        "## - CaPoliciesExport.StorageAccount.Name"
        "## - CaPoliciesExport.StorageAccount.Location"
        "## - CaPoliciesExport.StorageAccount.Sku"
        ""
        "## Stopping execution."
        throw "Missing Storage Account Configuration."
    }

    Connect-RjRbGraph
    Connect-RjRbAzAccount

    # fetch the policies
    $pols = Invoke-RjRbRestMethodGraph -Resource "/identity/conditionalAccess/policies"

    # Write policy export as files
    mkdir "CAPols" | Out-Null
    Set-Location -Path "CAPols" | Out-Null
    Export-PolicyObject -policies $pols
    Set-Location -Path ".."  | Out-Null
    Compress-Archive -Path "CAPols\*" -DestinationPath "$ContainerName.zip" | Out-Null

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
        ""
    }

    # Upload

    ## Single file mode
    #$files = Get-ChildItem -Path $path
    #$files | ForEach-Object {
    #    Set-AzStorageBlobContent -File $_.FullName -Container $ContainerName -Blob $_.Name -Context $context -Force | Out-Null
    #}

    # Compressed Archive mode
    Set-AzStorageBlobContent -File "$ContainerName.zip" -Container $ContainerName -Blob "$ContainerName.zip" -Context $context -Force | Out-Null

    #Create signed (SAS) link
    $EndTime = (Get-Date).AddDays(6)
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob "$ContainerName.zip" -FullUri -ExpiryTime $EndTime


    "## Successfully created Conditional Access Export."
    "## Expiry of the Link: $EndTime"
    #$container.CloudBlobContainer.Uri.AbsoluteUri | Out-String
    $SASLink | Out-String

}
catch {
    throw $_
}
finally {
    Disconnect-AzAccount -Confirm:$false | Out-Null
}
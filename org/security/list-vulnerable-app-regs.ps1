<#
  .SYNOPSIS
  List all app registrations that suffer from the CVE-2021-42306 vulnerability.

  .DESCRIPTION
  List all app registrations that suffer from the CVE-2021-42306 vulnerability.

  .NOTES
  Permissions
   MS Graph (API): 
   - DeviceManagementManagedDevices.Read.All

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
        "CallerName": {
            "Hide": true
        },
        "ExportToFile": {
            "Select": {
                "Options": [
                    {
                        "Display": "Export to a CSV file",
                        "ParameterValue": true
                    },
                    {
                        "Display": "List in Console",
                        "ParameterValue": false,
                        "Customization": {
                            "Hide": [
                                "ContainerName",
                                "ResourceGroupName",
                                "StorageAccountName",
                                "StorageAccountLocation",
                                "StorageAccountSku"
                            ]
                        }
                    }
                ],
                "ShowValue": false
            }
        }
    }
}

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Save report to CSV file (instead of printing it to console)?" } )]
    [bool] $ExportToFile = $false,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "VulnAppRegExport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "VulnAppRegExport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "VulnAppRegExport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "VulnAppRegExport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "VulnAppRegExport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)


if (-not $ContainerName) {
    $ContainerName = "list-vulnerableappreg"
}

if ($ExportToFile -and ((-not $ResourceGroupName) -or (-not $StorageAccountName) -or (-not $StorageAccountSku) -or (-not $StorageAccountLocation))) {
    "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
    ""
    "## Configure the following attributes:"
    "## - VulnAppRegExport.ResourceGroup"
    "## - VulnAppRegExport.StorageAccount.Name"
    "## - VulnAppRegExport.StorageAccount.Location"
    "## - VulnAppRegExport.StorageAccount.Sku"
    ""
    "## Stopping execution."
    throw "Missing Storage Account Configuration."
}

Connect-RjRbGraph

"## AzureAD App. Registrations possibly vulnerable to CVE-2021-42306:"

$beforedate = "2021-12-06T00:00:00Z"
#$appregs = Invoke-RjRbRestMethodGraph -Resource "/applications" -OdSelect "displayName,id,appId,createdDateTime,keyCredentials" -OdFilter "createdDateTime ge $beforedate"
$appregs = Invoke-RjRbRestMethodGraph -Resource "/applications" -OdSelect "displayName,id,appId,createdDateTime,keyCredentials" -FollowPaging

$AffectedAppRegs = @()
foreach ($appreg in $appregs) {
    if ($appreg.displayName) {
        $DisplayName = $appreg.displayName
    }
    else {
        $DisplayName = "$(AppId) ($appreg.AppId)"
    }
    $appID = $appReg.AppId

    $ErrorActionPreference = 'SilentlyContinue'

    Write-RjRbLog "Trying - $displayName - $appId"
    foreach ($cred in $appReg.keyCredentials) {
        if ($cred.Key.Length -gt 2000) {

            $isBefore = $false
            $certResults = $null

            # Only interested in "old" credentials
            if (get-date($cred.startdate) -le get-date($beforedate)) {
                $isBefore = $true

                $outputBase = "$PWD\$appID"
                $outputFile = "$PWD\$appID.pfx"
                $iter = 1    
                while (Test-Path $outputFile) {                    
                    $outputFile = ( -join ($outputBase, '-', ([string]$iter), '.pfx'))
                    $iter += 1
                }
                Write-RjRbLog "Testing keyId $($cred.keyId)"
                [IO.File]::WriteAllBytes($outputFile, [Convert]::FromBase64String($cred.Key))
                $certResults = Get-PfxData $outputFile     
            }

            if (($null -ne $certResults) -and $isBefore) {
                if ($ExportToFile) {
                    Write-RjRbLog "`t$displayName - $appID - has a potentially vulnerable stored credentials"    
                }
                else {
                    "## $DisplayName - $appID - $appID - has a potentially vulnerable stored credentials"    
                }
                $AffectedAppRegs += "$displayName `t $appID" 
            }
            if (Test-Path $outputFile) {
                Remove-Item $outputFile | Out-Null
            }
        }
    }
}

if ($ExportToFile) {
    Connect-RjRbAzAccount
    try {
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
        $filename = "AffectedAppRegs.csv"
        $blobname = "$(get-date -Format yyyy-MM-dd)-AffectedAppRegs.csv"
        $AffectedAppRegs | ConvertTo-Csv > $filename
        Write-RjRbLog "Upload"
        Set-AzStorageBlobContent -File $fileName -Container $ContainerName -Blob $blobname -Context $context -Force | Out-Null

        $EndTime = (Get-Date).AddDays(6)
        $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $blobname -FullUri -ExpiryTime $EndTime

        "## Export of Vulnerable App registrations created."
        "## Expiry of Link: $EndTime"
        $SASLink | Out-String
    }
    catch {
        "## Upload of report failed. Please see log."
        ""
        $_
    }
}
<#
  .SYNOPSIS
  Create and export an Intune Policies 

  .DESCRIPTION
  List all devices and where they are registered.

  .NOTES
  Source: https://www.wpninjas.ch/2021/05/automatic-intune-documentation-evolves-to-automatic-microsoft365-documentation/
  Permissions
   MS Graph (API): 
   - AccessReview.Read.All
   - Agreement.Read.All
   - AppCatalog.Read.All
   - Application.Read.All
   - CloudPC.Read.All
   - ConsentRequest.Read.All
   - Device.Read.All 
   - DeviceManagementApps.Read.All
   - DeviceManagementConfiguration.Read.All
   - DeviceManagementManagedDevices.Read.All
   - DeviceManagementRBAC.Read.All
   - DeviceManagementServiceConfig.Read.All
   - Directory.Read.All
   - Domain.Read.All
   - Organization.Read.All
   - Policy.Read.All 
   - Policy.ReadWrite.AuthenticationMethod
   - Policy.ReadWrite.FeatureRollout
   - PrintConnector.Read.All 
   - Printer.Read.All
   - PrinterShare.Read.All 
   - PrintSettings.Read.All
   - PrivilegedAccess.Read.AzureAD
   - PrivilegedAccess.Read.AzureADGroup
   - PrivilegedAccess.Read.AzureResources
   - User.Read"

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

param(
    [string] $Components = "Intune",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneReport.Container" } )]
    [string] $ContainerName="intune-report",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneReport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "IntuneReport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku,
    [string] $CallerName
)

#Requires -Modules MSAL.PS, PSWriteWord, M365Documentation

"## Trying to create a M365Documentation Intune report."

if (-not $ContainerName) {
    $ContainerName = "intune-report"
}
$reportFileName = "$(get-date -Format yyyy-MM-dd)-M365Report.docx"

# "Getting Process configuration"
if ((-not $ResourceGroupName) -or (-not $StorageAccountName) -or (-not $StorageAccountLocation) -or (-not $StorageAccountSku)) {
    $processConfigRaw = Get-AutomationVariable -name "SettingsExports" -ErrorAction SilentlyContinue

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
}

if ((-not $ResourceGroupName) -or (-not $StorageAccountName) -or (-not $StorageAccountSku) -or (-not $StorageAccountLocation)) {
    "## To export to a storage account, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
    "## Alternatively, present values for ResourceGroup and StorageAccount when staring the runbook."
    ""
    "## Configure the following attributes:"
    "## - IntuneReport.ResourceGroup"
    "## - IntuneReport.StorageAccount.Name"
    "## - IntuneReport.StorageAccount.Location"
    "## - IntuneReport.StorageAccount.Sku"
    ""
    "## Stopping execution."
    throw "Missing Storage Account Configuration."
}

# MSAL.PS is finicky with the load order of modules. Beware.
# https://github.com/AzureAD/MSAL.PS/issues/45#issuecomment-1102100456
Write-RjRbLog "Import MSAL Module"
Import-Module MSAL.PS

# Use MSAL.PS to collect a token for MS Graph API
Write-RjRbLog "Authenticating MSAL"
$Conn = Get-AutomationConnection -Name "AzureRunAsConnection"
$Cert = Get-Item "Cert:\CurrentUser\My\$($Conn.CertificateThumbprint)"
$Token = Get-MsalToken -ClientId $Conn.ApplicationId -TenantId $Conn.TenantId -ClientCertificate $Cert

Write-RjRbLog "Import M365Documentation module"
Import-Module M365Documentation

Write-RjRbLog "Authenticating M365Documentation"
Connect-M365Doc -token $Token
mkdir report | Out-Null

Write-RjRbLog "Collecting Report"
# It will not report missing permissions, as SilentlyContinue is given. Make sure permissions are available. 
# See https://github.com/ThomasKur/M365Documentation/blob/main/AdvancedUsage.md#silent-execution-custom-app-registration
$doc = Get-M365Doc -Components $Components -ErrorAction SilentlyContinue
Write-RjRbLog "Writing Report"
$doc | Write-M365DocWord -FullDocumentationPath "$((Get-Location).Path)\report\$reportFileName"

try {
    Write-RjRbLog "Connecting AzureRM"
    Connect-RjRbAzAccount

    Write-RjRbLog "Get Storage Account"
    $storAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
    if (-not $storAccount) {
        "## Creating Azure Storage Account $($StorageAccountName)"
        $storAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $StorageAccountLocation -SkuName $StorageAccountSku 
    }
 
    Write-RjRbLog "Get StorageAccount Keys"
    # Get access to the Storage Account
    $keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    $context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $keys[0].Value

    Write-RjRbLog "Get Container"
    # Make sure, container exists
    $container = Get-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction SilentlyContinue
    if (-not $container) {
        "## Creating Azure Storage Account Container $($ContainerName)"
        $container = New-AzStorageContainer -Name $ContainerName -Context $context 
    }

    "## Upload report"
    Set-AzStorageBlobContent -File "report\$reportFileName" -Container $ContainerName -Blob $reportFileName -Context $context -Force | Out-Null

    Write-RjRbLog "Create Links"
    $EndTime = (Get-Date).AddDays(6)
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob $reportFileName -FullUri -ExpiryTime $EndTime

    "## M365Documentation Intune Export created."
    "## Expiry of Link: $EndTime"
    $SASLink | Out-String

    Disconnect-AzAccount -Confirm:$false | Out-Null
}
catch {
    $_
}


# https://gitlab.c4a8.net/modern-workplace-code/RJRunbookBacklog/-/issues/86

<#
  .SYNOPSIS
  List all AutoPilot Devices.

  .DESCRIPTION
  This runbook lists all AutoPilot devices with specified properties.

  .NOTES
  Permissions:
  MS Graph (API)
  - DeviceManagementServiceConfig.Read.All

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.0" }

param(
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [bool] $exportCsv = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.StorageAccount.Location" } )]
    [string] $StorageAccountLocation,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Setting -Attribute "EnrolledDevicesReport.StorageAccount.Sku" } )]
    [string] $StorageAccountSku
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

# Sanity checks for CSV export
if ($exportCsv -and ((-not $ResourceGroupName) -or (-not $StorageAccountLocation) -or (-not $StorageAccountName) -or (-not $StorageAccountSku))) {
  "## To export to a CSV, please use RJ Runbooks Customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) to specify an Azure Storage Account for upload."
  "## Please configure the following attributes in the RJ central datastore:"
  "## - EnrolledDevicesReport.ResourceGroup"
  "## - EnrolledDevicesReport.StorageAccount.Name"
  "## - EnrolledDevicesReport.StorageAccount.Location"
  "## - EnrolledDevicesReport.StorageAccount.Sku"
  "## Disabling CSV export."
  $exportCsv = $false
  ""
}

"Connecting to RJ Runbook Graph..."
Connect-RjRbGraph
"Connection established."

# Retrieve all Autopilot devices
"Retrieving all Autopilot devices..."
$autopilotDevices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -Beta -ErrorAction SilentlyContinue -FollowPaging

$deviceList = @()

if ($autopilotDevices) {
    foreach ($device in $autopilotDevices) {
        $deviceInfo = [PSCustomObject]@{
            Id                              = $device.id
            SerialNumber                    = $device.serialNumber
            GroupTag                        = $device.groupTag
            EnrollmentState                 = $device.enrollmentState
            DeploymentProfileAssignmentStatus = $device.deploymentProfileAssignmentStatus
            RemediationState                = $device.remediationState
            DeploymentProfileAssignmentDate = $device.deploymentProfileAssignedDateTime
            LastContactedDateTime           = $device.lastContactedDateTime
        }

        $deviceList += $deviceInfo

        "## Display device information"
        "Id: $($deviceInfo.Id)"
        "SerialNumber: $($deviceInfo.SerialNumber)"
        "GroupTag: $($deviceInfo.GroupTag)"
        "EnrollmentState: $($deviceInfo.EnrollmentState)"
        "DeploymentProfileAssignmentStatus: $($deviceInfo.DeploymentProfileAssignmentStatus)"
        "RemediationState: $($deviceInfo.RemediationState)"
        "DeploymentProfileAssignmentDate: $($deviceInfo.DeploymentProfileAssignmentDate)"
        "LastContactedDateTime: $($deviceInfo.LastContactedDateTime)"
        "-----------------------------"
    }
} else {
    "No AutoPilot devices found."
}

if ($exportCsv -and $deviceList.Count -gt 0) {
    "## Exporting data to CSV..."
    Connect-RjRbAzAccount

    if (-not $ContainerName) {
        $ContainerName = "autopilot-devices-" + (Get-Date -Format "yyyy-MM-dd")
    }

    $deviceList | ConvertTo-Csv -NoTypeInformation -Delimiter ";" | Set-Content -Path "autopilot-devices.csv" -Encoding UTF8

    # Ensure storage account exists
    $storAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
    if (-not $storAccount) {
        "## Creating Azure Storage Account $($StorageAccountName)"
        $storAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $StorageAccountLocation -SkuName $StorageAccountSku 
    }
 
    # Get access to the Storage Account
    $keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    $context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $keys[0].Value

    # Ensure container exists
    $container = Get-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction SilentlyContinue
    if (-not $container) {
        "## Creating Azure Storage Account Container $($ContainerName)"
        $container = New-AzStorageContainer -Name $ContainerName -Context $context 
    }
 
    # Upload CSV
    "## Uploading CSV to Azure Storage..."
    Set-AzStorageBlobContent -File "autopilot-devices.csv" -Container $ContainerName -Blob "autopilot-devices.csv" -Context $context -Force | Out-Null
 
    # Create signed (SAS) link
    $EndTime = (Get-Date).AddDays(6)
    $SASLink = New-AzStorageBlobSASToken -Permission "r" -Container $ContainerName -Context $context -Blob "autopilot-devices.csv" -FullUri -ExpiryTime $EndTime

    "## AutoPilot devices CSV report created."
    "## Expiry of Link: $EndTime"
    $SASLink | Out-String
}

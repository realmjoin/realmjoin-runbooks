<#
  .SYNOPSIS
  Write daily Windows 365 Utilization Data to Azure Tables

  .DESCRIPTION
  Write daily Windows 365 Utilization Data to Azure Tables. Will write data about the last full day.

  .NOTES
  Permissions: 
  MS Graph: CloudPC.Read.All
  StorageAccount: Contributor

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" },"Az.Storage","Az.Resources"

param(
    # CallerName is tracked purely for auditing purposes
    [string] $Table = 'CloudPCUsage',
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $StorageAccountName,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

function Get-StorageContext() {
    # Get access to the Storage Account
    try {
        $keys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
        New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $keys[0].Value
    }
    catch {
        "## Failed to get Az storage context." 
        ""
        $_
    }
}

function Get-StorageTables([array]$tables) {
    try {

        $storageTables = @{}
        $storageContext = Get-StorageContext

        $allTables = Get-AzStorageTable -Context $storageContext
        $alltables | ForEach-Object {
            if ($_.Name -in $tables) {
                $storageTables.Add($_.Name, $_.CloudTable)
            }
        }

        # Create missing tables
        $tables | ForEach-Object {
            if ($_ -notin $allTables.Name) {
                $newTable = New-AzStorageTable -Name $_ -Context $storageContext
                $storageTables.Add($_, $newtable.CloudTable)
            }
        }

        $storageTables | Write-Output
    }
    catch {
        "## Could not get Az Storage Table."
        ""
        throw $_
    }
}

function Optimize-EntityValue($value) {
    $output = $value

    if ([string]::IsNullOrEmpty($value)) {
        $output = ''
    }

    if ([string]::IsNullOrWhiteSpace($value)) {
        $output = ''
    }

    return $output
}

function Save-ToDataTable {
    param(
        [Parameter(Mandatory = $true)]
        [system.object]$Table,

        [Parameter(Mandatory = $true)]
        [string]$PartitionKey,

        [Parameter(Mandatory = $true)]
        [string]$RowKey,

        [Parameter(Mandatory = $true)]
        [hashtable]$Properties,

        [Parameter(Mandatory = $false, ParameterSetName = 'Update')]
        [switch]$Update,

        [Parameter(Mandatory = $false, ParameterSetName = 'Merge')]
        [switch]$Merge
    )

    # Creates the table entity with mandatory PartitionKey and RowKey arguments
    $entity = New-Object -TypeName "Microsoft.Azure.Cosmos.Table.DynamicTableEntity" -ArgumentList $PartitionKey, $RowKey

    # Properties are managed by the table itself. Remove them.
    $MetaProperties = ('PartitionKey', 'RowKey', 'TableTimestamp', 'etag')

    # Add properties to entity
    foreach ($Key in $Properties.Keys) {
        $Value = $null

        if ($Key -in $MetaProperties) {
            continue
        }

        $Value = Optimize-EntityValue($Properties[$Key])
        # Fail gracefully if we get unfiltered input.
        if (($Value.GetType().Name -eq "Object[]") -or ($Value.GetType().Name -eq "PSCustomObject")) {
            $entity.Properties.Add($Key, $Value.ToString())
        }
        else {
            $entity.Properties.Add($Key, $Value)
        }
    }

    try {

        $Status = $null

        if ($Merge.IsPresent) {
            $Status = $Table.Execute([Microsoft.Azure.Cosmos.Table.TableOperation]::InsertOrMerge($Entity))
        }
        else {
            $Status = $Table.Execute([Microsoft.Azure.Cosmos.Table.TableOperation]::InsertOrReplace($Entity))
        }

        if ($Status.HttpStatusCode -lt 200 -or $Status.HttpStatusCode -gt 299) {
            throw $Status.HttpStatusCode
        }
    }
    catch {
        throw "Cannot write data into table. $PSItem"
    }
}

function Get-SanitizedRowKey {
    param(
        [Parameter(Mandatory)]
        [string]$RowKey
    )

    $Pattern = '[^A-Za-z0-9-_*]'
    return ($RowKey -replace $Pattern).Trim()
}

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph 
Connect-RjRbAzAccount

$params = @{
    Select = @(
        "EventDateTime"
        "CloudPcId"
        "ManagedDeviceName"
        "UsageInHour"
        "RoundTripTimeInMsP50"
        "AvailableBandwidthInMBpsP50"
        "RemoteSignInTimeInSecP50"
        "UserPrincipalName"
    )
}

$TenantId = (invoke-RjRbRestMethodGraph -Resource "/organization").id
$rawreport = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/reports/getDailyAggregatedRemoteConnectionReports" -Body $params -Method Post -Beta

$allCloudPcs = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs" -Beta
$cloudPcReported = @{}
foreach ($cloudPc in $allCloudPcs) {
    $cloudPcReported[$cloudPc.ManagedDeviceName] = $false
}

$StorageTables = Get-StorageTables -tables $Table

$ReportDateUpper = Get-Date -Format 'yyyy-MM-dd'
$ReportDateLower = (get-date) - (New-TimeSpan -Days 1) | Get-Date -Format 'yyyy-MM-dd'

[int]$rowsWritten = 0

$DataTable = @{
    Table        = $StorageTables.$Table
    PartitionKey = $TenantId
    Merge        = $true
}
    
foreach ($row in $rawreport.Values) {
    $properties = @{}
    for ($i = 0; $i -lt $rawreport.Schema.Column.count; $i++) {
        $RowValue = Optimize-EntityValue($row[$i])
        $properties.add($rawreport.Schema.Column[$i], $RowValue)
    }

    if (($properties["EventDateTime"] -ge $ReportDateLower) -and ($properties["EventDateTime"] -lt $ReportDateUpper)) {
        $cloudPcReported[$properties["ManagedDeviceName"]] = $true
        $RowKey = Get-SanitizedRowKey -RowKey ($TenantId + '_' + $ReportDateLower + "_" + $properties["ManagedDeviceName"])

        try {
            Save-ToDataTable @DataTable -RowKey $RowKey -Properties $properties
            $rowsWritten++
        }
        catch {
            Write-Error "Failed to save CloudPC stats for '$($properties.ManagedDeviceName)' to table. $PSItem" -ErrorAction Continue
        }
    }
} 

foreach ($cloudPc in $cloudPcReported.keys) {
    if ($cloudPcReported[$cloudPc] -eq $false) {
        $properties = @{
            EventDateTime = $ReportDateLower
            CloudPcId = $cloudPc.id
            ManagedDeviceName = $cloudPc.managedDeviceId
            UsageInHour = "0"
            RoundTripTimeInMsP50 = ""
            RemoteSignInTimeInSecP50 = ""
            UserPrincipalName = $cloudpc.userPrincipalName
            AvailableBandwidthInMBpsP50 = ""
        }
        $RowKey = Get-SanitizedRowKey -RowKey ($TenantId + '_' + $ReportDateLower + "_" + $properties["ManagedDeviceName"])

        try {
            Save-ToDataTable @DataTable -RowKey $RowKey -Properties $properties
            $rowsWritten++
        }
        catch {
            Write-Error "Failed to save CloudPC stats for '$($properties.ManagedDeviceName)' to table. $PSItem" -ErrorAction Continue
        }
    }
}

"## Wrote $($rowsWritten) rows to table '$Table'"

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" },"Az.Storage","Az.Resources"

param(
    # CallerName is tracked purely for auditing purposes
    [string] $Table = 'CloudPCUsageV2',
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string] $StorageAccountName,
    [int] $days = 2,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

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

Connect-RjRbGraph 
Connect-RjRbAzAccount

$ReportDateLower = (get-date) - (New-TimeSpan -Days $days) | Get-Date -Format 'yyyy-MM-dd'
$TenantId = (invoke-RjRbRestMethodGraph -Resource "/organization").id

$StorageTables = Get-StorageTables -tables $Table

[int]$rowsWritten = 0

$DataTable = @{
    Table        = $StorageTables.$Table
    PartitionKey = $TenantId
    Merge        = $true
}

# Get all Cloud PCs
$allCloudPcs = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs" -Beta -FollowPaging
foreach ($cloudPc in $allCloudPcs) {

    # Fetch this CloudPCs usage data
    $params = @{
        filter  = "CloudPcId eq '$($cloudPc.id)' and SignInDateTime gt datetime'$($ReportDateLower)T00:00:00.000Z'"
        select  = @(
            "SignInDateTime"
            "SignOutDateTime"
            "RoundTripTimeInMsP50"
            "RemoteSignInTimeInSec"
            "UsageInHour"
        )
        orderBy = @(
            "SignInDateTime desc"
        )
        skip    = 0
        top     = 50
    }
    $rawConnectionsReport = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/reports/getRemoteConnectionHistoricalReports" -Body $params -Method Post -Beta

    if ($rawConnectionsReport.TotalRowCount -eq 0) {
        $properties = @{
            SignInDateTime        = "$($ReportDateLower)T00:00:00"
            SignOutDateTime       = "$($ReportDateLower)T00:00:00"
            RoundTripTimeInMsP50  = $null
            RemoteSignInTimeInSec = $null
            UsageInHour           = 0
        }

        # Add CloudPC metadata
        $properties.Add("managedDeviceName", $cloudPc.managedDeviceName)
        $properties.Add("model", $cloudPc.servicePlanName)
        $properties.Add("userPrincipalName", $cloudPc.userPrincipalName)
        $RowKey = Get-SanitizedRowKey -RowKey ($TenantId + '_' + $properties.SignInDateTime + "_" + $cloudPC.managedDeviceName)

        try {
            Save-ToDataTable @DataTable -RowKey $RowKey -Properties $properties
            $rowsWritten++
        }
        catch {
            Write-Error "Failed to save CloudPC stats for '$($properties.ManagedDeviceName)' to table. $PSItem" -ErrorAction Continue
        }
    }
    else {
        # Write each row to the table
        foreach ($row in $rawConnectionsReport.Values) {    
            $properties = @{}
            for ($i = 0; $i -lt $rawConnectionsReport.Schema.Column.count; $i++) {
                if ($row[$i] -eq $null) {
                    $properties.add($rawConnectionsReport.Schema.Column[$i], 0 )
                }
                else {
                    $properties.add($rawConnectionsReport.Schema.Column[$i], $row[$i])
                }
            }

            # Add CloudPC metadata
            $properties.Add("managedDeviceName", $cloudPc.managedDeviceName)
            $properties.Add("model", $cloudPc.servicePlanName)
            $properties.Add("userPrincipalName", $cloudPc.userPrincipalName)
            $RowKey = Get-SanitizedRowKey -RowKey ($TenantId + '_' + $properties.SignInDateTime + "_" + $cloudPC.managedDeviceName)

            # DEBUG OUTPUT
            #$RowKey
            #$properties | ConvertTo-Json | Out-String
            #""
    
            try {
                Save-ToDataTable @DataTable -RowKey $RowKey -Properties $properties
                $rowsWritten++
            }
            catch {
                Write-Error "Failed to save CloudPC stats for '$($properties.ManagedDeviceName)' to table. $PSItem" -ErrorAction Continue
            }
        }
    }
}
"## Wrote $($rowsWritten) rows to table '$Table'"

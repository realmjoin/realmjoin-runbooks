<#
.SYNOPSIS
Show a local admin password for a device.

.DESCRIPTION
Show a local admin password for a device.

.NOTES
Permissions (Graph):
- DeviceLocalCredential.Read.All
  
.INPUTS
  RunbookCustomization: {
        "Parameters": {
            "DeviceId": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

try {
    $result = Invoke-RjRbRestMethodGraph -Resource "/deviceLocalCredentials/$DeviceId" -Method GET -Beta -OdSelect "credentials"
}
catch {
    "## Querying LAPS credentials on DeviceId '$DeviceId' failed. `n## Aborting..."
    ""
    "## Maybe the 'DeviceLocalCredential.Read.All' permission is missing?"
    ""
    "## Error:"
    $_
    ""
    throw ("credential query failed")
}

"## Reporting LAPS credentials for DeviceId '$DeviceId'"
"## Please ensure, the passwords are rotated after use."
""
[string] $accountName = ""
[string] $password = ""
[datetime] $backupDateTime = [datetime]::MinValue
$result.credentials | ForEach-Object { 
    if ($_.backupDateTime -gt $backupDateTime) {
        $accountName = $_.accountName
        $backupDateTime = $_.backupDateTime
        $password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_.passwordBase64))
    }
}
"## AccountName"
"$accountName"
""
"## Password"
"$password" 
""
"## Time of Backup / Last Rotation"
get-date -Format 'dd.MM.yyyy HH:mm' -Date $backupDateTime
""
"## Time of Refresh / Next Rotation"
get-date -Format 'dd.MM.yyyy HH:mm' -Date $result.refreshDateTime
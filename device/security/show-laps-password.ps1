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
"AccountName;Password"
$result.credentials | ForEach-Object { 
    $password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_.passwordBase64))
    "$($_.accountName);$password" 
}
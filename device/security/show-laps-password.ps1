<#
    .SYNOPSIS
    Show the local admin password of this device

    .DESCRIPTION
    Shows the most recent Windows LAPS password of the local administrator account that is backed up for this device. Use it for break-glass troubleshooting and rotate the password afterwards. Looking it up changes nothing on the device.

    .PARAMETER DeviceId
    Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

# Suppress false positive from PSScriptAnalyzer - variables are assigned inside ForEach-Object but used afterwards
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "accountName")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "password")]
param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

try {
    $result = Invoke-RjRbRestMethodGraph -Resource "/directory/deviceLocalCredentials/$DeviceId" -Method GET -OdSelect "deviceName,credentials"
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

if ((-not $result) -or (-not $result.credentials) -or ($result.credentials.Count -eq 0)) {
    "## No LAPS credentials found for DeviceId '$DeviceId'."
    ""
    "## The device may not have LAPS enabled or no password has been backed up yet."
    return
}

"## Reporting LAPS credentials for Device $($result.deviceName) (DeviceId '$DeviceId')"
"## Please ensure, the passwords are rotated after use."
""
[string] $accountName = ""
[string] $password = ""
[datetime] $backupDateTime = [datetime]::MinValue
$result.credentials | ForEach-Object {
    [datetime] $newBackupDateTime = [datetime]$_.backupDateTime
    if ($newBackupDateTime -gt $backupDateTime) {
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
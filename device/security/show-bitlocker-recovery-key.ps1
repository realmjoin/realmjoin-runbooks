<#
    .SYNOPSIS
    Show all BitLocker recovery keys for a device

    .DESCRIPTION
    This runbook retrieves and displays all BitLocker recovery keys that are backed up for the specified device.
    Keys are sorted by creation date (newest first). Use it for disk recovery scenarios.

    .PARAMETER DeviceId
    The device ID of the target device.

    .PARAMETER CallerName
    Caller name for auditing purposes.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "DeviceId: $DeviceId" -Verbose

#endregion

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_)"
    throw
}

#endregion

########################################################
#region     Main Part
########################################################

Write-Output "Querying BitLocker recovery keys for device..."
Write-Output ""

# Get all recovery keys for the device
try {
    $uri = "https://graph.microsoft.com/beta/informationProtection/bitlocker/recoveryKeys?`$filter=deviceId eq '$DeviceId'"
    $result = Invoke-MgGraphRequest -Method GET -Uri $uri
}
catch {
    "## Querying BitLocker recovery keys on DeviceId '$DeviceId' failed."
    "## Aborting..."
    ""
    "## Maybe the 'BitLockerKey.Read.All' permission is missing?"
    ""
    "## Error:"
    $_
    ""
    throw ("BitLocker recovery key query failed")
}

if ((-not $result) -or (-not $result.value) -or ($result.value.Count -eq 0)) {
    "## No BitLocker recovery keys found for DeviceId '$DeviceId'."
    ""
    "## The device may not have BitLocker enabled or no recovery key has been backed up yet."
    return
}

# Sort recovery keys by creation date (newest first)
Write-RjRbLog -Message "Found $($result.value.Count) recovery key(s) for device" -Verbose

$sortedKeys = $result.value | Where-Object { $_.createdDateTime } | Sort-Object createdDateTime -Descending

# Display results header
"## Reporting all BitLocker recovery keys for DeviceId '$DeviceId'"
"## Please ensure the keys are securely stored and only used for legitimate recovery purposes."
""
"## Found $($sortedKeys.Count) recovery key(s)"
""

# Retrieve and display each recovery key
$keyNumber = 1
foreach ($keyInfo in $sortedKeys) {
    Write-RjRbLog -Message "Retrieving key $keyNumber of $($sortedKeys.Count): $($keyInfo.id)" -Verbose

    # Retrieve the actual recovery key
    try {
        $keyUri = "https://graph.microsoft.com/beta/informationProtection/bitlocker/recoveryKeys/$($keyInfo.id)?`$select=key"
        $keyResult = Invoke-MgGraphRequest -Method GET -Uri $keyUri
    }
    catch {
        Write-Warning "Failed to retrieve key details for ID: $($keyInfo.id)"
        continue
    }

    # Display key information
    "=========================================="
    "## Recovery Key #$keyNumber"
    "=========================================="
    ""
    "BitLocker Key ID:"
    "$($keyInfo.id)"
    ""
    "Volume Type:"
    switch ($keyInfo.volumeType) {
        "1" { "Operating System Volume" }
        "2" { "Fixed Data Volume" }
        "3" { "Removable Data Volume" }
        default { "Unknown ($($keyInfo.volumeType))" }
    }
    ""
    "Created / Backed Up:"
    Get-Date -Format 'dd.MM.yyyy HH:mm' -Date $keyInfo.createdDateTime
    ""
    "Recovery Key:"
    "$($keyResult.key)"
    ""

    $keyNumber++
}

""

#endregion

"Done!"

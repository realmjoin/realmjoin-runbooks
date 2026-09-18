<#
    .SYNOPSIS
    Show all BitLocker recovery keys for a device

    .DESCRIPTION
    This runbook retrieves and displays all BitLocker recovery keys that are backed up for the specified device.
    Keys are sorted by creation date (newest first). Use it for disk recovery scenarios.
    Optionally, the keys are only shown when the device's Microsoft Defender for Endpoint risk score is not Medium or High.

    .PARAMETER DeviceId
    The device ID of the target device.

    .PARAMETER skipIfAtRisk
    If set to true, the recovery keys are only shown when the device's Microsoft Defender for Endpoint risk score is not Medium or High. This prevents the recovery key of a device that may be involved in a security incident from being disclosed without aligning with your security team first. Devices that are not found in Defender for Endpoint are not blocked.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "DeviceId": {
                "Hide": true
            },
            "skipIfAtRisk": {
                "DisplayName": "Only show keys if device is not at risk (Defender Medium/High)?",
                "SelectSimple": {
                    "Only show keys if Defender risk score is not Medium/High": true,
                    "Show keys regardless of Defender risk score": false
                }
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    # If true, only show the recovery keys when the device's Defender risk score is not Medium or High (protects devices involved in a security incident).
    [bool] $skipIfAtRisk = $false,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "DeviceId: $DeviceId" -Verbose
Write-RjRbLog -Message "skipIfAtRisk: $skipIfAtRisk" -Verbose

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
#region     Defender Risk Preflight (runs first, may abort)
########################################################

# Evaluate the device's Defender for Endpoint risk score before doing anything else.
# If the device is at risk (Medium/High), abort immediately so the recovery key of a
# device that may be involved in a security incident is not disclosed.
if ($skipIfAtRisk) {
    "## 'Skip if at risk' is enabled. Checking Microsoft Defender for Endpoint risk score..."
    try {
        # Defender for Endpoint is only required for this check.
        Connect-RjRbDefenderATP

        # From experience the first result seems to be the "freshest" candidate.
        $atpDevice = Invoke-RjRbRestMethodDefenderATP -Resource "/machines" -OdFilter "aadDeviceId eq $DeviceId" -ErrorAction Stop |
            Sort-Object { [datetime]$_.lastSeen } -Descending |
            Select-Object -First 1
    }
    catch {
        "## Error Message: $($_.Exception.Message)"
        "## Please see 'All logs' for more details."
        "## Maybe the 'Machine.Read.All' permission on WindowsDefenderATP is missing?"
        "## Execution stopped."
        throw "Could not determine the device's Defender risk score. Aborting to avoid disclosing the recovery key of a potentially at-risk device."
    }

    if ($atpDevice -and $atpDevice.riskScore) {
        "## Defender risk score: '$($atpDevice.riskScore)'"
        if ($atpDevice.riskScore -in @('Medium', 'High')) {
            ""
            "!!!!! Warning !!!!!"
            "Defender risk score of this device is '$($atpDevice.riskScore)'."
            "The device may be involved in a security incident. Disclosing its BitLocker recovery key now could expose encrypted data to an attacker."
            "Please align with your security team before retrieving the recovery key."
            "To show the keys anyway, disable 'Only show keys if device is not at risk' and re-run this runbook."
            "!!!!!!!!!!!!!!!!!!!!!!!!!!"
            ""
            throw "Execution stopped: Defender risk score is '$($atpDevice.riskScore)'. Key retrieval cancelled to protect a potentially compromised device. Align with security or disable 'Only show keys if device is not at risk'."
        }
    }
    elseif ($atpDevice) {
        "## Device found in Defender for Endpoint, but no risk score is reported yet; proceeding with key retrieval."
    }
    else {
        "## Device not found in Defender for Endpoint. Risk score could not be determined; proceeding with key retrieval."
    }
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

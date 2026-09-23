<#
    .SYNOPSIS
    Look up a BitLocker recovery key by its key ID

    .DESCRIPTION
    Finds the BitLocker recovery key that belongs to the key ID shown on a device's recovery screen and returns the key together with the device it belongs to. Use it when a user is locked out at the BitLocker prompt.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .PARAMETER bitlockeryRecoveryKeyId
    The key ID displayed on the BitLocker recovery screen of the device.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "bitlockeryRecoveryKeyId": {
                "DisplayName": "BitLocker recovery key ID"
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
    [string] $CallerName,
    [Parameter(Mandatory = $true)]
    [string] $bitlockeryRecoveryKeyId
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph -Force

try {
    Write-Output "Get bitlockeryRecoveryKey for: $bitlockeryRecoveryKeyId"

    $bitlockeryRecoveryKeyIdResponse = Invoke-RjRbRestMethodGraph -Resource "/informationProtection/bitlocker/recoveryKeys/$($bitlockeryRecoveryKeyId)" -OdSelect "key" -Method GET

    if ($bitlockeryRecoveryKeyIdResponse) {
        Write-Output "- bitlockeryRecoveryKey: $($bitlockeryRecoveryKeyIdResponse.key)"
        Write-Output "- created at: $($bitlockeryRecoveryKeyIdResponse.createdDateTime)"
        switch ($bitlockeryRecoveryKeyIdResponse.volumeType) {
            1 { Write-Output "- volumeType: operatingSystemVolume" }
            2 { Write-Output "- volumeType: fixedDataVolume" }
            3 { Write-Output "- volumeType: removableDataVolume" }
            4 { Write-Output "- volumeType: unknownFutureValue" }
            default { Write-Output "- volumeType: unexpected value" }
        }
        $deviceId = $bitlockeryRecoveryKeyIdResponse.deviceId
        Write-Output "- deviceId: $($deviceId)"

        try {
            # Get device details
            $deviceResponse = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$deviceId'"
            Write-Output "- deviceName: $($deviceResponse.displayName)"
            Write-Output "- trustType: $($deviceResponse.trustType)"
            Write-Output "- isCompliant: $($deviceResponse.isCompliant)"
        }
        catch {
            $errorResponseDevice = $_
            Write-Output "- Error getting device details: $($errorResponseDevice)"
        }

    }
    else {
        Write-Output "- No recovery key found (empty response)."
    }
}
catch {
    $errorResponse = $_
    if ($errorResponse -match '404') {
        Write-Output "- No recovery key found."
        Write-RjRbLog -Message "- Error: $($errorResponse)" -Verbose
        throw ("No recovery key found.")
    }
    elseif ($errorResponse -match '403') {
        Write-Output "- Forbidden. Check Graph permissions of automation account."
        Write-RjRbLog -Message "- Error: $($errorResponse)" -Verbose
        throw ("Forbidden. Check Graph permissions of automation account.")
    }
    elseif ($errorResponse -match '400') {
        Write-Output "- Bad Request. Check format of submitted bitlockeryRecoveryKeyId."
        Write-RjRbLog -Message "- Error: $($errorResponse)" -Verbose
        throw ("Bad Request. Check format of submitted bitlockeryRecoveryKeyId.")
    }
    else {
        Write-Output "- Other error."
        Write-Output "- Error: $($errorResponse)"
        throw ("Other error.")
    }
}
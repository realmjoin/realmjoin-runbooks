<#
    .SYNOPSIS
    Register a device in Intune by its corporate identifier

    .DESCRIPTION
    Adds a device to Intune's list of corporate identifiers, such as a serial number or IMEI, so it counts as corporate-owned when it enrolls. An existing entry for the same identifier can be overwritten, and a description can be stored with it.

    .PARAMETER CorpIdentifierType
    Serial number for most devices, IMEI for cellular devices.

    .PARAMETER CorpIdentifier
    Value of the chosen identifier, exactly as printed on or reported by the device.

    .PARAMETER DeviceDescripton
    Free text stored with the identifier, for example the device model or its owner.

    .PARAMETER OverwriteExistingEntry
    Replaces an entry that already exists for the same identifier.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "DeviceDescripton": {
                "DisplayName": "Description"
            },
            "OverwriteExistingEntry": {
                "DisplayName": "Overwrite an existing entry?"
            },
            "CorpIdentifierType": {
                "DisplayName": "Identifier type",
                "SelectSimple": {
                    "Serial Number": "serialNumber",
                    "IMEI": "imei"
                }
            },
            "CallerName": {
                "Hide": true
            },
            "CorpIdentifier": {
                "DisplayName": "Identifier"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CorpIdentifierType = "serialNumber",
    [Parameter(Mandatory = $true)]
    [string] $CorpIdentifier,
    [string] $DeviceDescripton = "",
    [bool] $OverwriteExistingEntry = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

if ($CorpIdentifierType -notin @("imei", "serialNumber")) {
    "## 'CorpIdentifierType' is either 'imei' or 'serialNumber'."
    throw ("invalid input")
}

# Serial is at least six alphanumerical char, max 128.
$regSerial = '^\w{6,128}$'
# IMEI is 14 to 16 numbers
$regImei = '^\d{14,16}$'

if ($CorpIdentifierType -eq "imei" -and (-not $CorpIdentifier -match $regImei)) {
    "## IMEI is 14 to 16 numerical digits."
    throw ("invalid input")
}

if ($CorpIdentifierType -eq "serialNumber" -and (-not $CorpIdentifier -match $regSerial)) {
    "## Serial is 6 to 128 alphanumerical characters."
    throw ("invalid input")
}

$body = @{
    importedDeviceIdentities          = [array]@{
        importedDeviceIdentifier   = $CorpIdentifier
        importedDeviceIdentityType = $CorpIdentifierType
        description                = $DeviceDescripton
        enrollmentState            = "enrolled"
    }
    overwriteImportedDeviceIdentities = $OverwriteExistingEntry
}

Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/importedDeviceIdentities/importDeviceIdentityList" -Beta -Method Post -Body $body

""
"## '$CorpIdentifierType`:$CorpIdentifier' added to Intune Corp. Identifiers list."


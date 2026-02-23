<#
    .SYNOPSIS
    Import a device into Intune via corporate identifier

    .DESCRIPTION
    This runbook imports a device into Intune using a corporate identifier such as serial number or IMEI.
    It can overwrite existing entries and optionally stores a description for the imported identity.

    .PARAMETER CorpIdentifierType
    Identifier type to use for import.

    .PARAMETER CorpIdentifier
    Identifier value to import.

    .PARAMETER DeviceDescripton
    Optional description stored for the imported identity.

    .PARAMETER OverwriteExistingEntry
    If set to true, an existing entry for the same identifier will be overwritten.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CorpIdentifierType": {
                "SelectSimple": {
                    "Serial Number": "serialNumber",
                    "IMEI": "imei"
                }
            },
            "CallerName": {
                "Hide": true
            },
            "CorpIdentifier": {
                "DisplayName": "Corporate Identifier Value"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

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

$Version = "1.0.0"
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


<#
  .SYNOPSIS
  Import a device into Intune via corporate identifier.

  .DESCRIPTION
  Import a device into Intune via corporate identifier.

  .NOTES
  Permissions: 
  MS Graph (API):
  - DeviceManagementServiceConfig.ReadWrite.All

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
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CorpIdentifierType = "serialNumber",
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -DisplayName "Corporate Identifier Value" } )]
    [string] $CorpIdentifier,
    [string] $DeviceDescripton = "",
    [bool] $OverwriteExistingEntry = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

if ($CorpIdentifierType -notin @("imei","serialNumber")) {
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
    importedDeviceIdentities = [array]@{
        importedDeviceIdentifier = $CorpIdentifier
        importedDeviceIdentityType = $CorpIdentifierType
        description = $DeviceDescripton
        enrollmentState = "enrolled"    
    }
    overwriteImportedDeviceIdentities = $OverwriteExistingEntry
}

Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/importedDeviceIdentities/importDeviceIdentityList" -Beta -Method Post -Body $body

""
"## '$CorpIdentifierType`:$CorpIdentifier' added to Intune Corp. Identifiers list."


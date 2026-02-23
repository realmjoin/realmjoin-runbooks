<#
    .SYNOPSIS
    Create a new Microsoft Defender for Endpoint indicator

    .DESCRIPTION
    Creates a new indicator in Microsoft Defender for Endpoint to allow or block a specific file hash, certificate thumbprint, IP, domain, or URL. The indicator action can generate alerts automatically for audit or alert-and-block actions.

    .PARAMETER IndicatorValue
    Value of the indicator, such as a hash, thumbprint, IP address, domain name, or URL.

    .PARAMETER IndicatorType
    Type of the indicator value.

    .PARAMETER Title
    Title of the indicator entry.

    .PARAMETER Description
    Description of the indicator entry.

    .PARAMETER Action
    Action applied to the indicator.

    .PARAMETER Severity
    Severity used for the indicator.

    .PARAMETER GenerateAlert
    If set to true, an alert is generated when the indicator matches.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "IndicatorValue": {
                "Hide": false
            },
            "IndicatorType": {
                "DisplayName": "IndicatorType",
                "SelectSimple": {
                    "File Sha256": "FileSha256",
                    "File Sha1": "FileSha1",
                    "File Md5": "FileMd5",
                    "Certificate Thumbprint": "CertificateThumbprint",
                    "Ip Address": "IpAddress",
                    "Domain Name": "DomainName",
                    "Url": "Url"
                }
            },
            "Title": {
                "Hide": false
            },
            "Description": {
                "Hide": false
            },
            "Action": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Alert": "Alert",
                    "Warn": "Warn",
                    "Block": "Block",
                    "Audit": "Audit",
                    "Block And Remediate": "BlockAndRemediate",
                    "Alert And Block": "AlertAndBlock",
                    "Allowed": "Allowed"
                }
            },
            "Severity": {
                "DisplayName": "Severity",
                "SelectSimple": {
                    "Informational": "Informational",
                    "Low": "Low",
                    "Medium": "Medium",
                    "High": "High"
                }
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [string] $IndicatorValue,
    [Parameter(Mandatory = $true)]
    [string] $IndicatorType = "FileSha256",
    [Parameter(Mandatory = $true)]
    [string] $Title,
    [Parameter(Mandatory = $true)]
    [string] $Description,
    [Parameter(Mandatory = $true)]
    [string] $Action = "Allowed",
    [Parameter(Mandatory = $true)]
    [string] $Severity = "Informational",
    [Parameter(Mandatory = $true)]
    [string] $GenerateAlert = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbDefenderATP -force

#If Action is Audit Generate-Alert must be set to "true"
$generateAlert = $false

if ($Action.Contains("Audit") -or $Action.Contains("AlertAndBlock")) {
    "For the requested action it is necessary to generate an alert."
    "Changing generateAlert to $true"
    $generateAlert = $true
}

$params = @{
    indicatorValue = $IndicatorValue
    indicatorType  = $IndicatorType
    title          = $Title
    action         = $Action
    description    = $Description
    generateAlert  = $generateAlert
}

try {
    $result = Invoke-RjRbRestMethodDefenderATP -Resource "/indicators" -Method Post -Body $params
}
catch {
    "## ... failed."
    ""
    "Error details:"
    $_
    throw "isolation failed"
}


if ($result) {
    "## Creation Sucessfull"
    $result
}
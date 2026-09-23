<#
    .SYNOPSIS
    Add an allow or block indicator to Defender for Endpoint

    .DESCRIPTION
    Creates a custom indicator in Microsoft Defender for Endpoint that allows, warns about, audits or blocks a file hash, certificate thumbprint, IP address, domain or URL on all onboarded devices. An alert can be raised whenever the indicator matches.

    .PARAMETER IndicatorValue
    The hash, thumbprint, IP address, domain name or URL the indicator applies to. Must match the indicator type.

    .PARAMETER IndicatorType
    File hash (SHA-256, SHA-1 or MD5), certificate thumbprint, IP address, domain name or URL. The value must be of this type.

    .PARAMETER Title
    Short name shown for the indicator in the Defender portal.

    .PARAMETER Description
    Why the indicator exists. Shown in the Defender portal and in alerts.

    .PARAMETER Action
    What Defender does on a match: Allow, Warn, Audit, Block, Block and remediate, or Alert and block.

    .PARAMETER Severity
    Severity of the alerts raised for this indicator.

    .PARAMETER GenerateAlert
    Raises an alert in the Defender portal each time the indicator matches.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "GenerateAlert": {
                "DisplayName": "Raise an alert on match?"
            },
            "CallerName": {
                "Hide": true
            },
            "IndicatorValue": {
                "DisplayName": "Indicator value",
                "Hide": false
            },
            "IndicatorType": {
                "DisplayName": "Indicator type",
                "SelectSimple": {
                    "File hash (SHA-256)": "FileSha256",
                    "File hash (SHA-1)": "FileSha1",
                    "File hash (MD5)": "FileMd5",
                    "Certificate thumbprint": "CertificateThumbprint",
                    "IP address": "IpAddress",
                    "Domain name": "DomainName",
                    "URL": "Url"
                }
            },
            "Title": {
                "DisplayName": "Title",
                "Hide": false
            },
            "Description": {
                "DisplayName": "Description",
                "Hide": false
            },
            "Action": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Alert": "Alert",
                    "Warn": "Warn",
                    "Block": "Block",
                    "Audit": "Audit",
                    "Block and remediate": "BlockAndRemediate",
                    "Alert and block": "AlertAndBlock",
                    "Allow": "Allowed"
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

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
    [Parameter(Mandatory = $false)]
    [bool] $GenerateAlert = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbDefenderATP -force

#If Action is Audit or AlertAndBlock, GenerateAlert must be set to $true
if ($Action.Contains("Audit") -or $Action.Contains("AlertAndBlock")) {
    "For the requested action it is necessary to generate an alert."
    "Changing generateAlert to $true"
    $GenerateAlert = $true
}

$params = @{
    indicatorValue = $IndicatorValue
    indicatorType  = $IndicatorType
    title          = $Title
    action         = $Action
    description    = $Description
    generateAlert  = $GenerateAlert
    severity       = $Severity
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
    $resultSummary = [PSCustomObject][ordered]@{
        Title           = $result.title
        Description     = $result.description
        IndicatorValue  = $result.indicatorValue
        IndicatorType   = $result.indicatorType
        Action          = $result.action
        Severity        = $result.severity
        GenerateAlert   = $result.generateAlert
        IndicatorId     = $result.id
        CreatedAt       = $result.creationTimeDateTimeUtc
        LastUpdatedAt   = $result.lastUpdateTime
    }

    "## Creation Successful"
    ""
    $resultSummary | Format-List | Out-String
}
<#
    .SYNOPSIS
    Allow, warn or block a URL in Defender SmartScreen

    .DESCRIPTION
    Manages URL indicators in Microsoft Defender for Endpoint, which SmartScreen uses to allow, audit, warn about or block a domain. Lists the existing indicators, adds one for a domain, or removes all indicators for it.

    .PARAMETER Url
    Domain to manage, for example exclusiondemo.com.

    .PARAMETER action
    List shows all URL indicators, Add creates one for the domain, Remove deletes every indicator for it.

    .PARAMETER mode
    What SmartScreen does with the domain: allow it, only audit access, warn the user, or block it.

    .PARAMETER explanationTitle
    Short title stored with the indicator.

    .PARAMETER explanationDescription
    Reason stored with the indicator, for example who requested the exclusion.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "action": {
                "DisplayName": "Action",
                "Select": {
                    "Options": [
                        {
                            "Display": "List all URL indicators",
                            "Value": 0,
                            "Customization": {
                                "Hide": [
                                    "mode",
                                    "explanationTitle",
                                    "explanationDescription",
                                    "Url"
                                ]
                            }
                        },
                        {
                            "Display": "Add a URL indicator",
                            "Value": 1
                        },
                        {
                            "Display": "Remove all indicators for this URL",
                            "Value": 2,
                            "Customization": {
                                "Hide": [
                                    "mode",
                                    "explanationTitle",
                                    "explanationDescription"
                                ]
                            }
                        }
                    ]
                }
            },
            "mode": {
                "DisplayName": "Allow, audit, warn or block?",
                "SelectSimple": {
                    "Allow": 0,
                    "Audit": 1,
                    "Warn": 2,
                    "Block": 3
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
    # 0 - list, 1 - add, 2 - remove
    [int] $action = 0,
    [string] $Url,
    # 0 - allow, 1 - audit, 2 - warn, 3 - block
    [int] $mode = 0,
    [string] $explanationTitle = "Allow this domain in SmartScreen",
    [string] $explanationDescription = "Required exclusion. Please provide more details.",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbDefenderATP

$indicators = Invoke-RjRbRestMethodDefenderATP -Resource "/indicators" -FollowPaging | Where-Object { $_.indicatorType -eq "DomainName" }

if ($action -eq 0) {
    "## Listing all current URL indicators from Security Center:"
    $indicators | Select-Object -Property @{name = "Domain"; expression = { $_.indicatorValue } }, action | Format-Table -AutoSize | Out-String
    exit
}

# Either add or remove...
$matchingIndicators = $indicators | Where-Object { $_.indicatorValue -eq $Url }
if ($matchingIndicators) {
    if ($action -eq 1) {
        "## Trying to add indicator for URL '$Url' - alread exists:"
        $matchingIndicators | Select-Object -Property @{name = "Domain"; expression = { $_.indicatorValue } }, action | Format-Table -AutoSize | Out-String
        "## Stopping"
        exit
    }
    else {
        "## Removing indicators for URL '$Url'."
        foreach ($match in $matchingIndicators) {
            Invoke-RjRbRestMethodDefenderATP -Resource "/indicators/$($match.id)" -Method Delete
        }
        exit
    }
}
else {
    if ($action -eq 1) {
        $body = @{
            indicatorValue = $Url
            indicatorType  = "DomainName"
            title          = $explanationTitle
            description    = $explanationDescription
        }
        switch ($mode) {
            0 {
                $body += @{ action = "Allowed" }
            }
            1 {
                $body += {
                    action = "Audit"
                    generateAlert = "True"
                }
            }
            2 {
                $body += { action = "Warn" }
            }
            3 {
                $body += { action = "Block" }
            }
        }
        "## Adding indicator for URL '$Url' mode '$($body.action)'."
        Invoke-RjRbRestMethodDefenderATP -Resource "/indicators" -Method POST -Body $body | Out-Null
        exit
    }
    else {
        "## Trying to remove indicators for URL '$Url' - no matches found. Stopping."
        exit
    }
}

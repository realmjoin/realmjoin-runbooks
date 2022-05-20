<#
  .SYNOPSIS
  Add/Remove a SmartScreen URL Exception/Rule in MS Security Center Indicators 

  .DESCRIPTION
  List/Add/Remove URL indicators entries in MS Security Center.

  .PARAMETER Url
  please give just the name of the domain, like "exclusiondemo.com"

  .NOTES
  Permissions: WindowsDefenderATP:
  - Ti.ReadWrite.All
 
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
                        "Display": "Add an URL indicator",
                        "Value": 1
                    },
                    {
                        "Display": "Remove all indicator for this URL",
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
            "DisplayName": "Allow, Audit, Warn or Block this URL?",
            "SelectSimple": {
                "Allow": 0,
                "Audit": 1,
                "Warn": 2,
                "Block": 3
            }
        }
    }
}

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    # 0 - list, 1 - add, 2 - remove
    [int] $action  = 0,
    [string] $Url,
    # 0 - allow, 1 - audit, 2 - warn, 3 - block
    [int] $mode = 0,
    [string] $explanationTitle = "Allow this domain in SmartScreen",
    [string] $explanationDescription = "Required exclusion. Please provide more details.",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

Connect-RjRbDefenderATP

$indicators = Invoke-RjRbRestMethodDefenderATP -Resource "/indicators" | Where-Object { $_.indicatorType -eq "DomainName" }

if ($action -eq 0) {
    "## Listing all current URL indicators from Security Center:"
    $indicators | Select-Object -Property @{name = "Domain"; expression = { $_.indicatorValue } },action | Format-Table -AutoSize | Out-String
    exit 
}

# Either add or remove...
$matchingIndicators = $indicators | Where-Object { $_.indicatorValue -eq $Url }
if ($matchingIndicators) {
    if ($action -eq 1) {
        "## Trying to add indicator for URL '$Url' - alread exists:"
        $matchingIndicators | Select-Object -Property @{name = "Domain"; expression = { $_.indicatorValue } },action | Format-Table -AutoSize | Out-String
        "## Stopping"
        exit 
    } else {
        "## Removing indicators for URL '$Url'."
        foreach($match in $matchingIndicators) {
            Invoke-RjRbRestMethodDefenderATP -Resource "/indicators/$($match.id)" -Method Delete
        }
        exit
    }
} else {
    if ($action -eq 1) {
        $body = @{
            indicatorValue = $Url
            indicatorType = "DomainName"
            title = $explanationTitle
            description = $explanationDescription
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
    } else {
        "## Trying to remove indicators for URL '$Url' - no matches found. Stopping."
        exit
    }
}

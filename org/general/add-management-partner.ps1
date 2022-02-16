<#
  .SYNOPSIS
  List or add or Management Partner Links (PAL)

  .DESCRIPTION
  List or add or Management Partner Links (PAL)

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "Action": {
                "Select": {
                    "Options": [
                        {
                            "Display": "List current PALs",
                            "ParameterValue": 0,
                            "Customization": {
                            "Hide": [
                                "PartnerId"
                            ]
                        }
                        },
                        {
                            "Display": "Add a PAL",
                            "ParameterValue": 1
                        }
                    ]
                }
            }  
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" },Az.ManagementPartner

param(
    [Parameter(Mandatory = $true)]
    [int] $Action = 0,
    [int] $PartnerId = 6457701,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbAzAccount

# Get current PALs
$pals = Get-AzManagementPartner -ErrorAction SilentlyContinue


if ($Action -eq 0) {
    "## Listing all PALs"
    ""
    if (-not $pals) {
        "## ... no PALs found."
    }
    else {
        $pals | Out-String
    }

}
elseif ($Action -eq 1) {
    if (($pals | Where-Object { $_.PartnerId -eq $PartnerId }).count -gt 0) {
        "## PAL / Management Parner Link $PartnerId is already set."
        ""
        throw ("PAL already set")
    }

    "## Setting Management Partner Link (PAL) ..."
    ""
    New-AzManagementPartner -PartnerId $PartnerId
}

#elseif ($Action -eq 2) {
#    if (($pals | Where-Object { $_.PartnerId -eq $PartnerId }).count -gt 0) {
#        "## Removing Management Partner Link (PAL) $PartnerId ..."
#        ""
#        Remove-AzManagementPartner -PartnerId $PartnerId
#    }
#    else {
#        "## PAL / Management Parner Link $PartnerId not present."
#        throw ("PAL not found")
#    }
#}
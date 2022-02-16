<#
  .SYNOPSIS
  Add a PAL / Management Partner Link

  .DESCRIPTION
  Add a PAL / Management Partner Link

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

if ($Action -eq 0) {
    "## Listing all PALs"
    ""
    Get-AzManagementPartner | Out-String

}
elseif ($Action -eq 1) {
    if ((Get-AzManagementPartner -ErrorAction SilentlyContinue | Where-Object { $_.PartnerId -eq $PartnerId }).count -gt 0) {
        "## PAL / Management Parner Link $PartnerId is already set."
        ""
        exit 0
    }

    "## Setting Management Partner Link..."
    ""
    New-AzManagementPartner -PartnerId $PartnerId
}
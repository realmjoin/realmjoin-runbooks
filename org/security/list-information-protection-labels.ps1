<#
  .SYNOPSIS
  Prints a list of all available InformationProtectionPolicy labels.

  .DESCRIPTION
  Prints a list of all available InformationProtectionPolicy labels.

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }

param(
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# TODO: Currently only in preview / beta. Change when available in v1.0
$labels = Invoke-RjRbRestMethodGraph -Resource "/informationProtection/policy/labels" -Beta -ErrorAction SilentlyContinue

if (-not $labels) {
    "## Could not read InformationProtection labels. Either missing permission, or no InformationProtection policy is set."
    ""
    "## Make sure, the following Graph API Permission is available"
    "## - InformationProtectionPolicy.Read.All (API)"
    ""
    throw "No inform. protection labels found."
}

"## Current Inf. Protection Labels"
""
$labels | Format-Table -AutoSize | Out-String
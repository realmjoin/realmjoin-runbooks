<#
  .SYNOPSIS
  Report groups that have license assignment errors

  .DESCRIPTION
  Report groups that have license assignment errors

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

# Query for license assignment errors
$result = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "hasMembersWithLicenseErrors eq true"

if (-not $result) {
    "## No groups with license assignment errors were found."
}
else {
    "## The following groups have license assignment errors:"
    $result | ForEach-Object {
        "Group: '$($_.displayName)', ObjectId: $($_.id)"
    }
}
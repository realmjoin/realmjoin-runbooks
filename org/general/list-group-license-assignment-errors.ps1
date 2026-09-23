<#
    .SYNOPSIS
    List groups whose license assignments have errors

    .DESCRIPTION
    Finds the Entra ID groups with members whose group-based license assignment failed and lists their names and object IDs. Nothing is changed.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
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
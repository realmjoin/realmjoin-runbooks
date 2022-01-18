<#
  .SYNOPSIS
  List AzureAD role holders.

  .DESCRIPTION
  Will list users and service principals that hold a builtin AzureAD role.

  .NOTES
  Permissions: MS Graph
  - User.Read.All
  - Directory.Read.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
  # CallerName is tracked purely for auditing purposes
  [Parameter(Mandatory = $true)]
  [string] $CallerName
)

Connect-RjRbGraph

## Get builtin AzureAD Roles
$roles = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleDefinitions" -OdFilter "isBuiltIn eq true"

if ([array]$roles.count -eq 0) {
    "## Error - No AzureAD roles found. Missing permissions?"
    throw("no roles found")
}

$roles | ForEach-Object {
    $roleHolders = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleAssignments" -OdFilter "roleDefinitionId eq '$($_.id)'" -ErrorAction SilentlyContinue
    if (([array]$roleHolders).count -gt 0) {
        "## Role: $($_.displayName)"
        $roleHolders | ForEach-Object {
            $principal = Invoke-RjRbRestMethodGraph -Resource "/directoryObjects/$($_.principalId)" -ErrorAction SilentlyContinue
            if (-not $principal) {
                "Unknown principal: $($_.principalId)"
            } else {
                if ($principal."@odata.type" -eq "#microsoft.graph.user") {
                    $principal.userPrincipalName
                } elseif ($principal."@odata.type" -eq "#microsoft.graph.servicePrincipal") {
                    "$($principal.displayName) (ServicePrincipal)"
                } else {
                    "$($principal.displayName) $($principal."@odata.type")"
                }
            }
        }
        ""
    }

}


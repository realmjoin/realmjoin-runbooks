<#

.SYNOPSIS
    Delete an application registration from Azure AD

.DESCRIPTION
    This script safely removes an application registration and its associated service principal from Azure Active Directory (Entra ID).
    
    This script is the counterpart to the add-application-registration script and ensures
    proper cleanup of all resources created during application registration.

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
    [Parameter(Mandatory = $true)]
    [string] $ClientId,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

# Check if the application exists
$existingApp = Invoke-RjRbRestMethodGraph -Method GET -Resource "/applications" -OdFilter "appId eq '$ClientId'" -ErrorAction SilentlyContinue

if (-not $existingApp) {
    "## Application with AppId '$ClientId' does not exist."
    throw "Application with AppId '$ClientId' does not exist."
}

# Check if the service principal exists
$existingServicePrincipal = Invoke-RjRbRestMethodGraph -Method GET -Resource "/servicePrincipals" -OdFilter "appId eq '$ClientId'" -ErrorAction SilentlyContinue

$assignedGroups = @()
if ($existingServicePrincipal) {
    # Check if a group is assigned to the application. Save the group for later.
    $existingAppRoleAssignment = Invoke-RjRbRestMethodGraph -Method GET -Resource "/servicePrincipals/$($existingServicePrincipal.id)/appRoleAssignedTo" -ErrorAction SilentlyContinue
    $existingAppRoleAssignment | ForEach-Object {
        if ($_.principalType -eq "Group") {
            #$existingGroup = Invoke-RjRbRestMethodGraph -Method GET -Resource "/groups/$($_.principalId)" -ErrorAction SilentlyContinue
            $assignedGroups += $existingAppRoleAssignment
        }
        
    }
}

"## Deleting the application"
"## '$ClientId'"
Invoke-RjRbRestMethodGraph -Method DELETE -Resource "/applications/$($existingApp.id)" | Out-Null

if ($assignedGroups.count -gt 0) {
    "## Deleting assigned groups"    
    $assignedGroups | ForEach-Object {
        "## - '$($_.principalDisplayName)'"
        Invoke-RjRbRestMethodGraph -Method DELETE -Resource "/groups/$($_.principalId)" | Out-Null
    }
}
    
"## Application deleted successfully"
<#
    .SYNOPSIS
    Delete an application registration and its service principal

    .DESCRIPTION
    Deletes an application registration from Entra ID together with its service principal. Every group assigned to the application is deleted as well, including groups shared with other applications. Applications that still sign users in stop working immediately.

    .PARAMETER ClientId
    Client ID (appId) of the application registration to delete.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "ClientId": {
                "DisplayName": "Application (client) ID"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [string] $ClientId,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

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
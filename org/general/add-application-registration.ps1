<#

.SYNOPSIS
    Add an application registration to Azure AD

.DESCRIPTION
    Add an application registration to Azure AD

.NOTES
    Permissions: 
    MS Graph (API):
    - Application.ReadWrite.All
    - RoleManagement.ReadWrite.Directory

.INPUTS
    RunbookCustomization: {
        "Parameters": {
            "signInAudience": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $ApplicationName,
    [string] $signInAudience = "AzureADMyOrg",
    [ValidateScript( { Use-RJInterface -DisplayName "Grant custom role permissions to this user." -Type Graph -Entity User } )]
    [string] $targetUserId = "",
    [string] $customPermissionRoleName = "",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

# Check if an application with the same name already exists
$existingApp = Invoke-RjRbRestMethodGraph -Method GET -Resource "/applications" -OdFilter "displayName eq '$ApplicationName'"

if ($existingApp) {
    "## Application '$ApplicationName' already exists, id: $($existingApp.id)"
    "## Skipping application creation"
    Exit
}

$body = @{
    "displayName" = $ApplicationName
    "signInAudience" = $signInAudience
}

$resultApp = Invoke-RjRbRestMethodGraph -Resource "/applications" -Method POST -Body $body
""
"## Application '$ApplicationName' created, Appid: $($resultApp.appId)"

$body = @{
    "appId" = $resultApp.appId
}
$resultSvcPrincipal = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -Method POST -Body $body
"## Service Principal created."

$roleDefinition = $null
if ($customPermissionRoleName) {
    $roleDefinition = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleDefinitions/" -OdFilter "displayName eq '$customPermissionRoleName'" -Method GET
    if ($null -eq $roleDefinition) {
        ""
        "## Role definition '$customPermissionRoleName' not found"
        "## Skipping role assignment"
        ""
    }
}

if ($targetUserId) {
    $targetUser = Invoke-RjRbRestMethodGraph -Resource "/users/$targetUserId" -ErrorAction SilentlyContinue
    if ($null -eq $targetUser) {
        ""
        "## User '$targetUserPrincipalName' not found"
        "## Skipping role assignment"
        ""
    }
}

if ($roleDefinition -and $targetUser) {
    $roleAssignment = @{
        "principalId" = $targetUser.id
        "roleDefinitionId" = $roleDefinition.id
        "directoryScopeId" = "/$($resultApp.id)"
    }

    $resultApp = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleAssignments/" -Method POST -Body $roleAssignment
    "## Role assignment for '$customPermissionRoleName' to '$($targetUser.displayName)' created."
}

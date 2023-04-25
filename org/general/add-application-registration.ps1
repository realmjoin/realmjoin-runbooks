<#

.SYNOPSIS
    Add an application registration to Azure AD

.DESCRIPTION
    Add an application registration to Azure AD

.NOTES
    Permissions: 
    MS Graph (API):
    - Application.ReadWrite.All

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [Parameter(Mandatory = $true)]
    [string] $ApplicationName,
    [string] $signInAudience = "AzureADMyOrg",
    [int] $ApplicationType = 0,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

# Check if an application with the same name already exists
$existingApp = Invoke-RjRbRestMethodGraph -Method GET -Resource "/applications" -OdFilter "displayName eq '$ApplicationName'"

if ($null -eq $existingApp) {
    "## Application '$ApplicationName' already exists, id: $($existingApp.id)"
    "## Skipping application creation"
    Exit
}

$body = @{
    "displayName" = $ApplicationName
    "signInAudience" = $signInAudience
}

$result = Invoke-RjRbRestMethodGraph -Resource "/applications" -Method POST -Body $body

""
"## Application '$ApplicationName' created, id: $($result.id)"


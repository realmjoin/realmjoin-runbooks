<#
    .SYNOPSIS
    List group ownerships for this user.

    .DESCRIPTION
    Lists Entra ID groups where the specified user is an owner. Outputs the group names and IDs.

    .PARAMETER UserName
    User principal name of the target user.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$User = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName"
$OwnedGroups = Invoke-RjRbRestMethodGraph -Resource "/users/$($User.id)/ownedObjects/microsoft.graph.group/"

"## Listing group ownerships for '$($User.UserPrincipalName)':"
if ($OwnedGroups) {
    foreach ($OwnedGroup in $OwnedGroups) {
        "## Group '$($OwnedGroup.displayName)' with id '$($OwnedGroup.id)'"
    }
}
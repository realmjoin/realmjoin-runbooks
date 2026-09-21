<#
    .SYNOPSIS
    Show the manager of this user

    .DESCRIPTION
    Shows who is set as the manager of this user in Entra ID, with the manager's display name, email address and phone numbers. Nothing is changed.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$User = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName"
$Manager = Invoke-RjRbRestMethodGraph -Resource "/users/$($User.id)/manager"

"## Listing manager information for '$($User.UserPrincipalName)':"
if ($Manager) {
    "## Manager: '$($Manager.displayName)'"
    "## Manager Email: '$($Manager.mail)'"
    "## Manager Job Title: '$($Manager.jobTitle)'"
    "## Manager Phone: '$($Manager.businessPhones[0])'"
    "## Manager Mobile: '$($Manager.mobilePhone)'"
}
else {
    "No manager information found for this user."
}

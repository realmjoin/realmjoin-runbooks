<#
    .SYNOPSIS
    List manager information for this user

    .DESCRIPTION
    Retrieves the manager object for a specified user. Outputs common manager attributes such as display name, email, and phone numbers.

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

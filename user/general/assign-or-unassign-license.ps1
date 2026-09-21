<#
    .SYNOPSIS
    Assign or remove a license for this user via a license group

    .DESCRIPTION
    Adds this user to a license assignment group or removes the user from it, which assigns or removes the license the group carries.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER GroupID_License
    Group that carries the license. Only groups whose name starts with LIC_ are offered.

    .PARAMETER Remove
    Assign adds the user to the group. Remove takes the user out of it.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "Remove": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Assign license to user": false,
                    "Remove license from user": true
                }
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
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    # production does not supprt "ref:LicenseGroup" yet
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -Filter "startswith(DisplayName, 'LIC_')" -DisplayName "License group" } )]
    [String] $GroupID_License,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Action" } )]
    [boolean] $Remove = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# Licensing group prefix
$groupPrefix = "LIC_"

# "Find select group from Object ID " + $GroupID_License
$group = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID_License"
if (-not $group.displayName.startswith($groupPrefix, 'CurrentCultureIgnoreCase')) {
    throw "'$($group.displayName)' is not a license assignment group. Will not proceed."
}

"## Trying to assign license group '$($group.displayName)' to '$UserName'"

# "Find the user object " + $UserName)
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter "userPrincipalName eq '$UserName'" -ErrorAction SilentlyContinue
if (-not $targetUser) {
    throw ("User $UserName not found.")
}

# "Is user member of the the group?"
if (Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID_License/members/$($targetUser.id)" -ErrorAction SilentlyContinue) {
    if ($Remove) {
        #"Removing license."
        Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID_License/members/$($targetUser.id)/`$ref" -Method Delete | Out-Null
        "## '$($group.displayName)' is removed from '$UserName'"
    }
    else {
        "## License '$($group.displayName)' is already assigned to '$UserName'. No action taken."
    }
}
else {
    if ($Remove) {
        "## License '$($group.displayName)' is not assigned to '$UserName'. Doing nothing."
    }
    else {
        #"Assigning license"
        $body = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($targetUser.id)"
        }
        Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID_License/members/`$ref" -Method Post -Body $body | Out-Null
        "## '$($group.displayName)' is assigned to '$UserName'"
    }
}

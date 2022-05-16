<#
  .SYNOPSIS
  (Un-)Assign a license to a user via group membership.

  .DESCRIPTION
  (Un-)Assign a license to a user via group membership

  .NOTES
  Permissions:
  MS Graph (API):
  - User.Read.All
  - GroupMember.ReadWrite.All 
  - Group.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "Remove": {
                "DisplayName": "Assign or Remove License",
                "SelectSimple": {
                    "Assign License to User": false,
                    "Remove License from User": true
                }
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
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    # production does not supprt "ref:LicenseGroup" yet
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -Filter "startswith(DisplayName, 'LIC_')" -DisplayName "License group" } )]
    [String] $GroupID_License,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove license" } )]
    [boolean] $Remove = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph

# Licensing group prefix
$groupPrefix = "LIC_"

# "Find select group from Object ID " + $GroupID_License
$group = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID_License"
if (-not $group.displayName.startswith($groupPrefix)) {
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

<#
  .SYNOPSIS
  Add, update or remove a user's mobile phone MFA information.

  .DESCRIPTION
  Add, update or remove a user's mobile phone MFA information.

  .PARAMETER phoneNumber
  Needs to be in '+###########' syntax

  .NOTES
  Permissions needed:
 - UserAuthenticationMethod.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "Remove": {
                "DisplayName": "Add or Remove Member",
                "SelectSimple": {
                    "Add this number as Mobile Phone MFA Factor'": false,
                    "Remove this number / mobile phone MFA factor": true
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
    [String]$UserName,
    [Parameter(Mandatory = $true)]
    [String]$phoneNumber,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this mobile phone MFA factor" } )]
    [bool] $Remove = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph

if ($Remove) {
    "## Trying to remove phone MFA number '$phoneNumber' from user '$UserName'."
} else {
    "## Trying to add phone MFA number '$phoneNumber' to user '$UserName'."
}

# Sanity check 
if (-not $phoneNumber.startswith("+")) {
    throw "Phone Number needs to be in international E.164 format ('+' + Country Code + Number)"
}

#"Find mobile phone auth. methods for user $UserName"
$phoneAM = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods" -Beta -OdFilter "phoneType eq 'mobile'"
$body = @{
    phoneNumber = $phoneNumber
    phoneType   = "mobile"
}
if ($phoneAM) {
    if ($remove) {
        Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods/$($phoneAM.id)" -Method Delete -Beta | Out-Null
        "## Successfully removed mobile phone authentication number '$phoneNumber' from user '$UserName'."
    }
    else {
        # "Mobile Phone method found. Updating entry."
        Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods/$($phoneAM.id)" -Method Put -Body $body -Beta | Out-Null
        "## Successfully updated mobile phone authentication number '$phoneNumber' for user '$UserName'."
    }
}
else {
    if ($Remove) {
        "## Number '$phoneNumber' not found as mobile phone MFA factor for '$UserName'."
    }
    else {
        # "No phone methods found. Will add a new one."
        Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods" -Method Post -Body $body -Beta | Out-Null
        "## Successfully added mobile phone authentication number '$phoneNumber' to user '$UserName'."
    }
}

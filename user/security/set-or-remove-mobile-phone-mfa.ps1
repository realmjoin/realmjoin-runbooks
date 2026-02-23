<#
    .SYNOPSIS
    Set or remove a user's mobile phone MFA method

    .DESCRIPTION
    Adds, updates, or removes the user's mobile phone authentication method. If you need to change a number, remove the existing method first and then add the new number.

    .PARAMETER UserName
    User principal name of the target user.

    .PARAMETER phoneNumber
    Mobile phone number in international E.164 format (e.g., +491701234567).

    .PARAMETER Remove
    If set to true, removes the mobile phone MFA method instead of adding or updating it.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "Remove": {
                "DisplayName": "Add or Remove Member",
                "SelectSimple": {
                    "Add this number as Mobile Phone MFA factor": false,
                    "Remove this number / mobile phone MFA factor": true
                }
            },
            "phoneNumber": {
                "DisplayName": "Mobile Phone Number"
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
    [String]$UserName,
    [Parameter(Mandatory = $true)]
    [String]$phoneNumber,
    [bool] $Remove = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

if ($Remove) {
    "## Trying to remove phone MFA number '$phoneNumber' from user '$UserName'."
}
else {
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

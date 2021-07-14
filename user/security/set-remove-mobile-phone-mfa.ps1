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
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.2" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String]$UserName,
    [Parameter(Mandatory = $true)]
    [String]$phoneNumber,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this mobile phone MFA factor" } )]
    [bool] $Remove = $false
)

Connect-RjRbGraph

# Graph API requires "+" Syntax
if ($phoneNumber.StartsWith("01")) {
    $phoneNumber = ("+49" + $phoneNumber.Substring(1))
}

# Workaround - sometimes "+" gets lost...
if ($phoneNumber.StartsWith("49")) {
    $phoneNumber = "+" + $phoneNumber
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
        "Successfully removed mobile phone authentication number $phoneNumber from user $UserName."
    }
    else {
        # "Mobile Phone method found. Updating entry."
        Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods/$($phoneAM.id)" -Method Put -Body $body -Beta | Out-Null
        "Successfully updated mobile phone authentication number $phoneNumber for user $UserName."
    }
}
else {
    if ($Remove) {
        "Number $phoneNumber not found as mobile phone MFA factor for $UserName."
    }
    else {
        # "No phone methods found. Will add a new one."
        Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods" -Method Post -Body $body -Beta | Out-Null
        "Successfully added mobile phone authentication number $phoneNumber to user $UserName."
    }
}

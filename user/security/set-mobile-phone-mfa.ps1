# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

<#
  .SYNOPSIS
  Add or update a user's mobile phone MFA information.

  .DESCRIPTION
  Aadd or update a user's mobile phone MFA information.

  .PARAMETER phoneNumber
  Needs to be in '+###########' syntax

#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String]$UserName,
    [Parameter(Mandatory = $true)]
    [String]$phoneNumber
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
    # "Mobile Phone method found. Updating entry."
    Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods/$($phoneAM.id)" -Method Put -Body $body -Beta | Out-Null
}
else {
    # "No phone methods found. Will add a new one."
    Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/phoneMethods" -Method Post -Body $body -Beta | Out-Null
}
"Successfully set mobile phone authentication number $phoneNumber to user $UserName."
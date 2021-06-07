# This runbook will add or update a user's mobile phone MFA information.
# It will NOT change the default auth method.
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

#Requires -Module MEMPSToolkit, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    [Parameter(Mandatory = $true)]
    [String]$phoneNumber
)

Connect-RjRbGraph

# Graph API requires "+" Syntax
if ($phoneNumber.StartsWith("01")) {
    $phoneNumber = ("+49" + $phoneNumber.Substring(1))
}

# Woraround - sometimes "+" gets lost...
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
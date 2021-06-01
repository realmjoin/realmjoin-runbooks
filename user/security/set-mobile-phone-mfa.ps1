# This runbook will add or update a user's mobile phone MFA information.
# It will NOT change the default auth method.
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

#Requires -Module MEMPSToolkit, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    [Parameter(Mandatory = $true)]
    [String]$phoneNumber
)

#region module check
function Test-ModulePresent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$neededModule
    )
    if (-not (Get-Module -ListAvailable $neededModule)) {
        throw ($neededModule + " is not available and can not be installed automatically. Please check.")
    }
    else {
        Import-Module $neededModule
        # "Module " + $neededModule + " is available."
    }
}

Test-ModulePresent "MEMPSToolkit"
Test-ModulePresent "RealmJoin.RunbookHelper"
#endregion

#region Authentication
# "Connect to Graph API..."
Connect-RjRbGraph
#endregion

# Graph API requires "+" Syntax
if ($phoneNumber.StartsWith("01")) {
    $phoneNumber = ("+49" + $phoneNumber.Substring(1))
}

# Woraround - sometimes "+" gets lost...
if ($phoneNumber.StartsWith("49")) {
    $phoneNumber = "+" + $phoneNumber
}

"Find mobile phone auth. methods for user $UserName"
$phoneAMs = Get-AADUserPhoneAuthMethods -userID $UserName -authToken $Global:RjRbGraphAuthHeaders
if ($phoneAMs) {
    "Phone methods found. Will update primary entry."
    $authId = ($phoneAMs | Where-Object { $_.phoneType -eq "mobile" }).id
    Update-AADUserPhoneAuthMethod -authToken $Global:RjRbGraphAuthHeaders -userID $UserName -authId $authId -phoneNumber $phoneNumber 
}
else {
    "No phone methods found. Will add a new one."
    Add-AADUserPhoneAuthMethod -authToken $Global:RjRbGraphAuthHeaders -userID $UserName -phoneNumber $phoneNumber 
}
"Successfully set mobile phone authentication number $phoneNumber to user $UserName."
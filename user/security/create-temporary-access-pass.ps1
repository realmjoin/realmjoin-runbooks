# This runbook will create an AAD temporary access pass for a user. 
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    # How long (starting immediately) is the pass valid?
    [ValidateScript( { Use-RJInterface -Type Number } )]
    [int] $lifetimeInMinutes = 240,
    # Is this a one-time pass (prefered); will be usable multiple times otherwise
    [bool] $oneTimeUseOnly = $true
)

Connect-RjRbGraph

# "Making sure, no old temp. access passes exist for $UserName"
$OldPasses = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/temporaryAccessPassMethods" -Beta
$OldPasses | ForEach-Object {
    Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/temporaryAccessPassMethods/$($_.id)" -Beta -Method Delete | Out-Null
}

# "Creating new temp. access pass"
$body = @{
    "@odata.type"       = "#microsoft.graph.temporaryAccessPassAuthenticationMethod";
    "lifetimeInMinutes" = $lifetimeInMinutes;
    "isUsableOnce"      = $oneTimeUseOnly
}
$pass = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/authentication/temporaryAccessPassMethods" -Body $body -Beta -Method Post 

if ($pass.methodUsabilityReason -eq "DisabledByPolicy") {
    "Beware: The use of Temporary access passes seems to be disabled for this user."
}

"New Temporary access pass for $UserName with a lifetime of $lifetimeInMinutes minutes has been created: $($pass.temporaryAccessPass)"

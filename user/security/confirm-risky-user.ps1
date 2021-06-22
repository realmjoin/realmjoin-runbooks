# This runbook will confirm a user as compromised. 
#
# This runbook will use the "AzureRunAsConnection". Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - IdentityRiskyUser.ReadWrite.All

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName
)

Connect-RjRbGraph

# "Checking risk status of $UserName"
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/identityProtection/riskyUsers" -OdFilter "userPrincipalName eq '$UserName'" -ErrorAction SilentlyContinue
if (-not $targetUser) {
    "$UserName is not in list of risky users. No action taken."
    exit
}

#"Current risk: $($targetUser.riskState)"
#if ($targetUser.riskState -eq "confirmedCompromised") {
# "User risk for $UserName already set to 'confirmed compromised'. No action taken."
# exit
#} 

$body = @{ "userIds" = ([array]$targetUser.id) }
Invoke-RjRbRestMethodGraph -Resource "/identityProtection/riskyUsers/confirmCompromised" -Body $body -Method Post | Out-Null
#set-ConfirmCompromisedRiskyUser -authToken $Global:RjRbGraphAuthHeaders -userId $targetUser.id 
"Compromise for $UserName successfully confirmed."


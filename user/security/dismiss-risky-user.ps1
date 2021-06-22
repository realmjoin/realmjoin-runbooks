# This runbook will dismiss a user risk classification. 
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

"Current risk: $($targetUser.riskState)"
if (($targetUser.riskState -eq "atRisk") -or ($targetUser.riskState -eq "confirmedCompromised")) {
    $body = @{ "userIds" = ([array]$targetUser.id) }
    Invoke-RjRbRestMethodGraph -Resource "/identityProtection/riskyUsers/dismiss" -Body $body -Method Post | Out-Null
    "User risk for $UserName successfully dismissed."
} else {
    "User $UserName not at risk. No action taken."
}

# This runbook will confirm a user as compromised. 
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - IdentityRiskyUser.ReadWrite.All

#Requires -Modules MEMPSToolkit, RealmJoin.RunbookHelper

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName
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

"Checking risk status of $UserName"
$riskyUsers = get-RiskyUsers -authToken $Global:RjRbGraphAuthHeaders
$targetUser = ($riskyUsers | where-Object { $_.userPrincipalName -ieq $UserName })
if (-not $targetUser) {
    "$UserName is not in list of risky users. No action taken."
    exit
}

"Current risk: $($targetUser.riskState)"
if ($targetUser.riskState -eq "confirmedCompromised") {
    "User risk for $UserName already set to `"confirmed compromised`". No action taken."
} 
else {
    set-ConfirmCompromisedRiskyUser -authToken $Global:RjRbGraphAuthHeaders -userId $targetUser.id 
    "Compromise for $UserName successfully confirmed."
}

# This runbook will dismiss a user risk classification. 
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

# "Checking risk status of $UserName"
$riskyUsers = get-RiskyUsers -authToken $Global:RjRbGraphAuthHeaders
$targetUser = ($riskyUsers | where-Object { $_.userPrincipalName -ieq $UserName })
if (-not $targetUser) {
    "$UserName is not in list of risky users. No action taken."
    exit
}

"Current risk: $($targetUser.riskState)"
if (($targetUser.riskState -eq "atRisk") -or ($targetUser.riskState -eq "confirmedCompromised")) {
    set-DismissRiskyUser -authToken $Global:RjRbGraphAuthHeaders -userId $targetUser.id 
    "User risk for $UserName successfully dismissed."
} else {
    "User $UserName not at risk. No action taken."
}

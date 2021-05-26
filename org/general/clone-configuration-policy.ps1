# This runbook will create a copy of a configuration policy (old style "configuration profiles", not newew "configuration settings") and append " - Copy" to the name of the new policy.
# This will currently not copy the device/user assignments. This is intentional, so you can tweak the policy before applying it.
# Problems: This version uses "v1.0" endpoints of graph api. These are stable but incomplete. Some profiles will only work with "beta".
#
# Assumptions: 
# - The automations creds in "realmjoin-automation-cred" correlate to an AppRegsitration and are able to sign in to MS Graph and have the enough permissions
#

#Requires -Modules MEMPSToolkit, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.4.0" }

param(
    [Parameter(Mandatory = $true)]
    [string]$configPolicyID = "",
    [string]$OrganizationID
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

#region authentication
# "Connecting to MS Graph"
Connect-RjRbGraph
#endregion

"Fetch policy $configPolicyID"
$confpol = Get-DeviceConfigurationById -authToken $Global:RjRbGraphAuthHeaders -configId $configPolicyID

"New name: $($confpol.displayName) - Copy"
$confpol.displayName = ($confpol.displayName + " - Copy")

"Fetch all policies, check new policy name does not exist..."
$allPols = Get-DeviceConfigurations -authToken $Global:RjRbGraphAuthHeaders
if ($null -ne ($allPols | Where-Object { $_.displayName -eq $confpol.displayName })) { 
    throw ("Target Policyname `"" + $confpol.displayName + "`" already exists.")
} 

"Import new policy"
Add-DeviceConfiguration -authToken $Global:RjRbGraphAuthHeaders -config $confpol | Out-Null

"Policy " + $confpol.displayName + " has been successfully created."

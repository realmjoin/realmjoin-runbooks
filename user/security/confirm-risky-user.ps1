# This runbook will confirm a user as compromised. 
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - IdentityRiskyUser.ReadWrite.All

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    [String]$OrganizationID,
    # Is this a "second attempt" to execute the runbook? Only allow starting another run if $false, to avoid endless looping.
    [bool]$reRun = $false
)

$neededModule = "MEMPSToolkit"
$thisRunbook = "rjgit-user_security_confirm-risky-user"
$thisRunbookParams = @{
    "reRun"    = $true;
    "UserName" = $UserName;
    "OrganizationID" = $OrganizationID;
}

#region Module Management
Write-Output ("Check if " + $neededModule + " is available")
$moduleInstallerRunbook = "rjgit-setup_import-module-from-gallery" 

if (-not $reRun) { 
    if (-not (Get-Module -ListAvailable $neededModule)) {
        Write-Output ("Installing " + $neededModule + ". This might take several minutes.")
        $runbookJob = Start-AutomationRunbook -Name $moduleInstallerRunbook -Parameters @{"moduleName" = $neededModule; "waitForDeployment" = $true }
        Wait-AutomationJob -Id $runbookJob.Guid -TimeoutInMinutes 10
        Write-Output ("Restarting Runbook and stopping this run.")
        Start-AutomationRunbook -Name $thisRunbook -Parameters $thisRunbookParams
        exit
    }
} 

if (-not (Get-Module -ListAvailable $neededModule)) {
    throw ($neededModule + " is not available and can not be installed automatically. Please check.")
}
else {
    Import-Module $neededModule
    Write-Output ("Module " + $neededModule + " is available.")
}
#endregion

#region Authentication
# Automation credentials
$automationCredsName = "realmjoin-automation-cred"

Write-Output "Connect to Graph API..."
$token = Get-AzAutomationCredLoginToken -tenant $OrganizationID -automationCredName $automationCredsName
#endregion

write-output ("Checking risk status of " + $UserName) 
$riskyUsers = get-RiskyUsers -authToken $token
$targetUser = ($riskyUsers | where-Object { $_.userPrincipalName -ieq $UserName })
if (-not $targetUser) {
    Write-Output ($UserName + " is not in list of risky users. No action taken.")
    exit
}

Write-Output ("Current risk: " + $targetUser.riskState)
if ($targetUser.riskState -eq "confirmedCompromised") {
    Write-Output ("User risk for " + $UserName + " already set to `"confirmed compromised`". No action taken.")
} else {
    Write-Output ("Confirming")
    set-ConfirmCompromisedRiskyUser -authToken $token -userId $targetUser.id 
    Write-Output ("Compromise for " + $UserName + " successfully confirmed.")
}

# This runbook will create a copy of a configuration policy (old style "configuration profiles", not newew "configuration settings") and append " - Copy" to the name of the new policy.
# This will currently not copy the device/user assignments. This is intentional, so you can tweak the policy before applying it.
# Problems: This version uses "v1.0" endpoints of graph api. These are stable but incomplete. Some profiles will only work with "beta".
#
# Assumptions: 
# - The automations creds in "realmjoin-automation-cred" correlate to an AppRegsitration and are able to sign in to MS Graph and have the enough permissions
#

param(
    [Parameter(Mandatory = $true)]
    [string]$configPolicyID = "",
    [string]$OrganizationID,
    # Is this a "second attempt" to execute the runbook? Only allow starting another run if $false, to avoid endless looping.
    [bool]$reRun = $false
)

$neededModule = "MSPSToolkit"
$thisRunbook = "rjgit-org_general_clone-configuration-policy"
$thisRunbookParams = @{
    "reRun"          = $true;
    "configPolicyID" = $configPolicyID;
    "OrganizationID" = $OrganizationID
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

$automationCredsName = "realmjoin-automation-cred"

Write-Output "Connect to Graph API..."
$token = Get-AzAutomationCredLoginToken -tenant $OrganizationID -automationCredName $automationCredsName

Write-Output ("Fetch policy " + $configPolicyID)
$confpol = Get-DeviceConfigurationById -authToken $token -configId $configPolicyID

Write-Output ("New name: " + $confpol.displayName + " - Copy")
$confpol.displayName = ($confpol.displayName + " - Copy")

Write-Output ("Fetch all policies, check new policy name does not exist...")
$allPols = Get-DeviceConfigurations -authToken $token
if ($null -ne ($allPols | Where-Object { $_.displayName -eq $confpol.displayName })) { 
    throw ("Target Policyname `"" + $confpol.displayName + "`" already exists.")
} 

Write-Output ("Import new policy")
Add-DeviceConfiguration -authToken $token -config $confpol | Out-Null

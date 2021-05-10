# This runbook will create an AAD temporary access pass for a user. 
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    [String]$OrganizationID,
    # How long (starting immediately) is the pass valid?
    [int] $lifetimeInMinutes = 240,
    # Is this a one-time pass (prefered); will be usable multiple times otherwise
    [bool] $oneTimeUseOnly = $true,
    # Is this a "second attempt" to execute the runbook? Only allow starting another run if $false, to avoid endless looping.
    [bool]$reRun = $false
)

$neededModule = "MEMPSToolkit"
$thisRunbook = "rjgit-user_security_create-temporary-access-pass"
$thisRunbookParams = @{
    "reRun"    = $true;
    "UserName" = $UserName;
    "OrganizationID" = $OrganizationID;
    "lifetimeInMinutes" = $lifetimeInMinutes;
    "oneTimeUseOnly" = $oneTimeUseOnly;
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

Write-Output ("Making sure, no old temp. access passes exist for " + $UserName)
Remove-AadUserTemporaryAccessPass -authToken $token -userID $UserName

Write-Output ("Creating new temp. access pass")
$pass = New-AadUserTemporaryAccessPass -authToken $token -userID $UserName -oneTimeUse $oneTimeUseOnly -lifetimeInMinutes $lifetimeInMinutes

if ($pass.methodUsabilityReason -eq "DisabledByPolicy") {
    Write-Output ("Beware: The use of Temporary access passes seems to be disabled for this user.")
}

Write-Output ("New Temporary access pass for " + $UserName + " with a lifetime of " + $lifetimeInMinutes +" minutes has been created: " + $pass.temporaryAccessPass)

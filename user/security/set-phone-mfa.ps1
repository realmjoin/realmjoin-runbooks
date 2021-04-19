# This runbook will add or update a user's mobile phone MFA information.
# It will NOT change the default auth method.
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    [String]$OrganizationID,
    [String]$phoneNumber,
    # Is this a "second attempt" to execute the runbook? Only allow starting another run if $false, to avoid endless looping.
    [bool]$reRun = $false
)

$neededModule = "MEMPSToolkit"
$thisRunbook = "rjgit-user_security_add-phone-mfa"
$thisRunbookParams = @{
    "reRun"    = $true;
    "UserName" = $UserName;
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

# Automation credentials
$automationCredsName = "realmjoin-automation-cred"

Write-Output "Connect to Graph API..."
$token = Get-AzAutomationCredLoginToken -tenant $OrganizationID -automationCredName $automationCredsName

write-output ("Find phone auth. methods for user " + $UserName) 
$phoneAMs = Get-AADUserPhoneAuthMethods -userID $UserName -authToken $token
if ($phoneAMs) {
    write-output "Phone methods found. Will update primary entry."
    $authId = ($phoneAMs | Where-Object {$_.phoneType -eq "mobile"}).id
    Update-AADUserPhoneAuthMethod -authToken $token -userID $UserName -authId $authId -phoneNumber $phoneNumber 
} else {
    write-output "No phone methods found. Will add a new one."
    Add-AADUserPhoneAuthMethod -authToken $token -userID $UserName -phoneNumber $phoneNumber 
}
write-output ("Phone auth method is updated.")
# This runbook will assign a license to a user via group membership.
#
# This runbook will use the "AzureRunAsConnection" via stored credentials. Please make sure, enough API-permissions are given to this service principal.
# 
# Permissions needed:
# - UserAuthenticationMethod.ReadWrite.All

param(
    [Parameter(Mandatory = $true)]
    [String]$UserName,
    [String]$OrganizationID,
    # Is this a "second attempt" to execute the runbook? Only allow starting another run if $false, to avoid endless looping.
    [bool]$reRun = $false
)

$neededModule = "MEMPSToolkit"
$thisRunbook = "rjgit-user_security_reset-mfa"
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
    write-output "Phone methods found"
}

write-output ("Find Authenticator App auth methods for user " + $UserName)
$appAMs = Get-AADUserMSAuthenticatorMethods -userID $UserName -authToken $token
if ($appAMs) {
    write-output "Apps methods found"
}

[int]$count = 0
while (($count -le 3) -and (($phoneAMs) -or ($appAMs))) {
    $count++;

    $phoneAMs | ForEach-Object {
        write-output ("try to remove phone method, id: " + $_.id) 
        try {
            Remove-AADUserPhoneAuthMethod -userID $UserName -authId $_.id -authToken $token
        } catch {
            write-output "Failed or not found. "
        }
    }

    $appAMs | ForEach-Object {
        write-output ("try to remove app method, id: " + $_.id) 
        try {
            Remove-AADUserMSAuthenticatorMethod -userID $UserName -authId $_.id -authToken $token
        } catch {
            write-output "Failed or not found. "
        }
    }

    Write-Output "Waiting 10 sec. (AuthMethod removal is not immediate)"
    Start-Sleep -Seconds 10

    write-output ("Find phone auth. methods for user " + $UserName) 
    $phoneAMs = Get-AADUserPhoneAuthMethods -userID $UserName -authToken $token
    if ($phoneAMs) {
        write-output "Phone methods found"
    }
    
    write-output ("Find Authenticator App auth methods for user " + $UserName)
    $appAMs = Get-AADUserMSAuthenticatorMethods -userID $UserName -authToken $token
    if ($appAMs) {
        write-output "App methods found"
    }

}

if ($count -le 3) {
    Write-Output "All methods removed."
} else {
    Write-Output "Could not remove all methods. Please review manually."
}
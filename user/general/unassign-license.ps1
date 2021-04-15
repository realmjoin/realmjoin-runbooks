# This runbook will remove a license from a user via removing a group membership.
#
# This runbook will use the "AzureRunAsConnection" to connect to AzureAD. Please make sure, enough API-permissions are given to this service principal.

# Required modules. Will be honored by Azure Automation.

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [String] $UI_GroupID_License,
    [Parameter(Mandatory = $true)]
    [String] $OrganizationID,
    # Is this a "second attempt" to execute the runbook? Only allow starting another run if $false, to avoid endless looping.
    [bool]$reRun = $false
)

$neededModule = "MEMPSToolkit"
$thisRunbook = "rjgi-user_general_unassign-license"
$thisRunbookParams = @{
    "reRun"              = $true;
    "UserName"           = $UserName;
    "UI_GroupID_License" = $UI_GroupID_License;
    "OrganizationID"     = $OrganizationID
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

# Licensing group prefix
$groupPrefix = "LIC_"

# Automation credentials
$automationCredsName = "realmjoin-automation-cred"

Write-Output "Connect to Graph API..."
$token = Get-AzAutomationCredLoginToken -tenant $OrganizationID -automationCredName $automationCredsName

write-output ("Find selected group from Object ID " + $UI_GroupID_License)
$group = Get-AADGroupById -groupId $UI_GroupID_License -authToken $token
if (-not $group.displayName.startswith($groupPrefix)) {
    throw "Please select a licensing group."
}

write-output ("Find the user object " + $UserName) 
$targetUser = get-AADUserByUPN -userName $UserName -authToken $token
if ($null -eq $targetUser) {
    throw ("User " + $UserName + " not found.")
}

write-output ("Is user member of the the group?")
$members = Get-AADGroupMembers -groupID $UI_GroupID_License -authToken $token
if ($members.id -contains $targetUser.id) {
    Write-Output "Removing license."
    Remove-AADGroupMember -groupID $UI_GroupID_License -userID $targetUser.id -authToken $token
}
else {
    Write-Output "License is not assigned. Doing nothing."
    
}




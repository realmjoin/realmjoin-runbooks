# This runbook will enable/disable external parties to send emails to O365 groups.
#

#Requires -Module RealmJoin.RunbookHelper, MEMPSToolkit

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group } )]
    [string]$GroupId,
    [bool]$disable = $false,
    [Parameter(Mandatory = $true)]
    [string] $OrganizationId
)

$ErrorActionPreference = "Stop"

#region module check
$neededModule = "MEMPSToolkit"

if (-not (Get-Module -ListAvailable $neededModule)) {
    throw ($neededModule + " is not available and can not be installed automatically. Please check.")
}
else {
    Import-Module $neededModule
    # "Module $neededModule is available."
}
#endregion

#region Authentication
$automationCredsName = "realmjoin-automation-cred"

"Connect to Graph API..."
$token = Get-AzAutomationCredLoginToken -tenant $OrganizationID -automationCredName $automationCredsName
#endregion

# "Searching for group with GroupId $GroupId"
$group = Get-AADGroupById -authToken $token -groupId $GroupId
if (-not $group) {
    throw "Group with GroupId $GroupId not found!"
}

# "Checking if the group is an O365 group"
if (-not $group.groupTypes.contains("Unified")) {
    throw "Not an O365 (unified) group. Please select an O365 group."
}


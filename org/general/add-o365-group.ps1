# This runbook will create a new Office 365 group, which in turn will create a SharePoint site and optionally a MS Teams team
#
# Permissions (according to https://docs.microsoft.com/en-us/graph/api/group-post-groups?view=graph-rest-1.0 )
# MS Graph: Group.Create

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

param(
    [Parameter(Mandatory = $true)]
    [string] $MailNickname,
    [string] $DisplayName,
    [bool] $CreateTeam = $false,
    [bool] $Private = $false,
    [bool] $MailEnabled = $false,
    [bool] $SecurityEnabled = $true
)

Connect-RjRbGraph

# Check if group exists already
$group = Invoke-RjRbRestMethodGraph -resource "/groups" -OdFilter "mailNickname eq '$MailNickname'" -erroraction SilentlyContinue
if ($group) {
    throw "Group $MailNickname already exists."
}

if (-not $DisplayName) {
    $DisplayName = $MailNickname
}

$groupDescription = @{
    mailNickname    = $mailNickName
    displayName     = $displayName
    securityEnabled = $securityEnabled
    mailEnabled     = $mailEnabled
    groupTypes      = @(
        "Unified"
    )
}

if ($Private) {
    $groupDescription["visibility"] = "Private"
}
else {
    $groupDescription["visibility"] = "Public"
}

if ($CreateTeam) {
    $groupDescription["resourceProvisioningOptions"] = [array]("Team")
}

Invoke-RjRbRestMethodGraph -Method POST -resource "/groups" -body $groupDescription | Out-Null

"Group $MailNickname successfully created."

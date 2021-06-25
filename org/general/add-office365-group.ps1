# Permissions (according to https://docs.microsoft.com/en-us/graph/api/group-post-groups?view=graph-rest-1.0 )
# MS Graph: Group.Create, Team.Create

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

<#
  .SYNOPSIS
  Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

  .DESCRIPTION
  Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -DisplayName "MailNickname" } )]
    [string] $MailNickname,
    [ValidateScript( { Use-RJInterface -DisplayName "DisplayName" } )]
    [string] $DisplayName,
    [ValidateScript( { Use-RJInterface -DisplayName "Create a team" } )]
    [bool] $CreateTeam = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Group is private" } )]
    [bool] $Private = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Group is mail-enabled" } )]
    [bool] $MailEnabled = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Group is securiry-enabled" } )]
    [bool] $SecurityEnabled = $true,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Owner" } )]
    [string] $Owner,
    [string] $CallerName
)

# How long to wait in seconds for a group to propagate to the Teams service
[int]$teamsTimer = 30

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

    # A team needs an owner
    if (-not $Owner) {
        $Owner = $CallerName    
    }
}

if ($Owner) {
    $OwnerObj = Invoke-RjRbRestMethodGraph -Resource "/users/$Owner"
    $groupDescription["owners@odata.bind"] = [array]("https://graph.microsoft.com/v1.0/users/$($OwnerObj.id)")
}

$groupObj = Invoke-RjRbRestMethodGraph -Method POST -resource "/groups" -body $groupDescription

if ($CreateTeam) {
    $teamDescription = @{
        "template@odata.bind" = "https://graph.microsoft.com/v1.0/teamsTemplates('standard')"
        "group@odata.bind"    = "https://graph.microsoft.com/v1.0/groups('$($groupObj.id)')"
    }

    # a new group needs some time to propagate...
    Start-Sleep -Seconds $teamsTimer

    Invoke-RjRbRestMethodGraph -Method POST -Resource "/teams" -Body $teamDescription | Out-Null
}

"Group $MailNickname successfully created."

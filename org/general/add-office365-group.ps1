<#
  .SYNOPSIS
  Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

  .DESCRIPTION
  Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

  .NOTES
  Permissions (according to https://docs.microsoft.com/en-us/graph/api/group-post-groups?view=graph-rest-1.0 )
  MS Graph (API): 
  - Group.Create 
  - Team.Create

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CreateTeam": {
                "DisplayName":  "Create a Teams Team",
                "SelectSimple": {
                    "Only create a SharePoint Site": false,
                    "Create a Team (and SharePoint Site)": true
                }
            },
            "Private": {
                "DisplayName":  "Visibility",
                "SelectSimple": {
                    "Public": false,
                    "Private": true
                }
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -DisplayName "MailNickname" } )]
    [string] $MailNickname,
    [ValidateScript( { Use-RJInterface -DisplayName "DisplayName - will use MailNickname if left empty" } )]
    [string] $DisplayName,
    [ValidateScript( { Use-RJInterface -DisplayName "Create a team" } )]
    [bool] $CreateTeam = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Group is private" } )]
    [bool] $Private = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Group is mail-enabled" } )]
    [bool] $MailEnabled = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Group is security-enabled" } )]
    [bool] $SecurityEnabled = $true,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Owner" -Filter "userType eq 'Member'" } )]
    [string] $Owner,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

# How long to wait in seconds for a group to propagate to the Teams service
[int]$teamsTimer = 15

# Input Validations - from user feedback.
if ($MailNickname.GetEnumerator() -contains " ") {
    throw "MailNickname may not contain Whitespaces."
}

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

"## Creating group '$MailNickname'"
$groupObj = Invoke-RjRbRestMethodGraph -Method POST -resource "/groups" -body $groupDescription

if ($CreateTeam) {
    $teamDescription = @{
        "template@odata.bind" = "https://graph.microsoft.com/v1.0/teamsTemplates('standard')"
        "group@odata.bind"    = "https://graph.microsoft.com/v1.0/groups('$($groupObj.id)')"
    }

    [int]$tries = 0
    [bool]$success = $false
    while (-not $success -and $tries -le 8) {
        $success = $true
        $tries++

        "## Waiting/Sleeping to allow data propagation..."
        # a new group needs some time to propagate...
        Start-Sleep -Seconds $teamsTimer

        try {
            "## Triggering Team creation"
            Invoke-RjRbRestMethodGraph -Method POST -Resource "/teams" -Body $teamDescription | Out-Null
        }
        catch {
            "## ... too early. Try again."
            $success = $false
        }
    }
    if (-not $success) {
        "## Timeout on Team creation. The group has been created, but could not be promoted to a Team."
        ""
        throw ("timeout")
    }
}

""
"## Group '$MailNickname' successfully created."

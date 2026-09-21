<#
    .SYNOPSIS
    Rename this group or change its description

    .DESCRIPTION
    Updates the display name, the mail nickname and the description of this group. Fill in only the fields you want to change; empty fields are left as they are. The group's email addresses do not change.

    .PARAMETER GroupId
    Object ID of the group the runbook acts on. Set by the portal from the selected group.

    .PARAMETER DisplayName
    New name of the group, for a team also the team name. Leave empty to keep the current name.

    .PARAMETER MailNickname
    New alias (mail nickname) of the group. The existing email addresses stay. Leave empty to keep the current alias.

    .PARAMETER Description
    New description shown for the group. Leave empty to keep the current one.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "GroupId": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            },
            "DisplayName": {
                "DisplayName": "New display name"
            },
            "MailNickname": {
                "DisplayName": "New mail nickname"
            },
            "Description": {
                "DisplayName": "New description"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [string] $GroupId,
    [string] $DisplayName,
    [string] $MailNickname,
    [string] $Description,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# Check if group exists already
$group = Invoke-RjRbRestMethodGraph -resource "/groups/$GroupId" -erroraction SilentlyContinue
if (-not $group) {
    throw "GroupId '$GroupId' does not exist."
}

"## Trying to rename/update group $($group.displayName) to:"

$body = @{}
if ($MailNickname) {
    "New MailNickname: $MailNickname"
    $body.Add("mailNickname", $MailNickname)
}
if ($DisplayName) {
    "New DisplayName: $DisplayName"
    $body.Add("displayName", $DisplayName)
}
if ($Description) {
    "New Descriptio: $Description"
    $body.Add("description", $Description)
}

if ($body.Count -gt 0) {
    Invoke-RjRbRestMethodGraph -resource "/groups/$GroupId" -Method Patch -Body $body | Out-Null
    "## Successfully updated group object."
}
else {
    "## Nothing to do."
}


<#
    .SYNOPSIS
    Make this group public or private

    .DESCRIPTION
    Switches this Microsoft 365 group between public and private. Public groups can be found and joined by anyone in the organization, private groups only by their members. Membership, owners and email addresses stay as they are.

    .PARAMETER GroupID
    Object ID of the group the runbook acts on. Set by the portal from the selected group.

    .PARAMETER Public
    Public groups can be found and joined by anyone in the organization, private groups only by their members.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Public": {
                "DisplayName": "Visibility",
                "SelectSimple": {
                    "Make group private": false,
                    "Make group public": true
                }
            },
            "GroupId": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [String] $GroupID,
    [bool] $Public = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# "Find the group object "
$targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId" -ErrorAction SilentlyContinue
if (-not $targetGroup) {
    throw ("Group $GroupId not found.")
}

$body = @{}

if ($Public) {
    $body.Add("visibility", "Public")
    "## Setting the group '$($targetGroup.mailNickname)' to 'Public' visibility."
}
else {
    $body.Add("visibility", "Private")
    "## Setting the group '$($targetGroup.mailNickname)'' to 'Private' visibility."
}

Invoke-RjRbRestMethodGraph -Method PATCH -resource "/groups/$($targetGroup.id)" -body $body | Out-Null


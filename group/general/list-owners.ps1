<#
    .SYNOPSIS
    List all owners of an Office 365 group.

    .DESCRIPTION
    This runbook retrieves and lists the owners of the specified group.
    It uses Microsoft Graph to query the group and its owners and outputs the results as a table.
    Use this to quickly review ownership assignments.

    .PARAMETER GroupID
    Object ID of the target group.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "GroupId": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [String] $GroupID,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$group = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID" -ErrorAction SilentlyContinue
if ($group) {
    "## Listing all owners of group '$($group.displayName)'"
}
else {
    "## Group '$GroupID' not found"
    throw ("Group not found")
}

$owners = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/owners" -ErrorAction SilentlyContinue -FollowPaging

if ($owners) {
    $owners | Format-Table -AutoSize -Property "displayName", "userPrincipalName" | Out-String
}
else {
    "## No owners found (or no access)."
}
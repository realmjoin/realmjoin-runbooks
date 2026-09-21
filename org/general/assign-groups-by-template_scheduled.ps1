<#
    .SYNOPSIS
    Add the users of a group to a predefined set of groups

    .DESCRIPTION
    Adds every user of a source group to the target groups of a template, on a schedule, so a whole population gets the same group set. Users in an exclusion group are skipped. The templates are defined in the runbook customization.

    .PARAMETER SourceGroupId
    Every user in this group is processed.

    .PARAMETER ExclusionGroupId
    Users in this group are skipped. Leave empty to process all users.

    .PARAMETER GroupsTemplate
    Template that decides which groups the users join. The available templates are set up in the runbook customization.

    .PARAMETER GroupsString
    Target groups, separated by commas. Usually filled in by the selected template.

    .PARAMETER UseDisplaynames
    Turn on when the group list holds display names instead of object IDs. Can be preset per template.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "SourceGroupId": {
                "DisplayName": "Source group"
            },
            "ExclusionGroupId": {
                "DisplayName": "Exclusion group"
            },
            "GroupsTemplate": {
                "DisplayName": "Group template"
            },
            "GroupsString": {
                "DisplayName": "Groups"
            },
            "UseDisplaynames": {
                "DisplayName": "Groups given as display names?"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

# Suppress false positive from PSScriptAnalyzer - GroupsTemplate is used to populate GroupsString via RJ Portal Customization
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "GroupsTemplate")]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Source group" } )]
    [String] $SourceGroupId,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclusion group" } )]
    [string] $ExclusionGroupId,
    # GroupsTemplate is not used directly, but is used to populate the GroupsString parameter via RJ Portal Customization
    [string] $GroupsTemplate,
    [Parameter(Mandatory = $true)]
    [string] $GroupsString,
    # $UseDisplayname = $false: GroupsString contains Group object ids, $true: GroupsString contains Group displayNames
    [bool] $UseDisplaynames = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

if (-not $GroupsString) {
    "## Please prepare Groups Templates before using this runbook."
    "## See this runbooks source for an example."
    throw("No GroupsString provided")
}

$SourceGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$SourceGroupId" -ErrorAction SilentlyContinue
if (-not $SourceGroup) {
    "## Source Group with ID '$SourceGroupId' not found in Azure AD."
    throw("Source Group not found");
}
$SourceGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$SourceGroupId/members" -OdSelect "Id,userPrincipalName" -FollowPaging

$ExclusionGroupMembers = @()
if ($ExclusionGroupId) {
    $ExclusionGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$ExclusionGroupId" -ErrorAction SilentlyContinue
    if (-not $ExclusionGroup) {
        "## Exclusion Group with ID '$ExclusionGroupId' not found in Azure AD."
        throw("Exclusion Group not found");
    }
    $ExclusionGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$ExclusionGroupId/members" -OdSelect "Id" -FollowPaging
}

$TargetGroupNames = $GroupsString.Split(',')

$TargetAADGroups = @()
if ($UseDisplaynames) {
    foreach ($GroupName in $TargetGroupNames) {
        $targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$GroupName'"
        if (-not $targetGroup) {
            "## Group with name '$GroupName' not found in Azure AD."
            throw("Group not found");
        }
        if ($targetGroup.count -gt 1) {
            "## Multiple groups with name '$GroupName' found in Azure AD."
            "## Recommendation: Use Group object ids instead of displayNames."
            throw("Group not unique")
        }
        if ($TargetAADGroups.id -notcontains $targetGroup.Id) {
            $TargetAADGroups += $targetGroup
        }
    }
}
else {
    foreach ($GroupId in $TargetGroupNames) {
        $targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId" -ErrorAction SilentlyContinue
        if (-not $targetGroup) {
            "## Group with ID '$GroupId' not found in Azure AD."
            throw("Group not found");
        }
        if ($TargetAADGroups.id -notcontains $targetGroup.Id) {
            $TargetAADGroups += $targetGroup
        }
    }
}

foreach ($AADGroup in $TargetAADGroups) {
    "## Processing Group '$($AADGroup.displayName)'"
    $AADGroupMembers = @()
    $AADGroupMembers += (Invoke-RjRbRestMethodGraph -Resource "/groups/$($AADGroup.Id)/members" -OdSelect "Id" -FollowPaging).id

    [array] $bindings = @()
    foreach ($targetUser in $SourceGroupMembers) {
        if ($ExclusionGroupMembers.id -notcontains $targetUser.Id) {
            #"## Processing user '$($targetUser.userPrincipalName)'"
            if ((-not $AADGroupMembers) -or (($AADGroupMembers.count -eq 1) -and ($AADGroupMembers -ne $targetUser.id)) -or (($AADGroupMembers.count -gt 1) -and ($AADgroupMembers -notcontains $targetUser.id))) {
                "## - Adding user '$($targetUser.userPrincipalName)'"
                $bindings += "https://graph.microsoft.com/v1.0/directoryObjects/$($targetUser.id)"
            }
            #else {
            #"## User is already member of '$($AADGroup.displayName)'. Skipping."
            #}
            if ($bindings.count -gt 15) {
                $GroupJson = @{"members@odata.bind" = $bindings }
                Invoke-RjRbRestMethodGraph -Resource "/groups/$($AADGroup.Id)" -Method Patch -Body $GroupJson | Out-Null
                #"## Updated group '$($AADGroup.displayName)'"
                $bindings = @()
            }
            #else {
            #    "## Pending: $($bindings.count)"
            #}
        }
    }

    if ($bindings) {
        $GroupJson = @{"members@odata.bind" = $bindings }
        Invoke-RjRbRestMethodGraph -Resource "/groups/$($AADGroup.Id)" -Method Patch -Body $GroupJson | Out-Null
        #"## Updated group '$($AADGroup.displayName)'."
    }
    ""
}
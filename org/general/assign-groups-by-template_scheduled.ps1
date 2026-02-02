<#
  .SYNOPSIS
  Assign cloud-only groups to many users based on a predefined template.

  .DESCRIPTION
  Assign cloud-only groups to many users based on a predefined template.

  .EXAMPLE
  Full Runbook Customizations Example
  {
    "Templates": {
        "Options": [
            {
                "$id": "GroupsTemplates",
                "$values": [
                    {
                        "Display": "Template 1 (UseDisplaynames=false)",
                        "Customization": {
                            "Default": {
                                "GroupsString": "c1f8e69f-e6c0-4e7e-b49d-241046958aa3,98c19df0-0bc1-4236-92b9-12559e1127d3"
                            }
                        }
                    },
                    {
                        "Display": "Template 2 (UseDisplaynames=true)",
                        "Customization": {
                            "Default": {
                                "GroupsString": "app - Microsoft VC Redistributable 2013,app - VLC Player"
                            }
                        }
                    }
                ]
            }
        ]
    },
    "Runbooks": {
        "rjgit-user_general_assign-groups-by-template": {
            "ParameterList": [
                {
                    "Name": "GroupsTemplate",
                    "Select": {
                        "Options": {
                            "$ref": "GroupsTemplates"
                        }
                    }
                },
                {
                    "Name": "UseDisplaynames",
                    "Default": false
                }
            ]
        }
    }
  }

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Source Group" } )]
    [String] $SourceGroupId,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Do not operate on Users from this Group" } )]
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

$Version = "1.0.0"
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
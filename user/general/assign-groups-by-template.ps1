<#
  .SYNOPSIS
  Assign cloud-only groups to a user based on a predefined template.

  .DESCRIPTION
  Assign cloud-only groups to a user based on a predefined template.

  .EXAMPLE
  Full Runbook Customizations Example
  {
    "Templates": {
        "Options": [
            {
                "$id": "GroupsTemplates",
                "$values": [
                    {
                        "Display": "User template 1 (UseDisplaynames=false)",
                        "Customization": {
                            "Default": {
                                "GroupsString": "c1f8e69f-e6c0-4e7e-b49d-241046958aa3,98c19df0-0bc1-4236-92b9-12559e1127d3"
                            }
                        }
                    },
                    {
                        "Display": "User template 2 (UseDisplaynames=true)",
                        "Customization": {
                            "Default": {
                                "GroupsString": "app - Microsoft VC Redistributable 2013",
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
            "UserId": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            },
            "UseDisplaynames": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserId,
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

Connect-RjRbGraph

if (-not $GroupsString) {
    "## Please prepare Groups Templates before using this runbook."
    "## See this runbooks source for an example."
    throw("No GroupsString provided")
}

$GroupNames = $GroupsString.Split(',')

$AADGroups = @()
if ($UseDisplaynames) {
    foreach ($GroupName in $GroupNames) {
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
        if ($AADGroups.id -notcontains $targetGroup.Id) {
            $AADGroups += $targetGroup
        }
    }
}
else {
    foreach ($GroupId in $GroupNames) {
        $targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId" -ErrorAction SilentlyContinue
        if (-not $targetGroup) {
            "## Group with ID '$GroupId' not found in Azure AD."
            throw("Group not found");
        }
        if ($AADGroups.id -notcontains $targetGroup.Id) {
            $AADGroups += $targetGroup
        }
    }
}

foreach ($AADGroup in $AADGroups) {
    $AADGroupMembers = @()
    $AADGroupMembers += (Invoke-RjRbRestMethodGraph -Resource "/groups/$($AADGroup.Id)/members" -OdSelect "Id" -FollowPaging).id
    [array] $bindings = @()
    if ((-not $AADGroupMembers) -or (($AADGroupMembers.count -eq 1) -and ($AADGroupMembers -ne $UserId)) -or (($AADGroupMembers.count -gt 1) -and ($AADgroupMembers -notcontains $UserId))) {    
        $bindingString = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
        $bindings += $bindingString
    }
    else {
        "## User is already member of '$($AADGroup.displayName)'. Skipping."
    }
    
    if ($bindings) {
        $GroupJson = @{"members@odata.bind" = $bindings }
        Invoke-RjRbRestMethodGraph -Resource "/groups/$($AADGroup.Id)" -Method Patch -Body $GroupJson | Out-Null
        "## Added user to group '$($AADGroup.displayName)'" 
    }
}
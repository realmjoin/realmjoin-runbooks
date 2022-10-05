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
                        "Display": "Endress+Hauser AT",
                        "Customization": {
                            "Default": {
                                "GroupsString": "app - Audacity,app - Google Chrome",
                            }
                        }
                    },
                    {
                        "Display": "Endress+Hauser InfoServe Germany",
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
        "rjgit-user_general_assign-group-template": {
            "ParameterList": [
                {
                    "Name": "GroupsTemplate",
                    "Select": {
                        "Options": {
                            "$ref": "GroupsTemplates"
                        }
                    }
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
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserId,
    [string] $GroupsTemplate,
    [string] $GroupsString,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

if (-not $GroupsString) {
    "## Please prepare Groups Templates before using this runbook."
    "## See this runbooks source for an example."
}

$GroupNames = $GroupsString.Split(',')

$AADGroups = @()
foreach ($GroupName in $GroupNames) {
    $targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$GroupName'"
    if ($AADGroups.id -notcontains $targetGroup.Id) {
        $AADGroups += $targetGroup
    }
}

foreach ($AADGroup in $AADGroups) {
    $AADGroupMembers = @()
    $AADGroupMembers += (Invoke-RjRbRestMethodGraph -Resource "/groups/$($AADGroup.Id)/members" -OdSelect "Id").id
    [array] $bindings = @()
    if ((-not $AADGroupMembers) -or (($AADGroupMembers.count -eq 1) -and ($AADGroupMembers -ne $UserId)) -or (($AADGroupMembers.count -gt 1) -and($AADgroupMembers.notcontains($UserId)))) {    
        $bindingString = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
        $bindings += $bindingString
    } else {
        "## User is already member of '$($AADGroup.displayName)'"
    }
    
    if ($bindings) {
        $GroupJson = @{"members@odata.bind" = $bindings }
        Invoke-RjRbRestMethodGraph -Resource "/groups/$($AADGroup.Id)" -Method Patch -Body $GroupJson | Out-Null
        "## Added user to group '$($AADGroup.displayName)'" 
    }
}
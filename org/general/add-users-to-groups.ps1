<#
  .SYNOPSIS
  Add new users and those in a Migration group to a set of groups.

  .DESCRIPTION
  Add new users and those in a Migration group to a set of groups.

  .NOTES
  Permissions
   MS Graph (API): 
   - DeviceManagementManagedDevices.Read.All
   - Groups.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "TargetGroupIdString": {
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
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Source Group" } )]
    [string] $MigGroupId,
    [ValidateScript( { Use-RJInterface -DisplayName "Ids of targetgroups separated by , " } )]
    [string] $TargetGroupIdString,
    [ValidateScript( { Use-RJInterface -DisplayName "Names of targetgroups separated by , " } )]
    [string] $TargetGroupNameString,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName 
)

Connect-RjRbGraph

"## Trying to add all members from '$MigGroupId' to multiple groups"

if ($TargetGroupIdString) {
    $TargetGroupIds = @()
    $TargetGroupIds = $TargetGroupIdString.Split(',')
    "## Target group Ids: "
    $TargetGroupIds
}
else {
    # $TargetGroupNameString
    $TargetGroupNames = @()
    $TargetGroupNames = $TargetGroupNameString.Split(',')
    "## Target group Names: "
    $TargetGroupNames
}

try {
    $AADGroups = @()
    foreach ($TargetGroupId in $TargetgroupIds) {
        if ($AADGroups.id -notcontains $TargetGroupId) {
            $AADGroups += Invoke-RjRbRestMethodGraph -Resource "/groups/$TargetGroupId" 
        }
    }
    foreach ($TargetGroupName in $TargetGroupNames) {
        $targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$TargetGroupName'"
        if ($AADGroups.id -notcontains $targetGroup.Id) {
            $AADGroups += $targetGroup
        }
    }

    $beforedate = (Get-Date).AddDays(-1) | Get-Date -Format "yyyy-MM-dd"    
    $filter = 'createdDateTime ge ' + $beforedate + 'T00:00:00Z'
    $NewUsers = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter $filter

    $MigGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$MigGroupId/members"
    $MigrationUsers = @()
    foreach ($migUser in $MigGroupMembers) {
        if ($MigrationUsers.id -notcontains $migUser.id) {
            $MigrationUsers += $migUser
        }
    }
    foreach ($migUser in $NewUsers) {
        if ($MigrationUsers.id -notcontains $migUser.id) {
            $MigrationUsers += $migUser
        }
    }

    foreach ($AADGroup in $AADGroups) {
        $AADGroupMembers = @()
        $AADGroupMembers += (Invoke-RjRbRestMethodGraph -Resource "/groups/$($AADGroup.Id)/members" -OdSelect "Id").id
        [array] $bindings = @()
        foreach ($MigrationUser in $MigrationUsers) {
            $bindingString = "https://graph.microsoft.com/v1.0/directoryObjects/$($MigrationUser.id)"
            if (!($AADgroupMembers.contains($MigrationUser.id)) -and !($bindings.Contains($bindingString))) {
                $bindings += $bindingString
                "## Selecting '$($MigrationUser.userPrincipalName)' for group adding."
            }
        }
        if ($bindings) {
            $GroupJson = @{"members@odata.bind" = $bindings }
            Invoke-RjRbRestMethodGraph -Resource "/groups/$($AADGroup.Id)" -Method Patch -Body $GroupJson 
            "## Added Users to group $($AADGroup.displayName)" 
        }
        else {
            "## All users already in Group $($AADGroup.displayName)"
        }
    }
}
catch {
    $_
}

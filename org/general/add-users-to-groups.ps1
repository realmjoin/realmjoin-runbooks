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

$TargetGroupIdString

$MigGroupId
if ($TargetGroupIdString) {
    $TargetGroupIds = @()
    $TargetGroupIds = $TargetGroupIdString.Split(',')
    $TargetGroupIds
}
else {
    $TargetGroupNameString
    $TargetGroupNames = @()
    $TargetGroupNames = $TargetGroupNameString.Split(',')
    $TargetGroupNames
}
#define TargetgroupIds and MigGroupId variables beforehand
#[string] $MigGroupId = ""
#$TargetGroupIds = @()
$beforedate = (Get-Date).AddDays(-1) | Get-Date -Format "yyyy-MM-dd"
try {
    $AADGroups = @()
    if ($TargetGroupIds) {
        foreach ($TargetGroupId in $TargetgroupIds) {
            $AADGroups += Invoke-RjRbRestMethodGraph -Resource "/groups/$TargetGroupId" 
        }
    }
    else {
        foreach ($TargetGroupName in $TargetGroupNames) {
            $AADGroups += Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$TargetGroupName'"
        }
    }

    $filter = 'createdDateTime ge ' + $beforedate + 'T00:00:00Z'
    $NewUsers = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter $filter

    $MigGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$MigGroupId/members"
    $MigrationUsers = @()
    $MigrationUsers += $MigGroupMembers
    $MigrationUsers += $NewUsers

    foreach ($AADGroup in $AADGroups) {
        $AADGroupMembers = @()
        $AADGroupMembers += (Invoke-RjRbRestMethodGraph -Resource "/groups/$($AADGroup.Id)/members" -OdSelect "Id").id
        [array] $bindings = @()
        foreach ($MigrationUser in $MigrationUsers) {
            $bindingString = "https://graph.microsoft.com/v1.0/directoryObjects/$($MigrationUser.id)"
            if (!($AADgroupMembers.contains($MigrationUser.id)) -and !($bindings.Contains($bindingString))) {

                $bindings += $bindingString
            }
        }
        if ($bindings) {
            $GroupJson = @{"members@odata.bind" = $bindings }
            Invoke-RjRbRestMethodGraph -Resource "/groups/$($AADGroup.Id)" -Method Patch -Body $GroupJson 
            "## added Users to group $($AADGroup.displayName)" 
        }
        else {
            "## all users already in Group $($AADGroup.displayName)"
        }
    }
}
catch {
    $_
}

<#
  .SYNOPSIS
  List all devices owned by group members.

  .DESCRIPTION
  List all devices owned by group members.

  .NOTES
  Permissions: 
  MS Graph (API)
  - Group.Read.All

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" },Microsoft.Graph

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Group" } )]
    [String] $GroupID,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph
$devicelist
$GroupMembers = Get-MgGroupMember -ObjectId $GroupID -All
foreach ($GroupMember in $GroupMembers){
    $UserDevices = Get-MgUserRegisteredDevice -ObjectId $GroupMember -All
    foreach ($UserDevice in $UserDevices){
        $devicelist =+ $UserDevice
    }
}
if ($devicelist) {
    $devicelist | Format-Table -AutoSize -Property "deviceid","userPrincipalName" | Out-String
} else {
    "## No devices found (or no access)."
}
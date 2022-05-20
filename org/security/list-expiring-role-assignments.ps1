<#
  .SYNOPSIS
  List Azure AD role assignments that will expire before a given number of days.

  .DESCRIPTION
  List Azure AD role assignments that will expire before a given number of days.

  .NOTES
  Permissions: MS Graph
  - Organization.Read.All
  - RoleManagement.Read.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
  [ValidateScript( { Use-RJInterface -DisplayName "Maximum days before expiry" } )]
  [int] $Days = 30,
  # CallerName is tracked purely for auditing purposes
  [Parameter(Mandatory = $true)]
  [string] $CallerName
)

Connect-RjRbGraph

$expiringDate = (get-date).AddDays($Days) | Get-Date -Format "yyyy-MM-dd"
$filter = "EndDateTime lt $expiringDate" + "T00:00:00Z"

"## Active AzureAD role assignments that will be expire before $($expiringDate):"
$roleAssignments = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleAssignmentscheduleInstances" -OdFilter $filter
foreach ($roleAssignment in $roleAssignments) {
  $roleName = (Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleDefinitions/$($roleAssignment.roleDefinitionId)").DisplayName
  $roleAssignment | Add-Member -Name "DisplayName" -Value $roleName -MemberType "NoteProperty"
  $user = Invoke-RjRbRestMethodGraph -Resource "/users/$($roleAssignment.principalId)" -ErrorAction SilentlyContinue
  if ($user) {
    $roleAssignment | Add-Member -Name "UserPrincipalName" -Value $user.userPrincipalName -MemberType "NoteProperty"
  }
  else {
    $roleAssignment | Add-Member -Name "UserPrincipalName" -Value "-NotAUser-" -MemberType "NoteProperty"
  }
  $roleAssignment | format-list -Property UserPrincipalName, @{name = "Role"; expression = { $_.DisplayName } }, @{name = "endDate"; expression = { Get-Date $_.endDateTime -Format "yyyy-MM-dd" } }, assignmentType, memberType | Out-String
}
""

"## PIM eligible AzureAD role assignment sthat will expire before $($expiringDate):"
$allPimEligigble = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleEligibilitySchedules" -Beta 
$pimEligible = $allPimEligigble | Where-Object { $_.scheduleInfo.expiration.endDateTime -lt $expiringDate }
foreach ($roleAssignment in $pimEligible) {
  $roleName = (Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleDefinitions/$($roleAssignment.roleDefinitionId)").DisplayName
  $roleAssignment | Add-Member -Name "DisplayName" -Value $roleName -MemberType "NoteProperty"
  $user = Invoke-RjRbRestMethodGraph -Resource "/users/$($roleAssignment.principalId)" -ErrorAction SilentlyContinue
  if ($user) {
    $roleAssignment | Add-Member -Name "UserPrincipalName" -Value $user.userPrincipalName -MemberType "NoteProperty"
  }
  else {
    $roleAssignment | Add-Member -Name "UserPrincipalName" -Value "-NotAUser-" -MemberType "NoteProperty"
  }
  $roleAssignment | format-list -Property UserPrincipalName, @{name = "Role"; expression = { $_.DisplayName } }, @{name = "endDate"; expression = { get-date $_.scheduleInfo.expiration.endDateTime -Format "yyyy-MM-dd" } }, status, memberType | Out-String
}
""

if ((-not $roleAssignments) -and (-not $pimEligible)) {
  "## no matching role assignments found"
}

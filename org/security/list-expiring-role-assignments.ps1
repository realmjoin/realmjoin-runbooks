<#
  .SYNOPSIS
  List Entra ID role assignments that expire soon

  .DESCRIPTION
  Lists the active and PIM eligible Entra ID role assignments that expire within the chosen number of days, so they can be renewed in time. Each entry shows the role, the principal and the expiry date. Nothing is changed.

  .PARAMETER Days
  Assignments that expire within this many days are listed.

  .PARAMETER CallerName
  Name of the user who started the runbook. Set by the portal and recorded for auditing.

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
      "CallerName": {
        "Hide": true
      },
      "Days": {
        "DisplayName": "Expiring within (days)"
      }
    }
  }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
  [int] $Days = 30,
  # CallerName is tracked purely for auditing purposes
  [Parameter(Mandatory = $true)]
  [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

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

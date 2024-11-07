<#
  .SYNOPSIS
  Check if devices in a group are onboarded to Windows Update for Business.

  .DESCRIPTION
  This script checks if single or multiple devices (by Group Object ID) are onboarded to Windows Update for Business.

  .NOTES
  Permissions (Graph):
  - Device.Read.All
  - Group.Read.All
  - WindowsUpdates.ReadWrite.All

  .PARAMETER GroupId
  Object ID of the group to check onboarding status for its members.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .INPUTS
  GroupId, and CallerName
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [Parameter(Mandatory = $true)]
    [string] $GroupId
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph -Force

Write-Output "Checking onboarding status for group members of Group ID: $GroupId"

# Get Group Members
Write-RjRbLog -Message "Fetching Group Members for Group ID: $GroupId" -Verbose

$groupMembersResponse = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId/members" -Method GET
$deviceObjects = $groupMembersResponse | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' } | Select-Object deviceId, displayName

foreach ($deviceObject in $deviceObjects) {
    $DeviceId = $deviceObject.deviceId
    $deviceName = $deviceObject.displayName

    Write-Output "Checking onboarding status for '$deviceName' (ID: $DeviceId)."

    $onboardingResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets/$DeviceId" -Method GET -Beta -ErrorAction SilentlyContinue -ErrorVariable errorGraph
    if ($onboardingResponse) {
        $status = "Onboarded"
        $updateCategories = $onboardingResponse.enrollments.updateCategory -join ", "
        $errors = if ($onboardingResponse.errors) { 
                ($onboardingResponse.errors | ForEach-Object { $_.reason }) -join ", "
        }
        else { 
            "None"
        }
        Write-Output "- Status: $status"
        Write-Output "- Update categories: $updateCategories"
        Write-Output "- Errors: $errors"
    }
    elseif ($errorGraph.message -match '404') {
        Write-Output "- Device is not onboarded / not found (404)."
        Write-RjRbLog -Message "- Error: $($errorGraph.message)" -Verbose
    }
    else {
        Write-Output "- Device is not onboarded - see details in the following."
        Write-Output "- Error: $($errorGraph.message)"
    }
    
}
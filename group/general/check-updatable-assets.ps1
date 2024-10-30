<#
  .SYNOPSIS
  Check if devices in a group are onboarded to Windows Update for Business.

  .DESCRIPTION
  This script checks if single or multiple devices (by Group Object ID) are onboarded to Windows Update for Business.

  .NOTES
  Permissions (Graph):
  - Device.Read.All
  - Group.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementApps.Read.All
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

Write-RjRbLog -Message "Checking onboarding status for group members of Group ID: $GroupId" -Verbose
"## Checking onboarding status for group members of Group ID: $GroupId"

# Get Group Members
Write-RjRbLog -Message "Fetching Group Members for Group ID: $GroupId" -Verbose
"## Fetching Group Members for Group ID: $GroupId"

# $groupMembersUri = "https://graph.microsoft.com/v1.0/groups/$GroupId/members"
$groupMembersResponse = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId/members" -Method GET
$deviceObjects = $groupMembersResponse | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' } | Select-Object deviceId, displayName

foreach ($deviceObject in $deviceObjects) {
    $DeviceId = $deviceObject.deviceId
    $deviceName = $deviceObject.displayName

    Write-RjRbLog -Message "Checking onboarding status for Device ID: $DeviceId" -Verbose
    "## Checking onboarding status for Device ID: $DeviceId"
    # $onboardingUri = "https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets/$DeviceId"
    try {
        $onboardingResponse = Invoke-RjRbRestMethodGraph -Resource "/admin/windows/updates/updatableAssets/$DeviceId" -Method GET -Beta -ErrorAction SilentlyContinue
        if ($onboardingResponse) {
            $status = "Onboarded"
            $updateCategories = $onboardingResponse.enrollments.updateCategory -join ", "
            $errors = if ($onboardingResponse.errors) { 
                    ($onboardingResponse.errors | ForEach-Object { $_.reason }) -join ", "
            }
            else { 
                "None"
            }
            Write-Output "Device '$deviceName' (ID: $DeviceId) is $status."
            Write-Output "Update Categories: $updateCategories"
            Write-Output "Errors: $errors"
        }
        else {
            Write-Output "Device ID: $DeviceId is not onboarded."
        }
    }
    catch {
        $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json
        if ($errorResponse.error.code -eq 'NotFound') {
            Write-Output "Device '$deviceName' (ID: $DeviceId) not found (possibly a non-Windows device)."
        }
        else {
            Write-Output "Device '$deviceName' (ID: $DeviceId) is not onboarded."
            Write-Output "Error: $($errorResponse.error.message)"
        }
    }
    
}

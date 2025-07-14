<#
  .SYNOPSIS
  List all Administrative Template policies and their assignments.

  .DESCRIPTION
  This script retrieves all Administrative Template policies from Intune and displays their assignments.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# Get Administrative Template Policies
Write-RjRbLog -Message "Starting Administrative Template Policies enumeration" -Verbose
Write-RjRbLog -Message "Fetching Administrative Template Policies" -Verbose
"## Administrative Template Policies"
$adminTemplatesResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/groupPolicyConfigurations" -Beta -FollowPaging

Write-RjRbLog -Message "Found $($adminTemplatesResponse.Count) Administrative Template policies" -Verbose

if (-not $adminTemplatesResponse) {
    Write-RjRbLog -Message "No Administrative Template policies found." -Verbose
    "## No Administrative Template policies found."
    return
}

$currentPolicy = 0
$totalPolicies = $adminTemplatesResponse.Count

foreach ($policy in $adminTemplatesResponse) {
    $currentPolicy++
    $policyName = $policy.displayName
    $policyId = $policy.id

    Write-RjRbLog -Message "Processing Administrative Template Policy ($currentPolicy/$totalPolicies): $policyName" -Verbose
    "## Administrative Template Policy: $policyName (ID: $policyId)"

    # Get policy assignments
    Write-RjRbLog -Message "Fetching assignments for policy: $policyName" -Verbose
    $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/groupPolicyConfigurations('$policyId')/assignments" -Beta

    if (-not $assignmentResponse) {
        Write-RjRbLog -Message "No assignments found for policy: $policyName" -Verbose
        "## - No assignments found"
        continue
    }

    Write-RjRbLog -Message "Found $($assignmentResponse.Count) assignments for policy: $policyName" -Verbose
    "## Assignments:"
    foreach ($assignment in $assignmentResponse) {
        if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {
            Write-RjRbLog -Message "Policy '$policyName' is assigned to All Users" -Verbose
            "## - Assigned to: All Users"
        }
        elseif ($assignment.target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget') {
            Write-RjRbLog -Message "Policy '$policyName' is assigned to All Devices" -Verbose
            "## - Assigned to: All Devices"
        }
        elseif ($assignment.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget') {
            $groupId = $assignment.target.groupId
            Write-RjRbLog -Message "Fetching group information for ID: $groupId" -Verbose
            $group = Invoke-RjRbRestMethodGraph -Resource "/groups/$groupId" -ErrorAction SilentlyContinue
            if ($group) {
                Write-RjRbLog -Message "Policy '$policyName' is assigned to group: $($group.displayName)" -Verbose
                "## - Assigned to group: $($group.displayName) (ID: $groupId)"
            }
            else {
                Write-RjRbLog -Message "Group not found for ID: $groupId" -Verbose
                "## - Assigned to group with ID: $groupId (Group not found)"
            }
        }
    }

    ""
}

Write-RjRbLog -Message "Completed listing Administrative Template policies" -Verbose

<#
    .SYNOPSIS
    Check Windows Update for Business enrollment of this group's devices

    .DESCRIPTION
    Checks for every device in this group whether it is registered as an updatable asset in Windows Update for Business. The result shows the enrollment state per update category and any error Windows Update returns. Nothing is changed.

    .PARAMETER GroupId
    Object ID of the group the runbook acts on. Set by the portal from the selected group.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "GroupId": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [string] $GroupId,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph -Force

Write-Output "Checking onboarding status for group members of Group ID: $GroupId"
Write-Output " "

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
        Write-Output "- Status: $status"

        # update categories
        Write-Output "- Update categories: "
        $updateCategories = $onboardingResponse.enrollment
        if ($null -ne $updateCategories) {
            Write-RjRbLog -Message "Categories response: $updateCategories" -Verbose
            foreach ($key in $updateCategories.PSObject.Properties.Name) {
                $updateCategory = $updateCategories.$key
                $updateCategoriesOut = "  - category: $($key), "
                $updateCategoriesOut += "enrollment state: $($updateCategory.enrollmentState), "
                $updateCategoriesOut += "last modified: $($updateCategory.lastModifiedDateTime)"
                Write-Output $updateCategoriesOut
            }
        }
        else {
            Write-Output "None (empty response)."
        }

        # errors
        $errors = if ($onboardingResponse.errors) {
                ($onboardingResponse.errors | ForEach-Object { $_.reason }) -join ", "
        }
        else {
            "None"
        }
        Write-Output "- Errors: $errors"
    }
    elseif ($errorGraph.message -match '404') {
        Write-Output "- Status: Device is not onboarded / not found (404)."
        Write-RjRbLog -Message "- Error: $($errorGraph.message)" -Verbose
    }
    else {
        Write-Output "- Status: Device is not onboarded - see details in the following."
        Write-Output "- Error: $($errorGraph.message)"
    }
    Write-Output " "
}
<#
    .SYNOPSIS
    Check if devices in a group are onboarded to Windows Update for Business.

    .DESCRIPTION
    This runbook checks the Windows Update for Business onboarding status for all device members of a Microsoft Entra ID group.
    It queries each device and reports the enrollment state per update category and any returned error details.
    Use this to validate whether group members are correctly registered as updatable assets.

    .PARAMETER GroupId
    Object ID of the group whose device members will be checked.

    .PARAMETER CallerName
    Caller name for auditing purposes.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [Parameter(Mandatory = $true)]
    [string] $GroupId
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
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
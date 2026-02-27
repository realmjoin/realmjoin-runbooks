<#
    .SYNOPSIS
    Check Intune assignments for one or more group names

    .DESCRIPTION
    This runbook queries Intune policies and optionally app assignments that target the specified group(s).
    It resolves group IDs and reports matching assignments.

    .PARAMETER GroupIDs
    Group IDs of the groups to check assignments for

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .PARAMETER IncludeApps
    If set to true, also evaluates application assignments.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "GroupIDs": {
                "DisplayName": "One or more groups to check assignments for"
            },
            "IncludeApps": {
                "DisplayName": "Include app assignments"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [Parameter(Mandatory = $true)][ValidateScript({ Use-RjRbInterface -Type Graph -Entity Group })]
    [string[]] $GroupIDs,
    [bool] $IncludeApps = $false
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

foreach ($groupId in $GroupIDs) {
    Write-RjRbLog -Message "Processing Group ID: $groupId" -Verbose

    # Get Group ID from Microsoft Entra based on Group ID
    Write-RjRbLog -Message "Fetching Group Details for $groupId" -Verbose
    "## Fetching Group Details for $groupId"
    $groupResponse = Invoke-RjRbRestMethodGraph -Resource "/groups('$groupId')"
    $groupName = $groupResponse.displayName
    if ($groupId) {
        Write-RjRbLog -Message "Group Found! -> Group ID: $groupId, Group Name: $groupName" -Verbose
    }
    else {
        Write-RjRbLog -Message "Group Not Found: $groupId" -ErrorAction Stop
    }

    # Initialize collections to hold relevant policies and applications
    $groupRelevantPolicies = @()
    $groupRelevantCompliancePolicies = @()
    $groupRelevantAppsRequired = @()
    $groupRelevantAppsAvailable = @()
    $groupRelevantAppsUninstall = @()

    # Get Intune Configuration Policies
    Write-RjRbLog -Message "Fetching Intune Configuration Policies" -Verbose
    "## Fetching Intune Configuration Policies"
    $policiesResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/configurationPolicies" -Beta -FollowPaging

    # Check each configuration policy for assignments that match group's ID
    foreach ($policy in $policiesResponse) {
        $policyName = $policy.name
        $policyId = $policy.id

        Write-RjRbLog -Message "Processing Policy: $policyName" -Verbose
        $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/configurationPolicies('$policyId')/assignments" -Beta

        foreach ($assignment in $assignmentResponse) {
            $assignmentReason = $null  # Clear previous reason

            if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {
                $assignmentReason = "All Users"
            }
            elseif ($groupId -eq $assignment.target.groupId) {
                $assignmentReason = "Group Assignment"
            }

            if ($assignmentReason) {
                # Attach the assignment reason to the policy
                Add-Member -InputObject $policy -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                $groupRelevantPolicies += $policy
                break
            }
        }
    }

    # Get Intune Group Policy Configurations
    Write-RjRbLog -Message "Fetching Intune Group Policy Configurations" -Verbose
    "## Fetching Intune Group Policy Configurations"
    $groupPoliciesResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/groupPolicyConfigurations" -Beta -FollowPaging

    # Check each group policy for assignments that match group's ID
    foreach ($grouppolicy in $groupPoliciesResponse) {
        $groupPolicyName = $grouppolicy.displayName
        $groupPolicyId = $grouppolicy.id

        Write-RjRbLog -Message "Processing Group Policy: $groupPolicyName" -Verbose
        $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/groupPolicyConfigurations('$groupPolicyId')/assignments" -Beta

        foreach ($assignment in $assignmentResponse) {
            $assignmentReason = $null  # Clear previous reason

            if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {
                $assignmentReason = "All Users"
            }
            elseif ($groupId -eq $assignment.target.groupId) {
                $assignmentReason = "Group Assignment"
            }

            if ($assignmentReason) {
                Add-Member -InputObject $grouppolicy -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                $groupRelevantPolicies += $grouppolicy
                break
            }
        }
    }

    # Get Intune Device Configurations
    Write-RjRbLog -Message "Fetching Intune Device Configurations" -Verbose
    "## Fetching Intune Device Configurations"
    $deviceConfigsResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/deviceConfigurations" -Beta -FollowPaging

    # Check each device configuration for assignments that match group's ID or all licensed users
    foreach ($config in $deviceConfigsResponse) {
        $configName = $config.displayName
        $configId = $config.id

        Write-RjRbLog -Message "Processing Device Configuration: $configName" -Verbose
        $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/deviceConfigurations('$configId')/assignments" -Beta

        foreach ($assignment in $assignmentResponse) {
            $assignmentReason = $null  # Clear previous reason

            if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {
                $assignmentReason = "All Users"
            }
            elseif ($groupId -eq $assignment.target.groupId) {
                $assignmentReason = "Group Assignment"
            }

            if ($assignmentReason) {
                # Attach the assignment reason to the config object
                Add-Member -InputObject $config -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                $groupRelevantPolicies += $config
                break
            }
        }
    }

    # Get Intune Compliance Policies
    Write-RjRbLog -Message "Fetching Intune Compliance Policies" -Verbose
    "## Fetching Intune Compliance Policies"
    $complianceResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/deviceCompliancePolicies" -Beta -FollowPaging

    # Check each compliance policy for assignments that match group's ID
    foreach ($compliancepolicy in $complianceResponse) {
        $compliancepolicyName = $compliancepolicy.displayName
        $compliancepolicyId = $compliancepolicy.id

        Write-RjRbLog -Message "Processing Compliance Policy: $compliancepolicyName" -Verbose
        $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/deviceCompliancePolicies('$compliancepolicyId')/assignments" -Beta

        foreach ($assignment in $assignmentResponse) {
            if ($groupId -eq $assignment.target.groupId) {
                $groupRelevantCompliancePolicies += $compliancepolicy
                break
            }
        }
    }

    if ($IncludeApps) {
        # Get Intune Applications
        Write-RjRbLog -Message "Fetching Intune Applications" -Verbose
        $appResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceAppManagement/mobileApps" -Beta -FollowPaging

        # Iterate over each application
        foreach ($app in $appResponse) {
            $appName = $app.displayName
            $appId = $app.id

            Write-RjRbLog -Message "Processing Application: $appName" -Verbose

            # Fetch the assignments for the app
            $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceAppManagement/mobileApps('$appId')/assignments" -Beta

            # Iterate over each assignment to check if the group's ID is targeted
            foreach ($assignment in $assignmentResponse) {
                $assignmentReason = $null  # Clear previous reason

                if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {
                    $assignmentReason = "All Users"
                }
                elseif ($groupId -eq $assignment.target.groupId) {
                    $assignmentReason = "Group Assignment"
                }

                if ($assignmentReason) {
                    # Add a new property to the app object to store the assignment reason
                    Add-Member -InputObject $app -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force

                    switch ($assignment.intent) {
                        "required" {
                            $groupRelevantAppsRequired += $app
                            if ($assignmentReason -eq "All Users") { break }
                        }
                        "available" {
                            $groupRelevantAppsAvailable += $app
                            if ($assignmentReason -eq "All Users") { break }
                        }
                        "uninstall" {
                            $groupRelevantAppsUninstall += $app
                            if ($assignmentReason -eq "All Users") { break }
                        }
                    }
                }
            }
        }
    }

    # Generating Results for Group
    Write-RjRbLog -Message "Generating Results for $groupName..." -Verbose
    "## Generating Results for $groupName..."

    # Output the results
    "## ------- Assigned Configuration Profiles for $groupName -------"
    foreach ($policy in $groupRelevantPolicies) {
        $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
        "## Configuration Profile Name: $policyName, Policy ID: $($policy.id), Assignment Reason: $($policy.AssignmentReason)"
    }

    "## ------- Assigned Compliance Policies for $groupName -------"
    foreach ($compliancepolicy in $groupRelevantCompliancePolicies) {
        $compliancepolicyName = if ([string]::IsNullOrWhiteSpace($compliancepolicy.name)) { $compliancepolicy.displayName } else { $compliancepolicy.name }
        "## Compliance Policy Name: $compliancepolicyName, Policy ID: $($compliancepolicy.id)"
    }

    if ($IncludeApps) {
        "## ------- Assigned Apps (Required) for $groupName -------"
        foreach ($app in $groupRelevantAppsRequired) {
            $appName = if ([string]::IsNullOrWhiteSpace($app.name)) { $app.displayName } else { $app.name }
            "## App Name: $appName, App ID: $($app.id), Assignment Reason: $($app.AssignmentReason)"
        }

        "## ------- Assigned Apps (Available) for $groupName -------"
        foreach ($app in $groupRelevantAppsAvailable) {
            $appName = if ([string]::IsNullOrWhiteSpace($app.name)) { $app.displayName } else { $app.name }
            "## App Name: $appName, App ID: $($app.id), Assignment Reason: $($app.AssignmentReason)"
        }

        "## ------- Assigned Apps (Uninstall) for $groupName -------"
        foreach ($app in $groupRelevantAppsUninstall) {
            $appName = if ([string]::IsNullOrWhiteSpace($app.name)) { $app.displayName } else { $app.name }
            "## App Name: $appName, App ID: $($app.id), Assignment Reason: $($app.AssignmentReason)"
        }
    }
}
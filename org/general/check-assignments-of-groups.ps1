<#
  .SYNOPSIS
  Check Intune assignments for a given (or multiple) Group Names.

  .DESCRIPTION
  This script checks the Intune assignments for a single or multiple specified Group Names.

  .NOTES
  Permissions (Graph):
  - User.Read.All
  - Group.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementManagedDevices.Read.All
  - Device.Read.All

  .PARAMETER GroupNames
  Group Names of the groups to check assignments for, separated by commas.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .PARAMETER IncludeApps
  Boolean to specify whether to include application assignments in the search.

  .INPUTS
  GroupNames, CallerName, and IncludeApps
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [Parameter(Mandatory = $true)]
    [string] $GroupNames,
    [bool] $IncludeApps = $false
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

$GroupNamesArray = $GroupNames.Split(',') | ForEach-Object { $_.Trim() }

foreach ($groupName in $GroupNamesArray) {
    Write-RjRbLog -Message "Processing Group: $groupName" -Verbose

    # Get Group ID from Microsoft Entra based on Group Name
    Write-RjRbLog -Message "Fetching Group Details for $groupName" -Verbose
    "## Fetching Group Details for $groupName"
    $groupDetailsUri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$groupName'"
    $groupResponse = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$groupName'"
    $groupId = $groupResponse.id
    if ($groupId) {
        Write-RjRbLog -Message "Group Found! -> Group ID: $groupId" -Verbose
    } else {
        Write-RjRbLog -Message "Group Not Found: $groupName" -ErrorAction Stop
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
        $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')/assignments"
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
        $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations('$groupPolicyId')/assignments"
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
        $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations('$configId')/assignments"
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
        $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies('$compliancepolicyId')/assignments"
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

            # Construct the URI to get assignments for the current app
            $assignmentsUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps('$appId')/assignments"

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
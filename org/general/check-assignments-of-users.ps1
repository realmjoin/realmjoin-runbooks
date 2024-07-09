<#
  .SYNOPSIS
  Check Intune assignments for a given (or multiple) User Principal Names (UPNs).

  .DESCRIPTION
  This script checks the Intune assignments for a single or multiple specified UPNs.

  .NOTES
  Permissions (Graph):
  - User.Read.All
  - Group.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementManagedDevices.Read.All
  - Device.Read.All

  .PARAMETER UPN
  User Principal Names of the users to check assignments for, separated by commas.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .PARAMETER IncludeApps
  Boolean to specify whether to include application assignments in the search.

  .INPUTS
  UPN, CallerName, and IncludeApps
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $UPN,
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [bool] $IncludeApps = $false
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

$UPNs = $UPN.Split(',') | ForEach-Object { $_.Trim() }

foreach ($userUPN in $UPNs) {
    Write-Host "Processing UPN: $userUPN" -ForegroundColor Green

    # Get User ID from Microsoft Entra based on UPN
    Write-Host "Fetching User Details for $userUPN" -ForegroundColor Yellow
    $userDetailsUri = "https://graph.microsoft.com/v1.0/users?`$filter=userPrincipalName eq '$userUPN'"
    $userResponse = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter "userPrincipalName eq '$userUPN'"
    $userId = $userResponse.id
    if ($userId) {
        Write-RjRbLog -Message "User Found! -> User ID: $userId" -Verbose
        Write-Host "User Found! -> User ID: $userId" -ForegroundColor Green
    } else {
        Write-RjRbLog -Message "User Not Found: $userUPN" -ErrorAction Stop
        Write-Host "User Not Found: $userUPN" -ForegroundColor Red
    }

    # Get User Group Memberships
    Write-Host "Fetching Group Memberships for $userUPN" -ForegroundColor Yellow
    $groupResponse = Invoke-RjRbRestMethodGraph -Resource "/users/$userId/transitiveMemberOf"
    $userGroupIds = $groupResponse | ForEach-Object { $_.id }
    $userGroupNames = $groupResponse | ForEach-Object { $_.displayName }

    Write-RjRbLog -Message "User Group Memberships: $($userGroupNames -join ', ')" -Verbose
    Write-Host "User Group Memberships: $($userGroupNames -join ', ')" -ForegroundColor Green

    # Initialize collections to hold relevant policies and applications
    $userRelevantPolicies = @()
    $userRelevantCompliancePolicies = @()
    $userRelevantAppsRequired = @()
    $userRelevantAppsAvailable = @()
    $userRelevantAppsUninstall = @()

    # Get Intune Configuration Policies
    Write-Host "Fetching Intune Configuration Policies" -ForegroundColor Yellow
    $policiesResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/configurationPolicies" -Beta -FollowPaging

    # Check each configuration policy for assignments that match user's groups
    foreach ($policy in $policiesResponse) {
        $policyName = $policy.name
        $policyId = $policy.id

        Write-Host "Processing Policy: $policyName" -ForegroundColor Blue
        $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')/assignments"
        $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/configurationPolicies('$policyId')/assignments" -Beta

        foreach ($assignment in $assignmentResponse) {
            $assignmentReason = $null  # Clear previous reason

            if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {
                $assignmentReason = "All Users"
            }
            elseif ($userGroupIds -contains $assignment.target.groupId) {
                $assignmentReason = "Group Assignment"
            }

            if ($assignmentReason) {
                # Attach the assignment reason to the policy
                Add-Member -InputObject $policy -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                $userRelevantPolicies += $policy
                break
            }
        }
    }

    # Get Intune Group Policy Configurations
    Write-Host "Fetching Intune Group Policy Configurations" -ForegroundColor Yellow
    $groupPoliciesResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/groupPolicyConfigurations" -Beta -FollowPaging

    # Check each group policy for assignments that match user's groups
    foreach ($grouppolicy in $groupPoliciesResponse) {
        $groupPolicyName = $grouppolicy.displayName
        $groupPolicyId = $grouppolicy.id

        Write-Host "Processing Group Policy: $groupPolicyName" -ForegroundColor Blue
        $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations('$groupPolicyId')/assignments"
        $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/groupPolicyConfigurations('$groupPolicyId')/assignments" -Beta

        foreach ($assignment in $assignmentResponse) {
            $assignmentReason = $null  # Clear previous reason

            if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {
                $assignmentReason = "All Users"
            }
            elseif ($userGroupIds -contains $assignment.target.groupId) {
                $assignmentReason = "Group Assignment"
            }

            if ($assignmentReason) {
                Add-Member -InputObject $grouppolicy -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                $userRelevantPolicies += $grouppolicy
                break
            }
        }
    }

    # Get Intune Device Configurations
    Write-Host "Fetching Intune Device Configurations" -ForegroundColor Yellow
    $deviceConfigsResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/deviceConfigurations" -Beta -FollowPaging

    # Check each device configuration for assignments that match user's groups or all licensed users
    foreach ($config in $deviceConfigsResponse) {
        $configName = $config.displayName
        $configId = $config.id

        Write-Host "Processing Device Configuration: $configName" -ForegroundColor Blue
        $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations('$configId')/assignments"
        $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/deviceConfigurations('$configId')/assignments" -Beta

        foreach ($assignment in $assignmentResponse) {
            $assignmentReason = $null  # Clear previous reason

            if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {
                $assignmentReason = "All Users"
            }
            elseif ($userGroupIds -contains $assignment.target.groupId) {
                $assignmentReason = "Group Assignment"
            }

            if ($assignmentReason) {
                # Attach the assignment reason to the config object
                Add-Member -InputObject $config -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                $userRelevantPolicies += $config
                break
            }
        }
    }

    # Get Intune Compliance Policies
    Write-Host "Fetching Intune Compliance Policies" -ForegroundColor Yellow
    $complianceResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/deviceCompliancePolicies" -Beta -FollowPaging

    # Check each compliance policy for assignments that match user's groups
    foreach ($compliancepolicy in $complianceResponse) {
        $compliancepolicyName = $compliancepolicy.displayName
        $compliancepolicyId = $compliancepolicy.id

        Write-Host "Processing Compliance Policy: $compliancepolicyName" -ForegroundColor Blue
        $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies('$compliancepolicyId')/assignments"
        $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/deviceCompliancePolicies('$compliancepolicyId')/assignments" -Beta

        foreach ($assignment in $assignmentResponse) {
            if ($userGroupIds -contains $assignment.target.groupId) {
                $userRelevantCompliancePolicies += $compliancepolicy
                break
            }
        }
    }

    if ($IncludeApps) {
        # Get Intune Applications
        Write-Host "Fetching Intune Applications" -ForegroundColor Yellow
        $appResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceAppManagement/mobileApps" -Beta -FollowPaging

        # Iterate over each application
        foreach ($app in $appResponse) {
            $appName = $app.displayName
            $appId = $app.id

            Write-Host "Processing Application: $appName"

 -ForegroundColor Blue
            # Construct the URI to get assignments for the current app
            $assignmentsUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps('$appId')/assignments"

            # Fetch the assignments for the app
            $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceAppManagement/mobileApps('$appId')/assignments" -Beta

            # Iterate over each assignment to check if the user's groups are targeted
            foreach ($assignment in $assignmentResponse) {
                $assignmentReason = $null  # Clear previous reason

                if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {
                    $assignmentReason = "All Users"
                }
                elseif ($userGroupIds -contains $assignment.target.groupId) {
                    $assignmentReason = "Group Assignment"
                }

                if ($assignmentReason) {
                    # Add a new property to the app object to store the assignment reason
                    Add-Member -InputObject $app -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force

                    switch ($assignment.intent) {
                        "required" {
                            $userRelevantAppsRequired += $app
                            if ($assignmentReason -eq "All Users") { break }
                        }
                        "available" {
                            $userRelevantAppsAvailable += $app
                            if ($assignmentReason -eq "All Users") { break }
                        }
                        "uninstall" {
                            $userRelevantAppsUninstall += $app
                            if ($assignmentReason -eq "All Users") { break }
                        }
                    }
                }
            }
        }
    }

    # Generating Results for User
    Write-RjRbLog -Message "Generating Results for $userUPN..." -Verbose
    Write-Host "Generating Results for $userUPN..." -ForegroundColor Yellow

    # Output the results
    Write-Host "------- Assigned Configuration Profiles for $userUPN -------" -ForegroundColor Cyan
    foreach ($policy in $userRelevantPolicies) {
        $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
        Write-Host "Configuration Profile Name: $policyName, Policy ID: $($policy.id), Assignment Reason: $($policy.AssignmentReason)" -ForegroundColor White
    }

    Write-Host "------- Assigned Compliance Policies for $userUPN -------" -ForegroundColor Cyan
    foreach ($compliancepolicy in $userRelevantCompliancePolicies) {
        $compliancepolicyName = if ([string]::IsNullOrWhiteSpace($compliancepolicy.name)) { $compliancepolicy.displayName } else { $compliancepolicy.name }
        Write-Host "Compliance Policy Name: $compliancepolicyName, Policy ID: $($compliancepolicy.id)" -ForegroundColor White
    }

    if ($IncludeApps) {
        Write-Host "------- Assigned Apps (Required) for $userUPN -------" -ForegroundColor Cyan
        foreach ($app in $userRelevantAppsRequired) {
            $appName = if ([string]::IsNullOrWhiteSpace($app.name)) { $app.displayName } else { $app.name }
            Write-Host "App Name: $appName, App ID: $($app.id), Assignment Reason: $($app.AssignmentReason)" -ForegroundColor White
        }

        Write-Host "------- Assigned Apps (Available) for $userUPN -------" -ForegroundColor Cyan
        foreach ($app in $userRelevantAppsAvailable) {
            $appName = if ([string]::IsNullOrWhiteSpace($app.name)) { $app.displayName } else { $app.name }
            Write-Host "App Name: $appName, App ID: $($app.id), Assignment Reason: $($app.AssignmentReason)" -ForegroundColor White
        }

        Write-Host "------- Assigned Apps (Uninstall) for $userUPN -------" -ForegroundColor Cyan
        foreach ($app in $userRelevantAppsUninstall) {
            $appName = if ([string]::IsNullOrWhiteSpace($app.name)) { $app.displayName } else { $app.name }
            Write-Host "App Name: $appName, App ID: $($app.id), Assignment Reason: $($app.AssignmentReason)" -ForegroundColor White
        }
    }
}
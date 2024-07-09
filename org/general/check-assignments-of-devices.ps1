<#
  .SYNOPSIS
  Check Intune assignments for a given (or multiple) Device Names.

  .DESCRIPTION
  This script checks the Intune assignments for a single or multiple specified Device Names.

  .NOTES
  Permissions (Graph):
  - Device.Read.All
  - Group.Read.All
  - DeviceManagementConfiguration.Read.All
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementApps.Read.All

  .PARAMETER DeviceNames
  Device Names of the devices to check assignments for, separated by commas.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .PARAMETER IncludeApps
  Boolean to specify whether to include application assignments in the search.

  .INPUTS
  DeviceNames, CallerName, and IncludeApps
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [Parameter(Mandatory = $true)]
    [string] $DeviceNames,
    [bool] $IncludeApps = $false
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

$DeviceNamesArray = $DeviceNames.Split(',') | ForEach-Object { $_.Trim() }

foreach ($deviceName in $DeviceNamesArray) {
    Write-RjRbLog -Message "Processing Device: $deviceName" -Verbose

    # Get Device ID from Microsoft Entra based on Device Name
    Write-RjRbLog -Message "Fetching Device Details for $deviceName" -Verbose
    "## Fetching Device Details for $deviceName"
    $deviceDetailsUri = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$deviceName'"
    $deviceResponse = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "displayName eq '$deviceName'"
    $deviceId = $deviceResponse.id
    if ($deviceId) {
        Write-RjRbLog -Message "Device Found! -> Device ID: $deviceId" -Verbose
    } else {
        Write-RjRbLog -Message "Device Not Found: $deviceName" -ErrorAction Stop
    }

    # Get Device Group Memberships
    Write-RjRbLog -Message "Fetching Group Memberships for $deviceName" -Verbose
    $groupResponse = Invoke-RjRbRestMethodGraph -Resource "/devices/$deviceId/transitiveMemberOf"
    $deviceGroupIds = $groupResponse | ForEach-Object { $_.id }
    $deviceGroupNames = $groupResponse | ForEach-Object { $_.displayName }

    Write-RjRbLog -Message "Device Group Memberships: $($deviceGroupNames -join ', ')" -Verbose
    "## Device Group Memberships: $($deviceGroupNames -join ', ')"

    # Initialize collections to hold relevant policies and applications
    $deviceRelevantPolicies = @()
    $deviceRelevantCompliancePolicies = @()
    $deviceRelevantAppsRequired = @()
    $deviceRelevantAppsAvailable = @()
    $deviceRelevantAppsUninstall = @()

    # Get Intune Configuration Policies
    Write-RjRbLog -Message "Fetching Intune Configuration Policies" -Verbose
    "## Fetching Intune Configuration Policies"
    $policiesResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/configurationPolicies" -Beta -FollowPaging

    # Check each configuration policy for assignments that match device's groups
    foreach ($policy in $policiesResponse) {
        $policyName = $policy.name
        $policyId = $policy.id

        Write-RjRbLog -Message "Processing Policy: $policyName" -Verbose
        $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')/assignments"
        $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/configurationPolicies('$policyId')/assignments" -Beta

        foreach ($assignment in $assignmentResponse) {
            $assignmentReason = $null  # Clear previous reason

            if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget') {
                $assignmentReason = "All Devices"
            }
            elseif ($deviceGroupIds -contains $assignment.target.groupId) {
                $assignmentReason = "Group Assignment"
            }

            if ($assignmentReason) {
                # Attach the assignment reason to the policy
                Add-Member -InputObject $policy -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                $deviceRelevantPolicies += $policy
                break
            }
        }
    }

    # Get Intune Group Policy Configurations
    Write-RjRbLog -Message "Fetching Intune Group Policy Configurations" -Verbose
    "## Fetching Intune Group Policy Configurations"
    $groupPoliciesResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/groupPolicyConfigurations" -Beta -FollowPaging

    # Check each group policy for assignments that match device's groups
    foreach ($grouppolicy in $groupPoliciesResponse) {
        $groupPolicyName = $grouppolicy.displayName
        $groupPolicyId = $grouppolicy.id

        Write-RjRbLog -Message "Processing Group Policy: $groupPolicyName" -Verbose
        $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations('$groupPolicyId')/assignments"
        $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/groupPolicyConfigurations('$groupPolicyId')/assignments" -Beta

        foreach ($assignment in $assignmentResponse) {
            $assignmentReason = $null  # Clear previous reason

            if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget') {
                $assignmentReason = "All Devices"
            }
            elseif ($deviceGroupIds -contains $assignment.target.groupId) {
                $assignmentReason = "Group Assignment"
            }

            if ($assignmentReason) {
                Add-Member -InputObject $grouppolicy -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                $deviceRelevantPolicies += $grouppolicy
                break
            }
        }
    }

    # Get Intune Device Configurations
    Write-RjRbLog -Message "Fetching Intune Device Configurations" -Verbose
    "## Fetching Intune Device Configurations"
    $deviceConfigsResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/deviceConfigurations" -Beta -FollowPaging

    # Check each device configuration for assignments that match device's groups or all devices
    foreach ($config in $deviceConfigsResponse) {
        $configName = $config.displayName
        $configId = $config.id

        Write-RjRbLog -Message "Processing Device Configuration: $configName" -Verbose
        $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations('$configId')/assignments"
        $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/deviceConfigurations('$configId')/assignments" -Beta

        foreach ($assignment in $assignmentResponse) {
            $assignmentReason = $null  # Clear previous reason

            if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget') {
                $assignmentReason = "All Devices"
            }
            elseif ($deviceGroupIds -contains $assignment.target.groupId) {
                $assignmentReason = "Group Assignment"
            }

            if ($assignmentReason) {
                # Attach the assignment reason to the config object
                Add-Member -InputObject $config -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                $deviceRelevantPolicies += $config
                break
            }
        }
    }

    # Get Intune Compliance Policies
    Write-RjRbLog -Message "Fetching Intune Compliance Policies" -Verbose
    "## Fetching Intune Compliance Policies"
    $complianceResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/deviceCompliancePolicies" -Beta -FollowPaging

    # Check each compliance policy for assignments that match device's groups
    foreach ($compliancepolicy in $complianceResponse) {
        $compliancepolicyName = $compliancepolicy.displayName
        $compliancepolicyId = $compliancepolicy.id

        Write-RjRbLog -Message "Processing Compliance Policy: $compliancepolicyName" -Verbose
        $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies('$compliancepolicyId')/assignments"
        $assignmentResponse = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/deviceCompliancePolicies('$compliancepolicyId')/assignments" -Beta

        foreach ($assignment in $assignmentResponse) {
            if ($deviceGroupIds -contains $assignment.target.groupId) {
                $deviceRelevantCompliancePolicies += $compliancepolicy
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

            # Iterate over each assignment to check if the device's groups are targeted
            foreach ($assignment in $assignmentResponse) {
                $assignmentReason = $null  # Clear previous reason

                if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget') {
                    $assignmentReason = "All Devices"
                }
                elseif ($deviceGroupIds -contains $assignment.target.groupId) {
                    $assignmentReason = "Group Assignment"
                }

                if ($assignmentReason) {
                    # Add a new property to the app object to store the assignment reason
                    Add-Member -InputObject $app -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force

                    switch ($assignment.intent) {
                        "required" {
                            $deviceRelevantAppsRequired += $app
                            if ($assignmentReason -eq "All Devices") { break }
                        }
                        "available" {
                            $deviceRelevantAppsAvailable += $app
                            if ($assignmentReason -eq "All Devices") { break }
                        }
                        "uninstall" {
                            $deviceRelevantAppsUninstall += $app
                            if ($assignmentReason -eq "All Devices") { break }
                        }
                    }
                }
            }
        }
    }

    # Generating Results for Device
    Write-RjRbLog -Message "Generating Results for $deviceName..." -Verbose
    "## Generating Results for $deviceName..."

    # Output the results
    "## ------- Assigned Configuration Profiles for $deviceName -------"
    foreach ($policy in $deviceRelevantPolicies) {
        $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
        "## Configuration Profile Name: $policyName, Policy ID: $($policy.id), Assignment Reason: $($policy.AssignmentReason)"
    }

    "## ------- Assigned Compliance Policies for $deviceName -------"
    foreach ($compliancepolicy in $deviceRelevantCompliancePolicies) {
        $compliancepolicyName = if ([string]::IsNullOrWhiteSpace($compliancepolicy.name)) { $compliancepolicy.displayName } else { $compliancepolicy.name }
        "## Compliance Policy Name: $compliancepolicyName, Policy ID: $($compliancepolicy.id)"
    }

    if ($IncludeApps) {
        "## ------- Assigned Apps (Required) for $deviceName -------"
        foreach ($app in $deviceRelevantAppsRequired) {
            $appName = if ([string]::IsNullOrWhiteSpace($app.name)) { $app.displayName } else { $app.name }
            "## App Name: $appName, App ID: $($app.id), Assignment Reason: $($app.AssignmentReason)"
        }

        "## ------- Assigned Apps (Available) for $deviceName -------"
        foreach ($app in $deviceRelevantAppsAvailable) {
            $appName = if ([string]::IsNullOrWhiteSpace($app.name)) { $app.displayName } else { $app.name }
            "## App Name: $appName, App ID: $($app.id), Assignment Reason: $($app.AssignmentReason)" 
        }

        "## ------- Assigned Apps (Uninstall) for $deviceName -------" 
        foreach ($app in $deviceRelevantAppsUninstall) {
            $appName = if ([string]::IsNullOrWhiteSpace($app.name)) { $app.displayName } else { $app.name }
            "## App Name: $appName, App ID: $($app.id), Assignment Reason: $($app.AssignmentReason)"
        }
    }
}

Write-Host "Script execution completed." -ForegroundColor Green

# https://gitlab.c4a8.net/modern-workplace-code/RJRunbookBacklog/-/issues/86

<#
  .SYNOPSIS
  List all AutoPilot Devices.

  .DESCRIPTION
  This runbook lists all AutoPilot devices with specified properties.

  .NOTES
  Permissions:
  MS Graph (API)
  - DeviceManagementServiceConfig.Read.All

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.0" }

param(
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph

# Retrieve all Autopilot devices
$autopilotDevices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -Beta -ErrorAction SilentlyContinue -FollowPaging

if ($autopilotDevices) {
    foreach ($device in $autopilotDevices) {

        $deviceInfo = [PSCustomObject]@{
            Id                              = $device.id
            SerialNumber                    = $device.serialNumber
            GroupTag                        = $device.groupTag
            EnrollmentState                 = $device.enrollmentState
            DeploymentProfileAssignmentStatus = $device.deploymentProfileAssignmentStatus
            RemediationState                = $device.remediationState
            DeploymentProfileAssignmentDate = $device.deploymentProfileAssignedDateTime
            LastContactedDateTime           = $device.lastContactedDateTime
        }

        "## Display device information"
        "Id: $($deviceInfo.Id)"
        "SerialNumber: $($deviceInfo.SerialNumber)"
        "GroupTag: $($deviceInfo.GroupTag)"
        "EnrollmentState: $($deviceInfo.EnrollmentState)"
        "DeploymentProfileAssignmentStatus: $($deviceInfo.DeploymentProfileAssignmentStatus)"
        "RemediationState: $($deviceInfo.RemediationState)"
        "DeploymentProfileAssignmentDate: $($deviceInfo.DeploymentProfileAssignmentDate)"
        "LastContactedDateTime: $($deviceInfo.LastContactedDateTime)"
        "-----------------------------"
    }
} else {
    "No AutoPilot devices found."
}

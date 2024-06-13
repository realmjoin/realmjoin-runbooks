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

param()

Connect-RjRbGraph

# Retrieve all Autopilot devices
$autopilotDevices = Invoke-RjRbRestMethodGraph -Resource "/beta/deviceManagement/windowsAutopilotDeviceIdentities" -ErrorAction SilentlyContinue

if ($autopilotDevices.value) {
    foreach ($device in $autopilotDevices.value) {

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

        # Display device information
        Write-Host "Id: $($deviceInfo.Id)"
        Write-Host "SerialNumber: $($deviceInfo.SerialNumber)"
        Write-Host "GroupTag: $($deviceInfo.GroupTag)"
        Write-Host "EnrollmentState: $($deviceInfo.EnrollmentState)"
        Write-Host "DeploymentProfileAssignmentStatus: $($deviceInfo.DeploymentProfileAssignmentStatus)"
        Write-Host "RemediationState: $($deviceInfo.RemediationState)"
        Write-Host "DeploymentProfileAssignmentDate: $($deviceInfo.DeploymentProfileAssignmentDate)"
        Write-Host "LastContactedDateTime: $($deviceInfo.LastContactedDateTime)"
        Write-Host "-----------------------------"
    }
} else {
    Write-Host "No AutoPilot devices found."
}

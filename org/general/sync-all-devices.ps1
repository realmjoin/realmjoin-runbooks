<#
  .SYNOPSIS
  Sync all Intune devices.

  .DESCRIPTION
  This runbook triggers a sync operation for all Windows devices managed by Microsoft Intune.
  It retrieves all managed Windows devices and sends a sync command to each device.
  This is useful for forcing devices to check in with Intune and apply any pending policies or configurations.

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }

param (
  # CallerName is tracked purely for auditing purposes
  [Parameter(Mandatory = $true)]
  [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$mgdDevices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -FollowPaging -OdFilter "operatingSystem eq 'Windows'" -OdSelect "id,deviceName,operatingSystem"

$mgdDevices | ForEach-Object {
  "## Triggering Sync: $($_.deviceName)"
  Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($_.id)/syncDevice" -Method Post -ErrorAction SilentlyContinue
}

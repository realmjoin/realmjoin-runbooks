<#
  .SYNOPSIS
  Sync all Intune Windows devices

  .DESCRIPTION
  This runbook triggers a sync operation for all Windows devices managed by Microsoft Intune.
  It forces devices to check in and apply pending policies and configurations.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

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

<#
  .SYNOPSIS
  Sync all Intune devices.

  .DESCRIPTION
  Sync all Intune devices.

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

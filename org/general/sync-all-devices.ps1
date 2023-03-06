<#
  .SYNOPSIS
  Sync all Intune devices.

  .DESCRIPTION
  Sync all Intune devices. 

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param (
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

$mgdDevices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -FollowPaging -OdFilter "operatingSystem eq 'Windows'" -OdSelect "id,deviceName,operatingSystem"

$mgdDevices | ForEach-Object {
    "## Triggering Sync: $($_.deviceName)"
    Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($_.id)/syncDevice" -Method Post -ErrorAction SilentlyContinue 
}
#change
#more commits bc i thought i knew what i was doing but turns out i didnt
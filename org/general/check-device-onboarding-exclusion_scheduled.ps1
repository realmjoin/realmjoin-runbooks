<#
  .SYNOPSIS
  Add unenrolled Autopilot devices to an exclusion group

  .DESCRIPTION
  This runbook identifies Windows Autopilot devices that are not yet enrolled in Intune and ensures they are members of a configured exclusion group.
  It also removes devices from the group once they are no longer in scope.

  .PARAMETER exclusionGroupName
  Display name of the exclusion group to manage.

  .PARAMETER maxAgeInDays
  Maximum age in days for recently enrolled devices to be considered in grace scope.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
      "CallerName": {
        "Hide": true
      },
      "exclusionGroupName": {
        "DisplayName": "Exclusion group name"
      },
      "maxAgeInDays": {
        "DisplayName": "Max age in days"
      }
    }
  }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

param(
  # EntraID exclusion group for Defender Compliance.
  [string]$exclusionGroupName = "cfg - Intune - Windows - Compliance for unenrolled Autopilot devices (devices)",
  [int] $maxAgeInDays = 1,
  # CallerName is tracked purely for auditing purposes
  [Parameter(Mandatory = $true)]
  [string]$CallerName
)

Connect-RjRbGraph

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

$exclusionGroupId = (Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$exclusionGroupName'").id
if (-not $exclusionGroupId) {
  "## Create the exclusion group"
  $mailNickname = $exclusionGroupName.Replace(" ", "").Replace("-", "").Replace("(", "").Replace(")", "")
  if ($mailNickname.Length -gt 50) {
    $mailNickname = $mailNickname.Substring(0, 50)
  }
  $body = @{
    displayName     = $exclusionGroupName
    mailEnabled     = $false
    mailNickname    = $mailNickname
    securityEnabled = $true
  }
  $group = Invoke-RjRbRestMethodGraph -Resource "/groups" -Method Post -Body $body
  $exclusionGroupId = $group.id
  "## Sleep for 10 seconds to allow the group to be created"
  Start-Sleep -Seconds 10
}

$InGraceDevices = @()

## Get all Autopiolt Devices
$APDevices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -FollowPaging

"## Search for the Autopilot Devices not yet present in Intune"
$count = 0;
$APDevices | Where-Object { $_.enrollmentState -ne "enrolled" } | ForEach-Object {
  $device = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$($_.azureActiveDirectoryDeviceId)'"
  if ($device) {
    $InGraceDevices += $device
    $count++;
  }
}
"## $count devices found."
""
"## Search for Intune devices younger than maxAgeInDays"
$count = 0
$intuneDevices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -FollowPaging
$intuneDevices | Where-Object { ((Get-date $_.enrolledDateTime) -ge (Get-Date).AddDays(-$maxAgeInDays)) -and ($_.operatingSystem -eq "Windows") } | ForEach-Object {
  $device = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$($_.azureADDeviceId)'"
  if ($device) {
    $InGraceDevices += $device
    #"$($device.displayName):$($_.enrolledDateTime)"
    $count++;
  }
}
"## $count devices found."
""

## Get current members of the exclusion group
$exclusionGroupMembers = Invoke-RjRbRestMethodGraph -Resource "/groups/$exclusionGroupId/members" -FollowPaging

"## Remove members from the group that are not in the InGraceDevices list"
$count = 0;
$exclusionGroupMembers | Where-Object { $InGraceDevices.id -notcontains $_.id } | ForEach-Object {
  $deviceId = $_.id
  $count++;
  Invoke-RjRbRestMethodGraph -Resource "/groups/$exclusionGroupId/members/$($_.id)/`$ref" -Method Delete -ErrorAction SilentlyContinue | Out-Null
  $exclusionGroupMembers = $exclusionGroupMembers | Where-Object { $_.id -ne $deviceId }
}
"## $count devices removed."
""
"## Add members to the group that are in the InGraceDevices list and not yet members of the group"
$count = 0;
$InGraceDevices | Where-Object { $exclusionGroupMembers.id -notcontains $_.id } | ForEach-Object {
  $body = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($_.id)" }
  Invoke-RjRbRestMethodGraph -Resource "/groups/$exclusionGroupId/members/`$ref" -Method Post -Body $body -ErrorAction SilentlyContinue | Out-Null
  $exclusionGroupMembers += $_
  $count++;
}
"## $count devices added."

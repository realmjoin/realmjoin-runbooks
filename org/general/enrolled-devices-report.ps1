<#
  .SYNOPSIS
  Show recent initial device enrollments.

  .DESCRIPTION
  Show recent initial device enrollments, grouped by a category/attribute.

  .NOTES
  Permissions: 
  MS Graph (API):

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
  [ValidateScript( { Use-RJInterface -DisplayName "Time range (in weeks)" } )]
  [int] $Weeks = 50,
  ## How to group results?
  # 0 - no grouping
  # 1 - AzureAD User properties
  # 2 - AzureAD Device properties
  # 3 - Intune device properties
  # 4 - AutoPilot properties
  [int] $groupingSource = 1,
  # Examples:
  #
  # Autopilot:
  # - "groupTag"
  # - "systemFamily"
  # - "skuNumber"
  #
  # AzureAD User:
  # - "city"
  # - "companyName"
  # - "department"
  # - "officeLocation"
  # - "preferredLanguage"
  # - "state"
  # - "usageLocation"
  # - "manager"
  #
  # AzureAD Device:
  # - "manufacturer"
  # - "model"
  #
  # Intune Device:
  # - "isEncrypted"
  [string] $groupingAttribute = "country"
)

Connect-RjRbGraph

# find cutoff point in time
$date = (Get-Date) - (New-TimeSpan -Days ($Weeks * 7))

# get AutoPilot-Devices newer than cutoff
$devices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/windowsAutopilotDeviceIdentities" -Beta | Where-Object { ([datetime]$_.deploymentProfileAssignedDateTime) -ge $date } 

"Grouping by:"

if ($groupingSource -eq 0) {
  " - no grouping"
  ""

  $devices | ForEach-Object {
    $intuneDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($_.managedDeviceId)" -ErrorAction SilentlyContinue 
  
    $output = [PSCustomObject]@{
      Serial         = $_.serialNumber
      User           = ""
      Model          = $_.model
      AssignmentDate = [datetime]($_.deploymentProfileAssignedDateTime)
    }
    if ($intuneDevice -and $intuneDevice.userPrincipalName) {
      $output.User = $intuneDevice.userPrincipalName
    }

    $output
  } | Sort-Object -Property "AssignmentDate" | Format-Table -AutoSize | Out-String
}

if ($groupingSource -eq 1) {
  "AzureAD User: $groupingAttribute"
  ""
  $devices | ForEach-Object {
    $intuneDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($_.managedDeviceId)" -ErrorAction SilentlyContinue 
    if ($intuneDevice -and $intuneDevice.userId) {
      $azureADUser = Invoke-RjRbRestMethodGraph -Resource "/users/$($intuneDevice.userId)" -OdSelect $groupingAttribute -ErrorAction SilentlyContinue 
    }

    $output = [PSCustomObject]@{
      Serial             = $_.serialNumber
      User               = ""
      Model              = $_.model
      AssignmentDate     = [datetime]($_.deploymentProfileAssignedDateTime)
      $groupingAttribute = ""
    }
    if ($intuneDevice -and $intuneDevice.userPrincipalName) {
      $output.User = $intuneDevice.userPrincipalName
    }
    if ($azureADUser) {
      $output.($groupingAttribute) = $azureADUser.($groupingAttribute)
    }

    $output
  } | Sort-Object -Property "$groupingAttribute", "AssignmentDate" | Format-Table -Property "Serial", "User", "Model", "AssignmentDate" -GroupBy "$groupingAttribute" -AutoSize | Out-String
}

if ($groupingSource -eq 2) {
  "AzureAD Device: $groupingAttribute"
  ""
  $devices | ForEach-Object {
    $intuneDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($_.managedDeviceId)" -ErrorAction SilentlyContinue 
    $azureADDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$($_.azureAdDeviceId)'" -ErrorAction SilentlyContinue 

    $output = [PSCustomObject]@{
      Serial             = $_.serialNumber
      User               = ""
      Model              = $_.model
      AssignmentDate     = [datetime]($_.deploymentProfileAssignedDateTime)
      $groupingAttribute = ""
    }
    if ($intuneDevice -and $intuneDevice.userPrincipalName) {
      $output.User = $intuneDevice.userPrincipalName
    }
    if ($azureADDevice) {
      $output.($groupingAttribute) = $azureADDevice.($groupingAttribute)
    }

    $output
  } | Sort-Object -Property "$groupingAttribute", "AssignmentDate" | Format-Table -Property "Serial", "User", "Model", "AssignmentDate" -GroupBy "$groupingAttribute" -AutoSize | Out-String
}

if ($groupingSource -eq 3) {
  "Intune Device: $groupingAttribute"
  ""
  $devices | ForEach-Object {
    $intuneDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($_.managedDeviceId)" -ErrorAction SilentlyContinue 

    $output = [PSCustomObject]@{
      Serial             = $_.serialNumber
      User               = ""
      Model              = $_.model
      AssignmentDate     = [datetime]($_.deploymentProfileAssignedDateTime)
      $groupingAttribute = ""
    }
    if ($intuneDevice -and $intuneDevice.userPrincipalName) {
      $output.User = $intuneDevice.userPrincipalName
    }
    if ($intuneDevice) {
      $output.($groupingAttribute) = $intuneDevice.($groupingAttribute)
    }

    $output
  } | Sort-Object -Property "$groupingAttribute", "AssignmentDate" | Format-Table -Property "Serial", "User", "Model", "AssignmentDate" -GroupBy "$groupingAttribute" -AutoSize | Out-String
}

if ($groupingSource -eq 4) {
  "AutoPilot Device: $groupingAttribute"
  ""
  $devices | ForEach-Object {
    $intuneDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices/$($_.managedDeviceId)" -ErrorAction SilentlyContinue 

    $output = [PSCustomObject]@{
      Serial             = $_.serialNumber
      User               = ""
      Model              = $_.model
      AssignmentDate     = [datetime]($_.deploymentProfileAssignedDateTime)
      $groupingAttribute = ""
    }
    if ($intuneDevice -and $intuneDevice.userPrincipalName) {
      $output.User = $intuneDevice.userPrincipalName
    }
    $output.($groupingAttribute) = $_.($groupingAttribute)

    $output
  } | Sort-Object -Property "$groupingAttribute", "AssignmentDate" | Format-Table -Property "Serial", "User", "Model", "AssignmentDate" -GroupBy "$groupingAttribute" -AutoSize | Out-String
}

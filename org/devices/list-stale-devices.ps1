<#
  .SYNOPSIS
  List stale devices based on last activity date and platform.

  .DESCRIPTION
  Identifies and lists devices that haven't been active for a specified number of days.
  Allows filtering by device platform (Windows, macOS, iOS, Android).

  .NOTES
  Permissions (Graph):
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All
  - Device.Read.All

  .PARAMETER Days
  Number of days without activity to be considered stale.

  .PARAMETER Windows
  Include Windows devices in the results.

  .PARAMETER MacOS
  Include macOS devices in the results.

  .PARAMETER iOS
  Include iOS devices in the results.

  .PARAMETER Android
  Include Android devices in the results.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
        "Days": {
            "DisplayName": "Number of days without activity to be considered stale"
        },
        "Windows": {
            "DisplayName": "Include Windows devices",
            "CheckBox": {}
        },
        "MacOS": {
            "DisplayName": "Include macOS devices",
            "CheckBox": {}
        },
        "iOS": {
            "DisplayName": "Include iOS devices",
            "CheckBox": {}
        },
        "Android": {
            "DisplayName": "Include Android devices",
            "CheckBox": {}
        },
        "CallerName": {
            "Hide": true
        }
    }
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Number of days without activity to be considered stale" } )]
    [int] $Days = 30,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Include Windows devices" } )]
    [bool] $Windows = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Include macOS devices" } )]
    [bool] $MacOS = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Include iOS devices" } )]
    [bool] $iOS = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Include Android devices" } )]
    [bool] $Android = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

# Connect to Microsoft Graph
Connect-RjRbGraph

# Calculate the date threshold for stale devices
$beforeDate = (Get-Date).AddDays(-$Days) | Get-Date -Format "yyyy-MM-dd"

# Prepare filter for the Graph API query
$filter = "lastSyncDateTime le ${beforeDate}T00:00:00Z"

# Define the properties to select
$selectString = "deviceName, lastSyncDateTime, enrolledDateTime, userPrincipalName, id, serialNumber, manufacturer, model, operatingSystem, osVersion, complianceState"

# Get all stale devices
Write-Output "## Listing devices not active for at least $Days days"
Write-Output ""

$devices = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdSelect $selectString -OdFilter $filter -FollowPaging

# Filter devices by platform based on user selection
$filteredDevices = @()

foreach ($device in $devices) {
    $include = $false
    
    # Check if the device's platform matches any of the selected platforms
    if ($Windows -and $device.operatingSystem -eq "Windows") {
        $include = $true
    }
    elseif ($MacOS -and $device.operatingSystem -eq "macOS") {
        $include = $true
    }
    elseif ($iOS -and $device.operatingSystem -eq "iOS") {
        $include = $true
    }
    elseif ($Android -and $device.operatingSystem -eq "Android") {
        $include = $true
    }
    
    if ($include) {
        # Try to get additional user information
        try {
            $userInfo = Invoke-RjRbRestMethodGraph -Resource "/Users/$($device.userPrincipalName)" -OdSelect "displayName, city, usageLocation" -ErrorAction SilentlyContinue
            
            if ($userInfo) {
                $device | Add-Member -Name "userDisplayName" -Value $userInfo.displayName -MemberType "NoteProperty" -Force
                $device | Add-Member -Name "userLocation" -Value "$($userInfo.city), $($userInfo.usageLocation)" -MemberType "NoteProperty" -Force
            }
        }
        catch {
            Write-RjRbLog -Message "Could not retrieve user info for $($device.userPrincipalName): $_" -Verbose
        }
        
        $filteredDevices += $device
    }
}

# Display summary counts
Write-Output "## Summary of stale devices:"
Write-Output "Total devices: $($filteredDevices.Count)"

if ($Windows) {
    $windowsCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Windows" }).Count
    Write-Output "Windows devices: $windowsCount"
}

if ($MacOS) {
    $macOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "macOS" }).Count
    Write-Output "macOS devices: $macOSCount"
}

if ($iOS) {
    $iOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "iOS" }).Count
    Write-Output "iOS devices: $iOSCount"
}

if ($Android) {
    $androidCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Android" }).Count
    Write-Output "Android devices: $androidCount"
}

Write-Output ""
Write-Output "## Detailed list of stale devices:"
Write-Output ""

# Display the filtered devices
$filteredDevices | Sort-Object -Property lastSyncDateTime | Format-Table -AutoSize -Property @{
    name       = "LastSync";
    expression = { Get-Date $_.lastSyncDateTime -Format yyyy-MM-dd }
}, @{
    name       = "DeviceName";
    expression = { if ($_.deviceName.Length -gt 15) { $_.deviceName.substring(0, 14) + ".." } else { $_.deviceName } }
}, @{
    name       = "OS";
    expression = { "$($_.operatingSystem) $($_.osVersion)" }
}, @{
    name       = "User";
    expression = { if ($_.userPrincipalName.Length -gt 20) { $_.userPrincipalName.substring(0, 19) + ".." } else { $_.userPrincipalName } }
}, @{
    name       = "Compliant";
    expression = { $_.complianceState }
}
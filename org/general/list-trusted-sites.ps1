<#
  .SYNOPSIS
  List Url/Zone pairs in an Intune Windows 10 Trusted Sites Policy

  .DESCRIPTION
  List Url/Zone pairs in an Intune Windows 10 Trusted Sites Policy

  .NOTES
  Permissions: MS Graph API permissions:
  - DeviceManagementConfiguration.ReadWrite.All

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [string] $IntunePolicyName = "Windows 10 - Trusted Sites"
)

Connect-RjRbGraph

$pol = Invoke-RjRbRestMethodGraph -resource "/deviceManagement/deviceConfigurations" -OdFilter "displayName eq '$intunePolicyName'" 
if (-not $pol) {
    throw "Policy '$intunePolicyName' not found."
}

$innerValue = ($pol.omaSettings.value.split('"')[3]) -replace ('&#xF000;',';') 
[array]$pairs = $innerValue.Split(';')
if (($pairs.Count % 2) -eq 0) {
    [int]$i = 0;
    $mappings = @{}
    do {
        $mappings.Add($pairs[$i],$pairs[$i+1])
        $i = $i +2
    } while ($i -lt $pairs.Count)
    $mappings | Format-Table -AutoSize | Out-String
} else {
    throw "Error in parsing policy!"
}

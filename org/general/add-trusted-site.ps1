# Permissions: MS Graph API permissions:
# - DeviceManagementConfiguration.ReadWrite.All

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

<#
  .SYNOPSIS
  Add an entry to the Intune Windows 10 Trusted Sites Policy

  .DESCRIPTION
  Add an entry to the Intune Windows 10 Trusted Sites Policy

  .PARAMETER Url
  Needs to be prefixed with "http://" or "https://"

  .PARAMETER Zone
  0: My Computer,
  1: Local Intranet Zone,
  2: Trusted sites Zone,
  3: Internet Zone,
  4: Restricted Sites Zone
#>

param(
    [Parameter(Mandatory = $true)] 
    [string] $Url,
    [int] $Zone = 1,
    [string] $IntunePolicyName = "Windows 10 - Trusted Sites"
)

Connect-RjRbGraph

$pol = Invoke-RjRbRestMethodGraph -resource "/deviceManagement/deviceConfigurations" -OdFilter "displayName eq '$intunePolicyName'"
if (-not $pol) {
    throw "Policy '$intunePolicyName' not found."
}

# Add new entry at the end of the list
$newValue = $pol.omaSettings.value.Substring(0, $pol.omaSettings.value.Length - 3) + '&#xF000;' + $Url + '&#xF000;' + $Zone + '"/>'

$body = @{
    "@odata.type" = "#microsoft.graph.windows10CustomConfiguration"
    omaSettings   = [array](@{
            "@odata.type" = "#microsoft.graph.omaSettingString"
            displayName   = $pol.omaSettings.displayName
            omaUri        = $pol.omaSettings.omaUri
            value         = $newValue
        })
}


Invoke-RjRbRestMethodGraph -resource "/deviceManagement/deviceConfigurations/$($pol.id)" -Method Patch -Body $body

"SiteToZoneMapping '$Url':$Zone successfully added to '$intunePolicyName'"
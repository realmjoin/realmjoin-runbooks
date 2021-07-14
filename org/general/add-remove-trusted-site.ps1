<#
  .SYNOPSIS
  Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy

  .DESCRIPTION
  Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy

  .PARAMETER Url
  Needs to be prefixed with "http://" or "https://"

  .NOTES
  Permissions: MS Graph API permissions:
  - DeviceManagementConfiguration.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "Zone": {
                "SelectSimple": {
                    "My Computer (0)": 0,
                    "Local Intranet Zone (1)": 1,
                    "Trusted sites Zone (2)": 2,
                    "Internet Zone (3)": 3,
                    "Restricted Sites Zone (4)": 4
                }
            },
            "Remove": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Add URL to Trusted Sites": false,
                    "Remove URL from Trusted Sites": true
                }
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.2" }

param(
    [Parameter(Mandatory = $true)] 
    [string] $Url,
    [int] $Zone = 1,
    [string] $IntunePolicyName = "Windows 10 - Trusted Sites",
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this URL" } )]
    [bool] $Remove = $false
)

Connect-RjRbGraph

$pol = Invoke-RjRbRestMethodGraph -resource "/deviceManagement/deviceConfigurations" -OdFilter "displayName eq '$intunePolicyName'" 
if (-not $pol) {
    throw "Policy '$intunePolicyName' not found."
}

if ($Remove) {
    # Find and remove entry. 
    # Either not at the end
    if ($pol.omaSettings.value | Select-String -SimpleMatch -Pattern ($Url + '&#xF000;' + $Zone + '&#xF000;')) {
        $newValue = $pol.omaSettings.value -replace (($Url + '&#xF000;' + $Zone + '&#xF000;'),"")
    } # or at the end
    elseif ($pol.omaSettings.value | Select-String -SimpleMatch -Pattern ('&#xF000;' + $Url + '&#xF000;' + $Zone)) {
        $newValue = $pol.omaSettings.value -replace (('&#xF000;' + $Url + '&#xF000;' + $Zone),"")
    } else {
        throw "Url/Zone pair not found in policy."
    }
}
else {
    # Add new entry at the end of the list
    $newValue = $pol.omaSettings.value.Substring(0, $pol.omaSettings.value.Length - 3) + '&#xF000;' + $Url + '&#xF000;' + $Zone + '"/>'
}

$body = @{
    "@odata.type" = "#microsoft.graph.windows10CustomConfiguration"
    omaSettings   = [array](@{
            "@odata.type" = "#microsoft.graph.omaSettingString"
            displayName   = $pol.omaSettings.displayName
            omaUri        = $pol.omaSettings.omaUri
            value         = $newValue
        })
}


Invoke-RjRbRestMethodGraph -resource "/deviceManagement/deviceConfigurations/$($pol.id)" -Method Patch -Body $body | Out-Null

if ($Remove) {
    "SiteToZoneMapping '$($Url):$Zone' successfully removed from '$intunePolicyName'"
} else {
    "SiteToZoneMapping '$($Url):$Zone' successfully added to '$intunePolicyName'"
}

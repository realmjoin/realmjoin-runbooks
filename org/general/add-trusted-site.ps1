# This will add one more entry to the intune configuration policy "Windows 10 - Trusted Sites" - if present
#
# Permissions: MS Graph API permissions:
# - DeviceManagementConfiguration.ReadWrite.All

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }

param(
    # needs to be prefixed with "http://" / "https://"
    [Parameter(Mandatory = $true)] [string] $newSite,
    [int] $newSiteZone = 1,
    [string] $intunePolicyName = "Windows 10 - Trusted Sites"
)

Connect-RjRbGraph

$pol = Invoke-RjRbRestMethodGraph -resource "/deviceManagement/deviceConfigurations" -OdFilter "displayName eq '$intunePolicyName'"
if (-not $pol) {
    throw "Policy '$intunePolicyName' not found."
}

# Add new entry at the end of the list
$newValue = $pol.omaSettings.value.Substring(0, $pol.omaSettings.value.Length - 3) + '&#xF000;' + $newSite + '&#xF000;' + $newSiteZone + '"/>'

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

"SiteToZoneMapping '$newSite':$newSiteZone successfully added to '$intunePolicyName'"
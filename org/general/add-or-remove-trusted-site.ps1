<#
  .SYNOPSIS
  Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy

  .DESCRIPTION
  Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy

  .PARAMETER Url
  Needs to be prefixed with "http://" or "https://"

  .PARAMETER IntunePolicyName
  Will use an existing policy or default policy name if left empty.

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
            },
            "DefaultPolicyName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [Parameter(Mandatory = $true)] 
    [string] $Url,
    [int] $Zone = 1,
    [Parameter(Mandatory = $true)]
    [string] $DefaultPolicyName = "Windows 10 - Trusted Sites", 
    [string] $IntunePolicyName,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove this URL" } )]
    [bool] $Remove = $false
)

##FIXME
#"## This runbook is currenty disabled as the Graph API has changed. Please see"
#"https://call4cloud.nl/2021/09/the-isencrypted-with-steve-zissou/"
#""
#"## Running this code will destroy existing policies."
#"## We will renable this runbooks as soon as possible."
#""
#throw("unsupported graph api changes")

Connect-RjRbGraph

$pol = $null

# Use given policy name
if ($IntunePolicyName) {
    $pol = Invoke-RjRbRestMethodGraph -Beta -resource "/deviceManagement/deviceConfigurations" -OdFilter "displayName eq '$intunePolicyName'" 
    if (-not $pol) {
        "## Policy '$intunePolicyName' not found."
        if ($Remove) {
            "## Nothing to do. Exiting."
            exit
        }
    }
}

# Do we have existing "Trusted Site" policies we should use?
if ((-not $IntunePolicyName) -and (-not $pol)) {
    $pols = Invoke-RjRbRestMethodGraph -Beta -resource "/deviceManagement/deviceConfigurations" 
    [array]$trustedSitesPols = $pols | Where-Object { $_.omaSettings.omaUri -eq "./User/Vendor/MSFT/Policy/Config/InternetExplorer/AllowSiteToZoneAssignmentList" }
    if ($trustedSitesPols.count -eq 0) {
        "## No Trusted Site Policies found."
        if ($Remove) {
            "## Nothing to do. Exiting."
            exit
        }
    }
    elseif ($trustedSitesPols.count -eq 1) {
        "## Exactly one policy found: '$($trustedSitesPols[0].displayName)'"
        $pol = $trustedSitesPols[0]  
        ""
    }
    elseif ($trustedSitesPols.count -gt 1) {
        $trustedSitesPols | Where-Object { $_.displayName -eq $DefaultPolicyName } | ForEach-Object {
            "## Using default policy '$DefaultPolicyName'"
            $script:pol = $_
            ""
        }
        if ((-not $pol) -and $Remove) {
            "## More than Trusted Site policy found. Please choose:"
            $trustedSitesPols.displayName
            ""
            throw ("Policy not chosen")
        }
    }

}

if (-not $pol) {
    if ($IntunePolicyName) {
        $polName = $IntunePolicyName
    }
    else {
        $polName = $DefaultPolicyName
    }
    "## Creating new Trusted Site policy '$polName'"
    $body = @{
        "@odata.type" = "#microsoft.graph.windows10CustomConfiguration"
        displayName   = $polName
        omaSettings   = [array](@{
                "@odata.type" = "#microsoft.graph.omaSettingString"
                displayName   = "SiteToZoneAssignmentList"
                omaUri        = "./User/Vendor/MSFT/Policy/Config/InternetExplorer/AllowSiteToZoneAssignmentList"
                value         = '<enabled/><data id="IZ_ZonemapPrompt" value=""/>'
            })
    }
    $pol = Invoke-RjRbRestMethodGraph -resource "/deviceManagement/deviceConfigurations" -Beta -Method Post -Body $body 
    "## - Please assign users to the policy to activate it."
    ""
}

if ($pol) {
    "## Will use policy '$($pol.displayName)'."
    ""

    # Decrypt omaSettings value...
    $omaValue = Invoke-RjRbRestMethodGraph -Beta -resource "/deviceManagement/deviceConfigurations/$($pol.id)/getOmaSettingPlainTextValue(secretReferenceValueId='$($pol.omaSettings.secretReferenceValueId)')"

    if ($Remove) {
        # Find and remove entry... 
        # ... either not at the end
        if ($omaValue | Select-String -SimpleMatch -Pattern ($Url + '&#xF000;' + $Zone + '&#xF000;')) {
            $newValue = $omaValue -replace (($Url + '&#xF000;' + $Zone + '&#xF000;'), "")
        } # ... or at the end
        elseif ($omaValue | Select-String -SimpleMatch -Pattern ('&#xF000;' + $Url + '&#xF000;' + $Zone)) {
            $newValue = $omaValue -replace (('&#xF000;' + $Url + '&#xF000;' + $Zone), "")
        }
        else {
            "## SiteToZoneMapping '$($Url):$Zone' not found in '$($pol.displayName)'. Exiting."
            ""
            exit
        }
    }
    else {
        # Add new entry at the end of the list
        if ($omaValue | Select-String -SimpleMatch -Pattern ($Url + '&#xF000;' + $Zone)) {
            "## SiteToZoneMapping '$($Url):$Zone' already present in '$($pol.displayName)'. Exiting."
            ""
            exit
        } else {
            $newValue = $omaValue.Substring(0, $omaValue.Length - 3) + '&#xF000;' + $Url + '&#xF000;' + $Zone + '"/>'
        }
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
        "## SiteToZoneMapping '$($Url):$Zone' successfully removed from '$($pol.displayName)'"
    }
    else {
        "## SiteToZoneMapping '$($Url):$Zone' successfully added to '$($pol.displayName)'"
    }
}
else {
    "## No policy available."
    ""
    throw ("Unknown error. No Policy created.")
}



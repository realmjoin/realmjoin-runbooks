<#
    .SYNOPSIS
    Add or remove a URL entry in the Intune Trusted Sites policy

    .DESCRIPTION
    Adds or removes a URL to the Site-to-Zone Assignment List in a Windows custom configuration policy. The runbook can also list all existing Trusted Sites policies and their mappings.

    .PARAMETER Action
    Action to execute: add, remove, or list policies.

    .PARAMETER Url
    URL to add or remove; it must be prefixed with "http://" or "https://".

    .PARAMETER Zone
    Internet Explorer zone id to assign the URL to.

    .PARAMETER DefaultPolicyName
    Default policy name used when multiple Trusted Sites policies exist and no specific policy name is provided.

    .PARAMETER IntunePolicyName
    Optional policy name; if provided, the runbook targets this policy instead of auto-selecting one.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .NOTES
    This runbook uses calls as described in https://call4cloud.nl/2021/09/the-isencrypted-with-steve-zissou/ to decrypt omaSettings. It currently needs to use the Microsoft Graph beta endpoint for this.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Action": {
                "Select": {
                    "Options": [
                        {
                            "Display": "Add URL to Trusted Sites",
                            "ParameterValue": 0
                        },
                        {
                            "Display": "Remove URL from Trusted Sites",
                            "ParameterValue": 1
                        },
                        {
                            "Display": "List/Print all Trusted Sites Policies",
                            "ParameterValue": 2,
                            "Customization": {
                                "Hide": [
                                    "Url",
                                    "Zone",
                                    "DefaultPolicyName",
                                    "IntunePolicyName"
                                ]
                            }
                        }
                    ]
                }
            },
            "Zone": {
                "SelectSimple": {
                    "My Computer (0)": 0,
                    "Local Intranet Zone (1)": 1,
                    "Trusted sites Zone (2)": 2,
                    "Internet Zone (3)": 3,
                    "Restricted Sites Zone (4)": 4
                }
            },
            "DefaultPolicyName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [int] $Action = 2,
    [string] $Url,
    [int] $Zone = 1,
    [string] $DefaultPolicyName = "Windows 10 - Trusted Sites",
    [string] $IntunePolicyName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# Print all policies and exit
if ($Action -eq 2) {
    $AllPol = Invoke-RjRbRestMethodGraph -resource "/deviceManagement/deviceConfigurations" -Beta -FollowPaging
    [array]$pol = $AllPol | Where-Object { $_.omaSettings.omaUri -eq "./User/Vendor/MSFT/Policy/Config/InternetExplorer/AllowSiteToZoneAssignmentList" }

    if ($pol.count -eq 0) {
        "## No Trusted Site Policies found."
    }
    else {
        $pol | ForEach-Object {
            ""
            "## Policy: $($_.displayName)"
            ""
            $omaValue = Invoke-RjRbRestMethodGraph -Beta -resource "/deviceManagement/deviceConfigurations/$($_.id)/getOmaSettingPlainTextValue(secretReferenceValueId='$($_.omaSettings.secretReferenceValueId)')"
            $innerValue = ($omaValue.split('"')[3]) -replace ('&#xF000;', ';')
            [array]$pairs = $innerValue.Split(';')
            if (($pairs.Count % 2) -eq 0) {
                [int]$i = 0;
                $mappings = @{}
                do {
                    switch ($pairs[$i + 1]) {
                        0 { $value = "My Computer (0)" }
                        1 { $value = "Local Intranet Zone (1)" }
                        2 { $value = "Trusted sites Zone (2)" }
                        3 { $value = "Internet Zone (3)" }
                        4 { $value = "Restricted Sites Zone (4)" }
                        Default { $value = $pairs[$i + 1] }
                    }
                    $mappings.Add($pairs[$i], $value)
                    $i = $i + 2
                } while ($i -lt $pairs.Count)
                $mappings | Format-Table -AutoSize | Out-String
            }
            elseif ($pairs.Count -gt 2) {
                "Error in parsing policy! Please verify the policies correctness."
            }
            else {
                "No values found in policy."
            }
        }
    }

    exit
}

# Add or remove a trusted site

$pol = $null

# Use given policy name
if ($IntunePolicyName) {
    $pol = Invoke-RjRbRestMethodGraph -Beta -resource "/deviceManagement/deviceConfigurations" -OdFilter "displayName eq '$intunePolicyName'"
    if (-not $pol) {
        "## Policy '$intunePolicyName' not found."
        if ($Action -eq 1) {
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
        if ($Action -eq 1) {
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
        if ((-not $pol) -and ($Action -eq 1)) {
            "## More than one Trusted Site policy found. Please choose:"
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

    if ($Action -eq 1) {
        # Find and remove entry...
        # ... either not at the end
        if ($omaValue | Select-String -SimpleMatch -Pattern ($Url + '&#xF000;' + $Zone + '&#xF000;')) {
            $newValue = $omaValue -replace (($Url + '&#xF000;' + $Zone + '&#xF000;'), "")
        } # ... or at the end
        elseif ($omaValue | Select-String -SimpleMatch -Pattern ('&#xF000;' + $Url + '&#xF000;' + $Zone)) {
            $newValue = $omaValue -replace (('&#xF000;' + $Url + '&#xF000;' + $Zone), "")
        } # Or the last one...
        elseif ($omaValue | Select-String -SimpleMatch -Pattern ($Url + '&#xF000;' + $Zone)) {
            $newValue = $omaValue -replace (($Url + '&#xF000;' + $Zone), "")
        }
        else {
            "## SiteToZoneMapping '$($Url):$Zone' not found in '$($pol.displayName)'. Exiting."
            ""
            exit
        }
    }
    else {
        # Add new entry to the the list
        if ($omaValue | Select-String -SimpleMatch -Pattern ($Url + '&#xF000;' + $Zone)) {
            "## SiteToZoneMapping '$($Url):$Zone' already present in '$($pol.displayName)'. Exiting."
            ""
            exit
        }
        else {
            if ($omaValue -match '&#xF000;') {
                # Add to the end
                $newValue = $omaValue.Substring(0, $omaValue.Length - 3) + '&#xF000;' + $Url + '&#xF000;' + $Zone + '"/>'
            }
            else {
                # Was empty, build new one
                $newValue = '<enabled/><data id="IZ_ZonemapPrompt" value="' + $Url + '&#xF000;' + $Zone + '"/>'
            }
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

    if ($Action -eq 1) {
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



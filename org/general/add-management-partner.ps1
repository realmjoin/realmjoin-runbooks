<#
	.SYNOPSIS
	List or add a Partner Admin Link (PAL) for the tenant

	.DESCRIPTION
	Shows the Partner Admin Links (PAL) that tie the Azure usage of this tenant to a Microsoft partner, or adds a new one with the partner's ID. The link only credits the partner for the Azure consumption it manages.

	.PARAMETER Action
	List shows the current links, Add creates one for the "Partner ID".

	.PARAMETER PartnerId
	Microsoft Partner Network ID of the partner to link.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"PartnerId": {
				"DisplayName": "Partner ID"
			},
			"CallerName": {
				"Hide": true
			},
			"Action": {
				"Select": {
					"Options": [
						{
							"Display": "List current PALs",
							"ParameterValue": 0,
							"Customization": {
								"Hide": [
									"PartnerId"
								]
							}
						},
						{
							"Display": "Add a PAL",
							"ParameterValue": 1
						}
					]
				}
			}
		}
	}

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Az.ManagementPartner"; ModuleVersion = "0.8.0" }

param(
    [Parameter(Mandatory = $true)]
    [int] $Action = 0,
    [int] $PartnerId = 6457701,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbAzAccount

# Get current PALs
$pals = Get-AzManagementPartner -ErrorAction SilentlyContinue


if ($Action -eq 0) {
    "## Listing all PALs"
    ""
    if (-not $pals) {
        "## ... no PALs found."
    }
    else {
        $pals | Out-String
    }

}
elseif ($Action -eq 1) {
    if (($pals | Where-Object { $_.PartnerId -eq $PartnerId }).count -gt 0) {
        "## PAL / Management Parner Link $PartnerId is already set."
        ""
        throw ("PAL already set")
    }

    "## Setting Management Partner Link (PAL) ..."
    ""
    New-AzManagementPartner -PartnerId $PartnerId
}

#elseif ($Action -eq 2) {
#    if (($pals | Where-Object { $_.PartnerId -eq $PartnerId }).count -gt 0) {
#        "## Removing Management Partner Link (PAL) $PartnerId ..."
#        ""
#        Remove-AzManagementPartner -PartnerId $PartnerId
#    }
#    else {
#        "## PAL / Management Parner Link $PartnerId not present."
#        throw ("PAL not found")
#    }
#}
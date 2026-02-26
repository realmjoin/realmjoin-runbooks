<#
	.SYNOPSIS
	List or add Management Partner Links (PAL)

	.DESCRIPTION
	This runbook lists existing Partner Admin Links (PAL) for the tenant or adds a new PAL.
	It uses the Azure Management Partner API and supports an interactive action selection.

	.PARAMETER Action
	Choice of action to perform: list existing PALs or add a new PAL.

	.PARAMETER PartnerId
	Partner ID to set when adding a PAL.

	.PARAMETER CallerName
	Caller name for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Az.ManagementPartner"; ModuleVersion = "0.7.5" }

param(
    [Parameter(Mandatory = $true)]
    [int] $Action = 0,
    [int] $PartnerId = 6457701,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
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
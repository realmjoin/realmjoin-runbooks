<#
	.SYNOPSIS
	List the sensitivity labels of the tenant with their IDs

	.DESCRIPTION
	Lists the Microsoft Purview Information Protection sensitivity labels of the tenant with their IDs, for example to pick the label ID needed by other runbooks. Nothing is changed.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"CallerName": {
				"Hide": true
			}
		}
	}

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param(
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

# This runbook has no input parameters besides CallerName, so there is nothing to validate.

#endregion Parameter Validation

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response. Logs progress for slow or
        large pulls and surfaces Graph errors with the failing URI for easier troubleshooting.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/healthOverviews".

        .EXAMPLE
        PS C:\> $allIssues = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/issues"
    #>
    param(
        [string]$Uri
    )

    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    $pageCount = 0

    do {
        try {
            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to retrieve paged data from '$nextLink': $($_.Exception.Message)" -ErrorAction Continue
            throw
        }

        $pageCount++
        if ($response.value) {
            $allResults.AddRange([object[]]$response.value)
        }

        if ($pageCount % 5 -eq 0) {
            Write-RjRbLog -Message "Pagination progress: $pageCount pages, $($allResults.Count) items retrieved so far" -Verbose
        }

        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    if ($pageCount -gt 1) {
        Write-RjRbLog -Message "Pagination complete: $pageCount pages, $($allResults.Count) total items" -Verbose
    }

    return $allResults.ToArray()
}

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

Write-Output ""
Write-Output "Get sensitivity labels"
Write-Output "---------------------"

# TODO: Currently only in preview / beta. Change when available in v1.0
try {
    $labels = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/informationProtection/policy/labels")
}
catch {
    Write-Output "## Could not read the sensitivity labels. Either the permission is missing, or no Information Protection policy is set."
    Write-Output "## Make sure the following Graph API permission is available: InformationProtectionPolicy.Read.All (application)"
    Write-Error "Failed to read the sensitivity labels: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

if ($labels.Count -eq 0) {
    Write-Error "No sensitivity labels found. Either no Information Protection policy is set, or the permission is missing." -ErrorAction Continue
    throw "No sensitivity labels found."
}

Write-Output "Found $($labels.Count) sensitivity label(s)."

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

$labelNames = @{}
foreach ($label in $labels) {
    $labelNames[[string]$label.id] = [string]$label.name
}

$labelRows = @(foreach ($label in $labels) {
        $parentName = $null
        if ($label.parent -and $label.parent.id) {
            $parentName = $labelNames[[string]$label.parent.id]
            if (-not $parentName) { $parentName = [string]$label.parent.id }
        }
        [PSCustomObject]@{
            Name        = $label.name
            Id          = $label.id
            Parent      = $parentName
            Active      = $label.isActive
            Sensitivity = $label.sensitivity
            Tooltip     = $label.tooltip
            Description = $label.description
        }
    }) | Sort-Object -Property Name

#endregion Data Processing

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last, with its own RjTableTitle marker directly in front of the rows.
Write-Output ""
Write-Output ([PSCustomObject]@{ RjTableTitle = "Sensitivity labels" })
Write-Output @($labelRows | Select-Object -Property Name, Id, Parent, Active, Sensitivity, Tooltip, Description)

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

<#
	.SYNOPSIS
	List the owners of this group

	.DESCRIPTION
	Shows the owners of this group as a table. Nothing is changed.

	.PARAMETER GroupID
	Object ID of the group the runbook acts on. Set by the portal from the selected group.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"GroupId": {
				"Hide": true
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param(
    [Parameter(Mandatory = $true)]
    [String] $GroupID,
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
Write-RjRbLog -Message "GroupID: $GroupID" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

if ([string]::IsNullOrWhiteSpace($GroupID)) {
    Write-Error "GroupID is empty. Select a group to list its owners." -ErrorAction Continue
    throw "GroupID is empty"
}

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

$group = $null
try {
    $group = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$([uri]::EscapeDataString($GroupID))" -Method GET -ErrorAction Stop
}
catch { }

if (-not $group) {
    Write-Error "Group '$GroupID' not found." -ErrorAction Continue
    throw "Group not found"
}

Write-Output ""
Write-Output "Listing all owners of group '$($group.displayName)'"
Write-Output "---------------------"

try {
    $owners = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$([uri]::EscapeDataString($GroupID))/owners")
}
catch {
    Write-Error "Failed to read the owners of group '$($group.displayName)': $($_.Exception.Message)" -ErrorAction Continue
    throw
}

Write-Output "Found $($owners.Count) owner(s)."

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

$ownerRows = @(foreach ($owner in $owners) {
        [PSCustomObject]@{
            DisplayName       = $owner.displayName
            UserPrincipalName = $owner.userPrincipalName
            ObjectType        = ([string]$owner.'@odata.type') -replace '^#microsoft\.graph\.', ''
        }
    }) | Sort-Object -Property DisplayName

#endregion Data Processing

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last, with its own RjTableTitle marker directly in front of the rows.
Write-Output ""
if ($ownerRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Group owners" })
    Write-Output @($ownerRows | Select-Object -Property DisplayName, UserPrincipalName, ObjectType)
}
else {
    Write-Output "No owners found for group '$($group.displayName)'."
}

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

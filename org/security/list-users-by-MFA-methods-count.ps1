<#
	.SYNOPSIS
	List users by how many MFA methods they registered

	.DESCRIPTION
	Counts the registered authentication methods of every enabled user and lists the users whose count falls into the chosen range, for example those with no MFA method at all. The list in the Output Data tab shows display name, sign-in name and the number of methods. Nothing is changed.

	.PARAMETER mfaMethodsRange
	No methods lists users without any registered method; the other ranges list users with that many registered methods.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"mfaMethodsRange": {
				"DisplayName": "Number of MFA methods",
				"Mandatory": true,
				"SelectSimple": {
					"No methods (no MFA)": "0",
					"1 to 3 methods": "1-3",
					"4 to 5 methods": "4-5",
					"6 or more methods": "6+"
				}
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("0", "1-3", "4-5", "6+")]
    [string]$mfaMethodsRange,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "mfaMethodsRange: $mfaMethodsRange" -Verbose

#endregion RJ Log Part

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

Write-Output "Connect to Microsoft Graph..."

try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Retrieving all enabled users (this may take a while in large tenants)..."

try {
    $allUsers = @(Get-GraphPagedResult -Uri 'https://graph.microsoft.com/v1.0/users?$select=id,displayName,userPrincipalName,accountEnabled&$filter=accountEnabled eq true')
}
catch {
    Write-Error "Failed to retrieve users: $($_.Exception.Message)" -ErrorAction Continue
    if (Get-MgContext -ErrorAction SilentlyContinue) { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null }
    throw
}

Write-Output "Retrieved enabled users: $($allUsers.Count)"

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Reading the registered authentication methods of $($allUsers.Count) users (this may take a while in large tenants)..."

# One request per user; the user id doubles as the request id for correlation.
$userById = @{}
$batchRequests = foreach ($tenantUser in $allUsers) {
    $userById["$($tenantUser.id)"] = $tenantUser
    @{
        id     = "$($tenantUser.id)"
        method = "GET"
        url    = "/users/$($tenantUser.id)/authentication/methods"
    }
}

$filteredUsers = [System.Collections.Generic.List[object]]::new()
$unreadableUsers = [System.Collections.Generic.List[object]]::new()

try {
    $responses = @()
    if ($batchRequests) {
        $responses = @(Invoke-RjRbGraphBatch -Requests @($batchRequests) -ProgressLabel "users")
    }

    foreach ($response in $responses) {
        $tenantUser = $userById["$($response.id)"]
        if (-not $tenantUser) { continue }

        if ($response.status -ne 200) {
            Write-RjRbLog -Message "WARNING: Failed to retrieve MFA methods for user $($tenantUser.userPrincipalName): HTTP $($response.status)" -Verbose
            $unreadableUsers.Add([PSCustomObject]@{
                    DisplayName       = $tenantUser.displayName
                    UserPrincipalName = $tenantUser.userPrincipalName
                    Error             = "HTTP $($response.status)"
                })
            continue
        }

        $mfaMethodsCount = @($response.body.value).Count

        # Filter based on the selected range
        $includeUser = switch ($mfaMethodsRange) {
            "0" { $mfaMethodsCount -eq 0 }
            "1-3" { $mfaMethodsCount -ge 1 -and $mfaMethodsCount -le 3 }
            "4-5" { $mfaMethodsCount -ge 4 -and $mfaMethodsCount -le 5 }
            "6+" { $mfaMethodsCount -ge 6 }
        }

        if ($includeUser) {
            $filteredUsers.Add([PSCustomObject]@{
                    DisplayName       = $tenantUser.displayName
                    UserPrincipalName = $tenantUser.userPrincipalName
                    MFAMethodsCount   = $mfaMethodsCount
                })
        }
    }
}
catch {
    Write-Error "Failed to retrieve MFA methods: $($_.Exception.Message)" -ErrorAction Continue
    if (Get-MgContext -ErrorAction SilentlyContinue) { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null }
    throw
}

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Users checked: $($allUsers.Count)"
Write-Output "Users with MFA methods count in range '$mfaMethodsRange': $($filteredUsers.Count)"
Write-Output "Users not readable: $($unreadableUsers.Count)"

#endregion Main Part

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last. Every table has its own RjTableTitle marker; a marker is only written when rows follow it.
Write-Output ""

$summaryValues = [ordered]@{
    "Users checked"      = $allUsers.Count
    "Users in range"     = $filteredUsers.Count
    "Users not readable" = $unreadableUsers.Count
}
$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($filteredUsers.Count -gt 0) {
    $resultTitle = if ($mfaMethodsRange -eq "0") { "Users without MFA methods" } else { "Users with $mfaMethodsRange MFA methods" }
    # Sort by MFA methods count (descending) and then by display name
    $sortedUsers = @($filteredUsers | Sort-Object MFAMethodsCount, DisplayName -Descending)
    Write-Output ([PSCustomObject]@{ RjTableTitle = $resultTitle })
    Write-Output @($sortedUsers | Select-Object -Property MFAMethodsCount, DisplayName, UserPrincipalName)
}
else {
    Write-Output "No users found with MFA methods count in the specified range: $mfaMethodsRange"
}

if ($unreadableUsers.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Users not readable" })
    Write-Output @($unreadableUsers | Select-Object -Property DisplayName, UserPrincipalName, Error)
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

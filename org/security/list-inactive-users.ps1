<#
	.SYNOPSIS
	List users with no recent interactive sign-in

	.DESCRIPTION
	Lists the users and guests whose last interactive sign-in is older than the chosen number of days. Accounts that are blocked from signing in and accounts that never signed in can be included. Nothing is changed.

	.PARAMETER Days
	Users with no interactive sign-in for at least this many days are listed.

	.PARAMETER ShowBlockedUsers
	Also lists users and guests whose sign-in is blocked.

	.PARAMETER ShowUsersThatNeverLoggedIn
	Also lists users and guests that never signed in.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"CallerName": {
				"Hide": true
			},
			"Days": {
				"DisplayName": "Inactive for at least (days)"
			},
			"showBlockedUsers": {
				"DisplayName": "Include blocked accounts?"
			},
			"showUsersThatNeverLoggedIn": {
				"DisplayName": "Include accounts that never signed in?"
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param(
    [int] $Days = 30,
    [bool] $ShowBlockedUsers = $true,
    [bool] $ShowUsersThatNeverLoggedIn = $false,
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
Write-RjRbLog -Message "Days: $Days" -Verbose
Write-RjRbLog -Message "ShowBlockedUsers: $ShowBlockedUsers" -Verbose
Write-RjRbLog -Message "ShowUsersThatNeverLoggedIn: $ShowUsersThatNeverLoggedIn" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

if ($Days -lt 0) {
    Write-Error "Days must not be negative (got $Days)." -ErrorAction Continue
    throw "Days must not be negative"
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

function ConvertTo-SignInText {
    param($Value)
    if (-not $Value) { return $null }
    return ([datetime]::Parse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal)).ToString("yyyy-MM-dd HH:mm:ss")
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

# Calculate "last sign in date"
$lastSignInDate = (Get-Date) - (New-TimeSpan -Days $Days) | Get-Date -Format "yyyy-MM-dd"
$cutoff = [datetime]::SpecifyKind([datetime]::ParseExact($lastSignInDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture), [System.DateTimeKind]::Utc)

Write-Output ""
Write-Output "Get users and guests"
Write-Output "---------------------"
Write-Output "Looking for accounts without interactive sign-in since $lastSignInDate. This may take some time in large tenants."

$selectQuery = "`$select=userPrincipalName,accountEnabled,mail,signInActivity,userType"
$userObjects = @()
$usersThatNeverLoggedIn = @()
try {
    if (-not $ShowUsersThatNeverLoggedIn) {
        $filter = 'signInActivity/lastSignInDateTime le ' + $lastSignInDate + 'T00:00:00Z'
        $userObjects = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users?$($selectQuery)&`$filter=$([uri]::EscapeDataString($filter))")
    }
    else {
        $allUsers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users?$($selectQuery)")
        $usersThatNeverLoggedIn = @($allUsers | Where-Object { $null -eq $_.signInActivity })
        $userObjects = @($allUsers | Where-Object {
                ($null -ne $_.signInActivity) -and $_.signInActivity.lastSignInDateTime -and
                ([datetime]::Parse([string]$_.signInActivity.lastSignInDateTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal) -le $cutoff)
            })
    }
}
catch {
    Write-Output "## Getting list of users and guests failed. Maybe missing permissions?"
    Write-Output "## Make sure the following Graph API permissions are present: User.Read.All, AuditLog.Read.All (application)"
    Write-Error "Listing users failed: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

if (-not $ShowBlockedUsers) {
    $userObjects = @($userObjects | Where-Object { $_.accountEnabled })
    $usersThatNeverLoggedIn = @($usersThatNeverLoggedIn | Where-Object { $_.accountEnabled })
}

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

$inactiveUsers = @($userObjects | Where-Object { $_.userType -eq "Member" } |
    Sort-Object -Property @{E = { $_.signInActivity.lastSignInDateTime } } |
    ForEach-Object {
        [PSCustomObject]@{
            UserPrincipalName = $_.userPrincipalName
            LastSignIn        = ConvertTo-SignInText $_.signInActivity.lastSignInDateTime
            AccountEnabled    = $_.accountEnabled
        }
    })

$inactiveGuests = @($userObjects | Where-Object { $_.userType -eq "Guest" } |
    Sort-Object -Property @{E = { $_.signInActivity.lastSignInDateTime } } |
    ForEach-Object {
        [PSCustomObject]@{
            Mail           = if ($_.mail) { $_.mail } else { $_.userPrincipalName }
            LastSignIn     = ConvertTo-SignInText $_.signInActivity.lastSignInDateTime
            AccountEnabled = $_.accountEnabled
        }
    })

$neverUsers = @($usersThatNeverLoggedIn | Where-Object { $_.userType -eq "Member" } |
    Sort-Object -Property userPrincipalName |
    ForEach-Object {
        [PSCustomObject]@{
            UserPrincipalName = $_.userPrincipalName
            AccountEnabled    = $_.accountEnabled
        }
    })

$neverGuests = @($usersThatNeverLoggedIn | Where-Object { $_.userType -eq "Guest" } |
    Sort-Object -Property mail, userPrincipalName |
    ForEach-Object {
        [PSCustomObject]@{
            Mail           = if ($_.mail) { $_.mail } else { $_.userPrincipalName }
            AccountEnabled = $_.accountEnabled
        }
    })

Write-Output ""
Write-Output "Inactive users (no sign-in since at least $Days days)"
Write-Output "---------------------"
Write-Output "Inactive users: $($inactiveUsers.Count)"
Write-Output "Inactive guests: $($inactiveGuests.Count)"
if ($ShowUsersThatNeverLoggedIn) {
    Write-Output "Users that never signed in: $($neverUsers.Count)"
    Write-Output "Guests that never signed in: $($neverGuests.Count)"
}

#endregion Data Processing

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last. Every table has its own RjTableTitle marker and column set; a marker is only
# written when rows follow it, an empty category gets a status line instead.
Write-Output ""

$summaryValues = [ordered]@{
    "Inactive users"  = $inactiveUsers.Count
    "Inactive guests" = $inactiveGuests.Count
}
if ($ShowUsersThatNeverLoggedIn) {
    $summaryValues["Users never signed in"] = $neverUsers.Count
    $summaryValues["Guests never signed in"] = $neverGuests.Count
}
$summaryRows = @(foreach ($metric in $summaryValues.Keys) {
        [PSCustomObject]@{ Metric = $metric; Value = [int]$summaryValues[$metric] }
    })
Write-Output ([PSCustomObject]@{ RjTableTitle = "Summary" })
Write-Output $summaryRows

if ($inactiveUsers.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Inactive users" })
    Write-Output @($inactiveUsers | Select-Object -Property UserPrincipalName, LastSignIn, AccountEnabled)
}
else {
    Write-Output "No inactive users found."
}

if ($inactiveGuests.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Inactive guests" })
    Write-Output @($inactiveGuests | Select-Object -Property Mail, LastSignIn, AccountEnabled)
}
else {
    Write-Output "No inactive guests found."
}

if ($ShowUsersThatNeverLoggedIn) {
    if ($neverUsers.Count -gt 0) {
        Write-Output ([PSCustomObject]@{ RjTableTitle = "Users never signed in" })
        Write-Output @($neverUsers | Select-Object -Property UserPrincipalName, AccountEnabled)
    }
    else {
        Write-Output "No users that never signed in."
    }

    if ($neverGuests.Count -gt 0) {
        Write-Output ([PSCustomObject]@{ RjTableTitle = "Guests never signed in" })
        Write-Output @($neverGuests | Select-Object -Property Mail, AccountEnabled)
    }
    else {
        Write-Output "No guests that never signed in."
    }
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

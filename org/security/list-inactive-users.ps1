<#
	.SYNOPSIS
	List users with no recent interactive sign-ins

	.DESCRIPTION
	Lists users and guests that have not signed in interactively for a specified number of days. Optionally includes accounts that never signed in and accounts that are blocked.

	.PARAMETER Days
	Number of days without interactive sign-in.

	.PARAMETER ShowBlockedUsers
	If set to true, includes users and guests that cannot sign in.

	.PARAMETER ShowUsersThatNeverLoggedIn
	If set to true, includes users and guests that never signed in.

	.PARAMETER CallerName
	Caller name is tracked purely for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"CallerName": {
				"Hide": true
			},
			"Days": {
				"DisplayName": "Days without signin"
			},
			"showBlockedUsers": {
				"DisplayName": "Include users/guests that can not sign in"
			},
			"showUsersThatNeverLoggedIn": {
				"DisplayName": "Include users/guests that never logged in"
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
  [int] $Days = 30,
  [bool] $ShowBlockedUsers = $true,
  [bool] $ShowUsersThatNeverLoggedIn = $false,
  # CallerName is tracked purely for auditing purposes
  [Parameter(Mandatory = $true)]
  [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# Calculate "last sign in date"
$lastSignInDate = (get-date) - (New-TimeSpan -Days $days) | Get-Date -Format "yyyy-MM-dd"
$userObjects = $null
$usersThatNeverLoggedIn = $null
try {
  if (-not $ShowUsersThatNeverLoggedIn) {
    $filter = 'signInActivity/lastSignInDateTime le ' + $lastSignInDate + 'T00:00:00Z'
    $userObjects = Invoke-RjRbRestMethodGraph -Resource '/users' -FollowPaging -UriQueryRaw "`$select=userPrincipalName,accountEnabled,mail,signinactivity,userType&`$filter=$filter"
  }
  else {
    $userObjects = Invoke-RjRbRestMethodGraph -Resource '/users' -FollowPaging -UriQueryRaw "`$select=userPrincipalName,accountEnabled,mail,signinactivity,userType"
    $usersThatNeverLoggedIn = $userObjects | Where-Object { $_.signInActivity -eq $null }
    $userObjects = $userObjects | Where-Object { ($_.signInActivity -ne $null) -and ($_.signInActivity.lastSignInDateTime -lt $lastSignInDate) }
    # $userObjects += $usersThatNeverLoggedIn
  }
}
catch {
  "## Getting list of users and guests failed. Maybe missing permissions?"
  ""
  "## Make sure, the following Graph API permissions are present:"
  "## - User.Read.All (API)"
  "## - AuditLog.Read.All (API)"
  ""
  $_
  throw ("Listing users failed.")
}

if (-not $ShowBlockedUsers) {
  $userObjects = $userObjects | Where-Object { $_.accountEnabled }
  $usersThatNeverLoggedIn = $usersThatNeverLoggedIn | Where-Object { $_.accountEnabled }
}

"## Inactive Users (No SignIn since at least $Days days.)"
""
$userObjects | Where-Object { $_.userType -eq "Member" } | Sort-Object -Property @{E = { $_.signInActivity.lastSignInDateTime } } | Format-Table UserPrincipalName, @{L = ’Last Signin’; E = { $_.signInActivity.lastSignInDateTime } }, @{L = ’Account Enabled’; E = { $_.accountEnabled } } | Out-String
""

if ($ShowUsersThatNeverLoggedIn) {
  "## Users that never logged in"
  ""
  $usersThatNeverLoggedIn | Where-Object { $_.userType -eq "Member" } | Format-Table UserPrincipalName, @{L = ’Account Enabled’; E = { $_.accountEnabled } } | Out-String
  ""
}

"## Inactive Guests (No SignIn since at least $Days days.)"
""
$userObjects | Where-Object { $_.userType -eq "Guest" } | Sort-Object -Property @{E = { $_.signInActivity.lastSignInDateTime } } | Format-Table Mail, @{L = ’Last Signin’; E = { $_.signInActivity.lastSignInDateTime } }, @{L = ’Account Enabled’; E = { $_.accountEnabled } } | Out-String
""

if ($ShowUsersThatNeverLoggedIn) {
  "## Guests that never logged in"
  ""
  $usersThatNeverLoggedIn | Where-Object { $_.userType -eq "Guest" } | Format-Table Mail, @{L = ’Account Enabled’; E = { $_.accountEnabled } } | Out-String
  ""
}

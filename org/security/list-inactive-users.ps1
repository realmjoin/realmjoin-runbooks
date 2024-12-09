<#
  .SYNOPSIS
  List users, that have no recent interactive signins.

  .DESCRIPTION
  List users, that have no recent interactive signins.

  .NOTES
  Permissions: MS Graph
  - User.Read.All
  - AuditLog.Read.All
  - Organization.Read.All

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

  .PARAMETER showUsersThatNeverLoggedIn
  Beware: This has to enumerate all users / Can take a long time.
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
  [int] $Days = 30,
  [bool] $showBlockedUsers = $true,
  [bool] $showUsersThatNeverLoggedIn = $false,
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
  if (-not $showUsersThatNeverLoggedIn) {
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

if (-not $showBlockedUsers) {
  $userObjects = $userObjects | Where-Object { $_.accountEnabled }
  $usersThatNeverLoggedIn = $usersThatNeverLoggedIn | Where-Object { $_.accountEnabled }
}

"## Inactive Users (No SignIn since at least $Days days.)"
""
$userObjects | Where-Object { $_.userType -eq "Member" } | Sort-Object -Property @{E = { $_.signInActivity.lastSignInDateTime } } | Format-Table UserPrincipalName, @{L = ’Last Signin’; E = { $_.signInActivity.lastSignInDateTime } }, @{L = ’Account Enabled’; E = { $_.accountEnabled } } | Out-String
""

if ($showUsersThatNeverLoggedIn) {
  "## Users that never logged in"
  ""
  $usersThatNeverLoggedIn | Where-Object { $_.userType -eq "Member" } | Format-Table UserPrincipalName, @{L = ’Account Enabled’; E = { $_.accountEnabled } } | Out-String
  ""
}

"## Inactive Guests (No SignIn since at least $Days days.)"
""
$userObjects | Where-Object { $_.userType -eq "Guest" } | Sort-Object -Property @{E = { $_.signInActivity.lastSignInDateTime } } | Format-Table Mail, @{L = ’Last Signin’; E = { $_.signInActivity.lastSignInDateTime } }, @{L = ’Account Enabled’; E = { $_.accountEnabled } } | Out-String
""

if ($showUsersThatNeverLoggedIn) {
  "## Guests that never logged in"
  ""
  $usersThatNeverLoggedIn | Where-Object { $_.userType -eq "Guest" } | Format-Table Mail, @{L = ’Account Enabled’; E = { $_.accountEnabled } } | Out-String
  ""
}

<#
  .SYNOPSIS
  List users, that have no recent signins.

  .DESCRIPTION
  List users, that have no recent signins.

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
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
  [ValidateScript( { Use-RJInterface -DisplayName "Days without signin" } )]
  [int] $Days = 30,
  [ValidateScript( { Use-RJInterface -DisplayName "Include users/guests that can not sign in" } )]
  [bool] $showBlockedUsers = $true,
  # CallerName is tracked purely for auditing purposes
  [Parameter(Mandatory = $true)]
  [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

# Calculate "last sign in date"
$lastSignInDate = (get-date) - (New-TimeSpan -Days $days) | Get-Date -Format "yyyy-MM-dd"
$filter = 'signInActivity/lastSignInDateTime le ' + $lastSignInDate + 'T00:00:00Z'
try {
  $userObjects = Invoke-RjRbRestMethodGraph -Resource '/users' -FollowPaging -UriQueryRaw "`$select=userPrincipalName,accountEnabled,mail,signinactivity,userType&`$filter=$filter"
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
}

"## Inactive Users (No SignIn since at least $Days days.)"
""
$userObjects | Where-Object { $_.userType -eq "Member" } | Sort-Object -Property @{E={$_.signInActivity.lastSignInDateTime}} | Format-Table UserPrincipalName,@{L=’Last Signin’;E={$_.signInActivity.lastSignInDateTime}},@{L=’Account Enabled’;E={$_.accountEnabled}} | Out-String
""

"## Inactive Guests (No SignIn since at least $Days days.)"
""
$userObjects | Where-Object { $_.userType -eq "Guest" } | Sort-Object -Property @{E={$_.signInActivity.lastSignInDateTime}} | Format-Table Mail,@{L=’Last Signin’;E={$_.signInActivity.lastSignInDateTime}},@{L=’Account Enabled’;E={$_.accountEnabled}} | Out-String
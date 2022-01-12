<#
  .SYNOPSIS
  List users, that have no recent signins.

  .DESCRIPTION
  List users, that have no recent signins.

  .NOTES
  Permissions: MS Graph
  - User.Read.All
  - AuditLogs.Read.All
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

Connect-RjRbGraph

# Calculate "last sign in date"
$lastSignInDate = (get-date) - (New-TimeSpan -Days $days) | Get-Date -Format "yyyy-MM-dd"
$filter = 'signInActivity/lastSignInDateTime le ' + $lastSignInDate + 'T00:00:00Z'
try {
  $userObjects = Invoke-RjRbRestMethodGraph -Resource '/users' -OdFilter $filter -Beta
}
catch {
  "## Getting list of users and guests failed. Maybe missing permissions?"
  ""
  "## Make sure, the following Graph API permissions are present:"
  "## - Users.Read.All (API)"
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
$userObjects | Where-Object { $_.userType -eq "Member" } | Select-Object -Property UserPrincipalName, signInSessionsValidFromDateTime, accountEnabled | Sort-Object -Property signInSessionsValidFromDateTime | Format-Table UserPrincipalName,@{L=’Last Signin’;E={$_.signInSessionsValidFromDateTime}},@{L=’Account Enabled’;E={$_.accountEnabled}} | Out-String
""

"## Inactive Guests (No SignIn since at least $Days days.)"
""
$userObjects | Where-Object { $_.userType -eq "Guest" } | Select-Object -Property Mail, signInSessionsValidFromDateTime, accountEnabled | Sort-Object -Property signInSessionsValidFromDateTime | Format-Table Mail,@{L=’Last Signin’;E={$_.signInSessionsValidFromDateTime}},@{L=’Account Enabled’;E={$_.accountEnabled}} | Out-String
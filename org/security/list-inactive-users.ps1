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
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
  [ValidateScript( { Use-RJInterface -DisplayName "Days without signin" } )]
  [int] $Days = 30
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

"## Inactive Users (No SignIn since at least $Days days.)"
""
$userObjects | Where-Object { $_.userType -eq "Member" } | Select-Object -Property UserPrincipalName, signInSessionsValidFromDateTime | out-string
""

"## Inactive Guests (No SignIn since at least $Days days.)"
""
$userObjects | Where-Object { $_.userType -eq "Guest" } | Select-Object -Property Mail, signInSessionsValidFromDateTime | out-string
<#
  .SYNOPSIS
  List Room configuration.

  .DESCRIPTION
  List Room configuration.

  .NOTES
  Permissions
  MS Graph (API):
  - Place.Read.All

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
            "UserName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param (
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox" } )]
    [string] $UserName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph

$User = Invoke-RjRbRestMethodGraph -Resource "/users/$($UserName)" 

"## Basic Infos:"
try {
    Invoke-RjRbRestMethodGraph -Resource "/places/$($User.userPrincipalName)/microsoft.graph.room" 
}
catch {
    "## Fetching Room Configuration for '$UserName' failed. Either missing permissions or this is not a Room-Mailbox."
    "## - If this is a Room Mailbox, make sure 'Place.Read.All' permissions are granted."
    ""
    Write-Error $_
}

""
"## Calendar Processing:"
Connect-RjRbExchangeOnline
try {
    Get-CalendarProcessing -Identity $UserName | Select-Object -Property AllBookInPolicy, AutomateProcessing, AllowConflicts, BookingWindowsInDays, MaximumDurationInMinutes, ForwardRequetsToDelegates, DeleteSubject, AddOrganizertoSubject, OrganizerInfo
}
catch {
    "## Fetching Room Configuration for '$UserName' failed."
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}


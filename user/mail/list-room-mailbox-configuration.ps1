<#
  .SYNOPSIS
  List Room configuration.

  .DESCRIPTION
  List Room configuration.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }

param (
    [Parameter(Mandatory = $true)]
    [string] $UserName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$User = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName" -OdSelect "mail,mailNickname"

"## Basic Infos:"
try {
    Invoke-RjRbRestMethodGraph -Resource "/places/$($User.Mail)/microsoft.graph.room"
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
    Get-CalendarProcessing -Identity $User.mailNickname | Select-Object -Property AllBookInPolicy, AutomateProcessing, AllowConflicts, BookingWindowInDays, MaximumDurationInMinutes, ForwardRequetsToDelegates, DeleteSubject, AddOrganizertoSubject, OrganizerInfo
}
catch {
    "## Fetching Room Configuration for '$UserName' failed."
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}


<#
    .SYNOPSIS
    List room mailbox configuration

    .DESCRIPTION
    Reads room metadata and lists calendar processing settings. This helps validate room resource configuration and booking behavior.

    .PARAMETER UserName
    User principal name of the room mailbox.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

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


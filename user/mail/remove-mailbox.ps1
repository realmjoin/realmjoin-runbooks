<#
  .SYNOPSIS
  Hard delete a shared mailbox, room or bookings calendar.

  .DESCRIPTION
  Hard delete a shared mailbox, room or bookings calendar.

  .NOTES
  Permissions
  Exchange Administrator access

  .INPUTS
  RunbookCustomization: {
        "Parameters": {            
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, Az.Storage, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Mailbox" } )]
    [String] $UserName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbExchangeOnline

try {
    $targetMBox = Get-Mailbox -Identity $UserName -ErrorAction Stop
}
catch {
    "## Could not find/read '$UserName'. Exiting"
    ""
    throw $_
}

"## Object Type: $($targetMBox.RecipientTypeDetails)"    
if ($targetMBox.RecipientTypeDetails -in ("SchedulingMailbox", "RoomMailbox", "SharedMailbox")) {
    "## Trying to hard delete mailbox '$UserName'."
    remove-mailbox -Identity $UserName -Confirm:$false
}
else {
    "## Wrong object type. Skipping."
}

Disconnect-ExchangeOnline -Confirm:$false | Out-Null


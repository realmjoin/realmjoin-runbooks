<#
  .SYNOPSIS
  Set the OWA mailbox policy for a user.

  .DESCRIPTION
  Set the OWA mailbox policy for a user. E.g. to allow MS Bookings.

  .NOTES
  Permissions
  Exchange Administrator access

  .INPUTS
  RunbookCustomization: {
        "Parameters": {    
            "OwaPolicyName": {
                "SelectSimple": {
                    "Default": "OwaMailboxPolicy-Default",
                    "BookingsCreators": "BookingsCreators"
                }            
            },
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
    [Parameter(Mandatory = $true)]
    [string] $OwaPolicyName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose


Connect-RjRbExchangeOnline

try {
    Get-OwaMailboxPolicy -Identity $OwaPolicyName -ErrorAction Stop       
} catch {
    "## Could not read OWA Policy '$OwaPolicyName'. Exiting."
    ""
    throw $_
}


try {
    $targetMBox = Get-Mailbox -Identity $UserName -ErrorAction Stop
}
catch {
    "## Could not find/read '$UserName'. Exiting"
    ""
    throw $_
}

Set-CasMailbox -OwaMailboxPolicy $OwaPolicyName -Identity $UserName | Out-Null
"## OWA Mailbox Policy for '$Username' set to '$OwaPolicyName'."

Disconnect-ExchangeOnline -Confirm:$false | Out-Null


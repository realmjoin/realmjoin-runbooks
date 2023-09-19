<#
  .SYNOPSIS
  Assign a given OWA mailbox policy to a user.

  .DESCRIPTION
  Assign a given OWA mailbox policy to a user. E.g. to allow MS Bookings.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }, Az.Storage, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [string] $OwaPolicyName = "OwaMailboxPolicy-Default",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose


Connect-RjRbExchangeOnline

try {
    $policy = Get-OwaMailboxPolicy -Identity $OwaPolicyName -ErrorAction Stop       
}
catch {
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

Set-CasMailbox -OwaMailboxPolicy $OwaPolicyName -Identity $UserName -ErrorAction Stop | Out-Null
"## OWA Mailbox Policy for '$Username' set to '$OwaPolicyName'."

Disconnect-ExchangeOnline -Confirm:$false | Out-Null


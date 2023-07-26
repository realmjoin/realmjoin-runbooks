<#
  .SYNOPSIS
  List permissions on a (shared) mailbox.

  .DESCRIPTION
  List permissions on a (shared) mailbox.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.1" }, @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.2.0" }

param
(
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User  -DisplayName "User/Mailbox" } )]
    [Parameter(Mandatory = $true)] 
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

"## Trying to list all mailbox access / send permissions granted on mailbox '$UserName'."

try {
    Connect-RjRbExchangeOnline

    # Check if User has a mailbox
    $user = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if (-not $user) {
        throw "User  object '$UserName' has no mailbox."
    }

    "## Dump Mailbox Permission Details for '$UserName'"
    ""
    "## Mailbox Access Permissions"
    Get-MailboxPermission -Identity $UserName | Where-Object { ($_.user -ne 'NT AUTHORITY\SELF') } | Format-Table -Property Identity, User, AccessRights -AutoSize | Out-String
    ""
    "## Recipient/Sender (SendAs) Permissions"
    Get-RecipientPermission -Identity $UserName | Where-Object { ($_.Trustee -ne 'NT AUTHORITY\SELF') } | Format-Table -Property Identity, Trustee, AccessRights -AutoSize | Out-String
    ""
    "## SendOnBehalf Permissions"
    (Get-Mailbox -Identity $UserName).GrantSendOnBehalfTo | ForEach-Object {
        $sobTrustee = Get-Recipient -Identity $_
        $result = @{}
        $result.Identity = $user.Identity
        if ($sobTrustee.RecipientType -eq "UserMailbox") {
            $result.Trustee = $sobTrustee.PrimarySmtpAddress
        } else {
            $result.Trustee = $sobTrustee.Identity
        }
        $result.AccessRights = "{SendOnBehalf}"
        [PsCustomObject]$result
    } | Format-Table -Property Identity, Trustee, AccessRights -AutoSize | Out-String

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
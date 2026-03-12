<#
    .SYNOPSIS
    List mailbox permissions for a mailbox

    .DESCRIPTION
    Lists different types of permissions like mailbox access, SendAs, and SendOnBehalf permissions for a mailbox. Outputs each permission type as formatted tables. This also works for shared mailboxes.

    .PARAMETER UserName
    User principal name of the mailbox.

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

param
(
    [Parameter(Mandatory = $true)]
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

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
        $sobTrustee = Get-Recipient -Identity $_ | Where-Object { $_.RecipientType -eq "UserMailbox" }
        foreach ($trustee in [array]$sobTrustee) {
            $result = @{}
            $result.Identity = $user.Identity
            $result.Trustee = $trustee.PrimarySmtpAddress
            $result.AccessRights = "{SendOnBehalf}"
            [PsCustomObject]$result
        }
    } | Format-Table -Property Identity, Trustee, AccessRights -AutoSize | Out-String

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
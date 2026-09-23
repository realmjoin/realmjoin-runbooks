<#
    .SYNOPSIS
    List who has access to this user's mailbox

    .DESCRIPTION
    Shows who has permissions on the mailbox of this user: full access, Send As and Send on Behalf, each as a table. Works for shared mailboxes as well. Nothing is changed.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param
(
    [Parameter(Mandatory = $true)]
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.2"
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
        # The entries are recipient names, which are not unique in Exchange Online - list the raw name
        # when it cannot be resolved to exactly one recipient.
        $sobEntry = $_
        $sobRecipient = Get-Recipient -Identity $sobEntry -ErrorAction SilentlyContinue
        if ($sobRecipient) {
            $sobTrustee = $sobRecipient | Where-Object { $_.RecipientType -eq "UserMailbox" }
        }
        else {
            $sobTrustee = [PSCustomObject]@{ PrimarySmtpAddress = "$sobEntry" }
        }
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
<#
    .SYNOPSIS
    Create an equipment mailbox with optional delegate

    .DESCRIPTION
    Creates an equipment mailbox in Exchange Online, for example for a projector or a pool car, so it can be booked in meeting requests. A delegate can get full access and manage the bookings, and meeting requests can be accepted automatically. The user account behind the mailbox can be disabled so nobody signs in with it.

    .PARAMETER MailboxName
    Alias of the mailbox, which becomes the part of the email address in front of the @ sign.

    .PARAMETER DisplayName
    Name shown in the address book. Leave empty to use the alias.

    .PARAMETER DelegateTo
    User who gets full access to the mailbox and handles its booking requests. Leave empty for none.

    .PARAMETER AutoAccept
    Meeting requests are accepted automatically when the equipment is free.

    .PARAMETER AutoMapping
    The mailbox opens automatically in the delegate's Outlook.

    .PARAMETER DisableUser
    Blocks sign-in for the user account behind the mailbox. Booking keeps working.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "MailboxName": {
                "DisplayName": "Alias"
            },
            "DisplayName": {
                "DisplayName": "Display name"
            },
            "CallerName": {
                "Hide": true
            },
            "AutoAccept": {
                "DisplayName": "Accept meeting requests automatically?"
            },
            "AutoMapping": {
                "DisplayName": "Open automatically in the delegate's Outlook?"
            },
            "DisableUser": {
                "DisplayName": "Block sign-in for the mailbox account?"
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param (
    [Parameter(Mandatory = $true)]
    [string] $MailboxName,
    [string] $DisplayName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string] $DelegateTo,
    [bool] $AutoAccept = $false,
    [bool] $AutoMapping = $false,
    [bool] $DisableUser = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

try {
    Connect-RjRbExchangeOnline

    $invokeParams = @{
        Name      = $MailboxName
        Alias     = $MailboxName
        Equipment = $true
    }

    if ($DisplayName) {
        $invokeParams += @{ DisplayName = $DisplayName }
    }

    # Create the mailbox
    $mailbox = New-Mailbox @invokeParams

    $found = $false
    while (-not $found) {
        $mailbox = Get-Mailbox -Identity $MailboxName -ErrorAction SilentlyContinue
        if ($null -eq $mailbox) {
            ".. Waiting for mailbox to be created..."
            Start-Sleep -Seconds 5
        }
        else {
            $found = $true
        }
    }

    if ($DelegateTo) {
        # "Grant SendOnBehalf"
        $mailbox | Set-Mailbox -GrantSendOnBehalfTo $DelegateTo | Out-Null
        # "Grant FullAccess"
        $mailbox | Add-MailboxPermission -User $DelegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
        # Calendar delegation
        Set-CalendarProcessing -Identity $MailboxName -ResourceDelegates $DelegateTo
    }

    if ($AutoAccept) {
        Set-CalendarProcessing -Identity $MailboxName -AutomateProcessing "AutoAccept"
    }

    if ($DisableUser) {
        # Deactive the user account using the Graph API
        $user = $null
        $retryCount = 0
        while (($null -eq $user) -and ($retryCount -lt 10)) {
            $user = Invoke-RjRbRestMethodGraph -Resource "/users" -Method Get -OdFilter "mailNickname eq '$MailboxName'" -ErrorAction Stop
            if ($null -eq $user) {
                $retryCount++
                ".. Waiting for user object to be created..."
                Start-Sleep -Seconds 5
            }
        }
        $body = @{
            accountEnabled = $false
        }
        Invoke-RjRbRestMethodGraph -Resource "/users/$($user.id)" -Method Patch -Body $body -ErrorAction Stop
    }

    "## Equipment Mailbox '$MailboxName' has been created."
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
<#
    .SYNOPSIS
    Create a room mailbox resource

    .DESCRIPTION
    Creates an Exchange Online room mailbox and optionally configures delegation and calendar processing. If requested, the associated Entra ID user account is disabled after creation.

    .PARAMETER MailboxName
    Alias (mail nickname) for the room mailbox.

    .PARAMETER DisplayName
    Optional display name for the room mailbox.

    .PARAMETER DelegateTo
    Optional user who receives delegated access to the mailbox.

    .PARAMETER Capacity
    Optional room capacity in number of people.

    .PARAMETER AutoAccept
    If set to true, meeting requests are automatically accepted.

    .PARAMETER AutoMapping
    If set to true, the mailbox is automatically mapped in Outlook for the delegate.

    .PARAMETER DisableUser
    If set to true, the associated Entra ID user account is disabled.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
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
    [string] $MailboxName,
    [string] $DisplayName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string] $DelegateTo,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Room capacity (people)" } )]
    [int] $Capacity,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Automatically accept meeting requests" } )]
    [bool] $AutoAccept = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Automatically map mailbox in Outlook" } )]
    [bool] $AutoMapping = $false,
    # CallerName is tracked purely for auditing purposes
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Disable AAD User" } )]
    [bool] $DisableUser = $true,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

try {
    Connect-RjRbGraph
    Connect-RjRbExchangeOnline

    $invokeParams = @{
        Name  = $MailboxName
        Alias = $MailboxName
        Room  = $true
    }

    if ($DisplayName) {
        $invokeParams += @{ DisplayName = $DisplayName }
    }

    if ($Capacity -and ($Capacity -gt 0)) {
        $invokeParams += @{ ResourceCapacity = $Capacity }
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
        Set-CalendarProcessing -Identity $MailboxName -ResourceDelegates $DelegateTo -AutomateProcessing AutoAccept -AllRequestInPolicy $true -AllBookInPolicy $false
    }

    if ($AutoAccept) {
        Set-CalendarProcessing -Identity $MailboxName -AutomateProcessing "AutoAccept" -AllRequestInPolicy $true -AllBookInPolicy $true
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

    "## Room Mailbox '$MailboxName' has been created."
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
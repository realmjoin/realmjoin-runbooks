<#
  .SYNOPSIS
  Create a shared mailbox.

  .DESCRIPTION
  Create a shared mailbox.

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "Language": {
                "SelectSimple": {
                    "en-US": "en-US",
                    "de-DE": "de-DE",
                    "fr-FR": "fr-FR"
                }
            }
        }
    }

  .EXAMPLE
      "Runbooks": {
        "rjgit-org_mail_add-shared-mailbox": {
            "ParameterList": [
                {
                    "Name": "DomainName",
                    "Select": {
                        "Options": [
                                {
                                    "Value": "contoso.onmicrosoft.com"
                                },
                                {
                                    "Value": "contoso.com"
                                }
                            ]
                    },
                    "DefaultValue": "contoso.com"
                }
            ]
        }
    }


#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)]
    [string] $MailboxName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "DisplayName" } )]
    [string] $DisplayName,
    [string] $DomainName,
    [string] $Language = "en-US",
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string] $DelegateTo,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Automatically map mailbox in Outlook" } )]
    [bool] $AutoMapping = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Save a copy of sent mails into shared mailbox's Sent Item folder for Send As Delegates" } )]
    [bool] $MessageCopyForSentAsEnabled = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Save a copy of sent mails into shared mailbox's Sent Item folder for Send On behalf Delegates" } )]
    [bool]$MessageCopyForSendOnBehalfEnabled = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Disable AAD User" } )]
    [bool] $DisableUser = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

try {
    Connect-RjRbExchangeOnline

    # make sure a displayName exists
    if (-not $DisplayName) {
        $DisplayName = $MailboxName
    }

    # Create the mailbox
    if (-not $DomainName) {
        $mailbox = New-Mailbox -Shared -Name $MailboxName -DisplayName $DisplayName -Alias $MailboxName
    }
    else {
        $mailbox = New-Mailbox -Shared -Name $MailboxName -DisplayName $DisplayName -Alias $MailboxName -PrimarySmtpAddress ($MailboxName + "@" + $DomainName)
    }

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
    }

    $mailbox | Set-Mailbox -MessageCopyForSentAsEnabled $MessageCopyForSentAsEnabled | Out-Null
    $mailbox | Set-Mailbox -MessageCopyForSendOnBehalfEnabled $MessageCopyForSendOnBehalfEnabled | Out-Null

    # Set Language ( i.e. rename folders like "inbox" )
    $mailbox |  Set-MailboxRegionalConfiguration -Language $Language -LocalizeDefaultFolderName

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

    "## Shared Mailbox '$MailboxName' has been created."

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
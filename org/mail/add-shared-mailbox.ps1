<#
  .SYNOPSIS
  Create a shared mailbox.

  .DESCRIPTION
  Create a shared mailbox.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.1" }, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)] 
    [string] $MailboxName,
    [ValidateScript( { Use-RJInterface -DisplayName "DisplayName" } )]
    [string] $DisplayName,
    [string] $DomainName,
    [string] $Language = "en-US",
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string] $DelegateTo,
    [ValidateScript( { Use-RJInterface -DisplayName "Automatically map mailbox in Outlook" } )]
    [bool] $AutoMapping = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Save a copy of sent mails into shared mailbox's Sent Item folder for Send As Delegates" } )]
    [bool] $MessageCopyForSentAsEnabled = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Save a copy of sent mails into shared mailbox's Sent Item folder for Send On behalf Delegates" } )]
    [bool]$MessageCopyForSendOnBehalfEnabled = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

try {
    Connect-RjRbExchangeOnline

    # make sure a displayName exists
    if (-not $DisplayName) {
        $DisplayName = $MailboxName
    }

    # Create the mailbox
    if (-not $DomainName) {
        $mailbox = New-Mailbox -Shared -Name $MailboxName -DisplayName $DisplayName -Alias $MailboxName 
    } else {
        $mailbox = New-Mailbox -Shared -Name $MailboxName -DisplayName $DisplayName -Alias $MailboxName -PrimarySmtpAddress ($MailboxName + "@" + $DomainName) 
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

    "## Shared Mailbox '$MailboxName' has been created."

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
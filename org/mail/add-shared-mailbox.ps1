<#
  .SYNOPSIS
  Create a shared mailbox.

  .DESCRIPTION
  This script creates a shared mailbox in Exchange Online and configures various settings such as delegation, auto-mapping, and message copy options.
  Also if specified, it disables the associated EntraID user account.

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

########################################################
#region     RJ Log Part
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "MailboxName: '$MailboxName'" -Verbose
Write-RjRbLog -Message "DisplayName: '$DisplayName'" -Verbose
Write-RjRbLog -Message "DomainName: '$DomainName'" -Verbose
Write-RjRbLog -Message "Language: '$Language'" -Verbose
Write-RjRbLog -Message "DelegateTo: '$DelegateTo'" -Verbose
Write-RjRbLog -Message "AutoMapping: '$AutoMapping'" -Verbose
Write-RjRbLog -Message "MessageCopyForSentAsEnabled: '$MessageCopyForSentAsEnabled'" -Verbose
Write-RjRbLog -Message "MessageCopyForSendOnBehalfEnabled: '$MessageCopyForSendOnBehalfEnabled'" -Verbose
Write-RjRbLog -Message "DisableUser: '$DisableUser'" -Verbose

#endregion

########################################################
#region     Connect and Initialize
########################################################

Write-Output "Connecting to Microsoft Graph..."
Connect-MgGraph -Identity -NoWelcome

try {
    Write-Output "Connecting to Exchange Online..."
    Connect-RjRbExchangeOnline
}
catch {
    Write-Error "Failed to connect to Exchange Online: $_"
    throw $_
}

try {
    # make sure a displayName exists
    if (-not $DisplayName) {
        $DisplayName = $MailboxName
    }

    # Check for alias conflicts and adjust if necessary
    $aliasToUse = $MailboxName
    $aliasConflict = $false

    Write-RjRbLog -Message "Checking for alias conflicts..." -Verbose
    $existingRecipient = Get-Recipient -Identity $aliasToUse -ErrorAction SilentlyContinue

    if ($existingRecipient) {
        Write-RjRbLog -Message "Alias '$aliasToUse' is already in use. Generating alternative alias..." -Warning
        $aliasConflict = $true

        # Generate random 4-digit number and append to alias
        $randomNumber = Get-Random -Minimum 1000 -Maximum 9999
        $aliasToUse = "$MailboxName$randomNumber"

        Write-RjRbLog -Message "New alias will be: '$aliasToUse'" -Verbose

        # Verify the new alias is available
        $existingRecipient = Get-Recipient -Identity $aliasToUse -ErrorAction SilentlyContinue
        if ($existingRecipient) {
            throw "Generated alias '$aliasToUse' is also already in use. Please try again or contact support."
        }
    }

    # Create the mailbox
    if (-not $DomainName) {
        $mailbox = New-Mailbox -Shared -Name $MailboxName -DisplayName $DisplayName -Alias $aliasToUse
    }
    else {
        $mailbox = New-Mailbox -Shared -Name $MailboxName -DisplayName $DisplayName -Alias $aliasToUse -PrimarySmtpAddress ($MailboxName + "@" + $DomainName)
    }

    if ($aliasConflict) {
        Write-RjRbLog -Message "## Note: Due to an alias conflict, the mailbox alias was set to '$aliasToUse' instead of '$MailboxName'" -Warning
    }

    $found = $false
    $identityToCheck = if ($aliasConflict) { $aliasToUse } else { $MailboxName }
    while (-not $found) {
        $mailbox = Get-Mailbox -Identity $identityToCheck -ErrorAction SilentlyContinue
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
        $mailNicknameToCheck = if ($aliasConflict) { $aliasToUse } else { $MailboxName }
        while (($null -eq $user) -and ($retryCount -lt 10)) {
            $user = Invoke-MgGraphRequest -Method Get -Uri "https://graph.microsoft.com/v1.0/users?`$filter=mailNickname eq '$mailNicknameToCheck'" -ErrorAction Stop
            if ($null -eq $user) {
                $retryCount++
                ".. Waiting for user object to be created..."
                Start-Sleep -Seconds 5
            }
        }
        $body = @{
            accountEnabled = $false
        }
        Invoke-MgGraphRequest -Method Patch -Uri "https://graph.microsoft.com/v1.0/users/$($user.id)" -Body $body -ErrorAction Stop
    }

    if ($aliasConflict) {
        "## Shared Mailbox '$MailboxName' has been created with alias '$aliasToUse' (due to conflict)."
    }
    else {
        "## Shared Mailbox '$MailboxName' has been created."
    }

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
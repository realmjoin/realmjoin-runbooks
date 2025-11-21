<#
    .SYNOPSIS
    Create a shared mailbox.

    .DESCRIPTION
    This script creates a shared mailbox in Exchange Online and configures various settings such as delegation, auto-mapping, and message copy options.
    Also if specified, it disables the associated EntraID user account.

    .PARAMETER MailboxName
    The alias (mailbox name) for the shared mailbox.

    .PARAMETER DisplayName
    The display name for the shared mailbox.

    .PARAMETER DomainName
    The domain name to be used for the primary SMTP address of the shared mailbox. If not specified, the default domain will be used.

    .PARAMETER Language
    The language/locale for the shared mailbox. This setting affects folder names like "Inbox". Default is "en-US".

    .PARAMETER DelegateTo
    The user to delegate access to the shared mailbox.

    .PARAMETER AutoMapping
    If set to true, the shared mailbox will be automatically mapped in Outlook for the delegate user.

    .PARAMETER MessageCopyForSentAsEnabled
    If set to true, a copy of sent emails will be saved in the shared mailbox's Sent Items folder when sent as the shared mailbox.

    .PARAMETER MessageCopyForSendOnBehalfEnabled
    If set to true, a copy of sent emails will be saved in the shared mailbox's Sent Items folder when sent on behalf of the shared mailbox.

    .PARAMETER DisableUser
    If set to true, the associated EntraID user account will be disabled.

    .PARAMETER CallerName
    The name of the caller executing this script. This parameter is used for auditing purposes.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

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
Write-RjRbLog -Message "MailboxName: $($MailboxName)" -Verbose
Write-RjRbLog -Message "DisplayName: $($DisplayName)" -Verbose
Write-RjRbLog -Message "DomainName: $($DomainName)" -Verbose
Write-RjRbLog -Message "Language: $($Language)" -Verbose
Write-RjRbLog -Message "DelegateTo: $($DelegateTo)" -Verbose
Write-RjRbLog -Message "AutoMapping: $($AutoMapping)" -Verbose
Write-RjRbLog -Message "MessageCopyForSentAsEnabled: $($MessageCopyForSentAsEnabled)" -Verbose
Write-RjRbLog -Message "MessageCopyForSendOnBehalfEnabled: $($MessageCopyForSendOnBehalfEnabled)" -Verbose
Write-RjRbLog -Message "DisableUser: $($DisableUser)" -Verbose

#endregion

########################################################
#region     Connect and Initialize
########################################################

try {
    Write-Output "Connecting to Microsoft Graph..."
    Connect-MgGraph -Identity -NoWelcome
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    throw $_
}

try {
    Write-Output "Connecting to Exchange Online..."
    Connect-RjRbExchangeOnline
}
catch {
    Write-Error "Failed to connect to Exchange Online: $_"
    throw $_
}

#endregion

########################################################
#region     Create Shared Mailbox
########################################################
try {
    # make sure a displayName exists
    if (-not $DisplayName) {
        $DisplayName = $MailboxName
    }

    # Check for alias conflicts and adjust if necessary
    $aliasToUse = $MailboxName
    $nameToUse = $MailboxName
    $aliasConflict = $false

    # Build primary SMTP address
    $primarySmtpAddress = if ($DomainName) { "$($MailboxName)@$($DomainName)" } else { $null }

    # First check if the exact mailbox (mailboxname@domain) already exists
    if ($primarySmtpAddress) {
        Write-Output "Checking if mailbox '$($primarySmtpAddress)' already exists..."
        $existingMailbox = Get-Recipient -Identity $primarySmtpAddress -ErrorAction SilentlyContinue
        if ($existingMailbox) {
            throw "A mailbox with the primary SMTP address '$($primarySmtpAddress)' already exists. Please use a different mailbox name or domain."
        }
    }

    Write-Output "Checking for alias conflicts..."
    $existingRecipient = Get-Recipient -Identity $aliasToUse -ErrorAction SilentlyContinue

    if ($existingRecipient) {
        Write-Output "Alias '$($aliasToUse)' is already in use by another recipient."

        # Check if it's the same combination of mailboxname@domain
        if ($primarySmtpAddress) {
            $existingPrimarySmtp = $existingRecipient.PrimarySmtpAddress
            if ($existingPrimarySmtp -eq $primarySmtpAddress) {
                throw "A mailbox with the exact combination '$($primarySmtpAddress)' already exists. Aborting."
            }
        }

        Write-Output "Generating alternative alias..."
        $aliasConflict = $true

        # Generate random 4-digit number and append to alias
        $randomNumber = Get-Random -Minimum 1000 -Maximum 9999
        $aliasToUse = "$($MailboxName)$($randomNumber)"

        # Also adjust the name to include domain for better identification
        if ($DomainName) {
            $nameToUse = "$($MailboxName) | $($DomainName)"
        }
        else {
            $nameToUse = "$($MailboxName)$($randomNumber)"
        }

        Write-Output "New alias will be: '$($aliasToUse)'"
        Write-Output "Name will be: '$($nameToUse)'"

        # Verify the new alias is available
        $existingRecipient = Get-Recipient -Identity $aliasToUse -ErrorAction SilentlyContinue
        if ($existingRecipient) {
            throw "Generated alias '$($aliasToUse)' is also already in use. Please try again or contact support."
        }
        else {
            Write-Output "Alias '$($aliasToUse)' is available."
        }
    }

    Write-Output ""
    if ($primarySmtpAddress) {
        Write-Output "Creating shared mailbox '$($primarySmtpAddress)'..."
    }
    else {
        Write-Output "Creating shared mailbox '$($MailboxName)'..."
    }

    # Create the mailbox
    if (-not $DomainName) {
        $mailbox = New-Mailbox -Shared -Name $nameToUse -DisplayName $DisplayName -Alias $aliasToUse
    }
    else {
        $mailbox = New-Mailbox -Shared -Name $nameToUse -DisplayName $DisplayName -Alias $aliasToUse -PrimarySmtpAddress $primarySmtpAddress
    }

    if ($aliasConflict) {
        Write-Warning "## Note: Due to an alias conflict, the mailbox alias was set to '$aliasToUse' instead of '$MailboxName'"
        Write-Output "Updating MicrosoftOnlineServicesID to match primary SMTP address..."

        # Update the UserPrincipalName to match the primary SMTP address
        if ($primarySmtpAddress) {
            $mailbox | Set-Mailbox -MicrosoftOnlineServicesID $primarySmtpAddress -ErrorAction SilentlyContinue
        }
    }

#endregion

########################################################
#region     Configure Mailbox Settings
########################################################

    Write-Output "Configuring mailbox settings..."
    $found = $false
    $identityToCheck = if ($primarySmtpAddress) { $primarySmtpAddress } elseif ($aliasConflict) { $aliasToUse } else { $MailboxName }
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
        Write-Output "Configuring delegate permissions for '$($DelegateTo)'..."
        # "Grant SendOnBehalf"
        $mailbox | Set-Mailbox -GrantSendOnBehalfTo $DelegateTo | Out-Null
        # "Grant FullAccess"
        $mailbox | Add-MailboxPermission -User $DelegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
    }

    $mailbox | Set-Mailbox -MessageCopyForSentAsEnabled $MessageCopyForSentAsEnabled | Out-Null
    $mailbox | Set-Mailbox -MessageCopyForSendOnBehalfEnabled $MessageCopyForSendOnBehalfEnabled | Out-Null

    # Set Language ( i.e. rename folders like "inbox" )
    Write-Output "Configuring mailbox regional settings..."
    $mailbox |  Set-MailboxRegionalConfiguration -Language $Language -LocalizeDefaultFolderName

    if ($DisableUser) {
        Write-Output "Disabling associated EntraID user account..."
        # Deactive the user account using the Graph API
        $user = $null
        $retryCount = 0
        $mailNicknameToCheck = if ($aliasConflict) { $aliasToUse } else { $MailboxName }
        while (($null -eq $user) -and ($retryCount -lt 10)) {
            $response = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users?`$filter=mailNickname eq '$mailNicknameToCheck'" -ErrorAction Stop
            if ($response.value -and $response.value.Count -gt 0) {
                $user = $response.value[0]
            }
            else {
                $retryCount++
                ".. Waiting for user object to be created..."
                Start-Sleep -Seconds 5
            }
        }

        if ($null -eq $user) {
            Write-Warning "Could not find user object to disable after 10 retries."
        }
        else {
            $body = @{
                accountEnabled = $false
            } | ConvertTo-Json
            Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/users/$($user.id)" -Body $body -ContentType "application/json" -ErrorAction Stop
        }
    }

    if ($aliasConflict) {
        Write-Output "## Shared Mailbox '$MailboxName' has been created."
        Write-Output "   Primary SMTP: $($mailbox.PrimarySmtpAddress)"
        Write-Output "   Alias: $aliasToUse (adjusted due to conflict)"
        Write-Output "   Name: $nameToUse"
    }
    else {
        Write-Output "## Shared Mailbox '$MailboxName' has been created."
        if ($mailbox.PrimarySmtpAddress) {
            Write-Output "   Primary SMTP: $($mailbox.PrimarySmtpAddress)"
        }
    }

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
#endregion
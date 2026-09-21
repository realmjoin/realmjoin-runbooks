<#
	.SYNOPSIS
	Create a shared mailbox with optional delegate

	.DESCRIPTION
	Creates a shared mailbox in Exchange Online with the chosen language and time zone. A delegate can get full access, and sent mails can be kept in the shared Sent Items folder. The user account behind the mailbox can be disabled so nobody signs in with it.

	.PARAMETER MailboxName
	Alias of the mailbox, which becomes the part of the email address in front of the @ sign.

	.PARAMETER DisplayName
	Name shown in the address book. Leave empty to use the alias.

	.PARAMETER DomainName
	Domain of the email address. Leave empty to use the default domain of the tenant.

	.PARAMETER Language
	Language of the mailbox, which sets the names of the default folders such as Inbox.

	.PARAMETER TimeZone
	Time zone used for the calendar and timestamps of the mailbox.

	.PARAMETER DelegateTo
	User who gets full access to the mailbox. Leave empty for none.

	.PARAMETER AutoMapping
	The mailbox opens automatically in the delegate's Outlook.

	.PARAMETER MessageCopyForSentAsEnabled
	Mails sent as the shared mailbox are also stored in its Sent Items folder.

	.PARAMETER MessageCopyForSendOnBehalfEnabled
	Mails sent on behalf of the shared mailbox are also stored in its Sent Items folder.

	.PARAMETER DisableUser
	Blocks sign-in for the user account behind the mailbox. Delegates keep their access.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"MailboxName": {
				"DisplayName": "Alias"
			},
			"DomainName": {
				"DisplayName": "Domain"
			},
			"CallerName": {
				"Hide": true
			},
			"Language": {
				"DisplayName": "Language",
				"SelectSimple": {
					"en-US": "en-US",
					"de-DE": "de-DE",
					"fr-FR": "fr-FR"
				}
			},
			"TimeZone": {
				"DisplayName": "Time zone",
				"SelectSimple": {
					"W. Europe Standard Time": "W. Europe Standard Time",
					"Central Europe Standard Time": "Central Europe Standard Time",
					"E. Europe Standard Time": "E. Europe Standard Time",
					"GMT Standard Time": "GMT Standard Time",
					"UTC": "UTC",
					"Eastern Standard Time": "Eastern Standard Time",
					"Central Standard Time": "Central Standard Time",
					"Mountain Standard Time": "Mountain Standard Time",
					"Pacific Standard Time": "Pacific Standard Time",
					"Alaska Standard Time": "Alaska Standard Time",
					"Hawaiian Standard Time": "Hawaiian Standard Time",
					"China Standard Time": "China Standard Time",
					"Tokyo Standard Time": "Tokyo Standard Time",
					"Korea Standard Time": "Korea Standard Time",
					"India Standard Time": "India Standard Time",
					"Arabian Standard Time": "Arabian Standard Time",
					"AUS Eastern Standard Time": "AUS Eastern Standard Time",
					"New Zealand Standard Time": "New Zealand Standard Time",
					"Romance Standard Time": "Romance Standard Time",
					"Russian Standard Time": "Russian Standard Time",
					"SA Pacific Standard Time": "SA Pacific Standard Time",
					"SE Asia Standard Time": "SE Asia Standard Time",
					"Singapore Standard Time": "Singapore Standard Time",
					"South Africa Standard Time": "South Africa Standard Time",
					"Turkey Standard Time": "Turkey Standard Time",
					"Argentina Standard Time": "Argentina Standard Time",
					"Atlantic Standard Time": "Atlantic Standard Time",
					"Canada Central Standard Time": "Canada Central Standard Time",
					"E. South America Standard Time": "E. South America Standard Time",
					"FLE Standard Time": "FLE Standard Time",
					"Israel Standard Time": "Israel Standard Time",
					"Middle East Standard Time": "Middle East Standard Time",
					"Nepal Standard Time": "Nepal Standard Time",
					"West Pacific Standard Time": "West Pacific Standard Time"
				}
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param(
    [Parameter(Mandatory = $true)]
    [string] $MailboxName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Display name" } )]
    [string] $DisplayName,
    [string] $DomainName,
    [string] $Language = "en-US",
    [string] $TimeZone = "W. Europe Standard Time",
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string] $DelegateTo,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Open automatically in the delegate's Outlook?" } )]
    [bool] $AutoMapping = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Keep copies of mails sent as the mailbox?" } )]
    [bool] $MessageCopyForSentAsEnabled = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Keep copies of mails sent on behalf?" } )]
    [bool]$MessageCopyForSendOnBehalfEnabled = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Block sign-in for the mailbox account?" } )]
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

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "MailboxName: $($MailboxName)" -Verbose
Write-RjRbLog -Message "DisplayName: $($DisplayName)" -Verbose
Write-RjRbLog -Message "DomainName: $($DomainName)" -Verbose
Write-RjRbLog -Message "Language: $($Language)" -Verbose
Write-RjRbLog -Message "TimeZone: $($TimeZone)" -Verbose
Write-RjRbLog -Message "DelegateTo: $($DelegateTo)" -Verbose
Write-RjRbLog -Message "AutoMapping: $($AutoMapping)" -Verbose
Write-RjRbLog -Message "MessageCopyForSentAsEnabled: $($MessageCopyForSentAsEnabled)" -Verbose
Write-RjRbLog -Message "MessageCopyForSendOnBehalfEnabled: $($MessageCopyForSendOnBehalfEnabled)" -Verbose
Write-RjRbLog -Message "DisableUser: $($DisableUser)" -Verbose
#endregion RJ Log Part

########################################################
#region     Connect Part
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
#endregion Connect Part

########################################################
#region     Main Part
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
    }

    if ($primarySmtpAddress) {
        Write-Output "Aligning UserPrincipalName with the primary SMTP address '$($primarySmtpAddress)'..."
        try {
            $mailbox | Set-Mailbox -MicrosoftOnlineServicesID $primarySmtpAddress -ErrorAction Stop
            Write-Output "UserPrincipalName set to '$($primarySmtpAddress)'."
        }
        catch {
            Write-RjRbLog -Message "Failed to align UserPrincipalName: $($_.Exception.Message)" -Verbose
            Write-Error "Failed to set the UserPrincipalName to '$($primarySmtpAddress)': $($_.Exception.Message)" -ErrorAction Continue
            throw "The shared mailbox was created, but its UserPrincipalName could not be aligned with the primary SMTP address '$($primarySmtpAddress)'. Verify that the domain '$($DomainName)' is verified in the tenant and that no other object already uses this address, then correct the UPN manually."
        }
    }

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
    $mailbox |  Set-MailboxRegionalConfiguration -Language $Language -TimeZone $TimeZone -LocalizeDefaultFolderName

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
        Write-Output "   UserPrincipalName: $($mailbox.UserPrincipalName)"
        Write-Output "   Alias: $aliasToUse (adjusted due to conflict)"
        Write-Output "   Name: $nameToUse"
    }
    else {
        Write-Output "## Shared Mailbox '$MailboxName' has been created."
        if ($mailbox.PrimarySmtpAddress) {
            Write-Output "   Primary SMTP: $($mailbox.PrimarySmtpAddress)"
        }
        if ($mailbox.UserPrincipalName) {
            Write-Output "   UserPrincipalName: $($mailbox.UserPrincipalName)"
        }
    }

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
#endregion Main Part

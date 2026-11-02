<#
	.SYNOPSIS
	Create a shared mailbox with optional delegates

	.DESCRIPTION
	Creates a shared mailbox in Exchange Online with the chosen language and time zone. Delegates can get full access and send on behalf of the mailbox, and sent mails can be kept in the shared Sent Items folder. The user account behind the mailbox can be disabled so nobody signs in with it.

	.PARAMETER MailboxName
	Alias of the mailbox, which becomes the part of the email address in front of the @ sign.

	.PARAMETER DisplayName
	Name shown in the address book. Leave empty to use the alias.

	.PARAMETER DomainName
	Domain of the email address. Leave empty to use the default domain of the tenant.

	.PARAMETER Language
	Language of the mailbox, which sets the names of the default folders such as Inbox.

	.PARAMETER TimeZone
	Time zone used for the calendar and timestamps of the mailbox. The list shows the standard time offset; daylight saving time is applied automatically where the region uses it.

	.PARAMETER DelegateTo
	People who get full access to the mailbox and can send on its behalf. You can pick several at once; leave empty for none. Nothing is created if one of them is not found in Exchange Online.

	.PARAMETER AutoMapping
	The mailbox opens automatically in the delegates' Outlook.

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
			"DisplayName": {
				"DisplayName": "Display name"
			},
			"DomainName": {
				"DisplayName": "Domain"
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
					"(UTC-12:00) International Date Line West": "Dateline Standard Time",
					"(UTC-10:00) Aleutian Islands": "Aleutian Standard Time",
					"(UTC-10:00) Hawaii": "Hawaiian Standard Time",
					"(UTC-09:30) Marquesas Islands": "Marquesas Standard Time",
					"(UTC-09:00) Alaska": "Alaskan Standard Time",
					"(UTC-08:00) Baja California": "Pacific Standard Time (Mexico)",
					"(UTC-08:00) Pacific Time (US & Canada)": "Pacific Standard Time",
					"(UTC-07:00) Arizona": "US Mountain Standard Time",
					"(UTC-07:00) La Paz, Mazatlan": "Mountain Standard Time (Mexico)",
					"(UTC-07:00) Mountain Time (US & Canada)": "Mountain Standard Time",
					"(UTC-07:00) Pacific Time (British Columbia)": "British Columbia Standard Time",
					"(UTC-07:00) Yukon": "Yukon Standard Time",
					"(UTC-06:00) Central America": "Central America Standard Time",
					"(UTC-06:00) Central Time (US & Canada)": "Central Standard Time",
					"(UTC-06:00) Easter Island": "Easter Island Standard Time",
					"(UTC-06:00) Guadalajara, Mexico City, Monterrey": "Central Standard Time (Mexico)",
					"(UTC-06:00) Mountain Time (Alberta)": "Alberta Standard Time",
					"(UTC-06:00) Saskatchewan": "Canada Central Standard Time",
					"(UTC-05:00) Bogota, Lima, Quito, Rio Branco": "SA Pacific Standard Time",
					"(UTC-05:00) Chetumal": "Eastern Standard Time (Mexico)",
					"(UTC-05:00) Eastern Time (US & Canada)": "Eastern Standard Time",
					"(UTC-05:00) Haiti": "Haiti Standard Time",
					"(UTC-05:00) Havana": "Cuba Standard Time",
					"(UTC-05:00) Indiana (East)": "US Eastern Standard Time",
					"(UTC-05:00) Manitoba": "Manitoba Standard Time",
					"(UTC-05:00) Turks and Caicos": "Turks And Caicos Standard Time",
					"(UTC-04:00) Atlantic Time (Canada)": "Atlantic Standard Time",
					"(UTC-04:00) Caracas": "Venezuela Standard Time",
					"(UTC-04:00) Cuiaba": "Central Brazilian Standard Time",
					"(UTC-04:00) Georgetown, La Paz, Manaus, San Juan": "SA Western Standard Time",
					"(UTC-04:00) Santiago": "Pacific SA Standard Time",
					"(UTC-03:30) Newfoundland": "Newfoundland Standard Time",
					"(UTC-03:00) Araguaina": "Tocantins Standard Time",
					"(UTC-03:00) Asuncion": "Paraguay Standard Time",
					"(UTC-03:00) Brasilia": "E. South America Standard Time",
					"(UTC-03:00) Cayenne, Fortaleza": "SA Eastern Standard Time",
					"(UTC-03:00) City of Buenos Aires": "Argentina Standard Time",
					"(UTC-03:00) Montevideo": "Montevideo Standard Time",
					"(UTC-03:00) Punta Arenas": "Magallanes Standard Time",
					"(UTC-03:00) Saint Pierre and Miquelon": "Saint Pierre Standard Time",
					"(UTC-03:00) Salvador": "Bahia Standard Time",
					"(UTC-02:00) Greenland": "Greenland Standard Time",
					"(UTC-01:00) Azores": "Azores Standard Time",
					"(UTC-01:00) Cabo Verde Is.": "Cape Verde Standard Time",
					"(UTC) Coordinated Universal Time": "UTC",
					"(UTC+00:00) Casablanca": "Morocco Standard Time",
					"(UTC+00:00) Dublin, Edinburgh, Lisbon, London": "GMT Standard Time",
					"(UTC+00:00) Monrovia, Reykjavik": "Greenwich Standard Time",
					"(UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna": "W. Europe Standard Time",
					"(UTC+01:00) Belgrade, Bratislava, Budapest, Ljubljana, Prague": "Central Europe Standard Time",
					"(UTC+01:00) Brussels, Copenhagen, Madrid, Paris": "Romance Standard Time",
					"(UTC+01:00) Sarajevo, Skopje, Warsaw, Zagreb": "Central European Standard Time",
					"(UTC+01:00) West Central Africa": "W. Central Africa Standard Time",
					"(UTC+02:00) Athens, Bucharest": "GTB Standard Time",
					"(UTC+02:00) Beirut": "Middle East Standard Time",
					"(UTC+02:00) Cairo": "Egypt Standard Time",
					"(UTC+02:00) Chisinau": "E. Europe Standard Time",
					"(UTC+02:00) Gaza, Hebron": "West Bank Standard Time",
					"(UTC+02:00) Harare, Pretoria": "South Africa Standard Time",
					"(UTC+02:00) Helsinki, Kyiv, Riga, Sofia, Tallinn, Vilnius": "FLE Standard Time",
					"(UTC+02:00) Jerusalem": "Israel Standard Time",
					"(UTC+02:00) Juba": "South Sudan Standard Time",
					"(UTC+02:00) Kaliningrad": "Kaliningrad Standard Time",
					"(UTC+02:00) Khartoum": "Sudan Standard Time",
					"(UTC+02:00) Tripoli": "Libya Standard Time",
					"(UTC+02:00) Windhoek": "Namibia Standard Time",
					"(UTC+03:00) Amman": "Jordan Standard Time",
					"(UTC+03:00) Baghdad": "Arabic Standard Time",
					"(UTC+03:00) Damascus": "Syria Standard Time",
					"(UTC+03:00) Istanbul": "Turkey Standard Time",
					"(UTC+03:00) Kuwait, Riyadh": "Arab Standard Time",
					"(UTC+03:00) Minsk": "Belarus Standard Time",
					"(UTC+03:00) Moscow, St. Petersburg": "Russian Standard Time",
					"(UTC+03:00) Nairobi": "E. Africa Standard Time",
					"(UTC+03:00) Volgograd": "Volgograd Standard Time",
					"(UTC+03:30) Tehran": "Iran Standard Time",
					"(UTC+04:00) Abu Dhabi, Muscat": "Arabian Standard Time",
					"(UTC+04:00) Astrakhan, Ulyanovsk": "Astrakhan Standard Time",
					"(UTC+04:00) Baku": "Azerbaijan Standard Time",
					"(UTC+04:00) Izhevsk, Samara": "Russia Time Zone 3",
					"(UTC+04:00) Port Louis": "Mauritius Standard Time",
					"(UTC+04:00) Saratov": "Saratov Standard Time",
					"(UTC+04:00) Tbilisi": "Georgian Standard Time",
					"(UTC+04:00) Yerevan": "Caucasus Standard Time",
					"(UTC+04:30) Kabul": "Afghanistan Standard Time",
					"(UTC+05:00) Ashgabat, Tashkent": "West Asia Standard Time",
					"(UTC+05:00) Astana": "Qyzylorda Standard Time",
					"(UTC+05:00) Ekaterinburg": "Ekaterinburg Standard Time",
					"(UTC+05:00) Islamabad, Karachi": "Pakistan Standard Time",
					"(UTC+05:30) Chennai, Kolkata, Mumbai, New Delhi": "India Standard Time",
					"(UTC+05:30) Sri Jayawardenepura": "Sri Lanka Standard Time",
					"(UTC+05:45) Kathmandu": "Nepal Standard Time",
					"(UTC+06:00) Bishkek": "Central Asia Standard Time",
					"(UTC+06:00) Dhaka": "Bangladesh Standard Time",
					"(UTC+06:00) Omsk": "Omsk Standard Time",
					"(UTC+06:30) Yangon (Rangoon)": "Myanmar Standard Time",
					"(UTC+07:00) Bangkok, Hanoi, Jakarta": "SE Asia Standard Time",
					"(UTC+07:00) Barnaul, Gorno-Altaysk": "Altai Standard Time",
					"(UTC+07:00) Hovd": "W. Mongolia Standard Time",
					"(UTC+07:00) Krasnoyarsk": "North Asia Standard Time",
					"(UTC+07:00) Novosibirsk": "N. Central Asia Standard Time",
					"(UTC+07:00) Tomsk": "Tomsk Standard Time",
					"(UTC+08:00) Beijing, Chongqing, Hong Kong, Urumqi": "China Standard Time",
					"(UTC+08:00) Irkutsk": "North Asia East Standard Time",
					"(UTC+08:00) Kuala Lumpur, Singapore": "Singapore Standard Time",
					"(UTC+08:00) Perth": "W. Australia Standard Time",
					"(UTC+08:00) Taipei": "Taipei Standard Time",
					"(UTC+08:00) Ulaanbaatar": "Ulaanbaatar Standard Time",
					"(UTC+08:45) Eucla": "Aus Central W. Standard Time",
					"(UTC+09:00) Chita": "Transbaikal Standard Time",
					"(UTC+09:00) Osaka, Sapporo, Tokyo": "Tokyo Standard Time",
					"(UTC+09:00) Pyongyang": "North Korea Standard Time",
					"(UTC+09:00) Seoul": "Korea Standard Time",
					"(UTC+09:00) Yakutsk": "Yakutsk Standard Time",
					"(UTC+09:30) Adelaide": "Cen. Australia Standard Time",
					"(UTC+09:30) Darwin": "AUS Central Standard Time",
					"(UTC+10:00) Brisbane": "E. Australia Standard Time",
					"(UTC+10:00) Canberra, Melbourne, Sydney": "AUS Eastern Standard Time",
					"(UTC+10:00) Guam, Port Moresby": "West Pacific Standard Time",
					"(UTC+10:00) Hobart": "Tasmania Standard Time",
					"(UTC+10:00) Vladivostok": "Vladivostok Standard Time",
					"(UTC+10:30) Lord Howe Island": "Lord Howe Standard Time",
					"(UTC+11:00) Bougainville Island": "Bougainville Standard Time",
					"(UTC+11:00) Chokurdakh": "Russia Time Zone 10",
					"(UTC+11:00) Magadan": "Magadan Standard Time",
					"(UTC+11:00) Norfolk Island": "Norfolk Standard Time",
					"(UTC+11:00) Sakhalin": "Sakhalin Standard Time",
					"(UTC+11:00) Solomon Is., New Caledonia": "Central Pacific Standard Time",
					"(UTC+12:00) Anadyr, Petropavlovsk-Kamchatsky": "Russia Time Zone 11",
					"(UTC+12:00) Auckland, Wellington": "New Zealand Standard Time",
					"(UTC+12:00) Fiji": "Fiji Standard Time",
					"(UTC+12:45) Chatham Islands": "Chatham Islands Standard Time",
					"(UTC+13:00) Nuku'alofa": "Tonga Standard Time",
					"(UTC+13:00) Samoa": "Samoa Standard Time",
					"(UTC+14:00) Kiritimati Island": "Line Islands Standard Time"
				}
			},
			"AutoMapping": {
				"DisplayName": "Open automatically in the delegates' Outlook?"
			},
			"MessageCopyForSentAsEnabled": {
				"DisplayName": "Keep copies of mails sent as the mailbox?"
			},
			"MessageCopyForSendOnBehalfEnabled": {
				"DisplayName": "Keep copies of mails sent on behalf?"
			},
			"DisableUser": {
				"DisplayName": "Block sign-in for the mailbox account?"
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param(
    [Parameter(Mandatory = $true)]
    [string] $MailboxName,
    [string] $DisplayName,
    [string] $DomainName,
    [string] $Language = "en-US",
    [string] $TimeZone = "W. Europe Standard Time",
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -Attribute userPrincipalName -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string[]] $DelegateTo,
    [bool] $AutoMapping = $false,
    [bool] $MessageCopyForSentAsEnabled = $true,
    [bool] $MessageCopyForSendOnBehalfEnabled = $true,
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

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "MailboxName: $($MailboxName)" -Verbose
Write-RjRbLog -Message "DisplayName: $($DisplayName)" -Verbose
Write-RjRbLog -Message "DomainName: $($DomainName)" -Verbose
Write-RjRbLog -Message "Language: $($Language)" -Verbose
Write-RjRbLog -Message "TimeZone: $($TimeZone)" -Verbose
Write-RjRbLog -Message "DelegateTo: $($DelegateTo -join ', ')" -Verbose
Write-RjRbLog -Message "AutoMapping: $($AutoMapping)" -Verbose
Write-RjRbLog -Message "MessageCopyForSentAsEnabled: $($MessageCopyForSentAsEnabled)" -Verbose
Write-RjRbLog -Message "MessageCopyForSendOnBehalfEnabled: $($MessageCopyForSendOnBehalfEnabled)" -Verbose
Write-RjRbLog -Message "DisableUser: $($DisableUser)" -Verbose
#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################
# The portal multi-user picker may pass empty entries; de-duplicate case-insensitively
$delegateList = @($DelegateTo | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)
#endregion Parameter Validation

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
#region     StatusQuo & Preflight-Check Part
########################################################
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

# Resolve the delegates before anything is created, so a wrong selection leaves no half-configured mailbox behind.
# Get-EXORecipient also finds mail users, which hold the on-premises mailboxes in a hybrid organization.
$delegateAddresses = @()
if ($delegateList.Count -gt 0) {
    Write-Output "Checking delegates..."
    $unresolvedDelegates = @()
    foreach ($delegate in $delegateList) {
        try {
            $delegateAddresses += [string](Get-EXORecipient -Identity $delegate -ErrorAction Stop).PrimarySmtpAddress
        }
        catch {
            $unresolvedDelegates += $delegate
        }
    }
    if ($unresolvedDelegates.Count -gt 0) {
        Write-Error "Delegates not found in Exchange Online: $($unresolvedDelegates -join ', '). They may have no mailbox yet, for example because a license was assigned only recently." -ErrorAction Continue
        throw "Delegates not found in Exchange Online: $($unresolvedDelegates -join ', '). The shared mailbox was not created. Remove them from 'Delegate access to' or wait until their mailboxes exist, then run the runbook again."
    }
    # Two picker values can resolve to the same recipient
    $delegateAddresses = @($delegateAddresses | Sort-Object -Unique)
    Write-Output "Delegates: $($delegateAddresses -join ', ')"
}
#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################
# make sure a displayName exists
if (-not $DisplayName) {
    $DisplayName = $MailboxName
}

Write-Output ""
if ($primarySmtpAddress) {
    Write-Output "Creating shared mailbox '$($primarySmtpAddress)'..."
}
else {
    Write-Output "Creating shared mailbox '$($MailboxName)'..."
}

# Create the mailbox
try {
    if (-not $DomainName) {
        $mailbox = New-Mailbox -Shared -Name $nameToUse -DisplayName $DisplayName -Alias $aliasToUse -ErrorAction Stop
    }
    else {
        $mailbox = New-Mailbox -Shared -Name $nameToUse -DisplayName $DisplayName -Alias $aliasToUse -PrimarySmtpAddress $primarySmtpAddress -ErrorAction Stop
    }
}
catch {
    Write-Error "Failed to create the shared mailbox '$($aliasToUse)': $($_.Exception.Message)" -ErrorAction Continue
    throw "The shared mailbox '$($aliasToUse)' could not be created: $($_.Exception.Message)"
}

if ($aliasConflict) {
    Write-RjRbLog -Message "WARNING: Due to an alias conflict, the mailbox alias was set to '$aliasToUse' instead of '$MailboxName'." -Verbose
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
# A new mailbox takes a moment until Exchange Online returns it
$maxAttempts = 30
$mailbox = $null
$identityToCheck = if ($primarySmtpAddress) { $primarySmtpAddress } elseif ($aliasConflict) { $aliasToUse } else { $MailboxName }
for ($attempt = 1; ($attempt -le $maxAttempts) -and ($null -eq $mailbox); $attempt++) {
    $mailbox = Get-Mailbox -Identity $identityToCheck -ErrorAction SilentlyContinue
    if ($null -eq $mailbox) {
        Write-Output ".. Waiting for mailbox to be created ($attempt/$maxAttempts)..."
        Start-Sleep -Seconds 10
    }
}
if ($null -eq $mailbox) {
    Write-Error "The shared mailbox '$($identityToCheck)' was created but did not become available within five minutes." -ErrorAction Continue
    throw "The shared mailbox '$($identityToCheck)' was created, but its delegates, Sent Items copies, language and time zone were not set because it did not become available in time. Set them in the Exchange admin center."
}

# A failure for one delegate does not stop the others; the run fails at the end so it is not reported as clean
$grantedDelegates = @()
$failedDelegates = @()
foreach ($delegateAddress in $delegateAddresses) {
    Write-Output "Granting full access and send on behalf to '$($delegateAddress)'..."
    try {
        $mailbox | Set-Mailbox -GrantSendOnBehalfTo @{ Add = $delegateAddress } -ErrorAction Stop | Out-Null
        $mailbox | Add-MailboxPermission -User $delegateAddress -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -Confirm:$false -ErrorAction Stop | Out-Null
        $grantedDelegates += $delegateAddress
    }
    catch {
        Write-RjRbLog -Message "WARNING: Could not grant access to '$($delegateAddress)': $($_.Exception.Message)" -Verbose
        $failedDelegates += $delegateAddress
    }
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
        Write-RjRbLog -Message "WARNING: The user account of the shared mailbox did not appear in Entra ID in time and was not disabled. Block its sign-in in Entra ID." -Verbose
        Write-Error "The user account of the shared mailbox '$($mailbox.PrimarySmtpAddress)' was not found in Entra ID, sign-in was not blocked." -ErrorAction Continue
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
if ($grantedDelegates.Count -gt 0) {
    Write-Output "   Delegates: $($grantedDelegates -join ', ')"
}

if ($failedDelegates.Count -gt 0) {
    Write-Error "Full access and send on behalf could not be granted completely to: $($failedDelegates -join ', '). The reason per delegate is in the warnings above." -ErrorAction Continue
    throw "The shared mailbox was created, but the access of $($failedDelegates.Count) of $($delegateAddresses.Count) delegate(s) is incomplete: $($failedDelegates -join ', '). Check their full access and send on behalf in the Exchange admin center."
}
#endregion Main Part

########################################################
#region     Cleanup
########################################################
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

Write-Output ""
Write-Output "Done!"
#endregion Cleanup

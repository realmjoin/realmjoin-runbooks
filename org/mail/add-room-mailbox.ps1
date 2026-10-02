<#
	.SYNOPSIS
	Create a room mailbox with optional booking delegates

	.DESCRIPTION
	Creates a room mailbox in Exchange Online so the room can be booked in meeting requests. Without booking delegates the room accepts requests automatically when it is free. With booking delegates every request waits for their approval; they get no access to the mailbox itself. The user account behind the mailbox can be disabled so nobody signs in with it.

	.PARAMETER MailboxName
	Alias of the mailbox, which becomes the part of the email address in front of the @ sign.

	.PARAMETER DisplayName
	Name shown in the address book and the room finder. Leave empty to use the alias.

	.PARAMETER DelegateTo
	Users who approve or decline every booking request for the room. Leave empty to accept requests automatically when the room is free.

	.PARAMETER Capacity
	How many people fit in the room. Shown in the room finder. Leave at 0 to set no capacity.

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
	        "Capacity": {
	            "DisplayName": "Room capacity (people)"
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param (
    [Parameter(Mandatory = $true)]
    [string] $MailboxName,
    [string] $DisplayName,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -Attribute userPrincipalName -DisplayName "Booking delegates" -Filter "userType eq 'Member'" } )]
    [string[]] $DelegateTo,
    [int] $Capacity = 0,
    [bool] $DisableUser = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "2.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "MailboxName: $MailboxName" -Verbose
Write-RjRbLog -Message "DisplayName: $DisplayName" -Verbose
Write-RjRbLog -Message "DelegateTo: $($DelegateTo -join ', ')" -Verbose
Write-RjRbLog -Message "Capacity: $Capacity" -Verbose
Write-RjRbLog -Message "DisableUser: $DisableUser" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

$MailboxName = $MailboxName.Trim()
if ([string]::IsNullOrWhiteSpace($MailboxName)) {
    Write-Error "The alias of the room mailbox is empty." -ErrorAction Continue
    throw "Empty alias"
}

# The portal multi-user picker may pass empty entries; de-duplicate case-insensitively
$delegateList = @($DelegateTo | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)

#endregion Parameter Validation

########################################################
#region     Connect Part
########################################################

Write-Output "Connect to Exchange Online..."

try {
    Connect-RjRbExchangeOnline
}
catch {
    Write-Error "Exchange Online connection failed: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

if ($DisableUser) {
    try {
        Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    }
    catch {
        Write-Error "Microsoft Graph connection failed: $($_.Exception.Message)" -ErrorAction Continue
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        throw
    }
}

#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Preflight-Check"
Write-Output "---------------------"

try {
    $existingRecipient = Get-EXORecipient -Filter "Alias -eq '$($MailboxName -replace "'", "''")'" -ResultSize 1 -ErrorAction Stop
    if ($existingRecipient) {
        throw "The alias '$MailboxName' is already used by '$($existingRecipient.PrimarySmtpAddress)'."
    }

    # Booking delegates need a mailbox to receive the requests they approve. Resolve them before anything
    # is created, so an invalid selection leaves no half-configured room behind.
    $delegateAddresses = @(foreach ($delegate in $delegateList) {
            try {
                [string](Get-EXOMailbox -Identity $delegate -ErrorAction Stop).PrimarySmtpAddress
            }
            catch {
                throw "Booking delegate '$delegate' has no mailbox in Exchange Online."
            }
        })
    $delegateAddresses = @($delegateAddresses | Sort-Object -Unique)
}
catch {
    Write-Error "Preflight check failed: $($_.Exception.Message)" -ErrorAction Continue
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    if (Get-MgContext -ErrorAction SilentlyContinue) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    throw
}

Write-Output "Alias '$MailboxName' is available."
if ($delegateAddresses.Count -gt 0) {
    Write-Output "Booking delegates: $($delegateAddresses -join ', ')"
}
else {
    Write-Output "No booking delegates - the room accepts requests automatically when it is free."
}

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Create room mailbox"
Write-Output "---------------------"

try {
    $newMailboxParams = @{
        Name        = $MailboxName
        Alias       = $MailboxName
        Room        = $true
        ErrorAction = "Stop"
    }
    if ($DisplayName) {
        $newMailboxParams.DisplayName = $DisplayName
    }
    if ($Capacity -gt 0) {
        $newMailboxParams.ResourceCapacity = $Capacity
    }
    $mailbox = New-Mailbox @newMailboxParams
    # All further cmdlets address the mailbox by its primary SMTP address, which is unique - the alias
    # can also match the name of another recipient.
    $mailboxAddress = [string]$mailbox.PrimarySmtpAddress
    Write-Output "Room mailbox '$mailboxAddress' created."
}
catch {
    Write-Error "Creating the room mailbox '$MailboxName' failed: $($_.Exception.Message)" -ErrorAction Continue
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    if (Get-MgContext -ErrorAction SilentlyContinue) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    throw
}

# Booking delegates are set only through the calendar processing - the same as "Select delegates who can
# accept or decline booking requests" in the Exchange admin center. They need no full access, and Exchange
# grants them Send on Behalf itself.
$calendarParams = @{
    AutomateProcessing = "AutoAccept"
    ErrorAction        = "Stop"
}
if ($delegateAddresses.Count -gt 0) {
    $calendarParams.AllBookInPolicy = $false
    $calendarParams.AllRequestInPolicy = $true
    $calendarParams.ResourceDelegates = $delegateAddresses
}
else {
    $calendarParams.AllBookInPolicy = $true
}

# A new mailbox takes a moment until its calendar can be configured
$maxAttempts = 12
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    try {
        Set-CalendarProcessing -Identity $mailboxAddress @calendarParams
        break
    }
    catch {
        if ($attempt -eq $maxAttempts) {
            Write-Error "Configuring the calendar processing of '$mailboxAddress' failed: $($_.Exception.Message)" -ErrorAction Continue
            Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            if (Get-MgContext -ErrorAction SilentlyContinue) {
                Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            }
            throw
        }
        Write-Output ".. Waiting for the mailbox to be ready ($attempt/$maxAttempts)..."
        Start-Sleep -Seconds 10
    }
}

if ($delegateAddresses.Count -gt 0) {
    Write-Output "Booking requests now wait for the approval of: $($delegateAddresses -join ', ')"
}
else {
    Write-Output "Booking requests are accepted automatically when the room is free."
}

if ($DisableUser) {
    # The user account appears in Entra ID shortly after the mailbox
    $graphUser = $null
    $userKey = if ($mailbox.ExternalDirectoryObjectId) { [string]$mailbox.ExternalDirectoryObjectId } else { [string]$mailbox.UserPrincipalName }
    for ($attempt = 1; ($attempt -le $maxAttempts) -and (-not $graphUser); $attempt++) {
        try {
            $graphUser = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($userKey))?`$select=id,userPrincipalName,accountEnabled" -Method GET -ErrorAction Stop
        }
        catch {
            Write-Output ".. Waiting for the user account in Entra ID ($attempt/$maxAttempts)..."
            Start-Sleep -Seconds 10
        }
    }

    if (-not $graphUser) {
        Write-RjRbLog -Message "WARNING: The user account of '$mailboxAddress' did not appear in Entra ID in time and was not blocked. Block its sign-in in Entra ID." -Verbose
        Write-Error "The user account of '$mailboxAddress' was not found in Entra ID, sign-in was not blocked." -ErrorAction Continue
    }
    elseif (-not $graphUser.accountEnabled) {
        Write-Output "Sign-in of '$($graphUser.userPrincipalName)' is already blocked."
    }
    else {
        try {
            Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($graphUser.id)" -Method PATCH -Body @{ accountEnabled = $false } -ErrorAction Stop | Out-Null
            Write-Output "Sign-in of '$($graphUser.userPrincipalName)' blocked."
        }
        catch {
            Write-Error "Blocking the sign-in of '$($graphUser.userPrincipalName)' failed: $($_.Exception.Message)" -ErrorAction Continue
            Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            if (Get-MgContext -ErrorAction SilentlyContinue) {
                Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            }
            throw
        }
    }
}

Write-Output ""
Write-Output "Room mailbox '$mailboxAddress' has been created."

#endregion Main Part

########################################################
#region     Cleanup
########################################################

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

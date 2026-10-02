<#
	.SYNOPSIS
	Configure the booking rules and booking delegates of this room mailbox

	.DESCRIPTION
	Sets the booking rules of this room mailbox: who may book it directly, who needs the approval of a booking delegate, and how requests are processed. It also sets recurring meetings, conflicts, the booking window, the maximum meeting length and the capacity. All booking rules are written as shown. The booking group, the booking delegates and the capacity change only when a value is given.

	.PARAMETER UserName
	User principal name of the room mailbox the runbook acts on. Set by the portal from the selected user.

	.PARAMETER AllBookInPolicy
	Everyone lets all users book the room directly. Restricted lets only the "Booking group" book directly; everyone else is declined or, with "Let everyone else request the room?", needs a booking delegate's approval.

	.PARAMETER BookInPolicyGroup
	Mail-enabled security group whose members book the room directly. Leave empty to keep the current group, for example when only the booking delegates decide.

	.PARAMETER AllRequestInPolicy
	Requests from users outside the "Booking group" go to the booking delegates, who approve or decline them. Turn off to decline these requests.

	.PARAMETER AllowRecurringMeetings
	Turn off to decline recurring meeting requests; single meetings are still accepted.

	.PARAMETER AutomateProcessing
	Auto accept books the room automatically or sends the request to the booking delegates. Auto update only marks requests as tentative, and booking delegates get no requests. None leaves requests untouched.

	.PARAMETER BookingWindowInDays
	Requests further ahead than this many days are declined.

	.PARAMETER MaximumDurationInMinutes
	Longest meeting the room accepts, in minutes.

	.PARAMETER AllowConflicts
	Lets overlapping bookings through instead of declining them.

	.PARAMETER Capacity
	Number of seats. Leave at 0 to keep the current value.

	.PARAMETER ResourceDelegates
	Users who approve or decline the booking requests that need approval. They get no access to the mailbox itself. Leave empty to keep the current booking delegates.

	.PARAMETER DelegateAction
	Add puts the selected users next to the current booking delegates, Replace makes them the only booking delegates, Remove takes them off the list.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
	    "Parameters": {
	        "CallerName": {
	            "Hide": true
	        },
	        "UserName": {
	            "Hide": true
	        },
	        "AllBookInPolicy": {
	            "DisplayName": "Who may book the room",
	            "Select": {
	                "Options": [
	                    {
	                        "Display": "Everyone",
	                        "Customization": {
	                            "Hide": [
	                                "BookInPolicyGroup",
	                                "AllRequestInPolicy"
	                            ]
	                        },
	                        "Value": true
	                    },
	                    {
	                        "Display": "Restricted",
	                        "Value": false
	                    }
	                ]
	            },
	            "Default": true
	        },
	        "AllRequestInPolicy": {
	            "DisplayName": "Let everyone else request the room?"
	        },
	        "AllowRecurringMeetings": {
	            "DisplayName": "Allow recurring meetings?"
	        },
	        "AutomateProcessing": {
	            "DisplayName": "Request processing",
	            "SelectSimple": {
	                "Auto accept": "AutoAccept",
	                "Auto update": "AutoUpdate",
	                "None": "None"
	            }
	        },
	        "BookingWindowInDays": {
	            "DisplayName": "Booking window (days)"
	        },
	        "MaximumDurationInMinutes": {
	            "DisplayName": "Maximum duration (minutes)"
	        },
	        "AllowConflicts": {
	            "DisplayName": "Allow conflicting bookings?"
	        },
	        "Capacity": {
	            "DisplayName": "Capacity"
	        },
	        "DelegateAction": {
	            "DisplayName": "Booking delegate change",
	            "SelectSimple": {
	                "Add to current delegates": "Add",
	                "Replace current delegates": "Replace",
	                "Remove from current delegates": "Remove"
	            }
	        }
	    }
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param (
    [Parameter(Mandatory = $true)]
    [string] $UserName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RoomMailbox.AllBookInPolicy" } )]
    [bool] $AllBookInPolicy = $true,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Booking group" } )]
    [string] $BookInPolicyGroup,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RoomMailbox.AllRequestInPolicy" } )]
    [bool] $AllRequestInPolicy = $false,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RoomMailbox.AllowRecurringMeetings" } )]
    [bool] $AllowRecurringMeetings = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RoomMailbox.AutomateProcessing" } )]
    [string] $AutomateProcessing = "AutoAccept",
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RoomMailbox.BookingWindowInDays" } )]
    [int] $BookingWindowInDays = 180,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RoomMailbox.MaximumDurationInMinutes" } )]
    [int] $MaximumDurationInMinutes = 1440,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RoomMailbox.AllowConflicts" } )]
    [bool] $AllowConflicts = $false,
    [int] $Capacity = 0,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -Attribute userPrincipalName -DisplayName "Booking delegates" -Filter "userType eq 'Member'" } )]
    [string[]] $ResourceDelegates,
    [string] $DelegateAction = "Add",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "AllBookInPolicy: $AllBookInPolicy" -Verbose
Write-RjRbLog -Message "BookInPolicyGroup: $BookInPolicyGroup" -Verbose
Write-RjRbLog -Message "AllRequestInPolicy: $AllRequestInPolicy" -Verbose
Write-RjRbLog -Message "AllowRecurringMeetings: $AllowRecurringMeetings" -Verbose
Write-RjRbLog -Message "AutomateProcessing: $AutomateProcessing" -Verbose
Write-RjRbLog -Message "BookingWindowInDays: $BookingWindowInDays" -Verbose
Write-RjRbLog -Message "MaximumDurationInMinutes: $MaximumDurationInMinutes" -Verbose
Write-RjRbLog -Message "AllowConflicts: $AllowConflicts" -Verbose
Write-RjRbLog -Message "Capacity: $Capacity" -Verbose
Write-RjRbLog -Message "ResourceDelegates: $($ResourceDelegates -join ', ')" -Verbose
Write-RjRbLog -Message "DelegateAction: $DelegateAction" -Verbose

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

if ($AutomateProcessing -notin @('AutoAccept', 'AutoUpdate', 'None')) {
    Write-Error "Unknown request processing '$AutomateProcessing'. Use AutoAccept, AutoUpdate or None." -ErrorAction Continue
    throw "Invalid AutomateProcessing"
}

if ($DelegateAction -notin @('Add', 'Replace', 'Remove')) {
    Write-Error "Unknown booking delegate change '$DelegateAction'. Use Add, Replace or Remove." -ErrorAction Continue
    throw "Invalid DelegateAction"
}

# The portal multi-user picker may pass empty entries; de-duplicate case-insensitively
$selectedDelegates = @($ResourceDelegates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)

#endregion Parameter Validation

########################################################
#region     Connect Part
########################################################

Write-Output "Connect to Microsoft Graph and Exchange Online..."

try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Microsoft Graph connection failed: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

try {
    Connect-RjRbExchangeOnline
}
catch {
    Write-Error "Exchange Online connection failed: $($_.Exception.Message)" -ErrorAction Continue
    if (Get-MgContext -ErrorAction SilentlyContinue) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    throw
}

#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo of '$UserName'"
Write-Output "---------------------"

try {
    $room = Get-EXOMailbox -Identity $UserName -ErrorAction Stop
    if ($room.RecipientTypeDetails -ne "RoomMailbox") {
        throw "'$UserName' is not a room mailbox (type: $($room.RecipientTypeDetails))."
    }
    # All further cmdlets address the room by a unique identifier - its name can also match other recipients
    $roomId = if ($room.ExternalDirectoryObjectId) { [string]$room.ExternalDirectoryObjectId } else { [string]$room.PrimarySmtpAddress }

    $StatusQuo = Get-CalendarProcessing -Identity $roomId -ErrorAction Stop

    # The current booking delegates are recipient names, which are not unique in Exchange Online. Use the
    # primary SMTP address where the name resolves to exactly one recipient and keep the raw name otherwise.
    $currentDelegates = @(foreach ($entry in @($StatusQuo.ResourceDelegates | Where-Object { $_ })) {
            $recipient = @()
            try {
                $recipient = @(Get-Recipient -Identity "$entry" -ErrorAction Stop)
            }
            catch {
                Write-RjRbLog -Message "Booking delegate '$entry' could not be resolved: $($_.Exception.Message)" -Verbose
            }
            if ($recipient.Count -eq 1) {
                [PSCustomObject]@{ Key = [string]$recipient[0].PrimarySmtpAddress; DisplayName = [string]$recipient[0].DisplayName }
            }
            else {
                [PSCustomObject]@{ Key = "$entry"; DisplayName = "$entry" }
            }
        })

    # Users picked as booking delegates need a mailbox to receive the requests they approve
    $validDelegates = @()
    foreach ($delegate in $selectedDelegates) {
        try {
            $delegateMailbox = Get-EXOMailbox -Identity $delegate -ErrorAction Stop
            $validDelegates += [PSCustomObject]@{ Key = [string]$delegateMailbox.PrimarySmtpAddress; DisplayName = [string]$delegateMailbox.DisplayName }
        }
        catch {
            Write-RjRbLog -Message "WARNING: '$delegate' has no mailbox in Exchange Online and is skipped." -Verbose
        }
    }
    if (($selectedDelegates.Count -gt 0) -and ($validDelegates.Count -eq 0)) {
        throw "None of the selected booking delegates has a mailbox in Exchange Online."
    }

    $bookInPolicyAddress = $null
    if ((-not $AllBookInPolicy) -and $BookInPolicyGroup) {
        $group = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$($BookInPolicyGroup)?`$select=displayName,mail,mailEnabled,securityEnabled" -Method GET -ErrorAction Stop
        if (-not $group.mailEnabled -or -not $group.securityEnabled) {
            throw "Group '$($group.displayName)' is not mail-enabled or not security-enabled."
        }
        $bookInPolicyAddress = if ($group.mail) { [string]$group.mail } else { $BookInPolicyGroup }
    }
}
catch {
    Write-Error "Preflight check failed: $($_.Exception.Message)" -ErrorAction Continue
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    if (Get-MgContext -ErrorAction SilentlyContinue) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    throw
}

$currentApproval = (-not $StatusQuo.AllBookInPolicy) -and $StatusQuo.AllRequestInPolicy
Write-Output "Request processing: $($StatusQuo.AutomateProcessing)"
Write-Output "Everyone books directly (AllBookInPolicy): $($StatusQuo.AllBookInPolicy)"
Write-Output "Everyone may request (AllRequestInPolicy): $($StatusQuo.AllRequestInPolicy)"
Write-Output "Requests go to the delegates (ForwardRequestsToDelegates): $($StatusQuo.ForwardRequestsToDelegates)"
if ($currentDelegates.Count -gt 0) {
    Write-Output "Booking delegates: $(($currentDelegates | ForEach-Object { $_.DisplayName }) -join ', ')"
}
else {
    Write-Output "Booking delegates: none"
}

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Update room mailbox"
Write-Output "---------------------"

# New list of booking delegates - only changed when users were selected
$newDelegates = $currentDelegates
if ($validDelegates.Count -gt 0) {
    switch ($DelegateAction) {
        "Add" {
            $newDelegates = @($currentDelegates) + @($validDelegates | Where-Object { $_.Key -notin $currentDelegates.Key })
        }
        "Replace" {
            $newDelegates = $validDelegates
        }
        "Remove" {
            foreach ($delegate in $validDelegates | Where-Object { $_.Key -notin $currentDelegates.Key }) {
                Write-Output "'$($delegate.DisplayName)' is no booking delegate - nothing to remove."
            }
            $newDelegates = @($currentDelegates | Where-Object { $_.Key -notin $validDelegates.Key })
        }
    }
}
$newDelegates = @($newDelegates)
$delegatesChanged = ((@($currentDelegates.Key) | Sort-Object) -join "|") -ne ((@($newDelegates.Key) | Sort-Object) -join "|")

$invokeParams = @{
    AutomateProcessing       = $AutomateProcessing
    AllowRecurringMeetings   = $AllowRecurringMeetings
    BookingWindowInDays      = $BookingWindowInDays
    MaximumDurationInMinutes = $MaximumDurationInMinutes
    AllowConflicts           = $AllowConflicts
    AllBookInPolicy          = $AllBookInPolicy
}
if (-not $AllBookInPolicy) {
    $invokeParams.AllRequestInPolicy = $AllRequestInPolicy
    if ($bookInPolicyAddress) {
        $invokeParams.BookInPolicy = $bookInPolicyAddress
    }
}
if ($delegatesChanged) {
    $invokeParams.ResourceDelegates = if ($newDelegates.Count -gt 0) { [string[]]$newDelegates.Key } else { $null }
}

# Combinations in which the booking delegates do not get the requests they are meant to approve
$newApproval = (-not $AllBookInPolicy) -and $AllRequestInPolicy
if ($AllBookInPolicy -and $currentApproval) {
    Write-RjRbLog -Message "WARNING: Everyone now books the room directly; the booking delegates no longer approve requests." -Verbose
}
elseif ($AllBookInPolicy -and ($newDelegates.Count -gt 0)) {
    Write-RjRbLog -Message "WARNING: Everyone books the room directly, so the booking delegates get no requests to approve." -Verbose
}
if ($newApproval -and ($newDelegates.Count -eq 0)) {
    Write-RjRbLog -Message "WARNING: Requests from outside the booking group need approval, but the room has no booking delegates." -Verbose
}
if ((-not $AllBookInPolicy) -and ($newDelegates.Count -gt 0)) {
    if ($AutomateProcessing -ne "AutoAccept") {
        Write-RjRbLog -Message "WARNING: The booking delegates get requests only with the request processing 'Auto accept'." -Verbose
    }
    elseif (-not $StatusQuo.ForwardRequestsToDelegates) {
        Write-RjRbLog -Message "WARNING: Forwarding requests to the delegates (ForwardRequestsToDelegates) is turned off for this room." -Verbose
    }
}

try {
    if ($Capacity -gt 0) {
        Set-Place -Identity $roomId -Capacity $Capacity -ErrorAction Stop
        Write-Output "Capacity set to $Capacity."
    }
    Set-CalendarProcessing -Identity $roomId @invokeParams -ErrorAction Stop
}
catch {
    Write-Error "Updating the room mailbox '$UserName' failed: $($_.Exception.Message)" -ErrorAction Continue
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    if (Get-MgContext -ErrorAction SilentlyContinue) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    throw
}

Write-Output "Booking rules updated."
if ($delegatesChanged) {
    if ($newDelegates.Count -gt 0) {
        Write-Output "Booking delegates now: $(($newDelegates | ForEach-Object { $_.DisplayName }) -join ', ')"
    }
    else {
        Write-Output "The room has no booking delegates any more."
    }
}
else {
    Write-Output "Booking delegates unchanged."
}

try {
    $result = Get-CalendarProcessing -Identity $roomId -ErrorAction Stop
    $calendarProcessingRows = @($result |
            Select-Object -Property AutomateProcessing, AllBookInPolicy, AllRequestInPolicy, AllRequestOutOfPolicy, ForwardRequestsToDelegates, AllowRecurringMeetings, AllowConflicts, BookingWindowInDays, MaximumDurationInMinutes)
}
catch {
    Write-RjRbLog -Message "WARNING: The updated settings could not be read back: $($_.Exception.Message)" -Verbose
    $calendarProcessingRows = @()
}
$delegateRows = @($newDelegates | ForEach-Object { [PSCustomObject]@{ DisplayName = $_.DisplayName; EmailAddress = $(if ($_.Key -like '*@*') { $_.Key } else { "" }) } })

#endregion Main Part

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last. Every table has its own RjTableTitle marker; a marker is only written when rows follow it.
Write-Output ""

if ($calendarProcessingRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Calendar processing" })
    Write-Output $calendarProcessingRows
}

if ($delegateRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Booking delegates" })
    Write-Output $delegateRows
}
else {
    Write-Output "No booking delegates."
}

#endregion Structured Output (Output Data)

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

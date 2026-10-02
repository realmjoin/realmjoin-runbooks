<#
	.SYNOPSIS
	Show the booking configuration of this room mailbox

	.DESCRIPTION
	Shows the room details and the calendar processing settings of this room mailbox, such as how booking requests are handled. It also lists the resource delegates who approve requests and the users and groups that may book the room directly or only request it. Nothing is changed.

	.PARAMETER UserName
	User principal name of the room mailbox the runbook acts on. Set by the portal from the selected user.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
	    "Parameters": {
	        "UserName": {
	            "Hide": true
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
    [string] $UserName,
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

#endregion RJ Log Part

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
Write-Output "Room mailbox configuration of '$UserName'"
Write-Output "---------------------"

try {
    # The places API needs the mail address, which can differ from the user principal name
    $roomUser = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($UserName))?`$select=mail" -Method GET -ErrorAction Stop
    if (-not $roomUser.mail) {
        throw "User object '$UserName' has no mail address."
    }
    $roomMail = "$($roomUser.mail)"
}
catch {
    Write-Error "Room mailbox preflight check failed: $($_.Exception.Message)" -ErrorAction Continue
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    if (Get-MgContext -ErrorAction SilentlyContinue) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    throw
}

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

# Room details from the places API - without them the calendar processing settings are still shown
$roomRows = @()
try {
    $place = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/places/$([uri]::EscapeDataString($roomMail))/microsoft.graph.room" -Method GET -ErrorAction Stop
    $address = $place.address
    $roomRows = @([PSCustomObject]@{
            DisplayName          = $place.displayName
            EmailAddress         = $place.emailAddress
            Capacity             = $place.capacity
            Building             = $place.building
            FloorNumber          = $place.floorNumber
            FloorLabel           = $place.floorLabel
            Label                = $place.label
            BookingType          = $place.bookingType
            WheelchairAccessible = $place.isWheelChairAccessible
            AudioDevice          = $place.audioDeviceName
            VideoDevice          = $place.videoDeviceName
            DisplayDevice        = $place.displayDeviceName
            Phone                = $place.phone
            Address              = if ($address) { (@($address.street, $address.postalCode, $address.city, $address.countryOrRegion) | Where-Object { $_ }) -join ", " } else { "" }
            Tags                 = (@($place.tags) | Where-Object { $_ }) -join ", "
        })
}
catch {
    Write-Output "Reading the room details of '$UserName' failed. Either the permission 'Place.Read.All' is missing or this is not a room mailbox."
    Write-Error "Reading the room details failed: $($_.Exception.Message)" -ErrorAction Continue
}

try {
    $calendarProcessing = Get-CalendarProcessing -Identity $UserName -ErrorAction Stop
    $calendarProcessingRows = @($calendarProcessing |
            Select-Object -Property AutomateProcessing, AllBookInPolicy, AllRequestInPolicy, AllRequestOutOfPolicy, ForwardRequestsToDelegates, AllowConflicts, BookingWindowInDays, MaximumDurationInMinutes, DeleteSubject, AddOrganizerToSubject, OrganizerInfo)

    # Resource delegates approve requests; the policy lists name who books directly (BookInPolicy) or
    # who may only send a request for approval (RequestInPolicy, RequestOutOfPolicy).
    $bookingRecipientRows = @(foreach ($settingName in @('ResourceDelegates', 'BookInPolicy', 'RequestInPolicy', 'RequestOutOfPolicy')) {
            foreach ($entry in @($calendarProcessing.$settingName | Where-Object { $_ })) {
                # The entries are recipient names, which are not unique in Exchange Online - list the raw name
                # when it does not resolve to exactly one recipient.
                $recipient = @()
                try {
                    $recipient = @(Get-Recipient -Identity "$entry" -ErrorAction Stop)
                }
                catch {
                    Write-RjRbLog -Message "Recipient '$entry' in $($settingName) could not be resolved: $($_.Exception.Message)" -Verbose
                }
                if ($recipient.Count -eq 1) {
                    [PSCustomObject]@{
                        Setting       = $settingName
                        DisplayName   = "$($recipient[0].DisplayName)"
                        EmailAddress  = "$($recipient[0].PrimarySmtpAddress)"
                        RecipientType = "$($recipient[0].RecipientTypeDetails)"
                    }
                }
                else {
                    [PSCustomObject]@{
                        Setting       = $settingName
                        DisplayName   = "$entry"
                        EmailAddress  = ""
                        RecipientType = ""
                    }
                }
            }
        })
}
catch {
    Write-Error "Reading the calendar processing settings of '$UserName' failed: $($_.Exception.Message)" -ErrorAction Continue
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    if (Get-MgContext -ErrorAction SilentlyContinue) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
    throw
}

foreach ($settingName in @('ResourceDelegates', 'BookInPolicy', 'RequestInPolicy', 'RequestOutOfPolicy')) {
    Write-Output "$($settingName): $(@($bookingRecipientRows | Where-Object { $_.Setting -eq $settingName }).Count)"
}

#endregion Main Part

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last. Every table has its own RjTableTitle marker; a marker is only written when rows follow it.
Write-Output ""

if ($roomRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Room details" })
    Write-Output $roomRows
}
else {
    Write-Output "No room details available."
}

if ($calendarProcessingRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Calendar processing" })
    Write-Output $calendarProcessingRows
}
else {
    Write-Output "No calendar processing settings found."
}

if ($bookingRecipientRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Delegates and booking policies" })
    Write-Output $bookingRecipientRows
}
else {
    Write-Output "No resource delegates and no users or groups in the booking policies."
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

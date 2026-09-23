<#
	.SYNOPSIS
	Set or remove automatic replies for this user

	.DESCRIPTION
	Turns on automatic replies for the mailbox of this user, with separate messages for people inside and outside the organization and for a period you choose. A matching out-of-office entry can be added to the calendar. Existing automatic replies can also be switched off again; a calendar entry created earlier is not removed.

	.PARAMETER UserName
	User principal name of the mailbox the runbook acts on. Set by the portal from the selected user.

	.PARAMETER Disable
	Enable automatic replies turns them on for the period and messages below. Disable switches existing automatic replies off.

	.PARAMETER Start
	When the automatic replies begin.

	.PARAMETER End
	When the automatic replies stop.

	.PARAMETER MessageInternal
	Reply sent to people inside the organization.

	.PARAMETER MessageExternal
	Reply sent to people outside the organization.

	.PARAMETER ExternalAudience
	None sends no external replies, Known only to saved contacts, All to every external sender.

	.PARAMETER CreateEvent
	Puts a matching out-of-office entry into the user's calendar for the same period.

	.PARAMETER EventSubject
	Subject of the out-of-office entry as colleagues see it in the calendar.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
	    "Parameters": {
	        "Disable": {
	            "DisplayName": "Automatic replies",
	            "Select": {
	                "Options": [
	                    {
	                        "Display": "Enable automatic replies",
	                        "ParameterValue": false,
	                        "Customization": {
	                            "Mandatory": [
	                                "Start",
	                                "MessageInternal",
	                                "MessageExternal"
	                            ]
	                        }
	                    },
	                    {
	                        "Display": "Disable automatic replies",
	                        "ParameterValue": true,
	                        "Customization": {
	                            "Hide": [
	                                "Start",
	                                "End",
	                                "MessageInternal",
	                                "MessageExternal",
	                                "ExternalAudience",
	                                "CreateEvent",
	                                "EventSubject"
	                            ]
	                        }
	                    }
	                ],
	                "ShowValue": false
	            }
	        },
	        "CallerName": {
	            "Hide": true
	        },
	        "UserName": {
	            "Hide": true
	        },
	        "Start": {
	            "DisplayName": "Start date"
	        },
	        "End": {
	            "DisplayName": "End date"
	        },
	        "MessageInternal": {
	            "DisplayName": "Message for colleagues"
	        },
	        "MessageExternal": {
	            "DisplayName": "Message for external senders"
	        },
	        "ExternalAudience": {
	            "DisplayName": "External audience"
	        },
	        "CreateEvent": {
	            "DisplayName": "Add an out-of-office calendar entry?"
	        },
	        "EventSubject": {
	            "DisplayName": "Calendar entry title"
	        }
	    }
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param
(
    [Parameter(Mandatory = $true)]
    [string]$UserName,
    [bool]$Disable = $false,
    [System.DateTime]$Start = (Get-Date),
    [System.DateTime]$End = ((Get-Date) + (New-TimeSpan -Days 3650)),
    [ValidateScript( { Use-RJInterface -Type Textarea } )]
    [string]$MessageInternal = "Sorry, this person is currently not able to receive your message.",
    [ValidateScript( { Use-RJInterface -Type Textarea } )]
    [string]$MessageExternal = "Sorry, this person is currently not able to receive your message.",
    [ValidateSet("None", "Known", "All")]
    [string]$ExternalAudience = "All",
    [bool]$CreateEvent = $false,
    [string]$EventSubject = "Out of Office",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "Disable: $Disable" -Verbose
Write-RjRbLog -Message "Start: $Start" -Verbose
Write-RjRbLog -Message "End: $End" -Verbose
Write-RjRbLog -Message "MessageInternal: $MessageInternal" -Verbose
Write-RjRbLog -Message "MessageExternal: $MessageExternal" -Verbose
Write-RjRbLog -Message "ExternalAudience: $ExternalAudience" -Verbose
Write-RjRbLog -Message "CreateEvent: $CreateEvent" -Verbose
Write-RjRbLog -Message "EventSubject: $EventSubject" -Verbose

#endregion

########################################################
#region     Connect Part
########################################################

Write-Output ""
Write-Output "Connect to Exchange Online"
Write-Output "---------------------"

try {
    Connect-RjRbExchangeOnline -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Exchange Online using managed identity: $_" -ErrorAction Continue
    throw
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

try {
    $StatusQuo = Get-MailboxAutoReplyConfiguration -Identity $UserName -ErrorAction Stop
    $CurrentAutoReplyState = $StatusQuo.AutoReplyState
    $CurrentExternalAudience = $StatusQuo.ExternalAudience
    $CurrentExternalMessage = $StatusQuo.ExternalMessage
    $CurrentInternalMessage = $StatusQuo.InternalMessage
    Write-Output "Current AutoReplyState: $CurrentAutoReplyState"
    Write-Output "Current ExternalAudience: $CurrentExternalAudience"
    Write-Output "Current ExternalMessage: $CurrentExternalMessage"
    Write-Output "Current InternalMessage: $CurrentInternalMessage"
}
catch {
    Write-Error "Failed to retrieve current Out Of Office configuration for '$UserName': $_" -ErrorAction Continue
    throw
}

#endregion

########################################################
#region     Main Part
########################################################

if ($Disable) {
    Write-Output ""
    Write-Output "Disabling Out Of Office settings for '$UserName'"
    Write-Output "---------------------"

    try {
        Set-MailboxAutoReplyConfiguration -Identity $UserName -AutoReplyState Disabled -ErrorAction Stop
        Write-Output "Out Of Office settings disabled successfully for '$UserName'."
        Write-Output "NOTE: If a calendar entry was created for the Out-Of-Office, it will not be removed."
    }
    catch {
        Write-Error "Failed to disable Out Of Office settings for '$UserName': $_" -ErrorAction Continue
        throw
    }
}
else {
    Write-Output ""
    Write-Output "Enabling Out Of Office settings for '$UserName'"
    Write-Output "---------------------"

    try {
        Set-MailboxAutoReplyConfiguration -Identity $UserName -AutoReplyState Scheduled `
            -ExternalAudience $ExternalAudience `
            -ExternalMessage $MessageExternal `
            -InternalMessage $MessageInternal `
            -StartTime $Start `
            -EndTime $End `
            -CreateOOFEvent $CreateEvent `
            -OOFEventSubject $EventSubject `
            -ErrorAction Stop
        Write-Output "Out Of Office settings enabled successfully for '$UserName'."
    }
    catch {
        Write-Error "Failed to enable Out Of Office settings for '$UserName': $_" -ErrorAction Continue
        throw
    }
}

Write-RjRbLog -Message "Resulting MailboxAutoReplyConfiguration for user '$UserName': $(Get-MailboxAutoReplyConfiguration $UserName | Format-List | Out-String)" -Verbose

#endregion

########################################################
#region     Cleanup
########################################################

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion

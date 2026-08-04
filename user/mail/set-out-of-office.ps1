<#
	.SYNOPSIS
	Enable or disable mailbox out-of-office notifications

	.DESCRIPTION
	Configures automatic replies for a mailbox and can optionally create an out-of-office calendar event. The runbook can either enable scheduled replies with internal and external messages or disable existing out-of-office settings.

	.PARAMETER UserName
	User principal name of the mailbox. This value is auto-filled by the portal.

	.PARAMETER Disable
	Select whether to enable out-of-office notifications or disable existing out-of-office settings.

	.PARAMETER Start
	Start time for scheduled out-of-office replies.

	.PARAMETER End
	End time for scheduled out-of-office replies. If not specified, it defaults to 10 years from the current date.

	.PARAMETER MessageInternal
	Internal automatic reply message.

	.PARAMETER MessageExternal
	External automatic reply message.

	.PARAMETER ExternalAudience
	Controls who receives external automatic replies. Use None to send no external replies, Known to send replies only to known external contacts, or All to send replies to all external senders.

	.PARAMETER CreateEvent
	If set to true, creates an out-of-office calendar event.

	.PARAMETER EventSubject
	Subject for the optional out-of-office calendar event.

	.PARAMETER CallerName
	Caller name is tracked purely for auditing purposes.

	.INPUTS
	RunbookCustomization: {
	    "Parameters": {
	        "Disable": {
	            "DisplayName": "Enable or Disable Out-of-Office",
	            "Select": {
	                "Options": [
	                    {
	                        "Display": "Enable Out-of-Office",
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
	                        "Display": "Disable Out-of-Office",
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
	            "DisplayName": "Start Date"
	        },
	        "End": {
	            "DisplayName": "End Date"
	        }
	    }
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

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

<#
	.SYNOPSIS
	List who has access to this user's mailbox

	.DESCRIPTION
	Shows who has permissions on the mailbox of this user: full access, Send As and Send on Behalf, each as a table in the Output Data tab. Works for shared mailboxes as well. Nothing is changed.

	.PARAMETER UserName
	User principal name of the user the runbook acts on. Set by the portal from the selected user.

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
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param
(
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

Write-Output "Connect to Exchange Online..."

try {
    Connect-RjRbExchangeOnline
}
catch {
    Write-Error "Exchange Online connection failed: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Mailbox permissions of '$UserName'"
Write-Output "---------------------"

try {
    # Check if the user has a mailbox
    $mailbox = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if (-not $mailbox) {
        throw "User object '$UserName' has no mailbox."
    }
    # All further lookups use the primary SMTP address of the mailbox
    $mailboxAddress = "$($mailbox.PrimarySmtpAddress)"
}
catch {
    Write-Error "Mailbox preflight check failed: $($_.Exception.Message)" -ErrorAction Continue
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    throw
}

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

try {
    # Full access permissions
    $fullAccessRows = @(Get-MailboxPermission -Identity $mailboxAddress |
            Where-Object { $_.User -ne 'NT AUTHORITY\SELF' } |
            ForEach-Object {
                [PSCustomObject]@{
                    Mailbox      = $mailboxAddress
                    User         = "$($_.User)"
                    AccessRights = (@($_.AccessRights) -join ", ")
                }
            })

    # Send As permissions
    $sendAsRows = @(Get-RecipientPermission -Identity $mailboxAddress |
            Where-Object { $_.Trustee -ne 'NT AUTHORITY\SELF' } |
            ForEach-Object {
                [PSCustomObject]@{
                    Mailbox      = $mailboxAddress
                    Trustee      = "$($_.Trustee)"
                    AccessRights = (@($_.AccessRights) -join ", ")
                }
            })

    # Send on Behalf permissions
    $sendOnBehalfRows = @(foreach ($sobEntry in @((Get-Mailbox -Identity $mailboxAddress).GrantSendOnBehalfTo)) {
            # The entries are recipient names, which are not unique in Exchange Online - list the raw name
            # when it cannot be resolved to exactly one recipient.
            $sobRecipient = Get-Recipient -Identity $sobEntry -ErrorAction SilentlyContinue
            if ($sobRecipient) {
                $sobTrustee = $sobRecipient | Where-Object { $_.RecipientType -eq "UserMailbox" }
            }
            else {
                $sobTrustee = [PSCustomObject]@{ PrimarySmtpAddress = "$sobEntry" }
            }
            foreach ($trustee in [array]$sobTrustee) {
                [PSCustomObject]@{
                    Mailbox      = $mailboxAddress
                    Trustee      = "$($trustee.PrimarySmtpAddress)"
                    AccessRights = "SendOnBehalf"
                }
            }
        })
}
catch {
    Write-Error "Reading the mailbox permissions failed: $($_.Exception.Message)" -ErrorAction Continue
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    throw
}

Write-Output "Full access permissions: $($fullAccessRows.Count)"
Write-Output "Send As permissions: $($sendAsRows.Count)"
Write-Output "Send on Behalf permissions: $($sendOnBehalfRows.Count)"

#endregion Main Part

########################################################
#region     Structured Output (Output Data)
########################################################

# Emitted last. Every table has its own RjTableTitle marker; a marker is only written when rows follow it.
Write-Output ""

if ($fullAccessRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Full access permissions" })
    Write-Output @($fullAccessRows | Select-Object -Property Mailbox, User, AccessRights)
}
else {
    Write-Output "No full access permissions found."
}

if ($sendAsRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Send As permissions" })
    Write-Output @($sendAsRows | Select-Object -Property Mailbox, Trustee, AccessRights)
}
else {
    Write-Output "No Send As permissions found."
}

if ($sendOnBehalfRows.Count -gt 0) {
    Write-Output ([PSCustomObject]@{ RjTableTitle = "Send on Behalf permissions" })
    Write-Output @($sendOnBehalfRows | Select-Object -Property Mailbox, Trustee, AccessRights)
}
else {
    Write-Output "No Send on Behalf permissions found."
}

#endregion Structured Output (Output Data)

########################################################
#region     Cleanup
########################################################

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion Cleanup

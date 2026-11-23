<#
	.SYNOPSIS
	Grant or revoke Exchange SendAs permission on a mailbox for one or more delegates

	.DESCRIPTION
	Grants or removes SendAs permission on the selected user's mailbox to one or more delegate users. The runbook displays current SendAs delegations before and after the change, processes each delegate independently, and reports a summary of successes, failures and skipped delegates. SendAs permission allows the delegate to send email that appears to come from the mailbox owner.

	.PARAMETER UserName
	User principal name of the mailbox owner.

	.PARAMETER delegateTo
	One or more users to whom you want to grant or revoke SendAs permission. You can select multiple delegates to apply the same action to all of them simultaneously.

	.PARAMETER Remove
	If set to true, the script will revoke SendAs permission from the selected delegates. If false, it will grant SendAs permission.

	.PARAMETER CallerName
	Name of the user or system that started the runbook. Tracked for auditing purposes.

	.INPUTS
	RunbookCustomization: {
	"Parameters": {
        "UserName": {
                "Hide" : true
            },
		"Remove": {
			"DisplayName": "Action",
			"Default": false,
			"Select": {
				"Options": [
					{ "Display": "Grant access", "ParameterValue": false },
					{ "Display": "Remove access", "ParameterValue": true }
				],
				"ShowValue": false
			}
		},
		"CallerName": {
			"Hide": true
		}
	}
}

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param(
[Parameter(Mandatory = $true)]
[String]$UserName,

[Parameter(Mandatory = $true)]
[ValidateScript( { Use-RJInterface -Type Graph -Entity User -Attribute userPrincipalName -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
[string[]]$delegateTo,

[bool]$Remove = $false,

# CallerName is tracked purely for auditing purposes
[Parameter(Mandatory = $true)]
[string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.2.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "delegateTo: $($delegateTo -join ', ')" -Verbose
Write-RjRbLog -Message "Remove: $Remove" -Verbose
Write-RjRbLog -Message "CallerName: $CallerName" -Verbose
#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################
Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

# Normalize $delegateTo into a de-duplicated, trimmed, non-empty list of UPNs.
# The portal multi-user picker may pass empty/whitespace entries.
# Sort-Object -Unique de-duplicates case-insensitively; Select-Object -Unique would keep both
# "John@contoso.com" and "john@contoso.com" and cause a duplicate permission call later.
$delegateList = @($delegateTo | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)

if (-not $delegateList -or $delegateList.Count -eq 0) {
    Write-Error "No valid delegate was specified. Please select at least one delegate to grant or remove SendAs for." -ErrorAction Continue
    throw "No valid delegate specified in 'delegateTo'."
}

# A mailbox cannot be delegated to its own owner - remove any self-references.
$selfDelegates = $delegateList | Where-Object { $_ -ieq $UserName }
if ($selfDelegates) {
    foreach ($selfDelegate in $selfDelegates) {
        Write-RjRbLog -Message "WARNING: '$selfDelegate' is the mailbox owner ('$UserName') and cannot be delegated to itself. Removing from the delegate list." -Verbose
    }
    $delegateList = @($delegateList | Where-Object { $_ -ine $UserName })
}

if (-not $delegateList -or $delegateList.Count -eq 0) {
    Write-Error "After removing the mailbox owner from the delegate list, no valid delegates remain. Please select at least one delegate other than '$UserName'." -ErrorAction Continue
    throw "No valid delegates remain after removing self-references."
}

Write-Output "Delegate(s) to process: $($delegateList -join ', ')"
#endregion Parameter Validation

########################################################
#region     Connect Part
########################################################
Write-Output ""
Write-Output "Connect to Exchange Online"
Write-Output "---------------------"

try {
    Connect-RjRbExchangeOnline
}
catch {
    Write-Error "Could not connect to Exchange Online: $($_.Exception.Message). Verify that the Azure Automation managed identity has been granted an Exchange Online RBAC role (e.g. 'Exchange Administrator' or a scoped custom role covering recipient permission management)." -ErrorAction Continue
    throw "Exchange Online connection could not be established. Stopping script."
}
#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################
Write-Output ""
Write-Output "Preflight-Check"
Write-Output "---------------------"

# Verify the target mailbox exists and is a valid Exchange Online recipient before attempting
# any SendAs grant/revoke against it. A missing mailbox is the most common failure mode here
# (user not yet licensed for Exchange Online, mailbox not yet provisioned, or a typo in $UserName).
Write-Output "Checking target mailbox '$UserName'..."
try {
    $targetMailbox = Get-EXOMailbox -Identity $UserName -ErrorAction Stop
}
catch {
    Write-Error "Could not find a mailbox for '$UserName': $($_.Exception.Message). This usually means the user is not licensed for Exchange Online, the mailbox has not finished provisioning yet, or '$UserName' is not a valid mailbox identity (UPN, primary SMTP address, or alias). Verify the user and license assignment, then try again." -ErrorAction Continue
    throw "Target mailbox '$UserName' could not be found."
}

# Resolve a canonical, tenant-unique identity for all subsequent Exchange Online calls against this
# mailbox. Do NOT use $targetMailbox.Identity: in Exchange Online that property is the mailbox's
# "Name" (derived from the display name at creation time), and Name is NOT guaranteed unique across
# the tenant. When another recipient (very commonly a shared mailbox) happens to share that Name,
# Exchange rejects subsequent calls with "... doesn't represent a unique recipient". The primary SMTP
# address, by contrast, is unique across every recipient in the tenant and is a supported Identity
# value for all the recipient-permission cmdlets used below.
$targetMailboxIdentity = [string]$targetMailbox.PrimarySmtpAddress
if ([string]::IsNullOrWhiteSpace($targetMailboxIdentity)) {
    $targetMailboxIdentity = [string]$targetMailbox.ExternalDirectoryObjectId
}
if ([string]::IsNullOrWhiteSpace($targetMailboxIdentity)) {
    $targetMailboxIdentity = $UserName
}
Write-RjRbLog -Message "Resolved target mailbox identity: '$targetMailboxIdentity'" -Verbose
Write-Output "Target mailbox resolved: $($targetMailbox.DisplayName) ($targetMailboxIdentity)"

# Verify each requested delegate actually has a mailbox. This is deliberately non-fatal per delegate:
# a single unresolvable delegate (typo, guest, mail-enabled contact, ambiguous Name) should not block
# granting/revoking SendAs for the rest of a multi-delegate request.
$validDelegates = @()
$skippedDelegates = @()

Write-Output ""
Write-Output "Verifying delegate mailboxes..."
foreach ($delegate in $delegateList) {
    try {
        $delegateMailbox = Get-EXOMailbox -Identity $delegate -ErrorAction Stop
        $resolvedDelegateSmtp = [string]$delegateMailbox.PrimarySmtpAddress
        $validDelegates += $resolvedDelegateSmtp
        Write-Output " - OK      : '$delegate' -> $resolvedDelegateSmtp"
    }
    catch {
        $delegateErrorMessage = $_.Exception.Message
        if ($delegateErrorMessage -like "*unique recipient*" -or $delegateErrorMessage -like "*more than one*recipient*" -or $delegateErrorMessage -like "*ambiguous*") {
            $skipReason = "The identity '$delegate' matches more than one recipient in the tenant (ambiguous Name/alias). Re-select this delegate using their primary SMTP address to disambiguate."
            $skipTerseReason = "ambiguous identity"
        }
        else {
            $skipReason = "No mailbox could be found for '$delegate': $delegateErrorMessage. Verify the delegate is a licensed, mailbox-enabled user."
            $skipTerseReason = "mailbox not found"
        }
        $skippedDelegates += [PSCustomObject]@{
            Delegate = $delegate
            Reason   = $skipReason
        }
        Write-Output " - SKIPPED : '$delegate' - $skipTerseReason"
        Write-RjRbLog -Message "WARNING: Skipping delegate '$delegate' - $skipReason" -Verbose
    }
}

if ($validDelegates.Count -eq 0) {
    Write-Error "None of the requested delegates could be resolved to a valid mailbox. No SendAs changes can be applied. See the SKIPPED entries above for details." -ErrorAction Continue
    throw "No valid delegates remain after mailbox verification."
}

if ($skippedDelegates.Count -gt 0) {
    Write-Output ""
    Write-Output "The following delegates were skipped and will NOT be processed:"
    foreach ($skipped in $skippedDelegates) {
        Write-Output " - $($skipped.Delegate): $($skipped.Reason)"
    }
}

# Re-apply the owner exclusion after resolution: a picker value can be an alias or secondary SMTP
# address that resolves to the SAME mailbox as the owner's primary SMTP address, even though the raw
# picker value looked different from $UserName. Compare against the resolved owner primary SMTP.
$ownerSmtp = [string]$targetMailbox.PrimarySmtpAddress
$ownerAfterResolution = $validDelegates | Where-Object { $_ -ieq $ownerSmtp }
if ($ownerAfterResolution) {
    Write-RjRbLog -Message "WARNING: One of the resolved delegates matched the mailbox owner's own primary SMTP address ('$ownerSmtp') after resolution and was removed from the delegate list." -Verbose
    $validDelegates = @($validDelegates | Where-Object { $_ -ine $ownerSmtp })
}

# De-duplicate again: two different picker values (e.g. an alias and the primary SMTP address) can
# resolve to the same underlying mailbox.
$validDelegates = @($validDelegates | Sort-Object -Unique)

if ($validDelegates.Count -eq 0) {
    Write-Error "After removing the mailbox owner from the resolved delegate list, no valid delegates remain. Nothing to do." -ErrorAction Continue
    throw "No valid delegates remain after excluding the mailbox owner."
}

Write-Output ""
Write-Output "Delegate(s) that will be processed: $($validDelegates -join ', ')"

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"
Write-Output "Getting current SendAs delegations for mailbox: $($UserName)"

# Read the current SendAs grants on the target mailbox. SendAs uses Get-RecipientPermission, which
# differs from the FullAccess sibling runbook (Get-MailboxPermission) in several important ways:
#  - the principal property is .Trustee, not .User
#  - the access right to filter on is the string "SendAs", not "FullAccess"
#  - entries carry an AccessControlType (Allow/Deny) instead of a Deny boolean
#  - there is no IsInherited property at all - SendAs grants returned here are never "inherited" in
#    the sense FullAccess permissions can be, so no inherited-permission handling applies
try {
    $StatusQuo = Get-RecipientPermission -Identity $targetMailboxIdentity -ErrorAction Stop | Where-Object { ($_.AccessRights -contains "SendAs") -or ([string]$_.AccessRights -match "\bSendAs\b") } | Where-Object { $_.Trustee -notlike "NT AUTHORITY\*" }
}
catch {
    $statusQuoErrorMessage = $_.Exception.Message
    if ($statusQuoErrorMessage -like "*unique recipient*" -or $statusQuoErrorMessage -like "*more than one*recipient*" -or $statusQuoErrorMessage -like "*ambiguous*") {
        Write-Error "Could not read current SendAs permissions for '$targetMailboxIdentity': $statusQuoErrorMessage. This runbook already resolved the mailbox to its unique primary SMTP address ('$targetMailboxIdentity') before this call, so another recipient in the tenant must be sharing that same address as a proxy address or alias. Check for a conflicting recipient and resolve the duplicate address before retrying." -ErrorAction Continue
    }
    else {
        Write-Error "Could not read current SendAs permissions for '$targetMailboxIdentity': $statusQuoErrorMessage" -ErrorAction Continue
    }
    throw "Failed to retrieve current SendAs delegations for '$targetMailboxIdentity'."
}

# Resolve each grant's Trustee to a primary SMTP address so we can compare it against $validDelegates
# (which are already primary SMTP addresses) and display something human-readable.
$CurrentSendAsEntries = @()
$CurrentSendAsEntryDelegates = @()
$CurrentSendAsDelegates = @()
$CurrentStateIsComplete = $true

foreach ($permissionEntry in $StatusQuo) {
    $isDenyEntry = ([string]$permissionEntry.AccessControlType -eq 'Deny')
    try {
        $trusteeRecipient = Get-EXORecipient -Identity $permissionEntry.Trustee -ErrorAction Stop
        $trusteeSmtp = [string]$trusteeRecipient.PrimarySmtpAddress
        $CurrentSendAsEntries += [PSCustomObject]@{
            DisplayUser = $trusteeSmtp
            IsDeny      = $isDenyEntry
        }
        $CurrentSendAsEntryDelegates += $trusteeSmtp
        if (-not $isDenyEntry) {
            $CurrentSendAsDelegates += $trusteeSmtp
        }
    }
    catch {
        $CurrentStateIsComplete = $false
        Write-RjRbLog -Message "WARNING: Could not resolve trustee '$($permissionEntry.Trustee)' to a mailbox/recipient: $($_.Exception.Message). Exchange Online will be treated as authoritative for this trustee instead of relying on this pre-checked status quo state." -Verbose
        $CurrentSendAsEntries += [PSCustomObject]@{
            DisplayUser = [string]$permissionEntry.Trustee
            IsDeny      = $isDenyEntry
        }
    }
}

Write-Output ""
Write-Output "Current SendAs Delegations:"
Write-Output "---------------------"

if ($CurrentSendAsEntries.Count -eq 0) {
    Write-Output "No existing SendAs delegations found on this mailbox."
}
else {
    foreach ($entry in $CurrentSendAsEntries) {
        $accessLabel = if ($entry.IsDeny) { "Deny" } else { "Allow" }
        Write-Output "Delegate: $($entry.DisplayUser) | SendAs: $accessLabel"
    }
}

Write-Output ""
Write-Output "Requested Delegates - Current State:"
Write-Output "---------------------"

foreach ($delegateSmtp in $validDelegates) {
    if ($CurrentSendAsDelegates -contains $delegateSmtp) {
        Write-Output "Delegate '$($delegateSmtp)' already has SendAs on this mailbox."
    }
    elseif ($CurrentSendAsEntryDelegates -contains $delegateSmtp) {
        Write-Output "Delegate '$($delegateSmtp)' currently has a SendAs Deny entry on this mailbox."
    }
    else {
        Write-Output "Delegate '$($delegateSmtp)' does not currently have SendAs on this mailbox."
    }
}
#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################
Write-Output ""
if ($Remove) {
    Write-Output "Removing SendAs delegation(s)"
}
else {
    Write-Output "Granting SendAs delegation(s)"
}
Write-Output "---------------------"

$succeededDelegates = @()
$failedDelegates = @()
$noopDelegates = @()

foreach ($delegateSmtp in $validDelegates) {
    if ($Remove) {
        # Only short-circuit when the pre-checked snapshot is complete AND it holds no SendAs
        # permission entry of any kind for this delegate. If an entry exists but is a Deny entry,
        # do NOT skip locally - let Exchange Online's own response to Remove-RecipientPermission
        # decide, so a removable delegation is never silently skipped.
        if ($CurrentStateIsComplete -and ($CurrentSendAsEntryDelegates -notcontains $delegateSmtp)) {
            Write-Output "Skipping '$delegateSmtp' - no SendAs permission entry exists on this mailbox for this delegate."
            $noopDelegates += $delegateSmtp
            continue
        }
        try {
            Remove-RecipientPermission -Identity $targetMailboxIdentity -Trustee $delegateSmtp -AccessRights SendAs -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Output "Removed SendAs for '$delegateSmtp'."
            $succeededDelegates += $delegateSmtp
        }
        catch {
            # Non-fatal per-delegate failure - recorded and surfaced, but the loop continues with the
            # remaining delegates. Detect the realistic Exchange Online failure modes so the requestor
            # gets a concrete next step instead of a raw exception string.
            $errorMessage = $_.Exception.Message
            if ($errorMessage -like "*no existing permission entry*" -or $errorMessage -like "*not found on this object*" -or $errorMessage -like "*isn't present on this object*" -or $errorMessage -like "*no matching permission*" -or $errorMessage -like "*ManagementObjectNotFoundException*") {
                # Exchange Online is authoritative: there is nothing to remove, so this is a no-op
                # rather than a failure (reached when the pre-check snapshot was incomplete).
                Write-Output "Skipping '$delegateSmtp' - Exchange Online reports no SendAs delegation to remove."
                $noopDelegates += $delegateSmtp
                continue
            }
            elseif ($errorMessage -like "*unique recipient*" -or $errorMessage -like "*more than one*recipient*" -or $errorMessage -like "*ambiguous*") {
                Write-RjRbLog -Message "WARNING: Could not remove SendAs for '$delegateSmtp' - Exchange Online reports the identity as ambiguous (more than one recipient matches it). Check whether another recipient in the tenant shares this address as a proxy/alias, resolve the duplicate in the Exchange admin center, and retry. Original error: $errorMessage" -Verbose
            }
            elseif ($errorMessage -like "*couldn't be found*" -or $errorMessage -like "*ObjectNotFound*" -or $errorMessage -like "*management object type*") {
                Write-RjRbLog -Message "WARNING: Could not remove SendAs for '$delegateSmtp' - the delegate could not be resolved as a valid Exchange Online recipient. If this delegate was created or renamed recently, Exchange Online directory replication can take up to a few hours; verify the SMTP address and retry after waiting. Original error: $errorMessage" -Verbose
            }
            elseif ($errorMessage -like "*access rights*" -or $errorMessage -like "*management role*" -or $errorMessage -like "*Insufficient*") {
                Write-RjRbLog -Message "WARNING: Could not remove SendAs for '$delegateSmtp' - the managed identity does not have sufficient Exchange Online permissions to modify recipient permissions. Verify that the managed identity is assigned an RBAC role (e.g. 'Mail Recipients' or a custom role including Remove-RecipientPermission) scoped to this mailbox. Original error: $errorMessage" -Verbose
            }
            else {
                Write-RjRbLog -Message "WARNING: Failed to remove SendAs for '$delegateSmtp': $errorMessage" -Verbose
            }
            $failedDelegates += [PSCustomObject]@{ Delegate = $delegateSmtp; Reason = $errorMessage }
        }
    }
    else {
        if ($CurrentStateIsComplete -and ($CurrentSendAsDelegates -contains $delegateSmtp)) {
            Write-Output "Skipping '$delegateSmtp' - SendAs is already granted."
            $noopDelegates += $delegateSmtp
            continue
        }
        try {
            Add-RecipientPermission -Identity $targetMailboxIdentity -Trustee $delegateSmtp -AccessRights SendAs -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Output "Granted SendAs for '$delegateSmtp'."
            $succeededDelegates += $delegateSmtp
        }
        catch {
            # Non-fatal per-delegate failure - recorded and surfaced, but the loop continues with the
            # remaining delegates. Detect the realistic Exchange Online failure modes so the requestor
            # gets a concrete next step instead of a raw exception string.
            $errorMessage = $_.Exception.Message
            if ($errorMessage -like "*existing permission entry*" -or $errorMessage -like "*already*exist*") {
                # Exchange Online is authoritative: the grant is already in place, so this is a no-op
                # rather than a failure (reached when the pre-check snapshot was incomplete).
                Write-Output "Skipping '$delegateSmtp' - SendAs is already granted."
                $noopDelegates += $delegateSmtp
                continue
            }
            elseif ($errorMessage -like "*unique recipient*" -or $errorMessage -like "*more than one*recipient*" -or $errorMessage -like "*ambiguous*") {
                Write-RjRbLog -Message "WARNING: Could not grant SendAs for '$delegateSmtp' - Exchange Online reports the identity as ambiguous (more than one recipient matches it). Check whether another recipient in the tenant shares this address as a proxy/alias, resolve the duplicate in the Exchange admin center, and retry. Original error: $errorMessage" -Verbose
            }
            elseif ($errorMessage -like "*couldn't be found*" -or $errorMessage -like "*ObjectNotFound*" -or $errorMessage -like "*management object type*") {
                Write-RjRbLog -Message "WARNING: Could not grant SendAs for '$delegateSmtp' - the delegate could not be resolved as a valid Exchange Online recipient. If this mailbox or delegate was created or renamed recently, Exchange Online directory replication can take up to a few hours; verify the SMTP address and retry after waiting. Original error: $errorMessage" -Verbose
            }
            elseif ($errorMessage -like "*access rights*" -or $errorMessage -like "*management role*" -or $errorMessage -like "*Insufficient*") {
                Write-RjRbLog -Message "WARNING: Could not grant SendAs for '$delegateSmtp' - the managed identity does not have sufficient Exchange Online permissions to modify recipient permissions. Verify that the managed identity is assigned an RBAC role (e.g. 'Mail Recipients' or a custom role including Add-RecipientPermission) scoped to this mailbox. Original error: $errorMessage" -Verbose
            }
            elseif ($errorMessage -like "*not a valid recipient*" -or $errorMessage -like "*isn't mail*enabled*" -or $errorMessage -like "*disabled*") {
                Write-RjRbLog -Message "WARNING: Could not grant SendAs for '$delegateSmtp' - the delegate may be a shared or unlicensed mailbox that cannot currently be used as a delegation target. Verify the mailbox is fully provisioned (license and mailbox plan assignment can also take time to replicate) and retry. Original error: $errorMessage" -Verbose
            }
            else {
                Write-RjRbLog -Message "WARNING: Failed to grant SendAs for '$delegateSmtp': $errorMessage" -Verbose
            }
            $failedDelegates += [PSCustomObject]@{ Delegate = $delegateSmtp; Reason = $errorMessage }
        }
    }
}

Write-Output ""
Write-Output "Result"
Write-Output "---------------------"

try {
    $newPermissions = Get-RecipientPermission -Identity $targetMailboxIdentity -ErrorAction Stop | Where-Object {
        ($_.AccessRights -contains "SendAs") -or ([string]$_.AccessRights -match "\bSendAs\b")
    } | Where-Object { $_.Trustee -notlike "NT AUTHORITY\*" }
    Write-Output "SendAs delegations on '$UserName' after the change:"
    if (-not $newPermissions) {
        Write-Output "No SendAs delegations remain on this mailbox."
    }
    else {
        foreach ($permission in $newPermissions) {
            $displayUser = $permission.Trustee
            try {
                $displayUser = (Get-EXORecipient -Identity $permission.Trustee -ErrorAction Stop).PrimarySmtpAddress
            }
            catch {
                Write-RjRbLog -Message "Could not resolve permission entry '$($permission.Trustee)' for display - listing as-is." -Verbose
            }
            # Get-RecipientPermission exposes Allow/Deny as the AccessControlType property (there is no
            # Deny boolean and no IsInherited property, unlike Get-MailboxPermission). Compare it as a
            # string so the classification is correct regardless of how the REST layer types it.
            $resultEntryType = if ([string]$permission.AccessControlType -eq 'Deny') { "Deny" } else { "Allow" }
            Write-Output "Delegate: $displayUser | SendAs: $resultEntryType"
        }
    }
}
catch {
    # This only affects the after-state read-back for display purposes. The delegation changes above
    # were already applied (or explicitly skipped/failed and reported) before this block runs.
    Write-RjRbLog -Message "WARNING: The delegation change(s) above were processed, but the recipient permissions could not be re-read to confirm the resulting state (this is a verification step only - the changes themselves were most likely applied successfully). Re-run this runbook or check delegations manually in the Exchange admin center if confirmation is required. Original error: $($_.Exception.Message)" -Verbose
}

Write-Output ""
Write-Output "Summary: $($succeededDelegates.Count) changed, $($noopDelegates.Count) unchanged, $($failedDelegates.Count) failed, $($skippedDelegates.Count) skipped (no mailbox)."
if ($failedDelegates.Count -gt 0) {
    foreach ($failure in $failedDelegates) {
        Write-Output " - $($failure.Delegate): $($failure.Reason)"
    }
}

# Any delegate that could not be processed is surfaced as a runbook failure, so a partial success
# is visible in the portal instead of being reported as a clean run. Delegates skipped during the
# preflight (no mailbox) were already reported above and do not fail the run on their own.
if ($failedDelegates.Count -gt 0) {
    Write-Error "SendAs delegation failed for $($failedDelegates.Count) of $($validDelegates.Count) selected delegate(s). Review the WARNING messages above for the specific reason per delegate (recipient not found / directory replication delay, an ambiguous identity that matches more than one recipient, insufficient Exchange Online permissions on the managed identity, or a shared/unlicensed mailbox) and retry for the affected delegate(s) after resolving them." -ErrorAction Continue
    throw "SendAs delegation failed for $($failedDelegates.Count) of $($validDelegates.Count) selected delegate(s) on '$UserName'."
}
#endregion Main Part

########################################################
#region     Cleanup
########################################################
Write-Output ""
Write-Output "Disconnecting from Exchange Online..."
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

Write-Output ""
Write-Output "Done!"
#endregion Cleanup

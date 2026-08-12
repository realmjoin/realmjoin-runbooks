<#
	.SYNOPSIS
	Grant or revoke Exchange Online FullAccess mailbox permission for one or more users

	.DESCRIPTION
	Grants or removes Exchange Online FullAccess permission on a selected user's mailbox for one or more delegate users, with optional Outlook AutoMapping configuration. The runbook displays the mailbox permissions before and after the change, and continues with the remaining delegates if one fails, providing a summary of all successes and failures.

	.PARAMETER UserName
	User principal name of the mailbox owner.

	.PARAMETER delegateTo
	One or more users to whom you want to grant or revoke full mailbox access. You can select multiple delegates to apply the same action to all of them simultaneously.

	.PARAMETER Remove
	If set to true, the script will remove the FullAccess permission. If false, it will grant the permission.

	.PARAMETER AutoMapping
	If set to true, Outlook will automatically map the delegated mailbox in the delegate's Outlook client. This option is only applicable when granting access (Remove = false).

	.PARAMETER CallerName
	Name of the user or system that started the runbook. Tracked for auditing purposes.

	.INPUTS
	RunbookCustomization: {
	    "Parameters": {
        	"UserName": {
                "Hide" : true
            },
	        "delegateTo": {
	            "DisplayName": "Delegate access to"
	        },
	        "Remove": {
	            "DisplayName": "Action",
	            "Default": false,
	            "Select": {
	                "Options": [
	                    {
	                        "Display": "Grant access",
	                        "ParameterValue": false,
	                        "Customization": {
	                            "Show": ["AutoMapping"]
	                        }
	                    },
	                    {
	                        "Display": "Remove access",
	                        "ParameterValue": true,
	                        "Customization": {
	                            "Hide": ["AutoMapping"]
	                        }
	                    }
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.8" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

param (
    [Parameter(Mandatory = $true)]
    [String]$UserName,

    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -Attribute userPrincipalName -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string[]]$delegateTo,

    [bool]$Remove = $false,

    [bool]$AutoMapping = $false,

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

$Version = "1.1.2"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "delegateTo: $($delegateTo -join ', ')" -Verbose
Write-RjRbLog -Message "Remove: $Remove" -Verbose
Write-RjRbLog -Message "AutoMapping: $AutoMapping" -Verbose
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
    Write-Error "No valid delegate was specified. Please select at least one delegate to grant or remove FullAccess for." -ErrorAction Continue
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

# AutoMapping has no effect when removing permissions - warn but do not fail the run.
if (($AutoMapping -eq $true) -and ($Remove -eq $true)) {
    Write-RjRbLog -Message "WARNING: 'AutoMapping' is set to true, but 'Remove' is also true. AutoMapping has no effect when removing FullAccess permissions and will be ignored." -Verbose
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
    Write-Error "Could not connect to Exchange Online: $($_.Exception.Message). Verify that the Azure Automation managed identity has been granted an Exchange Online RBAC role (e.g. 'Exchange Administrator' or a scoped custom role covering mailbox permission management)." -ErrorAction Continue
    throw "Exchange Online connection could not be established. Stopping script."
}

#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Preflight-Check"
Write-Output "---------------------"

# Verify the target mailbox exists before attempting any permission changes.
Write-Output "Checking if mailbox '$UserName' exists..."
try {
    $targetMailbox = Get-EXOMailbox -Identity $UserName -ErrorAction Stop
}
catch {
    Write-Error "Mailbox '$UserName' could not be found in Exchange Online. The user may not be licensed for Exchange Online, the mailbox may not yet be provisioned, or the identity is incorrect. Details: $($_.Exception.Message)" -ErrorAction Continue
    throw "Mailbox '$UserName' not found in Exchange Online."
}
Write-Output "Mailbox '$UserName' found."

# Verify each delegate has a mailbox. A missing delegate mailbox is NOT fatal for the whole
# run - it is skipped so processing can continue for the remaining, valid delegates.
Write-Output ""
Write-Output "Checking delegate mailboxes..."
$validDelegates = @()
$skippedDelegates = @()

foreach ($delegate in $delegateList) {
    try {
        $delegateMailbox = Get-EXOMailbox -Identity $delegate -ErrorAction Stop
        $validDelegates += [string]$delegateMailbox.PrimarySmtpAddress
        Write-Output " - OK      : '$delegate' -> $($delegateMailbox.PrimarySmtpAddress)"
    }
    catch {
        $skipReason = "Mailbox '$delegate' could not be found in Exchange Online. The user may not be licensed for Exchange Online, the mailbox may not yet be provisioned, or the identity is incorrect."
        $skippedDelegates += [PSCustomObject]@{
            Delegate = $delegate
            Reason   = $skipReason
        }
        Write-RjRbLog -Message "WARNING: Skipping delegate '$delegate': $skipReason" -Verbose
        Write-Output " - SKIPPED : '$delegate' - mailbox not found"
    }
}

if ($validDelegates.Count -eq 0) {
    Write-Error "None of the specified delegates have a valid mailbox in Exchange Online. Please check the delegate names/UPNs and try again." -ErrorAction Continue
    throw "No valid delegate mailboxes found among: $($delegateList -join ', ')"
}

if ($skippedDelegates.Count -gt 0) {
    Write-Output ""
    Write-Output "The following delegate(s) were skipped and will NOT be processed:"
    foreach ($skipped in $skippedDelegates) {
        Write-Output " - $($skipped.Delegate): $($skipped.Reason)"
    }
}

# The pre-resolution owner check compares raw picker values. A picker value can be a UPN or an
# alias that resolves to the mailbox owner's primary SMTP address, so re-apply the exclusion now
# that every delegate has been resolved.
$ownerSmtp = [string]$targetMailbox.PrimarySmtpAddress
$ownerAfterResolution = $validDelegates | Where-Object { $_ -ieq $ownerSmtp }
if ($ownerAfterResolution) {
    Write-RjRbLog -Message "WARNING: One of the selected delegates resolves to the mailbox owner ('$ownerSmtp') and cannot be delegated to itself. Removing from the delegate list." -Verbose
    $validDelegates = @($validDelegates | Where-Object { $_ -ine $ownerSmtp })
}

# De-duplicate again: two different picker values can resolve to the same mailbox.
$validDelegates = @($validDelegates | Sort-Object -Unique)

if ($validDelegates.Count -eq 0) {
    Write-Error "After removing the mailbox owner from the delegate list, no valid delegates remain. Please select at least one delegate other than '$UserName'." -ErrorAction Continue
    throw "No valid delegates remain after resolving delegate mailboxes."
}

Write-Output ""
Write-Output "Delegate(s) that will be processed: $($validDelegates -join ', ')"

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"
Write-Output "Getting current FullAccess delegations for mailbox: $($UserName)"

try {
    # Exclude the mailbox's own inherited "NT AUTHORITY\SELF" system entry - that is not a real
    # delegation. Real delegates can still legitimately show up as inherited (e.g. via nested group
    # membership), so IsInherited is not filtered out here - it is surfaced per entry below instead.
    $StatusQuo = Get-MailboxPermission -Identity $targetMailbox.Identity -ErrorAction Stop | Where-Object {
        ($_.AccessRights -contains "FullAccess") -or ([string]$_.AccessRights -match "\bFullAccess\b")
    } | Where-Object { $_.User -notlike "NT AUTHORITY\*" }
}
catch {
    Write-Error "Failed to retrieve current mailbox permissions for '$($UserName)': $($_.Exception.Message)" -ErrorAction Continue
    throw "Could not read current mailbox permissions for '$UserName'."
}

# Resolve each existing permission entry to its primary SMTP address, so it can be compared
# against $validDelegates (already resolved to primary SMTP addresses by the preflight checks above).
# Only entries that actually grant access (Deny -eq $false) count as "currently has FullAccess".
#
# EXO V3 (REST-backed) Get-MailboxPermission does not reliably return Deny/IsInherited as real
# [bool] values - they can come back as the literal strings "True"/"False". PowerShell's implicit
# truthiness treats ANY non-empty string (including the string "False") as $true, so evaluating
# $permissionEntry.Deny directly in an `if` / `-not` is unsafe and previously misclassified real
# Allow grants as Deny. Normalize both flags via explicit string comparison instead, which is
# correct whether the property is a real [bool], the string "True"/"False", or $null/absent
# (treated as $false, i.e. Allow / not inherited).
$CurrentFullAccessDelegates = @()
# Every resolved FullAccess entry regardless of Allow/Deny - lets the Main Part distinguish "no
# entry at all for this delegate" (safe to treat as a local no-op) from "an entry exists but it is
# Deny" (must not be skipped locally; let Exchange Online's own response be authoritative instead).
$CurrentFullAccessEntryDelegates = @()
$CurrentFullAccessEntries = @()
# Tracks whether every existing permission entry could be resolved to an SMTP address. When an
# entry cannot be resolved, the snapshot is incomplete and must NOT be used to skip work as a
# no-op - Exchange Online itself is treated as authoritative instead.
$CurrentStateIsComplete = $true

foreach ($permissionEntry in $StatusQuo) {
    $resolvedSmtp = $null
    try {
        $resolvedRecipient = Get-EXORecipient -Identity $permissionEntry.User -ErrorAction Stop
        $resolvedSmtp = [string]$resolvedRecipient.PrimarySmtpAddress
    }
    catch {
        $CurrentStateIsComplete = $false
        Write-RjRbLog -Message "WARNING: Could not resolve existing permission entry '$($permissionEntry.User)' to a mailbox/recipient - listing it as-is. Exchange Online will be treated as authoritative for the delegates below instead of this pre-checked state." -Verbose
    }

    # String-compare, not a direct boolean evaluation - see the normalization comment above.
    $isDenyEntry = ([string]$permissionEntry.Deny -eq 'True')
    $isInheritedEntry = ([string]$permissionEntry.IsInherited -eq 'True')

    $CurrentFullAccessEntries += [PSCustomObject]@{
        DisplayUser = if ($resolvedSmtp) { $resolvedSmtp } else { $permissionEntry.User }
        IsInherited = $isInheritedEntry
        IsDeny      = $isDenyEntry
    }

    if ($resolvedSmtp) {
        $CurrentFullAccessEntryDelegates += $resolvedSmtp
        if (-not $isDenyEntry) {
            $CurrentFullAccessDelegates += $resolvedSmtp
        }
    }
}

Write-Output ""
Write-Output "Current FullAccess Delegations:"
Write-Output "---------------------"

if ($CurrentFullAccessEntries.Count -eq 0) {
    Write-Output "No existing FullAccess delegations found on this mailbox."
}
else {
    foreach ($entry in $CurrentFullAccessEntries) {
        $entryType = if ($entry.IsDeny) { "Deny" } else { "Allow" }
        $inheritedNote = if ($entry.IsInherited) { " (inherited)" } else { "" }
        Write-Output "Delegate: $($entry.DisplayUser) | FullAccess: $($entryType)$($inheritedNote)"
    }
}

Write-Output ""
Write-Output "Requested Delegates - Current State:"
Write-Output "---------------------"

foreach ($delegateSmtp in $validDelegates) {
    if ($CurrentFullAccessDelegates -contains $delegateSmtp) {
        Write-Output "Delegate '$($delegateSmtp)' already has FullAccess on this mailbox."
    }
    else {
        Write-Output "Delegate '$($delegateSmtp)' does not currently have FullAccess on this mailbox."
    }
}

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

Write-Output ""
if ($Remove) {
    Write-Output "Removing FullAccess delegation(s)"
}
else {
    Write-Output "Granting FullAccess delegation(s)"
}
Write-Output "---------------------"

$succeededDelegates = @()
$failedDelegates = @()
$noopDelegates = @()

foreach ($delegateSmtp in $validDelegates) {
    if ($Remove) {
        # Only short-circuit when the pre-checked snapshot is complete AND it holds no FullAccess
        # permission entry of any kind for this delegate. If an entry exists but is a Deny entry,
        # do NOT skip locally - let Exchange Online's own response to Remove-MailboxPermission
        # decide, so a removable delegation is never silently skipped.
        if ($CurrentStateIsComplete -and ($CurrentFullAccessEntryDelegates -notcontains $delegateSmtp)) {
            Write-Output "Skipping '$delegateSmtp' - no FullAccess permission entry exists on this mailbox for this delegate."
            $noopDelegates += $delegateSmtp
            continue
        }
        try {
            Remove-MailboxPermission -Identity $targetMailbox.Identity -User $delegateSmtp -AccessRights FullAccess -InheritanceType All -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Output "Removed FullAccess for '$delegateSmtp'."
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
                Write-Output "Skipping '$delegateSmtp' - Exchange Online reports no FullAccess delegation to remove."
                $noopDelegates += $delegateSmtp
                continue
            }
            elseif ($errorMessage -like "*inherited*" -or $errorMessage -like "*cannot be removed*" -or $errorMessage -like "*can't be modified*") {
                Write-RjRbLog -Message "WARNING: Could not remove FullAccess for '$delegateSmtp' - this permission entry is inherited (for example from a role group or security group assignment) rather than granted directly on the mailbox, so it cannot be removed with Remove-MailboxPermission. Remove or adjust the inherited assignment (e.g. the group membership or role group) instead. Original error: $errorMessage" -Verbose
            }
            elseif ($errorMessage -like "*couldn't be found*" -or $errorMessage -like "*ObjectNotFound*" -or $errorMessage -like "*management object type*") {
                Write-RjRbLog -Message "WARNING: Could not remove FullAccess for '$delegateSmtp' - the delegate could not be resolved as a valid Exchange Online recipient. If this delegate was created or renamed recently, Exchange Online directory replication can take up to a few hours; verify the SMTP address and retry after waiting. Original error: $errorMessage" -Verbose
            }
            elseif ($errorMessage -like "*access rights*" -or $errorMessage -like "*management role*" -or $errorMessage -like "*Insufficient*") {
                Write-RjRbLog -Message "WARNING: Could not remove FullAccess for '$delegateSmtp' - the managed identity does not have sufficient Exchange Online permissions to modify mailbox permissions. Verify that the managed identity is assigned an RBAC role (e.g. 'Mail Recipients' or a custom role including Remove-MailboxPermission) scoped to this mailbox. Original error: $errorMessage" -Verbose
            }
            else {
                Write-RjRbLog -Message "WARNING: Failed to remove FullAccess for '$delegateSmtp': $errorMessage" -Verbose
            }
            $failedDelegates += [PSCustomObject]@{ Delegate = $delegateSmtp; Reason = $errorMessage }
        }
    }
    else {
        if ($CurrentStateIsComplete -and ($CurrentFullAccessDelegates -contains $delegateSmtp)) {
            Write-Output "Skipping '$delegateSmtp' - FullAccess is already granted."
            $noopDelegates += $delegateSmtp
            continue
        }
        try {
            Add-MailboxPermission -Identity $targetMailbox.Identity -User $delegateSmtp -AccessRights FullAccess -AutoMapping $AutoMapping -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Output "Granted FullAccess for '$delegateSmtp' (AutoMapping: $AutoMapping)."
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
                Write-Output "Skipping '$delegateSmtp' - FullAccess is already granted."
                $noopDelegates += $delegateSmtp
                continue
            }
            elseif ($errorMessage -like "*couldn't be found*" -or $errorMessage -like "*ObjectNotFound*" -or $errorMessage -like "*management object type*") {
                Write-RjRbLog -Message "WARNING: Could not grant FullAccess for '$delegateSmtp' - the delegate could not be resolved as a valid Exchange Online recipient. If this mailbox or delegate was created or renamed recently, Exchange Online directory replication can take up to a few hours; verify the SMTP address and retry after waiting. Original error: $errorMessage" -Verbose
            }
            elseif ($errorMessage -like "*access rights*" -or $errorMessage -like "*management role*" -or $errorMessage -like "*Insufficient*") {
                Write-RjRbLog -Message "WARNING: Could not grant FullAccess for '$delegateSmtp' - the managed identity does not have sufficient Exchange Online permissions to modify mailbox permissions. Verify that the managed identity is assigned an RBAC role (e.g. 'Mail Recipients' or a custom role including Add-MailboxPermission) scoped to this mailbox. Original error: $errorMessage" -Verbose
            }
            elseif ($errorMessage -like "*not a valid recipient*" -or $errorMessage -like "*isn't mail*enabled*" -or $errorMessage -like "*disabled*") {
                Write-RjRbLog -Message "WARNING: Could not grant FullAccess for '$delegateSmtp' - the delegate may be a shared or unlicensed mailbox that cannot currently be used as a delegation target. Verify the mailbox is fully provisioned (license and mailbox plan assignment can also take time to replicate) and retry. Original error: $errorMessage" -Verbose
            }
            else {
                Write-RjRbLog -Message "WARNING: Failed to grant FullAccess for '$delegateSmtp': $errorMessage" -Verbose
            }
            $failedDelegates += [PSCustomObject]@{ Delegate = $delegateSmtp; Reason = $errorMessage }
        }
    }
}

Write-Output ""
Write-Output "Result"
Write-Output "---------------------"

try {
    $newPermissions = Get-MailboxPermission -Identity $targetMailbox.Identity -ErrorAction Stop | Where-Object {
        ($_.AccessRights -contains "FullAccess") -or ([string]$_.AccessRights -match "\bFullAccess\b")
    } | Where-Object { $_.User -notlike "NT AUTHORITY\*" }
    Write-Output "FullAccess delegations on '$UserName' after the change:"
    if (-not $newPermissions) {
        Write-Output "No FullAccess delegations remain on this mailbox."
    }
    else {
        foreach ($permission in $newPermissions) {
            $displayUser = $permission.User
            try {
                $displayUser = (Get-EXORecipient -Identity $permission.User -ErrorAction Stop).PrimarySmtpAddress
            }
            catch {
                Write-RjRbLog -Message "Could not resolve permission entry '$($permission.User)' for display - listing as-is." -Verbose
            }
            # Normalized the same way as the StatusQuo display - the raw EXO properties may be the
            # strings "True"/"False" and must not be evaluated as booleans directly.
            $resultEntryType = if ([string]$permission.Deny -eq 'True') { "Deny" } else { "Allow" }
            $resultInheritedNote = if ([string]$permission.IsInherited -eq 'True') { " (inherited)" } else { "" }
            Write-Output "Delegate: $displayUser | FullAccess: $($resultEntryType)$($resultInheritedNote)"
        }
    }
}
catch {
    # This only affects the after-state read-back for display purposes. The delegation changes above
    # were already applied (or explicitly skipped/failed and reported) before this block runs.
    Write-RjRbLog -Message "WARNING: The delegation change(s) above were processed, but the mailbox permissions could not be re-read to confirm the resulting state (this is a verification step only - the changes themselves were most likely applied successfully). Re-run this runbook or check delegations manually in the Exchange admin center if confirmation is required. Original error: $($_.Exception.Message)" -Verbose
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
    Write-Error "FullAccess delegation failed for $($failedDelegates.Count) of $($validDelegates.Count) selected delegate(s). Review the WARNING messages above for the specific reason per delegate (recipient not found / directory replication delay, insufficient Exchange Online permissions on the managed identity, a permission inherited from a group rather than assigned directly, or a shared/unlicensed mailbox) and retry for the affected delegate(s) after resolving them." -ErrorAction Continue
    throw "FullAccess delegation failed for $($failedDelegates.Count) of $($validDelegates.Count) selected delegate(s) on '$UserName'."
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

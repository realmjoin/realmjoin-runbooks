# Delegate Send As

Grant or revoke Exchange SendAs permission on a mailbox for one or more delegates

## Detailed description
Grants or removes SendAs permission on the selected user's mailbox to one or more delegate users. The runbook displays current SendAs delegations before and after the change, processes each delegate independently, and reports a summary of successes, failures and skipped delegates. SendAs permission allows the delegate to send email that appears to come from the mailbox owner.

## Where to find
User \ Mail \ Delegate Send As

## How it works

On each run the runbook:

1. Connects to Exchange Online with the Automation account's managed identity.
2. Verifies that the selected mailbox owner (`UserName`) actually has a mailbox - if not, the run stops before anything is changed.
3. Resolves every selected delegate to its primary SMTP address and drops duplicates and the mailbox owner itself.
4. Reads and prints the current **SendAs** delegations on the mailbox (the *status quo*).
5. Grants or removes SendAs for each remaining delegate, one at a time.
6. Re-reads the recipient permissions and prints the resulting state plus a per-run summary.

The runbook only ever touches the **SendAs** right on the one selected mailbox. Full Access, Send on Behalf and folder-level permissions are not affected.

### Selecting delegates

The **Delegate access to** field is a **multi-select** user picker. Select as many delegates as needed - all of them receive the same action (*Grant access* or *Remove access*) from the form in a single run.

The picker is restricted to member accounts (`userType eq 'Member'`), so guest accounts are not offered. It hands over each selected delegate as a **user principal name**, so the very first log line already reads as a list of UPNs instead of raw object IDs. Each value is then resolved against Exchange Online, and from the preflight step onward all output shows the delegate's primary SMTP address.

Two picker entries that resolve to the same mailbox are de-duplicated, and a delegate that resolves to the mailbox owner is dropped with a warning - a mailbox cannot be delegated to itself.

### What gets changed

- **Grant access (`Remove` = false):** `Add-RecipientPermission` with `-AccessRights SendAs` for each delegate.
- **Remove access (`Remove` = true):** `Remove-RecipientPermission` with `-AccessRights SendAs` for each delegate.

SendAs lets the delegate send messages that appear to come **from the mailbox owner** - the recipient sees only the owner's address as the sender. This differs from *Send on Behalf*, which shows "delegate on behalf of owner", and from *Full Access*, which grants read access to the mailbox contents but no ability to send as the owner. Granting SendAs does **not** give the delegate access to the mailbox itself.

### Idempotent by design

Nothing is done twice and nothing fails just because it was already true:

- Granting SendAs to a delegate who already holds it is reported as *unchanged*, not as an error.
- Removing SendAs from a delegate who has no such entry is reported as *unchanged*, not as an error.
- When the pre-change snapshot cannot classify an existing permission entry, the runbook does **not** take the shortcut - it calls Exchange Online and lets its response decide, so a removable delegation is never silently skipped.

### Partial results

Delegates are processed independently:

- A delegate **without a mailbox** is skipped during the preflight check and counted as *skipped*; the remaining delegates are still processed. If none of the selected delegates has a mailbox, the run stops.
- A delegate whose change **fails** is reported with a targeted reason (directory-replication delay, insufficient Exchange Online permissions on the managed identity, an ambiguous recipient, or a shared/unlicensed mailbox) and the loop continues with the rest.

Every run ends with a summary line in the form `Summary: <changed>, <unchanged>, <failed>, <skipped (no mailbox)>`, followed by the resulting SendAs delegations on the mailbox.

If **any** delegate failed, the runbook itself reports a failure. This is deliberate: with a multi-select picker, a partial success reported as a clean run would hide delegates that never received access.

### Mailbox identity resolution

The target mailbox is looked up once with `Get-EXOMailbox` and then addressed by its **primary SMTP address** for every permission operation. Exchange Online's `Identity` property is the mailbox *Name*, which is derived from the display name and is not unique - if any other recipient in the tenant carries the same name, Exchange rejects the call with *"&lt;name&gt; doesn't represent a unique recipient"*. This is common for shared mailboxes. A primary SMTP address cannot be duplicated across recipients, so it is used instead.

If an ambiguity error still occurs, the runbook reports it explicitly and points at the duplicate recipient rather than showing the raw Exchange exception.

### Limitations

- **Only explicit Allow grants are managed.** An explicit **Deny** entry on the mailbox is displayed for transparency, but the runbook never adds or removes one.
- **Distribution groups and mail-enabled security groups are not offered as delegates.** The picker resolves member user accounts, and every delegate must have a mailbox to pass the preflight check.
- **Unlike Full Access, SendAs has no AutoMapping option.** There is nothing for Outlook to map, so no such parameter exists on this runbook.

### Prerequisites

The Automation account's managed identity connects to Exchange Online via `Connect-RjRbExchangeOnline` and needs:

- the `Exchange.ManageAsApp` application permission on *Office 365 Exchange Online*, and
- the **Exchange Administrator** role (or an equivalent Exchange Online RBAC role that includes `Add-RecipientPermission` and `Remove-RecipientPermission`).

`Exchange.ManageAsApp` is a broad, admin-equivalent grant. It is used here because Exchange Online offers no narrower app-only permission that covers recipient permission management - it is the minimal available scope for this operation, not a convenience choice.

The runbook makes no Microsoft Graph calls - the user picker is a portal-side annotation only, so no Graph application permissions are required.


## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### UserName
User principal name of the mailbox owner.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### delegateTo
One or more users to whom you want to grant or revoke SendAs permission. You can select multiple delegates to apply the same action to all of them simultaneously.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String Array |

### Remove
If set to true, the script will revoke SendAs permission from the selected delegates. If false, it will grant SendAs permission.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


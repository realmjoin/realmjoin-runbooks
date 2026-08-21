# Delegate Full Access

Grant or revoke Exchange Online FullAccess mailbox permission for one or more users

## Detailed description
Grants or removes Exchange Online FullAccess permission on a selected user's mailbox for one or more delegate users, with optional Outlook AutoMapping configuration. The runbook displays the mailbox permissions before and after the change, and continues with the remaining delegates if one fails, providing a summary of all successes and failures.

## Where to find
User \ Mail \ Delegate Full Access

## How it works

On each run the runbook:

1. Connects to Exchange Online with the Automation account's managed identity.
2. Verifies that the selected mailbox owner (`UserName`) actually has a mailbox - if not, the run stops before anything is changed.
3. Resolves every selected delegate to its primary SMTP address and drops duplicates and the mailbox owner itself.
4. Reads and prints the current **FullAccess** delegations on the mailbox (the *status quo*).
5. Grants or removes FullAccess for each remaining delegate, one at a time.
6. Re-reads the mailbox permissions and prints the resulting state plus a per-run summary.

The runbook only ever touches the **FullAccess** right on the one selected mailbox. Send As, Send on Behalf and folder-level permissions are not affected.

### Selecting delegates

The **Delegate access to** field is a **multi-select** user picker. Select as many delegates as needed - all of them receive the same action (*Grant access* or *Remove access*) and the same AutoMapping setting from the form in a single run.

The picker is restricted to member accounts (`userType eq 'Member'`), so guest accounts are not offered. It hands over each selected delegate as a **user principal name**, so the very first log line already reads as a list of UPNs instead of raw object IDs. Each value is then resolved against Exchange Online, and from the preflight step onward all output shows the delegate's primary SMTP address.

Two picker entries that resolve to the same mailbox are de-duplicated, and a delegate that resolves to the mailbox owner is dropped with a warning - a mailbox cannot be delegated to itself.

### What gets changed

- **Grant access (`Remove` = false):** `Add-MailboxPermission` with `-AccessRights FullAccess` for each delegate.
- **Remove access (`Remove` = true):** `Remove-MailboxPermission` with `-AccessRights FullAccess -InheritanceType All` for each delegate.

### AutoMapping

**`AutoMapping`** is only evaluated when granting access; the portal hides the field when *Remove access* is selected. With AutoMapping enabled, Outlook adds the delegated mailbox to the delegate's profile automatically - but only after the client re-creates the mapping, which can take a while. Existing grants are not re-written to change their AutoMapping value; remove the delegation and grant it again if the mapping behaviour must change.

### Idempotent by design

Nothing is done twice and nothing fails just because it was already true:

- Granting access to a delegate who already holds FullAccess is reported as *unchanged*, not as an error.
- Removing access from a delegate who has no FullAccess entry is reported as *unchanged*, not as an error.
- When the pre-change snapshot cannot classify an existing permission entry, the runbook does **not** take the shortcut - it calls Exchange Online and lets its response decide, so a removable delegation is never silently skipped.

### Partial results

Delegates are processed independently:

- A delegate **without a mailbox** is skipped during the preflight check and counted as *skipped*; the remaining delegates are still processed. If none of the selected delegates has a mailbox, the run stops.
- A delegate whose change **fails** is reported with a targeted reason (directory-replication delay, insufficient Exchange Online permissions on the managed identity, a permission inherited from a group, or a shared/unlicensed mailbox) and the loop continues with the rest.

Every run ends with a summary line in the form `Summary: <changed>, <unchanged>, <failed>, <skipped (no mailbox)>`, followed by the resulting FullAccess delegations on the mailbox.

If **any** delegate failed, the runbook itself reports a failure. This is deliberate: with a multi-select picker, a partial success reported as a clean run would hide delegates that never received access.

### Limitations

- **Inherited permissions cannot be removed.** A FullAccess right that comes from a role group or security group membership is shown as *inherited* but cannot be revoked here - adjust the group membership or role assignment instead.
- **Only explicit Allow grants are managed.** An explicit **Deny** entry on the mailbox is displayed for transparency, but the runbook never adds or removes one.

### Prerequisites

The Automation account's managed identity connects to Exchange Online via `Connect-RjRbExchangeOnline` and needs:

- the `Exchange.ManageAsApp` application permission on *Office 365 Exchange Online*, and
- the **Exchange Administrator** role (or an equivalent Exchange Online RBAC role that includes `Add-MailboxPermission` and `Remove-MailboxPermission`).

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
One or more users to whom you want to grant or revoke full mailbox access. You can select multiple delegates to apply the same action to all of them simultaneously.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String Array |

### Remove
If set to true, the script will remove the FullAccess permission. If false, it will grant the permission.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### AutoMapping
If set to true, Outlook will automatically map the delegated mailbox in the delegate's Outlook client. This option is only applicable when granting access (Remove = false).

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


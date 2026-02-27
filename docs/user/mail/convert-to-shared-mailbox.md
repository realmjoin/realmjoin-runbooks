# Convert To Shared Mailbox

Convert a user mailbox to a shared mailbox and back

## Detailed description
Converts a mailbox to a shared mailbox or reverts it back to a regular user mailbox. Optionally delegates access and adjusts group memberships and license groups.

## Where to find
User \ Mail \ Convert To Shared Mailbox

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### UserName
User principal name of the mailbox.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### delegateTo
User principal name of the delegate who should receive access.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Remove
If set to true, converts a shared mailbox back to a regular mailbox.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### AutoMapping
If set to true, enables automatic Outlook mapping for delegated FullAccess.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### RemoveGroups
If set to true, removes existing group memberships when converting to a shared mailbox.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ArchivalLicenseGroup
Display name of a license group to assign when an archive or larger mailbox requires it.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RegularLicenseGroup
Display name of a license group to assign when converting back to a regular mailbox.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


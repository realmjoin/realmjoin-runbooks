# Convert To Shared Mailbox

Convert this user's mailbox to a shared mailbox or back

## Detailed description
Turns the mailbox of this user into a shared mailbox, or turns a shared mailbox back into a regular user mailbox. When converting to shared, a delegate can get full access and the user's group memberships can be removed. A license group can be assigned when the mailbox needs an Exchange Online Plan 2.

## Where to find
User \ Mail \ Convert To Shared Mailbox

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp
- **Type**: Microsoft Graph
  - User.ReadWrite.All
  - Group.Read.All *(optional: Group and license handling)*
  - GroupMember.ReadWrite.All *(optional: Group and license handling)*

### RBAC roles
- Exchange Administrator


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### delegateTo
User who gets full access to the shared mailbox. Leave empty to grant no access.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Remove
Whether the shared mailbox is turned back into a regular mailbox. Set by the "Action" choice.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### AutoMapping
Makes the shared mailbox appear automatically in the delegate's Outlook.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### RemoveGroups
Takes the user out of all groups, including license groups, when converting to shared.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ArchivalLicenseGroup
Group that assigns an Exchange Online Plan 2 license, needed when the shared mailbox has an archive, is larger than 50 GB or is on litigation hold. Leave empty if not needed.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RegularLicenseGroup
Group that assigns the mailbox license when converting back to a regular mailbox. Leave empty to assign none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


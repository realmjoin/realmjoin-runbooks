# Add Mail Contact

Create a new Exchange Online mail contact with optional display name and address list settings

## Detailed description
This runbook creates a new Exchange Online mail contact (external contact) using the New-MailContact cmdlet. You can optionally set the contact's first name, last name, email alias, and control whether it appears in the Global Address List. All names default to the provided display name if not explicitly set.

## Where to find
Org \ Mail \ Add Mail Contact

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### ExternalEmailAddress
The external SMTP email address for the mail contact. This is the primary email address used for communication with the contact.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisplayName
The display name shown for the mail contact in Exchange Online and the Global Address List.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Name
The unique contact name used for management and identification. If left empty, defaults to the DisplayName value.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### FirstName
The first name of the contact. If not specified, the field is left empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LastName
The last name of the contact. If not specified, the field is left empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Alias
The mail nickname (alias) for the mail contact. If not specified, the system generates one automatically from the display name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### HideFromAddressLists
If set to true, the mail contact will be hidden from the Global Address List and other address lists. If false, the contact is visible to all users. Defaults to false.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


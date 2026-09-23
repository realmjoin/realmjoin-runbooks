# Add Mail Contact

Create a mail contact for an external address

## Detailed description
Creates a mail contact in Exchange Online for an external email address, so the person can be found in the address book and added to groups. First name, last name, contact name and alias are optional; the contact can be hidden from the address lists.

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
External address of the person. Mail to the contact is delivered there.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DisplayName
Name shown in the address book.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Name
Unique name used to manage the contact in Exchange Online. Leave empty to use the display name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### FirstName
First name of the person. Can stay empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LastName
Last name of the person. Can stay empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Alias
Mail alias of the contact. Leave empty to have Exchange derive one from the contact name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### HideFromAddressLists
Hides the contact from the global address list and the other address lists.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


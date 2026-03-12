# Add User

Create a new user account

## Detailed description
This runbook creates a new cloud user in Microsoft Entra ID and applies standard user properties.
It can optionally assign a license group, add the user to additional groups, and create an Exchange Online archive mailbox.

## Where to find
Org \ General \ Add User

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementManagedDevices.PrivilegedOperations.All

### RBAC roles
- User Administrator


## Parameters
### GivenName
First name of the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Surname
Last name of the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UserPrincipalName
User principal name (UPN). If empty, the runbook generates a UPN from the provided name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### MailNickname
Mail nickname (alias) used for the user. If empty, the runbook derives it from the UPN.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DisplayName
Display name of the user. If empty, the runbook derives it from the provided name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CompanyName
Company name of the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### JobTitle
Job title of the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Department
Department of the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ManagerId
Optional manager user ID to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### MobilePhone
Mobile phone number of the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LocationName
Office location name used for portal customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StreetAddress
Street address of the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### PostalCode
Postal code of the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### City
City of the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### State
State or region of the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Country
Country of the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### UsageLocation
Usage location used for licensing.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DefaultLicense
Optional license group to assign to the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DefaultGroups
Comma-separated list of groups to assign to the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### InitialPassword
Initial password. If empty, the runbook generates a random password.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EnableEXOArchive
If set to true, creates an Exchange Online archive mailbox for the user.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


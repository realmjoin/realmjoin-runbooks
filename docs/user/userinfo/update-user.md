# Update User

Update user metadata and memberships

## Detailed description
Updates user profile properties in Microsoft Entra ID and applies optional group memberships and Exchange Online settings. This runbook is typically used to finalize onboarding or to correct user metadata.

## Where to find
User \ Userinfo \ Update User

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - UserAuthenticationMethod.Read.All

### RBAC roles
- User administrator
- Exchange Administrator


## Parameters
### UserName
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### GivenName
Given name to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Surname
Surname to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DisplayName
Display name to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CompanyName
Company name to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### City
City to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Country
Country to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### JobTitle
Job title to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Department
Department to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### OfficeLocation
Office location to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### PostalCode
Postal code to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### PreferredLanguage
Preferred language to set for the user. Examples: "en-US" or "de-DE".

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### State
State to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StreetAddress
Street address to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### UsageLocation
Usage location to set for the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DefaultLicense
Display name of a license group to assign.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DefaultGroups
Comma-separated list of group display names to assign.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EnableEXOArchive
If set to true, enables the Exchange Online archive mailbox.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ResetPassword
If set to true, resets the user's password.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


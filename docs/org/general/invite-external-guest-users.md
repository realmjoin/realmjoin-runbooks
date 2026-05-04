# Invite External Guest Users

Invite external guest users to the organization

## Detailed description
This runbook invites an external user as a guest user in Microsoft Entra ID.
Optional profile properties such as given name, surname, company name, usage location, and manager can be set after the invitation is accepted.
The invited user can optionally be added to a specified group.

## Where to find
Org \ General \ Invite External Guest Users

## Notes
Common Use Cases:
- Basic guest invite: provide only the email address and display name; all profile and group parameters can be left blank
- Full onboarding: supply all optional fields to set profile properties, assign a manager, and add to a group in a single run

Parameter Interactions:
- Profile properties (givenName, surname, companyName, usageLocation) are applied only when non-empty; omitting them skips the PATCH call entirely
- Manager assignment and group membership each require their respective parameters; both are silently skipped when not provided

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.ReadWrite.All
  - Group.ReadWrite.All


## Parameters
### InvitedUserEmail
Email address of the guest user to invite.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### InvitedUserDisplayName
Display name of the guest user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupId
The object ID of the group to add the guest user to. If not specified, the user will not be added to any group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GivenName
Given name (first name) of the guest user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Surname
Surname (last name) of the guest user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CompanyName
Company name of the guest user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ManagerName
Manager to assign to the guest user. Select a user from the directory.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### UsageLocation
ISO 3166-1 alpha-2 country code for the usage location of the guest user (e.g. "US", "DE").

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


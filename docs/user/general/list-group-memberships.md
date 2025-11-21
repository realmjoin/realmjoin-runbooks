# List Group Memberships

List group memberships for this user.

## Detailed description
List group memberships for this user with filtering options for group type, membership type, role assignable status, Teams enabled status, and source.
The output is in CSV format with all group details including DisplayName, ID, Type, MembershipType, RoleAssignable, TeamsEnabled, and Source.

## Where to find
User \ General \ List Group Memberships

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Group.Read.All


## Parameters
### -UserName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -GroupType
Filter by group type: Security (security permissions only), M365 (Microsoft 365 groups with mailbox), or All (default).

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |

### -MembershipType
Filter by membership type: Assigned (manually added members), Dynamic (rule-based membership), or All (default).

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |

### -RoleAssignable
Filter groups that can be assigned to Azure AD roles: Yes (role-assignable only) or NotSet (all groups, default).

| Property | Value |
|----------|-------|
| Default Value | NotSet |
| Required | false |
| Type | String |

### -TeamsEnabled
Filter groups with Microsoft Teams functionality: Yes (Teams-enabled only) or NotSet (all groups, default).

| Property | Value |
|----------|-------|
| Default Value | NotSet |
| Required | false |
| Type | String |

### -Source
Filter by group origin: Cloud (Azure AD only), OnPrem (synchronized from on-premises AD), or All (default).

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |

### -WritebackEnabled
Filter groups with writeback to on-premises AD enabled: Yes (writeback enabled), No (writeback disabled), or All (default).

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


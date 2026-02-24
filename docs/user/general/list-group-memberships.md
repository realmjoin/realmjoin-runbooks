# List Group Memberships

List group memberships for this user

## Detailed description
Lists group memberships for this user and supports filtering by group type, membership type, role-assignable status, Teams enablement, source, and writeback status. Outputs the results as CSV-formatted text.

## Where to find
User \ General \ List Group Memberships

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Group.Read.All


## Parameters
### UserName
User principal name of the target user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### GroupType
Filter by group type: Security (security permissions only), M365 (Microsoft 365 groups with mailbox), or All (default).

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |

### MembershipType
Filter by membership type: Assigned (manually added members), Dynamic (rule-based membership), or All (default).

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |

### RoleAssignable
Filter groups that can be assigned to Azure AD roles: Yes (role-assignable only) or NotSet (all groups, default).

| Property | Value |
|----------|-------|
| Default Value | NotSet |
| Required | false |
| Type | String |

### TeamsEnabled
Filter groups with Microsoft Teams functionality: Yes (Teams-enabled only) or NotSet (all groups, default).

| Property | Value |
|----------|-------|
| Default Value | NotSet |
| Required | false |
| Type | String |

### Source
Filter by group origin: Cloud (Azure AD only), OnPrem (synchronized from on-premises AD), or All (default).

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |

### WritebackEnabled
Filter groups by writeback enablement.

| Property | Value |
|----------|-------|
| Default Value | All |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


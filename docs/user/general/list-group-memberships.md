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
Description: 
Default Value: 
Required: true

### -GroupType
Description: Filter by group type: Security (security permissions only), M365 (Microsoft 365 groups with mailbox), or All (default).
Default Value: All
Required: false

### -MembershipType
Description: Filter by membership type: Assigned (manually added members), Dynamic (rule-based membership), or All (default).
Default Value: All
Required: false

### -RoleAssignable
Description: Filter groups that can be assigned to Azure AD roles: Yes (role-assignable only) or NotSet (all groups, default).
Default Value: NotSet
Required: false

### -TeamsEnabled
Description: Filter groups with Microsoft Teams functionality: Yes (Teams-enabled only) or NotSet (all groups, default).
Default Value: NotSet
Required: false

### -Source
Description: Filter by group origin: Cloud (Azure AD only), OnPrem (synchronized from on-premises AD), or All (default).
Default Value: All
Required: false

### -WritebackEnabled
Description: Filter groups with writeback to on-premises AD enabled: Yes (writeback enabled), No (writeback disabled), or All (default).
Default Value: All
Required: false


[Back to Table of Content](../../../README.md)


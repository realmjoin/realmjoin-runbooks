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
  - Mail.Send
  - Organization.Read.All


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

### SendMail
If enabled, the report is sent via email as a CSV attachment. Toggling this on reveals the recipient address field.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Recipient address or multiple comma-separated addresses for the email report. Only used when SendMail is enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
The sender email address. This needs to be configured in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CreateDownloadLink
If enabled, the report CSV is uploaded to an Azure Storage Account and a time-limited download link is returned in the output.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container name used for the upload.

| Property | Value |
|----------|-------|
| Default Value | user-group-memberships |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group that contains the storage account.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account name used for the upload.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LinkExpiryDays
Number of days until the generated download link expires.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)


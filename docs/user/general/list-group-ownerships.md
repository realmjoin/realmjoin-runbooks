# List Group Ownerships

List group ownerships for this user.

## Detailed description
Lists Entra ID groups where the specified user is an owner. Outputs the group names and IDs.

## Where to find
User \ General \ List Group Ownerships

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
| Default Value | user-group-ownerandmemberships |
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


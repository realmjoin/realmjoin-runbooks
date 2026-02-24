# List Pim Rolegroups Without Owners (Scheduled)

List role-assignable groups with eligible role assignments but without owners

## Detailed description
Finds role-assignable groups that have PIM eligible role assignments but no owners assigned. Optionally sends an email alert containing the group names.

## Where to find
Org \ Security \ List Pim Rolegroups Without Owners_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Read.All
  - RoleManagement.Read.Directory
  - Mail.Send


## Parameters
### SendEmailIfFound
If set to true, sends an email when matching groups are found.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### From
Sender email address used to send the alert.

| Property | Value |
|----------|-------|
| Default Value | reports@contoso.com |
| Required | false |
| Type | String |

### To
Recipient email address for the alert.

| Property | Value |
|----------|-------|
| Default Value | support@glueckkanja-gab.com |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


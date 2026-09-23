# List Pim Rolegroups Without Owners (Scheduled)

Alert on PIM role groups that have no owner

## Detailed description
Finds role-assignable groups that hold eligible PIM role assignments but have no owner, so nobody is responsible for their membership. The group names are listed and can be sent by email. Nothing is changed.

## Where to find
Org \ Security \ List Pim Rolegroups Without Owners_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.Read.All
  - RoleManagement.Read.Directory
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All *(optional: Email report)*


## Parameters
### SendEmailIfFound
Sends an email with the group names when such groups are found.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### From
User in the tenant the alert is sent as; needs a mailbox.

| Property | Value |
|----------|-------|
| Default Value | reports@contoso.com |
| Required | false |
| Type | String |

### To
Gets the email with the group names.

| Property | Value |
|----------|-------|
| Default Value | support@glueckkanja-gab.com |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


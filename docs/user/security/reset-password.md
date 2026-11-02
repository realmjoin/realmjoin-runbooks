# Reset Password

Set a new password for this user

## Detailed description
Sets a new password for this user in Entra ID and shows it in the output. A disabled account can be enabled first, and the user can be made to choose their own password at the next sign-in.

## Where to find
User \ Security \ Reset Password

## Users with administrator roles

Entra ID protects users who hold an administrator role from changes by lower-privileged administrators. With the User Administrator role, the RealmJoin managed identity can reset the password and enable the account of users without administrator roles and of users with a few roles such as Helpdesk Administrator, Password Administrator, Groups Administrator or User Administrator.

For users with any other role, for example Power Platform Administrator, Exchange Administrator or Global Administrator, and for members and owners of role-assignable groups, Entra ID requires a Privileged Authentication Administrator or Global Administrator. The run then stops with "Insufficient privileges" and names the roles of the user. Reset the password of such a user in the Entra admin center with a Privileged Authentication Administrator or Global Administrator account.

Granting one of these two roles to the RealmJoin managed identity is not recommended, because both can also reset the credentials of Global Administrators. Microsoft lists which role can reset which administrator's password in [Who can reset passwords](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/privileged-roles-permissions#who-can-reset-passwords).

### Roles in the job output

Before anything changes, the job output lists the Entra ID roles assigned directly to the user. This needs the optional permission for the administrator role check; without it the output shows "could not be read" and the run continues.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - RoleManagement.Read.Directory *(optional: Administrator role check)*

### RBAC roles
- User Administrator


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### EnableUserIfNeeded
Enables a disabled account before the password is set.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### ForceChangePasswordNextSignIn
Makes the user choose their own password at the next sign-in.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


## Users with administrator roles

Entra ID protects users who hold an administrator role from changes by lower-privileged administrators. With the User Administrator role, the RealmJoin managed identity can block or restore sign-in and revoke sessions for users without administrator roles and for users with a few roles such as Helpdesk Administrator, Password Administrator, Groups Administrator or User Administrator.

For users with any other role, for example Power Platform Administrator, Exchange Administrator or Global Administrator, and for members and owners of role-assignable groups, Entra ID requires a Privileged Authentication Administrator or Global Administrator. The run then stops with "Insufficient privileges" and names the roles of the user. Make the change for such a user in the Entra admin center with a Privileged Authentication Administrator or Global Administrator account.

Granting one of these two roles to the RealmJoin managed identity is not recommended, because both can also reset the credentials of Global Administrators. Microsoft lists which role can change which administrator in [Who can perform sensitive actions](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/privileged-roles-permissions#who-can-perform-sensitive-actions).

### Roles in the job output

Before anything changes, the job output lists the Entra ID roles assigned directly to the user. This needs the optional permission for the administrator role check; without it the output shows "could not be read" and the run continues.

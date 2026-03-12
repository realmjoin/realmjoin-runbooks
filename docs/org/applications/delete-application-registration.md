# Delete Application Registration

Delete an application registration from Azure AD

## Detailed description
This runbook deletes an application registration and its associated service principal from Microsoft Entra ID.
It verifies that the application exists before deletion and performs a best-effort cleanup of groups assigned during provisioning.

## Where to find
Org \ Applications \ Delete Application Registration

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.ReadWrite.OwnedBy
  - Group.ReadWrite.All

### RBAC roles
- Application Developer


## Parameters
### ClientId
The application client ID (appId) of the application registration to delete.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


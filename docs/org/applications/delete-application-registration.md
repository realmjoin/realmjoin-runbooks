# Delete Application Registration

Delete an application registration and its service principal

## Detailed description
Deletes an application registration from Entra ID together with its service principal. Every group assigned to the application is deleted as well, including groups shared with other applications. Applications that still sign users in stop working immediately.

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
Client ID (appId) of the application registration to delete.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


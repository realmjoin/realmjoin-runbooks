# Delete Application Registration

Delete an application registration from Azure AD

## Detailed description
This script safely removes an application registration and its associated service principal from Azure Active Directory (Entra ID).

This script is the counterpart to the add-application-registration script and ensures
proper cleanup of all resources created during application registration.

## Where to find
Org \ Applications \ Delete Application Registration

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.ReadWrite.All
  - Group.ReadWrite.All


## Parameters
### ClientId

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


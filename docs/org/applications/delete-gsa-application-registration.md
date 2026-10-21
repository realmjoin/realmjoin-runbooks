# Delete GSA Application Registration

Delete a Global Secure Access application and its access group

## Detailed description
Deletes a Global Secure Access application that was created with the Add GSA Application Registration runbook. Its service principal, application segments, connector group assignment and the access group that follows the naming scheme go with it. Before deleting anything it checks that the application really is a GSA or App Proxy application. Other groups assigned to the application are only listed, unless you choose to delete them too.

## Where to find
Org \ Applications \ Delete GSA Application Registration

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.ReadWrite.All
  - Group.ReadWrite.All


## Parameters
### applicationName
Full display name of the application, for example GSA-MyApp.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### groupPrefix
Prefix of the access group's naming scheme, the same as in the add runbook. Usually preset in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value | App - Entra - GSA - |
| Required | false |
| Type | String |

### groupSuffix
Suffix of the access group's naming scheme, if one was used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### deleteAllAssignedGroups
Also deletes every other group assigned to the application. Careful, such groups may be shared with other applications.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


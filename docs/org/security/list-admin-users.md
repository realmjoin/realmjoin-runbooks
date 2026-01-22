# List Admin Users

List AzureAD role holders and their MFA state.

## Detailed description
Will list users and service principals that hold a builtin AzureAD role.
Admins will be queried for valid MFA methods.

## Where to find
Org \ Security \ List Admin Users

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Directory.Read.All
  - RoleManagement.Read.All


## Parameters
### exportToFile

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### pimEligibleUntilInCSV

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ResourceGroupName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountLocation

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountSku

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### QueryMfaState

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### TrustEmailMfa

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### TrustPhoneMfa

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### TrustSoftwareOathMfa

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### TrustWinHelloMFA

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


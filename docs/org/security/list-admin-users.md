# List Admin Users

List AzureAD role holders and their MFA state.

## Detailed description
Will list users and service principals that hold a builtin AzureAD role.
Admins will be queried for valid MFA methods.

## Where to find
Org \ Security \ List Admin Users

## Notes
Permissions: MS Graph
- User.Read.All
- Directory.Read.All
- RoleManagement.Read.All

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.Read.All
  - Directory.Read.All
  - RoleManagement.Read.All


## Parameters
### -exportToFile
Description: 
Default Value: True
Required: false

### -ContainerName
Description: 
Default Value: 
Required: false

### -ResourceGroupName
Description: 
Default Value: 
Required: false

### -StorageAccountName
Description: 
Default Value: 
Required: false

### -StorageAccountLocation
Description: 
Default Value: 
Required: false

### -StorageAccountSku
Description: 
Default Value: 
Required: false

### -QueryMfaState
Description: 
Default Value: True
Required: false

### -TrustEmailMfa
Description: 
Default Value: False
Required: false

### -TrustPhoneMfa
Description: 
Default Value: False
Required: false

### -TrustSoftwareOathMfa
Description: 
Default Value: True
Required: false

### -TrustWinHelloMFA
Description: 
Default Value: False
Required: false


[Back to Table of Content](../../../README.md)


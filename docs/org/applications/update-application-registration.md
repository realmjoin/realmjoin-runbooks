# Update Application Registration

## Update an application registration in Azure AD

## Description
This script modifies an existing application registration in Azure Active Directory (Entra ID) with comprehensive configuration updates.

The script intelligently determines what changes need to be applied by comparing current settings
with requested parameters, ensuring only necessary updates are performed. It maintains backward
compatibility while supporting modern authentication patterns and security requirements.

## Where to find
Org \ Applications \ Update Application Registration

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.ReadWrite.All
  - Organization.Read.All
  - Group.ReadWrite.All


## Parameters
### -ClientId
Description: 
Default Value: 
Required: true

### -RedirectURI
Description: 
Default Value: 
Required: false

### -webRedirectURI
Description: Only for UI used
Default Value: 
Required: false

### -publicClientRedirectURI
Description: 
Default Value: 
Required: false

### -spaRedirectURI
Description: 
Default Value: 
Required: false

### -EnableSAML
Description: 
Default Value: False
Required: false

### -SAMLReplyURL
Description: 
Default Value: 
Required: false

### -SAMLSignOnURL
Description: 
Default Value: 
Required: false

### -SAMLLogoutURL
Description: 
Default Value: 
Required: false

### -SAMLIdentifier
Description: 
Default Value: 
Required: false

### -SAMLRelayState
Description: 
Default Value: 
Required: false

### -SAMLExpiryNotificationEmail
Description: 
Default Value: 
Required: false

### -isApplicationVisible
Description: 
Default Value: True
Required: false

### -UserAssignmentRequired
Description: 
Default Value: False
Required: false

### -groupAssignmentPrefix
Description: 
Default Value: col - Entra - users -
Required: false

### -implicitGrantAccessTokens
Description: 
Default Value: False
Required: false

### -implicitGrantIDTokens
Description: 
Default Value: False
Required: false

### -disableImplicitGrant
Description: 
Default Value: False
Required: false


[Back to Table of Content](../../../README.md)


# Add Application Registration

Add an application registration to Azure AD

## Detailed description
This script creates a new application registration in Azure Active Directory (Entra ID) with comprehensive configuration options.

The script validates input parameters, prevents duplicate application creation, and provides comprehensive logging
throughout the process. For SAML applications, it automatically configures reply URLs, sign-on URLs, logout URLs,
and certificate expiry notifications.

## Where to find
Org \ Applications \ Add Application Registration

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.ReadWrite.All
  - Organization.Read.All
  - Group.ReadWrite.All


## Parameters
### -ApplicationName
Description: 
Default Value: 
Required: true

### -RedirectURI
Description: 
Default Value: 
Required: false

### -signInAudience
Description: Only for UI used
Default Value: AzureADMyOrg
Required: false

### -webRedirectURI
Description: 
Default Value: 
Required: false

### -spaRedirectURI
Description: 
Default Value: 
Required: false

### -publicClientRedirectURI
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

### -SAMLCertificateLifeYears
Description: 
Default Value: 3
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


[Back to Table of Content](../../../README.md)


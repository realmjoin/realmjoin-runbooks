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
Description: The display name of the application registration to create.
Default Value: 
Required: true

### -RedirectURI
Description: Used for UI selection only. Determines which redirect URI type to configure (None, Web, SAML, Public Client, or SPA).
Default Value: 
Required: false

### -signInAudience
Description: Specifies who can use the application. Default is "AzureADMyOrg" (single tenant). Hidden in UI.
Default Value: AzureADMyOrg
Required: false

### -webRedirectURI
Description: Redirect URI(s) for web applications. Supports multiple URIs separated by semicolons (e.g., "https://app1.com/auth;https://app2.com/auth").
Default Value: 
Required: false

### -spaRedirectURI
Description: Redirect URI(s) for single-page applications (SPA). Supports multiple URIs separated by semicolons.
Default Value: 
Required: false

### -publicClientRedirectURI
Description: Redirect URI(s) for public client/native applications (mobile & desktop). Supports multiple URIs separated by semicolons (e.g., "myapp://auth").
Default Value: 
Required: false

### -EnableSAML
Description: Enable SAML-based authentication for the application. When enabled, SAML-specific parameters are required.
Default Value: False
Required: false

### -SAMLReplyURL
Description: The reply URL for SAML authentication. Required when EnableSAML is true.
Default Value: 
Required: false

### -SAMLSignOnURL
Description: The sign-on URL for SAML authentication.
Default Value: 
Required: false

### -SAMLLogoutURL
Description: The logout URL for SAML authentication.
Default Value: 
Required: false

### -SAMLIdentifier
Description: The SAML identifier (Entity ID). If not specified, defaults to "urn:app:{AppId}".
Default Value: 
Required: false

### -SAMLRelayState
Description: The SAML relay state parameter for maintaining application state during authentication.
Default Value: 
Required: false

### -SAMLExpiryNotificationEmail
Description: Email address to receive notifications when the SAML token signing certificate is about to expire.
Default Value: 
Required: false

### -SAMLCertificateLifeYears
Description: Lifetime of the SAML token signing certificate in years. Default is 3 years.
Default Value: 3
Required: false

### -isApplicationVisible
Description: Determines whether the application is visible in the My Apps portal. Default is true.
Default Value: True
Required: false

### -UserAssignmentRequired
Description: Determines whether users must be assigned to the application before accessing it. When enabled, an EntraID group is created for user assignment. Default is false.
Default Value: False
Required: false

### -groupAssignmentPrefix
Description: Prefix for the automatically created EntraID group when UserAssignmentRequired is enabled. Default is "col - Entra - users - ".
Default Value: col - Entra - users -
Required: false

### -implicitGrantAccessTokens
Description: Enable implicit grant flow for access tokens. Default is false.
Default Value: False
Required: false

### -implicitGrantIDTokens
Description: Enable implicit grant flow for ID tokens. Default is false.
Default Value: False
Required: false


[Back to Table of Content](../../../README.md)


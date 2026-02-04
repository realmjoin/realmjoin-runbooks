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
  - Application.ReadWrite.OwnedBy
  - Organization.Read.All
  - Group.ReadWrite.All

### RBAC roles
- Application Developer


## Parameters
### ApplicationName
The display name of the application registration to create.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### RedirectURI
Used for UI selection only. Determines which redirect URI type to configure (None, Web, SAML, Public Client, or SPA).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### signInAudience
Specifies who can use the application. Default is "AzureADMyOrg" (single tenant). Hidden in UI.

| Property | Value |
|----------|-------|
| Default Value | AzureADMyOrg |
| Required | false |
| Type | String |

### webRedirectURI
Redirect URI(s) for web applications. Supports multiple URIs separated by semicolons (e.g., "https://app1.com/auth;https://app2.com/auth").

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### spaRedirectURI
Redirect URI(s) for single-page applications (SPA). Supports multiple URIs separated by semicolons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### publicClientRedirectURI
Redirect URI(s) for public client/native applications (mobile & desktop). Supports multiple URIs separated by semicolons (e.g., "myapp://auth").

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EnableSAML
Enable SAML-based authentication for the application. When enabled, SAML-specific parameters are required.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### SAMLReplyURL
The reply URL for SAML authentication. Required when EnableSAML is true.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLSignOnURL
The sign-on URL for SAML authentication.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLLogoutURL
The logout URL for SAML authentication.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLIdentifier
The SAML identifier (Entity ID). If not specified, defaults to "urn:app:{AppId}".

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLRelayState
The SAML relay state parameter for maintaining application state during authentication.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLExpiryNotificationEmail
Email address to receive notifications when the SAML token signing certificate is about to expire.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLCertificateLifeYears
Lifetime of the SAML token signing certificate in years. Default is 3 years.

| Property | Value |
|----------|-------|
| Default Value | 3 |
| Required | false |
| Type | Int32 |

### isApplicationVisible
Determines whether the application is visible in the My Apps portal. Default is true.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### UserAssignmentRequired
Determines whether users must be assigned to the application before accessing it. When enabled, an EntraID group is created for user assignment. Default is false.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### groupAssignmentPrefix
Prefix for the automatically created EntraID group when UserAssignmentRequired is enabled. Default is "col - Entra - users - ".

| Property | Value |
|----------|-------|
| Default Value | col - Entra - users - |
| Required | false |
| Type | String |

### implicitGrantAccessTokens
Enable implicit grant flow for access tokens. Default is false.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### implicitGrantIDTokens
Enable implicit grant flow for ID tokens. Default is false.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


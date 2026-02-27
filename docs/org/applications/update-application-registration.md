# Update Application Registration

Update an application registration in Azure AD

## Detailed description
This runbook updates an existing application registration and its related configuration in Microsoft Entra ID.
It compares the current settings with the requested parameters and applies only the necessary updates.
Use it to manage redirect URIs, SAML settings, visibility, assignment requirements, and token issuance behavior.

## Where to find
Org \ Applications \ Update Application Registration

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.ReadWrite.OwnedBy
  - Organization.Read.All
  - Group.ReadWrite.All

### RBAC roles
- Application Developer


## Parameters
### ClientId
The application client ID (appId) of the application registration to update.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### RedirectURI
Used for UI selection only. Determines which redirect URI type to configure.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### webRedirectURI
Redirect URI or URIs for web applications. Multiple values can be separated by semicolons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### publicClientRedirectURI
Redirect URI or URIs for public client/native applications. Multiple values can be separated by semicolons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### spaRedirectURI
Redirect URI or URIs for single-page applications. Multiple values can be separated by semicolons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EnableSAML
If set to true, SAML-based authentication is configured on the service principal.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### SAMLReplyURL
The SAML reply URL.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLSignOnURL
The SAML sign-on URL.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLLogoutURL
The SAML logout URL.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLIdentifier
The SAML identifier (Entity ID).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLRelayState
The SAML relay state parameter.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLExpiryNotificationEmail
Email address for SAML certificate expiry notifications.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### isApplicationVisible
Determines whether the application is visible in the My Apps portal.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### UserAssignmentRequired
Determines whether user assignment is required for the application.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### groupAssignmentPrefix
Prefix for the automatically created assignment group.

| Property | Value |
|----------|-------|
| Default Value | col - Entra - users - |
| Required | false |
| Type | String |

### implicitGrantAccessTokens
Enable implicit grant flow for access tokens.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### implicitGrantIDTokens
Enable implicit grant flow for ID tokens.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### disableImplicitGrant
If set to true, disables implicit grant issuance regardless of other settings.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


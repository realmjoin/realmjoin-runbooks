# Update Application Registration

Update redirect URIs, SAML and sign-in settings of an app registration

## Detailed description
Changes the configuration of an existing application registration in Entra ID: redirect URIs, SAML sign-in, visibility in My Apps, user assignment and implicit grant. Only settings that differ from the current ones are written. The application is selected by its client ID.

## Where to find
Org \ Applications \ Update Application Registration

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.ReadWrite.OwnedBy
  - Group.ReadWrite.All

### RBAC roles
- Application Developer


## Parameters
### ClientId
Client ID (appId) of the application registration to update.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### RedirectURI
Type of sign-in to set up: none, a web redirect URI, SAML, a public client (mobile and desktop) or a single-page application. The matching fields appear once you choose.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### webRedirectURI
Redirect URI of a web application, for example https://myapp.com/auth. Separate several with semicolons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### publicClientRedirectURI
Redirect URI of a mobile or desktop client, for example myapp://auth. Separate several with semicolons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### spaRedirectURI
Redirect URI of a single-page application, for example https://myapp.com. Separate several with semicolons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EnableSAML
Whether SAML sign-in is configured. Set by the "Redirect URI" choice.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### SAMLReplyURL
Where the SAML response is sent (assertion consumer service URL).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLSignOnURL
URL where users start the sign-in to the application.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLLogoutURL
URL the application uses to sign users out.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLIdentifier
Identifier of the application in SAML (entity ID).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLRelayState
Value the application receives back after sign-in, for example to return to a page.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLExpiryNotificationEmail
Email address that is notified before the SAML signing certificate expires.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### isApplicationVisible
Lists the application in the users' My Apps portal.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### UserAssignmentRequired
Only assigned users can use the application. An access group is created for the assignment.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### groupAssignmentPrefix
Text put in front of the access group name. Only used when user assignment is required.

| Property | Value |
|----------|-------|
| Default Value | col - Entra - users - |
| Required | false |
| Type | String |

### implicitGrantAccessTokens
Lets the application receive access tokens through the implicit flow. Needed only for older single-page apps.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### implicitGrantIDTokens
Lets the application receive ID tokens through the implicit flow.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### disableImplicitGrant
Switches implicit grant off for both token types, regardless of "Implicit grant for access tokens?" and "Implicit grant for ID tokens?".

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


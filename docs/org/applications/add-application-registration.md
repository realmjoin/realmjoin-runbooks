# Add Application Registration

Create an application registration in Entra ID

## Detailed description
Creates a new application registration in Entra ID. Optionally it also configures redirect URIs for web, SPA or public clients, SAML sign-in, visibility in My Apps, user assignment with an access group, and implicit grant. Duplicate names are refused and the inputs are checked before anything is created.

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
Display name of the new application registration.

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

### signInAudience
Who may sign in to the application. Preset to accounts in this tenant only (AzureADMyOrg).

| Property | Value |
|----------|-------|
| Default Value | AzureADMyOrg |
| Required | false |
| Type | String |

### webRedirectURI
Redirect URI of a web application, for example https://myapp.com/auth. Separate several with semicolons.

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

### publicClientRedirectURI
Redirect URI of a mobile or desktop client, for example myapp://auth. Separate several with semicolons.

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
Identifier of the application in SAML (entity ID). Leave empty to use urn:app: followed by the client ID.

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

### SAMLCertificateLifeYears
How many years the SAML signing certificate stays valid.

| Property | Value |
|----------|-------|
| Default Value | 3 |
| Required | false |
| Type | Int32 |

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


[Back to Table of Content](../../../README.md)


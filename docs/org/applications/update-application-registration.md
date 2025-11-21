# Update Application Registration

Update an application registration in Azure AD

## Detailed description
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
### ClientId

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### RedirectURI

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### webRedirectURI
Only for UI used

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### publicClientRedirectURI

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### spaRedirectURI

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EnableSAML

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### SAMLReplyURL

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLSignOnURL

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLLogoutURL

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLIdentifier

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLRelayState

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SAMLExpiryNotificationEmail

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### isApplicationVisible

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### UserAssignmentRequired

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### groupAssignmentPrefix

| Property | Value |
|----------|-------|
| Default Value | col - Entra - users - |
| Required | false |
| Type | String |

### implicitGrantAccessTokens

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### implicitGrantIDTokens

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### disableImplicitGrant

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


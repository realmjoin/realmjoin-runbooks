# Add Or Remove Trusted Site

Add a URL to the Intune trusted sites list or remove it

## Detailed description
Adds a URL to the site-to-zone assignment list of a Windows configuration policy in Intune, or removes it again. That list puts a URL into an Internet Explorer security zone such as Trusted sites. It can also list all trusted sites policies with their entries.

## Where to find
Org \ General \ Add Or Remove Trusted Site

## Implementation notes

The runbook decrypts the `omaSettings` of the custom configuration policy using the approach described in [this call4cloud article](https://call4cloud.nl/2021/09/the-isencrypted-with-steve-zissou/). This currently requires the Microsoft Graph beta endpoint.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.ReadWrite.All


## Parameters
### Action
Add puts the URL into the policy, Remove takes it out, List shows the policies and their entries.

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | true |
| Type | Int32 |

### Url
Address to add or remove, starting with http:// or https://.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Zone
Security zone the URL is assigned to: My computer (0), Local intranet (1), Trusted sites (2), Internet (3) or Restricted sites (4).

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |

### DefaultPolicyName
Policy used when several trusted sites policies exist and none is named.

| Property | Value |
|----------|-------|
| Default Value | Windows 10 - Trusted Sites |
| Required | false |
| Type | String |

### IntunePolicyName
Policy to change. Leave empty to pick one automatically.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


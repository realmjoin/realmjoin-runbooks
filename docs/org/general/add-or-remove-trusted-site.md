# Add Or Remove Trusted Site

Add or remove a URL entry in the Intune Trusted Sites policy

## Detailed description
Adds or removes a URL to the Site-to-Zone Assignment List in a Windows custom configuration policy. The runbook can also list all existing Trusted Sites policies and their mappings.

## Where to find
Org \ General \ Add Or Remove Trusted Site

## Notes
This runbook uses calls as described in https://call4cloud.nl/2021/09/the-isencrypted-with-steve-zissou/ to decrypt omaSettings. It currently needs to use the Microsoft Graph beta endpoint for this.

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.ReadWrite.All


## Parameters
### Action
Action to execute: add, remove, or list policies.

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | true |
| Type | Int32 |

### Url
URL to add or remove; it must be prefixed with "http://" or "https://".

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Zone
Internet Explorer zone id to assign the URL to.

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |

### DefaultPolicyName
Default policy name used when multiple Trusted Sites policies exist and no specific policy name is provided.

| Property | Value |
|----------|-------|
| Default Value | Windows 10 - Trusted Sites |
| Required | false |
| Type | String |

### IntunePolicyName
Optional policy name; if provided, the runbook targets this policy instead of auto-selecting one.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


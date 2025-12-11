# Add Or Remove Trusted Site

Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy

## Detailed description
Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy

## Where to find
Org \ General \ Add Or Remove Trusted Site

## Notes
This runbook uses calls as described in
https://call4cloud.nl/2021/09/the-isencrypted-with-steve-zissou/
to decrypt omaSettings. It currently needs to use the MS Graph Beta Endpoint for this.
Please switch to "v1.0" as soon, as this funtionality is available.

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.ReadWrite.All


## Parameters
### Action

| Property | Value |
|----------|-------|
| Default Value | 2 |
| Required | true |
| Type | Int32 |

### Url
Needs to be prefixed with "http://" or "https://"

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Zone

| Property | Value |
|----------|-------|
| Default Value | 1 |
| Required | false |
| Type | Int32 |

### DefaultPolicyName

| Property | Value |
|----------|-------|
| Default Value | Windows 10 - Trusted Sites |
| Required | false |
| Type | String |

### IntunePolicyName
Will use an existing policy or default policy name if left empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


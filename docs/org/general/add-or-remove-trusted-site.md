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
### -Action
Description: 
Default Value: 2
Required: true

### -Url
Description: Needs to be prefixed with "http://" or "https://"
Default Value: 
Required: false

### -Zone
Description: 
Default Value: 1
Required: false

### -DefaultPolicyName
Description: 
Default Value: Windows 10 - Trusted Sites
Required: false

### -IntunePolicyName
Description: Will use an existing policy or default policy name if left empty.
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)


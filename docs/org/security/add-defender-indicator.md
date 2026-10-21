# Add Defender Indicator

Add an allow or block indicator to Defender for Endpoint

## Detailed description
Creates a custom indicator in Microsoft Defender for Endpoint that allows, warns about, audits or blocks a file hash, certificate thumbprint, IP address, domain or URL on all onboarded devices. An alert can be raised whenever the indicator matches.

## Where to find
Org \ Security \ Add Defender Indicator

## Permissions
### Application permissions
- **Type**: WindowsDefenderATP
  - Ti.ReadWrite.All


## Parameters
### IndicatorValue
The hash, thumbprint, IP address, domain name or URL the indicator applies to. Must match the indicator type.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### IndicatorType
File hash (SHA-256, SHA-1 or MD5), certificate thumbprint, IP address, domain name or URL. The value must be of this type.

| Property | Value |
|----------|-------|
| Default Value | FileSha256 |
| Required | true |
| Type | String |

### Title
Short name shown for the indicator in the Defender portal.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Description
Why the indicator exists. Shown in the Defender portal and in alerts.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Action
What Defender does on a match: Allow, Warn, Audit, Block, Block and remediate, or Alert and block.

| Property | Value |
|----------|-------|
| Default Value | Allowed |
| Required | true |
| Type | String |

### Severity
Severity of the alerts raised for this indicator.

| Property | Value |
|----------|-------|
| Default Value | Informational |
| Required | true |
| Type | String |

### GenerateAlert
Raises an alert in the Defender portal each time the indicator matches.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


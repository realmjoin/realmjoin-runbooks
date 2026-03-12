# Add Defender Indicator

Create a new Microsoft Defender for Endpoint indicator

## Detailed description
Creates a new indicator in Microsoft Defender for Endpoint to allow or block a specific file hash, certificate thumbprint, IP, domain, or URL. The indicator action can generate alerts automatically for audit or alert-and-block actions.

## Where to find
Org \ Security \ Add Defender Indicator

## Permissions
### Application permissions
- **Type**: WindowsDefenderATP
  - Ti.ReadWrite.All


## Parameters
### IndicatorValue
Value of the indicator, such as a hash, thumbprint, IP address, domain name, or URL.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### IndicatorType
Type of the indicator value.

| Property | Value |
|----------|-------|
| Default Value | FileSha256 |
| Required | true |
| Type | String |

### Title
Title of the indicator entry.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Description
Description of the indicator entry.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Action
Action applied to the indicator.

| Property | Value |
|----------|-------|
| Default Value | Allowed |
| Required | true |
| Type | String |

### Severity
Severity used for the indicator.

| Property | Value |
|----------|-------|
| Default Value | Informational |
| Required | true |
| Type | String |

### GenerateAlert
If set to true, an alert is generated when the indicator matches.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


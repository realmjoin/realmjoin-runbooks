# Add Defender Indicator

Create new Indicator in Defender for Endpoint.

## Detailed description
Create a new Indicator in Defender for Endpoint e.g. to allow a specific file using it's hash value or allow a specific url that by default is blocked by Defender for Endpoint

## Where to find
Org \ Security \ Add Defender Indicator

## Permissions
### Application permissions
- **Type**: WindowsDefenderATP
  - Ti.ReadWrite.All


## Parameters
### -IndicatorValue

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -IndicatorType

| Property | Value |
|----------|-------|
| Default Value | FileSha256 |
| Required | true |
| Type | String |

### -Title

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -Description

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -Action

| Property | Value |
|----------|-------|
| Default Value | Allowed |
| Required | true |
| Type | String |

### -Severity

| Property | Value |
|----------|-------|
| Default Value | Informational |
| Required | true |
| Type | String |

### -GenerateAlert

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


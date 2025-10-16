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
Description: 
Default Value: 
Required: true

### -IndicatorType
Description: 
Default Value: FileSha256
Required: true

### -Title
Description: 
Default Value: 
Required: true

### -Description
Description: 
Default Value: 
Required: true

### -Action
Description: 
Default Value: Allowed
Required: true

### -Severity
Description: 
Default Value: Informational
Required: true

### -GenerateAlert
Description: 
Default Value: False
Required: true


[Back to Table of Content](../../../README.md)


# Add Or Remove Smartscreen Exclusion

## Add/Remove a SmartScreen URL Exception/Rule in MS Security Center Indicators

## Description
List/Add/Remove URL indicators entries in MS Security Center.

## Where to find
Org \ General \ Add Or Remove Smartscreen Exclusion

## Permissions
### Application permissions
- **Type**: WindowsDefenderATP
  - Ti.ReadWrite.All


## Parameters
### -action
Description: 0 - list, 1 - add, 2 - remove
Default Value: 0
Required: false

### -Url
Description: please give just the name of the domain, like "exclusiondemo.com"
Default Value: 
Required: false

### -mode
Description: 0 - allow, 1 - audit, 2 - warn, 3 - block
Default Value: 0
Required: false

### -explanationTitle
Description: 
Default Value: Allow this domain in SmartScreen
Required: false

### -explanationDescription
Description: 
Default Value: Required exclusion. Please provide more details.
Required: false


[Back to Table of Content](../../../README.md)


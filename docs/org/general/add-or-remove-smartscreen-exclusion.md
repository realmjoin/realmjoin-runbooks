# Add Or Remove Smartscreen Exclusion

Add/Remove a SmartScreen URL Exception/Rule in MS Security Center Indicators

## Detailed description
List/Add/Remove URL indicators entries in MS Security Center.

## Where to find
Org \ General \ Add Or Remove Smartscreen Exclusion

## Permissions
### Application permissions
- **Type**: WindowsDefenderATP
  - Ti.ReadWrite.All


## Parameters
### action
0 - list, 1 - add, 2 - remove

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### Url
please give just the name of the domain, like "exclusiondemo.com"

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### mode
0 - allow, 1 - audit, 2 - warn, 3 - block

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### explanationTitle

| Property | Value |
|----------|-------|
| Default Value | Allow this domain in SmartScreen |
| Required | false |
| Type | String |

### explanationDescription

| Property | Value |
|----------|-------|
| Default Value | Required exclusion. Please provide more details. |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


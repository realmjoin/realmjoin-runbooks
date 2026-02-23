# Add Or Remove Smartscreen Exclusion

Add or remove a SmartScreen URL indicator in Microsoft Defender

## Detailed description
This runbook lists, adds, or removes URL indicators in Microsoft Defender.
It can allow, audit, warn, or block a given domain by creating an indicator entry.

## Where to find
Org \ General \ Add Or Remove Smartscreen Exclusion

## Permissions
### Application permissions
- **Type**: WindowsDefenderATP
  - Ti.ReadWrite.All


## Parameters
### action
"List all URL indicators", "Add an URL indicator" or "Remove all indicator for this URL" could be selected as action to perform.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### Url
Domain name to manage, for example "exclusiondemo.com".

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### mode
Indicator mode to apply.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### explanationTitle
Title used when creating an indicator.

| Property | Value |
|----------|-------|
| Default Value | Allow this domain in SmartScreen |
| Required | false |
| Type | String |

### explanationDescription
Description used when creating an indicator.

| Property | Value |
|----------|-------|
| Default Value | Required exclusion. Please provide more details. |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


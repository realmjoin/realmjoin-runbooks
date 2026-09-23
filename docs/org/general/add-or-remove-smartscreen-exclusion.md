# Add Or Remove Smartscreen Exclusion

Allow, warn or block a URL in Defender SmartScreen

## Detailed description
Manages URL indicators in Microsoft Defender for Endpoint, which SmartScreen uses to allow, audit, warn about or block a domain. Lists the existing indicators, adds one for a domain, or removes all indicators for it.

## Where to find
Org \ General \ Add Or Remove Smartscreen Exclusion

## Permissions
### Application permissions
- **Type**: WindowsDefenderATP
  - Ti.ReadWrite.All


## Parameters
### action
List shows all URL indicators, Add creates one for the domain, Remove deletes every indicator for it.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### Url
Domain to manage, for example exclusiondemo.com.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### mode
What SmartScreen does with the domain: allow it, only audit access, warn the user, or block it.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### explanationTitle
Short title stored with the indicator.

| Property | Value |
|----------|-------|
| Default Value | Allow this domain in SmartScreen |
| Required | false |
| Type | String |

### explanationDescription
Reason stored with the indicator, for example who requested the exclusion.

| Property | Value |
|----------|-------|
| Default Value | Required exclusion. Please provide more details. |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


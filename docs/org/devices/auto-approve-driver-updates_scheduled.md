# Auto Approve Driver Updates (Scheduled)

Auto-approve new driver updates in Intune driver update policies

## Detailed description
This scheduled runbook automatically approves pending driver updates in one or more Intune driver update policies. It can filter driver updates by display name pattern, driver class, or manufacturer. Optional email notifications can be sent after approval operations complete.

## Where to find
Org \ Devices \ Auto Approve Driver Updates_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.


## Notes
Prerequisites:
- Microsoft Graph BETA API access (driver update endpoints are in beta)
- RJReport.EmailSender setting configured (if email notifications are used)

Common Use Cases:
- Test filters first: Use WhatIf parameter to preview which drivers would be approved
- Auto-approve all drivers: Run without any filter parameters
- Approve specific manufacturers: Use DriverManufacturer to target vendors like "Intel" or "AMD"
- Target specific policies: Use PolicyNames or PolicyIds to scope to test policies first
- Monitor approvals: Configure EmailTo to receive detailed reports after each run

Parameter Interactions:
- If no policy filter is specified, ALL driver update policies are processed
- If no driver filter is specified, ALL pending drivers in selected policies are approved
- PolicyNames and PolicyIds can be combined - both filters apply independently
- Email notifications require RJReport.EmailSender setting and Connect-RjRbGraph
- WhatIf mode simulates approvals without making changes - useful for testing filters

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.ReadWrite.All
  - Mail.Send
  - Organization.Read.All


## Parameters
### PolicyNames
(Optional) Comma-separated list of driver update policy names to scope the approval (e.g., "Policy1, Policy2, Policy3"). If not specified, all policies are processed.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### PolicyIds
(Optional) Comma-separated list of driver update policy IDs to scope the approval (e.g., "id1, id2, id3"). If not specified, all policies are processed.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DriverDisplayNamePattern
(Optional) Filter driver updates by display name pattern (supports wildcards). Only matching drivers will be approved.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DriverClass
(Optional) Filter by driver class IDs (comma-separated). Example: "Bluetooth,Networking,Firmware" for specific driver classes.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DriverManufacturer
(Optional) Filter by driver manufacturer name. Only drivers from the specified manufacturer will be approved.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### MaximumDriverAge
(Optional) Maximum age in days for drivers to be approved. Only drivers released within the last X days will be approved. Example: 30 to only approve drivers released in the last 30 days.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |

### OnlyNeedsReview
When enabled (default), only drivers with status "needsReview" are approved. Drivers with status "suspended" or "declined" are skipped. Disable to also re-approve suspended or declined drivers.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### WhatIf
(Optional) When enabled, simulates driver approvals without making actual changes. Shows which drivers would be approved and sends a report to EmailTo if configured.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | SwitchParameter |

### EmailFrom
Sender email address for notifications. This parameter is backed by a setting and should not be modified directly.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailTo
(Optional) Recipient email address for approval notifications. If not specified, no email is sent.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


# Report Stale Devices (Scheduled)

Scheduled report of stale devices based on last activity date and platform.

## Detailed description
Identifies and lists devices that haven't been active for a specified number of days.
Automatically sends a report via email.

## Where to find
Org \ Devices \ Report Stale Devices_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.


## Notes
This runbook generates a comprehensive report of stale devices and delivers it via email.
The report includes device details, platform breakdowns, and exports a CSV file for further analysis.

Prerequisites:
- EmailFrom parameter must be configured in runbook customization (RJReport.EmailSender setting)

Common Use Cases:
- Regular device inventory audits and compliance reporting
- Identifying devices for retirement or decommissioning
- Security reviews to find potentially lost devices
- Monitoring device health across the organization
- Using MaxDays parameter for staged reporting (e.g., 30-60 days, 60-90 days)
- User scope filtering to focus on specific departments or exclude service accounts

The runbook supports optional user scope filtering to include or exclude devices based on primary user group membership.

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All
  - Device.Read.All
  - Mail.Send


## Parameters
### Days
Number of days without activity to be considered stale.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### MaxDays
Optional maximum number of days without activity. If set, only devices inactive between Days and MaxDays will be included.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | Int32 |

### Windows
Include Windows devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### MacOS
Include macOS devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### iOS
Include iOS devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### Android
Include Android devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### EmailFrom
The sender email address. This needs to be configured in the runbook customization

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### UseUserScope
Enable user scope filtering to include or exclude devices based on primary user group membership.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeUserGroup
Only include devices whose primary users are members of this group. Requires UseUserScope to be enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ExcludeUserGroup
Exclude devices whose primary users are members of this group. Requires UseUserScope to be enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailTo
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


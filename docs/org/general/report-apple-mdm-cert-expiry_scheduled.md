# Report Apple MDM Cert Expiry (Scheduled)

Monitor/Report expiry of Apple device management certificates.

## Detailed description
Monitors expiration dates of Apple Push certificates, VPP tokens, and DEP tokens in Microsoft Intune.
Sends an email report with alerts for certificates/tokens expiring within the specified threshold.

## Where to find
Org \ General \ Report Apple MDM Cert Expiry_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementServiceConfig.Read.All
  - DeviceManagementConfiguration.Read.All
  - Mail.Send


## Parameters
### -Days
The warning threshold in days. Certificates and tokens expiring within this many days will be
flagged as alerts in the report. Default is 300 days (approximately 10 months).

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### -EmailTo
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -EmailFrom
The sender email address. This needs to be configured in the runbook customization

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


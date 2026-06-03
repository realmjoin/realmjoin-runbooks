# Report Primary User Mismatch (Scheduled)

Compare primary user assignments in Intune against RealmJoin for Windows managed devices

## Detailed description
For Windows managed devices, this scheduled report compares the primary user recorded in Intune against the primary user recorded in the RealmJoin customer API. It correlates the two datasets per device, flags any device where the primary user differs, and emails the differences with a CSV attachment.

## Where to find
Org \ Devices \ Report Primary User Mismatch_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.

## Setup regarding RealmJoin API credentials

This runbook queries the RealmJoin customer API and requires a dedicated credential stored in the Azure Automation Account.

**Step-by-step setup:**

1. **Get API credentials** — If you do not yet have RealmJoin API credentials, request them at support@realmjoin.com
2. **Open the Automation Account** — In the Azure portal, navigate to the Automation Account used for runbooks
3. **Go to Shared Resources > Credentials** — In the left menu under *Shared Resources*, click *Credentials*
4. **Add a new credential** — Click *Add a credential*
5. **Name it exactly `RJAPI`** — The runbook looks up this name; any deviation will cause the credential lookup to fail
6. **Enter the RealmJoin API username and password** — Use the credentials from step 1
7. **Save** — Click *Create* and re-run the runbook


## Notes
Prerequisites:
- An Azure Automation Account shared credential named exactly "RJAPI" must be created manually
  before scheduling. Set the username and password to match a RealmJoin customer API account
  (see https://docs.realmjoin.com/dev-reference/realmjoin-api/authentication).
- The Automation Account managed identity must have the following Graph application permissions
  assigned: DeviceManagementManagedDevices.Read.All, Mail.Send, Organization.Read.All.
- The RJReport.EmailSender setting must be configured with a valid sender address before the first run.
- No email is sent when the two datasets are in sync; an empty run is not an error.

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Mail.Send
  - Organization.Read.All


## Parameters
### SyncThresholdDays
Number of days to look back for the Intune last-sync filter. Only Windows devices that have synced within this many days are evaluated.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### DeviceNamePrefix
Optional device name prefix to filter the report to a specific subset of devices. Leave blank to include all devices.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### IncludeMismatches
Include devices whose primary user differs between Intune and RealmJoin in the report. Enabled by default.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeMissingInRealmJoin
Include devices that exist in Intune but have no matching device in RealmJoin in the report. Disabled by default.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeMissingInIntune
Include devices that exist in RealmJoin but have no matching Intune device in the report. Disabled by default.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Recipient email address (or multiple comma-separated addresses) that should receive the report.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### EmailFrom
The sender email address. This is configured via the runbook customization setting and hidden in the portal.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


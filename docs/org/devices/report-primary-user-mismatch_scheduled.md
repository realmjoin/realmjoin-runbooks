# Report Primary User Mismatch (Scheduled)

Compare primary users and logons between Intune and RealmJoin

## Detailed description
Compares, for Windows devices, the primary user recorded in Intune with the one recorded in RealmJoin and lists every device where they differ. It also checks who actually logs on to each device, using the logons Intune and the RealmJoin agent recorded, and lists devices whose primary user no longer does. Which categories are listed is set in the runbook customization. Only devices that synced with Intune recently are considered. The report can be sent by email or provided as a download link.

## Where to find
Org \ Devices \ Report Primary User Mismatch_Scheduled

## How it works

The runbook reads two lists and matches them by the Entra device ID (with the Intune device ID as fallback):

- **Intune**: all Windows devices that completed a sync within the last *Intune last sync within (days)*, with their primary user and the logons Intune recorded on the device. Devices that stopped syncing with Intune are left out on purpose; they belong in the **Report Stale Devices (Scheduled)** runbook.
- **RealmJoin**: the device list of the RealmJoin customer API. For every device it carries the users the RealmJoin agent has reported as signed in, each with a *last seen* timestamp, and which of them RealmJoin treats as the primary user.

For every device the runbook answers two questions: do the primary users agree, and does the primary user still log on? Each answer is a category; a device can be in several. Whether the RealmJoin agent itself still reports is a different question and answered by the **Report RealmJoin Agent Contact (Scheduled)** runbook.

## Categories

| Category | Meaning |
| --- | --- |
| `Mismatch` | The Intune primary user and the RealmJoin primary user differ. |
| `PrimaryUserDeleted` | The Intune primary user was deleted from Entra ID. Intune then writes the user's object id in front of the user principal name; the runbook recognizes this and does not count it as a mismatch. |
| `PrimaryUserNotLoggingOn` | Someone else logged on to the device, and the primary user did not within *Primary user must have logged on within (days)*. The device is probably used by a different person than the one recorded. |
| `MissingInRealmJoin` | The device exists in Intune but RealmJoin does not know it, or knows it without a primary user. |
| `MissingInIntune` | RealmJoin knows the device but it did not sync with Intune within the sync window. |

Which categories are listed is set in the runbook customization; by default only `Mismatch` is on. Every category has its own table in the Output Data tab of the run, with the columns that explain the finding. The report files hold one row per device in the enabled categories with all columns, including a `Findings` column that names every category the device is in.

### Where the logons come from

Two sources are combined:

- **Intune** records the most recent logons on a device with the user's object id and a timestamp. The runbook resolves the ids to user principal names; a user that no longer exists is shown as deleted.
- **The RealmJoin agent** runs in the context of the signed-in user and reports to RealmJoin every 15 minutes while someone is signed in. Every report updates the *last seen* of that user on that device, so the RealmJoin users of a device are the people the agent saw signed in, each with their last time.

The primary user counts as logging on when either source saw them within the logon window. `PrimaryUserNotLoggingOn` needs both: someone else was seen, and the primary user was not within the window. A device on which nobody was seen at all is shown as `Unknown` in the `PrimaryUserLogon` column and is never counted as not logging on.

Shared devices where several people log on by design produce this finding for their primary user; exclude them with *Exclude devices from group*.

### Device scope

*Include devices from group* limits the comparison to the devices in that Entra ID group, *Exclude devices from group* skips the devices of a group. Both are optional and can be combined; a filter applies as soon as its group is selected.

## Enabling categories

The category switches are hidden in the portal and set in the runbook customization, so a schedule always reports the same set. A customization that enables the logon check in addition to the mismatches:

```json
"rjgit-org_devices_report-primary-user-mismatch_scheduled": {
    "parameters": {
        "IncludeMismatches": {
            "Default": true
        },
        "IncludePrimaryUserDeleted": {
            "Default": true
        },
        "IncludePrimaryUserNotLoggingOn": {
            "Default": true
        },
        "PrimaryUserLogonDays": {
            "Default": 30
        }
    }
}
```

See the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization) for the syntax.

## Report delivery

Report files are only generated when a delivery method is selected via the **Report delivery** option (email and/or download link). With *Output Data only* selected, the results are read directly in the Output Data tab of the RealmJoin portal, where each table can also be exported to Excel. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

Schedules that were created before the **Report delivery** option existed keep sending their email: a stored recipient alone still enables the email for them. When such a schedule is opened for editing, the option shows *Output Data only*; select the delivery again before saving, otherwise the schedule stops sending the report.

## Result without findings

No email is sent and no file is created when no device falls into an enabled category. A run without findings completes normally and is not an error; the Output Data tab still shows the summary.

## Setup regarding RealmJoin API credentials

The runbook queries the RealmJoin customer API and needs a dedicated credential stored in the Azure Automation Account. The same credential serves every runbook that uses the API, so this is a one-time setup per Automation Account.

1. **Get API credentials** - If you do not yet have RealmJoin API credentials, request them at support@realmjoin.com. The username has the form `t-<tenant id>`, the password is the API secret. A portal login does not work here.
2. **Ask for the device users feature** - The device list of the customer API is a feature RealmJoin enables per tenant. Ask support to enable it together with the credentials; without it the API answers with HTTP 403 and the runbook stops with that message.
3. **Open the Automation Account** - In the Azure portal, open the Automation Account used for runbooks.
4. **Go to Shared Resources > Credentials** - In the left menu under *Shared Resources*, click *Credentials*.
5. **Add a new credential** - Click *Add a credential*.
6. **Name it exactly `RJAPI`** - The runbook looks up this name; any other name fails the credential lookup.
7. **Enter the API username and secret** - Use the values from step 1.
8. **Save** - Click *Create* and run the runbook again.

The API allows 30 requests per minute per tenant and answers with HTTP 429 beyond that. The runbook needs one request per run and repeats a throttled request after a short delay, up to five times, before it gives up.

## Setup regarding email sending

Sending an email report is optional and only happens when the *Email report* delivery option is selected; a recipient (`EmailTo`) is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings).

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** - public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** - target of the footer image
- **Accent and text color** - 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email - the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## Notes and limitations

- Only Windows devices are compared: the RealmJoin agent runs on Windows, so RealmJoin has no primary user or logon data for other platforms.
- The report is a snapshot per run. It does not keep the previous run and therefore does not report that a primary user *changed* between two runs; compare two report files for that.
- The logons Intune records cover the most recent logons only, and the RealmJoin agent only sees users who were signed in while it ran. A user who logs on rarely can therefore show up as not logging on.
- The primary user shown for RealmJoin is the one RealmJoin determined from the agent reports; it is not the Entra ID registered owner of the device.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All *(optional: Email report)*

### Permission notes
RealmJoin customer API: an Automation Account credential named 'RJAPI' with the tenant's API username (t-<tenant id>) and secret, issued by RealmJoin support
RealmJoin customer API: the device users feature of the API has to be enabled for the tenant by RealmJoin support (the device list answers with HTTP 403 otherwise)


## Parameters
### SyncThresholdDays
Only devices that synced with Intune within this many days are compared. Devices that stopped syncing altogether belong in the stale device report instead.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### DeviceNamePrefix
Only devices whose name starts with this text. Leave empty for all.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### PrimaryUserLogonDays
The primary user counts as not logging on when someone else logged on to the device and the primary user did not within this many days.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### IncludeMismatches
Lists devices whose primary user differs between Intune and RealmJoin.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeMissingInRealmJoin
Lists devices that exist in Intune but not in RealmJoin, or that RealmJoin knows without a primary user.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeMissingInIntune
Lists devices that exist in RealmJoin but did not sync with Intune within the sync window.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludePrimaryUserDeleted
Lists devices whose Intune primary user was deleted from Entra ID. Without this they would look like mismatches, because Intune rewrites the name of a deleted user.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludePrimaryUserNotLoggingOn
Lists devices where other users log on but the primary user has not within "Primary user must have logged on within (days)". Uses the logons Intune and the RealmJoin agent recorded.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeDeviceGroup
Only devices in this Entra ID group. Leave empty for all devices.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ExcludeDeviceGroup
Skips devices in this Entra ID group, for example shared devices where several people log on by design. Leave empty to skip none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SendEmailReport
Send the report to the recipient email address.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
Sender address of the report email. Taken from the tenant setting RJReport.EmailSender.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingHeaderImageUrl
Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl
Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink
Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingAccentColor
Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor
Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ReportFileFormat
Deliver the report as CSV, as an Excel workbook, or both.

| Property | Value |
|----------|-------|
| Default Value | CSV & XLSX |
| Required | false |
| Type | String |

### CreateDownloadLink
Also upload the report and return a download link that expires after a few days.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Set per runbook.

| Property | Value |
|----------|-------|
| Default Value | report-primary-user-mismatch |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LinkExpiryDays
Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)


# Delete Stale Devices (Scheduled)

Delete Intune devices that have been inactive for too long

## Detailed description
Finds Intune devices that have not checked in for a given number of days, filtered by platform and optionally by group membership. An include group limits the run to devices of its users; an exclude group protects devices of its users and devices that are members themselves. By default it only lists what it would delete; deletion has to be switched on explicitly. The report can be sent by email or provided as a download link.

## Where to find
Org \ Devices \ Delete Stale Devices_Scheduled

## Common use cases

This runbook deletes managed devices from Intune based on inactivity, so use it with care.

- Regular cleanup of stale device records in Intune
- Simulation runs (report-only mode) before enabling the actual deletion
- Scheduled lifecycle management with an audit trail via the email report

## Inactivity threshold

*Days without activity* accepts 1 to 3650 days. A device counts as stale when its last check-in is at least that many days ago.

## User scope filtering

The runbook supports optional group filtering as an additional safety net when deletion is enabled. Members of nested groups count as well.

- **Include group** - only devices whose primary user is a member are in scope. Devices without a primary user, and devices whose primary user was deleted from Entra ID, are left out.
- **Exclude group** - devices whose primary user is a member are skipped, and so are devices whose Entra ID device object is a member of the group itself. A device group such as "Intune - do not delete" therefore protects its devices. Devices of deleted users stay in scope.

Group membership is checked against the primary user's object ID as recorded by Intune, so a changed user principal name does not affect the filter.

A group applies whenever it is set, also when the runbook is started through the API or by a schedule without the *Filter by primary user group?* choice. Choosing *Yes, filter by group membership* without selecting a group stops the run before anything is deleted.

The filter fails closed:

- If a selected group cannot be read, or the include group contains no users, the run stops with an error and no device is deleted.
- If Intune records a primary user for a device but no user object ID, the device is not deleted. It is listed with the status *Skipped: primary user could not be resolved* for manual review.

## Download link

If the upload for the download link fails, the email report and the Output Data are still delivered, so the list of deleted devices is not lost. The job then ends as failed.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All
  - Directory.Read.All
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All *(optional: Email report)*


## Parameters
### Days
Devices with no check-in for at least this many days count as stale. Allowed are 1 to 3650 days.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### Windows
Includes Windows devices.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### MacOS
Includes macOS devices.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### iOS
Includes iOS and iPadOS devices.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### Android
Includes Android devices.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### DeleteDevices
Delete removes the stale devices from Intune. Report only lists them and changes nothing.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

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
| Default Value | delete-stale-devices |
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

### SubscriptionId
Subscription ID of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.SubscriptionId; the subscription the managed identity signs in to is used when empty.

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

### UseUserScope
Set by the "Filter by primary user group?" choice; with "Yes", at least one group is required. A group in "Include users from group" or "Exclude users from group" applies whenever it is set, also without this choice.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeUserGroup
Only devices whose primary user is a member of this group, directly or through nested groups. Devices without a primary user are left out.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ExcludeUserGroup
Skips devices whose primary user is a member of this group and devices that are members themselves, directly or through nested groups. Skipped devices are never deleted.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailTo
Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


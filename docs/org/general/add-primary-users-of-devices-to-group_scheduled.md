# Add Primary Users Of Devices To Group (Scheduled)

Keep a group in sync with the primary users of Intune devices

## Detailed description
Collects the primary users of all Intune devices of the chosen platforms and keeps an Entra ID group in sync with them. Users without a matching device are removed unless removal is turned off. An include group limits which users are eligible, an exclude group blocks users. A report-only mode previews the changes by email without applying anything.

## Where to find
Org \ General \ Add Primary Users Of Devices To Group_Scheduled

## Common use cases

- Keeping a distribution or Conditional Access target group aligned with "who currently has a managed device", filtered by platform, by an advanced OData filter or by an include/exclude group scope.
- Validating a new or changed filter or scope before it is allowed to write to a production group.

A daily schedule is recommended.

## Report-only mode for pilots and testing

Enable `ReportOnly` to compute the same add/remove diff a real run would produce, without applying any change to the group. Instead, a Markdown preview email listing the affected users by UPN is sent to `EmailTo`: each list (would be added, would be removed) shows at most 10 users in the mail body, with a "... and N more" pointer when a list is longer, and the complete lists are attached as report file(s) in the format chosen by `ReportFileFormat`. Run once in this mode after changing the platform selection, `AdvancedFilter` or the include/exclude groups, review the preview, then disable `ReportOnly` to let the sync apply.

## Parameter interactions

- `AdvancedFilter`, when set, replaces the Windows/macOS/iOS/Android platform selection entirely rather than combining with it.
- `RemoveUsersWhenNoDeviceMatch` controls both the real run and the `ReportOnly` preview: when disabled, no users are removed in either case, so the preview always reflects what a real run would do.

## Setup regarding email sending

Sending an email report is optional and only happens when the `ReportOnly` option is enabled; a recipient (`EmailTo`) is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

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
  - DeviceManagementManagedDevices.Read.All
  - Group.Read.All
  - GroupMember.ReadWrite.All
  - User.Read.All


## Parameters
### TargetGroupId
Group that receives the primary users. Its membership is managed by this runbook alone.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Windows
Includes the primary users of Windows devices.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### MacOS
Includes the primary users of macOS devices.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### iOS
Includes the primary users of iOS and iPadOS devices.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### Android
Includes the primary users of Android devices.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### AdvancedFilter
OData filter for the devices instead of the platform switches, for example startsWith(deviceName,'FWP-') and operatingSystem eq 'Windows'.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RemoveUsersWhenNoDeviceMatch
Removes users from the target group when they are no longer primary user of a matching device. Turn off to only ever add.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeGroupId
Only members of this group can be added to the target group.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ExcludeGroupId
Members of this group are never added and are removed if present.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ReportOnly
Previews the changes without applying them. The preview goes by email, with the first 10 users per list in the body and the complete lists attached.

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

### EmailTo
Address the preview goes to. Only used in report-only mode.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ReportFileFormat
Attach the complete lists as CSV, as an Excel workbook, or both. Only used in report-only mode.

| Property | Value |
|----------|-------|
| Default Value | CSV & XLSX |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


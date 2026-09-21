# Report Intune Enrollment Readiness

Report which users can enroll devices in Intune

## Detailed description
Checks for a set of users, given directly or through a group, whether they can enroll a device in Intune. Each user is reported as Ready, Ready with warnings or Not ready, together with the blockers found. The check covers account status, Intune license, enrollment limit, authentication methods and Conditional Access policies that target device registration or enrollment. Nothing is changed. The report can be sent by email.

## Where to find
Org \ General \ Report Intune Enrollment Readiness

## Interpretation notes

- Checks performed per user: account state, Intune license and service plan, tenant MDM authority, device enrollment limit, platform restrictions, registered authentication methods, Conditional Access policies and, optionally, pilot group membership.
- Conditional Access is evaluated as a static "What If" against the enrollment sign-in for each user's `EnrollmentPlatform`; Entra's own What If tool remains the authority.
- Compliant-device requirements on "All resources" policies do not block enrollment (a documented Entra exemption); only policies targeting device registration or the Intune enrollment apps are treated as strict gates.
- Not evaluated statically: named locations, device filters, sign-in frequency and terms of use.
- Expired or already used Temporary Access Passes are not counted as usable methods.

## Prerequisites

At least one of `UserName` or `GroupName` is required; group memberships are resolved transitively.

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
  - DeviceManagementServiceConfig.Read.All
  - Group.Read.All
  - GroupMember.Read.All
  - Organization.Read.All
  - Policy.Read.All
  - RoleManagement.Read.Directory
  - User.Read.All
  - UserAuthenticationMethod.Read.All
  - Mail.Send *(optional: Email report)*


## Parameters
### UserName
Each picked user is checked on its own. Leave empty to check only the members of the group.

| Property | Value |
|----------|-------|
| Default Value | @() |
| Required | false |
| Type | String Array |

### GroupName
Group whose members are checked, nested groups included. Can be combined with individual users.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EnrollmentPlatform
Platform of the device the users want to enroll. Conditional Access policies scoped to other platforms are ignored; All platforms checks every platform and reports each one.

| Property | Value |
|----------|-------|
| Default Value | Windows |
| Required | false |
| Type | String |

### CheckPilotGroupMembership
Adds a column with the pilot group membership; non-members are reported as Not ready.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### PilotGroupDisplayName
Members of this group count as pilot users. The group is looked up by its display name.

| Property | Value |
|----------|-------|
| Default Value | col - All Users - Pilot (users) |
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

### ReportFileFormat
Deliver the report as CSV, as an Excel workbook, or both.

| Property | Value |
|----------|-------|
| Default Value | CSV & XLSX |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


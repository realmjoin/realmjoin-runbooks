# Report Intune Enrollment Readiness

Report Intune enrollment readiness for a set of users

## Detailed description
Analyzes whether each user in a selected user set can enroll a device in Microsoft Intune by checking account status, Intune licensing, device enrollment limits, authentication methods, and Conditional Access policies that explicitly target device registration or Intune enrollment; policies requiring compliant devices via "All resources" are exempted per Microsoft Entra design. Platform-scoped policies and browser-only client-app constraints are evaluated against the selected enrollment platform. Results are exported as CSV and/or XLSX with optional email delivery.

## Where to find
Org \ General \ Report Intune Enrollment Readiness

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


## Notes
Interpretation notes:
- Checks performed per user: account state, Intune license and service plan, tenant MDM authority,
  device enrollment limit, platform restrictions, registered authentication methods, Conditional
  Access policies, and optionally pilot group membership.
- Conditional Access is evaluated as a static "What If" against the enrollment sign-in for each
  user's EnrollmentPlatform; Entra's own What If tool remains the authority.
- Compliant-device requirements on "All resources" policies do not block enrollment (documented
  Entra exemption); only policies targeting device registration or the Intune enrollment apps are
  treated as strict gates.
- Not evaluated statically: named locations, device filters, sign-in frequency, and terms of use.
- Expired or already-used Temporary Access Passes are not counted as usable methods.

Prerequisites:
- Requires the RJReport.EmailSender setting for email delivery, and at least one of UserName or
  GroupName (memberships resolved transitively).

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
User principal names of users to check for Intune enrollment readiness. Select one or more users. At least one of UserName or GroupName must be supplied; both may be combined.

| Property | Value |
|----------|-------|
| Default Value | @() |
| Required | false |
| Type | String Array |

### GroupName
Display name of a group whose members to check for Intune enrollment readiness. Group membership is resolved transitively, including nested groups. At least one of UserName or GroupName must be supplied; both may be combined.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EnrollmentPlatform
Device platform assumed during Conditional Access evaluation. Platform-scoped policies that do not cover this platform are ruled out. When set to 'All', the script evaluates every platform and reports results per platform.

| Property | Value |
|----------|-------|
| Default Value | Windows |
| Required | false |
| Type | String |

### CheckPilotGroupMembership
If set to true, the report includes a column showing pilot group membership for each user. Users who are not members are marked "Not ready" with the reason "Not a member of the pilot group"; if the group cannot be found or verified, a warning is issued.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### PilotGroupDisplayName
Display name of the pilot group to check membership against when CheckPilotGroupMembership is enabled. Default is "col - All Users - Pilot (users)". This can be overridden per run or configured via runbook customization.

| Property | Value |
|----------|-------|
| Default Value | col - All Users - Pilot (users) |
| Required | false |
| Type | String |

### EmailFrom
The sender email address for report delivery. Configured as a tenant setting; leave empty if no email report is requested.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingHeaderImageUrl
URL of a custom header image for report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl
URL of a custom footer image for report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink
Link target applied to the footer image in report emails, for example the company website. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingAccentColor
Accent color used for headings and highlights in report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor
Body text color used in report emails. Configured as a tenant setting; leave empty to use the default RealmJoin branding.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SendEmailReport
If set to true, the report is sent as an email to the address specified by EmailTo. If false, the report is generated but not emailed.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Recipient email address or multiple comma-separated addresses for the report email. Required when SendEmailReport is set to true. Each recipient receives an individual email for privacy.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ReportFileFormat
File format for the generated report: CSV only, CSV & XLSX (both files), or XLSX only.

| Property | Value |
|----------|-------|
| Default Value | CSV & XLSX |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


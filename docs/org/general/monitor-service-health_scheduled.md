# Monitor Service Health (Scheduled)

Alert by email on newly announced Microsoft 365 Service Health issues

## Detailed description
Queries the Microsoft 365 Service Health issues feed on a schedule and identifies issues whose first Service Health post falls within a configurable lookback window, since Microsoft frequently back-dates the official start time and filtering on that alone would miss alerts. Optionally narrows monitoring to a chosen set of services and sends one alert email per newly detected issue, with the subject naming the tenant and the issue title. All issue details are carried in the email body; the runbook produces no report files.

## Where to find
Org \ General \ Monitor Service Health_Scheduled

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings: a custom header image, a custom footer image (public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each), a custom footer link, and custom accent and text colors (6-digit hex values, e.g. `#0052cc`). When these settings are not configured, the default RealmJoin graphics and colors are used. A branding image that cannot be downloaded or validated, or a color value that is not a valid hex color, never prevents the report email - the corresponding default is used instead.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for setup details.


## Notes
Common Use Cases:
- Schedule the runbook to run at or slightly more often than LookbackHours to catch every new Service Health issue exactly once.
- Set Services to a comma-separated list of service names or short ids (matched case-insensitively) to monitor only specific services, such as Exchange Online or Teams; leave it empty to monitor all services.
- Leave IncludeAdvisories and IncludeResolvedIssues at their default of $false for the lowest-noise setup, which alerts only on unresolved incidents; set either to $true to also surface advisories or issues Microsoft has already marked resolved.

Parameter Interactions:
- An issue counts as newly announced when its first Service Health post falls inside the LookbackHours window (falling back to startDateTime if the issue has no posts) - not by lastModifiedDateTime alone. This avoids missing back-dated issues while preventing re-alerts on every status update of an ongoing incident.
- The runbook keeps no state between runs, so a failed or skipped run means those alerts are never sent unless LookbackHours is temporarily widened for a catch-up run.
- One email is sent per new issue, so a busy Service Health day can produce several emails per run.

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All
  - ServiceHealth.Read.All


## Parameters
### Services
Comma-separated list of Microsoft 365 service names to monitor, for example Microsoft Intune, Microsoft Entra, Exchange Online. Leave empty to monitor all services. Matching is case-insensitive against both the service display name and its short id, so Intune matches Microsoft Intune. Valid names can be found on the Microsoft 365 admin center service health page.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LookbackHours
How many hours back to look for newly announced issues. Set this to the same interval as the runbook schedule, for example 24 for a daily schedule, so that no issue is missed and none is alerted on twice.

| Property | Value |
|----------|-------|
| Default Value | 24 |
| Required | false |
| Type | Int32 |

### IncludeAdvisories
If set to false, only incidents raise an alert. If set to true, advisories are alerted on as well.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeResolvedIssues
If set to false, issues that Microsoft has already marked as resolved by the time the runbook runs are skipped. If set to true, resolved issues are still reported.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailFrom
The sender email address used for the per-issue alert emails. This needs to be configured in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingHeaderImageUrl
Optional public HTTPS URL of a custom header image (PNG/JPEG/GIF, max. 200 KB) for the alert emails.
Sourced from the RJReport.Branding.HeaderImageUrl tenant setting. When empty, the default RealmJoin header graphic is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl
Optional public HTTPS URL of a custom footer image (PNG/JPEG/GIF, max. 200 KB) for the alert emails.
Sourced from the RJReport.Branding.FooterImageUrl tenant setting. When empty, the default RealmJoin footer graphic is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink
Optional URL the footer image links to. Sourced from the RJReport.Branding.FooterLink tenant setting.
When empty, the default link (https://www.realmjoin.com) is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingAccentColor
Optional accent color override (6-digit hex, e.g. '#0052cc') for the report email template.
Sourced from the RJReport.Branding.AccentColor tenant setting. When empty or invalid, the default RealmJoin accent color is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor
Optional text color override (6-digit hex) for the report email template.
Sourced from the RJReport.Branding.TextColor tenant setting. When empty or invalid, the default RealmJoin text color is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailTo
Comma-separated list of recipient email addresses for the per-issue alert emails. At least one valid recipient is required.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


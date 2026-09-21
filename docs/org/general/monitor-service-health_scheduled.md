# Monitor Service Health (Scheduled)

Alert by email about new Microsoft 365 service health issues

## Detailed description
Checks the Microsoft 365 service health feed for issues that Microsoft announced within the chosen number of hours. Each new issue is sent as a separate alert email, with the tenant and issue title in the subject and all details in the body. Monitoring can be limited to certain services, and advisories and already resolved issues can be included. No report files are created.

## Where to find
Org \ General \ Monitor Service Health_Scheduled

## Common use cases

- Schedule the runbook to run at or slightly more often than `LookbackHours` to catch every new Service Health issue exactly once.
- Set `Services` to a comma-separated list of service names or short ids (matched case-insensitively) to monitor only specific services, such as Exchange Online or Teams; leave it empty to monitor all services.
- Leave `IncludeAdvisories` and `IncludeResolvedIssues` at their default of `false` for the lowest-noise setup, which alerts only on unresolved incidents; set either to `true` to also surface advisories or issues Microsoft has already marked as resolved.

## Parameter interactions

- An issue counts as newly announced when its first Service Health post falls inside the `LookbackHours` window (falling back to `startDateTime` if the issue has no posts), not by `lastModifiedDateTime` alone. This avoids missing back-dated issues while preventing re-alerts on every status update of an ongoing incident.
- The runbook keeps no state between runs, so a failed or skipped run means those alerts are never sent unless `LookbackHours` is temporarily widened for a catch-up run.
- One email is sent per new issue, so a busy Service Health day can produce several emails per run.

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
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All
  - ServiceHealth.Read.All


## Parameters
### Services
Services to watch, separated by commas, for example Microsoft Intune, Microsoft Entra, Exchange Online. Leave empty for all services. Short names such as Intune work too.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LookbackHours
How many hours back to look for newly announced issues, 1 to 168. Use the same interval as the schedule, for example 24 for a daily run, so nothing is missed or alerted twice.

| Property | Value |
|----------|-------|
| Default Value | 24 |
| Required | false |
| Type | Int32 |

### IncludeAdvisories
Also alerts on advisories, not only on incidents.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeResolvedIssues
Also alerts on issues Microsoft has already resolved by the time the runbook runs.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailFrom
Sender address of the alert email. Taken from the tenant setting RJReport.EmailSender.

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
Addresses that receive the alert emails, separated by commas. At least one is required.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


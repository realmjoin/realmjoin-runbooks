# Report Signins (Scheduled)

Report retained Entra agent identity sign-in events

## Detailed description
Uses the documented Microsoft Graph beta auditLogs/signIns query for service-principal events whose
agent/agentType is agenticAppInstance. Applies an explicit UTC time window, follows pagination, summarizes
success, failure, resources, and identities, and optionally emails the result.

## Where to find
Org \ Agent Identity \ Report Signins_Scheduled

## Usage guidance

Reports autonomous Agent ID sign-ins over a bounded UTC window.

## Output

Per-event status plus summary counts by success/failure, identity, and target resource.

The same assessment summary appears in job output and email. `NoRetainedEvents` is not proof of
inactivity or absence of risk: check the time window, retention, licensing, and ingestion delay.
Missing event status is `Unknown`, not success. `Truncated` explicitly identifies an exceeded
`MaxEvents` cap; its counts describe only the retained subset.

## API and safety notes

Microsoft Learn documents agent sign-in filtering on the beta /auditLogs/signIns endpoint. The query explicitly requests servicePrincipal events and filters agent/agentType to agenticAppInstance.

Unknown lookup or revalidation states are reported and fail closed. Microsoft Graph pagination is followed, and HTTP 429/5xx responses are retried with backoff.

## Email delivery

Email is optional. Set `EmailTo` to enable it. The sender is read from `RJReport.EmailSender` and the runbook uses `Send-RjRbReportEmail`.

## Access requirements

### Required Graph access

- `AuditLog.Read.All`
- `Mail.Send (optional)`

`Mail.Send` is optional and is needed only for email delivery.

## Parameter behavior

### MaxEvents

Bounds report size. The report explicitly states when this cap truncates results.

### LookbackHours

UTC time window, from now minus this value through now.

### EmailTo

Optional comma- or semicolon-separated report recipients.

### EmailFrom

Hidden sender setting sourced from `RJReport.EmailSender`.


## RealmJoin output and operator guidance

- The **Output Data** tab receives raw objects in named tables, with full identifiers and exportable columns; console formatting is not used for report data.
- Reports include a structured summary even when no detail rows match. Unknown, partial, and blocked states are not evidence of a clean assessment.
- Parameter information tooltips describe expected inputs and safety requirements. Context and centrally configured settings stay hidden; supported choices use dropdowns.
- Action runbooks retain their runtime validation and confirmation checks. Selecting an action in the portal does not bypass those checks.
- Output Data applies to new live jobs, not previously completed or archived jobs. Existing console output and email/file delivery remain available.

See [RealmJoin Output Data](https://docs.realmjoin.com/dev-reference/runbook-output-data) and [runbook customization](https://docs.realmjoin.com/automation/runbooks/runbook-customization).

## Email branding

Report emails use the optional RJReport.Branding settings for header/footer images, footer links and colors. Configure RJReport.EmailSender and grant Mail.Send before enabling email delivery. See the [report settings](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings).


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AuditLog.Read.All
  - Mail.Send *(optional: Email report)*


## Parameters
### LookbackHours
UTC lookback window in hours.

| Property | Value |
|----------|-------|
| Default Value | 24 |
| Required | false |
| Type | Int32 |

### MaxEvents
Maximum events retained in the report; collection stops at the cap.

| Property | Value |
|----------|-------|
| Default Value | 10000 |
| Required | false |
| Type | Int32 |

### EmailTo
Optional comma- or semicolon-separated recipients for the report.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
Sender mailbox from the RJReport.EmailSender tenant setting. Required only when EmailTo is set.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingHeaderImageUrl
Header image URL for report emails.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl
Footer image URL for report emails.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink
Destination link for the report email footer.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingAccentColor
Accent color for report emails.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor
Text color for report emails.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


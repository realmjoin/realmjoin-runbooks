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

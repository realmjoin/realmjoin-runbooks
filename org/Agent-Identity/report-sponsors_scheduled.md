## Usage guidance

Reports missing, disabled, deleted, guest, and unknown sponsor states.

## Output

Actionable sponsor findings and unknown lookup counts are reported separately. Unknown lookups
make the assessment partial; they are not healthy sponsors. Findings on existing tenant objects
remain visible and are not remediated automatically by this report.

One row per sponsor relationship, or a missing/unknown row per target.

## API and safety notes

Uses v1.0 typed sponsor relationships. Lookup failures are Unknown. Fallback sponsor assignment is intentionally out of scope; use the interactive sponsor/owner runbook.

Unknown lookup or revalidation states are reported and fail closed. Microsoft Graph pagination is followed, and HTTP 429/5xx responses are retried with backoff.

## Email delivery

Email is optional. Set `EmailTo` to enable it. The sender is read from `RJReport.EmailSender` and the runbook uses `Send-RjRbReportEmail`.

## Access requirements

### Required Graph access

- `AgentIdentity.Read.All`
- `AgentIdentity.ReadWrite.All` (Learn exposes no read-only application permission for the Agent Identity `sponsors` relationship)
- `AgentIdentityBlueprint.Read.All`
- `Application.Read.All` (blueprint sponsors)
- `User.Read.All`
- `Directory.Read.All`
- `Mail.Send (optional)`

`Mail.Send` is optional and is needed only for email delivery.

## Parameter behavior

### IncludeBlueprints

Include blueprint sponsors in addition to agent identity sponsors.

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

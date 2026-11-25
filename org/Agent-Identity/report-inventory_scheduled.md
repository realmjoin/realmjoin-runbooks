## Usage guidance

Reports a complete Microsoft Entra Agent ID inventory and posture view.

## Output

The summary includes the UTC collection start and counts for each object type in both job output
and email. All returned objects are included, including disposable test objects still present at
collection time. Counts describe an inventory snapshot, not health or completed test coverage.

A structured row per agent identity and related Agent ID object, including relationship state and per-blueprint counts.

## API and safety notes

Core resources and sponsor/owner relationships use Microsoft Graph v1.0. The 250 constraint applies to agent identities created for a blueprint by an app-only caller; it is not a general tenant quota.

Unknown lookup or revalidation states are reported and fail closed. Microsoft Graph pagination is followed, and HTTP 429/5xx responses are retried with backoff.

## Email delivery

Email is optional. Set `EmailTo` to enable it. The sender is read from `RJReport.EmailSender` and the runbook uses `Send-RjRbReportEmail`.

## Access requirements

### Required Graph access

- `AgentIdentity.Read.All`
- `AgentIdentity.ReadWrite.All` (Learn exposes no read-only application permission for the Agent Identity `sponsors` relationship)
- `AgentIdentityBlueprint.Read.All`
- `AgentIdentityBlueprintPrincipal.Read.All`
- `User.Read.All`
- `CustomSecAttributeAssignment.Read.All (optional)`
- `Mail.Send (optional)`

`Mail.Send` is optional and is needed only for email delivery.

## Parameter behavior

### IncludeCustomSecurityAttributes

Request custom security attributes. Their permission is optional.

### BlueprintQuotaWarningPercent

Warn at this percentage of the documented app-only 250-agent-identities-per-blueprint constraint.

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

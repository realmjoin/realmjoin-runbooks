## Usage guidance

Reports Conditional Access target selectors for agent and blueprint principals, not effective protection.

## Output

Per-principal inclusion/exclusion, target kind, policy state, and unknown selectors. Enabled,
report-only and disabled policies remain distinct. A selector match does not prove that the policy
applies to a particular sign-in or that its grant controls enforce protection.

## API and safety notes

Uses the beta Conditional Access policy surface to read `includeAgentIdServicePrincipals`,
`excludeAgentIdServicePrincipals` and `agentIdServicePrincipalFilter`. Ordinary
`includeServicePrincipals` / `excludeServicePrincipals` selectors are reported separately as
`WorkloadIdentity`, not silently treated as agent-specific coverage.

Explicit exclusions take precedence. Filters and unrecognized symbolic selectors produce **Unknown**;
they are not evaluated locally. Other conditions, grant controls and OBO coverage are not inferred.
See the [Graph client application conditions](https://learn.microsoft.com/graph/api/resources/conditionalaccessclientapplications?view=graph-rest-beta).

Unknown lookup or revalidation states are reported and fail closed. Microsoft Graph pagination is followed, and HTTP 429/5xx responses are retried with backoff.

## Email delivery

Email is optional. Set `EmailTo` to enable it. The sender is read from `RJReport.EmailSender` and the runbook uses `Send-RjRbReportEmail`.

## Access requirements

### Required Graph access

- `AgentIdentity.Read.All`
- `AgentIdentityBlueprintPrincipal.Read.All`
- `Policy.Read.All`
- `Mail.Send (optional)`

`Mail.Send` is optional and is needed only for email delivery.

## Parameter behavior

### IncludeDisabledPolicies

Include disabled policy targeting as informational, non-enforced coverage.

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

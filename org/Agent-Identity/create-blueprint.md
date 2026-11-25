## Usage guidance

Principal creation POSTs are not replayed after ambiguous server or transport failures. If the
blueprint application was created before principal creation failed, its IDs are reported and the
application is retained. Inspect and reconcile that partial result before starting another creation run.

Creates a Microsoft Entra Agent ID blueprint and its required blueprint principal in the current Microsoft Learn sequence.

## How it works

The runbook validates mandatory user or eligible-group sponsors, optional user/service-principal owners, and optional manager applications supplied by application (client) ID. It posts the blueprint to `/applications/microsoft.graph.agentIdentityBlueprint`, then creates its principal at `/servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal`. Principal creation uses bounded exponential retry because the application can take time to propagate.

`description`, `tags`, and the `managerApplications` GUID collection are sent only when supplied. Groups can't be owners. Sponsor groups must be Microsoft 365 or dynamic groups and can't be role assignable. Microsoft Learn documents a maximum of 100 sponsors per blueprint, of which no more than 5 may be groups; Graph enforces these limits.

## Output and safety

Output contains both object IDs, the blueprint app ID, and relationship counts. If principal creation exhausts retries, the error clearly reports a partially created blueprint; rerun only after checking whether the principal now exists.

## Access requirements

- `AgentIdentityBlueprint.Create`
- `AgentIdentityBlueprint.ReadWrite.All`
- `AgentIdentityBlueprintPrincipal.Create`
- `Directory.Read.All`

The specific blueprint permissions are used instead of `Application.ReadWrite.All`. Manager application values are validated as GUIDs, while the typed blueprint API authoritatively enforces the Microsoft first-party application restriction.

## RealmJoin output and operator guidance

- The **Output Data** tab receives raw objects in named tables, with full identifiers and exportable columns; console formatting is not used for report data.
- Reports include a structured summary even when no detail rows match. Unknown, partial, and blocked states are not evidence of a clean assessment.
- Parameter information tooltips describe expected inputs and safety requirements. Context and centrally configured settings stay hidden; supported choices use dropdowns.
- Action runbooks retain their runtime validation and confirmation checks. Selecting an action in the portal does not bypass those checks.
- Output Data applies to new live jobs, not previously completed or archived jobs. Existing console output and email/file delivery remain available.

See [RealmJoin Output Data](https://docs.realmjoin.com/dev-reference/runbook-output-data) and [runbook customization](https://docs.realmjoin.com/automation/runbooks/runbook-customization).


## Additional operational guidance

Uses the current v1.0 typed Agent ID creation sequence: blueprint first, then blueprint principal. A partial result is reported if principal creation still fails after bounded retries.

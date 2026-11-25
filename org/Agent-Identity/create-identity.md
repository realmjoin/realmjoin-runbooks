## Usage guidance

Creation POSTs are not idempotent. Throttling and recognized propagation failures can be retried,
but an ambiguous server or transport error stops without replaying the POST. Inspect the blueprint's
identities before trying again; the first request may already have created an identity.

Creates an Agent Identity from a selected existing blueprint.

## How it works

Supply the blueprint application ID, mandatory sponsors, and optional owners, display name, and tags. The runbook verifies the typed blueprint and its required blueprint principal, enforces current sponsor-group restrictions (Microsoft 365 or dynamic groups only, not role assignable; Learn documents at most 100 sponsors with no more than 5 groups, enforced by Graph), then posts to `/servicePrincipals/microsoft.graph.agentIdentity`. When `DisplayName` is omitted, the runbook explicitly uses the validated blueprint display name because the create API requires a display name. Bounded retry handles directory eventual consistency.

Credentials are never added to the identity; they belong on the blueprint.

## Output

Returns the new identity object ID, app ID, display name, blueprint app ID, and sponsor/owner counts.

## Access requirements

- `AgentIdentity.Create.All`
- `AgentIdentityBlueprint.Read.All`
- `AgentIdentityBlueprintPrincipal.Read.All`
- `Directory.Read.All`

## RealmJoin output and operator guidance

- The **Output Data** tab receives raw objects in named tables, with full identifiers and exportable columns; console formatting is not used for report data.
- Reports include a structured summary even when no detail rows match. Unknown, partial, and blocked states are not evidence of a clean assessment.
- Parameter information tooltips describe expected inputs and safety requirements. Context and centrally configured settings stay hidden; supported choices use dropdowns.
- Action runbooks retain their runtime validation and confirmation checks. Selecting an action in the portal does not bypass those checks.
- Output Data applies to new live jobs, not previously completed or archived jobs. Existing console output and email/file delivery remain available.

See [RealmJoin Output Data](https://docs.realmjoin.com/dev-reference/runbook-output-data) and [runbook customization](https://docs.realmjoin.com/automation/runbooks/runbook-customization).


## Additional operational guidance

The blueprint principal must already exist. Credentials belong on the blueprint, never on an agent identity.

# Transfer Sponsorships

Transfer direct agent identity and blueprint sponsorships

## Detailed description
Enumerates Agent Identities and blueprints with pagination, finds sponsorship references held by the source user, and reports them by default. Execute mode requires explicit confirmation, revalidates each typed object and both users, adds the target first, removes the source second, enforces a cap, and is idempotent.

## Where to find
Org \ Agent Identity \ Transfer Sponsorships

## Usage guidance

Reports or transfers sponsorship references from one user to another across Agent Identities and blueprints.

## How it works

Report-only is the default. The runbook paginates both typed collections, discovers references held by the source user, and can be narrowed to selected target object IDs. Execute mode requires a second confirmation and is capped by `MaxChanges`.

Each change revalidates both users and the typed object. It adds the target before removing the source and re-reads the sponsor list to confirm the target is present before the source reference is deleted, so accountability overlaps. If the target is already assigned, only the source is removed. Completed or externally changed objects are handled idempotently.

Candidates are processed independently: a Graph rejection for one object (for example the documented limit of 100 sponsors and 5 groups per object) is reported as `Failed safely` for that object and the remaining transfers continue. Objects whose sponsor list could not be read are reported as `Unknown (sponsor lookup failed)` and are never changed.

## Access requirements

- `AgentIdentity.ReadWrite.All`
- `AgentIdentityBlueprint.Read.All`
- `Application.ReadWrite.All`
- `User.Read.All`

Microsoft Graph currently documents `Application.ReadWrite.All` for Agent Identity Blueprint sponsor relationship writes. The narrower blueprint permission is retained for typed blueprint reads.

## RealmJoin output and operator guidance

- The **Output Data** tab receives raw objects in named tables, with full identifiers and exportable columns; console formatting is not used for report data.
- Reports include a structured summary even when no detail rows match. Unknown, partial, and blocked states are not evidence of a clean assessment.
- Parameter information tooltips describe expected inputs and safety requirements. Context and centrally configured settings stay hidden; supported choices use dropdowns.
- Action runbooks retain their runtime validation and confirmation checks. Selecting an action in the portal does not bypass those checks.
- Output Data applies to new live jobs, not previously completed or archived jobs. Existing console output and email/file delivery remain available.

See [RealmJoin Output Data](https://docs.realmjoin.com/dev-reference/runbook-output-data) and [runbook customization](https://docs.realmjoin.com/automation/runbooks/runbook-customization).


## Additional operational guidance

The target sponsor is added before the source is removed. Already-complete transfers are reported as NoChange.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AgentIdentity.ReadWrite.All
  - AgentIdentityBlueprint.Read.All
  - Application.ReadWrite.All
  - User.Read.All


## Parameters
### SourceUserObjectId
Object ID of the user whose sponsorship references are being transferred.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### TargetUserObjectId
Object ID of the user receiving sponsorship references.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### SelectedTargetObjectIds
Optional comma-separated Agent Identity or blueprint object IDs. Leave empty to consider all discovered references.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Execute
When false, produces a report only. Set true to request changes.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ConfirmExecute
Second interlock that must be true with Execute.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### MaxChanges
Maximum number of objects changed in one execution.

| Property | Value |
|----------|-------|
| Default Value | 20 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)


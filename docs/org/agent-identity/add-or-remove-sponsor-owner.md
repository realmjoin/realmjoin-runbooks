# Add Or Remove Sponsor Owner

Add or remove sponsors or owners on agent identities and blueprints

## Detailed description
Revalidates the typed target and every directory object, enforces owner and sponsor object-type restrictions, checks sponsor-group eligibility, and changes the selected relationship through the current v1.0 typed cast endpoint.

## Where to find
Org \ Agent Identity \ Add Or Remove Sponsor Owner

## Usage guidance

Changes sponsor or owner relationships on an Agent Identity or blueprint.

## How it works

Select the target kind, relationship, action, and directory object IDs. The target is revalidated through its v1.0 typed cast. Owners may be users or service principals but never groups. Sponsors may be users or eligible groups; group eligibility is checked before a relationship is changed. Removing the final sponsor is refused.

Already-applied additions and already-absent removals return `NoChange`.

## Access requirements

- `AgentIdentity.ReadWrite.All`
- `AgentIdentityBlueprint.Read.All`
- `Application.ReadWrite.All`
- `Directory.Read.All`

Microsoft Graph currently documents `Application.ReadWrite.All` for Agent Identity Blueprint sponsor and owner relationship writes. The narrower blueprint permission is used for typed blueprint reads. `AgentIdentity.CreateAsManager` is listed by Learn only as a scoped alternative for first-party manager applications and isn't requested.

Microsoft Learn documents that an Agent Identity or Blueprint may have up to 100 sponsors, of which no more than 5 may be groups; the runbook relies on Graph to enforce these limits and surfaces the resulting error.

## RealmJoin output and operator guidance

- The **Output Data** tab receives raw objects in named tables, with full identifiers and exportable columns; console formatting is not used for report data.
- Reports include a structured summary even when no detail rows match. Unknown, partial, and blocked states are not evidence of a clean assessment.
- Parameter information tooltips describe expected inputs and safety requirements. Context and centrally configured settings stay hidden; supported choices use dropdowns.
- Action runbooks retain their runtime validation and confirmation checks. Selecting an action in the portal does not bypass those checks.
- Output Data applies to new live jobs, not previously completed or archived jobs. Existing console output and email/file delivery remain available.

See [RealmJoin Output Data](https://docs.realmjoin.com/dev-reference/runbook-output-data) and [runbook customization](https://docs.realmjoin.com/automation/runbooks/runbook-customization).


## Additional operational guidance

Owners can't be groups. Sponsors can be users or eligible groups; group sponsors must be Microsoft 365 or dynamic groups and can't be role-assignable. Removal never removes the final sponsor.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AgentIdentity.ReadWrite.All
  - AgentIdentityBlueprint.Read.All
  - Application.ReadWrite.All
  - Directory.Read.All


## Parameters
### TargetKind
Target resource type: Identity or Blueprint.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### TargetObjectId
Object ID of the target service principal (Identity) or application (Blueprint).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Relationship
Relationship to change: Sponsor or Owner.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Action
Operation to perform: Add or Remove.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DirectoryObjectIds
Comma-separated directory object IDs to add or remove.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


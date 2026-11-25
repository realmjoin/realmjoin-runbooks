# Report Inventory (Scheduled)

Inventory Entra agent identities, blueprints and agent users

## Detailed description
Inventories v1.0 agent identities, blueprints, blueprint principals, and agent users. For every
agent identity it records enablement, Microsoft disablement, sponsors, owners, creation, tags,
manager applications, custom security attributes, and blueprint population. Relationship failures
remain Unknown. It warns when app-only creation approaches the documented 250 identities per
blueprint constraint; it does not describe this as a tenant-wide quota.

## Where to find
Org \ Agent Identity \ Report Inventory_Scheduled

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


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AgentIdentity.Read.All
  - AgentIdentity.ReadWrite.All
  - AgentIdentityBlueprint.Read.All
  - AgentIdentityBlueprintPrincipal.Read.All
  - User.Read.All
  - CustomSecAttributeAssignment.Read.All *(optional: Custom security attributes)*
  - Mail.Send *(optional: Email report)*


## Parameters
### BlueprintQuotaWarningPercent
Percentage of the documented app-only 250-per-blueprint constraint at which to warn.

| Property | Value |
|----------|-------|
| Default Value | 80 |
| Required | false |
| Type | Int32 |

### IncludeCustomSecurityAttributes
Request customSecurityAttributes. Disable if the managed identity lacks that separate permission.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

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


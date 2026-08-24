# Agent Identities Without Sponsor or Owner (Scheduled)

Report Entra Agent Identities without sponsors or owners.

## Detailed description

This scheduled runbook queries the Microsoft Graph beta API for Entra Agent Identities and reports identities that have no sponsor, no owner, or either relationship. Sponsorless identities are labeled as anomalies because Agent Identities are expected to have at least one sponsor. Ownerless identities are labeled as legitimate because owners are optional.

Sponsor and owner lookup failures are reported as `Unknown (lookup failed)` and are never treated as proof that a relationship is empty. Blueprint details are fetched once and used to enrich each report row.

When `EmailTo` is configured, the runbook also sends the summary and findings as a branded Markdown email through `Send-RjRbReportEmail`. Without a recipient, the runbook continues to write only to the scheduled job output.

## Where to find

Org \ General \ Agent Identities Without Sponsor or Owner_Scheduled

## Output

The scheduled job output contains a summary and a table with these fields:

- Status and finding classification
- Sponsors and owners
- Blueprint application ID
- Agent Identity object ID and application ID
- Agent Identity and Blueprint display names
- Creation date in UTC

The report does not change tenant data. It does not query audit logs, so it does not attempt to infer the identity creator. Microsoft Entra audit-log retention can prevent reliable creator attribution for older Agent Identities.

## Email delivery

Email delivery is optional. Provide one recipient or a comma-separated list through `EmailTo`. Each recipient receives an individual message.

The sender mailbox is sourced from the central `RJReport.EmailSender` tenant setting. It must be configured when `EmailTo` is used. See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for setup details.

The report email includes the selected scope, counts, finding classifications, sponsor and owner names, and identity object IDs. It uses the default RealmJoin header and footer supplied by `RealmJoin.RunbookHelper`.

## API status

The Agent Identity APIs are currently available only through Microsoft Graph beta endpoints and may change without notice. The runbook uses the derived-type cast paths:

- `/beta/servicePrincipals/microsoft.graph.agentIdentity`
- `/beta/servicePrincipals/{id}/microsoft.graph.agentIdentity/sponsors`
- `/beta/servicePrincipals/{id}/microsoft.graph.agentIdentity/owners`
- `/beta/applications/microsoft.graph.agentIdentityBlueprint`

## Permissions

### Application permissions

- **Type**: Microsoft Graph
  - AgentIdentity.Read.All
  - AgentIdentity.ReadWrite.All
  - AgentIdentityBlueprint.Read.All
  - Application.Read.All
  - User.Read.All
  - Mail.Send *(optional: Email report)*

`AgentIdentity.ReadWrite.All` is required to list sponsors because Microsoft Graph currently provides no read-only application permission for the sponsors relationship. The runbook itself performs only GET requests.

## Parameters

### ReportScope

Controls which Agent Identities are included in the report.

| Property | Value |
|----------|-------|
| Default Value | Missing sponsor or owner |
| Required | false |
| Type | String |
| Allowed Values | Missing sponsor, Missing owner, Missing sponsor or owner, All identities |

### IncludeInactive

Include disabled Agent Identities. By default, only active identities are evaluated.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo

Optional report recipient. Multiple recipients can be supplied as a comma-separated list. When omitted, no email is sent.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom

Sender mailbox sourced from the `RJReport.EmailSender` tenant setting. Required only when `EmailTo` is configured and hidden in the RealmJoin portal.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

[Back to Table of Content](../../../README.md)
# Report Expiring Application Credentials (Scheduled)

List expiry date of all Application Registration credentials

## Detailed description
This runbook lists the expiry dates of application registration credentials, including client secrets and certificates.
It can optionally filter by application IDs and can limit output to credentials that are about to expire.

## Where to find
Org \ Applications \ Report Expiring Application Credentials_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.Read.All
  - Mail.Send


## Parameters
### listOnlyExpiring
If only credentials that are about to expire within the specified number of days should be listed, select "List only credentials about to expire" (final value: true).
If you want to list all credentials regardless of their expiry date, select "List all credentials" (final value: false).

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### Days
The number of days before a credential expires to consider it "about to expire".

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### CredentialType
Filter by credential type: "Both" (default), "ClientSecrets", or "Certificates".

| Property | Value |
|----------|-------|
| Default Value | Both |
| Required | false |
| Type | String |

### ApplicationIds
Optional - comma-separated list of Application IDs to filter the credentials.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailTo
If specified, an email with the report will be sent to the provided address(es).
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### EmailFrom
The sender email address. This needs to be configured in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


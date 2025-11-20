# Report Expiring Application Credentials (Scheduled)

List expiry date of all Application Registration credentials

## Detailed description
List the expiry date of all Application Registration credentials, including Client Secrets and Certificates.
Optionally, filter by Application IDs and list only those credentials that are about to expire.

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
### -listOnlyExpiring
Description: If set to true, only credentials that are about to expire within the specified number of days will be listed.
If set to false, all credentials will be listed regardless of their expiry date.
Default Value: True
Required: false

### -Days
Description: The number of days before a credential expires to consider it "about to expire".
Default Value: 30
Required: false

### -CredentialType
Description: Filter by credential type: "Both" (default), "ClientSecrets", or "Certificates".
Default Value: Both
Required: false

### -ApplicationIds
Description: Optional - comma-separated list of Application IDs to filter the credentials.
Default Value: 
Required: false

### -EmailTo
Description: If specified, an email with the report will be sent to the provided address(es).
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.
Default Value: 
Required: true

### -EmailFrom
Description: The sender email address. This needs to be configured in the runbook customization.
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)


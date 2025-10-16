# Report App Registration

Generate and email a comprehensive App Registration report

## Detailed description
This runbook generates a report of all Entra ID Application Registrations and deleted Application Registrations,
exports them to CSV files, and sends them via email.

## Where to find
Org \ Applications \ Report App Registration

## Setup regarding email sending
This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.Read.All
  - Directory.Read.All
  - Mail.Send
  - Organization.Read.All


## Parameters
### -EmailTo
Description: Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.
Default Value: 
Required: true

### -EmailFrom
Description: The sender email address. This needs to be configured in the runbook customization
Default Value: 
Required: false

### -IncludeDeletedApps
Description: Whether to include deleted application registrations in the report (default: true)
Default Value: True
Required: false


[Back to Table of Content](../../../README.md)


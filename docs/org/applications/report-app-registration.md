# Report App Registration

## Generate and email a comprehensive App Registration report

## Description
This runbook generates a report of all Entra ID Application Registrations and deleted Application Registrations,
exports them to CSV files, and sends them via email.

## Where to find
Org \ Applications \ Report App Registration

## Setup regarding email sending
### Overview
This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

### Prerequisites
We recommend using a dedicated shared mailbox, such as `realmjoin-report@contoso.com`. This mailbox will be used as the sender address for all reports. You can use a no-reply address, as recipients are not expected to respond to automated reports.

### RealmJoin Runbook Customization
As described in detail in the [JSON Based Customizing](https://docs.realmjoin.com/automation/runbooks/runbook-customization#json-based-customizing) documentation, you need to configure the sender email address in the settings block. This configuration defines the sender email address for all reporting runbooks across your tenant.

First, navigate to [RealmJoin Runbook Customization](https://portal.realmjoin.com/settings/runbooks-customizations) in the RealmJoin Portal (Settings > Runbook Customizations).

In the `Settings` block, add or modify the `RJReport` section to include the `EmailFrom` property with your desired sender email address:

```json
{
    "Settings": {
        "RJReport": {
            "EmailFrom": "realmjoin-report@contoso.com"
        }
    }
}
```

**Example:** With this configuration, the runbook will use `realmjoin-report@contoso.com` as the sender email address for all outgoing reports. Replace `contoso.com` with your actual domain name.


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


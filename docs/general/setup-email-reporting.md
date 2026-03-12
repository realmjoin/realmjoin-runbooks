# Setup Email Reporting

## Overview

Several RealmJoin runbooks include automated email reporting capabilities to deliver reports, notifications, and alerts directly to administrators. These runbooks leverage the Microsoft Graph API to send emails on behalf of a configured sender address.

To enable email functionality across all reporting runbooks in your tenant, you need to configure a centralized sender email address through the RealmJoin Runbook Customization settings.
This one-time configuration will be automatically applied to all runbooks that utilize the email reporting feature.

## Prerequisites

We recommend using a dedicated shared mailbox, such as `realmjoin-report@contoso.com`. This mailbox will be used as the sender address for all reports. You can use a no-reply address, as recipients are not expected to respond to automated reports.

## RealmJoin Runbook Customization

As described in detail in the [JSON Based Customizing](https://docs.realmjoin.com/automation/runbooks/runbook-customization#json-based-customizing) documentation, you need to configure the sender email address in the settings block. This configuration defines the sender email address for all reporting runbooks across your tenant.

First, navigate to [RealmJoin Runbook Customization](https://portal.realmjoin.com/settings/runbooks-customizations) in the RealmJoin Portal (Settings > Runbook Customizations).

In the `Settings` block, add or modify the `RJReport` section to include the `EmailSender` property with your desired sender email address:

```json
{
    "Settings": {
        "RJReport": {
            "EmailSender": "realmjoin-report@contoso.com"
        }
    }
}
```

**Example:** With this configuration, the runbook will use `realmjoin-report@contoso.com` as the sender email address for all outgoing reports. Replace `realmjoin-report@contoso.com` with your actual shared mailbox address.

## Setup of Service Desk contact information (optional)

To include Service Desk contact information in the notification emails, you can configure the following settings in your runbook customization:

```json
"Settings": {
  "RJReport": {
    "ServiceDesk_DisplayName": "IT Service Desk",
    "ServiceDesk_EMail": "servicedesk@domain.com",
    "ServiceDesk_Phone": "+49123456789"
  }
}
```

**Parameters:**
- `ServiceDesk_DisplayName` - Display name of your Service Desk (e.g., "IT Support", "Help Desk")
- `ServiceDesk_EMail` - Service Desk email address (will be shown as clickable mailto link)
- `ServiceDesk_Phone` - Service Desk phone number in international format (will be shown as clickable tel link)

All three parameters are optional. If configured, they will be displayed in the email footer as clickable links, making it easy for users to contact support.


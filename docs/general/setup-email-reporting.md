# Setup Email Reporting

## Overview

Several RealmJoin runbooks include automated email reporting capabilities to deliver reports, notifications, and alerts directly to administrators. These runbooks leverage the Microsoft Graph API to send emails on behalf of a configured sender address.

To enable email functionality across all reporting runbooks in your tenant, you need to configure a centralized sender email address through the RealmJoin Runbook Customization settings. This one-time configuration will be automatically applied to all runbooks that utilize the email reporting feature.

## Prerequisites

We recommend using a dedicated shared mailbox, such as `realmjoin-report@contoso.com`. This mailbox will be used as the sender address for all reports. You can use a no-reply address, as recipients are not expected to respond to automated reports.

## RealmJoin Runbook Customization

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

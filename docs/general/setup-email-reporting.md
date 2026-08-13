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
    "ServiceDesk_Phone": "+49123456789",
    "ServiceDesk_PortalUrl": "https://servicedesk.domain.com"
  }
}
```

**Parameters:**

- `ServiceDesk_DisplayName` - Display name of your Service Desk (e.g., "IT Support", "Help Desk")
- `ServiceDesk_EMail` - Service Desk email address (will be shown as clickable mailto link)
- `ServiceDesk_Phone` - Service Desk phone number in international format (will be shown as clickable tel link)
- `ServiceDesk_PortalUrl` - URL of your Service Desk portal (will be shown as clickable link)

All parameters are optional. If configured, they will be displayed in the email footer as clickable links, making it easy for users to contact support.

## Customize email branding (optional)

By default, all report emails use the RealmJoin header and footer graphics. You can replace them with your own branding and change the link behind the footer image by adding a `Branding` block to the `RJReport` section:

```json
"Settings": {
  "RJReport": {
    "Branding": {
      "HeaderImageUrl": "https://cdn.contoso.com/branding/email-header.png",
      "FooterImageUrl": "https://cdn.contoso.com/branding/email-footer.png",
      "FooterLink": "https://intranet.contoso.com"
    }
  }
}
```

**Parameters:**

- `HeaderImageUrl` - Public HTTPS URL of a custom header image, replacing the default RealmJoin header graphic
- `FooterImageUrl` - Public HTTPS URL of a custom footer image, replacing the default RealmJoin footer graphic
- `FooterLink` - URL the footer image links to (default: `https://www.realmjoin.com`)

All parameters are optional and apply to every runbook that sends report emails.

**Image requirements:**

- Publicly reachable **HTTPS** URL, e.g. an Azure Blob Storage container with anonymous read access, a CDN, or your company website
- PNG, JPEG or GIF (validated by file signature, not by URL extension)
- Rendered at 750 px width - recommended **750 × 200 px** (matches the default banners) or **1500 × 400 px** for high-DPI displays
- Maximum **200 KB** per image, recommended **≤ 100 KB**: the branding images share the ~4 MB email size limit with the report attachments (for reference, the default RealmJoin graphics are 52 KB and 15 KB)

**Behavior:**

- The images are downloaded and validated by the runbook on each run - no caching between runs
- An empty or missing setting means the default RealmJoin graphic (and default footer link) is used
- If a download or validation fails, the runbook logs a warning and sends the report with the default graphic - a broken branding configuration never prevents a report email from being sent

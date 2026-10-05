## How it works

The runbook reads two lists and matches them by the Entra device ID (with the Intune device ID as fallback):

- **Intune**: all Windows devices that completed a sync within the last *Intune last sync within (days)*. Devices that stopped syncing with Intune are left out on purpose; they belong in the **Report Stale Devices (Scheduled)** runbook.
- **RealmJoin**: the device list of the RealmJoin customer API. For every device it carries the users the RealmJoin agent has reported as signed in, each with a *last seen* timestamp. RealmJoin writes the same timestamp to the user and to the device with every agent report, so the newest of these values is the device's last agent contact.

For each Intune device the runbook calculates the **gap**: how many days Intune kept seeing the device after the RealmJoin agent last reported. Every device gets one status:

| Status | Meaning |
| --- | --- |
| `InSync` | The agent reported recently enough; the gap is below the allowed value. |
| `AgentStale` | Intune saw the device at least *Allowed gap to RealmJoin last seen (days)* after the agent last reported. The device was in use while the agent did not report: the agent is missing, blocked by a proxy or firewall, not running or broken. |
| `NeverSeen` | RealmJoin knows the device but the agent has never reported a signed-in user on it, for example a device that was enrolled and never used, or a kiosk. |
| `MissingInRealmJoin` | The device exists in Intune but not in RealmJoin: the agent never registered it. |
| `MissingInIntune` | The device exists in RealmJoin but did not sync with Intune within the sync window. Not available together with a device name prefix, because RealmJoin devices carry no device name to match. |

`AgentStale` is always part of the report. The other categories are switched on with the *Include ...* choices. The Output Data tab of the run shows a summary and one table per category; the report files hold the same rows.

Whether the primary users of a device agree and who logs on to it are different questions; the **Report Primary User Mismatch (Scheduled)** runbook answers them.

### Why the gap and not the age

Comparing the RealmJoin timestamp with today would list every device that is simply switched off, for example during holidays. The gap compares the two sources with each other: a device that Intune has not seen either is not a problem of the RealmJoin agent. Only a device that keeps talking to Intune while RealmJoin hears nothing points to the agent. The default of 14 days matches the point at which the RealmJoin Portal marks a device as stale.

### What the RealmJoin timestamp means

The RealmJoin agent runs in the context of the signed-in user and reports every 15 minutes while someone is signed in. Every report updates the *last seen* of that user on that device and of the device itself. A device without a signed-in user, for example a kiosk device, a shared device without a signed-in account or a device that is only powered on for updates, does not produce a fresh timestamp and can show up as `AgentStale` although the agent is fine. Exclude such devices with *Exclude devices from group*, or raise the allowed gap.

The *Last Seen* column in the RealmJoin Portal is not the same value: the portal shows the newest of the agent contact, the Intune sync and the Entra ID sign-in activity. This report deliberately uses the agent contact only, because that is what tells whether the agent works.

### Plausibility line

The runbook also reads RealmJoin's own client statistics and prints how many clients RealmJoin counts as active. The threshold behind that count is a RealmJoin tenant setting (90 days by default), so the number is usually higher than the number of devices in sync here; a large difference in the other direction means the sync window or the allowed gap is set too tight for the tenant.

## Setup regarding RealmJoin API credentials

The runbook queries the RealmJoin customer API and needs a dedicated credential stored in the Azure Automation Account. The same credential serves every runbook that uses the API, so this is a one-time setup per Automation Account.

1. **Get API credentials** - If you do not yet have RealmJoin API credentials, request them at support@realmjoin.com. The username has the form `t-<tenant id>`, the password is the API secret. A portal login does not work here.
2. **Ask for the device users feature** - The device list of the customer API is a feature RealmJoin enables per tenant. Ask support to enable it together with the credentials; without it the API answers with HTTP 403 and the runbook stops with that message.
3. **Open the Automation Account** - In the Azure portal, open the Automation Account used for runbooks.
4. **Go to Shared Resources > Credentials** - In the left menu under *Shared Resources*, click *Credentials*.
5. **Add a new credential** - Click *Add a credential*.
6. **Name it exactly `RJAPI`** - The runbook looks up this name; any other name fails the credential lookup.
7. **Enter the API username and secret** - Use the values from step 1.
8. **Save** - Click *Create* and run the runbook again.

The API allows 30 requests per minute per tenant and answers with HTTP 429 beyond that. The runbook needs two requests per run and repeats a throttled request after a short delay, up to five times, before it gives up.

## Report delivery

The results always appear as named tables in the Output Data tab of the run in the RealmJoin portal. Report files are only generated when the **Report delivery** option includes an email and/or a download link; *Output Data only* creates no report files. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

## Setup regarding email sending

Sending an email report is optional and only happens when *Also email the report* or *Also email & download link* is selected as report delivery; a recipient is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** - public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** - target of the footer image
- **Accent and text color** - 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email - the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## Scheduling

Run the report weekly. Start with the default of 14 days for the allowed gap and a sync window of 30 days; lower the gap once the list is clean, or raise it when devices with long idle periods keep showing up.

A customization that fixes both values and delivers the report by email:

```json
"rjgit-org_devices_report-realmjoin-agent-contact_scheduled": {
    "parameters": {
        "SyncThresholdDays": {
            "Default": 30
        },
        "AgentContactThresholdDays": {
            "Default": 14
        },
        "EmailTo": {
            "Default": "endpoint-team@contoso.com"
        }
    }
}
```

See the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization) for the syntax.

## Notes and limitations

- Only Windows devices are compared, as the RealmJoin agent runs on Windows.
- The RealmJoin customer API exposes neither the agent version nor the Intune sync time per device; the comparison rests on the agent contact described above.
- The Intune primary user shown in the tables is the user recorded in Intune, not necessarily the user the agent last saw; both are listed for the `AgentStale` rows.

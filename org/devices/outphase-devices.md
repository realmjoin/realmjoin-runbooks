## Microsoft Defender for Endpoint exclusion tag

Microsoft Defender for Endpoint has a native **Exclusion state** (shown in the Device Inventory filter as *Excluded* / *Not Excluded*). This state can only be set through the Defender portal — there is **no API** to set a device's native exclusion state programmatically.

Because the native exclusion state cannot be automated, this runbook instead applies a custom device tag (default `ExcludeFromRemediation`) when *Exclude devices from Defender for Endpoint* is enabled. Each device in the list is looked up by its Entra ID device ID and tagged via `POST /api/machines/{id}/tags`, providing a marker that can be used to filter and target excluded devices.

### One-time setup: make the tag filterable

The portal's **Tags** filter only lists tags that were created through the portal. A tag set purely via the API is attached to the device and visible on the device page, but it does **not** appear in the Tags filter on its own.

To make the exclusion tag visible and usable for filtering in the [Defender Device Inventory](https://security.microsoft.com/machines), one client must be tagged manually once through the portal (select a device > **Manage tags** > "Create new tag", using the exact same tag value). After this one-time step the tag becomes a known, filterable tag, and this runbook can apply it to devices at scale.

> **Note:** This tag is only a label — it does not set the device's native Exclusion state and has no remediation effect on its own. It takes effect only if a Defender device group or automation rule is explicitly configured to match this tag value. Such rules match the tag value directly, independently of the portal **Tags** filter, so the one-time manual step only affects whether the tag is selectable for filtering in the portal UI.

Devices supplied by serial number that are not found in Intune have no Entra ID device ID and are therefore not tagged in Defender.

See [Create and manage device tags](https://learn.microsoft.com/defender-endpoint/machine-tags#create-tags) for details.

# List Mobile Devices

List managed mobile devices with inventory and network details

## Detailed description
Lists all Intune managed Android, iOS and iPadOS devices with their inventory: IMEI, serial number, phone number, carrier, ownership, compliance and enrollment. Optionally the last reported IP address and subnet, ICCID, eSIM identifier, cellular technology, UDID, battery health and Shared iPad state are added. That shows in which networks the devices were last active. The list can be limited by platform, a device group or a group of the primary users. The report can be sent by email or provided as a download link.

## Where to find
Org \ Devices \ List Mobile Devices

## Common use cases

- Inventory of all mobile devices including IMEI, serial number, phone number and carrier
- Identifying in which (Wi-Fi) networks mobile devices were last active, for example handheld scanners across warehouse locations
- Reviewing the compliance, supervision and encryption state of the mobile fleet
- SIM/eSIM inventory via ICCID and eSIM identifier
- Handing the full mobile inventory to asset management as an Excel workbook or CSV file

## Output columns

The runbook prints a summary block (device counts per platform, compliance state and ownership, applied filters and - with network details enabled - the number of devices without a reported IP address) followed by up to three tables. The same data can optionally be delivered as an email report and/or as a download link, see [Report delivery](#report-delivery).

### Inventory (always shown)

| Column | Source and meaning |
| --- | --- |
| DeviceName | Device name as reported by Intune |
| User | User principal name of the primary user |
| OS / OSVersion | Operating system (Android, iOS, iPadOS) and version |
| Manufacturer / Model | Hardware manufacturer and model |
| SerialNumber | Hardware serial number |
| IMEI | International Mobile Equipment Identity of the device |
| PhoneNumber | Phone number of the SIM - only present when `IncludePhoneNumber` is enabled, otherwise the column is omitted entirely |
| Carrier | Subscriber carrier of the SIM |
| Ownership | `company` or `personal` |
| Compliance | Intune compliance state |
| LastSync | Timestamp of the last successful Intune check-in |

### Security and enrollment (always shown)

| Column | Source and meaning |
| --- | --- |
| Supervised | iOS/iPadOS supervised mode |
| Encrypted | Device encryption state |
| Jailbroken | Whether the device is jailbroken or rooted |
| ThreatState | Threat state reported by a Mobile Threat Defense partner (only meaningful when an MTD partner is connected) |
| PatchLevel | Android security patch level (empty on iOS/iPadOS) |
| EnrollmentType / EnrollmentProfile | How the device was enrolled and the enrollment profile used |
| Category | Intune device category |
| FreeGB / TotalGB | Free and total storage (empty when the device reports no usable storage inventory, common for Android Enterprise work profiles) |
| Enrolled | Enrollment date |

### Network and SIM (only with `IncludeNetworkDetails` enabled - off by default)

| Column | Source and meaning |
| --- | --- |
| IPv4 / Subnet | Last IP address and subnet reported by the device - the closest indicator for the (Wi-Fi) network the device was last active in |
| WiFiMAC | Wi-Fi MAC address of the device |
| ICCID | Unique identification number of the SIM card |
| ESIM | eSIM identifier, when an eSIM is provisioned |
| Cellular | Cellular technology of the device |
| UDID | Unique device identifier (iOS/iPadOS) |
| BatteryHealth | Battery health percentage, where reported |
| Shared | Whether the device is a Shared iPad |
| LastSync | Timestamp of the last successful Intune check-in - tells how old the IP information is |

This table is sorted by subnet, so devices group visually by the network they were last seen in.

## Data freshness and limitations

All values describe the state of the last successful Intune device check-in, not necessarily the current state - always interpret them together with the LastSync column. Intune does not report the Wi-Fi SSID of a device; the last IP address and subnet are the closest network indicator. Note that the reported IP address can also stem from a cellular connection when the device last checked in over mobile data. Intune partially masks the phone number of personally owned devices regardless of the `IncludePhoneNumber` setting.

## Performance considerations

The network/SIM details are disabled by default and should be enabled with care on large tenants or with many mobile devices: Microsoft Graph returns these values only on a single-device request, not in the device list response. The runbook always sends these requests through the Graph batch endpoint in chunks of up to 20, but the runtime still grows linearly with the number of devices - thousands of mobile devices mean correspondingly long runs and an increased risk of Graph throttling (throttled requests are retried automatically with the wait time reported by Graph). On large environments, combine `IncludeNetworkDetails` with the group scope filters.

## Scope filtering

The scope can be limited to the members of an Entra device group (`IncludeDeviceGroup`) and/or to devices whose primary user is a member of a user group (`IncludeUserGroup`). When both filters are set, a device must match both. Transitive memberships are resolved, so members of nested groups are included.

## Report delivery

By default the runbook only prints the tables to the job output. Two optional delivery channels are available and can be combined:

- **Email report** (`EmailTo`): sends a summary email with the complete inventory attached as CSV and/or Excel workbook (`ReportFileFormat`, default `XLSX only`). Requires the `RJReport.EmailSender` setting; the email branding is taken from the `RJReport.Branding.*` settings as in the other report runbooks. When the CSV attachment exceeds the email size limit and `CSV & XLSX` is selected, the email falls back to the Excel workbook alone.
- **Download link** (`CreateDownloadLink`): uploads the report file(s) to the storage account configured in the `RJReport.StorageAccount.*` settings (container `list-mobile-devices` by default) and prints time-limited SAS download links in the job output. Suitable when the inventory is too large for an email attachment or should be handed to asset management directly.

The report files contain all columns of the tables above, including the `DeviceId`. The `PhoneNumber` and the network/SIM columns are only part of the files when the corresponding options are enabled. Non-compliant devices are highlighted in the Excel workbook. No files are created when no mobile device matches the selected platforms and filters.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All *(optional: Group scope filtering)*
  - Organization.Read.All *(optional: Email report / download link)*
  - Mail.Send *(optional: Email report)*

### Permission notes
Azure Storage Account: 'Storage Account Contributor' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required when CreateDownloadLink is used)


## Parameters
### Android
Includes Android devices.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### iOS
Includes iOS and iPadOS devices.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeNetworkDetails
Adds IP address, subnet, ICCID, eSIM identifier, cellular technology, UDID, battery health and Shared iPad state. Needs one extra request per device, so large tenants take longer.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludePhoneNumber
Shows the phone number column. Intune masks part of the number on personally owned devices anyway.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeDeviceGroup
Only devices in this Entra ID group, nested groups included. Leave empty for all mobile devices.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### IncludeUserGroup
Only devices whose primary user is in this group, nested groups included. Leave empty for all.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
Sender address of the report email. Taken from the tenant setting RJReport.EmailSender.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingHeaderImageUrl
Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl
Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink
Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingAccentColor
Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor
Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ReportFileFormat
Deliver the report as CSV, as an Excel workbook, or both.

| Property | Value |
|----------|-------|
| Default Value | XLSX only |
| Required | false |
| Type | String |

### CreateDownloadLink
Also upload the report and return a download link that expires after a few days.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Set per runbook.

| Property | Value |
|----------|-------|
| Default Value | list-mobile-devices |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LinkExpiryDays
Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |

### EmailTo
Send the report to these addresses, separated by commas. Leave empty to only show the result in the run output.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


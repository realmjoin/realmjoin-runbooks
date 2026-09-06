# List Mobile Devices

Lists all managed mobile devices (Android, iOS/iPadOS) with mobile-specific inventory, security and network details.

## Detailed description
Lists all Intune managed mobile devices with their mobile-specific inventory such as IMEI, serial number, phone number,
carrier, ownership, compliance and enrollment details.
Optionally the last reported IP address and subnet, ICCID, eSIM identifier, cellular technology, UDID, battery health
and Shared iPad state are added per device, which helps to see in which (Wi-Fi) networks the devices were last active.
The result can be narrowed down by platform and by an Entra device group and/or a user group of the primary users.
Optionally the full inventory is sent as an email report with CSV and/or Excel (xlsx) attachments and/or uploaded to an
Azure Storage Account, returning time-limited download links. Without a recipient and without the download link option,
the runbook only prints the result to the job output.
The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

## Where to find
Org \ Devices \ List Mobile Devices

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

The network/SIM details are disabled by default and should be enabled with care on large tenants or with many mobile devices: Microsoft Graph returns these values only on a single-device request, not in the device list response. The runbook always sends these requests through the Graph batch endpoint in chunks of up to 20, but the runtime still grows linearly with the number of devices - thousands of mobile devices mean correspondingly long runs and an increased risk of Graph throttling (throttled requests are retried once). On large environments, combine `IncludeNetworkDetails` with the group scope filters.

## Scope filtering

The scope can be limited to the members of an Entra device group (`IncludeDeviceGroup`) and/or to devices whose primary user is a member of a user group (`IncludeUserGroup`). When both filters are set, a device must match both. Transitive memberships are resolved, so members of nested groups are included.

## Report delivery

By default the runbook only prints the tables to the job output. Two optional delivery channels are available and can be combined:

- **Email report** (`EmailTo`): sends a summary email with the complete inventory attached as CSV and/or Excel workbook (`ReportFileFormat`, default `XLSX only`). Requires the `RJReport.EmailSender` setting; the email branding is taken from the `RJReport.Branding.*` settings as in the other report runbooks. When the CSV attachment exceeds the email size limit and `CSV & XLSX` is selected, the email falls back to the Excel workbook alone.
- **Download link** (`CreateDownloadLink`): uploads the report file(s) to the storage account configured in the `RJReport.StorageAccount.*` settings (container `list-mobile-devices` by default) and prints time-limited SAS download links in the job output. Suitable when the inventory is too large for an email attachment or should be handed to asset management directly.

The report files contain all columns of the tables above, including the `DeviceId`. The `PhoneNumber` and the network/SIM columns are only part of the files when the corresponding options are enabled. Non-compliant devices are highlighted in the Excel workbook. No files are created when no mobile device matches the selected platforms and filters.


## Notes
Intune does not report the Wi-Fi SSID of a device. The last reported IP address and subnet are the closest network
indicator and should always be interpreted together with the Last Sync column, because they describe the state of the
last successful device check-in - which can also have happened over cellular.

Prerequisites:
- EmailFrom parameter must be configured in runbook customization (RJReport.EmailSender setting) when an email report is requested
- RJReport.StorageAccount.* settings must be configured when a download link is requested

Data source and freshness:
All values are taken from the Intune inventory of each device, which is refreshed with the regular device check-in.
They therefore describe the state of the last successful check-in and not necessarily the current state.
The network and SIM details (IP address, subnet, ICCID, UDID, ...) are not part of the Graph device list response and
are retrieved with one additional Graph request per device, sent through the Graph batch endpoint in chunks of up to 20.

Performance:
The network/SIM details are disabled by default. When enabled, the runtime grows linearly with the number of mobile
devices. On tenants with many mobile devices, combine the option with the group scope filters.

Common Use Cases:
- Inventory of all mobile devices including IMEI, serial number, phone number and carrier
- Identifying in which (Wi-Fi) networks mobile devices were last active, e.g. handheld scanners across warehouse locations
- Reviewing compliance, supervision and encryption state of the mobile fleet
- SIM/eSIM inventory via ICCID and eSIM identifier
- Handing the full mobile inventory to asset management as an Excel workbook or CSV file

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
Include Android devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### iOS
Include iOS and iPadOS devices in the results.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeNetworkDetails
Adds last reported IP address and subnet, ICCID, eSIM identifier, cellular technology, UDID, battery health and Shared
iPad state to the output. Requires one additional Graph request per device (sent in batches of 20), so the runtime grows
with the number of devices. Disabled by default.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludePhoneNumber
Controls whether the phone number is retrieved and shown. When disabled, the phone number column is omitted entirely.
Note that Intune partially masks the phone number of personally owned devices anyway.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeDeviceGroup
Only include devices that are members of this Entra device group. Nested group memberships are resolved. Leave empty to include all mobile devices.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### IncludeUserGroup
Only include devices whose primary user is a member of this Entra user group. Nested group memberships are resolved. Leave empty to include all mobile devices.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
The sender email address. This needs to be configured in the runbook customization

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingHeaderImageUrl
Optional public HTTPS URL of a custom header image (PNG/JPEG/GIF, max. 200 KB) for the report email.
Sourced from the RJReport.Branding.HeaderImageUrl tenant setting. When empty, the default RealmJoin header graphic is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl
Optional public HTTPS URL of a custom footer image (PNG/JPEG/GIF, max. 200 KB) for the report email.
Sourced from the RJReport.Branding.FooterImageUrl tenant setting. When empty, the default RealmJoin footer graphic is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink
Optional URL the footer image links to. Sourced from the RJReport.Branding.FooterLink tenant setting.
When empty, the default link (https://www.realmjoin.com) is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingAccentColor
Optional accent color override (6-digit hex, e.g. '#0052cc') for the report email template.
Sourced from the RJReport.Branding.AccentColor tenant setting. When empty or invalid, the default RealmJoin accent color is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor
Optional text color override (6-digit hex) for the report email template.
Sourced from the RJReport.Branding.TextColor tenant setting. When empty or invalid, the default RealmJoin text color is used.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ReportFileFormat
Controls which report file formats are generated and delivered: "CSV only", "CSV & XLSX" or "XLSX only" (default).

| Property | Value |
|----------|-------|
| Default Value | XLSX only |
| Required | false |
| Type | String |

### CreateDownloadLink
If enabled, the report files are uploaded to an Azure Storage Account and time-limited download links are returned. Disabled by default.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

| Property | Value |
|----------|-------|
| Default Value | list-mobile-devices |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group that contains the storage account. Sourced from the RJReport tenant settings.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account name used for the upload. Sourced from the RJReport tenant settings.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LinkExpiryDays
Number of days until the generated download link expires. Sourced from the RJReport tenant settings.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |

### EmailTo
If specified, an email with the report will be sent to the provided address(es).
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


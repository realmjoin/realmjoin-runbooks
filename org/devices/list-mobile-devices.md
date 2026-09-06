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

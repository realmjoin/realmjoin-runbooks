# List Mobile Devices

Lists all managed mobile devices (Android, iOS/iPadOS) with mobile-specific inventory, security and network details.

## Detailed description
Lists all Intune managed mobile devices with their mobile-specific inventory such as IMEI, serial number, phone number,
carrier, ownership, compliance and enrollment details.
Optionally the last reported IP address and subnet, ICCID, eSIM identifier, cellular technology, UDID, battery health
and Shared iPad state are added per device, which helps to see in which (Wi-Fi) networks the devices were last active.
The result can be narrowed down by platform and by an Entra device group and/or a user group of the primary users.

## Where to find
Org \ Devices \ List Mobile Devices

## Output columns

The runbook prints a summary block (device counts per platform, compliance state and ownership, applied filters and - with network details enabled - the number of devices without a reported IP address) followed by up to three tables.

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

### Network and SIM (only with `IncludeNetworkDetails` enabled)

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

Use the network/SIM details with care on large tenants or with many mobile devices: Microsoft Graph returns these values only on a single-device request, not in the device list response. The runbook always sends these requests through the Graph batch endpoint in chunks of up to 20, but the runtime still grows linearly with the number of devices - thousands of mobile devices mean correspondingly long runs and an increased risk of Graph throttling (throttled requests are retried once). On large environments, combine `IncludeNetworkDetails` with the group scope filters, or disable it when only inventory data is needed.

## Scope filtering

The scope can be limited to the members of an Entra device group (`IncludeDeviceGroup`) and/or to devices whose primary user is a member of a user group (`IncludeUserGroup`). When both filters are set, a device must match both. Transitive memberships are resolved, so members of nested groups are included.


## Notes
Intune does not report the Wi-Fi SSID of a device. The last reported IP address and subnet are the closest network
indicator and should always be interpreted together with the Last Sync column, because they describe the state of the
last successful device check-in - which can also have happened over cellular.

Data source and freshness:
All values are taken from the Intune inventory of each device, which is refreshed with the regular device check-in.
They therefore describe the state of the last successful check-in and not necessarily the current state.
The network and SIM details (IP address, subnet, ICCID, UDID, ...) are not part of the Graph device list response and
are retrieved with one additional Graph request per device, sent through the Graph batch endpoint in chunks of up to 20.

Performance:
With network/SIM details enabled the runtime grows linearly with the number of mobile devices. On tenants with many
mobile devices, combine the option with the group scope filters or disable it when only inventory data is needed.

Common Use Cases:
- Inventory of all mobile devices including IMEI, serial number, phone number and carrier
- Identifying in which (Wi-Fi) networks mobile devices were last active, e.g. handheld scanners across warehouse locations
- Reviewing compliance, supervision and encryption state of the mobile fleet
- SIM/eSIM inventory via ICCID and eSIM identifier

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Directory.Read.All *(optional: Group scope filtering)*


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
with the number of devices.

| Property | Value |
|----------|-------|
| Default Value | True |
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


[Back to Table of Content](../../../README.md)


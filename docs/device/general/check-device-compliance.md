# Check Device Compliance

Check the compliance status of a device

## Detailed description
This runbook retrieves the compliance status of a managed device from Microsoft Intune.
In simple mode it shows the overall compliance state and lists any non-compliant policies. In detailed mode it additionally shows which specific settings are failing and the reason for each failure.
Optionally, a report with the full compliance details can be sent via email.

## Where to find
Device \ General \ Check Device Compliance

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Device.Read.All
  - DeviceManagementManagedDevices.Read.All
  - Organization.Read.All


## Parameters
### DeviceId
The Entra ID device ID of the target device. Passed automatically by the RealmJoin platform.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### DetailedOutput
Select "Simple" (final value: $false) to show only the overall compliance state and non-compliant policy names.
Select "Detailed" (final value: $true) to additionally show which specific settings are failing and the reason for each failure.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Optional - if specified, a compliance report will be sent to the provided email address(es).
Can be a single address or multiple comma-separated addresses.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
The sender email address. This needs to be configured in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


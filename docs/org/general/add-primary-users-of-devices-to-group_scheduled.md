# Add Primary Users Of Devices To Group (Scheduled)

Sync primary users of Intune managed devices by platform into an Entra ID group

## Detailed description
This runbook collects the primary users of all Intune managed devices matching the selected platform(s) and synchronizes them into a target Entra ID group. Users no longer assigned as primary user on any matching device are removed from the group. An optional include group restricts which users are eligible, and an optional exclude group prevents specific users from being added or keeps them removed.

## Where to find
Org \ General \ Add Primary Users Of Devices To Group_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - Group.Read.All
  - GroupMember.ReadWrite.All
  - User.Read.All


## Parameters
### TargetGroupId
The Entra ID group to synchronize primary users into. Members of this group will be managed exclusively by this runbook.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Windows
Include primary users of Windows devices. (OData Filter used "operatingSystem eq 'Windows'")

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### MacOS
Include primary users of macOS devices. (OData Filter used "operatingSystem eq 'macOS'")

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### iOS
Include primary users of iOS and iPadOS devices. (OData Filter used "operatingSystem eq 'iOS'")

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### Android
Include primary users of Android devices. (OData Filter used "operatingSystem eq 'Android'")

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### AdvancedFilter
Optional. Custom OData filter to apply when retrieving devices. Overrides the platform-based filters if provided. Example: startsWith(deviceName,'FWP-') and operatingSystem eq 'Windows' .

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### RemoveUsersWhenNoDeviceMatch
When enabled (default), users who no longer have a primary device matching the selected platform(s) are removed from the target group. Disable to add-only mode — existing members are never removed.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeGroupId
Optional. Only users who are members of this group are eligible to be added to the target group. Leave empty to consider all primary users.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ExcludeGroupId
Optional. Users who are members of this group will not be added and will be removed from the target group if already present.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


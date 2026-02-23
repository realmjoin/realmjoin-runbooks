# Set Room Mailbox Configuration

Set room mailbox resource policies

## Detailed description
Updates room mailbox settings such as booking policy, calendar processing, and capacity. The runbook can optionally restrict BookInPolicy to members of a specific mail-enabled security group.

## Where to find
User \ Mail \ Set Room Mailbox Configuration

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online API
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### UserName
User principal name of the room mailbox.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### AllBookInPolicy
"Allow BookIn for everyone" (final value: $true) or "Custom BookIn Policy" (final value: $false) can be selected as action to perform. If set to true, the room will allow BookIn for everyone and the BookInPolicyGroup parameter will be ignored. If set to false, only members of the group specified in the BookInPolicyGroup parameter will be allowed to BookIn.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookInPolicyGroup
Group whose members are allowed to book when AllBookInPolicy is false.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### AllowRecurringMeetings
If set to true, allows recurring meetings.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### AutomateProcessing
Calendar processing mode for the room mailbox.

| Property | Value |
|----------|-------|
| Default Value | AutoAccept |
| Required | false |
| Type | String |

### BookingWindowInDays
How many days into the future bookings are allowed.

| Property | Value |
|----------|-------|
| Default Value | 180 |
| Required | false |
| Type | Int32 |

### MaximumDurationInMinutes
Maximum meeting duration in minutes.

| Property | Value |
|----------|-------|
| Default Value | 1440 |
| Required | false |
| Type | Int32 |

### AllowConflicts
If set to true, allows scheduling conflicts.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### Capacity
Capacity to set for the room when greater than 0.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)


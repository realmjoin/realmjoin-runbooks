# Set Room Mailbox Configuration

Configure the booking rules of this room mailbox

## Detailed description
Sets the booking rules of this room mailbox: who may book it, whether recurring meetings and conflicts are allowed, and how requests are processed. It also sets how far ahead and how long meetings may be, and the room capacity. All booking settings are written as shown; the capacity only when it is greater than 0.

## Where to find
User \ Mail \ Set Room Mailbox Configuration

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp
- **Type**: Microsoft Graph
  - Group.Read.All *(optional: Book-in policy group)*

### RBAC roles
- Exchange Administrator


## Parameters
### UserName
User principal name of the room mailbox the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### AllBookInPolicy
Everyone lets all users book the room. Only members of a group restricts booking to the "Booking group".

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookInPolicyGroup
Mail-enabled security group whose members may book the room.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### AllowRecurringMeetings
Turn off to decline recurring meeting requests; single meetings are still accepted.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### AutomateProcessing
Auto accept books the room automatically. Auto update only marks requests as tentative for a delegate to decide. None leaves requests untouched.

| Property | Value |
|----------|-------|
| Default Value | AutoAccept |
| Required | false |
| Type | String |

### BookingWindowInDays
Requests further ahead than this many days are declined.

| Property | Value |
|----------|-------|
| Default Value | 180 |
| Required | false |
| Type | Int32 |

### MaximumDurationInMinutes
Longest meeting the room accepts, in minutes.

| Property | Value |
|----------|-------|
| Default Value | 1440 |
| Required | false |
| Type | Int32 |

### AllowConflicts
Lets overlapping bookings through instead of declining them.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### Capacity
Number of seats. Leave at 0 to keep the current value.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)


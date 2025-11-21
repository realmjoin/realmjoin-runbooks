# Set Booking Config

Configure Microsoft Bookings settings for the organization.

## Detailed description
Configure Microsoft Bookings settings at the organization level, including booking policies,
naming conventions, and access restrictions. Optionally creates an OWA mailbox policy for
Bookings creators and disables Bookings in the default OWA policy.

## Where to find
Org \ Mail \ Set Booking Config

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### -BookingsEnabled

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -BookingsAuthEnabled

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -BookingsSocialSharingRestricted

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -BookingsExposureOfStaffDetailsRestricted

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -BookingsMembershipApprovalRequired

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -BookingsSmsMicrosoftEnabled

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -BookingsSearchEngineIndexDisabled

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -BookingsAddressEntryRestricted

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -BookingsCreationOfCustomQuestionsRestricted

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -BookingsNotesEntryRestricted

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -BookingsPhoneNumberEntryRestricted

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -BookingsNamingPolicyEnabled

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -BookingsBlockedWordsEnabled

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -BookingsNamingPolicyPrefixEnabled

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -BookingsNamingPolicyPrefix

| Property | Value |
|----------|-------|
| Default Value | Booking- |
| Required | false |
| Type | String |

### -BookingsNamingPolicySuffixEnabled

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### -BookingsNamingPolicySuffix

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### -CreateOwaPolicy

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### -OwaPolicyName

| Property | Value |
|----------|-------|
| Default Value | BookingsCreators |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


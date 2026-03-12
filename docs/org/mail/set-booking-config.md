# Set Booking Config

Configure Microsoft Bookings settings for the organization

## Detailed description
Configures Microsoft Bookings settings at the organization level using Exchange Online organization configuration. The runbook can optionally create an OWA mailbox policy for Bookings creators and disable Bookings in the default OWA policy.

## Where to find
Org \ Mail \ Set Booking Config

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange administrator


## Parameters
### BookingsEnabled
If set to true, Microsoft Bookings is enabled for the organization.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookingsAuthEnabled
If set to true, Bookings uses authentication.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsSocialSharingRestricted
If set to true, social sharing is restricted.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsExposureOfStaffDetailsRestricted
If set to true, exposure of staff details is restricted.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookingsMembershipApprovalRequired
If set to true, membership approval is required.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookingsSmsMicrosoftEnabled
If set to true, Microsoft SMS notifications are enabled.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookingsSearchEngineIndexDisabled
If set to true, search engine indexing is disabled.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsAddressEntryRestricted
If set to true, address entry is restricted.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsCreationOfCustomQuestionsRestricted
If set to true, creation of custom questions is restricted.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsNotesEntryRestricted
If set to true, notes entry is restricted.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsPhoneNumberEntryRestricted
If set to true, phone number entry is restricted.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsNamingPolicyEnabled
If set to true, naming policies are enabled.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookingsBlockedWordsEnabled
If set to true, blocked words are enabled for naming policies.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsNamingPolicyPrefixEnabled
If set to true, the naming policy prefix is enabled.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookingsNamingPolicyPrefix
Prefix applied by the naming policy.

| Property | Value |
|----------|-------|
| Default Value | Booking- |
| Required | false |
| Type | String |

### BookingsNamingPolicySuffixEnabled
If set to true, the naming policy suffix is enabled.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsNamingPolicySuffix
Suffix applied by the naming policy.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CreateOwaPolicy
If set to true, an OWA mailbox policy for Bookings creators is created if missing.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### OwaPolicyName
Name of the OWA mailbox policy to create or use for Bookings creators.

| Property | Value |
|----------|-------|
| Default Value | BookingsCreators |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


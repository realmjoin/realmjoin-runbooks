# Set Booking Config

Configure the Microsoft Bookings settings of the tenant

## Detailed description
Sets the tenant-wide Microsoft Bookings settings in Exchange Online, such as whether Bookings is on, what customers may enter and how booking pages are named. Optionally an Outlook web policy for Bookings creators is created and Bookings is turned off in the default policy, so only members of that policy can create booking pages.

## Where to find
Org \ Mail \ Set Booking Config

## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- Exchange Administrator


## Parameters
### BookingsEnabled
Turns Microsoft Bookings on for the tenant.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookingsAuthEnabled
Customers must sign in before they can book.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsSocialSharingRestricted
Removes the social sharing options from booking pages.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsExposureOfStaffDetailsRestricted
Keeps staff details such as email addresses off the booking pages.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookingsMembershipApprovalRequired
Staff must approve before they are added to a booking page.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookingsSmsMicrosoftEnabled
Customers can get SMS notifications about their bookings.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookingsSearchEngineIndexDisabled
Keeps booking pages out of search engine results.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsAddressEntryRestricted
Customers cannot enter their address when booking.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsCreationOfCustomQuestionsRestricted
Staff cannot add custom questions to booking forms.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsNotesEntryRestricted
Customers cannot add notes when booking.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsPhoneNumberEntryRestricted
Customers cannot enter their phone number when booking.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsNamingPolicyEnabled
Applies the prefix, suffix and blocked words rules to new booking page names.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookingsBlockedWordsEnabled
Rejects booking page names that contain a word from the blocked words list of the Microsoft 365 groups naming policy.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsNamingPolicyPrefixEnabled
Adds the prefix to every new booking page name.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### BookingsNamingPolicyPrefix
Text put in front of new booking page names.

| Property | Value |
|----------|-------|
| Default Value | Booking- |
| Required | false |
| Type | String |

### BookingsNamingPolicySuffixEnabled
Adds the suffix to every new booking page name.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### BookingsNamingPolicySuffix
Text appended to new booking page names.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CreateOwaPolicy
Creates the Outlook web policy for Bookings creators if it is missing and turns off Bookings in the default policy.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### OwaPolicyName
Name of the Outlook web policy for Bookings creators.

| Property | Value |
|----------|-------|
| Default Value | BookingsCreators |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


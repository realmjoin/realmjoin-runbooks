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
Description: 
Default Value: True
Required: false

### -BookingsAuthEnabled
Description: 
Default Value: False
Required: false

### -BookingsSocialSharingRestricted
Description: 
Default Value: False
Required: false

### -BookingsExposureOfStaffDetailsRestricted
Description: 
Default Value: True
Required: false

### -BookingsMembershipApprovalRequired
Description: 
Default Value: True
Required: false

### -BookingsSmsMicrosoftEnabled
Description: 
Default Value: True
Required: false

### -BookingsSearchEngineIndexDisabled
Description: 
Default Value: False
Required: false

### -BookingsAddressEntryRestricted
Description: 
Default Value: False
Required: false

### -BookingsCreationOfCustomQuestionsRestricted
Description: 
Default Value: False
Required: false

### -BookingsNotesEntryRestricted
Description: 
Default Value: False
Required: false

### -BookingsPhoneNumberEntryRestricted
Description: 
Default Value: False
Required: false

### -BookingsNamingPolicyEnabled
Description: 
Default Value: True
Required: false

### -BookingsBlockedWordsEnabled
Description: 
Default Value: False
Required: false

### -BookingsNamingPolicyPrefixEnabled
Description: 
Default Value: True
Required: false

### -BookingsNamingPolicyPrefix
Description: 
Default Value: Booking-
Required: false

### -BookingsNamingPolicySuffixEnabled
Description: 
Default Value: False
Required: false

### -BookingsNamingPolicySuffix
Description: 
Default Value: 
Required: false

### -CreateOwaPolicy
Description: 
Default Value: True
Required: false

### -OwaPolicyName
Description: 
Default Value: BookingsCreators
Required: false


[Back to Table of Content](../../../README.md)


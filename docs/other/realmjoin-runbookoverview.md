<a name='runbook-overview'></a>
# RealmJoin runbook overview
This document provides a comprehensive overview of all runbooks currently available in the RealmJoin portal. Each runbook is listed along with a brief description or synopsis to give a clear understanding of its purpose and functionality.

To ensure easy navigation, the runbooks are categorized into different sections based on their area of application. The following categories are currently available:
- device
- group
- org
- user

Each category contains multiple runbooks that are further divided into subcategories based on their functionality. The runbooks are listed in alphabetical order within each subcategory.

# Runbooks - Table of contents

- [Device](#device)
  - [Avd](#device-avd)
      - [Restart Host](#restart-host)
      - [Toggle Drain Mode](#toggle-drain-mode)
  - [General](#device-general)
      - [Change Grouptag](#change-grouptag)
      - [Check Updatable Assets](#check-updatable-assets)
      - [Enroll Updatable Assets](#enroll-updatable-assets)
      - [Outphase Device](#outphase-device)
      - [Remove Primary User](#remove-primary-user)
      - [Rename Device](#rename-device)
      - [Unenroll Updatable Assets](#unenroll-updatable-assets)
      - [Wipe Device](#wipe-device)
  - [Security](#device-security)
      - [Enable Or Disable Device](#enable-or-disable-device)
      - [Isolate Or Release Device](#isolate-or-release-device)
      - [Reset Mobile Device Pin](#reset-mobile-device-pin)
      - [Restrict Or Release Code Execution](#restrict-or-release-code-execution)
      - [Show Laps Password](#show-laps-password)
- [Group](#group)
  - [Devices](#group-devices)
      - [Check Updatable Assets](#check-updatable-assets)
      - [Unenroll Updatable Assets](#unenroll-updatable-assets)
  - [General](#group-general)
      - [Add Or Remove Nested Group](#add-or-remove-nested-group)
      - [Add Or Remove Owner](#add-or-remove-owner)
      - [Add Or Remove User](#add-or-remove-user)
      - [Change Visibility](#change-visibility)
      - [List All Members](#list-all-members)
      - [List Owners](#list-owners)
      - [List User Devices](#list-user-devices)
      - [Remove Group](#remove-group)
      - [Rename Group](#rename-group)
  - [Mail](#group-mail)
      - [Enable Or Disable External Mail](#enable-or-disable-external-mail)
      - [Show Or Hide In Address Book](#show-or-hide-in-address-book)
  - [Teams](#group-teams)
      - [Archive Team](#archive-team)
- [Org](#org)
  - [Applications](#org-applications)
      - [Add Application Registration](#add-application-registration)
      - [Delete Application Registration](#delete-application-registration)
      - [Export Enterprise App Users](#export-enterprise-app-users)
      - [List Application Creds Expiry](#list-application-creds-expiry)
      - [List Inactive Enterprise Apps](#list-inactive-enterprise-apps)
      - [Report App Registration](#report-app-registration)
      - [Update Application Registration](#update-application-registration)
  - [Devices](#org-devices)
      - [Delete Stale Devices_Scheduled](#delete-stale-devices_scheduled)
      - [Get Bitlocker Recovery Key](#get-bitlocker-recovery-key)
      - [List Stale Devices_Scheduled](#list-stale-devices_scheduled)
      - [Outphase Devices](#outphase-devices)
      - [Report Devices Without Primary User](#report-devices-without-primary-user)
      - [Report Last Device Contact By Range](#report-last-device-contact-by-range)
      - [Report Users With More Than 5-Devices](#report-users-with-more-than-5-devices)
      - [Sync Device Serialnumbers To Entraid_Scheduled](#sync-device-serialnumbers-to-entraid_scheduled)
  - [General](#org-general)
      - [Add Autopilot Device](#add-autopilot-device)
      - [Add Device Via Corporate Identifier](#add-device-via-corporate-identifier)
      - [Add Devices Of Users To Group_Scheduled](#add-devices-of-users-to-group_scheduled)
      - [Add Management Partner](#add-management-partner)
      - [Add Microsoft Store App Logos](#add-microsoft-store-app-logos)
      - [Add Office365 Group](#add-office365-group)
      - [Add Or Remove Safelinks Exclusion](#add-or-remove-safelinks-exclusion)
      - [Add Or Remove Smartscreen Exclusion](#add-or-remove-smartscreen-exclusion)
      - [Add Or Remove Trusted Site](#add-or-remove-trusted-site)
      - [Add Security Group](#add-security-group)
      - [Add User](#add-user)
      - [Add Viva Engange Community](#add-viva-engange-community)
      - [Assign Groups By Template_Scheduled](#assign-groups-by-template_scheduled)
      - [Bulk Delete Devices From Autopilot](#bulk-delete-devices-from-autopilot)
      - [Bulk Retire Devices From Intune](#bulk-retire-devices-from-intune)
      - [Check Aad Sync Status_Scheduled](#check-aad-sync-status_scheduled)
      - [Check Assignments Of Devices](#check-assignments-of-devices)
      - [Check Assignments Of Groups](#check-assignments-of-groups)
      - [Check Assignments Of Users](#check-assignments-of-users)
      - [Check Autopilot Serialnumbers](#check-autopilot-serialnumbers)
      - [Check Device Onboarding Exclusion_Schedule](#check-device-onboarding-exclusion_schedule)
      - [Enrolled Devices Report_Scheduled](#enrolled-devices-report_scheduled)
      - [Export All Autopilot Devices](#export-all-autopilot-devices)
      - [Export All Intune Devices](#export-all-intune-devices)
      - [Export Cloudpc Usage_Scheduled](#export-cloudpc-usage_scheduled)
      - [Export Non Compliant Devices](#export-non-compliant-devices)
      - [Export Policy Report](#export-policy-report)
      - [Invite External Guest Users](#invite-external-guest-users)
      - [List All Administrative Template Policies](#list-all-administrative-template-policies)
      - [List Group License Assignment Errors](#list-group-license-assignment-errors)
      - [Office365 License Report](#office365-license-report)
      - [Report Apple Mdm Cert Expiry_Scheduled](#report-apple-mdm-cert-expiry_scheduled)
      - [Report Pim Activations_Scheduled](#report-pim-activations_scheduled)
      - [Sync All Devices](#sync-all-devices)
  - [Mail](#org-mail)
      - [Add Distribution List](#add-distribution-list)
      - [Add Equipment Mailbox](#add-equipment-mailbox)
      - [Add Or Remove Public Folder](#add-or-remove-public-folder)
      - [Add Or Remove Teams Mailcontact](#add-or-remove-teams-mailcontact)
      - [Add Room Mailbox](#add-room-mailbox)
      - [Add Shared Mailbox](#add-shared-mailbox)
      - [Hide Mailboxes_Scheduled](#hide-mailboxes_scheduled)
      - [Set Booking Config](#set-booking-config)
  - [Phone](#org-phone)
      - [Get Teams Phone Number Assignment](#get-teams-phone-number-assignment)
  - [Security](#org-security)
      - [Add Defender Indicator](#add-defender-indicator)
      - [Backup Conditional Access Policies](#backup-conditional-access-policies)
      - [List Admin Users](#list-admin-users)
      - [List Expiring Role Assignments](#list-expiring-role-assignments)
      - [List Inactive Devices](#list-inactive-devices)
      - [List Inactive Users](#list-inactive-users)
      - [List Information Protection Labels](#list-information-protection-labels)
      - [List Pim Rolegroups Without Owners_Scheduled](#list-pim-rolegroups-without-owners_scheduled)
      - [List Users By MFA Methods Count](#list-users-by-mfa-methods-count)
      - [List Vulnerable App Regs](#list-vulnerable-app-regs)
      - [Notify Changed CA Policies](#notify-changed-ca-policies)
- [User](#user)
  - [Avd](#user-avd)
      - [User Signout](#user-signout)
  - [General](#user-general)
      - [Assign Groups By Template](#assign-groups-by-template)
      - [Assign Or Unassign License](#assign-or-unassign-license)
      - [Assign Windows365](#assign-windows365)
      - [List Group Ownerships](#list-group-ownerships)
      - [List Manager](#list-manager)
      - [Offboard User Permanently](#offboard-user-permanently)
      - [Offboard User Temporarily](#offboard-user-temporarily)
      - [Reprovision Windows365](#reprovision-windows365)
      - [Resize Windows365](#resize-windows365)
      - [Unassign Windows365](#unassign-windows365)
  - [Mail](#user-mail)
      - [Add Or Remove Email Address](#add-or-remove-email-address)
      - [Assign Owa Mailbox Policy](#assign-owa-mailbox-policy)
      - [Convert To Shared Mailbox](#convert-to-shared-mailbox)
      - [Delegate Full Access](#delegate-full-access)
      - [Delegate Send As](#delegate-send-as)
      - [Delegate Send On Behalf](#delegate-send-on-behalf)
      - [Hide Or Unhide In Addressbook](#hide-or-unhide-in-addressbook)
      - [List Mailbox Permissions](#list-mailbox-permissions)
      - [List Room Mailbox Configuration](#list-room-mailbox-configuration)
      - [Remove Mailbox](#remove-mailbox)
      - [Set Out Of Office](#set-out-of-office)
      - [Set Room Mailbox Configuration](#set-room-mailbox-configuration)
  - [Phone](#user-phone)
      - [Disable Teams Phone](#disable-teams-phone)
      - [Get Teams User Info](#get-teams-user-info)
      - [Grant Teams User Policies](#grant-teams-user-policies)
      - [Set Teams Permanent Call Forwarding](#set-teams-permanent-call-forwarding)
      - [Set Teams Phone](#set-teams-phone)
  - [Security](#user-security)
      - [Confirm Or Dismiss Risky User](#confirm-or-dismiss-risky-user)
      - [Create Temporary Access Pass](#create-temporary-access-pass)
      - [Enable Or Disable Password Expiration](#enable-or-disable-password-expiration)
      - [Reset Mfa](#reset-mfa)
      - [Reset Password](#reset-password)
      - [Revoke Or Restore Access](#revoke-or-restore-access)
      - [Set Or Remove Mobile Phone Mfa](#set-or-remove-mobile-phone-mfa)
  - [Userinfo](#user-userinfo)
      - [Rename User](#rename-user)
      - [Set Photo](#set-photo)
      - [Update User](#update-user)

<a name='device'></a>

# Device
<a name='device-avd'></a>

## Avd
<a name='device-avd-restart-host'></a>

### Restart Host
#### Reboots a specific AVD Session Host.

#### Description
This Runbook reboots a specific AVD Session Host. If Users are signed in, they will be disconnected. In any case, Drain Mode will be enabled and the Session Host will be restarted.
If the SessionHost is not running, it will be started. Once the Session Host is running, Drain Mode is disabled again.

#### Where to find
Device \ Avd \ Restart Host


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-avd-toggle-drain-mode'></a>

### Toggle Drain Mode
#### Sets Drainmode on true or false for a specific AVD Session Host.

#### Description
This Runbooks looks through all AVD Hostpools of a tenant and sets the DrainMode for a specific Session Host.
The SubscriptionId value must be defined in the runbooks customization.

#### Where to find
Device \ Avd \ Toggle Drain Mode


[Back to Table of Content](#table-of-contents)

 
 

<a name='device'></a>

# Device
<a name='device-general'></a>

## General
<a name='device-general-change-grouptag'></a>

### Change Grouptag
#### Assign a new AutoPilot GroupTag to this device.

#### Description
Assign a new AutoPilot GroupTag to this device.

#### Where to find
Device \ General \ Change Grouptag


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-check-updatable-assets'></a>

### Check Updatable Assets
#### Check if a device is onboarded to Windows Update for Business.

#### Description
This script checks if single device is onboarded to Windows Update for Business.

#### Where to find
Device \ General \ Check Updatable Assets


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-enroll-updatable-assets'></a>

### Enroll Updatable Assets
#### Enroll device into Windows Update for Business.

#### Description
This script enrolls devices into Windows Update for Business.

#### Where to find
Device \ General \ Enroll Updatable Assets


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-outphase-device'></a>

### Outphase Device
#### Remove/Outphase a windows device

#### Description
Remove/Outphase a windows device. You can choose if you want to wipe the device and/or delete it from Intune an AutoPilot.

#### Where to find
Device \ General \ Outphase Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-remove-primary-user'></a>

### Remove Primary User
#### Removes the primary user from a device.

#### Description
This script removes the assigned primary user from a specified Azure AD device.
It requires the DeviceId of the target device and the name of the caller for auditing purposes.

#### Where to find
Device \ General \ Remove Primary User


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-rename-device'></a>

### Rename Device
#### Rename a device.

#### Description
Rename a device (in Intune and Autopilot).

#### Where to find
Device \ General \ Rename Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-unenroll-updatable-assets'></a>

### Unenroll Updatable Assets
#### Unenroll device from Windows Update for Business.

#### Description
This script unenrolls devices from Windows Update for Business.

#### Where to find
Device \ General \ Unenroll Updatable Assets


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-wipe-device'></a>

### Wipe Device
#### Wipe a Windows or MacOS device

#### Description
Wipe a Windows or MacOS device.

#### Where to find
Device \ General \ Wipe Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='device'></a>

# Device
<a name='device-security'></a>

## Security
<a name='device-security-enable-or-disable-device'></a>

### Enable Or Disable Device
#### Disable a device in AzureAD.

#### Description
Disable a device in AzureAD.

#### Where to find
Device \ Security \ Enable Or Disable Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-isolate-or-release-device'></a>

### Isolate Or Release Device
#### Isolate this device.

#### Description
Isolate this device using Defender for Endpoint.

#### Where to find
Device \ Security \ Isolate Or Release Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-reset-mobile-device-pin'></a>

### Reset Mobile Device Pin
#### Reset a mobile device's password/PIN code.

#### Description
Reset a mobile device's password/PIN code. Warning: Not possible for all types of devices.

#### Where to find
Device \ Security \ Reset Mobile Device Pin


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-restrict-or-release-code-execution'></a>

### Restrict Or Release Code Execution
#### Restrict code execution.

#### Description
Only allow Microsoft signed code to be executed.

#### Where to find
Device \ Security \ Restrict Or Release Code Execution


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-show-laps-password'></a>

### Show Laps Password
#### Show a local admin password for a device.

#### Description
Show a local admin password for a device.

#### Where to find
Device \ Security \ Show Laps Password


[Back to Table of Content](#table-of-contents)

 
 

<a name='group'></a>

# Group
<a name='group-devices'></a>

## Devices
<a name='group-devices-check-updatable-assets'></a>

### Check Updatable Assets
#### Check if devices in a group are onboarded to Windows Update for Business.

#### Description
This script checks if single or multiple devices (by Group Object ID) are onboarded to Windows Update for Business.

#### Where to find
Group \ Devices \ Check Updatable Assets


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-devices-unenroll-updatable-assets'></a>

### Unenroll Updatable Assets
#### Unenroll devices from Windows Update for Business.

#### Description
This script unenrolls devices from Windows Update for Business.

#### Where to find
Group \ Devices \ Unenroll Updatable Assets


[Back to Table of Content](#table-of-contents)

 
 

<a name='group'></a>

# Group
<a name='group-general'></a>

## General
<a name='group-general-add-or-remove-nested-group'></a>

### Add Or Remove Nested Group
#### Add/remove a nested group to/from a group.

#### Description
Add/remove a nested group to/from an AzureAD or Exchange Online group.

#### Where to find
Group \ General \ Add Or Remove Nested Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-add-or-remove-owner'></a>

### Add Or Remove Owner
#### Add/remove owners to/from an Office 365 group.

#### Description
Add/remove owners to/from an Office 365 group.

#### Where to find
Group \ General \ Add Or Remove Owner


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-add-or-remove-user'></a>

### Add Or Remove User
#### Add/remove users to/from a group.

#### Description
Add/remove users to/from an AzureAD or Exchange Online group.

#### Where to find
Group \ General \ Add Or Remove User


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-change-visibility'></a>

### Change Visibility
#### Change a group's visibility

#### Description
Change a group's visibility

#### Where to find
Group \ General \ Change Visibility


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-list-all-members'></a>

### List All Members
#### Retrieves the members of a specified EntraID group, including members from nested groups.

#### Description
This script retrieves the members of a specified EntraID group, including both direct members and those from nested groups.
The output is a CSV file with columns for User Principal Name (UPN), direct membership status, and group path.
The group path reflects the membership hierarchy—for example, “Primary, Secondary” if a user belongs to “Primary” via the nested group “Secondary.”

#### Where to find
Group \ General \ List All Members


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-list-owners'></a>

### List Owners
#### List all owners of an Office 365 group.

#### Description
List all owners of an Office 365 group.

#### Where to find
Group \ General \ List Owners


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-list-user-devices'></a>

### List User Devices
#### List all devices owned by group members.

#### Description
List all devices owned by group members.

#### Where to find
Group \ General \ List User Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-remove-group'></a>

### Remove Group
#### Removes a group, incl. SharePoint site and Teams team.

#### Description
Removes a group, incl. SharePoint site and Teams team.

#### Where to find
Group \ General \ Remove Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-rename-group'></a>

### Rename Group
#### Rename a group.

#### Description
Rename a group MailNickname, DisplayName and Description. Will NOT change eMail addresses!

#### Where to find
Group \ General \ Rename Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='group'></a>

# Group
<a name='group-mail'></a>

## Mail
<a name='group-mail-enable-or-disable-external-mail'></a>

### Enable Or Disable External Mail
#### Enable/disable external parties to send eMails to O365 groups.

#### Description
Enable/disable external parties to send eMails to O365 groups.

#### Where to find
Group \ Mail \ Enable Or Disable External Mail


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-mail-show-or-hide-in-address-book'></a>

### Show Or Hide In Address Book
#### (Un)hide an O365- or static Distribution-group in Address Book.

#### Description
(Un)hide an O365- or static Distribution-group in Address Book. Can also show the current state.

#### Where to find
Group \ Mail \ Show Or Hide In Address Book


[Back to Table of Content](#table-of-contents)

 
 

<a name='group'></a>

# Group
<a name='group-teams'></a>

## Teams
<a name='group-teams-archive-team'></a>

### Archive Team
#### Archive a team.

#### Description
Decomission an inactive team while preserving its contents for review.

#### Where to find
Group \ Teams \ Archive Team


[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-applications'></a>

## Applications
<a name='org-applications-add-application-registration'></a>

### Add Application Registration
#### Add an application registration to Azure AD

#### Description
This script creates a new application registration in Azure Active Directory (Entra ID) with comprehensive configuration options.

The script validates input parameters, prevents duplicate application creation, and provides comprehensive logging
throughout the process. For SAML applications, it automatically configures reply URLs, sign-on URLs, logout URLs,
and certificate expiry notifications.

#### Where to find
Org \ Applications \ Add Application Registration


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-delete-application-registration'></a>

### Delete Application Registration
#### Delete an application registration from Azure AD

#### Description
This script safely removes an application registration and its associated service principal from Azure Active Directory (Entra ID).

This script is the counterpart to the add-application-registration script and ensures
proper cleanup of all resources created during application registration.

#### Where to find
Org \ Applications \ Delete Application Registration


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-export-enterprise-app-users'></a>

### Export Enterprise App Users
#### Export a CSV of all (entprise) app owners and users

#### Description
Export a CSV of all (entprise) app owners and users.

#### Where to find
Org \ Applications \ Export Enterprise App Users


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-list-application-creds-expiry'></a>

### List Application Creds Expiry
#### List expiry date of all AppRegistration credentials

#### Description
List the expiry date of all AppRegistration credentials, including Client Secrets and Certificates.
Optionally, filter by Application IDs and list only those credentials that are about to expire.

#### Where to find
Org \ Applications \ List Application Creds Expiry


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-list-inactive-enterprise-apps'></a>

### List Inactive Enterprise Apps
#### List App registrations, which had no recent user logons.

#### Description
List App registrations, which had no recent user logons.

#### Where to find
Org \ Applications \ List Inactive Enterprise Apps


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-report-app-registration'></a>

### Report App Registration
#### Generate and email a comprehensive App Registration report

#### Description
This runbook generates a report of all Entra ID Application Registrations and deleted Application Registrations,
exports them to CSV files, and sends them via email.

#### Where to find
Org \ Applications \ Report App Registration

## Setup regarding email sending
### Overview
This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

### Prerequisites
We recommend using a dedicated shared mailbox, such as `realmjoin-report@contoso.com`. This mailbox will be used as the sender address for all reports. You can use a no-reply address, as recipients are not expected to respond to automated reports.

### RealmJoin Runbook Customization
As described in detail in the [JSON Based Customizing](https://docs.realmjoin.com/automation/runbooks/runbook-customization#json-based-customizing) documentation, you need to configure the sender email address in the settings block. This configuration defines the sender email address for all reporting runbooks across your tenant.

First, navigate to [RealmJoin Runbook Customization](https://portal.realmjoin.com/settings/runbooks-customizations) in the RealmJoin Portal (Settings > Runbook Customizations).

In the `Settings` block, add or modify the `RJReport` section to include the `EmailFrom` property with your desired sender email address:

```json
{
    "Settings": {
        "RJReport": {
            "EmailFrom": "realmjoin-report@contoso.com"
        }
    }
}
```

**Example:** With this configuration, the runbook will use `realmjoin-report@contoso.com` as the sender email address for all outgoing reports. Replace `contoso.com` with your actual domain name.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-update-application-registration'></a>

### Update Application Registration
#### Update an application registration in Azure AD

#### Description
This script modifies an existing application registration in Azure Active Directory (Entra ID) with comprehensive configuration updates.

The script intelligently determines what changes need to be applied by comparing current settings
with requested parameters, ensuring only necessary updates are performed. It maintains backward
compatibility while supporting modern authentication patterns and security requirements.

#### Where to find
Org \ Applications \ Update Application Registration


[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-devices'></a>

## Devices
<a name='org-devices-delete-stale-devices_scheduled'></a>

### Delete Stale Devices_Scheduled
#### Scheduled deletion of stale devices based on last activity date and platform.

#### Description
Identifies, lists, and deletes devices that haven't been active for a specified number of days.
Can be scheduled to run automatically and send a report via email.

#### Where to find
Org \ Devices \ Delete Stale Devices_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-get-bitlocker-recovery-key'></a>

### Get Bitlocker Recovery Key
#### Get BitLocker recovery key

#### Description
Get BitLocker recovery key via supplying bitlockeryRecoveryKeyId.

#### Where to find
Org \ Devices \ Get Bitlocker Recovery Key


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-list-stale-devices_scheduled'></a>

### List Stale Devices_Scheduled
#### Scheduled report of stale devices based on last activity date and platform.

#### Description
Identifies and lists devices that haven't been active for a specified number of days.
Automatically sends a report via email.

#### Where to find
Org \ Devices \ List Stale Devices_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-outphase-devices'></a>

### Outphase Devices
#### Remove/Outphase multiple devices

#### Description
Remove/Outphase multiple devices. You can choose if you want to wipe the device and/or delete it from Intune an AutoPilot.

#### Where to find
Org \ Devices \ Outphase Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-report-devices-without-primary-user'></a>

### Report Devices Without Primary User
#### Reports all managed devices in Intune that do not have a primary user assigned.

#### Description
This script retrieves all managed devices from Intune, and filters out those without a primary user (userId).
The output is a formatted table showing Object ID, Device ID, Display Name, and Last Sync Date/Time for each device without a primary user.

#### Where to find
Org \ Devices \ Report Devices Without Primary User


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-report-last-device-contact-by-range'></a>

### Report Last Device Contact By Range
#### Reports Windows devices with last device contact within a specified date range.

#### Description
This Runbook retrieves a list of Windows devices from Azure AD / Intune, filtered by their
last device contact time (lastSyncDateTime). As a dropdown for the date range, you can select from 0-30 days, 30-90 days, 90-180 days, 180-365 days, or 365+ days.
The output includes the device name, last sync date, user ID, user display name, and user principal name.

#### Where to find
Org \ Devices \ Report Last Device Contact By Range


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-report-users-with-more-than-5-devices'></a>

### Report Users With More Than 5-Devices
#### Reports users with more than five registered devices in Entra ID.

#### Description
This script queries all devices and their registered users, and reports users who have more than five devices registered.
The output includes the users ObjectId, UPN, and the number of devices.

#### Where to find
Org \ Devices \ Report Users With More Than 5-Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-sync-device-serialnumbers-to-entraid_scheduled'></a>

### Sync Device Serialnumbers To Entraid_Scheduled
#### Syncs serial numbers from Intune devices to Azure AD device extension attributes.

#### Description
This runbook retrieves all managed devices from Intune, extracts their serial numbers,
and updates the corresponding Azure AD device objects' extension attributes.
This helps maintain consistency between Intune and Azure AD device records.

#### Where to find
Org \ Devices \ Sync Device Serialnumbers To Entraid_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-general'></a>

## General
<a name='org-general-add-autopilot-device'></a>

### Add Autopilot Device
#### Import a windows device into Windows Autopilot.

#### Description
Import a windows device into Windows Autopilot.

#### Where to find
Org \ General \ Add Autopilot Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-device-via-corporate-identifier'></a>

### Add Device Via Corporate Identifier
#### Import a device into Intune via corporate identifier.

#### Description
Import a device into Intune via corporate identifier.

#### Where to find
Org \ General \ Add Device Via Corporate Identifier


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-devices-of-users-to-group_scheduled'></a>

### Add Devices Of Users To Group_Scheduled
#### Sync devices of users in a specific group to another device group.

#### Description
This runbook reads accounts from a specified Users group and adds their devices to a specified Devices group. It ensures new devices are also added.

#### Where to find
Org \ General \ Add Devices Of Users To Group_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-management-partner'></a>

### Add Management Partner
#### List or add or Management Partner Links (PAL)

#### Description
List or add or Management Partner Links (PAL)

#### Where to find
Org \ General \ Add Management Partner


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-microsoft-store-app-logos'></a>

### Add Microsoft Store App Logos
#### Update logos of Microsoft Store Apps (new) in Intune.

#### Description
This script updates the logos for Microsoft Store Apps (new) in Intune by fetching them from the Microsoft Store.

#### Where to find
Org \ General \ Add Microsoft Store App Logos


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-office365-group'></a>

### Add Office365 Group
#### Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

#### Description
Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

#### Where to find
Org \ General \ Add Office365 Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-or-remove-safelinks-exclusion'></a>

### Add Or Remove Safelinks Exclusion
#### Add or remove a SafeLinks URL exclusion to/from a given policy.

#### Description
Add or remove a SafeLinks URL exclusion to/from a given policy.
It can also be used to initially create a new policy if required.

#### Where to find
Org \ General \ Add Or Remove Safelinks Exclusion


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-or-remove-smartscreen-exclusion'></a>

### Add Or Remove Smartscreen Exclusion
#### Add/Remove a SmartScreen URL Exception/Rule in MS Security Center Indicators

#### Description
List/Add/Remove URL indicators entries in MS Security Center.

#### Where to find
Org \ General \ Add Or Remove Smartscreen Exclusion


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-or-remove-trusted-site'></a>

### Add Or Remove Trusted Site
#### Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy

#### Description
Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy

#### Where to find
Org \ General \ Add Or Remove Trusted Site


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-security-group'></a>

### Add Security Group
#### This runbook creates a Microsoft Entra ID security group with membership type "Assigned".

#### Description
This runbook creates a Microsoft Entra ID security group with membership type "Assigned".

#### Where to find
Org \ General \ Add Security Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-user'></a>

### Add User
#### Create a new user account.

#### Description
Create a new user account.

#### Where to find
Org \ General \ Add User


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-viva-engange-community'></a>

### Add Viva Engange Community
#### Creates a Viva Engage (Yammer) community via the Yammer API

#### Description
Creates a Viva Engage (Yammer) community using a Yammer dev token. The API-calls used are subject to change, so this script might break in the future.

#### Where to find
Org \ General \ Add Viva Engange Community


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-assign-groups-by-template_scheduled'></a>

### Assign Groups By Template_Scheduled
#### Assign cloud-only groups to many users based on a predefined template.

#### Description
Assign cloud-only groups to many users based on a predefined template.

#### Where to find
Org \ General \ Assign Groups By Template_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-bulk-delete-devices-from-autopilot'></a>

### Bulk Delete Devices From Autopilot
#### Mass-Delete Autopilot objects based on Serial Number.

#### Description
This runbook deletes Autopilot objects in bulk based on a list of serial numbers.

#### Where to find
Org \ General \ Bulk Delete Devices From Autopilot


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-bulk-retire-devices-from-intune'></a>

### Bulk Retire Devices From Intune
#### Bulk retire devices from Intune using serial numbers

#### Description
This runbook retires multiple devices from Intune based on a list of serial numbers.

#### Where to find
Org \ General \ Bulk Retire Devices From Intune


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-aad-sync-status_scheduled'></a>

### Check Aad Sync Status_Scheduled
#### Check for last Azure AD Connect Sync Cycle.

#### Description
This runbook checks the Azure AD Connect sync status and the last sync date and time.

#### Where to find
Org \ General \ Check Aad Sync Status_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-assignments-of-devices'></a>

### Check Assignments Of Devices
#### Check Intune assignments for a given (or multiple) Device Names.

#### Description
This script checks the Intune assignments for a single or multiple specified Device Names.

#### Where to find
Org \ General \ Check Assignments Of Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-assignments-of-groups'></a>

### Check Assignments Of Groups
#### Check Intune assignments for a given (or multiple) Group Names.

#### Description
This script checks the Intune assignments for a single or multiple specified Group Names.

#### Where to find
Org \ General \ Check Assignments Of Groups


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-assignments-of-users'></a>

### Check Assignments Of Users
#### Check Intune assignments for a given (or multiple) User Principal Names (UPNs).

#### Description
This script checks the Intune assignments for a single or multiple specified UPNs.

#### Where to find
Org \ General \ Check Assignments Of Users


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-autopilot-serialnumbers'></a>

### Check Autopilot Serialnumbers
#### Check if given serial numbers are present in AutoPilot.

#### Description
Check if given serial numbers are present in AutoPilot.

#### Where to find
Org \ General \ Check Autopilot Serialnumbers


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-device-onboarding-exclusion_schedule'></a>

### Check Device Onboarding Exclusion_Schedule
#### Check for Autopilot devices not yet onboarded to Intune. Add these to an exclusion group.

#### Description
Check for Autopilot devices not yet onboarded to Intune. Add these to an exclusion group.

#### Where to find
Org \ General \ Check Device Onboarding Exclusion_Schedule


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-enrolled-devices-report_scheduled'></a>

### Enrolled Devices Report_Scheduled
#### Show recent first-time device enrollments.

#### Description
Show recent first-time device enrollments, grouped by a category/attribute.

#### Where to find
Org \ General \ Enrolled Devices Report_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-all-autopilot-devices'></a>

### Export All Autopilot Devices
#### List/export all AutoPilot devices.

#### Description
List/export all AutoPilot devices.

#### Where to find
Org \ General \ Export All Autopilot Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-all-intune-devices'></a>

### Export All Intune Devices
#### Export a list of all Intune devices and where they are registered.

#### Description
Export all Intune devices and metadata based on their owner, like usageLocation.

#### Where to find
Org \ General \ Export All Intune Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-cloudpc-usage_scheduled'></a>

### Export Cloudpc Usage_Scheduled
#### Write daily Windows 365 Utilization Data to Azure Tables

#### Description
Write daily Windows 365 Utilization Data to Azure Tables. Will write data about the last full day.

#### Where to find
Org \ General \ Export Cloudpc Usage_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-non-compliant-devices'></a>

### Export Non Compliant Devices
#### Report on non-compliant devices and policies

#### Description
Report on non-compliant devices and policies

#### Where to find
Org \ General \ Export Non Compliant Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-policy-report'></a>

### Export Policy Report
#### Create a report of a tenant's polcies from Intune and AAD and write them to a markdown file.

#### Where to find
Org \ General \ Export Policy Report


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-invite-external-guest-users'></a>

### Invite External Guest Users
#### Invites external guest users to the organization using Microsoft Graph.

#### Description
This script automates the process of inviting external users as guests to the organization. Optionally, the invited user can be added to a specified group.

#### Where to find
Org \ General \ Invite External Guest Users


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-list-all-administrative-template-policies'></a>

### List All Administrative Template Policies
#### List all Administrative Template policies and their assignments.

#### Description
This script retrieves all Administrative Template policies from Intune and displays their assignments.

#### Where to find
Org \ General \ List All Administrative Template Policies


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-list-group-license-assignment-errors'></a>

### List Group License Assignment Errors
#### Report groups that have license assignment errors

#### Description
Report groups that have license assignment errors

#### Where to find
Org \ General \ List Group License Assignment Errors


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-office365-license-report'></a>

### Office365 License Report
#### Generate an Office 365 licensing report.

#### Description
Generate an Office 365 licensing report.

#### Where to find
Org \ General \ Office365 License Report


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-report-apple-mdm-cert-expiry_scheduled'></a>

### Report Apple Mdm Cert Expiry_Scheduled
#### Monitor/Report expiry of Apple device management certificates.

#### Description
Monitor/Report expiry of Apple device management certificates.

#### Where to find
Org \ General \ Report Apple Mdm Cert Expiry_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-report-pim-activations_scheduled'></a>

### Report Pim Activations_Scheduled
#### Scheduled Report on PIM Activations.

#### Description
This runbook collects and reports PIM activation details, including date, requestor, UPN, role, primary target, PIM group, reason, and status, and sends it via email.

#### Where to find
Org \ General \ Report Pim Activations_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-sync-all-devices'></a>

### Sync All Devices
#### Sync all Intune devices.

#### Description
This runbook triggers a sync operation for all Windows devices managed by Microsoft Intune.
It retrieves all managed Windows devices and sends a sync command to each device.
This is useful for forcing devices to check in with Intune and apply any pending policies or configurations.

#### Where to find
Org \ General \ Sync All Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-mail'></a>

## Mail
<a name='org-mail-add-distribution-list'></a>

### Add Distribution List
#### Create a classic distribution group.

#### Description
Create a classic distribution group.

#### Where to find
Org \ Mail \ Add Distribution List


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-equipment-mailbox'></a>

### Add Equipment Mailbox
#### Create an equipment mailbox.

#### Description
Create an equipment mailbox.

#### Where to find
Org \ Mail \ Add Equipment Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-or-remove-public-folder'></a>

### Add Or Remove Public Folder
#### Add or remove a public folder.

#### Description
Assumes you already have at least on Public Folder Mailbox. It will not provision P.F. Mailboxes.

#### Where to find
Org \ Mail \ Add Or Remove Public Folder


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-or-remove-teams-mailcontact'></a>

### Add Or Remove Teams Mailcontact
#### Create/Remove a contact, to allow pretty email addresses for Teams channels.

#### Description
Create/Remove a contact, to allow pretty email addresses for Teams channels.

#### Where to find
Org \ Mail \ Add Or Remove Teams Mailcontact


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-room-mailbox'></a>

### Add Room Mailbox
#### Create a room resource.

#### Description
Create a room resource.

#### Where to find
Org \ Mail \ Add Room Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-shared-mailbox'></a>

### Add Shared Mailbox
#### Create a shared mailbox.

#### Description
Create a shared mailbox.

#### Where to find
Org \ Mail \ Add Shared Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-hide-mailboxes_scheduled'></a>

### Hide Mailboxes_Scheduled
#### Hide / Unhide special mailboxes in Global Address Book

#### Description
Hide / Unhide special mailboxes in Global Address Book. Currently intended for Booking calendars.

#### Where to find
Org \ Mail \ Hide Mailboxes_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-set-booking-config'></a>

### Set Booking Config
#### Configure Microsoft Bookings settings for the organization.

#### Description
Configure Microsoft Bookings settings at the organization level, including booking policies,
naming conventions, and access restrictions. Optionally creates an OWA mailbox policy for
Bookings creators and disables Bookings in the default OWA policy.

#### Where to find
Org \ Mail \ Set Booking Config


[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-phone'></a>

## Phone
<a name='org-phone-get-teams-phone-number-assignment'></a>

### Get Teams Phone Number Assignment
#### Looks up, if the given phone number is assigned to a user in Microsoft Teams.

#### Description
This runbook looks up, if the given phone number is assigned to a user in Microsoft Teams. If the phone number is assigned to a user, information about the user will be returned.

#### Where to find
Org \ Phone \ Get Teams Phone Number Assignment

## Additional documentation
If a Teams user is found for the phone number, the following details are displayed:
- Display name
- User principal name
- Account type
- Phone number type
- Online voice routing policy
- Calling policy
- Dial plan
- Tenant dial plan


[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-security'></a>

## Security
<a name='org-security-add-defender-indicator'></a>

### Add Defender Indicator
#### Create new Indicator in Defender for Endpoint.

#### Description
Create a new Indicator in Defender for Endpoint e.g. to allow a specific file using it's hash value or allow a specific url that by default is blocked by Defender for Endpoint

#### Where to find
Org \ Security \ Add Defender Indicator


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-backup-conditional-access-policies'></a>

### Backup Conditional Access Policies
#### Exports the current set of Conditional Access policies to an Azure storage account.

#### Description
Exports the current set of Conditional Access policies to an Azure storage account.

#### Where to find
Org \ Security \ Backup Conditional Access Policies


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-admin-users'></a>

### List Admin Users
#### List AzureAD role holders and their MFA state.

#### Description
Will list users and service principals that hold a builtin AzureAD role.
Admins will be queried for valid MFA methods.

#### Where to find
Org \ Security \ List Admin Users


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-expiring-role-assignments'></a>

### List Expiring Role Assignments
#### List Azure AD role assignments that will expire before a given number of days.

#### Description
List Azure AD role assignments that will expire before a given number of days.

#### Where to find
Org \ Security \ List Expiring Role Assignments


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-inactive-devices'></a>

### List Inactive Devices
#### List/export inactive evices, which had no recent user logons.

#### Description
Collect devices based on the date of last user logon or last Intune sync.

#### Where to find
Org \ Security \ List Inactive Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-inactive-users'></a>

### List Inactive Users
#### List users, that have no recent interactive signins.

#### Description
List users, that have no recent interactive signins.

#### Where to find
Org \ Security \ List Inactive Users


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-information-protection-labels'></a>

### List Information Protection Labels
#### Prints a list of all available InformationProtectionPolicy labels.

#### Description
Prints a list of all available InformationProtectionPolicy labels.

#### Where to find
Org \ Security \ List Information Protection Labels


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-pim-rolegroups-without-owners_scheduled'></a>

### List Pim Rolegroups Without Owners_Scheduled
#### List role-assignable groups with eligible role assignments but without owners

#### Where to find
Org \ Security \ List Pim Rolegroups Without Owners_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-users-by-mfa-methods-count'></a>

### List Users By MFA Methods Count
#### Reports users by the count of their registered MFA methods.

#### Description
This Runbook retrieves a list of users from Azure AD and counts their registered MFA authentication methods.
As a dropdown for the MFA methods count range, you can select from "0 methods (no MFA)", "1-3 methods", "4-5 methods", or "6+ methods".
The output includes the user display name, user principal name, and the count of registered MFA methods.

#### Where to find
Org \ Security \ List Users By MFA Methods Count


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-vulnerable-app-regs'></a>

### List Vulnerable App Regs
#### List all app registrations that suffer from the CVE-2021-42306 vulnerability.

#### Description
List all app registrations that suffer from the CVE-2021-42306 vulnerability.

#### Where to find
Org \ Security \ List Vulnerable App Regs


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-notify-changed-ca-policies'></a>

### Notify Changed CA Policies
#### Exports the current set of Conditional Access policies to an Azure storage account.

#### Description
Exports the current set of Conditional Access policies to an Azure storage account.

#### Where to find
Org \ Security \ Notify Changed CA Policies


[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-avd'></a>

## Avd
<a name='user-avd-user-signout'></a>

### User Signout
#### Removes (Signs Out) a specific User from their AVD Session.

#### Description
This Runbooks looks for active User Sessions in all AVD Hostpools of a tenant and removes forces a Sign-Out of the user.
The SubscriptionIds value must be defined in the runbooks customization.

#### Where to find
User \ Avd \ User Signout


[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-general'></a>

## General
<a name='user-general-assign-groups-by-template'></a>

### Assign Groups By Template
#### Assign cloud-only groups to a user based on a predefined template.

#### Description
Assign cloud-only groups to a user based on a predefined template.

#### Where to find
User \ General \ Assign Groups By Template


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-assign-or-unassign-license'></a>

### Assign Or Unassign License
#### (Un-)Assign a license to a user via group membership.

#### Description
(Un-)Assign a license to a user via group membership.

#### Where to find
User \ General \ Assign Or Unassign License


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-assign-windows365'></a>

### Assign Windows365
#### Assign/Provision a Windows 365 instance

#### Description
Assign/Provision a Windows 365 instance for this user.

#### Where to find
User \ General \ Assign Windows365


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-list-group-ownerships'></a>

### List Group Ownerships
#### List group ownerships for this user.

#### Description
List group ownerships for this user.

#### Where to find
User \ General \ List Group Ownerships


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-list-manager'></a>

### List Manager
#### List manager information for this user.

#### Description
List manager information for the specified user.

#### Where to find
User \ General \ List Manager


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-offboard-user-permanently'></a>

### Offboard User Permanently
#### Permanently offboard a user.

#### Description
Permanently offboard a user.

#### Where to find
User \ General \ Offboard User Permanently


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-offboard-user-temporarily'></a>

### Offboard User Temporarily
#### Temporarily offboard a user.

#### Description
Temporarily offboard a user in cases like parental leaves or sabaticals.

#### Where to find
User \ General \ Offboard User Temporarily


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-reprovision-windows365'></a>

### Reprovision Windows365
#### Reprovision a Windows 365 Cloud PC

#### Description
Reprovision an already existing Windows 365 Cloud PC without reassigning a new instance for this user.

#### Where to find
User \ General \ Reprovision Windows365


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-resize-windows365'></a>

### Resize Windows365
#### Resize a Windows 365 Cloud PC

#### Description
Resize an already existing Windows 365 Cloud PC by derpovisioning and assigning a new differently sized license to the user. Warning: All local data will be lost. Proceed with caution.

#### Where to find
User \ General \ Resize Windows365


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-unassign-windows365'></a>

### Unassign Windows365
#### Remove/Deprovision a Windows 365 instance

#### Description
Remove/Deprovision a Windows 365 instance

#### Where to find
User \ General \ Unassign Windows365


[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-mail'></a>

## Mail
<a name='user-mail-add-or-remove-email-address'></a>

### Add Or Remove Email Address
#### Add/remove eMail address to/from mailbox.

#### Description
Add/remove eMail address to/from mailbox, update primary eMail address.

#### Where to find
User \ Mail \ Add Or Remove Email Address


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-assign-owa-mailbox-policy'></a>

### Assign Owa Mailbox Policy
#### Assign a given OWA mailbox policy to a user.

#### Description
Assign a given OWA mailbox policy to a user. E.g. to allow MS Bookings.

#### Where to find
User \ Mail \ Assign Owa Mailbox Policy


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-convert-to-shared-mailbox'></a>

### Convert To Shared Mailbox
#### Turn this users mailbox into a shared mailbox.

#### Description
Turn this users mailbox into a shared mailbox.

#### Where to find
User \ Mail \ Convert To Shared Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-delegate-full-access'></a>

### Delegate Full Access
#### Grant another user full access to this mailbox.

#### Description
Grant another user full access to this mailbox.

#### Where to find
User \ Mail \ Delegate Full Access


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-delegate-send-as'></a>

### Delegate Send As
#### Grant another user sendAs permissions on this mailbox.

#### Description
Grant another user sendAs permissions on this mailbox.

#### Where to find
User \ Mail \ Delegate Send As


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-delegate-send-on-behalf'></a>

### Delegate Send On Behalf
#### Grant another user sendOnBehalf permissions on this mailbox.

#### Description
Grant another user sendOnBehalf permissions on this mailbox.

#### Where to find
User \ Mail \ Delegate Send On Behalf


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-hide-or-unhide-in-addressbook'></a>

### Hide Or Unhide In Addressbook
#### (Un)Hide this mailbox in address book.

#### Description
(Un)Hide this mailbox in address book.

#### Where to find
User \ Mail \ Hide Or Unhide In Addressbook


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-list-mailbox-permissions'></a>

### List Mailbox Permissions
#### List permissions on a (shared) mailbox.

#### Description
List permissions on a (shared) mailbox.

#### Where to find
User \ Mail \ List Mailbox Permissions


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-list-room-mailbox-configuration'></a>

### List Room Mailbox Configuration
#### List Room configuration.

#### Description
List Room configuration.

#### Where to find
User \ Mail \ List Room Mailbox Configuration


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-remove-mailbox'></a>

### Remove Mailbox
#### Hard delete a shared mailbox, room or bookings calendar.

#### Description
Hard delete a shared mailbox, room or bookings calendar.

#### Where to find
User \ Mail \ Remove Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-set-out-of-office'></a>

### Set Out Of Office
#### En-/Disable Out-of-office-notifications for a user/mailbox.

#### Description
En-/Disable Out-of-office-notifications for a user/mailbox.

#### Where to find
User \ Mail \ Set Out Of Office


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-set-room-mailbox-configuration'></a>

### Set Room Mailbox Configuration
#### Set room resource policies.

#### Description
Set room resource policies.

#### Where to find
User \ Mail \ Set Room Mailbox Configuration


[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-phone'></a>

## Phone
<a name='user-phone-disable-teams-phone'></a>

### Disable Teams Phone
#### Microsoft Teams telephony offboarding

#### Description
Remove the phone number and specific policies from a teams-enabled user.

#### Where to find
User \ Phone \ Disable Teams Phone


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-phone-get-teams-user-info'></a>

### Get Teams User Info
#### Get the status quo of a Microsoft Teams user in terms of phone number, if any, and certain Microsoft Teams policies.

#### Description
Get the status quo of a Microsoft Teams user in terms of phone number, if any, and certain Microsoft Teams policies.

#### Where to find
User \ Phone \ Get Teams User Info


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-phone-grant-teams-user-policies'></a>

### Grant Teams User Policies
#### Grant specific Microsoft Teams policies to a Microsoft Teams enabled user.

#### Description
Grant specific Microsoft Teams policies to a Microsoft Teams enabled user.
If the policy name of a policy is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

#### Where to find
User \ Phone \ Grant Teams User Policies


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-phone-set-teams-permanent-call-forwarding'></a>

### Set Teams Permanent Call Forwarding
#### Set up immediate call forwarding for a Microsoft Teams Enterprise Voice user.

#### Description
Set up instant call forwarding for a Microsoft Teams Enterprise Voice user. Forwarding to another Microsoft Teams Enterprise Voice user or to an external phone number.

#### Where to find
User \ Phone \ Set Teams Permanent Call Forwarding


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-phone-set-teams-phone'></a>

### Set Teams Phone
#### Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies.

#### Description
Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies.
If the policy name of a policy is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

#### Where to find
User \ Phone \ Set Teams Phone


[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-security'></a>

## Security
<a name='user-security-confirm-or-dismiss-risky-user'></a>

### Confirm Or Dismiss Risky User
#### Confirm compromise / Dismiss a "risky user"

#### Description
Confirm compromise / Dismiss a "risky user"

#### Where to find
User \ Security \ Confirm Or Dismiss Risky User


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-create-temporary-access-pass'></a>

### Create Temporary Access Pass
#### Create an AAD temporary access pass for a user.

#### Description
Create an AAD temporary access pass for a user.

#### Where to find
User \ Security \ Create Temporary Access Pass


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-enable-or-disable-password-expiration'></a>

### Enable Or Disable Password Expiration
#### Set a users password policy to "(Do not) Expire"

#### Description
Set a users password policy to "(Do not) Expire"

#### Where to find
User \ Security \ Enable Or Disable Password Expiration


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-reset-mfa'></a>

### Reset Mfa
#### Remove all App- and Mobilephone auth methods for a user.

#### Description
Remove all App- and Mobilephone auth methods for a user. User can re-enroll MFA.

#### Where to find
User \ Security \ Reset Mfa


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-reset-password'></a>

### Reset Password
#### Reset a user's password.

#### Description
Reset a user's password. The user will have to change it on signin. Does not work with PW writeback to onprem AD.

#### Where to find
User \ Security \ Reset Password


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-revoke-or-restore-access'></a>

### Revoke Or Restore Access
#### Revoke user access and all active tokens or re-enable user.

#### Description
Revoke user access and all active tokens or re-enable user.

#### Where to find
User \ Security \ Revoke Or Restore Access


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-set-or-remove-mobile-phone-mfa'></a>

### Set Or Remove Mobile Phone Mfa
#### Add, update or remove a user's mobile phone MFA information.

#### Description
Add, update or remove a user's mobile phone MFA information.

#### Where to find
User \ Security \ Set Or Remove Mobile Phone Mfa


[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-userinfo'></a>

## Userinfo
<a name='user-userinfo-rename-user'></a>

### Rename User
#### Rename a user or mailbox. Will not update metadata like DisplayName, GivenName, Surname.

#### Description
Rename a user or mailbox. Will not update metadata like DisplayName, GivenName, Surname.

#### Where to find
User \ Userinfo \ Rename User


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-userinfo-set-photo'></a>

### Set Photo
#### Set / update the photo / avatar picture of a user.

#### Description
Set / update the photo / avatar picture of a user.

#### Where to find
User \ Userinfo \ Set Photo


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-userinfo-update-user'></a>

### Update User
#### Update/Finalize an existing user object.

#### Description
Update the metadata, group memberships and Exchange settings of an existing user object.

#### Where to find
User \ Userinfo \ Update User


[Back to Table of Content](#table-of-contents)

 
 


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
      - [Export Enterprise Application Users](#export-enterprise-application-users)
      - [List Inactive Enterprise Applications](#list-inactive-enterprise-applications)
      - [Report Application Registration](#report-application-registration)
      - [Report Expiring Application Credentials (Scheduled)](#report-expiring-application-credentials-(scheduled))
      - [Update Application Registration](#update-application-registration)
  - [Devices](#org-devices)
      - [Add Autopilot Device](#add-autopilot-device)
      - [Add Device Via Corporate Identifier](#add-device-via-corporate-identifier)
      - [Delete Stale Devices (Scheduled)](#delete-stale-devices-(scheduled))
      - [Get Bitlocker Recovery Key](#get-bitlocker-recovery-key)
      - [Notify Users About Stale Devices (Scheduled)](#notify-users-about-stale-devices-(scheduled))
      - [Outphase Devices](#outphase-devices)
      - [Report Devices Without Primary User](#report-devices-without-primary-user)
      - [Report Stale Devices (Scheduled)](#report-stale-devices-(scheduled))
      - [Report Users With More Than 5-Devices](#report-users-with-more-than-5-devices)
      - [Sync Device Serialnumbers To Entraid (Scheduled)](#sync-device-serialnumbers-to-entraid-(scheduled))
  - [General](#org-general)
      - [Add Devices Of Users To Group (Scheduled)](#add-devices-of-users-to-group-(scheduled))
      - [Add Management Partner](#add-management-partner)
      - [Add Microsoft Store App Logos](#add-microsoft-store-app-logos)
      - [Add Office365 Group](#add-office365-group)
      - [Add Or Remove Safelinks Exclusion](#add-or-remove-safelinks-exclusion)
      - [Add Or Remove Smartscreen Exclusion](#add-or-remove-smartscreen-exclusion)
      - [Add Or Remove Trusted Site](#add-or-remove-trusted-site)
      - [Add Security Group](#add-security-group)
      - [Add User](#add-user)
      - [Add Viva Engange Community](#add-viva-engange-community)
      - [Assign Groups By Template (Scheduled)](#assign-groups-by-template-(scheduled))
      - [Bulk Delete Devices From Autopilot](#bulk-delete-devices-from-autopilot)
      - [Bulk Retire Devices From Intune](#bulk-retire-devices-from-intune)
      - [Check Aad Sync Status (Scheduled)](#check-aad-sync-status-(scheduled))
      - [Check Assignments Of Devices](#check-assignments-of-devices)
      - [Check Assignments Of Groups](#check-assignments-of-groups)
      - [Check Assignments Of Users](#check-assignments-of-users)
      - [Check Autopilot Serialnumbers](#check-autopilot-serialnumbers)
      - [Check Device Onboarding Exclusion (Scheduled)](#check-device-onboarding-exclusion-(scheduled))
      - [Enrolled Devices Report (Scheduled)](#enrolled-devices-report-(scheduled))
      - [Export All Autopilot Devices](#export-all-autopilot-devices)
      - [Export All Intune Devices](#export-all-intune-devices)
      - [Export Cloudpc Usage (Scheduled)](#export-cloudpc-usage-(scheduled))
      - [Export Non Compliant Devices](#export-non-compliant-devices)
      - [Export Policy Report](#export-policy-report)
      - [Invite External Guest Users](#invite-external-guest-users)
      - [List All Administrative Template Policies](#list-all-administrative-template-policies)
      - [List Group License Assignment Errors](#list-group-license-assignment-errors)
      - [Office365 License Report](#office365-license-report)
      - [Report Apple MDM Cert Expiry (Scheduled)](#report-apple-mdm-cert-expiry-(scheduled))
      - [Report License Assignment (Scheduled)](#report-license-assignment-(scheduled))
      - [Report Pim Activations (Scheduled)](#report-pim-activations-(scheduled))
      - [Sync All Devices](#sync-all-devices)
  - [Mail](#org-mail)
      - [Add Distribution List](#add-distribution-list)
      - [Add Equipment Mailbox](#add-equipment-mailbox)
      - [Add Or Remove Public Folder](#add-or-remove-public-folder)
      - [Add Or Remove Teams Mailcontact](#add-or-remove-teams-mailcontact)
      - [Add Or Remove Tenant Allow Block List](#add-or-remove-tenant-allow-block-list)
      - [Add Room Mailbox](#add-room-mailbox)
      - [Add Shared Mailbox](#add-shared-mailbox)
      - [Hide Mailboxes (Scheduled)](#hide-mailboxes-(scheduled))
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
      - [List Pim Rolegroups Without Owners (Scheduled)](#list-pim-rolegroups-without-owners-(scheduled))
      - [List Users By MFA Methods Count](#list-users-by-mfa-methods-count)
      - [List Vulnerable App Regs](#list-vulnerable-app-regs)
      - [Monitor Pending EPM Requests (Scheduled)](#monitor-pending-epm-requests-(scheduled))
      - [Notify Changed CA Policies](#notify-changed-ca-policies)
      - [Report EPM Elevation Requests (Scheduled)](#report-epm-elevation-requests-(scheduled))
- [User](#user)
  - [Avd](#user-avd)
      - [User Signout](#user-signout)
  - [General](#user-general)
      - [Assign Groups By Template](#assign-groups-by-template)
      - [Assign Or Unassign License](#assign-or-unassign-license)
      - [Assign Windows365](#assign-windows365)
      - [List Group Memberships](#list-group-memberships)
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
Device \ AVD \ Restart Host


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-avd-toggle-drain-mode'></a>

### Toggle Drain Mode
#### Sets Drainmode on true or false for a specific AVD Session Host.

#### Description
This Runbooks looks through all AVD Hostpools of a tenant and sets the DrainMode for a specific Session Host.
The SubscriptionId value must be defined in the runbooks customization.

#### Where to find
Device \ AVD \ Toggle Drain Mode


[Back to Table of Content](#table-of-contents)

 
 

<a name='device'></a>

# Device
<a name='device-general'></a>

## General
<a name='device-general-change-grouptag'></a>

### Change Grouptag
#### Assign a new AutoPilot GroupTag to this device.

#### Description
This Runbook assigns a new AutoPilot GroupTag to the device. This can be used to trigger a new deployment with different policies and applications for the device.

#### Where to find
Device \ General \ Change Grouptag


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-check-updatable-assets'></a>

### Check Updatable Assets
#### Check if a device is onboarded to Windows Update for Business

#### Description
This script checks if single device is onboarded to Windows Update for Business

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
Wipe a Windows or MacOS device. For Windows devices, you can choose between a regular wipe and a protected wipe. For MacOS devices, you can provide a recovery code if needed and specify the obliteration behavior.

#### Where to find
Device \ General \ Wipe Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='device'></a>

# Device
<a name='device-security'></a>

## Security
<a name='device-security-enable-or-disable-device'></a>

### Enable Or Disable Device
#### Enable or disable a device in Entra ID

#### Description
This runbook enables or disables a Windows device object in Entra ID (Azure AD) based on the provided device ID.
Use it to temporarily block sign-ins from a compromised or lost device, or to re-enable the device after remediation.

#### Where to find
Device \ Security \ Enable Or Disable Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-isolate-or-release-device'></a>

### Isolate Or Release Device
#### Isolate this device.

#### Description
This runbook isolates a device in Microsoft Defender for Endpoint to reduce the risk of lateral movement and data exfiltration.
Optionally, it can release a previously isolated device.
Provide a short reason so the action is documented in the service.

#### Where to find
Device \ Security \ Isolate Or Release Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-reset-mobile-device-pin'></a>

### Reset Mobile Device Pin
#### Reset a mobile device's password/PIN code.

#### Description
This runbook triggers an Intune reset passcode action for a managed mobile device.
The action is only supported for certain, corporate-owned device types and will be rejected for personal or unsupported devices.

#### Where to find
Device \ Security \ Reset Mobile Device Pin


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-restrict-or-release-code-execution'></a>

### Restrict Or Release Code Execution
#### Only allow Microsoft-signed code to run on a device, or remove an existing restriction.

#### Description
This runbook restricts code execution on a device via Microsoft Defender for Endpoint so that only Microsoft-signed code can run.
Optionally, it can remove an existing restriction.
Provide a short reason so the action is documented in the service.

#### Where to find
Device \ Security \ Restrict Or Release Code Execution


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-show-laps-password'></a>

### Show Laps Password
#### Show a local admin password for a device.

#### Description
This runbook retrieves and displays the most recent Windows LAPS local administrator password that is backed up for the specified device.
Use it for break-glass troubleshooting and rotate the password after use.

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
This runbook checks the Windows Update for Business onboarding status for all device members of a Microsoft Entra ID group.
It queries each device and reports the enrollment state per update category and any returned error details.
Use this to validate whether group members are correctly registered as updatable assets.

#### Where to find
Group \ Devices \ Check Updatable Assets


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-devices-unenroll-updatable-assets'></a>

### Unenroll Updatable Assets
#### Unenroll devices from Windows Update for Business.

#### Description
This runbook unenrolls all device members of a Microsoft Entra ID group from Windows Update for Business updatable assets.
You can remove a specific update category enrollment or delete the updatable asset registration entirely.
Use this to offboard devices from WUfB reporting or to reset their enrollment state.

#### Where to find
Group \ Devices \ Unenroll Updatable Assets


[Back to Table of Content](#table-of-contents)

 
 

<a name='group'></a>

# Group
<a name='group-general'></a>

## General
<a name='group-general-add-or-remove-nested-group'></a>

### Add Or Remove Nested Group
#### Add/remove a nested group to/from a group

#### Description
This runbook adds a nested group to a target group or removes an existing nesting.
It supports Microsoft Entra ID groups and Exchange Online distribution or mail-enabled security groups.
Use the Remove switch to remove the nested group instead of adding it.

#### Where to find
Group \ General \ Add Or Remove Nested Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-add-or-remove-owner'></a>

### Add Or Remove Owner
#### Add or remove a Office 365 group owner

#### Description
This runbook adds a user as an owner of a group or removes an existing owner.
For Microsoft 365 groups, it also ensures that newly added owners are members of the group.
Use the Remove switch to remove ownership instead of adding it.

#### Where to find
Group \ General \ Add Or Remove Owner


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-add-or-remove-user'></a>

### Add Or Remove User
#### Add or remove a group member

#### Description
This runbook adds a user to a group or removes a user from a group.
It supports Microsoft Entra ID groups and Exchange Online distribution or mail-enabled security groups.
Use the Remove switch to remove the user instead of adding the user.

#### Where to find
Group \ General \ Add Or Remove User


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-change-visibility'></a>

### Change Visibility
#### Change a group's visibility

#### Description
This runbook changes the visibility of a Microsoft 365 group between Private and Public.
Set the Public switch to make the group public; otherwise it will be set to private.
This does not change group membership, owners, or email addresses.

#### Where to find
Group \ General \ Change Visibility


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-list-all-members'></a>

### List All Members
#### List all members of a group, including members that are part of nested groups

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
This runbook retrieves and lists the owners of the specified group.
It uses Microsoft Graph to query the group and its owners and outputs the results as a table.
Use this to quickly review ownership assignments.

#### Where to find
Group \ General \ List Owners


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-list-user-devices'></a>

### List User Devices
#### List devices owned by group members.

#### Description
This runbook enumerates the users in a group and lists their registered devices.
Optionally, it can add the discovered devices to a specified device group.
Use this to create or maintain a device group based on group member ownership.

#### Where to find
Group \ General \ List User Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-remove-group'></a>

### Remove Group
#### Remove a group. For Microsoft 365 groups, also the associated resources (Teams, SharePoint site) will be removed.

#### Description
This runbook deletes the specified group, which for Microsoft 365 groups means, that it also deletes the associated resources such as the Teams Team and the SharePoint Site.

#### Where to find
Group \ General \ Remove Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-rename-group'></a>

### Rename Group
#### Rename a group.

#### Description
This runbook updates a group's DisplayName, MailNickname, and Description.
It does not change the group's email addresses.
Provide only the fields you want to update; empty values are ignored.

#### Where to find
Group \ General \ Rename Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='group'></a>

# Group
<a name='group-mail'></a>

## Mail
<a name='group-mail-enable-or-disable-external-mail'></a>

### Enable Or Disable External Mail
#### Enable or disable external parties to send emails to a Microsoft 365 group

#### Description
This runbook configures whether external senders are allowed to email a Microsoft 365 group.
It uses Exchange Online to enable or disable the RequireSenderAuthenticationEnabled setting.
You can also query the current state without making changes.

#### Where to find
Group \ Mail \ Enable Or Disable External Mail


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-mail-show-or-hide-in-address-book'></a>

### Show Or Hide In Address Book
#### Show or hide a group in the address book

#### Description
This runbook shows or hides a Microsoft 365 group or a distribution group from address lists.
You can also query the current visibility state without making changes.

#### Where to find
Group \ Mail \ Show Or Hide In Address Book


[Back to Table of Content](#table-of-contents)

 
 

<a name='group'></a>

# Group
<a name='group-teams'></a>

## Teams
<a name='group-teams-archive-team'></a>

### Archive Team
#### Archive a team

#### Description
This runbook archives a Microsoft Teams team backed by the specified Microsoft 365 group.
It verifies that the group is provisioned as a team and then triggers the archive action via Microsoft Graph.
Use this to decommission inactive teams while preserving their contents for review.

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
This runbook creates a new application registration in Microsoft Entra ID and optionally configures redirect URIs and SAML settings.
It validates the submitted parameters, prevents duplicate app creation, and writes verbose logs for troubleshooting.
Use it to standardize application registration setup, including visibility and assignment-related options.

#### Where to find
Org \ Applications \ Add Application Registration


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-delete-application-registration'></a>

### Delete Application Registration
#### Delete an application registration from Azure AD

#### Description
This runbook deletes an application registration and its associated service principal from Microsoft Entra ID.
It verifies that the application exists before deletion and performs a best-effort cleanup of groups assigned during provisioning.

#### Where to find
Org \ Applications \ Delete Application Registration


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-export-enterprise-application-users'></a>

### Export Enterprise Application Users
#### Export a CSV of all (enterprise) application owners and users

#### Description
This runbook exports a CSV report of enterprise applications (or all service principals) including owners and assigned users or groups.
It uploads the generated CSV file to an Azure Storage Account and returns a time-limited download link.

#### Where to find
Org \ Applications \ Export Enterprise Application Users


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-list-inactive-enterprise-applications'></a>

### List Inactive Enterprise Applications
#### List enterprise applications with no recent sign-ins

#### Description
This runbook identifies enterprise applications with no recent sign-in activity based on Microsoft Entra ID sign-in logs.
It lists apps that have not been used for the specified number of days and apps that have no sign-in records.
Use it to find candidates for review, cleanup, or decommissioning.

#### Where to find
Org \ Applications \ List Inactive Enterprise Applications


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-report-application-registration'></a>

### Report Application Registration
#### Generate and email a comprehensive Application Registration report

#### Description
This runbook generates a report of all application registrations in Microsoft Entra ID and can optionally include deleted registrations.
It exports the results to CSV files and sends them via email.
Use it for periodic inventory, review, and audit purposes.

#### Where to find
Org \ Applications \ Report Application Registration

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-report-expiring-application-credentials-(scheduled)'></a>

### Report Expiring Application Credentials (Scheduled)
#### List expiry date of all Application Registration credentials

#### Description
This runbook lists the expiry dates of application registration credentials, including client secrets and certificates.
It can optionally filter by application IDs and can limit output to credentials that are about to expire.

#### Where to find
Org \ Applications \ Report Expiring Application Credentials_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-update-application-registration'></a>

### Update Application Registration
#### Update an application registration in Azure AD

#### Description
This runbook updates an existing application registration and its related configuration in Microsoft Entra ID.
It compares the current settings with the requested parameters and applies only the necessary updates.
Use it to manage redirect URIs, SAML settings, visibility, assignment requirements, and token issuance behavior.

#### Where to find
Org \ Applications \ Update Application Registration


[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-devices'></a>

## Devices
<a name='org-devices-add-autopilot-device'></a>

### Add Autopilot Device
#### Import a Windows device into Windows Autopilot

#### Description
This runbook imports a Windows device into Windows Autopilot using the device serial number and hardware hash.
It can optionally wait for the import job to finish and supports tagging during import.

#### Where to find
Org \ Devices \ Add Autopilot Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-add-device-via-corporate-identifier'></a>

### Add Device Via Corporate Identifier
#### Import a device into Intune via corporate identifier

#### Description
This runbook imports a device into Intune using a corporate identifier such as serial number or IMEI.
It can overwrite existing entries and optionally stores a description for the imported identity.

#### Where to find
Org \ Devices \ Add Device Via Corporate Identifier


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-delete-stale-devices-(scheduled)'></a>

### Delete Stale Devices (Scheduled)
#### Scheduled deletion of stale devices based on last activity

#### Description
This runbook identifies Intune managed devices that have not been active for a defined number of days.
It can optionally delete the matching devices and can send an email report.

#### Where to find
Org \ Devices \ Delete Stale Devices_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-get-bitlocker-recovery-key'></a>

### Get Bitlocker Recovery Key
#### Get the BitLocker recovery key

#### Description
This runbook retrieves a BitLocker recovery key using the recovery key ID from the BitLocker recovery screen.
It returns key details and related device information.

#### Where to find
Org \ Devices \ Get Bitlocker Recovery Key


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-notify-users-about-stale-devices-(scheduled)'></a>

### Notify Users About Stale Devices (Scheduled)
#### Notify primary users about their stale devices via email

#### Description
Identifies devices that haven't been active for a specified number of days and sends personalized email notifications to the primary users of those devices. The email contains device information and action steps for the user. Optionally filter users by including or excluding specific groups.

#### Where to find
Org \ Devices \ Notify Users About Stale Devices_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.




[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-outphase-devices'></a>

### Outphase Devices
#### Remove or outphase multiple devices

#### Description
This runbook outphases multiple devices based on a comma-separated list of device IDs or serial numbers.
It can optionally wipe devices in Intune and delete or disable the corresponding Entra ID device objects.

#### Where to find
Org \ Devices \ Outphase Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-report-devices-without-primary-user'></a>

### Report Devices Without Primary User
#### Reports all managed devices in Intune that do not have a primary user assigned.

#### Description
This script retrieves all managed devices from Intune, and filters out those without a primary user (userId).
The output is a formatted table showing Object ID, Device ID, Display Name, and Last Sync Date/Time for each device without a primary user.

Optionally, the report can be sent via email with a CSV attachment containing detailed device information

#### Where to find
Org \ Devices \ Report Devices Without Primary User

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-report-stale-devices-(scheduled)'></a>

### Report Stale Devices (Scheduled)
#### Scheduled report of stale devices based on last activity date and platform.

#### Description
Identifies and lists devices that haven't been active for a specified number of days.
Automatically sends a report via email.

#### Where to find
Org \ Devices \ Report Stale Devices_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-report-users-with-more-than-5-devices'></a>

### Report Users With More Than 5-Devices
#### Report users with more than five registered devices

#### Description
This runbook queries Entra ID devices and their registered users to identify users with more than five devices.
It outputs a summary table and can optionally send an email with CSV attachments.

#### Where to find
Org \ Devices \ Report Users With More Than 5-Devices

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-sync-device-serialnumbers-to-entraid-(scheduled)'></a>

### Sync Device Serialnumbers To Entraid (Scheduled)
#### Sync Intune serial numbers to Entra ID extension attributes

#### Description
This runbook retrieves Intune managed devices and syncs their serial numbers into an Entra ID device extension attribute.
It can process all devices or only devices with missing or mismatched values and can optionally send an email report.

#### Where to find
Org \ Devices \ Sync Device Serialnumbers To Entraid_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-general'></a>

## General
<a name='org-general-add-devices-of-users-to-group-(scheduled)'></a>

### Add Devices Of Users To Group (Scheduled)
#### Sync devices of users in a specific group to another device group

#### Description
This runbook reads accounts from a specified users group and adds their devices to a specified device group.
It can filter devices by operating system and keeps the target group in sync.

#### Where to find
Org \ General \ Add Devices Of Users To Group_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-management-partner'></a>

### Add Management Partner
#### List or add Management Partner Links (PAL)

#### Description
This runbook lists existing Partner Admin Links (PAL) for the tenant or adds a new PAL.
It uses the Azure Management Partner API and supports an interactive action selection.

#### Where to find
Org \ General \ Add Management Partner


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-microsoft-store-app-logos'></a>

### Add Microsoft Store App Logos
#### Update logos of Microsoft Store Apps (new) in Intune

#### Description
This runbook updates missing logos for Microsoft Store Apps (new) in Intune by fetching the icon from the Microsoft Store.
It skips apps that already have a logo and reports how many apps were updated.

#### Where to find
Org \ General \ Add Microsoft Store App Logos


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-office365-group'></a>

### Add Office365 Group
#### Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

#### Description
This runbook creates a Microsoft 365 group and provisions the related SharePoint site.
It can optionally promote the group to a Microsoft Teams team after creation.

#### Where to find
Org \ General \ Add Office365 Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-or-remove-safelinks-exclusion'></a>

### Add Or Remove Safelinks Exclusion
#### Add or remove a SafeLinks URL exclusion from a policy

#### Description
Adds or removes a SafeLinks URL pattern exclusion in a specified policy. The runbook can also list existing policies and can create a new policy and group if needed.

#### Where to find
Org \ General \ Add Or Remove Safelinks Exclusion


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-or-remove-smartscreen-exclusion'></a>

### Add Or Remove Smartscreen Exclusion
#### Add or remove a SmartScreen URL indicator in Microsoft Defender

#### Description
This runbook lists, adds, or removes URL indicators in Microsoft Defender.
It can allow, audit, warn, or block a given domain by creating an indicator entry.

#### Where to find
Org \ General \ Add Or Remove Smartscreen Exclusion


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-or-remove-trusted-site'></a>

### Add Or Remove Trusted Site
#### Add or remove a URL entry in the Intune Trusted Sites policy

#### Description
Adds or removes a URL to the Site-to-Zone Assignment List in a Windows custom configuration policy. The runbook can also list all existing Trusted Sites policies and their mappings.

#### Where to find
Org \ General \ Add Or Remove Trusted Site


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-security-group'></a>

### Add Security Group
#### Create a Microsoft Entra ID security group

#### Description
This runbook creates a Microsoft Entra ID security group with membership type Assigned.
It validates the group name and optionally sets an owner during creation.

#### Where to find
Org \ General \ Add Security Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-user'></a>

### Add User
#### Create a new user account

#### Description
This runbook creates a new cloud user in Microsoft Entra ID and applies standard user properties.
It can optionally assign a license group, add the user to additional groups, and create an Exchange Online archive mailbox.

#### Where to find
Org \ General \ Add User


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-viva-engange-community'></a>

### Add Viva Engange Community
#### Create a Viva Engage (Yammer) community

#### Description
This runbook creates a Viva Engage community via the Yammer REST API using a stored developer token.
It can optionally assign owners and remove the initial API user from the resulting Microsoft 365 group.

#### Where to find
Org \ General \ Add Viva Engange Community


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-assign-groups-by-template-(scheduled)'></a>

### Assign Groups By Template (Scheduled)
#### Assign cloud-only groups to many users based on a predefined template

#### Description
This runbook adds users from a source group to one or more target groups.
Target groups are provided via a template-driven string and can be resolved by group ID or display name.

#### Where to find
Org \ General \ Assign Groups By Template_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-bulk-delete-devices-from-autopilot'></a>

### Bulk Delete Devices From Autopilot
#### Bulk delete Autopilot objects by serial number

#### Description
This runbook deletes Windows Autopilot device identities based on a comma-separated list of serial numbers.
It searches for each serial number and deletes the matching Autopilot object if found.

#### Where to find
Org \ General \ Bulk Delete Devices From Autopilot


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-bulk-retire-devices-from-intune'></a>

### Bulk Retire Devices From Intune
#### Bulk retire devices from Intune using serial numbers

#### Description
Retires multiple Intune devices based on a comma-separated list of serial numbers. Each serial number is looked up in Intune and the device is retired if found.

#### Where to find
Org \ General \ Bulk Retire Devices From Intune


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-aad-sync-status-(scheduled)'></a>

### Check Aad Sync Status (Scheduled)
#### Check last Azure AD Connect sync status

#### Description
This runbook checks whether on-premises directory synchronization is enabled and when the last sync happened.
It can send an email alert if synchronization is not enabled.

#### Where to find
Org \ General \ Check Aad Sync Status_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-assignments-of-devices'></a>

### Check Assignments Of Devices
#### Check Intune assignments for one or more device names

#### Description
This runbook queries Intune policies and optionally app assignments relevant to the specified device(s).
It resolves device group memberships and reports matching assignments.

#### Where to find
Org \ General \ Check Assignments Of Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-assignments-of-groups'></a>

### Check Assignments Of Groups
#### Check Intune assignments for one or more group names

#### Description
This runbook queries Intune policies and optionally app assignments that target the specified group(s).
It resolves group IDs and reports matching assignments.

#### Where to find
Org \ General \ Check Assignments Of Groups


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-assignments-of-users'></a>

### Check Assignments Of Users
#### Check Intune assignments for one or more user principal names

#### Description
This runbook queries Intune policies and optionally app assignments relevant to the specified user(s).
It resolves transitive group membership and reports matching assignments.

#### Where to find
Org \ General \ Check Assignments Of Users


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-autopilot-serialnumbers'></a>

### Check Autopilot Serialnumbers
#### Check if given serial numbers are present in Autopilot

#### Description
This runbook checks whether Windows Autopilot device identities exist for the provided serial numbers.
It returns the serial numbers found and lists any missing serial numbers.

#### Where to find
Org \ General \ Check Autopilot Serialnumbers


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-device-onboarding-exclusion-(scheduled)'></a>

### Check Device Onboarding Exclusion (Scheduled)
#### Add unenrolled Autopilot devices to an exclusion group

#### Description
This runbook identifies Windows Autopilot devices that are not yet enrolled in Intune and ensures they are members of a configured exclusion group.
It also removes devices from the group once they are no longer in scope.

#### Where to find
Org \ General \ Check Device Onboarding Exclusion_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-enrolled-devices-report-(scheduled)'></a>

### Enrolled Devices Report (Scheduled)
#### Show recent first-time device enrollments

#### Description
This runbook reports recent device enrollments based on a configurable time range.
It can group results by a selected attribute and can optionally export the report as a CSV file.

#### Where to find
Org \ General \ Enrolled Devices Report_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-all-autopilot-devices'></a>

### Export All Autopilot Devices
#### List or export all Windows Autopilot devices

#### Description
Lists all Windows Autopilot devices and optionally exports them to a CSV file in Azure Storage. If exporting is enabled, the runbook uploads the report and returns a time-limited SAS (download) link.

#### Where to find
Org \ General \ Export All Autopilot Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-all-intune-devices'></a>

### Export All Intune Devices
#### Export a list of all Intune devices and where they are registered

#### Description
Exports all Intune managed devices and enriches them with selected owner metadata such as usage location. The report is uploaded as a CSV file to an Azure Storage container.

#### Where to find
Org \ General \ Export All Intune Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-cloudpc-usage-(scheduled)'></a>

### Export Cloudpc Usage (Scheduled)
#### Write daily Windows 365 utilization data to Azure Table Storage

#### Description
Collects Windows 365 Cloud PC remote connection usage for the last full day and writes it to an Azure Table. The runbook creates the table if needed and merges records per tenant and timestamp.

#### Where to find
Org \ General \ Export Cloudpc Usage_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-non-compliant-devices'></a>

### Export Non Compliant Devices
#### Export non-compliant Intune devices and settings

#### Description
This runbook queries Intune for non-compliant and in-grace-period devices and retrieves detailed policy and setting compliance data.
It can export the results to CSV with SAS (download) links.

#### Where to find
Org \ General \ Export Non Compliant Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-policy-report'></a>

### Export Policy Report
#### Create a report of tenant policies from Intune and Entra ID.

#### Description
This runbook exports configuration policies from Intune and Entra ID and writes the results to a Markdown report.
It can optionally export raw JSON and create downloadable links for exported artifacts.

#### Where to find
Org \ General \ Export Policy Report


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-invite-external-guest-users'></a>

### Invite External Guest Users
#### Invite external guest users to the organization

#### Description
This runbook invites an external user as a guest user in Microsoft Entra ID.
It can optionally add the invited user to a specified group.

#### Where to find
Org \ General \ Invite External Guest Users


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-list-all-administrative-template-policies'></a>

### List All Administrative Template Policies
#### List all Administrative Template policies and their assignments

#### Description
This runbook retrieves all Administrative Template policies from Intune.
It lists each policy and shows its current assignments.

#### Where to find
Org \ General \ List All Administrative Template Policies


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-list-group-license-assignment-errors'></a>

### List Group License Assignment Errors
#### Report groups that have license assignment errors

#### Description
This runbook searches for Entra ID groups that have members with license assignment errors.
It prints the affected group names and object IDs.

#### Where to find
Org \ General \ List Group License Assignment Errors


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-office365-license-report'></a>

### Office365 License Report
#### Generate an Office 365 licensing report

#### Description
This runbook creates a licensing report based on Microsoft 365 subscription SKUs and optionally includes Exchange Online related reports.
It can export the results to Azure Storage and generate SAS links for downloads.

#### Where to find
Org \ General \ Office365 License Report


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-report-apple-mdm-cert-expiry-(scheduled)'></a>

### Report Apple MDM Cert Expiry (Scheduled)
#### Monitor/Report expiry of Apple device management certificates

#### Description
Monitors expiration dates of Apple Push certificates, VPP tokens, and DEP tokens in Microsoft Intune.
Sends an email report with alerts for certificates/tokens expiring within the specified threshold.

#### Where to find
Org \ General \ Report Apple MDM Cert Expiry_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-report-license-assignment-(scheduled)'></a>

### Report License Assignment (Scheduled)
#### Generate and email a license availability report based on thresholds

#### Description
This runbook checks the license availability based on the transmitted SKUs and sends an email report if any thresholds are reached.
Two types of thresholds can be configured. The first type is a minimum threshold, which triggers an alert when the number of available licenses falls below a specified number.
The second type is a maximum threshold, which triggers an alert when the number of available licenses exceeds a specified number.
The report includes detailed information about licenses that are outside the configured thresholds, exports them to CSV files, and sends them via email.

#### Where to find
Org \ General \ Report License Assignment_Scheduled

## Runbook Customization

### Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.

### InputJson Configuration

Each license configuration requires:

- **SKUPartNumber** (required): Microsoft SKU identifier
- **FriendlyName** (required): Display name
- **MinThreshold** (optional): Alert when available licenses < threshold
- **MaxThreshold** (optional): Alert when available licenses > threshold

At least one threshold must be set per license.

### Configuration Examples

**Minimum threshold only** (prevent shortages):

```json
[
    {
        "SKUPartNumber": "ENTERPRISEPACK",
        "FriendlyName": "Microsoft 365 E3",
        "MinThreshold": 50
    }
]
```

**Maximum threshold only** (prevent over-provisioning):

```json
[
    {
        "SKUPartNumber": "POWER_BI_PRO",
        "FriendlyName": "Power BI Pro",
        "MaxThreshold": 500
    }
]
```

**Both thresholds** (maintain range):

```json
[
    {
        "SKUPartNumber": "ENTERPRISEPREMIUM",
        "FriendlyName": "Microsoft 365 E5",
        "MinThreshold": 50,
        "MaxThreshold": 150
    }
]
```

### Complete Runbook Customization

```json
{
    "Settings": {
        "RJReport": {
            "EmailSender": "sender@contoso.com"
        }
    },
    "Runbooks": {
        "rjgit-org_general_report-license-assignment_scheduled": {
            "Parameters": {
                "EmailTo": {
                    "DisplayName": "Recipient Email Address(es)"
                },
                "InputJson": {
                    "Hide": true,
                    "DefaultValue": [
                        {
                            "SKUPartNumber": "SPE_E5",
                            "FriendlyName": "Microsoft 365 E5",
                            "MinThreshold": 20,
                            "MaxThreshold": 30
                        },
                        {
                            "SKUPartNumber": "FLOW_FREE",
                            "FriendlyName": "Microsoft Power Automate Free",
                            "MinThreshold": 10
                        }
                    ]
                },
                "EmailFrom": {
                    "Hide": true
                },
                "CallerName": {
                    "Hide": true
                }
            }
        }
    }
}
```

## Finding SKU Part Numbers

```powershell
Connect-MgGraph -Scopes "Organization.Read.All"
Get-MgSubscribedSku | Select-Object SkuPartNumber, SkuId | Sort-Object SkuPartNumber
```

Common SKUs:

- `ENTERPRISEPACK` - Microsoft 365 E3
- `ENTERPRISEPREMIUM` - Microsoft 365 E5
- `EMS` - Enterprise Mobility + Security E3

## Output

**When violations detected:**

- Console output in job log
- CSV export (`License_Threshold_Violations.csv`)
- Email report with summary, violations, recommendations, and CSV attachment

**When all within thresholds:**

- No email sent
- Job completes successfully

## Troubleshooting

**SKU Not Found**: Verify SKU exists using `Get-MgSubscribedSku`

**Email Not Sent**: Check EmailFrom configuration and Mail.Send permission

**Invalid JSON**: Validate JSON format before configuration

## Migration Note

Legacy `WarningThreshold` automatically maps to `MinThreshold` - old configurations continue to work.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-report-pim-activations-(scheduled)'></a>

### Report Pim Activations (Scheduled)
#### Scheduled report on PIM activations

#### Description
This runbook queries Microsoft Entra ID audit logs for recent PIM activations.
It builds an report and sends it via email.

#### Where to find
Org \ General \ Report Pim Activations_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-sync-all-devices'></a>

### Sync All Devices
#### Sync all Intune Windows devices

#### Description
This runbook triggers a sync operation for all Windows devices managed by Microsoft Intune.
It forces devices to check in and apply pending policies and configurations.

#### Where to find
Org \ General \ Sync All Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-mail'></a>

## Mail
<a name='org-mail-add-distribution-list'></a>

### Add Distribution List
#### Create a classic distribution group

#### Description
Creates a classic Exchange Online distribution group with optional owner configuration. If no primary SMTP address is provided, the default verified domain is used.

#### Where to find
Org \ Mail \ Add Distribution List


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-equipment-mailbox'></a>

### Add Equipment Mailbox
#### Create an equipment mailbox

#### Description
Creates an Exchange Online equipment mailbox and optionally configures delegate access and calendar processing. If requested, the associated Entra ID user account is disabled after creation.

#### Where to find
Org \ Mail \ Add Equipment Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-or-remove-public-folder'></a>

### Add Or Remove Public Folder
#### Add or remove a public folder

#### Description
Creates or removes an Exchange Online public folder. The runbook assumes that at least one public folder mailbox already exists and does not provision public folder mailboxes.

#### Where to find
Org \ Mail \ Add Or Remove Public Folder


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-or-remove-teams-mailcontact'></a>

### Add Or Remove Teams Mailcontact
#### Create/Remove a contact, to allow pretty email addresses for Teams channels.

#### Description
Creates or updates a mail contact so a desired email address relays to the real Teams channel email address. The runbook can also remove the desired relay address again.

#### Where to find
Org \ Mail \ Add Or Remove Teams Mailcontact


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-or-remove-tenant-allow-block-list'></a>

### Add Or Remove Tenant Allow Block List
#### Add or remove entries from the Tenant Allow/Block List

#### Description
Adds or removes entries from the Tenant Allow/Block List in Microsoft Defender for Office 365. The runbook supports senders, URLs, and file hashes and sets new entries to expire after 30 days by default.

#### Where to find
Org \ Mail \ Add Or Remove Tenant Allow Block List


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-room-mailbox'></a>

### Add Room Mailbox
#### Create a room mailbox resource

#### Description
Creates an Exchange Online room mailbox and optionally configures delegation and calendar processing. If requested, the associated Entra ID user account is disabled after creation.

#### Where to find
Org \ Mail \ Add Room Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-shared-mailbox'></a>

### Add Shared Mailbox
#### Create a shared mailbox

#### Description
This script creates a shared mailbox in Exchange Online and configures various settings such as delegation, auto-mapping, and message copy options.
Also if specified, it disables the associated EntraID user account.

#### Where to find
Org \ Mail \ Add Shared Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-hide-mailboxes-(scheduled)'></a>

### Hide Mailboxes (Scheduled)
#### Hide or unhide special mailboxes in the Global Address List

#### Description
Hides or unhides special mailboxes in the Global Address List, currently intended for Bookings calendars. The runbook updates all scheduling mailboxes accordingly.

#### Where to find
Org \ Mail \ Hide Mailboxes_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-set-booking-config'></a>

### Set Booking Config
#### Configure Microsoft Bookings settings for the organization

#### Description
Configures Microsoft Bookings settings at the organization level using Exchange Online organization configuration. The runbook can optionally create an OWA mailbox policy for Bookings creators and disable Bookings in the default OWA policy.

#### Where to find
Org \ Mail \ Set Booking Config


[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-phone'></a>

## Phone
<a name='org-phone-get-teams-phone-number-assignment'></a>

### Get Teams Phone Number Assignment
#### Check whether a phone number is assigned in Microsoft Teams

#### Description
Looks up whether a given phone number is assigned to a user in Microsoft Teams. If the phone number is assigned, information about the user and relevant voice policies is returned.

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
#### Create a new Microsoft Defender for Endpoint indicator

#### Description
Creates a new indicator in Microsoft Defender for Endpoint to allow or block a specific file hash, certificate thumbprint, IP, domain, or URL. The indicator action can generate alerts automatically for audit or alert-and-block actions.

#### Where to find
Org \ Security \ Add Defender Indicator


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-backup-conditional-access-policies'></a>

### Backup Conditional Access Policies
#### Export Conditional Access policies to an Azure Storage account

#### Description
Exports the current set of Conditional Access policies via Microsoft Graph and uploads them as a ZIP archive to Azure Storage. If no container name is provided, a date-based name is generated.

#### Where to find
Org \ Security \ Backup Conditional Access Policies


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-admin-users'></a>

### List Admin Users
#### List Entra ID role holders and optionally evaluate their MFA methods

#### Description
Lists users and service principals holding built-in Entra ID roles and produces an admin-to-role report. Optionally queries each admin for registered authentication methods to assess MFA coverage.

#### Where to find
Org \ Security \ List Admin Users


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-expiring-role-assignments'></a>

### List Expiring Role Assignments
#### List Azure AD role assignments expiring within a given number of days

#### Description
Lists active and PIM-eligible Azure AD role assignments that expire within a specified number of days. The output includes role name, principal, and expiration date.

#### Where to find
Org \ Security \ List Expiring Role Assignments


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-inactive-devices'></a>

### List Inactive Devices
#### List or export inactive devices with no recent logon or Intune sync

#### Description
Collects devices based on either last interactive sign-in or last Intune sync date and lists them in the console. Optionally exports the results to a CSV file in Azure Storage.

#### Where to find
Org \ Security \ List Inactive Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-inactive-users'></a>

### List Inactive Users
#### List users with no recent interactive sign-ins

#### Description
Lists users and guests that have not signed in interactively for a specified number of days. Optionally includes accounts that never signed in and accounts that are blocked.

#### Where to find
Org \ Security \ List Inactive Users


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-information-protection-labels'></a>

### List Information Protection Labels
#### List Microsoft Information Protection labels

#### Description
Retrieves all available Microsoft Information Protection labels in the tenant. This can be used to get the label IDs for use in other runbooks, e.g. for auto-labeling based on sensitivity.

#### Where to find
Org \ Security \ List Information Protection Labels


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-pim-rolegroups-without-owners-(scheduled)'></a>

### List Pim Rolegroups Without Owners (Scheduled)
#### List role-assignable groups with eligible role assignments but without owners

#### Description
Finds role-assignable groups that have PIM eligible role assignments but no owners assigned. Optionally sends an email alert containing the group names.

#### Where to find
Org \ Security \ List Pim Rolegroups Without Owners_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-users-by-mfa-methods-count'></a>

### List Users By MFA Methods Count
#### Report users by the count of their registered MFA methods

#### Description
This Runbook retrieves a list of users from Azure AD and counts their registered MFA authentication methods.
As a dropdown for the MFA methods count range, you can select from "0 methods (no MFA)", "1-3 methods", "4-5 methods", or "6+ methods".
The output includes the user display name, user principal name, and the count of registered MFA methods.

#### Where to find
Org \ Security \ List Users By MFA Methods Count


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-vulnerable-app-regs'></a>

### List Vulnerable App Regs
#### List app registrations potentially vulnerable to CVE-2021-42306

#### Description
Lists Azure AD app registrations that may be affected by CVE-2021-42306 by inspecting stored key credentials. Optionally exports the findings to a CSV file in Azure Storage.

#### Where to find
Org \ Security \ List Vulnerable App Regs


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-monitor-pending-epm-requests-(scheduled)'></a>

### Monitor Pending EPM Requests (Scheduled)
#### Monitor and report pending Endpoint Privilege Management (EPM) elevation requests

#### Description
Queries Microsoft Intune for pending EPM elevation requests and sends an email report.
Email is only sent when there are pending requests.
Optionally includes detailed information about each request in a table and CSV attachment.

#### Where to find
Org \ Security \ Monitor Pending EPM Requests_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-notify-changed-ca-policies'></a>

### Notify Changed CA Policies
#### Send notification email if Conditional Access policies have been created or modified in the last 24 hours.

#### Description
Checks Conditional Access policies for changes in the last 24 hours and sends an email with a text attachment listing the changed policies. If no changes are detected, no email is sent.

#### Where to find
Org \ Security \ Notify Changed CA Policies


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-report-epm-elevation-requests-(scheduled)'></a>

### Report EPM Elevation Requests (Scheduled)
#### Generate report for Endpoint Privilege Management (EPM) elevation requests

#### Description
Queries Microsoft Intune for EPM elevation requests with flexible filtering options.
Supports filtering by multiple status types and time range.
Sends an email report with summary statistics and detailed CSV attachment.

#### Where to find
Org \ Security \ Report EPM Elevation Requests_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.



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
User \ AVD \ User Signout


[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-general'></a>

## General
<a name='user-general-assign-groups-by-template'></a>

### Assign Groups By Template
#### Assign cloud-only groups to a user based on a template

#### Description
Adds a user to one or more Entra ID groups using either group object IDs or display names. The list of groups is typically provided via runbook customization templates.

#### Where to find
User \ General \ Assign Groups By Template


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-assign-or-unassign-license'></a>

### Assign Or Unassign License
#### Assign or remove a license for a user via group membership

#### Description
Adds or removes a user to a dedicated license assignment group to control license allocation. The license group must match the configured naming convention.

#### Where to find
User \ General \ Assign Or Unassign License


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-assign-windows365'></a>

### Assign Windows365
#### Assign and provision a Windows 365 Cloud PC for a user

#### Description
Assigns the required groups and license or Frontline provisioning policy to initiate Windows 365 provisioning. Optionally notifies the user when provisioning completes and can create a support ticket when licenses are exhausted.

#### Where to find
User \ General \ Assign Windows365


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-list-group-memberships'></a>

### List Group Memberships
#### List group memberships for this user

#### Description
Lists group memberships for this user and supports filtering by group type, membership type, role-assignable status, Teams enablement, source, and writeback status. Outputs the results as CSV-formatted text.

#### Where to find
User \ General \ List Group Memberships


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-list-group-ownerships'></a>

### List Group Ownerships
#### List group ownerships for this user.

#### Description
Lists Entra ID groups where the specified user is an owner. Outputs the group names and IDs.

#### Where to find
User \ General \ List Group Ownerships


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-list-manager'></a>

### List Manager
#### List manager information for this user

#### Description
Retrieves the manager object for a specified user. Outputs common manager attributes such as display name, email, and phone numbers.

#### Where to find
User \ General \ List Manager


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-offboard-user-permanently'></a>

### Offboard User Permanently
#### Permanently offboard a user

#### Description
Permanently offboards a user by revoking access, disabling or deleting the account, adjusting group and license assignments, and optionally exporting memberships. Optionally removes or replaces group ownerships when required.

#### Where to find
User \ General \ Offboard User Permanently


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-offboard-user-temporarily'></a>

### Offboard User Temporarily
#### Temporarily offboard a user

#### Description
Temporarily offboards a user for scenarios such as parental leave or sabbatical by disabling access, adjusting group and license assignments, and optionally exporting memberships. Optionally removes or replaces group ownerships when required.

#### Where to find
User \ General \ Offboard User Temporarily


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-reprovision-windows365'></a>

### Reprovision Windows365
#### Reprovision a Windows 365 Cloud PC

#### Description
Triggers a reprovision action for an existing Windows 365 Cloud PC without assigning a new instance. Optionally notifies the user when reprovisioning starts.

#### Where to find
User \ General \ Reprovision Windows365


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-resize-windows365'></a>

### Resize Windows365
#### Resize an existing Windows 365 Cloud PC for a user

#### Description
Resizes a Windows 365 Cloud PC by removing the current assignment and provisioning a new size using a different license group.
WARNING: This operation deprovisions and reprovisions the Cloud PC and local data may be lost.

#### Where to find
User \ General \ Resize Windows365


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-unassign-windows365'></a>

### Unassign Windows365
#### Remove and deprovision a Windows 365 Cloud PC for a user

#### Description
Removes Windows 365 assignments for a user and deprovisions the associated Cloud PC. Optionally ends the grace period immediately to trigger faster removal.

#### Where to find
User \ General \ Unassign Windows365


[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-mail'></a>

## Mail
<a name='user-mail-add-or-remove-email-address'></a>

### Add Or Remove Email Address
#### Add or remove an email address for a mailbox

#### Description
Adds or removes an alias email address on a mailbox and can optionally set it as the primary address.

#### Where to find
User \ Mail \ Add Or Remove Email Address


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-assign-owa-mailbox-policy'></a>

### Assign Owa Mailbox Policy
#### Assign an OWA mailbox policy to a user

#### Description
Assigns an OWA mailbox policy to a mailbox in Exchange Online. This can be used to enable or restrict features such as Microsoft Bookings.

#### Where to find
User \ Mail \ Assign Owa Mailbox Policy


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-convert-to-shared-mailbox'></a>

### Convert To Shared Mailbox
#### Convert a user mailbox to a shared mailbox and back

#### Description
Converts a mailbox to a shared mailbox or reverts it back to a regular user mailbox. Optionally delegates access and adjusts group memberships and license groups.

#### Where to find
User \ Mail \ Convert To Shared Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-delegate-full-access'></a>

### Delegate Full Access
#### Delegate FullAccess permissions to another user on a mailbox or remove existing delegation

#### Description
Grants or removes FullAccess permissions for a delegate on a mailbox. Optionally enables Outlook automapping when granting access.
Also shows the current and new permissions for the mailbox.
Automapping allows the delegated mailbox to automatically appear in the delegate's Outlook client.

#### Where to find
User \ Mail \ Delegate Full Access


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-delegate-send-as'></a>

### Delegate Send As
#### Delegate SendAs permissions for other user on his/her mailbox or remove existing delegation

#### Description
Grants or removes SendAs permissions for a delegate on a mailbox in Exchange Online. The current permissions are shown before and after applying the change.
This allows the delegate to send emails as if they were the mailbox owner.

#### Where to find
User \ Mail \ Delegate Send As


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-delegate-send-on-behalf'></a>

### Delegate Send On Behalf
#### Delegate SendOnBehalf permissions for the user's mailbox

#### Description
Grants or removes SendOnBehalf permissions for a delegate on the user's mailbox. Outputs the resulting SendOnBehalf trustees after applying the change.
This allows the delegate to send emails on behalf of the mailbox owner.

#### Where to find
User \ Mail \ Delegate Send On Behalf


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-hide-or-unhide-in-addressbook'></a>

### Hide Or Unhide In Addressbook
#### Hide or unhide a mailbox in the address book

#### Description
Hides or unhides a mailbox from the global address lists. Important: This change can take up to 72 hours until it is reflected in the global address list.

#### Where to find
User \ Mail \ Hide Or Unhide In Addressbook


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-list-mailbox-permissions'></a>

### List Mailbox Permissions
#### List mailbox permissions for a mailbox

#### Description
Lists different types of permissions like mailbox access, SendAs, and SendOnBehalf permissions for a mailbox. Outputs each permission type as formatted tables. This also works for shared mailboxes.

#### Where to find
User \ Mail \ List Mailbox Permissions


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-list-room-mailbox-configuration'></a>

### List Room Mailbox Configuration
#### List room mailbox configuration

#### Description
Reads room metadata and lists calendar processing settings. This helps validate room resource configuration and booking behavior.

#### Where to find
User \ Mail \ List Room Mailbox Configuration


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-remove-mailbox'></a>

### Remove Mailbox
#### Hard delete a shared mailbox, room or bookings calendar

#### Description
Forces a deletion of a shared mailbox, room mailbox, or bookings calendar. The mailbox type is validated before deletion.

#### Where to find
User \ Mail \ Remove Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-set-out-of-office'></a>

### Set Out Of Office
#### Enable or disable out-of-office notifications for a mailbox

#### Description
Configures automatic replies for a mailbox and optionally creates an out-of-office calendar event. The runbook can either enable scheduled replies or disable them.

#### Where to find
User \ Mail \ Set Out Of Office


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-set-room-mailbox-configuration'></a>

### Set Room Mailbox Configuration
#### Set room mailbox resource policies

#### Description
Updates room mailbox settings such as booking policy, calendar processing, and capacity. The runbook can optionally restrict BookInPolicy to members of a specific mail-enabled security group.

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
Removes the assigned phone number and clears selected Teams voice policies for a Teams-enabled user. This fullfills the telephony offboarding scenarios.

#### Where to find
User \ Phone \ Disable Teams Phone


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-phone-get-teams-user-info'></a>

### Get Teams User Info
#### Get Microsoft Teams voice status for a user

#### Description
Retrieves voice-related status information for a Teams user such as phone number assignment, call forwarding settings, voicemail configuration, and policy assignments. The output is intended for troubleshooting and validation.

#### Where to find
User \ Phone \ Get Teams User Info


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-phone-grant-teams-user-policies'></a>

### Grant Teams User Policies
#### Grant Microsoft Teams policies to a Microsoft Teams enabled user

#### Description
Assigns selected Teams policies for a Teams-enabled user. Policies are only changed when a value is provided, and assignments can be cleared by using the value "Global (Org Wide Default)".
It allows to assign the following policies: Online Voice Routing Policy, Tenant Dial Plan, Teams Calling Policy, Teams IP Phone Policy, Online Voicemail Policy, Teams Meeting Policy and Teams Meeting Broadcast Policy (Live Event Policy).

#### Where to find
User \ Phone \ Grant Teams User Policies


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-phone-set-teams-permanent-call-forwarding'></a>

### Set Teams Permanent Call Forwarding
#### Set immediate call forwarding for a Teams user

#### Description
Configures immediate call forwarding for a Teams Enterprise Voice user to a Teams user, a phone number, voicemail, or the user's delegates. The runbook can also disable immediate forwarding.

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
#### Confirm compromise or dismiss a risky user

#### Description
Confirms a user compromise or dismisses a risky user entry using Microsoft Entra ID Identity Protection. This helps security teams remediate and track risky sign-in events.

#### Where to find
User \ Security \ Confirm Or Dismiss Risky User


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-create-temporary-access-pass'></a>

### Create Temporary Access Pass
#### Create a temporary access pass for a user

#### Description
Creates a new Temporary Access Pass (TAP) authentication method for a user in Microsoft Entra ID. Existing TAPs for the user are removed before creating a new one.

#### Where to find
User \ Security \ Create Temporary Access Pass


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-enable-or-disable-password-expiration'></a>

### Enable Or Disable Password Expiration
#### Enable or disable password expiration for a user

#### Description
Updates the password policy for a user in Microsoft Entra ID. This can be used to disable password expiration or re-enable the default expiration behavior.

#### Where to find
User \ Security \ Enable Or Disable Password Expiration


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-reset-mfa'></a>

### Reset Mfa
#### Remove all App- and Mobilephone auth methods for a user

#### Description
Removes authenticator app and phone-based authentication methods for a user. This forces the user to re-enroll MFA methods after the reset.

#### Where to find
User \ Security \ Reset Mfa


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-reset-password'></a>

### Reset Password
#### Reset a user's password

#### Description
Resets the password for a user in Microsoft Entra ID and optionally enables the account first. The user can be forced to change the password at the next sign-in. This runbook is useful for helpdesk scenarios where a technician needs to reset a user's password and ensure that the user updates it upon next login.

#### Where to find
User \ Security \ Reset Password


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-revoke-or-restore-access'></a>

### Revoke Or Restore Access
#### Revoke or restore user access

#### Description
Blocks or re-enables a user account and optionally revokes active sign-in sessions. This can be used during incident response to immediately invalidate user tokens.

#### Where to find
User \ Security \ Revoke Or Restore Access


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-set-or-remove-mobile-phone-mfa'></a>

### Set Or Remove Mobile Phone Mfa
#### Set or remove a user's mobile phone MFA method

#### Description
Adds, updates, or removes the user's mobile phone authentication method. If you need to change a number, remove the existing method first and then add the new number.

#### Where to find
User \ Security \ Set Or Remove Mobile Phone Mfa


[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-userinfo'></a>

## Userinfo
<a name='user-userinfo-rename-user'></a>

### Rename User
#### Rename a user or mailbox

#### Description
Renames a user by changing the user principal name in Microsoft Entra ID and optionally updates mailbox properties in Exchange Online. This does not update user metadata such as display name, given name, or surname.

#### Where to find
User \ Userinfo \ Rename User


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-userinfo-set-photo'></a>

### Set Photo
#### Set the profile photo for a user

#### Description
Downloads a JPEG image from a URL and uploads it as the user's profile photo. This is useful to set or update user avatars in Microsoft 365.

#### Where to find
User \ Userinfo \ Set Photo


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-userinfo-update-user'></a>

### Update User
#### Update user metadata and memberships

#### Description
Updates user profile properties in Microsoft Entra ID and applies optional group memberships and Exchange Online settings. This runbook is typically used to finalize onboarding or to correct user metadata.

#### Where to find
User \ Userinfo \ Update User


[Back to Table of Content](#table-of-contents)

 
 


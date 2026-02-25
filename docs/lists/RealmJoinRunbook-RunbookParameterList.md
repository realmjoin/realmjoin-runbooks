<a name='runbook-parameter-overview'></a>
# Overview
This document provides a comprehensive overview of all parameters used in the runbooks available in the RealmJoin portal. Each parameter is listed with its type and whether it is required or optional.

To ensure easy navigation, the runbooks are categorized into different sections based on their area of application. The following categories are currently available:
- device
- group
- org
- user

Each category contains multiple runbooks that are further divided into subcategories based on their functionality. For runbooks with multiple parameters, each parameter is listed in a separate row.

# Table of Contents
- [Device](#device)
  - [AVD](#device-avd)
    - [Restart Host](#device-avd-restart-host)
    - [Toggle Drain Mode](#device-avd-toggle-drain-mode)
  - [General](#device-general)
    - [Change Grouptag](#device-general-change-grouptag)
    - [Check Updatable Assets](#device-general-check-updatable-assets)
    - [Enroll Updatable Assets](#device-general-enroll-updatable-assets)
    - [Outphase Device](#device-general-outphase-device)
    - [Remove Primary User](#device-general-remove-primary-user)
    - [Rename Device](#device-general-rename-device)
    - [Unenroll Updatable Assets](#device-general-unenroll-updatable-assets)
    - [Wipe Device](#device-general-wipe-device)
  - [Security](#device-security)
    - [Enable Or Disable Device](#device-security-enable-or-disable-device)
    - [Isolate Or Release Device](#device-security-isolate-or-release-device)
    - [Reset Mobile Device Pin](#device-security-reset-mobile-device-pin)
    - [Restrict Or Release Code Execution](#device-security-restrict-or-release-code-execution)
    - [Show Bitlocker Recovery Key](#device-security-show-bitlocker-recovery-key)
    - [Show LAPS Password](#device-security-show-laps-password)
- [Group](#group)
  - [Devices](#group-devices)
    - [Check Updatable Assets](#group-devices-check-updatable-assets)
    - [Unenroll Updatable Assets (Scheduled)](#group-devices-unenroll-updatable-assets-scheduled)
  - [General](#group-general)
    - [Add Or Remove Nested Group](#group-general-add-or-remove-nested-group)
    - [Add Or Remove Owner](#group-general-add-or-remove-owner)
    - [Add Or Remove User](#group-general-add-or-remove-user)
    - [Change Visibility](#group-general-change-visibility)
    - [List All Members](#group-general-list-all-members)
    - [List Owners](#group-general-list-owners)
    - [List User Devices](#group-general-list-user-devices)
    - [Remove Group](#group-general-remove-group)
    - [Rename Group](#group-general-rename-group)
  - [Mail](#group-mail)
    - [Enable Or Disable External Mail](#group-mail-enable-or-disable-external-mail)
    - [Show Or Hide In Address Book](#group-mail-show-or-hide-in-address-book)
  - [Teams](#group-teams)
    - [Archive Team](#group-teams-archive-team)
- [Organization](#organization)
  - [Applications](#organization-applications)
    - [Add Application Registration](#organization-applications-add-application-registration)
    - [Delete Application Registration](#organization-applications-delete-application-registration)
    - [Export Enterprise Application Users](#organization-applications-export-enterprise-application-users)
    - [List Inactive Enterprise Applications](#organization-applications-list-inactive-enterprise-applications)
    - [Report Application Registration](#organization-applications-report-application-registration)
    - [Report Expiring Application Credentials (Scheduled)](#organization-applications-report-expiring-application-credentials-scheduled)
    - [Update Application Registration](#organization-applications-update-application-registration)
  - [Devices](#organization-devices)
    - [Add Autopilot Device](#organization-devices-add-autopilot-device)
    - [Add Device Via Corporate Identifier](#organization-devices-add-device-via-corporate-identifier)
    - [Delete Stale Devices (Scheduled)](#organization-devices-delete-stale-devices-scheduled)
    - [Get Bitlocker Recovery Key](#organization-devices-get-bitlocker-recovery-key)
    - [Notify Users About Stale Devices (Scheduled)](#organization-devices-notify-users-about-stale-devices-scheduled)
    - [Outphase Devices](#organization-devices-outphase-devices)
    - [Report Devices Without Primary User](#organization-devices-report-devices-without-primary-user)
    - [Report Stale Devices (Scheduled)](#organization-devices-report-stale-devices-scheduled)
    - [Report Users With More Than 5-Devices](#organization-devices-report-users-with-more-than-5-devices)
    - [Sync Device Serialnumbers To Entraid (Scheduled)](#organization-devices-sync-device-serialnumbers-to-entraid-scheduled)
  - [General](#organization-general)
    - [Add Devices Of Users To Group (Scheduled)](#organization-general-add-devices-of-users-to-group-scheduled)
    - [Add Management Partner](#organization-general-add-management-partner)
    - [Add Microsoft Store App Logos](#organization-general-add-microsoft-store-app-logos)
    - [Add Office365 Group](#organization-general-add-office365-group)
    - [Add Or Remove Safelinks Exclusion](#organization-general-add-or-remove-safelinks-exclusion)
    - [Add Or Remove Smartscreen Exclusion](#organization-general-add-or-remove-smartscreen-exclusion)
    - [Add Or Remove Trusted Site](#organization-general-add-or-remove-trusted-site)
    - [Add Security Group](#organization-general-add-security-group)
    - [Add User](#organization-general-add-user)
    - [Add Viva Engange Community](#organization-general-add-viva-engange-community)
    - [Assign Groups By Template (Scheduled)](#organization-general-assign-groups-by-template-scheduled)
    - [Bulk Delete Devices From Autopilot](#organization-general-bulk-delete-devices-from-autopilot)
    - [Bulk Retire Devices From Intune](#organization-general-bulk-retire-devices-from-intune)
    - [Check AAD Sync Status (Scheduled)](#organization-general-check-aad-sync-status-scheduled)
    - [Check Assignments Of Devices](#organization-general-check-assignments-of-devices)
    - [Check Assignments Of Groups](#organization-general-check-assignments-of-groups)
    - [Check Assignments Of Users](#organization-general-check-assignments-of-users)
    - [Check Autopilot Serialnumbers](#organization-general-check-autopilot-serialnumbers)
    - [Check Device Onboarding Exclusion (Scheduled)](#organization-general-check-device-onboarding-exclusion-scheduled)
    - [Enrolled Devices Report (Scheduled)](#organization-general-enrolled-devices-report-scheduled)
    - [Export All Autopilot Devices](#organization-general-export-all-autopilot-devices)
    - [Export All Intune Devices](#organization-general-export-all-intune-devices)
    - [Export Cloudpc Usage (Scheduled)](#organization-general-export-cloudpc-usage-scheduled)
    - [Export Non Compliant Devices](#organization-general-export-non-compliant-devices)
    - [Export Policy Report](#organization-general-export-policy-report)
    - [Invite External Guest Users](#organization-general-invite-external-guest-users)
    - [List All Administrative Template Policies](#organization-general-list-all-administrative-template-policies)
    - [List Group License Assignment Errors](#organization-general-list-group-license-assignment-errors)
    - [Office365 License Report](#organization-general-office365-license-report)
    - [Report Apple MDM Cert Expiry (Scheduled)](#organization-general-report-apple-mdm-cert-expiry-scheduled)
    - [Report License Assignment (Scheduled)](#organization-general-report-license-assignment-scheduled)
    - [Report PIM Activations (Scheduled)](#organization-general-report-pim-activations-scheduled)
    - [Sync All Devices](#organization-general-sync-all-devices)
  - [Mail](#organization-mail)
    - [Add Distribution List](#organization-mail-add-distribution-list)
    - [Add Equipment Mailbox](#organization-mail-add-equipment-mailbox)
    - [Add Or Remove Public Folder](#organization-mail-add-or-remove-public-folder)
    - [Add Or Remove Teams Mailcontact](#organization-mail-add-or-remove-teams-mailcontact)
    - [Add Or Remove Tenant Allow Block List](#organization-mail-add-or-remove-tenant-allow-block-list)
    - [Add Room Mailbox](#organization-mail-add-room-mailbox)
    - [Add Shared Mailbox](#organization-mail-add-shared-mailbox)
    - [Hide Mailboxes (Scheduled)](#organization-mail-hide-mailboxes-scheduled)
    - [Set Booking Config](#organization-mail-set-booking-config)
  - [Phone](#organization-phone)
    - [Get Teams Phone Number Assignment](#organization-phone-get-teams-phone-number-assignment)
  - [Security](#organization-security)
    - [Add Defender Indicator](#organization-security-add-defender-indicator)
    - [Backup Conditional Access Policies](#organization-security-backup-conditional-access-policies)
    - [List Admin Users](#organization-security-list-admin-users)
    - [List Expiring Role Assignments](#organization-security-list-expiring-role-assignments)
    - [List Inactive Devices](#organization-security-list-inactive-devices)
    - [List Inactive Users](#organization-security-list-inactive-users)
    - [List Information Protection Labels](#organization-security-list-information-protection-labels)
    - [List PIM Rolegroups Without Owners (Scheduled)](#organization-security-list-pim-rolegroups-without-owners-scheduled)
    - [List Users By MFA Methods Count](#organization-security-list-users-by-mfa-methods-count)
    - [List Vulnerable App Regs](#organization-security-list-vulnerable-app-regs)
    - [Monitor Pending EPM Requests (Scheduled)](#organization-security-monitor-pending-epm-requests-scheduled)
    - [Notify Changed CA Policies](#organization-security-notify-changed-ca-policies)
    - [Report EPM Elevation Requests (Scheduled)](#organization-security-report-epm-elevation-requests-scheduled)
- [User](#user)
  - [AVD](#user-avd)
    - [User Signout](#user-avd-user-signout)
  - [General](#user-general)
    - [Assign Groups By Template](#user-general-assign-groups-by-template)
    - [Assign Or Unassign License](#user-general-assign-or-unassign-license)
    - [Assign Windows365](#user-general-assign-windows365)
    - [List Group Memberships](#user-general-list-group-memberships)
    - [List Group Ownerships](#user-general-list-group-ownerships)
    - [List Manager](#user-general-list-manager)
    - [Offboard User Permanently](#user-general-offboard-user-permanently)
    - [Offboard User Temporarily](#user-general-offboard-user-temporarily)
    - [Reprovision Windows365](#user-general-reprovision-windows365)
    - [Resize Windows365](#user-general-resize-windows365)
    - [Unassign Windows365](#user-general-unassign-windows365)
  - [Mail](#user-mail)
    - [Add Or Remove Email Address](#user-mail-add-or-remove-email-address)
    - [Assign OWA Mailbox Policy](#user-mail-assign-owa-mailbox-policy)
    - [Convert To Shared Mailbox](#user-mail-convert-to-shared-mailbox)
    - [Delegate Full Access](#user-mail-delegate-full-access)
    - [Delegate Send As](#user-mail-delegate-send-as)
    - [Delegate Send On Behalf](#user-mail-delegate-send-on-behalf)
    - [Hide Or Unhide In Addressbook](#user-mail-hide-or-unhide-in-addressbook)
    - [List Mailbox Permissions](#user-mail-list-mailbox-permissions)
    - [List Room Mailbox Configuration](#user-mail-list-room-mailbox-configuration)
    - [Remove Mailbox](#user-mail-remove-mailbox)
    - [Set Out Of Office](#user-mail-set-out-of-office)
    - [Set Room Mailbox Configuration](#user-mail-set-room-mailbox-configuration)
  - [Phone](#user-phone)
    - [Disable Teams Phone](#user-phone-disable-teams-phone)
    - [Get Teams User Info](#user-phone-get-teams-user-info)
    - [Grant Teams User Policies](#user-phone-grant-teams-user-policies)
    - [Set Teams Permanent Call Forwarding](#user-phone-set-teams-permanent-call-forwarding)
    - [Set Teams Phone](#user-phone-set-teams-phone)
  - [Security](#user-security)
    - [Confirm Or Dismiss Risky User](#user-security-confirm-or-dismiss-risky-user)
    - [Create Temporary Access Pass](#user-security-create-temporary-access-pass)
    - [Enable Or Disable Password Expiration](#user-security-enable-or-disable-password-expiration)
    - [Reset MFA](#user-security-reset-mfa)
    - [Reset Password](#user-security-reset-password)
    - [Revoke Or Restore Access](#user-security-revoke-or-restore-access)
    - [Set Or Remove Mobile Phone MFA](#user-security-set-or-remove-mobile-phone-mfa)
  - [Userinfo](#user-userinfo)
    - [Rename User](#user-userinfo-rename-user)
    - [Set Photo](#user-userinfo-set-photo)
    - [Update User](#user-userinfo-update-user)

<a name='device'></a>
# Device
<a name='device-avd'></a>
## AVD

<a name='device-avd-restart-host'></a>

### Restart Host
Reboots a specific AVD Session Host.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceName | ✓ | String | The name of the AVD Session Host device to restart. Hidden in UI |
| SubscriptionIds | ✓ | String Array | Array of Azure subscription IDs where the AVD Session Host resources are located. Retrieved from AVD.SubscriptionIds setting (Customization). Hidden in UI |
| CallerName | ✓ | String | The name of the user executing the runbook. Used for auditing purposes. Hidden in UI |

<a name='device-avd-toggle-drain-mode'></a>

### Toggle Drain Mode
Sets Drainmode on true or false for a specific AVD Session Host.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceName | ✓ | String | The name of the AVD Session Host device for which to toggle drain mode. Hidden in UI. |
| DrainMode | ✓ | Boolean | Boolean value to enable or disable Drain Mode. Set to true to enable Drain Mode (prevent new sessions), false to disable it (allow new sessions). Default is false. |
| SubscriptionIds | ✓ | String Array | Array of Azure subscription IDs where the AVD Session Host resources are located. Retrieved from AVD.SubscriptionIds setting (Customization). Hidden in UI. |
| CallerName | ✓ | String | The name of the user executing the runbook. Used for auditing purposes. Hidden in UI. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='device-general'></a>
## General

<a name='device-general-change-grouptag'></a>

### Change Grouptag
Assign a new AutoPilot GroupTag to this device.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String | The device ID of the target device. |
| newGroupTag |  | String | The new AutoPilot GroupTag to assign to the device. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='device-general-check-updatable-assets'></a>

### Check Updatable Assets
Check if a device is onboarded to Windows Update for Business

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| DeviceId | ✓ | String | DeviceId of the device to check. |

<a name='device-general-enroll-updatable-assets'></a>

### Enroll Updatable Assets
Enroll device into Windows Update for Business.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| DeviceId | ✓ | String | DeviceId of the device to unenroll. |
| UpdateCategory | ✓ | String | Category of updates to enroll into. Possible values are: driver, feature or quality. |

<a name='device-general-outphase-device'></a>

### Outphase Device
Remove/Outphase a windows device

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String | The device ID of the target device. |
| intuneAction |  | Int32 | Determines the Intune action to perform (wipe, delete, or none). |
| aadAction |  | Int32 | Determines the Entra ID (Azure AD) action to perform (delete, disable, or none). |
| wipeDevice |  | Boolean | If set to true, triggers a wipe action in Intune. |
| removeIntuneDevice |  | Boolean | If set to true, deletes the Intune device object. |
| removeAutopilotDevice |  | Boolean | "Delete device from AutoPilot database?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will delete the device from the AutoPilot database, which also allows the device to leave the tenant. If set to false, the device will remain in the AutoPilot database and can be re-assigned to another user/device in the tenant. |
| removeAADDevice |  | Boolean | "Delete device from EntraID?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will delete the device object from Entra ID (Azure AD). If set to false, the device object will remain in Entra ID (Azure AD). |
| disableAADDevice |  | Boolean | "Disable device in EntraID?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will disable the device object in Entra ID (Azure AD). If set to false, the device object will remain enabled in Entra ID (Azure AD). |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='device-general-remove-primary-user'></a>

### Remove Primary User
Removes the primary user from a device.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String | The unique identifier of the device from which the primary user will be removed.<br>It will be prefilled from the RealmJoin Portal and is hidden in the UI. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='device-general-rename-device'></a>

### Rename Device
Rename a device.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String | The device ID of the target device. |
| NewDeviceName | ✓ | String | The new device name to set. This runbook validates the name against common Windows hostname constraints. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='device-general-unenroll-updatable-assets'></a>

### Unenroll Updatable Assets
Unenroll device from Windows Update for Business.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| DeviceId | ✓ | String | DeviceId of the device to unenroll. |
| UpdateCategory | ✓ | String | Category of updates to unenroll from. Possible values are: driver, feature, quality or all (delete). |

<a name='device-general-wipe-device'></a>

### Wipe Device
Wipe a Windows or MacOS device

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String | The device ID of the target device. |
| wipeDevice |  | Boolean | "Wipe this device?" (final value: true) or "Do not wipe device" (final value: false) can be selected as action to perform. If set to true, the runbook will trigger a wipe action for the device in Intune. If set to false, no wipe action will be triggered for the device in Intune. |
| useProtectedWipe |  | Boolean | Windows-only. If set to true, uses protected wipe. |
| removeIntuneDevice |  | Boolean | If set to true, deletes the Intune device object. |
| removeAutopilotDevice |  | Boolean | Windows-only. "Delete device from AutoPilot database?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will delete the device from the AutoPilot database, which also allows the device to leave the tenant. If set to false, the device will remain in the AutoPilot database and can be re-assigned to another user/device in the tenant. |
| removeAADDevice |  | Boolean | "Delete device from EntraID?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will delete the device object from Entra ID (Azure AD). If set to false, the device object will remain in Entra ID (Azure AD). |
| disableAADDevice |  | Boolean | "Disable device in EntraID?" (final value: true) or "Keep device / do not care" (final value: false) can be selected as action to perform. If set to true, the runbook will disable the device object in Entra ID (Azure AD). If set to false, the device object will remain enabled in Entra ID (Azure AD). |
| macOsRecoveryCode |  | String | MacOS-only. Recovery code for older devices; newer devices may not require this. |
| macOsObliterationBehavior |  | String | MacOS-only. Controls the OS obliteration behavior during wipe. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='device-security'></a>
## Security

<a name='device-security-enable-or-disable-device'></a>

### Enable Or Disable Device
Enable or disable a device in Entra ID

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String | The device ID of the target device. |
| Enable |  | Boolean | "Disable Device?" (final value: false) or "Enable Device again?" (final value: true) can be selected as action to perform. If set to false, the runbook will disable the device in Entra ID (Azure AD). If set to true, the runbook will enable the device in Entra ID (Azure AD) again. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='device-security-isolate-or-release-device'></a>

### Isolate Or Release Device
Isolate this device.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String | The device ID of the target device. |
| Release | ✓ | Boolean | "Isolate Device" (final value: false) or "Release Device from Isolation" (final value: true) can be selected as action to perform. If set to false, the runbook will isolate the device in Defender for Endpoint. If set to true, it will release a previously isolated device from isolation in Defender for Endpoint. |
| IsolationType |  | String | The isolation type to use when isolating the device. |
| Comment | ✓ | String | A short reason for the (un)isolation action. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='device-security-reset-mobile-device-pin'></a>

### Reset Mobile Device Pin
Reset a mobile device's password/PIN code.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String | The device ID of the target device. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='device-security-restrict-or-release-code-execution'></a>

### Restrict Or Release Code Execution
Only allow Microsoft-signed code to run on a device, or remove an existing restriction.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String | The device ID of the target device. |
| Release | ✓ | Boolean | "Restrict Code Execution" (final value: false) or "Remove Code Restriction" (final value: true) can be selected as action to perform. If set to false, the runbook will restrict code execution on the device in Defender for Endpoint. If set to true, it will remove an existing code execution restriction on the device in Defender for Endpoint. |
| Comment | ✓ | String | A short reason for the (un)restriction action. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='device-security-show-bitlocker-recovery-key'></a>

### Show Bitlocker Recovery Key
Show all BitLocker recovery keys for a device

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String | The device ID of the target device. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='device-security-show-laps-password'></a>

### Show LAPS Password
Show a local admin password for a device.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String | The device ID of the target device. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='group'></a>
# Group
<a name='group-devices'></a>
## Devices

<a name='group-devices-check-updatable-assets'></a>

### Check Updatable Assets
Check if devices in a group are onboarded to Windows Update for Business.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| GroupId | ✓ | String | Object ID of the group whose device members will be checked. |

<a name='group-devices-unenroll-updatable-assets-scheduled'></a>

### Unenroll Updatable Assets (Scheduled)
Unenroll devices from Windows Update for Business.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| GroupId | ✓ | String | Object ID of the group whose device members will be unenrolled. |
| UpdateCategory | ✓ | String | The update category to unenroll from. Supported values are driver, feature, quality, or all. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='group-general'></a>
## General

<a name='group-general-add-or-remove-nested-group'></a>

### Add Or Remove Nested Group
Add/remove a nested group to/from a group

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String | Object ID of the target group. |
| NestedGroupID | ✓ | String | Object ID of the group to add as a nested member. |
| Remove |  | Boolean | Set to true to remove the nested group membership, or false to add it. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='group-general-add-or-remove-owner'></a>

### Add Or Remove Owner
Add or remove a Office 365 group owner

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String | Object ID of the target group. |
| UserId | ✓ | String | Object ID of the user to add or remove. |
| Remove |  | Boolean | "Add User as Owner" (final value: $false) or "Remove User as Owner" (final value: $true) can be selected as action to perform. If set to true, the runbook will remove the user from the group owners. If set to false, it will add the user as an owner of the group. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='group-general-add-or-remove-user'></a>

### Add Or Remove User
Add or remove a group member

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String | Object ID of the target group. |
| UserId | ✓ | String | Object ID of the user to add or remove. |
| Remove |  | Boolean | "Add User to Group" (final value: $false) or "Remove User from Group" (final value: $true) can be selected as action to perform. If set to true, the runbook will remove the user from the group. If set to false, it will add the user to the group. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='group-general-change-visibility'></a>

### Change Visibility
Change a group's visibility

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String | Object ID of the target group. |
| Public |  | Boolean | "Make group private" (final value: $false) or "Make group public" (final value: $true) can be selected as action to perform. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='group-general-list-all-members'></a>

### List All Members
List all members of a group, including members that are part of nested groups

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupId | ✓ | String | The Object ID of the Microsoft Entra ID group whose membership will be retrieved. |
| CallerName |  | String | Caller name for auditing purposes. |

<a name='group-general-list-owners'></a>

### List Owners
List all owners of an Office 365 group.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String | Object ID of the target group. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='group-general-list-user-devices'></a>

### List User Devices
List devices owned by group members.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String | Object ID of the group whose members will be evaluated. |
| moveGroup |  | Boolean | If set to true, the discovered devices are added to the target device group. |
| targetgroup |  | String | Object ID of the target device group that receives the devices when moveGroup is enabled. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='group-general-remove-group'></a>

### Remove Group
Remove a group. For Microsoft 365 groups, also the associated resources (Teams, SharePoint site) will be removed.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupId | ✓ | String | Object ID of the group to delete. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='group-general-rename-group'></a>

### Rename Group
Rename a group.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupId | ✓ | String | Object ID of the group to update. |
| DisplayName |  | String | New display name for the group. |
| MailNickname |  | String | New mail nickname (alias) for the group. |
| Description |  | String | New description for the group. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='group-mail'></a>
## Mail

<a name='group-mail-enable-or-disable-external-mail'></a>

### Enable Or Disable External Mail
Enable or disable external parties to send emails to a Microsoft 365 group

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupId | ✓ | String | Object ID of the Microsoft 365 group. |
| Action |  | Int32 | "Enable External Mail" (final value: 0), "Disable External Mail" (final value: 1) or "Query current state only" (final value: 2) can be selected as action to perform. If set to 0, the runbook will allow external senders to email the group. If set to 1, it will block external senders from emailing the group. If set to 2, it will return whether external mailing is currently enabled or disabled for the group without making any changes. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='group-mail-show-or-hide-in-address-book'></a>

### Show Or Hide In Address Book
Show or hide a group in the address book

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupName | ✓ | String | The identity of the target group (name, alias, or other Exchange identity value). |
| Action |  | Int32 | "Show Group in Address Book" (final value: 0), "Hide Group from Address Book" (final value: 1) or "Query current state only" (final value: 2) can be selected as action to perform. If set to 0, the runbook will make the group visible in address lists. If set to 1, it will hide the group from address lists. If set to 2, it will return whether the group is currently hidden from address lists without making any changes. |
| CallerName | ✓ | String | Caller name for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='group-teams'></a>
## Teams

<a name='group-teams-archive-team'></a>

### Archive Team
Archive a team

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String | Object ID of the Microsoft 365 group that backs the team. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='organization'></a>
# Organization
<a name='organization-applications'></a>
## Applications

<a name='organization-applications-add-application-registration'></a>

### Add Application Registration
Add an application registration to Azure AD

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ApplicationName | ✓ | String | The display name of the application registration to create. |
| RedirectURI |  | String | Used for UI selection only. Determines which redirect URI type to configure - None, Web, SPA, or Public Client |
| signInAudience |  | String | Specifies who can use the application. Defaults to "AzureADMyOrg" (single tenant). |
| webRedirectURI |  | String | Redirect URI or URIs for web applications. Multiple values can be separated by semicolons. |
| spaRedirectURI |  | String | Redirect URI or URIs for single-page applications. Multiple values can be separated by semicolons. |
| publicClientRedirectURI |  | String | Redirect URI or URIs for public client/native applications. Multiple values can be separated by semicolons. |
| EnableSAML |  | Boolean | If set to true, SAML-based authentication is configured for the application. If enabled, additional SAML-related parameters become required. |
| SAMLReplyURL |  | String | The reply URL for SAML-based authentication |
| SAMLSignOnURL |  | String | The sign-on URL for SAML authentication. |
| SAMLLogoutURL |  | String | The logout URL for SAML authentication. |
| SAMLIdentifier |  | String | The SAML identifier (Entity ID). If not specified, defaults to "urn:app:{AppId}". |
| SAMLRelayState |  | String | The SAML relay state parameter for maintaining application state during authentication. |
| SAMLExpiryNotificationEmail |  | String | Email address to receive notifications when the SAML token signing certificate is about to expire. |
| SAMLCertificateLifeYears |  | Int32 | Lifetime of the SAML token signing certificate in years. Default is 3 years. |
| isApplicationVisible |  | Boolean | Determines whether the application is visible in the My Apps portal. Default is true. |
| UserAssignmentRequired |  | Boolean | Determines whether users must be assigned to the application before accessing it. When enabled, an EntraID group is created for user assignment. Default is false. |
| groupAssignmentPrefix |  | String | Prefix for the automatically created EntraID group when UserAssignmentRequired is enabled. Default is "col - Entra - users - ". |
| implicitGrantAccessTokens |  | Boolean | Enable implicit grant flow for access tokens. Default is false. |
| implicitGrantIDTokens |  | Boolean | Enable implicit grant flow for ID tokens. Default is false. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-applications-delete-application-registration'></a>

### Delete Application Registration
Delete an application registration from Azure AD

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ClientId | ✓ | String | The application client ID (appId) of the application registration to delete. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-applications-export-enterprise-application-users'></a>

### Export Enterprise Application Users
Export a CSV of all (enterprise) application owners and users

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| entAppsOnly |  | Boolean | Determines whether to export only enterprise applications (final value: true) or all service principals/applications (final value: false). |
| ContainerName |  | String | Storage container name used for the upload. |
| ResourceGroupName |  | String | Resource group that contains the storage account. |
| StorageAccountName |  | String | Storage account name used for the upload. |
| StorageAccountLocation |  | String | Azure region for the storage account, used when the account needs to be created. |
| StorageAccountSku |  | String | Storage account SKU, used when the account needs to be created. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-applications-list-inactive-enterprise-applications'></a>

### List Inactive Enterprise Applications
List enterprise applications with no recent sign-ins

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Days |  | Int32 | Number of days without user logon to consider an application as inactive. Default is 90 days. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-applications-report-application-registration'></a>

### Report Application Registration
Generate and email a comprehensive Application Registration report

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| EmailTo | ✓ | String | Can be a single address or multiple comma-separated addresses (string).<br>The function sends individual emails to each recipient for privacy reasons. |
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization. |
| IncludeDeletedApps |  | Boolean | Whether to include deleted application registrations in the report (default: true) |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-applications-report-expiring-application-credentials-scheduled'></a>

### Report Expiring Application Credentials (Scheduled)
List expiry date of all Application Registration credentials

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| listOnlyExpiring |  | Boolean | If only credentials that are about to expire within the specified number of days should be listed, select "List only credentials about to expire" (final value: true).<br>If you want to list all credentials regardless of their expiry date, select "List all credentials" (final value: false). |
| Days |  | Int32 | The number of days before a credential expires to consider it "about to expire". |
| CredentialType |  | String | Filter by credential type: "Both" (default), "ClientSecrets", or "Certificates". |
| ApplicationIds |  | String | Optional - comma-separated list of Application IDs to filter the credentials. |
| EmailTo | ✓ | String | If specified, an email with the report will be sent to the provided address(es).<br>Can be a single address or multiple comma-separated addresses (string).<br>The function sends individual emails to each recipient for privacy reasons. |
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-applications-update-application-registration'></a>

### Update Application Registration
Update an application registration in Azure AD

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ClientId | ✓ | String | The application client ID (appId) of the application registration to update. |
| RedirectURI |  | String | Used for UI selection only. Determines which redirect URI type to configure. |
| webRedirectURI |  | String | Redirect URI or URIs for web applications. Multiple values can be separated by semicolons. |
| publicClientRedirectURI |  | String | Redirect URI or URIs for public client/native applications. Multiple values can be separated by semicolons. |
| spaRedirectURI |  | String | Redirect URI or URIs for single-page applications. Multiple values can be separated by semicolons. |
| EnableSAML |  | Boolean | If set to true, SAML-based authentication is configured on the service principal. |
| SAMLReplyURL |  | String | The SAML reply URL. |
| SAMLSignOnURL |  | String | The SAML sign-on URL. |
| SAMLLogoutURL |  | String | The SAML logout URL. |
| SAMLIdentifier |  | String | The SAML identifier (Entity ID). |
| SAMLRelayState |  | String | The SAML relay state parameter. |
| SAMLExpiryNotificationEmail |  | String | Email address for SAML certificate expiry notifications. |
| isApplicationVisible |  | Boolean | Determines whether the application is visible in the My Apps portal. |
| UserAssignmentRequired |  | Boolean | Determines whether user assignment is required for the application. |
| groupAssignmentPrefix |  | String | Prefix for the automatically created assignment group. |
| implicitGrantAccessTokens |  | Boolean | Enable implicit grant flow for access tokens. |
| implicitGrantIDTokens |  | Boolean | Enable implicit grant flow for ID tokens. |
| disableImplicitGrant |  | Boolean | If set to true, disables implicit grant issuance regardless of other settings. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='organization-devices'></a>
## Devices

<a name='organization-devices-add-autopilot-device'></a>

### Add Autopilot Device
Import a Windows device into Windows Autopilot

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| SerialNumber | ✓ | String | Device serial number as returned by Get-WindowsAutopilotInfo. |
| HardwareIdentifier | ✓ | String | Device hardware hash as returned by Get-WindowsAutopilotInfo. |
| AssignedUser |  | String | Optional user to assign to the Autopilot device. |
| Wait |  | Boolean | If set to true, the runbook waits until the import job completes. |
| GroupTag |  | String | Optional group tag to apply to the imported device. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-devices-add-device-via-corporate-identifier'></a>

### Add Device Via Corporate Identifier
Import a device into Intune via corporate identifier

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CorpIdentifierType | ✓ | String | Identifier type to use for import. |
| CorpIdentifier | ✓ | String | Identifier value to import. |
| DeviceDescripton |  | String | Optional description stored for the imported identity. |
| OverwriteExistingEntry |  | Boolean | If set to true, an existing entry for the same identifier will be overwritten. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-devices-delete-stale-devices-scheduled'></a>

### Delete Stale Devices (Scheduled)
Scheduled deletion of stale devices based on last activity

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Days |  | Int32 | Number of days without activity to be considered stale |
| Windows |  | Boolean | Include Windows devices in the results |
| MacOS |  | Boolean | Include macOS devices in the results |
| iOS |  | Boolean | Include iOS devices in the results |
| Android |  | Boolean | Include Android devices in the results |
| DeleteDevices |  | Boolean | If set to true, the script will delete the stale devices. If false, it will only report them. |
| ConfirmDeletion |  | Boolean | If set to true, the script will prompt for confirmation before deleting devices.<br>Should be set to false for scheduled runs. |
| sendAlertTo |  | String | Email address to send the report to. |
| sendAlertFrom |  | String | Email address to send the report from. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-devices-get-bitlocker-recovery-key'></a>

### Get Bitlocker Recovery Key
Get the BitLocker recovery key

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| bitlockeryRecoveryKeyId | ✓ | String | Recovery key ID of the desired key. |

<a name='organization-devices-notify-users-about-stale-devices-scheduled'></a>

### Notify Users About Stale Devices (Scheduled)
Notify primary users about their stale devices via email

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Days |  | Int32 | Number of days without activity to be considered stale (minimum threshold). |
| MaxDays |  | Int32 | Optional maximum number of days without activity. If set, only devices inactive between Days and MaxDays will be included. |
| Windows |  | Boolean | Include Windows devices in the results. |
| MacOS |  | Boolean | Include macOS devices in the results. |
| iOS |  | Boolean | Include iOS devices in the results. |
| Android |  | Boolean | Include Android devices in the results. |
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization. |
| ServiceDeskDisplayName |  | String | Service Desk display name for user contact information (optional). |
| ServiceDeskEmail |  | String | Service Desk email address for user contact information (optional). |
| ServiceDeskPhone |  | String | Service Desk phone number for user contact information (optional). |
| UseUserScope |  | Boolean | Enable user scope filtering to include or exclude users based on group membership. |
| IncludeUserGroup |  | String | Only send emails to users who are members of this group. Requires UseUserScope to be enabled. |
| ExcludeUserGroup |  | String | Do not send emails to users who are members of this group. Requires UseUserScope to be enabled. |
| OverrideEmailRecipient |  | String | Optional: Email address(es) to send all notifications to instead of end users. Can be comma-separated for multiple recipients. Perfect for testing, piloting, or sending to ticket systems. If left empty, emails will be sent to the actual end users. |
| MailTemplateLanguage |  | String | Select which email template to use: EN (English, default), DE (German), or Custom (from Runbook Customizations). |
| CustomMailTemplateSubject |  | String | Custom email subject line (only used when MailTemplateLanguage is set to 'Custom'). |
| CustomMailTemplateBeforeDeviceDetails |  | String | Custom text to display before the device list (only used when MailTemplateLanguage is set to 'Custom'). Supports Markdown formatting. |
| CustomMailTemplateAfterDeviceDetails |  | String | Custom text to display after the device list (only used when MailTemplateLanguage is set to 'Custom'). Supports Markdown formatting. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-devices-outphase-devices'></a>

### Outphase Devices
Remove or outphase multiple devices

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceListChoice | ✓ | Int32 | Determines whether the list contains device IDs or serial numbers. |
| DeviceList | ✓ | String | Comma-separated list of device IDs or serial numbers. |
| intuneAction |  | Int32 | Determines whether to wipe the device, delete it from Intune, or skip Intune actions. |
| aadAction |  | Int32 | Determines whether to delete the Entra ID device, disable it, or skip Entra ID actions. |
| wipeDevice |  | Boolean | Internal flag derived from intuneAction. |
| removeIntuneDevice |  | Boolean | Internal flag derived from intuneAction. |
| removeAutopilotDevice |  | Boolean | "Remove the device from Autopilot" (final value: true) or "Keep device in Autopilot" (final value: false) handles whether to delete the device from the Autopilot database. |
| removeAADDevice |  | Boolean | Internal flag derived from aadAction. |
| disableAADDevice |  | Boolean | Internal flag derived from aadAction. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-devices-report-devices-without-primary-user'></a>

### Report Devices Without Primary User
Reports all managed devices in Intune that do not have a primary user assigned.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization. |
| EmailTo |  | String | If specified, an email with the report will be sent to the provided address(es).<br>Can be a single address or multiple comma-separated addresses (string).<br>The function sends individual emails to each recipient for privacy reasons. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-devices-report-stale-devices-scheduled'></a>

### Report Stale Devices (Scheduled)
Scheduled report of stale devices based on last activity date and platform.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Days |  | Int32 | Number of days without activity to be considered stale. |
| MaxDays |  | Int32 | Optional maximum number of days without activity. If set, only devices inactive between Days and MaxDays will be included. |
| Windows |  | Boolean | Include Windows devices in the results. |
| MacOS |  | Boolean | Include macOS devices in the results. |
| iOS |  | Boolean | Include iOS devices in the results. |
| Android |  | Boolean | Include Android devices in the results. |
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization |
| UseUserScope |  | Boolean | Enable user scope filtering to include or exclude devices based on primary user group membership. |
| IncludeUserGroup |  | String | Only include devices whose primary users are members of this group. Requires UseUserScope to be enabled. |
| ExcludeUserGroup |  | String | Exclude devices whose primary users are members of this group. Requires UseUserScope to be enabled. |
| EmailTo | ✓ | String | Can be a single address or multiple comma-separated addresses (string).<br>The function sends individual emails to each recipient for privacy reasons. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-devices-report-users-with-more-than-5-devices'></a>

### Report Users With More Than 5-Devices
Report users with more than five registered devices

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization. |
| EmailTo |  | String | If specified, an email with the report will be sent to the provided address(es).<br>Can be a single address or multiple comma-separated addresses (string).<br>The function sends individual emails to each recipient for privacy reasons. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-devices-sync-device-serialnumbers-to-entraid-scheduled'></a>

### Sync Device Serialnumbers To Entraid (Scheduled)
Sync Intune serial numbers to Entra ID extension attributes

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ExtensionAttributeNumber |  | Int32 | Extension attribute number to update |
| ProcessAllDevices |  | Boolean | If set to true, processes all devices; otherwise only devices with missing or mismatched values are processed. |
| MaxDevicesToProcess |  | Int32 | Maximum number of devices to process in a single run. Use 0 for unlimited. |
| sendReportTo |  | String | Email address to send the report to. If empty, no email will be sent. |
| sendReportFrom |  | String | Email address to send the report from. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='organization-general'></a>
## General

<a name='organization-general-add-devices-of-users-to-group-scheduled'></a>

### Add Devices Of Users To Group (Scheduled)
Sync devices of users in a specific group to another device group

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserGroup | ✓ | String | Name or object ID of the users group, to which the target users belong. |
| DeviceGroup | ✓ | String | Name or object ID of the device group, to which the devices should be added. |
| CallerName | ✓ | String | Caller name for auditing purposes. |
| IncludeWindowsDevice |  | Boolean | If set to true, includes Windows devices in the target device group. |
| IncludeMacOSDevice |  | Boolean | If set to true, includes macOS devices in the target device group. |
| IncludeLinuxDevice |  | Boolean | If set to true, includes Linux devices in the target device group. |
| IncludeAndroidDevice |  | Boolean | If set to true, includes Android devices in the target device group. |
| IncludeIOSDevice |  | Boolean | If set to true, includes iOS devices in the target device group. |
| IncludeIPadOSDevice |  | Boolean | If set to true, includes iPadOS devices. |

<a name='organization-general-add-management-partner'></a>

### Add Management Partner
List or add Management Partner Links (PAL)

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Action | ✓ | Int32 | Choice of action to perform: list existing PALs or add a new PAL. |
| PartnerId |  | Int32 | Partner ID to set when adding a PAL. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-add-microsoft-store-app-logos'></a>

### Add Microsoft Store App Logos
Update logos of Microsoft Store Apps (new) in Intune

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-add-office365-group'></a>

### Add Office365 Group
Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| MailNickname | ✓ | String | Mail nickname used for group creation. |
| DisplayName |  | String | Optional display name. If empty, MailNickname is used. |
| CreateTeam |  | Boolean | Choose to "Only create a SharePoint Site" (final value: $false) or "Create a Team (and SharePoint Site)" (final value: $true). A team needs an owner, so if CreateTeam is set to true and no owner is specified, the runbook will set the caller as the owner. |
| Private |  | Boolean | Choose the group visibility: "Public" (final value: $false) or "Private" (final value: $true). |
| MailEnabled |  | Boolean | If set to true, the group is mail-enabled. |
| SecurityEnabled |  | Boolean | If set to true, the group is security-enabled. |
| Owner |  | String | Optional owner of the group. |
| Owner2 |  | String | Optional second owner of the group. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-add-or-remove-safelinks-exclusion'></a>

### Add Or Remove Safelinks Exclusion
Add or remove a SafeLinks URL exclusion from a policy

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Action |  | Int32 | "Add URL Pattern to Policy", "Remove URL Pattern from Policy" or "List all existing policies and settings" could be selected as action to perform. |
| LinkPattern |  | String | URL pattern to allow; it can contain '*' as a wildcard for host and paths. |
| DefaultPolicyName | ✓ | String | Default SafeLinks policy name used when no explicit policy name is provided. |
| PolicyName |  | String | Optional SafeLinks policy name; if provided, it overrides the default selection. |
| CreateNewPolicyIfNeeded |  | Boolean | If set to true, the runbook creates a new SafeLinks policy and assignment group when the requested policy does not exist. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-general-add-or-remove-smartscreen-exclusion'></a>

### Add Or Remove Smartscreen Exclusion
Add or remove a SmartScreen URL indicator in Microsoft Defender

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| action |  | Int32 | "List all URL indicators", "Add an URL indicator" or "Remove all indicator for this URL" could be selected as action to perform. |
| Url |  | String | Domain name to manage, for example "exclusiondemo.com". |
| mode |  | Int32 | Indicator mode to apply. |
| explanationTitle |  | String | Title used when creating an indicator. |
| explanationDescription |  | String | Description used when creating an indicator. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-add-or-remove-trusted-site'></a>

### Add Or Remove Trusted Site
Add or remove a URL entry in the Intune Trusted Sites policy

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Action | ✓ | Int32 | Action to execute: add, remove, or list policies. |
| Url |  | String | URL to add or remove; it must be prefixed with "http://" or "https://". |
| Zone |  | Int32 | Internet Explorer zone id to assign the URL to. |
| DefaultPolicyName |  | String | Default policy name used when multiple Trusted Sites policies exist and no specific policy name is provided. |
| IntunePolicyName |  | String | Optional policy name; if provided, the runbook targets this policy instead of auto-selecting one. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-general-add-security-group'></a>

### Add Security Group
Create a Microsoft Entra ID security group

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupName | ✓ | String | Display name of the security group to create. |
| GroupDescription |  | String | Optional description for the security group. |
| Owner |  | String | Optional owner to assign to the group. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-add-user'></a>

### Add User
Create a new user account

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GivenName | ✓ | String | First name of the user. |
| Surname | ✓ | String | Last name of the user. |
| UserPrincipalName |  | String | User principal name (UPN). If empty, the runbook generates a UPN from the provided name. |
| MailNickname |  | String | Mail nickname (alias) used for the user. If empty, the runbook derives it from the UPN. |
| DisplayName |  | String | Display name of the user. If empty, the runbook derives it from the provided name. |
| CompanyName |  | String | Company name of the user. |
| JobTitle |  | String | Job title of the user. |
| Department |  | String | Department of the user. |
| ManagerId |  | String | Optional manager user ID to set for the user. |
| MobilePhone |  | String | Mobile phone number of the user. |
| LocationName |  | String | Office location name used for portal customization. |
| StreetAddress |  | String | Street address of the user. |
| PostalCode |  | String | Postal code of the user. |
| City |  | String | City of the user. |
| State |  | String | State or region of the user. |
| Country |  | String | Country of the user. |
| UsageLocation |  | String | Usage location used for licensing. |
| DefaultLicense |  | String | Optional license group to assign to the user. |
| DefaultGroups |  | String | Comma-separated list of groups to assign to the user. |
| InitialPassword |  | String | Initial password. If empty, the runbook generates a random password. |
| EnableEXOArchive |  | Boolean | If set to true, creates an Exchange Online archive mailbox for the user. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-add-viva-engange-community'></a>

### Add Viva Engange Community
Create a Viva Engage (Yammer) community

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CommunityName | ✓ | String | Name of the community to create. Maximum length is 264 characters. |
| CommunityPrivate |  | Boolean | If set to true, the community is created as private. |
| CommunityShowInDirectory |  | Boolean | If set to true, the community is visible in the directory. |
| CommunityOwners |  | String | Comma-separated list of owner UPNs to add to the community. |
| removeCreatorFromGroup |  | Boolean | If set to true, removes the initial API user from the group when at least one other owner exists. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-assign-groups-by-template-scheduled'></a>

### Assign Groups By Template (Scheduled)
Assign cloud-only groups to many users based on a predefined template

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| SourceGroupId | ✓ | String | Object ID of the source group containing users to process. |
| ExclusionGroupId |  | String | Optional object ID of a group whose users are excluded from processing. |
| GroupsTemplate |  | String | Template selector used by the portal to populate the GroupsString parameter. |
| GroupsString | ✓ | String | Comma-separated list of target groups (IDs or display names depending on UseDisplaynames). |
| UseDisplaynames |  | Boolean | If set to true, GroupsString contains display names; otherwise it contains object IDs. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-bulk-delete-devices-from-autopilot'></a>

### Bulk Delete Devices From Autopilot
Bulk delete Autopilot objects by serial number

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| SerialNumbers | ✓ | String | Comma-separated list of serial numbers to delete from Autopilot. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-bulk-retire-devices-from-intune'></a>

### Bulk Retire Devices From Intune
Bulk retire devices from Intune using serial numbers

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| SerialNumbers | ✓ | String | Comma-separated list of device serial numbers to retire. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-general-check-aad-sync-status-scheduled'></a>

### Check AAD Sync Status (Scheduled)
Check last Azure AD Connect sync status

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| sendAlertTo |  | String | Email address to send the report to. |
| sendAlertFrom |  | String | Sender mailbox used for sending the report. |

<a name='organization-general-check-assignments-of-devices'></a>

### Check Assignments Of Devices
Check Intune assignments for one or more device names

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| DeviceNames | ✓ | String | Comma-separated list of device names to check. |
| IncludeApps |  | Boolean | If set to true, also evaluates application assignments. |

<a name='organization-general-check-assignments-of-groups'></a>

### Check Assignments Of Groups
Check Intune assignments for one or more group names

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| GroupNames | ✓ | String | Group Names of the groups to check assignments for, separated by commas. |
| IncludeApps |  | Boolean | If set to true, also evaluates application assignments. |

<a name='organization-general-check-assignments-of-users'></a>

### Check Assignments Of Users
Check Intune assignments for one or more user principal names

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| UPN | ✓ | String | User Principal Names of the users to check assignments for, separated by commas. |
| IncludeApps |  | Boolean | If set to true, also evaluates application assignments. |

<a name='organization-general-check-autopilot-serialnumbers'></a>

### Check Autopilot Serialnumbers
Check if given serial numbers are present in Autopilot

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| SerialNumbers | ✓ | String | Serial numbers of the devices, separated by commas. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-check-device-onboarding-exclusion-scheduled'></a>

### Check Device Onboarding Exclusion (Scheduled)
Add unenrolled Autopilot devices to an exclusion group

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| exclusionGroupName |  | String | Display name of the exclusion group to manage. |
| maxAgeInDays |  | Int32 | Maximum age in days for recently enrolled devices to be considered in grace scope. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-enrolled-devices-report-scheduled'></a>

### Enrolled Devices Report (Scheduled)
Show recent first-time device enrollments

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Weeks |  | Int32 | Time range in weeks to include in the report. |
| dataSource |  | Int32 | Data source used to determine the first enrollment date. |
| groupingSource |  | Int32 | Data source used to resolve the grouping attribute. |
| groupingAttribute |  | String | Attribute name used for grouping. |
| exportCsv |  | Boolean | Please configure an Azure Storage Account to use this feature. |
| ContainerName |  | String | Storage container name used for upload. |
| ResourceGroupName |  | String | Resource group that contains the storage account. |
| StorageAccountName |  | String | Storage account name used for upload. |
| StorageAccountLocation |  | String | Azure region for the storage account. |
| StorageAccountSku |  | String | Storage account SKU. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-export-all-autopilot-devices'></a>

### Export All Autopilot Devices
List or export all Windows Autopilot devices

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ExportToFile |  | Boolean | "List in Console" (final value: $false) or "Export to a CSV file" (final value: $true) can be selected as action to perform. |
| ContainerName |  | String | Name of the Azure Storage container to upload the CSV report to. |
| ResourceGroupName |  | String | Name of the Azure Resource Group containing the Storage Account. |
| StorageAccountName |  | String | Name of the Azure Storage Account used for upload. |
| StorageAccountLocation |  | String | Azure region for the Storage Account if it needs to be created. |
| StorageAccountSku |  | String | SKU name for the Storage Account if it needs to be created. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-general-export-all-intune-devices'></a>

### Export All Intune Devices
Export a list of all Intune devices and where they are registered

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ContainerName |  | String | Name of the Azure Storage container to upload the CSV report to. |
| ResourceGroupName |  | String | Name of the Azure Resource Group containing the Storage Account. |
| StorageAccountName |  | String | Name of the Azure Storage Account used for upload. |
| StorageAccountLocation |  | String | Azure region for the Storage Account if it needs to be created. |
| StorageAccountSku |  | String | SKU name for the Storage Account if it needs to be created. |
| SubscriptionId |  | String | Optional Azure Subscription Id to set the context for Storage Account operations. |
| FilterGroupID |  | String | Optional group filter (ObjectId). When specified, only devices whose primary owner is a member of this group are exported. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-general-export-cloudpc-usage-scheduled'></a>

### Export Cloudpc Usage (Scheduled)
Write daily Windows 365 utilization data to Azure Table Storage

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Table |  | String | Name of the Azure Table Storage table to write to. |
| ResourceGroupName | ✓ | String | Name of the Azure Resource Group containing the Storage Account. |
| StorageAccountName | ✓ | String | Name of the Azure Storage Account hosting the table. |
| Days |  | Int32 | Number of days to look back when collecting usage data. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-general-export-non-compliant-devices'></a>

### Export Non Compliant Devices
Export non-compliant Intune devices and settings

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| produceLinks |  | Boolean | If set to true, uploads artifacts and produces SAS (download) links when storage settings are available. |
| ContainerName |  | String | Storage container name used for uploads. |
| ResourceGroupName |  | String | Resource group that contains the storage account. |
| StorageAccountName |  | String | Storage account name used for uploads. |
| StorageAccountLocation |  | String | Azure region for the storage account. |
| StorageAccountSku |  | String | Storage account SKU. |
| SubscriptionId |  | String | Azure subscription ID used for storage operations. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-export-policy-report'></a>

### Export Policy Report
Create a report of tenant policies from Intune and Entra ID.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| produceLinks |  | Boolean | If set to true, creates links for exported artifacts based on settings. |
| exportJson |  | Boolean | If set to true, also exports raw JSON policy payloads. |
| renderLatexPagebreaks |  | Boolean | If set to true, adds LaTeX page breaks to the generated Markdown. |
| ContainerName |  | String | Storage container name used for uploads. |
| ResourceGroupName |  | String | Resource group that contains the storage account. |
| StorageAccountName |  | String | Storage account name used for uploads. |
| StorageAccountLocation |  | String | Azure region for the storage account. |
| StorageAccountSku |  | String | Storage account SKU. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-invite-external-guest-users'></a>

### Invite External Guest Users
Invite external guest users to the organization

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| InvitedUserEmail | ✓ | String | Email address of the guest user to invite. |
| InvitedUserDisplayName | ✓ | String | Display name of the guest user. |
| GroupId |  | String | The object ID of the group to add the guest user to.<br>If not specified, the user will not be added to any group. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-list-all-administrative-template-policies'></a>

### List All Administrative Template Policies
List all Administrative Template policies and their assignments

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-list-group-license-assignment-errors'></a>

### List Group License Assignment Errors
Report groups that have license assignment errors

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-office365-license-report'></a>

### Office365 License Report
Generate an Office 365 licensing report

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| printOverview |  | Boolean | If set to true, prints a short license usage overview. |
| includeExhange |  | Boolean | If set to true, includes Exchange Online related reports. |
| exportToFile |  | Boolean | If set to true, exports reports to Azure Storage when configured. |
| exportAsZip |  | Boolean | If set to true, exports reports as a single ZIP file. |
| produceLinks |  | Boolean | If set to true, creates SAS tokens/links for exported artifacts. |
| ContainerName |  | String | Storage container name used for uploads. |
| ResourceGroupName |  | String | Resource group that contains the storage account. |
| StorageAccountName |  | String | Storage account name used for uploads. |
| StorageAccountLocation |  | String | Azure region for the storage account. |
| StorageAccountSku |  | String | Storage account SKU. |
| SubscriptionId |  | String | Azure subscription ID used for storage operations. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-report-apple-mdm-cert-expiry-scheduled'></a>

### Report Apple MDM Cert Expiry (Scheduled)
Monitor/Report expiry of Apple device management certificates

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| Days |  | Int32 | The warning threshold in days. Certificates and tokens expiring within this many days will be<br>flagged as alerts in the report. Default is 300 days (approximately 10 months). |
| EmailTo |  | String | Can be a single address or multiple comma-separated addresses (string).<br>The function sends individual emails to each recipient for privacy reasons. |
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization |

<a name='organization-general-report-license-assignment-scheduled'></a>

### Report License Assignment (Scheduled)
Generate and email a license availability report based on thresholds

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| InputJson | ✓ | Object | JSON array containing SKU configurations with thresholds. Each entry should include a SKUPartNumber for the Microsoft SKU identifier, a FriendlyName as the display name for the license, an optional MinThreshold specifying the minimum number of licenses that should be available, and an optional MaxThreshold specifying the maximum number of licenses that should be available.<br><br>This needs to be configured in the runbook customization |
| EmailTo | ✓ | String | Recipient email address or comma-separated recipient list. |
| EmailFrom |  | String | Sender email address resolved from settings. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-general-report-pim-activations-scheduled'></a>

### Report PIM Activations (Scheduled)
Scheduled report on PIM activations

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| sendAlertTo |  | String | Recipient email address for the report. |
| sendAlertFrom |  | String | Sender mailbox UPN used to send the report email. |

<a name='organization-general-sync-all-devices'></a>

### Sync All Devices
Sync all Intune Windows devices

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='organization-mail'></a>
## Mail

<a name='organization-mail-add-distribution-list'></a>

### Add Distribution List
Create a classic distribution group

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Alias | ✓ | String | Mail alias (mail nickname) for the distribution group. |
| PrimarySMTPAddress |  | String | Optional primary SMTP address for the distribution group. |
| GroupName |  | String | Optional display name for the distribution group; defaults to the alias. |
| Owner |  | String | Optional owner who can manage the group. |
| Roomlist |  | Boolean | If set to true, the distribution group is created as a room list. |
| AllowExternalSenders |  | Boolean | If set to true, the group can receive email from external senders. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-mail-add-equipment-mailbox'></a>

### Add Equipment Mailbox
Create an equipment mailbox

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| MailboxName | ✓ | String | Alias (mail nickname) for the equipment mailbox. |
| DisplayName |  | String | Optional display name for the equipment mailbox. |
| DelegateTo |  | String | Optional user who receives delegated access to the mailbox. |
| AutoAccept |  | Boolean | If set to true, meeting requests are automatically accepted. |
| AutoMapping |  | Boolean | If set to true, the mailbox is automatically mapped in Outlook for the delegate. |
| DisableUser |  | Boolean | If set to true, the associated Entra ID user account is disabled. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-mail-add-or-remove-public-folder'></a>

### Add Or Remove Public Folder
Add or remove a public folder

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| PublicFolderName | ✓ | String | Name of the public folder to create or remove. |
| MailboxName |  | String | Optional target public folder mailbox to create the folder in. |
| AddPublicFolder | ✓ | Boolean | If set to true, the public folder is created; if set to false, it is removed. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-mail-add-or-remove-teams-mailcontact'></a>

### Add Or Remove Teams Mailcontact
Create/Remove a contact, to allow pretty email addresses for Teams channels.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| RealAddress | ✓ | String | Enter the address created by MS Teams for a channel |
| DesiredAddress | ✓ | String | Desired email address that should relay to the real address. |
| DisplayName |  | String | Optional display name for the contact in the address book. |
| Remove |  | Boolean | "Relay the desired address to the real address" (final value: $false) or "Stop the relay and remove desired address" (final value: $true) can be selected as action to perform. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-mail-add-or-remove-tenant-allow-block-list'></a>

### Add Or Remove Tenant Allow Block List
Add or remove entries from the Tenant Allow/Block List

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Entry | ✓ | String | The entry to add or remove (for example: domain, email address, URL, or file hash). |
| ListType |  | String | Type of entry to manage. |
| Block |  | Boolean | "Block List (block entry)" (final value: $true) or "Allow List (permit entry)" (final value: $false) can be selected as list type. |
| Remove |  | Boolean | "Add entry to the list" (final value: $false) or "Remove entry from the list" (final value: $true) can be selected as action to perform. |
| DaysToExpire |  | Int32 | Number of days until a newly added entry expires. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-mail-add-room-mailbox'></a>

### Add Room Mailbox
Create a room mailbox resource

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| MailboxName | ✓ | String | Alias (mail nickname) for the room mailbox. |
| DisplayName |  | String | Optional display name for the room mailbox. |
| DelegateTo |  | String | Optional user who receives delegated access to the mailbox. |
| Capacity |  | Int32 | Optional room capacity in number of people. |
| AutoAccept |  | Boolean | If set to true, meeting requests are automatically accepted. |
| AutoMapping |  | Boolean | If set to true, the mailbox is automatically mapped in Outlook for the delegate. |
| DisableUser |  | Boolean | If set to true, the associated Entra ID user account is disabled. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-mail-add-shared-mailbox'></a>

### Add Shared Mailbox
Create a shared mailbox

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| MailboxName | ✓ | String | The alias (mailbox name) for the shared mailbox. |
| DisplayName |  | String | Display name for the shared mailbox. |
| DomainName |  | String | Optional domain used for the primary SMTP address; if not provided, the default domain is used. |
| Language |  | String | The language/locale for the shared mailbox. This setting affects folder names like "Inbox". Default is "en-US". |
| DelegateTo |  | String | Optional user who receives delegated access to the mailbox. |
| AutoMapping |  | Boolean | If set to true, the mailbox is automatically mapped in Outlook for the delegate. |
| MessageCopyForSentAsEnabled |  | Boolean | If set to true, copies of messages sent as the mailbox are stored in the mailbox sent items. |
| MessageCopyForSendOnBehalfEnabled |  | Boolean | If set to true, copies of messages sent on behalf of the mailbox are stored in the mailbox sent items. |
| DisableUser |  | Boolean | If set to true, the associated Entra ID user account is disabled. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-mail-hide-mailboxes-scheduled'></a>

### Hide Mailboxes (Scheduled)
Hide or unhide special mailboxes in the Global Address List

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| HideBookingCalendars | ✓ | Boolean | If set to true, booking calendars are hidden from address lists. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-mail-set-booking-config'></a>

### Set Booking Config
Configure Microsoft Bookings settings for the organization

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| BookingsEnabled |  | Boolean | If set to true, Microsoft Bookings is enabled for the organization. |
| BookingsAuthEnabled |  | Boolean | If set to true, Bookings uses authentication. |
| BookingsSocialSharingRestricted |  | Boolean | If set to true, social sharing is restricted. |
| BookingsExposureOfStaffDetailsRestricted |  | Boolean | If set to true, exposure of staff details is restricted. |
| BookingsMembershipApprovalRequired |  | Boolean | If set to true, membership approval is required. |
| BookingsSmsMicrosoftEnabled |  | Boolean | If set to true, Microsoft SMS notifications are enabled. |
| BookingsSearchEngineIndexDisabled |  | Boolean | If set to true, search engine indexing is disabled. |
| BookingsAddressEntryRestricted |  | Boolean | If set to true, address entry is restricted. |
| BookingsCreationOfCustomQuestionsRestricted |  | Boolean | If set to true, creation of custom questions is restricted. |
| BookingsNotesEntryRestricted |  | Boolean | If set to true, notes entry is restricted. |
| BookingsPhoneNumberEntryRestricted |  | Boolean | If set to true, phone number entry is restricted. |
| BookingsNamingPolicyEnabled |  | Boolean | If set to true, naming policies are enabled. |
| BookingsBlockedWordsEnabled |  | Boolean | If set to true, blocked words are enabled for naming policies. |
| BookingsNamingPolicyPrefixEnabled |  | Boolean | If set to true, the naming policy prefix is enabled. |
| BookingsNamingPolicyPrefix |  | String | Prefix applied by the naming policy. |
| BookingsNamingPolicySuffixEnabled |  | Boolean | If set to true, the naming policy suffix is enabled. |
| BookingsNamingPolicySuffix |  | String | Suffix applied by the naming policy. |
| CreateOwaPolicy |  | Boolean | If set to true, an OWA mailbox policy for Bookings creators is created if missing. |
| OwaPolicyName |  | String | Name of the OWA mailbox policy to create or use for Bookings creators. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='organization-phone'></a>
## Phone

<a name='organization-phone-get-teams-phone-number-assignment'></a>

### Get Teams Phone Number Assignment
Check whether a phone number is assigned in Microsoft Teams

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| PhoneNumber | ✓ | String | The phone number must be in E.164 format. Example: +49321987654 or +49321987654;ext=123. It must start with a '+' followed by the country code and subscriber number, with an optional ';ext=' followed by the extension number, without spaces or special characters. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='organization-security'></a>
## Security

<a name='organization-security-add-defender-indicator'></a>

### Add Defender Indicator
Create a new Microsoft Defender for Endpoint indicator

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| IndicatorValue | ✓ | String | Value of the indicator, such as a hash, thumbprint, IP address, domain name, or URL. |
| IndicatorType | ✓ | String | Type of the indicator value. |
| Title | ✓ | String | Title of the indicator entry. |
| Description | ✓ | String | Description of the indicator entry. |
| Action | ✓ | String | Action applied to the indicator. |
| Severity | ✓ | String | Severity used for the indicator. |
| GenerateAlert | ✓ | String | If set to true, an alert is generated when the indicator matches. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-security-backup-conditional-access-policies'></a>

### Backup Conditional Access Policies
Export Conditional Access policies to an Azure Storage account

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ContainerName |  | String | Name of the Azure Storage container; if omitted, a default name is generated. |
| ResourceGroupName |  | String | Name of the Azure Resource Group containing the Storage Account. |
| StorageAccountName |  | String | Name of the Azure Storage Account used for upload. |
| StorageAccountLocation |  | String | Azure region for the Storage Account if it needs to be created. |
| StorageAccountSku |  | String | SKU name for the Storage Account if it needs to be created. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-security-list-admin-users'></a>

### List Admin Users
List Entra ID role holders and optionally evaluate their MFA methods

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ExportToFile |  | Boolean | If set to true, exports the report to an Azure Storage Account. |
| PimEligibleUntilInCSV |  | Boolean | If set to true, includes PIM eligible until information in the CSV report. |
| ContainerName |  | String | Name of the Azure Storage container to upload the CSV report to. |
| ResourceGroupName |  | String | Name of the Azure Resource Group containing the Storage Account. |
| StorageAccountName |  | String | Name of the Azure Storage Account used for upload. |
| StorageAccountLocation |  | String | Azure region for the Storage Account if it needs to be created. |
| StorageAccountSku |  | String | SKU name for the Storage Account if it needs to be created. |
| QueryMfaState |  | Boolean | "Check and report every admin's MFA state" (final value: $true) or "Do not check admin MFA states" (final value: $false) can be selected as action to perform. |
| TrustEmailMfa |  | Boolean | If set to true, regards email as a valid MFA method. |
| TrustPhoneMfa |  | Boolean | If set to true, regards phone/SMS as a valid MFA method. |
| TrustSoftwareOathMfa |  | Boolean | If set to true, regards software OATH token as a valid MFA method. |
| TrustWinHelloMFA |  | Boolean | If set to true, regards Windows Hello for Business as a valid MFA method. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-security-list-expiring-role-assignments'></a>

### List Expiring Role Assignments
List Azure AD role assignments expiring within a given number of days

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Days |  | Int32 | Maximum number of days until expiry. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-security-list-inactive-devices'></a>

### List Inactive Devices
List or export inactive devices with no recent logon or Intune sync

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Days |  | Int32 | Number of days without sync or sign-in used to consider a device inactive. |
| Sync |  | Boolean | If set to true, inactivity is based on last Intune sync; otherwise it is based on last interactive sign-in. |
| ExportToFile |  | Boolean | If set to true, exports the results to a CSV file in Azure Storage. |
| ContainerName |  | String | Name of the Azure Storage container to upload the CSV report to. |
| ResourceGroupName |  | String | Name of the Azure Resource Group containing the Storage Account. |
| StorageAccountName |  | String | Name of the Azure Storage Account used for upload. |
| StorageAccountLocation |  | String | Azure region for the Storage Account if it needs to be created. |
| StorageAccountSku |  | String | SKU name for the Storage Account if it needs to be created. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-security-list-inactive-users'></a>

### List Inactive Users
List users with no recent interactive sign-ins

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Days |  | Int32 | Number of days without interactive sign-in. |
| ShowBlockedUsers |  | Boolean | If set to true, includes users and guests that cannot sign in. |
| ShowUsersThatNeverLoggedIn |  | Boolean | If set to true, includes users and guests that never signed in. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-security-list-information-protection-labels'></a>

### List Information Protection Labels
List Microsoft Information Protection labels

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-security-list-pim-rolegroups-without-owners-scheduled'></a>

### List PIM Rolegroups Without Owners (Scheduled)
List role-assignable groups with eligible role assignments but without owners

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| SendEmailIfFound |  | Boolean | If set to true, sends an email when matching groups are found. |
| From |  | String | Sender email address used to send the alert. |
| To |  | String | Recipient email address for the alert. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-security-list-users-by-mfa-methods-count'></a>

### List Users By MFA Methods Count
Report users by the count of their registered MFA methods

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| mfaMethodsRange | ✓ | String | Range for filtering users based on the count of their registered MFA methods. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

<a name='organization-security-list-vulnerable-app-regs'></a>

### List Vulnerable App Regs
List app registrations potentially vulnerable to CVE-2021-42306

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ExportToFile |  | Boolean | "List in Console" (final value: $false) or "Export to a CSV file" (final value: $true) can be selected as action to perform. The export saves the findings to a CSV file in Azure Storage. |
| ContainerName |  | String | Name of the Azure Storage container to upload the CSV report to. |
| ResourceGroupName |  | String | Name of the Azure Resource Group containing the Storage Account. |
| StorageAccountName |  | String | Name of the Azure Storage Account used for upload. |
| StorageAccountLocation |  | String | Azure region for the Storage Account if it needs to be created. |
| StorageAccountSku |  | String | SKU name for the Storage Account if it needs to be created. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-security-monitor-pending-epm-requests-scheduled'></a>

### Monitor Pending EPM Requests (Scheduled)
Monitor and report pending Endpoint Privilege Management (EPM) elevation requests

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Internal parameter for tracking purposes |
| DetailedReport |  | Boolean | When enabled, includes detailed request information in a table and as CSV attachment.<br>When disabled, only provides a summary count of pending requests. |
| EmailTo |  | String | Can be a single address or multiple comma-separated addresses (string).<br>The function sends individual emails to each recipient for privacy reasons. |
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization. |

<a name='organization-security-notify-changed-ca-policies'></a>

### Notify Changed CA Policies
Send notification email if Conditional Access policies have been created or modified in the last 24 hours.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| From | ✓ | String | Sender email address used to send the notification. |
| To | ✓ | String | Recipient email address for the notification. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='organization-security-report-epm-elevation-requests-scheduled'></a>

### Report EPM Elevation Requests (Scheduled)
Generate report for Endpoint Privilege Management (EPM) elevation requests

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Internal parameter for tracking purposes |
| IncludeApproved |  | Boolean | Include requests with status "Approved" - Request has been approved by an administrator. |
| IncludeDenied |  | Boolean | Include requests with status "Denied" - Request was rejected by an administrator. |
| IncludeExpired |  | Boolean | Include requests with status "Expired" - Request expired before approval/denial. |
| IncludeRevoked |  | Boolean | Include requests with status "Revoked" - Previously approved request was revoked. |
| IncludePending |  | Boolean | Include requests with status "Pending" - Awaiting approval decision. |
| IncludeCompleted |  | Boolean | Include requests with status "Completed" - Request was approved and executed successfully. |
| MaxAgeInDays |  | Int32 | Filter requests created within the last X days (default: 30).<br>Note: Request details are retained in Intune for 30 days after creation. |
| EmailTo |  | String | Can be a single address or multiple comma-separated addresses (string).<br>The function sends individual emails to each recipient for privacy reasons. |
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='user'></a>
# User
<a name='user-avd'></a>
## AVD

<a name='user-avd-user-signout'></a>

### User Signout
Removes (Signs Out) a specific User from their AVD Session.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | The username (UPN) of the user to sign out from their AVD session. Hidden in UI. |
| SubscriptionIds | ✓ | String Array | Array of Azure subscription IDs where the AVD resources are located. Retrieved from AVD.SubscriptionIds setting (Customization). Hidden in UI. |
| CallerName | ✓ | String | Caller name for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='user-general'></a>
## General

<a name='user-general-assign-groups-by-template'></a>

### Assign Groups By Template
Assign cloud-only groups to a user based on a template

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserId | ✓ | String | ID of the target user in Microsoft Graph. |
| GroupsTemplate |  | String | Template selector used by portal customization to populate the group list. |
| GroupsString | ✓ | String | Comma-separated list of group object IDs or group display names. |
| UseDisplaynames |  | Boolean | If set to true, treats values in GroupsString as group display names instead of IDs. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-general-assign-or-unassign-license'></a>

### Assign Or Unassign License
Assign or remove a license for a user via group membership

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| GroupID_License | ✓ | String | Object ID of the license assignment group. |
| Remove |  | Boolean | "Assign the license to the user" (final value: $false) or "Remove the license from the user" (final value: $true) can be selected as action to perform. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-general-assign-windows365'></a>

### Assign Windows365
Assign and provision a Windows 365 Cloud PC for a user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| cfgProvisioningGroupName |  | String | Display name of the provisioning policy group or Frontline assignment to use. |
| cfgUserSettingsGroupName |  | String | Display name of the user settings policy group to use. |
| licWin365GroupName |  | String | Display name of the Windows 365 license group to assign when using dedicated Cloud PCs. |
| cfgProvisioningGroupPrefix |  | String | Prefix used to detect provisioning-related configuration groups. |
| cfgUserSettingsGroupPrefix |  | String | Prefix used to detect user-settings-related configuration groups. |
| sendMailWhenProvisioned |  | Boolean | If set to true, sends an email to the user after provisioning completes. |
| customizeMail |  | Boolean | If set to true, uses a custom email body. |
| customMailMessage |  | String | Custom message body used for the notification email. |
| createTicketOutOfLicenses |  | Boolean | If set to true, creates a service ticket email when no licenses or Frontline seats are available. |
| ticketQueueAddress |  | String | Email address used as ticket queue recipient. |
| fromMailAddress |  | String | Mailbox used to send the ticket and user notification emails. |
| ticketCustomerId |  | String | Customer identifier used in ticket subject lines. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-general-list-group-memberships'></a>

### List Group Memberships
List group memberships for this user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| GroupType |  | String | Filter by group type: Security (security permissions only), M365 (Microsoft 365 groups with mailbox), or All (default). |
| MembershipType |  | String | Filter by membership type: Assigned (manually added members), Dynamic (rule-based membership), or All (default). |
| RoleAssignable |  | String | Filter groups that can be assigned to Azure AD roles: Yes (role-assignable only) or NotSet (all groups, default). |
| TeamsEnabled |  | String | Filter groups with Microsoft Teams functionality: Yes (Teams-enabled only) or NotSet (all groups, default). |
| Source |  | String | Filter by group origin: Cloud (Azure AD only), OnPrem (synchronized from on-premises AD), or All (default). |
| WritebackEnabled |  | String | Filter groups by writeback enablement. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-general-list-group-ownerships'></a>

### List Group Ownerships
List group ownerships for this user.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-general-list-manager'></a>

### List Manager
List manager information for this user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-general-offboard-user-permanently'></a>

### Offboard User Permanently
Permanently offboard a user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| DeleteUser |  | Boolean | "Delete user object" (final value: $true) or "Keep the user object" (final value: $false) can be selected as action to perform. If set to true, the user object will be deleted. If set to false, the user object will be kept but access will be revoked and sign-in will be blocked. |
| DisableUser |  | Boolean | If set to true, disables the user account for sign-in. |
| RevokeAccess |  | Boolean | If set to true, revokes the user's refresh tokens and active sessions. |
| exportResourceGroupName |  | String | Azure Resource Group name for exporting data to storage. |
| exportStorAccountName |  | String | Azure Storage Account name for exporting data to storage. |
| exportStorAccountLocation |  | String | Azure region used when creating the Storage Account. |
| exportStorAccountSKU |  | String | SKU name used when creating the Storage Account. |
| exportStorContainerGroupMembershipExports |  | String | Container name used for group membership exports. |
| exportGroupMemberships |  | Boolean | If set to true, exports the user's current group memberships to Azure Storage. |
| ChangeLicensesSelector |  | Int32 | Controls how directly assigned licenses should be handled. |
| ChangeGroupsSelector |  | Int32 | "Change" and "Remove all" will both honour "groupToAdd" |
| GroupToAdd |  | String | Group that should be added or kept when group changes are enabled. |
| GroupsToRemovePrefix |  | String | Prefix used to remove groups matching a naming convention. |
| RevokeGroupOwnership |  | Boolean | "Remove/Replace this user's group ownerships" (final value: $true) or "User will remain owner / Do not change" (final value: $false) can be selected as action to perform. If set to true, the runbook will attempt to remove the user from group ownerships. If the user is the last owner of a group, it will attempt to assign a replacement owner; if that fails, it will skip ownership change for that group and log it for manual follow-up. |
| ManagerAsReplacementOwner |  | Boolean | If set to true, uses the user's manager as replacement owner where applicable. |
| ReplacementOwnerName |  | String | User who will take over group or resource ownership if required. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

<a name='user-general-offboard-user-temporarily'></a>

### Offboard User Temporarily
Temporarily offboard a user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| RevokeAccess |  | Boolean | If set to true, revokes the user's refresh tokens and active sessions. |
| DisableUser |  | Boolean | If set to true, disables the user account for sign-in. |
| exportResourceGroupName |  | String | Azure Resource Group name for exporting data to storage. |
| exportStorAccountName |  | String | Azure Storage Account name for exporting data to storage. |
| exportStorAccountLocation |  | String | Azure region used when creating the Storage Account. |
| exportStorAccountSKU |  | String | SKU name used when creating the Storage Account. |
| exportStorContainerGroupMembershipExports |  | String | Container name used for group membership exports. |
| exportGroupMemberships |  | Boolean | If set to true, exports the user's current group memberships to Azure Storage. |
| ChangeLicensesSelector |  | Int32 | Controls how directly assigned licenses should be handled. |
| ChangeGroupsSelector |  | Int32 | Controls how assigned groups should be handled. "Change" and "Remove all" will both honour "groupToAdd". |
| GroupToAdd |  | String | Group that should be added or kept when group changes are enabled. |
| GroupsToRemovePrefix |  | String | Prefix used to remove groups matching a naming convention. |
| RevokeGroupOwnership |  | Boolean | If set to true, removes or replaces the user's group ownerships. |
| ReplacementOwnerName |  | String | Who will take over group ownership if the offboarded user is the last remaining group owner? Will only be used if needed. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-general-reprovision-windows365'></a>

### Reprovision Windows365
Reprovision a Windows 365 Cloud PC

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| licWin365GroupName | ✓ | String | Display name of the Windows 365 license group used to identify the Cloud PC. |
| sendMailWhenReprovisioning |  | Boolean | "Do not send an Email." (final value: $false) or "Send an Email." (final value: $true) can be selected as action to perform. If set to true, an email notification will be sent to the user when Cloud PC reprovisioning has begun. |
| fromMailAddress |  | String | Mailbox used to send the notification email. |
| customizeMail |  | Boolean | If set to true, uses a custom email body. |
| customMailMessage |  | String | Custom message body used for the notification email. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-general-resize-windows365'></a>

### Resize Windows365
Resize an existing Windows 365 Cloud PC for a user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| currentLicWin365GroupName | ✓ | String | Current Windows 365 license group name used by the Cloud PC. |
| newLicWin365GroupName | ✓ | String | New Windows 365 license group name to assign for the resized Cloud PC. |
| sendMailWhenDoneResizing |  | Boolean | "Do not send an Email." (final value: $false) or "Send an Email." (final value: $true) can be selected as action to perform. If set to true, an email notification will be sent to the user when Cloud PC resizing has finished. |
| fromMailAddress |  | String | Mailbox used to send the notification email. |
| customizeMail |  | Boolean | If set to true, uses a custom email body. |
| customMailMessage |  | String | Custom message body used for the notification email. |
| cfgProvisioningGroupPrefix |  | String | Prefix used to detect provisioning-related configuration groups. |
| cfgUserSettingsGroupPrefix |  | String | Prefix used to detect user-settings-related configuration groups. |
| unassignRunbook |  | String | Name of the runbook used to remove the current Windows 365 assignment. |
| assignRunbook |  | String | Name of the runbook used to assign the new Windows 365 configuration. |
| skipGracePeriod |  | Boolean | If set to true, ends the old Cloud PC grace period immediately. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-general-unassign-windows365'></a>

### Unassign Windows365
Remove and deprovision a Windows 365 Cloud PC for a user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| licWin365GroupName |  | String | Display name of the Windows 365 license group or Frontline provisioning policy to remove. |
| cfgProvisioningGroupPrefix |  | String | Prefix used to detect provisioning-related configuration groups. |
| cfgUserSettingsGroupPrefix |  | String | Prefix used to detect user-settings-related configuration groups. |
| licWin365GroupPrefix |  | String | Prefix used to detect Windows 365 license groups. |
| skipGracePeriod |  | Boolean | If set to true, ends the Cloud PC grace period immediately. |
| KeepUserSettingsAndProvisioningGroups |  | Boolean | If set to true, does not remove related provisioning and user settings groups. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='user-mail'></a>
## Mail

<a name='user-mail-add-or-remove-email-address'></a>

### Add Or Remove Email Address
Add or remove an email address for a mailbox

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the mailbox. |
| EmailAddress | ✓ | String | Email address to add or remove. |
| Remove |  | Boolean | If set to true, removes the address instead of adding it. |
| asPrimary |  | Boolean | If set to true, sets the specified address as the primary SMTP address. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-mail-assign-owa-mailbox-policy'></a>

### Assign OWA Mailbox Policy
Assign an OWA mailbox policy to a user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target mailbox. |
| OwaPolicyName | ✓ | String | Name of the OWA mailbox policy to assign. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-mail-convert-to-shared-mailbox'></a>

### Convert To Shared Mailbox
Convert a user mailbox to a shared mailbox and back

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the mailbox. |
| delegateTo |  | String | User principal name of the delegate who should receive access. |
| Remove |  | Boolean | If set to true, converts a shared mailbox back to a regular mailbox. |
| AutoMapping |  | Boolean | If set to true, enables automatic Outlook mapping for delegated FullAccess. |
| RemoveGroups |  | Boolean | If set to true, removes existing group memberships when converting to a shared mailbox. |
| ArchivalLicenseGroup |  | String | Display name of a license group to assign when an archive or larger mailbox requires it. |
| RegularLicenseGroup |  | String | Display name of a license group to assign when converting back to a regular mailbox. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-mail-delegate-full-access'></a>

### Delegate Full Access
Delegate FullAccess permissions to another user on a mailbox or remove existing delegation

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the mailbox. |
| delegateTo | ✓ | String | User principal name of the delegate. |
| Remove |  | Boolean | If set to true, removes the delegation instead of granting it. |
| AutoMapping |  | Boolean | If set to true, enables Outlook automapping when granting FullAccess. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-mail-delegate-send-as'></a>

### Delegate Send As
Delegate SendAs permissions for other user on his/her mailbox or remove existing delegation

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| delegateTo | ✓ | String | User principal name of the delegate. |
| Remove |  | Boolean | If set to true, removes the delegation instead of granting it. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-mail-delegate-send-on-behalf'></a>

### Delegate Send On Behalf
Delegate SendOnBehalf permissions for the user's mailbox

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the mailbox. |
| delegateTo | ✓ | String | User principal name of the delegate. |
| Remove |  | Boolean | If set to true, removes the delegation instead of granting it. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-mail-hide-or-unhide-in-addressbook'></a>

### Hide Or Unhide In Addressbook
Hide or unhide a mailbox in the address book

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the mailbox. |
| HideMailbox |  | Boolean | If set to true, hides the mailbox from address lists. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-mail-list-mailbox-permissions'></a>

### List Mailbox Permissions
List mailbox permissions for a mailbox

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the mailbox. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-mail-list-room-mailbox-configuration'></a>

### List Room Mailbox Configuration
List room mailbox configuration

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the room mailbox. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-mail-remove-mailbox'></a>

### Remove Mailbox
Hard delete a shared mailbox, room or bookings calendar

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the mailbox. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-mail-set-out-of-office'></a>

### Set Out Of Office
Enable or disable out-of-office notifications for a mailbox

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the mailbox. |
| Disable |  | Boolean | "Enable Out-of-Office" (final value: $false) or "Disable Out-of-Office" (final value: $true) can be selected as action to perform. |
| Start |  | DateTime | Start time for scheduled out-of-office replies. |
| End |  | DateTime | End time for scheduled out-of-office replies. If not specified, defaults to 10 years from the current date. |
| MessageInternal |  | String | Internal automatic reply message. |
| MessageExternal |  | String | External automatic reply message. |
| CreateEvent |  | Boolean | If set to true, creates an out-of-office calendar event. |
| EventSubject |  | String | Subject for the optional out-of-office calendar event. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-mail-set-room-mailbox-configuration'></a>

### Set Room Mailbox Configuration
Set room mailbox resource policies

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the room mailbox. |
| AllBookInPolicy |  | Boolean | "Allow BookIn for everyone" (final value: $true) or "Custom BookIn Policy" (final value: $false) can be selected as action to perform. If set to true, the room will allow BookIn for everyone and the BookInPolicyGroup parameter will be ignored. If set to false, only members of the group specified in the BookInPolicyGroup parameter will be allowed to BookIn. |
| BookInPolicyGroup |  | String | Group whose members are allowed to book when AllBookInPolicy is false. |
| AllowRecurringMeetings |  | Boolean | If set to true, allows recurring meetings. |
| AutomateProcessing |  | String | Calendar processing mode for the room mailbox. |
| BookingWindowInDays |  | Int32 | How many days into the future bookings are allowed. |
| MaximumDurationInMinutes |  | Int32 | Maximum meeting duration in minutes. |
| AllowConflicts |  | Boolean | If set to true, allows scheduling conflicts. |
| Capacity |  | Int32 | Capacity to set for the room when greater than 0. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='user-phone'></a>
## Phone

<a name='user-phone-disable-teams-phone'></a>

### Disable Teams Phone
Microsoft Teams telephony offboarding

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User which should be cleared. Could be filled with the user picker in the UI. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-phone-get-teams-user-info'></a>

### Get Teams User Info
Get Microsoft Teams voice status for a user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-phone-grant-teams-user-policies'></a>

### Grant Teams User Policies
Grant Microsoft Teams policies to a Microsoft Teams enabled user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| OnlineVoiceRoutingPolicy |  | String | Microsoft Teams Online Voice Routing Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TenantDialPlan |  | String | Microsoft Teams Tenant Dial Plan Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TeamsCallingPolicy |  | String | Microsoft Teams Calling Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TeamsIPPhonePolicy |  | String | Microsoft Teams IP Phone Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. This is typically used for Common Area Phone users. |
| OnlineVoicemailPolicy |  | String | Microsoft Teams Online Voicemail Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TeamsMeetingPolicy |  | String | Microsoft Teams Meeting Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TeamsMeetingBroadcastPolicy |  | String | Microsoft Teams Meeting Broadcast Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-phone-set-teams-permanent-call-forwarding'></a>

### Set Teams Permanent Call Forwarding
Set immediate call forwarding for a Teams user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| ForwardTargetPhoneNumber |  | String | Phone number to which calls should be forwarded. Must be in E.164 format (e.g. +49123456789) |
| ForwardTargetTeamsUser |  | String | User principal name of the Teams user to forward calls to. |
| ForwardToVoicemail |  | Boolean | If set to true, forwards calls to voicemail. |
| ForwardToDelegates |  | Boolean | If set to true, forwards calls to the delegates defined by the user. |
| TurnOffForward |  | Boolean | If set to true, disables immediate call forwarding. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-phone-set-teams-phone'></a>

### Set Teams Phone
Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| PhoneNumber | ✓ | String | Phone number which should be assigned to the user. The number must be in E.164 format (e.g. +49123456789). |
| OnlineVoiceRoutingPolicy |  | String | Name of the Online Voice Routing Policy to assign. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TenantDialPlan |  | String | Name of the Tenant Dial Plan to assign. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TeamsCallingPolicy |  | String | Name of the Teams Calling Policy to assign. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TeamsIPPhonePolicy |  | String | Name of the Teams IP Phone Policy to assign. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='user-security'></a>
## Security

<a name='user-security-confirm-or-dismiss-risky-user'></a>

### Confirm Or Dismiss Risky User
Confirm compromise or dismiss a risky user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| Dismiss |  | Boolean | "Confirm compromise" (final value: $false) or "Dismiss risk" (final value: $true) can be selected as action to perform. If set to true, the runbook will attempt to dismiss the risky user entry for the target user. If set to false, it will attempt to confirm a compromise for the target user. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-security-create-temporary-access-pass'></a>

### Create Temporary Access Pass
Create a temporary access pass for a user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| LifetimeInMinutes |  | Int32 | Lifetime of the temporary access pass in minutes. |
| OneTimeUseOnly |  | Boolean | If set to true, the pass can be used only once. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-security-enable-or-disable-password-expiration'></a>

### Enable Or Disable Password Expiration
Enable or disable password expiration for a user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| DisablePasswordExpiration |  | Boolean | If set to true, disables password expiration for the user. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-security-reset-mfa'></a>

### Reset MFA
Remove all App- and Mobilephone auth methods for a user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-security-reset-password'></a>

### Reset Password
Reset a user's password

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| EnableUserIfNeeded |  | Boolean | If set to true, enables the user account before resetting the password. |
| ForceChangePasswordNextSignIn |  | Boolean | If set to true, forces the user to change the password at the next sign-in. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-security-revoke-or-restore-access'></a>

### Revoke Or Restore Access
Revoke or restore user access

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| Revoke |  | Boolean | "(Re-)Enable User" (final value: $false) or "Revoke Access" (final value: $true) can be selected as action to perform. If set to true, the runbook will block the user from signing in and revoke active sessions. If set to false, it will re-enable the user account. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-security-set-or-remove-mobile-phone-mfa'></a>

### Set Or Remove Mobile Phone MFA
Set or remove a user's mobile phone MFA method

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| phoneNumber | ✓ | String | Mobile phone number in international E.164 format (e.g., +491701234567). |
| Remove |  | Boolean | "Set/Update Mobile Phone MFA Method" (final value: $false) or "Remove Mobile Phone MFA Method" (final value: $true) can be selected as action to perform. If set to true, the runbook will remove the mobile phone MFA method for the user. If set to false, it will add or update the mobile phone MFA method with the provided phone number. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='user-userinfo'></a>
## Userinfo

<a name='user-userinfo-rename-user'></a>

### Rename User
Rename a user or mailbox

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the user or mailbox to rename. |
| NewUpn | ✓ | String | New user principal name to set. |
| ChangeMailnickname |  | Boolean | If set to true, updates the mailbox alias and name based on the new UPN. |
| UpdatePrimaryAddress |  | Boolean | If set to true, updates the primary SMTP address and rewrites email addresses accordingly. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-userinfo-set-photo'></a>

### Set Photo
Set the profile photo for a user

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| PhotoURI | ✓ | String | URL to a JPEG image that will be used as the profile photo. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

<a name='user-userinfo-update-user'></a>

### Update User
Update user metadata and memberships

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User principal name of the target user. |
| GivenName |  | String | Given name to set for the user. |
| Surname |  | String | Surname to set for the user. |
| DisplayName |  | String | Display name to set for the user. |
| CompanyName |  | String | Company name to set for the user. |
| City |  | String | City to set for the user. |
| Country |  | String | Country to set for the user. |
| JobTitle |  | String | Job title to set for the user. |
| Department |  | String | Department to set for the user. |
| OfficeLocation |  | String | Office location to set for the user. |
| PostalCode |  | String | Postal code to set for the user. |
| PreferredLanguage |  | String | Preferred language to set for the user. Examples: "en-US" or "de-DE". |
| State |  | String | State to set for the user. |
| StreetAddress |  | String | Street address to set for the user. |
| UsageLocation |  | String | Usage location to set for the user. |
| DefaultLicense |  | String | Display name of a license group to assign. |
| DefaultGroups |  | String | Comma-separated list of group display names to assign. |
| EnableEXOArchive |  | Boolean | If set to true, enables the Exchange Online archive mailbox. |
| ResetPassword |  | Boolean | If set to true, resets the user's password. |
| CallerName | ✓ | String | Caller name is tracked purely for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)


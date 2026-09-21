<a name='runbook-overview'></a>
# RealmJoin runbook overview
This document provides a comprehensive overview of all runbooks currently available in the RealmJoin portal. Each runbook is listed along with a brief description or synopsis to give a clear understanding of its purpose and functionality.

To ensure easy navigation, the runbooks are categorized into different sections based on their area of application. The following categories are currently available:
- Device
- Group
- Organization
- User

Each category contains multiple runbooks that are further divided into subcategories based on their functionality. The runbooks are listed in alphabetical order within each subcategory.

# Runbooks - Table of contents

- [Device](#device)
  - [AVD](#device-avd)
      - [Restart Host](#restart-host)
      - [Toggle Drain Mode](#toggle-drain-mode)
  - [General](#device-general)
      - [Assign Groups By Template](#assign-groups-by-template)
      - [Change Grouptag](#change-grouptag)
      - [Check Device Compliance](#check-device-compliance)
      - [Check Updatable Assets](#check-updatable-assets)
      - [Enroll Updatable Assets](#enroll-updatable-assets)
      - [Outphase Device](#outphase-device)
      - [Remove Primary User](#remove-primary-user)
      - [Rename Device](#rename-device)
      - [Set Primary User](#set-primary-user)
      - [Unenroll Updatable Assets](#unenroll-updatable-assets)
      - [Wipe Device](#wipe-device)
      - [Wipe Managed App Data](#wipe-managed-app-data)
  - [Security](#device-security)
      - [Check Defender Status](#check-defender-status)
      - [Enable Or Disable Device](#enable-or-disable-device)
      - [Isolate Or Release Device](#isolate-or-release-device)
      - [Reset Mobile Device Pin](#reset-mobile-device-pin)
      - [Restrict Or Release Code Execution](#restrict-or-release-code-execution)
      - [Show Bitlocker Recovery Key](#show-bitlocker-recovery-key)
      - [Show Filevault Recovery Key](#show-filevault-recovery-key)
      - [Show Laps Password](#show-laps-password)
- [Group](#group)
  - [Devices](#group-devices)
      - [Check Updatable Assets](#check-updatable-assets)
      - [Unenroll Updatable Assets (Scheduled)](#unenroll-updatable-assets-(scheduled))
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
      - [Add GSA Application Registration](#add-gsa-application-registration)
      - [Delete Application Registration](#delete-application-registration)
      - [Delete GSA Application Registration](#delete-gsa-application-registration)
      - [Export Enterprise Application Users](#export-enterprise-application-users)
      - [List Inactive Enterprise Applications](#list-inactive-enterprise-applications)
      - [Report Application Registration](#report-application-registration)
      - [Report Expiring Application Credentials (Scheduled)](#report-expiring-application-credentials-(scheduled))
      - [Update Application Registration](#update-application-registration)
  - [Collab](#org-collab)
      - [Check Onedrive Status](#check-onedrive-status)
      - [List Sharepoint Sitecollection Permission](#list-sharepoint-sitecollection-permission)
      - [Report Sharepoint Tenant Storage (Scheduled)](#report-sharepoint-tenant-storage-(scheduled))
  - [Devices](#org-devices)
      - [Add Autopilot Device](#add-autopilot-device)
      - [Add Device Via Corporate Identifier](#add-device-via-corporate-identifier)
      - [Auto Approve Driver Updates (Scheduled)](#auto-approve-driver-updates-(scheduled))
      - [Cleanup Autopilot Devices (Scheduled)](#cleanup-autopilot-devices-(scheduled))
      - [Create Endpoint Analytics Baseline](#create-endpoint-analytics-baseline)
      - [Dedup Device Names (Scheduled)](#dedup-device-names-(scheduled))
      - [Delete Stale Devices (Scheduled)](#delete-stale-devices-(scheduled))
      - [Get Bitlocker Recovery Key](#get-bitlocker-recovery-key)
      - [List Mobile Devices](#list-mobile-devices)
      - [Notify Users About Low Diskspace (Scheduled)](#notify-users-about-low-diskspace-(scheduled))
      - [Notify Users About Stale Devices (Scheduled)](#notify-users-about-stale-devices-(scheduled))
      - [Outphase Devices](#outphase-devices)
      - [Rename Devices By Group Tag (Scheduled)](#rename-devices-by-group-tag-(scheduled))
      - [Report Devices Low Diskspace (Scheduled)](#report-devices-low-diskspace-(scheduled))
      - [Report Devices Without Primary User (Scheduled)](#report-devices-without-primary-user-(scheduled))
      - [Report Primary User Mismatch (Scheduled)](#report-primary-user-mismatch-(scheduled))
      - [Report Stale Devices (Scheduled)](#report-stale-devices-(scheduled))
      - [Report Users With More Than 5-Devices (Scheduled)](#report-users-with-more-than-5-devices-(scheduled))
      - [Report Windows Devices Without Autopilot (Scheduled)](#report-windows-devices-without-autopilot-(scheduled))
      - [Sync Device Serialnumbers To Entraid (Scheduled)](#sync-device-serialnumbers-to-entraid-(scheduled))
  - [General](#org-general)
      - [Add Devices Of Users To Group (Scheduled)](#add-devices-of-users-to-group-(scheduled))
      - [Add Management Partner](#add-management-partner)
      - [Add Microsoft Store App Logos](#add-microsoft-store-app-logos)
      - [Add Office365 Group](#add-office365-group)
      - [Add Or Remove Safelinks Exclusion](#add-or-remove-safelinks-exclusion)
      - [Add Or Remove Smartscreen Exclusion](#add-or-remove-smartscreen-exclusion)
      - [Add Or Remove Trusted Site](#add-or-remove-trusted-site)
      - [Add Primary Users Of Devices To Group (Scheduled)](#add-primary-users-of-devices-to-group-(scheduled))
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
      - [Monitor Service Health (Scheduled)](#monitor-service-health-(scheduled))
      - [Office365 License Report](#office365-license-report)
      - [Report Apple MDM Cert Expiry (Scheduled)](#report-apple-mdm-cert-expiry-(scheduled))
      - [Report Intune Enrollment Readiness](#report-intune-enrollment-readiness)
      - [Report License Assignment (Scheduled)](#report-license-assignment-(scheduled))
      - [Report Pim Activations (Scheduled)](#report-pim-activations-(scheduled))
      - [Sync All Devices](#sync-all-devices)
      - [Sync Apple Tokens](#sync-apple-tokens)
      - [Sync Channel Or Group Members (Scheduled)](#sync-channel-or-group-members-(scheduled))
      - [Sync Shared Channel Owners (Scheduled)](#sync-shared-channel-owners-(scheduled))
  - [Mail](#org-mail)
      - [Add Distribution List](#add-distribution-list)
      - [Add Equipment Mailbox](#add-equipment-mailbox)
      - [Add Mail Contact](#add-mail-contact)
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
      - [Find SMS Auth Phone Number](#find-sms-auth-phone-number)
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
      - [Sync MFA Secure Users To Group (Scheduled)](#sync-mfa-secure-users-to-group-(scheduled))
- [User](#user)
  - [AVD](#user-avd)
      - [User Signout](#user-signout)
  - [General](#user-general)
      - [Assign Groups By Template](#assign-groups-by-template)
      - [Assign Or Unassign License](#assign-or-unassign-license)
      - [Assign Windows365](#assign-windows365)
      - [Check Intune Enrollment Readiness](#check-intune-enrollment-readiness)
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
      - [Manage Archive Mailbox](#manage-archive-mailbox)
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
      - [List MFA Methods](#list-mfa-methods)
      - [List Signin Events](#list-signin-events)
      - [Reset MFA](#reset-mfa)
      - [Reset Password](#reset-password)
      - [Revoke Or Restore Access](#revoke-or-restore-access)
      - [Set Or Remove Mobile Phone MFA](#set-or-remove-mobile-phone-mfa)
  - [Userinfo](#user-userinfo)
      - [Rename User](#rename-user)
      - [Set Photo](#set-photo)
      - [Update User](#update-user)

<a name='device'></a>

# Device
<a name='device-avd'></a>

## AVD
<a name='device-avd-restart-host'></a>

### Restart Host
#### Restart this AVD session host and return it to service

#### Description

Restarts this Azure Virtual Desktop session host. Signed-in users are disconnected. Drain mode is switched on first so no new sessions land on the host. A stopped host is started instead of rebooted. Once the host runs again, drain mode is switched off.

#### Where to find

Device \ AVD \ Restart Host


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-avd-toggle-drain-mode'></a>

### Toggle Drain Mode
#### Enable or disable drain mode on this AVD session host

#### Description

Switches drain mode for this Azure Virtual Desktop session host, whichever host pool of the tenant it belongs to. With drain mode on, the host accepts no new sessions, for example before maintenance; existing sessions stay connected. With drain mode off, the host takes new sessions again.

#### Where to find

Device \ AVD \ Toggle Drain Mode


[Back to Table of Content](#table-of-contents)

 
 

<a name='device'></a>

# Device
<a name='device-general'></a>

## General
<a name='device-general-assign-groups-by-template'></a>

### Assign Groups By Template
#### Add this device to a predefined set of groups

#### Description

Adds this device to one or more Entra ID groups. The groups come from a template that an administrator defines in the runbook customization, so the person running it picks a template instead of individual groups.

#### Where to find

Device \ General \ Assign Groups By Template


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-change-grouptag'></a>

### Change Grouptag
#### Assign a new Autopilot group tag to this device

#### Description

Sets a new Windows Autopilot group tag on this device. The group tag decides which Autopilot profile and, through dynamic groups, which policies and apps the device gets, so changing it prepares the device for a different deployment. Nothing else on the device is changed.

#### Where to find

Device \ General \ Change Grouptag


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-check-device-compliance'></a>

### Check Device Compliance
#### Check the Intune compliance status of this device

#### Description

Shows whether this device is compliant in Intune. The simple view lists the overall state and the names of the non-compliant policies; the detailed view also shows which settings fail and why. Nothing is changed on the device. The report can be sent by email.

#### Where to find

Device \ General \ Check Device Compliance

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-check-updatable-assets'></a>

### Check Updatable Assets
#### Check whether this device is enrolled in Windows Update for Business

#### Description

Shows whether this device is registered as an updatable asset in the Windows Update for Business deployment service. Nothing is changed on the device.

#### Where to find

Device \ General \ Check Updatable Assets


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-enroll-updatable-assets'></a>

### Enroll Updatable Assets
#### Enroll this device in Windows Update for Business

#### Description

Registers this device as an updatable asset in Windows Update for Business for the chosen update category, so Intune can manage driver, feature or quality updates for it. All enrolls it in driver, feature and quality updates.

#### Where to find

Device \ General \ Enroll Updatable Assets


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-outphase-device'></a>

### Outphase Device
#### Wipe this Windows device and clean up Intune, Autopilot and Entra ID

#### Description

Takes this Windows device out of service. You choose whether the device is wiped or only deleted from Intune, and whether it leaves the Autopilot database. Its Entra ID object can be deleted, disabled or kept. Optionally the device is tagged in Microsoft Defender for Endpoint so rules that use the tag can exclude it from automated remediation. A wipe removes all user and enrollment data from the device and cannot be undone.

#### Where to find

Device \ General \ Outphase Device

## Microsoft Defender for Endpoint exclusion tag

Microsoft Defender for Endpoint has a native **Exclusion state** (shown in the Device Inventory filter as *Excluded* / *Not Excluded*). This state can only be set through the Defender portal — there is **no API** to set a device's native exclusion state programmatically.

Because the native exclusion state cannot be automated, this runbook instead applies a custom device tag (default `ExcludeFromRemediation`) when *Exclude device from Defender for Endpoint* is enabled. The device is looked up by its Entra ID device ID and tagged via `POST /api/machines/{id}/tags`, providing a marker that can be used to filter and target excluded devices.

### One-time setup: make the tag filterable

The portal's **Tags** filter unfortunately only lists tags that were created through the portal. A tag set purely via the API is attached to the device and visible on the device page, but it does **not** appear in the Tags filter on its own.

To make the exclusion tag visible and usable for filtering in the [Defender Device Inventory](https://security.microsoft.com/machines), one client must be tagged manually once through the portal (select a device > **Manage tags** > "Create new tag", using the exact same tag value). After this one-time step the tag becomes a known, filterable tag, and this runbook can apply it to devices at scale.

> **Note:** This tag is only a label — it does not set the device's native Exclusion state and has no remediation effect on its own. It takes effect only if a Defender device group or automation rule is explicitly configured to match this tag value. Such rules match the tag value directly, independently of the portal **Tags** filter, so the one-time manual step only affects whether the tag is selectable for filtering in the portal UI.

See [Create and manage device tags](https://learn.microsoft.com/defender-endpoint/machine-tags#create-tags) for details.



[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-remove-primary-user'></a>

### Remove Primary User
#### Remove the primary user from this device

#### Description

Clears the primary user of this device in Intune. The device then has no assigned user, which is useful for shared devices or before handing the device to someone else. The user account itself is not changed.

#### Where to find

Device \ General \ Remove Primary User


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-rename-device'></a>

### Rename Device
#### Rename this device in Intune and Autopilot

#### Description

Gives this device a new name in Intune and in its Windows Autopilot record. Before anything is changed, the name is checked against the Windows computer name rules. It may have up to 15 letters, digits and hyphens, must start and end with a letter or digit, and cannot be digits only.

#### Where to find

Device \ General \ Rename Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-set-primary-user'></a>

### Set Primary User
#### Set a new primary user on this device

#### Description

Assigns the chosen user as the new primary user of this device in Intune and replaces the current one. The output shows the previous and the new assignment.

#### Where to find

Device \ General \ Set Primary User


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-unenroll-updatable-assets'></a>

### Unenroll Updatable Assets
#### Unenroll this device from Windows Update for Business

#### Description

Removes this device from Windows Update for Business for the chosen update category. Choosing all removes the device as an updatable asset altogether, so Intune no longer manages driver, feature or quality updates for it through the deployment service.

#### Where to find

Device \ General \ Unenroll Updatable Assets


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-wipe-device'></a>

### Wipe Device
#### Wipe this Windows or macOS device and clean up its records

#### Description

Wipes this Windows or macOS device. Optionally it also cleans up what is left of it: the Intune record, the Autopilot registration and the Entra ID object can be deleted or disabled. For Windows you can choose a protected wipe and a longer compliance grace period after re-enrollment, for macOS a recovery code and how the OS is erased. A wipe removes all data on the device and cannot be undone. The wipe can be skipped when Defender for Endpoint rates the device as medium or high risk.

#### Where to find

Device \ General \ Wipe Device

## Only wipe if the device is not at risk

When *Only wipe if device is not at risk* (`skipWipeIfAtRisk`) is enabled, the runbook checks the device's risk score in Microsoft Defender for Endpoint before any device object is touched. The lookup uses the Entra device ID and is the same query the **Check Defender Status** runbook performs. The check is off by default and only runs when a wipe is requested; it is skipped when *Do not wipe device* is selected.

Possible outcomes:

- **No elevated risk** (risk score `None`, `Informational` or `Low`): the wipe and the selected clean-up actions run as usual.
- **Risk score `Medium` or `High`**: the runbook stops with a warning before the wipe, the exclusion-group membership, the Entra changes and the Intune/Autopilot deletions. A device with an elevated risk score may be involved in a security incident, and wiping it could destroy forensic data (e.g. logs). Align with your security team first; to wipe the device anyway, run the runbook with the option disabled.
- **Device not found in Defender for Endpoint**: the risk score cannot be determined. The runbook notes this and proceeds with the wipe, so devices that are not onboarded to Defender are not blocked.
- **Defender query fails**: the runbook stops without wiping, so a temporary API problem never bypasses the protection.

### Enable the check by default

To enforce the check for every wipe, preset the parameter and hide it, so it cannot be switched off from the portal.

The json configuration for this is as follows:

```json
"rjgit-device_general_wipe-device": {
    "parameters": {
        "skipWipeIfAtRisk": {
            "Default": true,
            "Hide": true
        }
    }
}
```

## Add the device to a compliance exclusion group

When *Add device to compliance exclusion group* (`addToExclusionGroup`) is enabled, the wiped Windows device is added to a compliance exclusion group. Devices in that group receive a longer compliance grace period after they are re-enrolled via Autopilot (this mirrors the **Check Device Onboarding Exclusion** runbook).

By default the group is identified by its **display name** (`exclusionGroupName`). Because display names are not guaranteed to be unique, you can instead pin the group by its **Object ID** (`exclusionGroupId`). When an Object ID is provided, it **always overrides** the display name, so name conflicts can never lead to the wrong group being used. `exclusionGroupId` is hidden by default and is meant to be set via runbook customization.

The group is resolved and validated in an upfront preflight check. If the configured group does not exist, the runbook aborts **before** any wipe/delete/disable action, so no half-applied state is left behind. Adding to the group is skipped for non-Windows devices and when the device is deleted from EntraID (`removeAADDevice`).

### Pin the group by Object ID (recommended)

Preset the group's Object ID and enable the switch, keeping the fields hidden. This avoids any ambiguity from duplicate display names.

The json configuration for this is as follows:

```json
"rjgit-device_general_wipe-device": {
    "parameters": {
        "addToExclusionGroup": {
            "Default": true
        },
        "exclusionGroupId": {
            "Default": "00000000-0000-0000-0000-000000000000",
            "Hide": true
        },
        "exclusionGroupName": {
            "Hide": true
        }
    }
}
```

Replace `00000000-0000-0000-0000-000000000000` with the Object ID of your group (EntraID > Groups > *your group* > **Object Id**).

### Pin the group by display name

If you prefer to work with the display name (and it is unique in your tenant), preset `exclusionGroupName` and leave `exclusionGroupId` empty so the name is used.

The json configuration for this is as follows:

```json
"rjgit-device_general_wipe-device": {
    "parameters": {
        "addToExclusionGroup": {
            "Default": true
        },
        "exclusionGroupName": {
            "Default": "cfg - Intune - Windows - Compliance for unenrolled Autopilot devices (devices)",
            "Hide": true
        }
    }
}
```

## macOS wipe options

macOS devices are wiped through Intune's erase action. Two options only apply to them:

- **Recovery code (macOS)** (`macOsRecoveryCode`): older Macs need a six-digit recovery code to accept the wipe; newer devices ignore it. The parameter is hidden in the portal and can be preset via runbook customization.
- **Obliteration behavior (macOS)** (`macOsObliterationBehavior`): decides what happens when *Erase All Content and Settings* (EACS) is not possible. `default` erases the user data and falls back to erasing the whole OS, `doNotObliterate` never erases the OS, `obliterateWithWarning` warns and then erases the OS, `always` erases the OS in any case.

Windows-only options (*protected wipe*, *Autopilot database*, *compliance exclusion group*) are ignored for macOS devices.



[Back to Table of Content](#table-of-contents)

 
 

<a name='device-general-wipe-managed-app-data'></a>

### Wipe Managed App Data
#### Remove company app data from this MAM-managed device

#### Description

Removes company data from apps protected by app protection policies on this device, without wiping the whole device. This is the app selective wipe known from the Intune portal, typically used for lost or stolen devices that are managed by app protection only and not enrolled in Intune. The data is removed the next time each protected app checks in, so the wipe is not instant. Pending requests can be monitored and cancelled in the Intune portal.

#### Where to find

Device \ General \ Wipe Managed App Data

## Device matching

MAM app registrations belong to a user, not to a device object. The runbook therefore resolves the
users registered on the device and matches their app registrations against the device's EntraID
device id (`azureADDeviceId`). Registrations without an EntraID device id are matched by the
device's display name as fallback; the runbook output indicates when this fallback was used.

## Wipe behavior

- The company app data is removed the next time each protected app checks in on the device; the
  wipe is not instantaneous.
- Pending wipe requests can be monitored and cancelled in the Intune portal under
  *Apps > App selective wipe*.
- Only app data protected by app protection policies (MAM) is affected. The device object itself
  is not touched: it remains in EntraID (and in Intune/Autopilot, if it is additionally
  MDM-enrolled). To disable or remove the device there as well, run the **Outphase Device**
  runbook (Device \ General) afterwards; for a full wipe of MDM-enrolled devices use
  **Wipe Device**.



[Back to Table of Content](#table-of-contents)

 
 

<a name='device'></a>

# Device
<a name='device-security'></a>

## Security
<a name='device-security-check-defender-status'></a>

### Check Defender Status
#### Check this device in Entra ID and Defender for Endpoint

#### Description

Looks up this device in Entra ID and in Microsoft Defender for Endpoint. It shows whether the device exists in each, its onboarding and health state in Defender, and its Defender risk score. A medium or high risk score is flagged. Nothing is changed.

#### Where to find

Device \ Security \ Check Defender Status


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-enable-or-disable-device'></a>

### Enable Or Disable Device
#### Enable or disable this device in Entra ID

#### Description

Disables or re-enables the Entra ID object of this device. A disabled device can no longer be used to sign in, which blocks a lost or compromised device; enabling it again lifts the block. Nothing on the device itself is changed.

#### Where to find

Device \ Security \ Enable Or Disable Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-isolate-or-release-device'></a>

### Isolate Or Release Device
#### Isolate this device from the network or release it

#### Description

Isolates this device in Microsoft Defender for Endpoint so that, with full isolation, it can only talk to the Defender service. That limits lateral movement and data theft during an incident. It can also release a previously isolated device. Give a short reason; it is recorded with the action in Defender.

#### Where to find

Device \ Security \ Isolate Or Release Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-reset-mobile-device-pin'></a>

### Reset Mobile Device Pin
#### Reset the passcode of this mobile device

#### Description

Triggers an Intune passcode reset for this mobile device. Intune supports this only for certain corporate-owned device types and rejects it for personal or unsupported devices. Optionally the reset is skipped when Microsoft Defender for Endpoint rates the device as medium or high risk.

#### Where to find

Device \ Security \ Reset Mobile Device Pin

## Only reset the passcode if the device is not at risk

When *Only reset passcode if device is not at risk* (`skipIfAtRisk`) is enabled, the runbook checks the device's risk score in Microsoft Defender for Endpoint before the Intune device is looked up and the reset is triggered. The lookup uses the Entra device ID and is the same query the **Check Defender Status** runbook performs. The check is off by default.

Possible outcomes:

- **No elevated risk** (risk score `None`, `Informational` or `Low`): the passcode is reset as usual.
- **Risk score `Medium` or `High`**: the runbook stops with a warning before anything is changed. A device with an elevated risk score may be involved in a security incident; resetting its passcode could grant access to the device or interfere with the investigation. Align with your security team first; to reset the passcode anyway, run the runbook with the option disabled.
- **Device not found in Defender for Endpoint**: the risk score cannot be determined. The runbook notes this and proceeds with the reset. Mobile devices only appear in Defender for Endpoint when the Defender app is deployed and onboarded on them, so devices without Defender are not blocked by the check.
- **Device found, but without a risk score** (e.g. freshly onboarded): the runbook notes this and proceeds as well.
- **Defender query fails**: the runbook stops without resetting the passcode, so a temporary API problem never bypasses the protection.

### Enable the check by default

To enforce the check for every request, preset the parameter and hide it, so it cannot be switched off from the portal.

The json configuration for this is as follows:

```json
"rjgit-device_security_reset-mobile-device-pin": {
    "parameters": {
        "skipIfAtRisk": {
            "Default": true,
            "Hide": true
        }
    }
}
```



[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-restrict-or-release-code-execution'></a>

### Restrict Or Release Code Execution
#### Restrict this device to Microsoft-signed code or lift the restriction

#### Description

Restricts this device through Microsoft Defender for Endpoint so that only Microsoft-signed code can run, which blocks unsigned tools an attacker may have placed on it. It can also lift an existing restriction. Give a short reason; it is recorded with the action in Defender.

#### Where to find

Device \ Security \ Restrict Or Release Code Execution


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-show-bitlocker-recovery-key'></a>

### Show Bitlocker Recovery Key
#### Show the BitLocker recovery keys of this device

#### Description

Lists all BitLocker recovery keys backed up for this device, newest first, for disk recovery. Nothing is changed. Optionally the keys are withheld when Microsoft Defender for Endpoint rates the device as medium or high risk. That way the keys are not handed out before the security team has been involved, in case the device is under investigation.

#### Where to find

Device \ Security \ Show Bitlocker Recovery Key

## Only show keys if the device is not at risk

When *Only show keys if device is not at risk* (`skipIfAtRisk`) is enabled, the runbook checks the device's risk score in Microsoft Defender for Endpoint before any recovery key is retrieved. The lookup uses the Entra device ID and is the same query the **Check Defender Status** runbook performs. The check is off by default.

Possible outcomes:

- **No elevated risk** (risk score `None`, `Informational` or `Low`): the recovery keys are shown as usual.
- **Risk score `Medium` or `High`**: the runbook stops with a warning before any key is read. A device with an elevated risk score may be involved in a security incident, and disclosing its recovery key could expose the encrypted data to an attacker. Align with your security team first; to show the keys anyway, run the runbook with the option disabled.
- **Device not found in Defender for Endpoint**: the risk score cannot be determined. The runbook notes this and proceeds with the key retrieval, so devices that are not onboarded to Defender are not blocked.
- **Device found, but without a risk score** (e.g. freshly onboarded): the runbook notes this and proceeds as well.
- **Defender query fails**: the runbook stops without showing any key, so a temporary API problem never bypasses the protection.

### Enable the check by default

To enforce the check for every request, preset the parameter and hide it, so it cannot be switched off from the portal.

The json configuration for this is as follows:

```json
"rjgit-device_security_show-bitlocker-recovery-key": {
    "parameters": {
        "skipIfAtRisk": {
            "Default": true,
            "Hide": true
        }
    }
}
```



[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-show-filevault-recovery-key'></a>

### Show Filevault Recovery Key
#### Show the FileVault recovery key of this Mac

#### Description

Shows the FileVault recovery key that Intune has stored for this macOS device. Use it to unlock the Mac when the user has forgotten the password or the device is locked. Nothing is changed.

#### Where to find

Device \ Security \ Show Filevault Recovery Key


[Back to Table of Content](#table-of-contents)

 
 

<a name='device-security-show-laps-password'></a>

### Show Laps Password
#### Show the local admin password of this device

#### Description

Shows the most recent Windows LAPS password of the local administrator account that is backed up for this device. Use it for break-glass troubleshooting and rotate the password afterwards. Looking it up changes nothing on the device.

#### Where to find

Device \ Security \ Show Laps Password


[Back to Table of Content](#table-of-contents)

 
 

<a name='group'></a>

# Group
<a name='group-devices'></a>

## Devices
<a name='group-devices-check-updatable-assets'></a>

### Check Updatable Assets
#### Check Windows Update for Business enrollment of this group's devices

#### Description

Checks for every device in this group whether it is registered as an updatable asset in Windows Update for Business. The result shows the enrollment state per update category and any error Windows Update returns. Nothing is changed.

#### Where to find

Group \ Devices \ Check Updatable Assets


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-devices-unenroll-updatable-assets-(scheduled)'></a>

### Unenroll Updatable Assets (Scheduled)
#### Unenroll this group's devices from Windows Update for Business

#### Description

Removes every device in this group from Windows Update for Business, either for one update category or by deleting the updatable asset registration entirely. Optionally the devices owned by the group's user members are included. Use it to offboard devices from Windows Update for Business reporting or to reset their enrollment.

#### Where to find

Group \ Devices \ Unenroll Updatable Assets_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='group'></a>

# Group
<a name='group-general'></a>

## General
<a name='group-general-add-or-remove-nested-group'></a>

### Add Or Remove Nested Group
#### Add a nested group to this group or remove it

#### Description

Adds another group as a member of this group, or removes that nesting again. Works for Microsoft Entra ID groups as well as Exchange Online distribution and mail-enabled security groups.

#### Where to find

Group \ General \ Add Or Remove Nested Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-add-or-remove-owner'></a>

### Add Or Remove Owner
#### Add an owner to this group or remove one

#### Description

Makes a user an owner of this group or removes an existing owner. For Microsoft 365 groups a new owner is also made a member.

#### Where to find

Group \ General \ Add Or Remove Owner


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-add-or-remove-user'></a>

### Add Or Remove User
#### Add a user to this group or remove one

#### Description

Adds a user as a member of this group or removes an existing member. Works for Microsoft Entra ID groups as well as Exchange Online distribution and mail-enabled security groups.

#### Where to find

Group \ General \ Add Or Remove User


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-change-visibility'></a>

### Change Visibility
#### Make this group public or private

#### Description

Switches this Microsoft 365 group between public and private. Public groups can be found and joined by anyone in the organization, private groups only by their members. Membership, owners and email addresses stay as they are.

#### Where to find

Group \ General \ Change Visibility


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-list-all-members'></a>

### List All Members
#### List all members of this group, nested groups included

#### Description

Lists every member of this Entra ID group, both direct members and those who belong through nested groups. The result is a CSV-formatted list with the user principal name, whether the membership is direct, and the group path. A path like "Primary, Secondary" means the user is in Primary through the nested group Secondary.

#### Where to find

Group \ General \ List All Members


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-list-owners'></a>

### List Owners
#### List the owners of this group

#### Description

Shows the owners of this group as a table. Nothing is changed.

#### Where to find

Group \ General \ List Owners


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-list-user-devices'></a>

### List User Devices
#### List the devices registered to this group's members

#### Description

Lists the devices registered to the users in this group. Optionally the found devices are added to a device group of your choice. Devices are only added to that group, never removed.

#### Where to find

Group \ General \ List User Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-remove-group'></a>

### Remove Group
#### Delete this group and its Microsoft 365 resources

#### Description

Deletes this group. For a Microsoft 365 group this also removes the Teams team and the SharePoint site that belong to it, including their content. The group and its content can be restored from the deleted groups for 30 days, after that they are gone.

#### Where to find

Group \ General \ Remove Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='group-general-rename-group'></a>

### Rename Group
#### Rename this group or change its description

#### Description

Updates the display name, the mail nickname and the description of this group. Fill in only the fields you want to change; empty fields are left as they are. The group's email addresses do not change.

#### Where to find

Group \ General \ Rename Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='group'></a>

# Group
<a name='group-mail'></a>

## Mail
<a name='group-mail-enable-or-disable-external-mail'></a>

### Enable Or Disable External Mail
#### Allow or block external senders for this Microsoft 365 group

#### Description

Controls whether people outside the organization can send email to this Microsoft 365 group. The current setting can also be shown without changing it.

#### Where to find

Group \ Mail \ Enable Or Disable External Mail

## Implementation notes

The setting is changed through Exchange Online (`RequireSenderAuthenticationEnabled`), not through Microsoft Graph. Writing the corresponding `allowExternalSenders` property of the group via Microsoft Graph is a documented known issue (as of 2021-06-28), see [Setting the allowExternalSenders property](https://docs.microsoft.com/en-us/graph/known-issues#setting-the-allowexternalsenders-property).



[Back to Table of Content](#table-of-contents)

 
 

<a name='group-mail-show-or-hide-in-address-book'></a>

### Show Or Hide In Address Book
#### Show or hide this group in the address book

#### Description

Shows this Microsoft 365 or distribution group in the address lists or hides it from them. A hidden group still receives email at its address; it just does not appear in the address book. Query only shows the current state without changing anything.

#### Where to find

Group \ Mail \ Show Or Hide In Address Book


[Back to Table of Content](#table-of-contents)

 
 

<a name='group'></a>

# Group
<a name='group-teams'></a>

## Teams
<a name='group-teams-archive-team'></a>

### Archive Team
#### Archive the team of this group

#### Description

Archives the Microsoft Teams team that belongs to this Microsoft 365 group. Members can still read the team's content, but nobody can post in its channels until the team is unarchived; files in the SharePoint site stay editable. Use it to retire an inactive team without losing its content. The group must be provisioned as a team.

#### Where to find

Group \ Teams \ Archive Team


[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-applications'></a>

## Applications
<a name='org-applications-add-application-registration'></a>

### Add Application Registration
#### Create an application registration in Entra ID

#### Description

Creates a new application registration in Entra ID. Optionally it also configures redirect URIs for web, SPA or public clients, SAML sign-in, visibility in My Apps, user assignment with an access group, and implicit grant. Duplicate names are refused and the inputs are checked before anything is created.

#### Where to find

Org \ Applications \ Add Application Registration


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-add-gsa-application-registration'></a>

### Add GSA Application Registration
#### Create a Global Secure Access application with its access group

#### Description

Creates a Global Secure Access (GSA) application in Entra ID with its application segment (destination, ports, protocol) and connector group, plus a security group that controls who may use it. If the application already exists, only the segment, group and assignment are updated. Everything is validated before anything is created, and objects created in a failed run are removed again.

#### Where to find

Org \ Applications \ Add GSA Application Registration


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-delete-application-registration'></a>

### Delete Application Registration
#### Delete an application registration and its service principal

#### Description

Deletes an application registration from Entra ID together with its service principal. Every group assigned to the application is deleted as well, including groups shared with other applications. Applications that still sign users in stop working immediately.

#### Where to find

Org \ Applications \ Delete Application Registration


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-delete-gsa-application-registration'></a>

### Delete GSA Application Registration
#### Delete a Global Secure Access application and its access group

#### Description

Deletes a Global Secure Access application that was created with the Add GSA Application Registration runbook. Its service principal, application segments, connector group assignment and the access group that follows the naming scheme go with it. Before deleting anything it checks that the application really is a GSA or App Proxy application. Other groups assigned to the application are only listed, unless you choose to delete them too.

#### Where to find

Org \ Applications \ Delete GSA Application Registration


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-export-enterprise-application-users'></a>

### Export Enterprise Application Users
#### Export the owners and users of all enterprise applications

#### Description

Lists all enterprise applications, or all service principals, with their owners and the users and groups assigned to them, for reviews and audits. Nothing is changed. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Applications \ Export Enterprise Application Users

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-list-inactive-enterprise-applications'></a>

### List Inactive Enterprise Applications
#### List enterprise applications with no recent sign-ins

#### Description

Finds enterprise applications that nobody has signed in to for a given number of days, plus those that were never used, so you can decide whether they are still needed. The check uses the service principal sign-in activity report, which keeps the last sign-in date of every application. Nothing is changed. Needs a Microsoft Entra ID P1 or P2 license. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Applications \ List Inactive Enterprise Applications

## How the sign-in data is determined

The runbook evaluates the Microsoft Entra **service principal sign-in activity** report
(`/beta/reports/servicePrincipalSignInActivities`). The report holds the date of the last sign-in per
service principal – across delegated and app-only flows, both as client and as resource – and is therefore
not limited to the retention period of the sign-in logs, which keep individual sign-in events for only
7 days (Microsoft Entra ID Free) resp. 30 days (Microsoft Entra ID P1/P2). A threshold of 90 days can
therefore be evaluated as reliably as one of 7 days.

Every enterprise application (service principal) of the tenant is assigned to exactly one of two lists:

- **Inactive applications** – the last sign-in is older than the configured number of days
- **Applications without any sign-in record** – the report contains no sign-in for the application

Requirements:

- A **Microsoft Entra ID P1 or P2** license – the report is part of *Usage & insights* and is not available without it
- The **AuditLog.Read.All** permission for the report and **Directory.Read.All** for the list of service principals

The runbook only reads data. It does not modify the listed applications.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-report-application-registration'></a>

### Report Application Registration
#### Report all application registrations, including deleted ones

#### Description

Lists every application registration in Entra ID, optionally including registrations deleted within the last 30 days, for inventory, review and audit purposes. Nothing is changed. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Applications \ Report Application Registration

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-report-expiring-application-credentials-(scheduled)'></a>

### Report Expiring Application Credentials (Scheduled)
#### Report expiring client secrets and certificates of app registrations

#### Description

Lists the client secrets and certificates of application registrations with their expiry dates. You can limit the list to credentials that expire within a chosen number of days and to certain applications. The credential list also appears as a sortable table in the portal's output. Nothing is changed. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Applications \ Report Expiring Application Credentials_Scheduled

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-applications-update-application-registration'></a>

### Update Application Registration
#### Update redirect URIs, SAML and sign-in settings of an app registration

#### Description

Changes the configuration of an existing application registration in Entra ID: redirect URIs, SAML sign-in, visibility in My Apps, user assignment and implicit grant. Only settings that differ from the current ones are written. The application is selected by its client ID.

#### Where to find

Org \ Applications \ Update Application Registration


[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-collab'></a>

## Collab
<a name='org-collab-check-onedrive-status'></a>

### Check Onedrive Status
#### Check whether a user's OneDrive is active, locked or deleted

#### Description

Looks up the personal OneDrive site of a user and reports whether it is active or archived, whether it is locked, and whether it sits in the tenant recycle bin. Works for users whose account has already been deleted, as their OneDrive may still be in the recycle bin. Nothing is changed.

#### Where to find

Org \ Collab \ Check Onedrive Status

## Common use cases

- Check whether an active user's OneDrive is provisioned and, if so, whether it is locked or archived.
- Check whether a deleted user's OneDrive still exists in the tenant recycle bin, and when it is scheduled to be purged.

## Parameter behaviour

- `UserPrincipalName` accepts the UPN of an already deleted account, not only of active users. This is intentional: a user picker cannot select a deleted account, so the parameter is free text rather than a picker.
- For a deleted user, the recycle bin lookup matches on the deleted site's `SiteOwnerEmail`. A missing value or a prior UPN rename can cause a false "Not found" result.

The runbook is strictly read-only and makes no changes to the tenant.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-collab-list-sharepoint-sitecollection-permission'></a>

### List Sharepoint Sitecollection Permission
#### List the administrators and members of a SharePoint site

#### Description

Shows who has access to a SharePoint Online site collection: the site collection administrators and the members of the Owners, Members and Visitors groups. Each entry shows its type, such as user, Entra ID group, security group or SharePoint group. Nothing is changed.

#### Where to find

Org \ Collab \ List Sharepoint Sitecollection Permission

## Parameter behaviour

- `SiteUrl` must point at a site collection root (for example `https://contoso.sharepoint.com/sites/marketing`), not at a sub-site. A sub-site URL still returns results, but they describe the parent site collection; the runbook logs a warning when this happens.
- The Owners, Members and Visitors groups are resolved via the site's associated-group properties, not by matching localized group names, so the report is accurate regardless of the tenant language. Any of the three groups may be absent (common on Teams-connected sites) and is then reported as "not configured" instead of causing a failure.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-collab-report-sharepoint-tenant-storage-(scheduled)'></a>

### Report Sharepoint Tenant Storage (Scheduled)
#### Monitor SharePoint storage and alert when limits are exceeded

#### Description

Checks the storage of the SharePoint Online tenant on every run: the quota, how much is used, and the site collections that use the most. The full inventory is written to the run output. An alert email is sent only when the free storage drops below the low-storage limit or the licensed but unused storage exceeds the reclaimable limit.

#### Where to find

Org \ Collab \ Report Sharepoint Tenant Storage_Scheduled

## Common use cases

- Scheduled daily health check of the SharePoint Online tenant storage that alerts only when a threshold is breached.
- Spotting a tenant that approaches its storage quota before users are blocked from saving files.
- Spotting a large amount of unused, potentially reclaimable licensed storage.

## Scheduling and output

A daily schedule is recommended. The storage summary and the top site collections are written to the runbook output on every run, regardless of whether a threshold is breached, so the job history stays useful on days without an alert.

## Parameter interactions

- `AlertLowStorageLimitInMB` alerts when the free tenant storage drops below the configured value.
- `AlertUnusedStorageLimitInMB` alerts when the free tenant storage rises above the configured value, an indicator of reclaimable licensed storage. Set it to `0` to disable this check.
- Both checks can fire in the same run only when `AlertLowStorageLimitInMB` is configured higher than `AlertUnusedStorageLimitInMB`; review both values together when tuning the thresholds.
- The alert email is only sent when at least one threshold is breached. A run without a breach completes normally and sends nothing.
- The top site collections list covers SharePoint site collections only. OneDrive for Business sites are excluded because their storage does not count against the tenant storage quota this runbook monitors.

## Limitations

- `Get-PnPTenantSite` does not reliably report the creation date of a site on every tenant or module version; the report shows "Unknown" for such a site.
- Enumerating all site collections can take several minutes in tenants with a large number of sites.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-devices'></a>

## Devices
<a name='org-devices-add-autopilot-device'></a>

### Add Autopilot Device
#### Register a Windows device in Windows Autopilot

#### Description

Registers a Windows device in Windows Autopilot from its serial number and hardware hash, as collected with Get-WindowsAutopilotInfo. Optionally a group tag is set during the import and the runbook waits until the import has finished.

#### Where to find

Org \ Devices \ Add Autopilot Device


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-add-device-via-corporate-identifier'></a>

### Add Device Via Corporate Identifier
#### Register a device in Intune by its corporate identifier

#### Description

Adds a device to Intune's list of corporate identifiers, such as a serial number or IMEI, so it counts as corporate-owned when it enrolls. An existing entry for the same identifier can be overwritten, and a description can be stored with it.

#### Where to find

Org \ Devices \ Add Device Via Corporate Identifier


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-auto-approve-driver-updates-(scheduled)'></a>

### Auto Approve Driver Updates (Scheduled)
#### Approve pending driver updates in Intune driver update policies

#### Description

Approves driver updates that are waiting for review in Intune driver update policies, so drivers roll out without manual approval. The scope can be narrowed to certain policies, driver names, classes, manufacturers or a maximum driver age, and a dry run shows what would be approved. The report of all approvals can be sent by email or provided as a download link.

#### Where to find

Org \ Devices \ Auto Approve Driver Updates_Scheduled

## Common use cases

- Test the filters first: use the `WhatIf` parameter to preview which drivers would be approved.
- Auto-approve all drivers: run without any filter parameter.
- Approve specific manufacturers: use `DriverManufacturer` to target vendors such as "Intel" or "AMD".
- Target specific policies: use `PolicyNames` or `PolicyIds` to scope the run to test policies first.
- Monitor the approvals: configure `EmailTo` to receive a detailed report after each run.

## Parameter interactions

- Without a policy filter, all driver update policies are processed.
- Without a driver filter, all pending drivers of the selected policies are approved.
- `PolicyNames` and `PolicyIds` can be combined; both filters apply independently.
- `WhatIf` simulates the approvals without making changes, which is useful for testing the filters.

## Prerequisites

The driver update endpoints are only available on the Microsoft Graph beta API, which this runbook uses.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-cleanup-autopilot-devices-(scheduled)'></a>

### Cleanup Autopilot Devices (Scheduled)
#### Remove orphaned and never-enrolled Autopilot registrations

#### Description

Cleans up Windows Autopilot registrations: devices whose serial number no longer matches any Intune device (orphaned) and, optionally, devices that never enrolled and are older than a given age. By default it only reports what it would delete; deletion has to be switched on explicitly and can include the matching Entra ID device objects. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Devices \ Cleanup Autopilot Devices_Scheduled

## Deletion is irreversible

- Removing an Autopilot device identity permanently deletes it from Windows Autopilot. There is no soft delete or recycle bin for Autopilot records.
- The physical device cannot re-enter Autopilot until its hardware hash is uploaded again.
- Deleting the Entra device object is likewise permanent; only do so for records that are genuinely dead, meaning the device will never enroll again.

## Recommended first run

1. Run with the delete mode *WhatIf (report only)*, which is the default, and review the output or the emailed CSV.
2. Confirm that the identified devices are genuinely orphaned or never enrolled.
3. Switch to a deletion mode only after the candidate list has been reviewed.

## Parameter interactions

- `DeleteMode` defaults to *WhatIf (report only)*; no deletions occur in that mode.
- *Delete Autopilot device* removes only the Autopilot identity. *Delete Autopilot and Entra device* additionally removes the matching Entra device object, which would otherwise be left behind as a stale record once the Autopilot identity is gone. The second mode requires the `Device.ReadWrite.All` permission.
- `CleanupOrphanedDevices` and `CleanupNeverEnrolledDevices` are independent; either or both can be enabled. `NeverEnrolledAgeDays` applies only to the never-enrolled check.
- `GroupTagFilter`, `ManufacturerFilter` and `ModelFilter` are optional; leave a filter empty to evaluate all values for that dimension. When more than one filter is set, they are combined with AND, so a device must match every populated filter to remain in scope. `GroupTagFilter` matches the group tag exactly (case-insensitive); `ManufacturerFilter` and `ModelFilter` match as case-insensitive substrings, so "Dell" matches "Dell Inc." and "Surface" matches "Surface Laptop 3".
- `ExcludeSerialNumbers` is applied after the AND filters as an exclusion: a device whose serial number is in the list (exact, case-insensitive) is removed from scope regardless of the other filters. Leave it empty to exclude nothing.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-create-endpoint-analytics-baseline'></a>

### Create Endpoint Analytics Baseline
#### Create an Endpoint Analytics baseline with a naming schema

#### Description

Creates a new Endpoint Analytics baseline in Intune, named after a schema with placeholders such as the current date, so baselines can be created regularly and compared over time. Intune allows at most 20 baselines; the oldest can be removed automatically when the limit is reached.

#### Where to find

Org \ Devices \ Create Endpoint Analytics Baseline


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-dedup-device-names-(scheduled)'></a>

### Dedup Device Names (Scheduled)
#### Rename Intune devices that share a display name

#### Description

Finds Intune devices that share the same display name and renames the most recently enrolled one of each set. The generated name is a fixed prefix followed by random digits up to the chosen total length. The new name is also written to the matching Windows Autopilot record. An OS filter limits which platforms are checked.

#### Where to find

Org \ Devices \ Dedup Device Names_Scheduled

## Common use cases

- Schedule the runbook weekly to resolve duplicate device names that arise from re-enrollment, OS reimaging or cloning workflows automatically.
- The Autopilot sync path is idempotent, so unique devices are normalized in Autopilot as well, also on the first run.

## Parameter interactions

- `NameLength` must be strictly greater than the number of characters in `NamePrefix`. The difference determines how many random digits are appended; for example, `NamePrefix` "CORP" with `NameLength` 8 produces names like "CORP4271".
- The runbook validates this constraint at startup and fails fast when it is violated.

## Behaviour

Autopilot display name changes made via `updateDeviceProperties` take effect at the next device sync and may not be reflected in the portal immediately.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-delete-stale-devices-(scheduled)'></a>

### Delete Stale Devices (Scheduled)
#### Delete Intune devices that have been inactive for too long

#### Description

Finds Intune devices that have not checked in for a given number of days, filtered by platform and optionally by the group membership of their primary user. By default it only lists what it would delete; deletion has to be switched on explicitly. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Devices \ Delete Stale Devices_Scheduled

## Common use cases

This runbook deletes managed devices from Intune based on inactivity, so use it with care.

- Regular cleanup of stale device records in Intune
- Simulation runs (report-only mode) before enabling the actual deletion
- Scheduled lifecycle management with an audit trail via the email report

## User scope filtering

The runbook supports optional user scope filtering to include or exclude devices based on the group membership of their primary user. This acts as an additional safety net when deletion is enabled.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-get-bitlocker-recovery-key'></a>

### Get Bitlocker Recovery Key
#### Look up a BitLocker recovery key by its key ID

#### Description

Finds the BitLocker recovery key that belongs to the key ID shown on a device's recovery screen and returns the key together with the device it belongs to. Use it when a user is locked out at the BitLocker prompt.

#### Where to find

Org \ Devices \ Get Bitlocker Recovery Key


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-list-mobile-devices'></a>

### List Mobile Devices
#### List managed mobile devices with inventory and network details

#### Description

Lists all Intune managed Android, iOS and iPadOS devices with their inventory: IMEI, serial number, phone number, carrier, ownership, compliance and enrollment. Optionally the last reported IP address and subnet, ICCID, eSIM identifier, cellular technology, UDID, battery health and Shared iPad state are added. That shows in which networks the devices were last active. The list can be limited by platform, a device group or a group of the primary users. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Devices \ List Mobile Devices

## Common use cases

- Inventory of all mobile devices including IMEI, serial number, phone number and carrier
- Identifying in which (Wi-Fi) networks mobile devices were last active, for example handheld scanners across warehouse locations
- Reviewing the compliance, supervision and encryption state of the mobile fleet
- SIM/eSIM inventory via ICCID and eSIM identifier
- Handing the full mobile inventory to asset management as an Excel workbook or CSV file

## Output columns

The runbook prints a summary block (device counts per platform, compliance state and ownership, applied filters and - with network details enabled - the number of devices without a reported IP address) followed by up to three tables. The same data can optionally be delivered as an email report and/or as a download link, see [Report delivery](#report-delivery).

### Inventory (always shown)

| Column | Source and meaning |
| --- | --- |
| DeviceName | Device name as reported by Intune |
| User | User principal name of the primary user |
| OS / OSVersion | Operating system (Android, iOS, iPadOS) and version |
| Manufacturer / Model | Hardware manufacturer and model |
| SerialNumber | Hardware serial number |
| IMEI | International Mobile Equipment Identity of the device |
| PhoneNumber | Phone number of the SIM - only present when `IncludePhoneNumber` is enabled, otherwise the column is omitted entirely |
| Carrier | Subscriber carrier of the SIM |
| Ownership | `company` or `personal` |
| Compliance | Intune compliance state |
| LastSync | Timestamp of the last successful Intune check-in |

### Security and enrollment (always shown)

| Column | Source and meaning |
| --- | --- |
| Supervised | iOS/iPadOS supervised mode |
| Encrypted | Device encryption state |
| Jailbroken | Whether the device is jailbroken or rooted |
| ThreatState | Threat state reported by a Mobile Threat Defense partner (only meaningful when an MTD partner is connected) |
| PatchLevel | Android security patch level (empty on iOS/iPadOS) |
| EnrollmentType / EnrollmentProfile | How the device was enrolled and the enrollment profile used |
| Category | Intune device category |
| FreeGB / TotalGB | Free and total storage (empty when the device reports no usable storage inventory, common for Android Enterprise work profiles) |
| Enrolled | Enrollment date |

### Network and SIM (only with `IncludeNetworkDetails` enabled - off by default)

| Column | Source and meaning |
| --- | --- |
| IPv4 / Subnet | Last IP address and subnet reported by the device - the closest indicator for the (Wi-Fi) network the device was last active in |
| WiFiMAC | Wi-Fi MAC address of the device |
| ICCID | Unique identification number of the SIM card |
| ESIM | eSIM identifier, when an eSIM is provisioned |
| Cellular | Cellular technology of the device |
| UDID | Unique device identifier (iOS/iPadOS) |
| BatteryHealth | Battery health percentage, where reported |
| Shared | Whether the device is a Shared iPad |
| LastSync | Timestamp of the last successful Intune check-in - tells how old the IP information is |

This table is sorted by subnet, so devices group visually by the network they were last seen in.

## Data freshness and limitations

All values describe the state of the last successful Intune device check-in, not necessarily the current state - always interpret them together with the LastSync column. Intune does not report the Wi-Fi SSID of a device; the last IP address and subnet are the closest network indicator. Note that the reported IP address can also stem from a cellular connection when the device last checked in over mobile data. Intune partially masks the phone number of personally owned devices regardless of the `IncludePhoneNumber` setting.

## Performance considerations

The network/SIM details are disabled by default and should be enabled with care on large tenants or with many mobile devices: Microsoft Graph returns these values only on a single-device request, not in the device list response. The runbook always sends these requests through the Graph batch endpoint in chunks of up to 20, but the runtime still grows linearly with the number of devices - thousands of mobile devices mean correspondingly long runs and an increased risk of Graph throttling (throttled requests are retried automatically with the wait time reported by Graph). On large environments, combine `IncludeNetworkDetails` with the group scope filters.

## Scope filtering

The scope can be limited to the members of an Entra device group (`IncludeDeviceGroup`) and/or to devices whose primary user is a member of a user group (`IncludeUserGroup`). When both filters are set, a device must match both. Transitive memberships are resolved, so members of nested groups are included.

## Report delivery

By default the runbook only prints the tables to the job output. Two optional delivery channels are available and can be combined:

- **Email report** (`EmailTo`): sends a summary email with the complete inventory attached as CSV and/or Excel workbook (`ReportFileFormat`, default `XLSX only`). Requires the `RJReport.EmailSender` setting; the email branding is taken from the `RJReport.Branding.*` settings as in the other report runbooks. When the CSV attachment exceeds the email size limit and `CSV & XLSX` is selected, the email falls back to the Excel workbook alone.
- **Download link** (`CreateDownloadLink`): uploads the report file(s) to the storage account configured in the `RJReport.StorageAccount.*` settings (container `list-mobile-devices` by default) and prints time-limited SAS download links in the job output. Suitable when the inventory is too large for an email attachment or should be handed to asset management directly.

The report files contain all columns of the tables above, including the `DeviceId`. The `PhoneNumber` and the network/SIM columns are only part of the files when the corresponding options are enabled. Non-compliant devices are highlighted in the Excel workbook. No files are created when no mobile device matches the selected platforms and filters.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-notify-users-about-low-diskspace-(scheduled)'></a>

### Notify Users About Low Diskspace (Scheduled)
#### Email users whose devices are running out of disk space

#### Description

Finds Windows and macOS devices in Intune whose free disk space is below a limit, either a fixed number of gigabytes or a percentage of the disk. Each primary user gets one email listing their affected devices with practical steps to free up space. Devices are rated Warning or Critical. The run can be limited to critical devices, to devices with a fresh inventory, to a device group and to certain users. A simulation mode only lists who would be notified, and an override recipient redirects all emails to a test mailbox.

#### Where to find

Org \ Devices \ Notify Users About Low Diskspace_Scheduled

## Common use cases

- Recurring reminders to users whose devices are about to run out of disk space, before updates and app installations start to fail
- Two-stage campaigns: report all devices below the threshold to administrators with **Report Devices Low Diskspace**, and notify only the users with critical devices via `NotifyOnSeverity`
- Staged rollouts per department or pilot group via the user and device group scope options
- Excluding service or shared accounts via the exclude group

## Data freshness and limitations

The free and total disk space values are read from the Intune hardware inventory of each managed device. This inventory is refreshed with the regular device check-in, so the runbook sees the state of the last successful inventory rather than the current state of the device. To avoid notifying users based on outdated numbers, devices whose last Intune sync is older than `MaxInventoryAgeDays` (default 14 days) are skipped and counted separately. Devices without a last sync date are treated as outdated as well. Set the parameter to `0` to disable this check.

The companion **Report Devices Low Diskspace** runbook deliberately does not apply this filter, so it lists devices with a stale inventory as well and can show more devices than are notified here. Both runbooks apply the same threshold and the same Critical/Warning rating, so a device is rated identically in both; the difference in the device count is exactly the devices skipped for an outdated inventory, which this runbook reports as a separate number in its output.

Devices that report a total disk size of zero bytes have no usable storage inventory, for example devices that have not completed an inventory yet. Such devices are excluded from the evaluation instead of being treated as "0 GB free", and their number is shown in the console output.

Only Windows and macOS devices are evaluated. The storage inventory of mobile devices is less reliable, the default threshold in gigabytes is dimensioned for desktop disks, and the cleanup guidance in the email is specific to desktop operating systems.

This runbook is the user-facing counterpart of **Report Devices Low Diskspace**. Both use the same threshold settings and the same Critical/Warning rating. Use the report for the administrative overview, including devices without a primary user, and this runbook to ask the affected users to free up space themselves.

## Threshold and severity

`ThresholdType` selects whether a device is considered based on a fixed amount of free space (`FreeSpaceThresholdGB`) or based on the share of free space relative to its disk size (`FreeSpacePercentThreshold`). Only the field belonging to the selected type is shown in the portal.

Every device below the threshold is rated: devices below half of the configured threshold are marked as **Critical**, all other devices below the threshold as **Warning**. The rating is shown per device in the email, and with the built-in English and German templates the subject line and introduction switch to an urgent wording as soon as one of the user's devices is Critical. The `Custom` template has a single subject and a single introduction, both taken verbatim from the runbook customization, so a Critical and a Warning notification read identically there - phrase the custom text so it works for both.

`NotifyOnSeverity` controls which devices trigger a notification. By default every device below the threshold does (*Warning and Critical*). With *Critical only*, users are contacted only when a device is below half of the threshold. This allows a two-stage approach: report all devices below the threshold to administrators via the report runbook, and notify only the users whose devices are critical.

## Notification behaviour

The runbook sends **one email per primary user** that lists all affected devices of that user with operating system, model, free and total disk space, rating and the date of the last inventory. The email contains practical cleanup steps for the platforms of the listed devices: the Windows section is included for Windows devices, the macOS section for macOS devices, and both when the user has affected devices of both kinds.

Recipients are resolved via Microsoft Graph: the primary user of a device is looked up by the Entra object id that Intune reports in `userId`, so guest accounts and users whose current UPN differs from the address recorded at enrollment resolve correctly; devices without a `userId` fall back to a lookup by user principal name. The email is then sent to the user's `mail` attribute, with the user principal name as fallback when no mail attribute is set. Disabled accounts and users that cannot be resolved are skipped and listed in the console output. Devices without a primary user cannot be notified; they are listed in the console output for central follow-up (the report runbook covers them as well).

`SimulationMode` lists the affected users, their devices and the intended recipients in the console output without sending any email. Use it to validate thresholds and scope filters before the first productive run.

`OverrideEmailRecipient` redirects **ALL** notifications to the given address (comma-separated for multiple recipients) instead of the end users. A warning is logged on every run while the override is active, and each redirected email states the affected user in the subject and body. Use this for testing the email content or for routing everything to a shared mailbox.

Keep in mind that the override mailbox then receives one email per affected user, all sent within a few seconds and with urgent subject lines. Mail filters may classify such a burst of similar emails as bulk or spam and move it to the junk folder or the quarantine, in particular when the override mailbox belongs to another tenant. The runbook only sees that Microsoft Graph accepted each email and reports it as sent; what the receiving side does afterwards is not visible in the job output. If the emails do not arrive, check the junk folder and the quarantine of the override mailbox and run a message trace for the sender address. A mailbox in the same tenant is the more reliable test target.

## Scoping options

- **User scope:** With `UseUserScope` enabled, `IncludeUserGroup` limits the notifications to users who are members of that group, and `ExcludeUserGroup` suppresses notifications for members of that group. Both use the transitive membership, so nested groups are resolved, and both are read once at the start of the run.
- **Device scope:** `IncludeDeviceGroup` limits the evaluation to devices that are (transitive) members of the given Entra device group. Devices are matched via their Entra device ID.

When a user scope and a device scope are configured, a device has to match both. A failing group lookup stops the runbook with an error instead of silently notifying every user.

## Setup regarding email sending

The notification emails are sent to the affected users; the sender address is taken from the `RJReport.EmailSender` tenant setting and is required.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The notification email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

### Service Desk contact information

The optional `RJReport.ServiceDesk_DisplayName`, `RJReport.ServiceDesk_EMail`, `RJReport.ServiceDesk_Phone` and `RJReport.ServiceDesk_PortalUrl` tenant settings add a contact block to the end of every email. `ServiceDeskTicketUrl` can additionally link to a ticket.

## Mail Template Language Selection

This runbook supports three email template options:

1. **EN (English - Default)**: Uses the built-in English template
2. **DE (German)**: Uses the built-in German template
3. **Custom**: Uses a custom template from Runbook Customizations

### Using Custom Mail Templates

To use a custom mail template (e.g., in Dutch, Spanish, or any other language), you need to configure the template text in the Runbook Customizations. If any custom template parameter is missing, the runbook will automatically fall back to the English template.

The custom template consists of a subject, a text before the device list and a text after the device list. The built-in cleanup steps, the "Why is this important" section and the "Questions" section are **not** rendered with the custom template, so the text after the device list should contain your own cleanup guidance.

#### Example: Custom Template

```json
{
    "Runbooks": {
        "rjgit-org_devices_notify-users-about-low-diskspace_scheduled": {
            "Parameters": {
                "CustomMailTemplateSubject": {
                    "Default": "This is a custom subject - Action Required: Low Disk Space"
                },
                "CustomMailTemplateBeforeDeviceDetails": {
                    "Default": "**This is above the Device Details.** \n\nDear user, the following devices are running out of disk space:"
                },
                "CustomMailTemplateAfterDeviceDetails": {
                    "Default": "**This is below the Device Details.** \n\n## What you can do now\n\n1. Empty the Recycle Bin\n2. ..."
                }
            }
        }
    }
}
```

**Important Notes:**
- Use `\n` for line breaks in the JSON configuration
- Markdown formatting (##, ###, **, -) is supported in the template text
- All three custom template parameters (Subject, BeforeDeviceDetails, AfterDeviceDetails) should be configured
- If any parameter is missing, the runbook automatically falls back to the English (EN) template
- When using the custom template, select "Custom - Use Template from Runbook Customizations" in the Mail Template dropdown
- The device list labels are rendered in English for the custom template



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-notify-users-about-stale-devices-(scheduled)'></a>

### Notify Users About Stale Devices (Scheduled)
#### Email users about devices they have not used for a while

#### Description

Finds Intune devices that have not been active for a given number of days. Each primary user gets an email listing their stale devices and what to do about them. Users can be included or excluded by group. Emails can be redirected: all of them to an override address for tests, or those of accounts matching a name pattern to a dedicated recipient. Stale devices without a primary user can be collected into one combined email.

#### Where to find

Org \ Devices \ Notify Users About Stale Devices_Scheduled

## Common use cases

- Automated user reminders about inactive devices to encourage regular device check-ins
- Proactive device lifecycle management by alerting users before devices are retired
- Security and compliance by ensuring users are aware of all devices registered to them
- Staged notifications via the `MaxDays` parameter, for example a first reminder at 30 days and a final notice at 60 days
- User scope filtering to target specific departments or to exclude service accounts
- Central handling of devices without a primary user or owned by Device Enrollment Manager accounts (for example `DEM-*`) via dedicated recipients

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

### Service Desk contact information

The optional `RJReport.ServiceDesk_DisplayName`, `RJReport.ServiceDesk_EMail`, `RJReport.ServiceDesk_Phone` and `RJReport.ServiceDesk_PortalUrl` tenant settings add a contact block to the end of every notification email. `ServiceDeskTicketUrl` can additionally link to a ticket.

## Mail Template Language Selection

This runbook supports three email template options:

1. **EN (English - Default)**: Uses the built-in English template
2. **DE (German)**: Uses the built-in German template
3. **Custom**: Uses a custom template from Runbook Customizations

### Using Custom Mail Templates

To use a custom mail template (e.g., in Dutch, Spanish, or any other language), you need to configure the template text in the Runbook Customizations. If any custom template parameter is missing, the runbook will automatically fall back to the English template.

#### Example: Custom Template

```json
{
    "Runbooks": {
        "rjgit-org_devices_notify-users-about-stale-devices_scheduled": {
            "Parameters": {
                "CustomMailTemplateSubject": {
                    "Default": "This is a custom subject - Action Required: Inactive Devices"
                },
                "CustomMailTemplateBeforeDeviceDetails": {
                    "Default": "**This is above the Device Details.** \n\nDear user ..."
                },
                "CustomMailTemplateAfterDeviceDetails": {
                    "Default": "**This is below the Device Details.** \n\n## What you should do..."
                }
            }
        }
    }
}
```

**Important Notes:**
- Use `\n` for line breaks in the JSON configuration
- Markdown formatting (##, ###, **, -) is supported in the template text
- All three custom template parameters (Subject, BeforeDeviceDetails, AfterDeviceDetails) should be configured
- If any parameter is missing, the runbook automatically falls back to the English (EN) template
- When using the custom template, select "Custom - Use Template from Runbook Customizations" in the Mail Template dropdown

## Email Routing

The runbook knows three independent routing targets, checked in this order of precedence:

1. **Global override (testing):** A filled `OverrideEmailRecipient` redirects **ALL** emails - user notifications, pattern-routed notifications and the combined email for devices without a primary user - to that address. No end user receives an email. Use this for testing, piloting, or routing everything to a shared mailbox or ticket system. A warning is logged on every run while the override is active.
2. **Pattern-matched users:** When `OverrideUserNamePattern` is set, notifications of users whose UPN matches the pattern are sent to `UserNamePatternEmailRecipient` instead of the user. All other users receive their notification directly. Typical use: Device Enrollment Manager or kiosk accounts (`DEM-*`, `KIOSK-*`) whose mailboxes nobody reads.
3. **Devices without a primary user:** When `SendNoPrimaryUserDevicesToOverride` is enabled, stale devices without a primary user are collected into **one** combined email to `NoPrimaryUserEmailRecipient`. Otherwise these devices are skipped. This setting never changes how user notifications are routed.

Incomplete configurations stop the runbook with an error instead of silently mailing end users:

- `SendNoPrimaryUserDevicesToOverride` enabled without `NoPrimaryUserEmailRecipient` (and without a global override) - error.
- `OverrideUserNamePattern` set without `UserNamePatternEmailRecipient` (and without a global override) - error.
- A recipient set without its feature (`NoPrimaryUserEmailRecipient` without the toggle, `UserNamePatternEmailRecipient` without a pattern) - warning, the recipient is ignored.

While the global override is active, the dedicated recipients do not need to be set - everything goes to the override recipient anyway.

### User Name Pattern

`OverrideUserNamePattern` accepts one or more wildcard patterns (comma-separated) matched against the primary user's UPN, e.g. `DEM-*` for Device Enrollment Manager accounts or `DEM-*,KIOSK-*` for multiple patterns. Matching is case-insensitive and uses PowerShell wildcard syntax (`*`, `?`). When the pattern routing is active, the runbook logs a warning stating which pattern is redirected to which recipient.

**Important Notes:**

- All recipient parameters accept multiple comma-separated addresses
- Devices without a primary user bypass the user scope filtering (they have no user to match against groups)
- Pattern-matched users are still subject to user scope filtering first; users excluded by scope produce no notification at all
- The combined email for devices without a primary user uses an administrative wording (no end-user action steps), independent of custom templates
- Redirected notifications state the affected user in the email subject and body



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-outphase-devices'></a>

### Outphase Devices
#### Wipe and clean up several devices at once

#### Description

Takes several devices out of service in one go, given as a list of device IDs or serial numbers. You choose whether the devices are wiped or only deleted from Intune, and whether their Autopilot registration is removed. Their Entra ID objects can be deleted, disabled or kept. Optionally the devices are tagged in Microsoft Defender for Endpoint so rules that use the tag can exclude them from automated remediation. A wipe removes all data and cannot be undone.

#### Where to find

Org \ Devices \ Outphase Devices

## Microsoft Defender for Endpoint exclusion tag

Microsoft Defender for Endpoint has a native **Exclusion state** (shown in the Device Inventory filter as *Excluded* / *Not Excluded*). This state can only be set through the Defender portal — there is **no API** to set a device's native exclusion state programmatically.

Because the native exclusion state cannot be automated, this runbook instead applies a custom device tag (default `ExcludeFromRemediation`) when *Exclude devices from Defender for Endpoint* is enabled. Each device in the list is looked up by its Entra ID device ID and tagged via `POST /api/machines/{id}/tags`, providing a marker that can be used to filter and target excluded devices.

### One-time setup: make the tag filterable

The portal's **Tags** filter only lists tags that were created through the portal. A tag set purely via the API is attached to the device and visible on the device page, but it does **not** appear in the Tags filter on its own.

To make the exclusion tag visible and usable for filtering in the [Defender Device Inventory](https://security.microsoft.com/machines), one client must be tagged manually once through the portal (select a device > **Manage tags** > "Create new tag", using the exact same tag value). After this one-time step the tag becomes a known, filterable tag, and this runbook can apply it to devices at scale.

> **Note:** This tag is only a label — it does not set the device's native Exclusion state and has no remediation effect on its own. It takes effect only if a Defender device group or automation rule is explicitly configured to match this tag value. Such rules match the tag value directly, independently of the portal **Tags** filter, so the one-time manual step only affects whether the tag is selectable for filtering in the portal UI.

Devices supplied by serial number that are not found in Intune have no Entra ID device ID and are therefore not tagged in Defender.

See [Create and manage device tags](https://learn.microsoft.com/defender-endpoint/machine-tags#create-tags) for details.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-rename-devices-by-group-tag-(scheduled)'></a>

### Rename Devices By Group Tag (Scheduled)
#### Name Autopilot devices after their group tag and serial number

#### Description

Builds the computer name of every Windows Autopilot device from a template of group tag and serial number, for example DEHAM-5CD1234ABC. The name goes into the Autopilot record for the next Autopilot deployment. Enrolled devices whose Intune name differs are renamed through Intune and take the new name after a restart. Hybrid joined and personal devices are only reported. A dry run lists all changes without writing anything.

#### Where to find

Org \ Devices \ Rename Devices By Group Tag_Scheduled

## Common use cases

- Replace Autopilot deployment profiles that only exist to give one location its own device name template. One deployment profile without a location prefix is enough: the location comes from the group tag of each Autopilot device, and this runbook writes the resulting name into the Autopilot record before the device is deployed.
- Give devices that were enrolled before the naming scheme existed, or that were registered with a different group tag, the name that matches their current group tag.
- Schedule the runbook daily so that newly registered Autopilot devices carry the right name before their first deployment and group tag changes are picked up automatically.

## Name template and placeholders

The name is built from `NameTemplate`. Two placeholders are replaced, case-insensitive:

| Placeholder | Replaced by |
|---|---|
| `%GROUPTAG%` (or `%ORDERID%`) | the Autopilot group tag of the device |
| `%SERIAL%` | the serial number of the Autopilot record |

Every other character of the template is used as typed, for example `%GROUPTAG%-%SERIAL%` or `PC-%GROUPTAG%%SERIAL%`. Each placeholder must appear exactly once: without the serial number all devices of a location would share one name, and without the group tag there is nothing to derive the location from. A random part is deliberately not supported, because the runbook compares the current name with the expected name on every run and a random part would rename every device on every run.

Group tag and serial number are cleaned before they are inserted: characters other than letters, digits and hyphens are removed, so a group tag `DE_HAM 01` becomes `DEHAM01` and a serial number `VMware-42 1a 2b` becomes `VMware-421a2b`. The finished name must follow the Windows computer name rules: 15 characters at most, letters, digits and hyphens only, starting and ending with a letter or digit, not digits only. A device whose name would break these rules is reported and skipped.

When the assembled name is longer than 15 characters, only the serial number is shortened; the template text and the group tag stay intact. `SerialTruncation` decides which end of the serial number survives:

| Serial number | `%GROUPTAG%-%SERIAL%` with tag `DEHAM` | Keep the end | Keep the start |
|---|---|---|---|
| `7ABCD12` (7 characters) | fits | `DEHAM-7ABCD12` | `DEHAM-7ABCD12` |
| `5CD1234ABC` (10 characters) | 16 characters, one too many | `DEHAM-CD1234ABC` | `DEHAM-5CD1234AB` |
| `012345678901` (12 characters) | 18 characters | `DEHAM-345678901` | `DEHAM-012345678` |

The `%SERIAL%` macro of an Autopilot deployment profile truncates the serial number from the beginning as well, so the default *Keep the end of the serial number* reproduces the names that devices deployed with such a profile already have. Choose *Keep the start of the serial number* only when an existing naming scheme requires it.

## Which devices are changed and which are skipped

Only Autopilot devices with a group tag are considered; `GroupTagFilter` narrows them further (comma-separated list, exact match, `*` as wildcard, for example `DE*` for all German locations). For each device in scope the runbook compares the expected name with two places:

- The display name of the Autopilot record. It is updated whenever it differs, also for devices that are not enrolled yet and independent of *Rename enrolled devices*. Autopilot uses this name as the computer name at the next deployment of an Entra joined device. For a device that is already running, the field has no effect until the device is reset, so the Autopilot list may show the target name while Intune still shows the old one.
- The device name in Intune, if the device is enrolled. When it differs and *Rename enrolled devices* is on, the runbook queues the Intune rename action. The device picks the new name up at its next check-in and applies it after a restart.

The result table in the Output Data tab lists every device in scope with the action taken for Intune and for Autopilot:

| Value | Meaning |
|---|---|
| `AlreadyNamed` | The name already matches; nothing to do. |
| `RenameQueued` / `Updated` | The Intune rename was queued / the Autopilot record was updated. In a dry run the values read `WouldRenameQueue` / `WouldUpdate`. |
| `RenamePending` | An Intune rename is still pending or active from an earlier run; it is not queued again. |
| `NotEnrolled` | The device has no Intune record; only the Autopilot record is maintained. |
| `RenameDisabled` | *Rename enrolled devices* is off; the Intune name is left alone. |
| `NotCompanyOwned` | Intune only renames corporate-owned devices. |
| `NotEntraJoined` | Hybrid joined or Entra registered devices cannot be renamed through Intune; hybrid joined devices get their name from the domain join profile. |
| `NameInUseByOtherDevice` | Another Intune device already carries the expected name; renaming would create a duplicate. This usually resolves itself once the other device has been renamed. |
| `RenameFailed` / `UpdateFailed` | The Graph call failed; the error is in the job log. |
| `MaxChangesReached` | *Maximum changes per run* was reached before this device; it is processed in a later run. |

The `Reason` column names the problem when no valid name could be built: `GroupTagUnusable` or `SerialUnusable` (nothing left after cleaning), `NameTooLong` (template text and group tag alone already fill 15 characters), `NameInvalid` (the finished name breaks the computer name rules, for example digits only or a hyphen at the end after truncation) and `NameCollision` (two or more Autopilot records would get the same name, for example placeholder serial numbers such as `Default string` or a collision after truncation). None of these devices is changed.

## Interplay with Dedup Device Names

**Dedup Device Names (Scheduled)** copies the current Intune name of every device with a unique name into its Autopilot record. When both runbooks are scheduled for Windows devices, the Autopilot display name of a device that this runbook cannot rename (hybrid joined, personal, pending rename, name collision, rename disabled) is written back and forth between the two. Run **Dedup Device Names** with the operating system filter *macOS only* or *Other* once this runbook manages the Windows names, or accept the alternating field for those devices. Devices renamed by this runbook never produce duplicates, because a name collision is detected before anything is written.

## Recommended first run

1. Run with *Dry run* on (the default) and *Group tag filter* set to a single location, for example `DEHAM`. Review the table in the Output Data tab: the expected names, the truncation of long serial numbers and the skip reasons.
2. Widen the filter, for example to `DE*`, still as a dry run, and check that devices deployed with the previous profile templates show `AlreadyNamed`.
3. Switch *Dry run* off with *Maximum changes per run* set to a manageable number such as 50, so that renames of already enrolled devices arrive in waves. Renamed devices need a restart to complete the rename.
4. Remove the limit and the filter and schedule the runbook, for example daily.

## Behaviour

- The Intune rename action does not restart the device. The new name is applied at the next check-in and becomes effective after the next restart; until then Intune still shows the old name and the runbook reports the rename as pending.
- The Autopilot device name applies to Entra joined deployments only. Hybrid joined devices are named by the domain join profile, and Autopilot device preparation does not use Autopilot device identities at all.
- A rename that failed on the device is queued again on the next run.
- Autopilot display name changes made via `updateDeviceProperties` take effect at the next device sync and may not be reflected in the portal immediately.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-report-devices-low-diskspace-(scheduled)'></a>

### Report Devices Low Diskspace (Scheduled)
#### Report devices that are running out of disk space

#### Description

Lists Intune devices whose free disk space is below a limit, either a fixed number of gigabytes or a percentage of the disk. Each device is rated Warning or Critical depending on how far below it is. The list can be narrowed by platform, manufacturer and model. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Devices \ Report Devices Low Diskspace_Scheduled

## Common use cases

- Recurring disk space monitoring across the managed device fleet
- Finding devices that are likely to fail feature updates or app deployments because of insufficient free space
- Preparing targeted user communication or cleanup campaigns, for example with **Notify Users About Low Diskspace**
- Checking a specific hardware generation via the manufacturer and model filters

## Data freshness and limitations

The free and total disk space values are read from the Intune hardware inventory of each managed device. This inventory is refreshed with the regular device check-in, so the report describes the state of the last successful inventory rather than the current state of the device. Use the **Last Sync** column of the report to judge how up to date an individual row is.

Devices that report a total disk size of zero bytes have no usable storage inventory. This is common for Android Enterprise work profiles and also happens on devices that have not completed an inventory yet. Such devices are excluded from the evaluation instead of being reported as "0 GB free", and their number is shown in the console output and in the email summary.

This report deliberately lists devices regardless of how old their inventory is, so that a device which stopped checking in still shows up. Its user-facing counterpart **Notify Users About Low Diskspace** does the opposite: it skips devices whose last Intune sync is older than its `MaxInventoryAgeDays` setting, so that nobody is asked to free up space based on outdated numbers. Both runbooks apply the same threshold and the same Critical/Warning rating, so a device is rated identically in both — but this report can list more devices than the notification runbook writes to. The difference is exactly the devices with a stale inventory, and the notification runbook reports their number in its own output.

Windows and macOS are included by default, iOS/iPadOS and Android are not. The default threshold of 20 GB is dimensioned for desktop disks and would report a large number of perfectly healthy mobile devices. When you enable the mobile platforms, the percentage based threshold (`ThresholdType` = *Free space below a percentage of the disk size*) usually gives more meaningful results.

## Threshold and severity

`ThresholdType` selects whether a device is reported based on a fixed amount of free space (`FreeSpaceThresholdGB`) or based on the share of free space relative to its disk size (`FreeSpacePercentThreshold`). Only the field belonging to the selected type is shown in the portal.

Every reported device is rated: devices below half of the configured threshold are marked as **Critical**, all other reported devices as **Warning**. In the Excel workbook these ratings are highlighted in red and yellow.

## Report delivery

Report files are only generated when a delivery method is used, that is when a recipient (`EmailTo`) is provided and/or `CreateDownloadLink` is enabled. Without either, the result is read directly in the RealmJoin portal output. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-report-devices-without-primary-user-(scheduled)'></a>

### Report Devices Without Primary User (Scheduled)
#### Report Intune devices without a primary user

#### Description

Lists all Intune managed devices that have no primary user, with object ID, device ID, name, operating system and last sync, so shared or orphaned devices can be reviewed. The list can be limited by platform. Nothing is changed. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Devices \ Report Devices Without Primary User_Scheduled

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-report-primary-user-mismatch-(scheduled)'></a>

### Report Primary User Mismatch (Scheduled)
#### Compare primary users between Intune and RealmJoin

#### Description

Compares, for Windows devices, the primary user recorded in Intune with the one recorded in RealmJoin and lists every device where they differ. Whether mismatches, devices missing on one side and deleted primary users are listed is set in the runbook customization. Only devices that synced with Intune recently are considered. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Devices \ Report Primary User Mismatch_Scheduled

## Result without mismatches

No email is sent when the two data sources are in sync. A run without mismatches completes normally and is not an error.

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings).

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## Setup regarding RealmJoin API credentials

This runbook queries the RealmJoin customer API and requires a dedicated credential stored in the Azure Automation Account.

**Step-by-step setup:**

1. **Get API credentials** — If you do not yet have RealmJoin API credentials, request them at support@realmjoin.com
2. **Open the Automation Account** — In the Azure portal, navigate to the Automation Account used for runbooks
3. **Go to Shared Resources > Credentials** — In the left menu under *Shared Resources*, click *Credentials*
4. **Add a new credential** — Click *Add a credential*
5. **Name it exactly `RJAPI`** — The runbook looks up this name; any deviation will cause the credential lookup to fail
6. **Enter the RealmJoin API username and password** — Use the credentials from step 1
7. **Save** — Click *Create* and re-run the runbook



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-report-stale-devices-(scheduled)'></a>

### Report Stale Devices (Scheduled)
#### Report devices that have been inactive for too long

#### Description

Lists Intune devices that have not checked in for a given number of days, optionally within a maximum age. The list can be filtered by platform and by the group membership of the primary user. Nothing is changed. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Devices \ Report Stale Devices_Scheduled

## Common use cases

- Regular device inventory audits and compliance reporting
- Identifying devices for retirement or decommissioning
- Security reviews to find potentially lost devices
- Monitoring device health across the organization
- Staged reporting via the `MaxDays` parameter, for example 30 to 60 days and 60 to 90 days
- User scope filtering to focus on specific departments or to exclude service accounts

## User scope filtering

The runbook supports optional user scope filtering to include or exclude devices based on the group membership of their primary user.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-report-users-with-more-than-5-devices-(scheduled)'></a>

### Report Users With More Than 5-Devices (Scheduled)
#### Report users with more than five registered devices

#### Description

Finds users who have more than five devices registered in Entra ID. The report has a summary and a detailed list of their devices, including whether each device is managed by Intune and compliant. Useful to spot leftover registrations before device limits are hit. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Devices \ Report Users With More Than 5-Devices_Scheduled

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-report-windows-devices-without-autopilot-(scheduled)'></a>

### Report Windows Devices Without Autopilot (Scheduled)
#### Report Windows devices in Entra ID without an Autopilot record

#### Description

Lists Windows device objects in Entra ID that no Windows Autopilot registration refers to. Such orphaned objects are usually left over from devices that were reset, re-imaged or replaced without cleanup, so the list shows what can be reviewed and deleted. Nothing is changed. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Devices \ Report Windows Devices Without Autopilot_Scheduled

## Reporting orphaned Windows devices

This runbook lists every Windows device object in Entra ID and matches it against the Windows Autopilot device identities in Intune. Devices that have no associated Autopilot object (matched via the Autopilot object's `azureActiveDirectoryDeviceId`) are reported as clean-up candidates.

Two Yes/No toggles control the output:

- **Send the report via email?** — when enabled, the recipient address field (`EmailTo`) is shown and the report is sent via email with the CSV attached.
- **Create a file download link?** — when enabled, the CSV is uploaded to an Azure Storage Account and a time-limited download link is returned.

Both can be combined or used independently. If both are disabled, the report is only printed to the runbook output.

## Setup regarding the storage account

The CSV report is uploaded to an Azure Storage Account. The target storage account is taken from the shared **RJReport** tenant settings, so it can be configured once and reused across all report runbooks:

- `RJReport.StorageAccount.ResourceGroup`
- `RJReport.StorageAccount.StorageAccountName`
- `RJReport.StorageAccount.LinkExpiryDays` (optional, defaults to 6)

The container name is configured per runbook (parameter `ContainerName`, default `windows-devices-without-autopilot`) and is intentionally not part of the global RJReport settings.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

The runbook's managed identity needs at least `Contributor` access on the subscription or resource group containing the storage account.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-devices-sync-device-serialnumbers-to-entraid-(scheduled)'></a>

### Sync Device Serialnumbers To Entraid (Scheduled)
#### Copy Intune serial numbers into an Entra ID extension attribute

#### Description

Writes the serial number of each Intune managed device into one of the extension attributes of its Entra ID device object. That makes the serial number usable in dynamic groups and filters. By default only devices with a missing or different value are updated. A report can be sent by email.

#### Where to find

Org \ Devices \ Sync Device Serialnumbers To Entraid_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-general'></a>

## General
<a name='org-general-add-devices-of-users-to-group-(scheduled)'></a>

### Add Devices Of Users To Group (Scheduled)
#### Add the devices of a user group's members to a device group

#### Description

Adds the devices of all users in a user group to a device group on every run, so device-based policies can follow user membership. Devices already in the group are skipped, and nothing is removed.

#### Where to find

Org \ General \ Add Devices Of Users To Group_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-management-partner'></a>

### Add Management Partner
#### List or add a Partner Admin Link (PAL) for the tenant

#### Description

Shows the Partner Admin Links (PAL) that tie the Azure usage of this tenant to a Microsoft partner, or adds a new one with the partner's ID. The link only credits the partner for the Azure consumption it manages.

#### Where to find

Org \ General \ Add Management Partner


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-microsoft-store-app-logos'></a>

### Add Microsoft Store App Logos
#### Add missing logos to Microsoft Store apps in Intune

#### Description

Fetches the icon from the Microsoft Store for every Microsoft Store app (new) in Intune that has no logo yet and sets it. Apps that already have a logo are skipped, and the result shows how many were updated.

#### Where to find

Org \ General \ Add Microsoft Store App Logos


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-office365-group'></a>

### Add Office365 Group
#### Create a Microsoft 365 group, optionally with a team

#### Description

Creates a Microsoft 365 group with its SharePoint site and, on request, turns it into a Microsoft Teams team. Visibility, mail and security settings and up to two owners can be set. A team without an owner gets the caller as owner.

#### Where to find

Org \ General \ Add Office365 Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-or-remove-safelinks-exclusion'></a>

### Add Or Remove Safelinks Exclusion
#### Allow a URL pattern in a Safe Links policy or remove it

#### Description

Adds a URL pattern to the exclusions of a Microsoft Defender Safe Links policy so links matching it are no longer rewritten, or removes such an exclusion. It can also list the existing policies with their settings, and create a policy with its assignment group when the requested one does not exist.

#### Where to find

Org \ General \ Add Or Remove Safelinks Exclusion


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-or-remove-smartscreen-exclusion'></a>

### Add Or Remove Smartscreen Exclusion
#### Allow, warn or block a URL in Defender SmartScreen

#### Description

Manages URL indicators in Microsoft Defender for Endpoint, which SmartScreen uses to allow, audit, warn about or block a domain. Lists the existing indicators, adds one for a domain, or removes all indicators for it.

#### Where to find

Org \ General \ Add Or Remove Smartscreen Exclusion


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-or-remove-trusted-site'></a>

### Add Or Remove Trusted Site
#### Add a URL to the Intune trusted sites list or remove it

#### Description

Adds a URL to the site-to-zone assignment list of a Windows configuration policy in Intune, or removes it again. That list puts a URL into an Internet Explorer security zone such as Trusted sites. It can also list all trusted sites policies with their entries.

#### Where to find

Org \ General \ Add Or Remove Trusted Site

## Implementation notes

The runbook decrypts the `omaSettings` of the custom configuration policy using the approach described in [this call4cloud article](https://call4cloud.nl/2021/09/the-isencrypted-with-steve-zissou/). This currently requires the Microsoft Graph beta endpoint.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-primary-users-of-devices-to-group-(scheduled)'></a>

### Add Primary Users Of Devices To Group (Scheduled)
#### Keep a group in sync with the primary users of Intune devices

#### Description

Collects the primary users of all Intune devices of the chosen platforms and keeps an Entra ID group in sync with them. Users without a matching device are removed unless removal is turned off. An include group limits which users are eligible, an exclude group blocks users. A report-only mode previews the changes by email without applying anything.

#### Where to find

Org \ General \ Add Primary Users Of Devices To Group_Scheduled

## Common use cases

- Keeping a distribution or Conditional Access target group aligned with "who currently has a managed device", filtered by platform, by an advanced OData filter or by an include/exclude group scope.
- Validating a new or changed filter or scope before it is allowed to write to a production group.

A daily schedule is recommended.

## Report-only mode for pilots and testing

Enable `ReportOnly` to compute the same add/remove diff a real run would produce, without applying any change to the group. Instead, a Markdown preview email listing the affected users by UPN is sent to `EmailTo`: each list (would be added, would be removed) shows at most 10 users in the mail body, with a "... and N more" pointer when a list is longer, and the complete lists are attached as report file(s) in the format chosen by `ReportFileFormat`. Run once in this mode after changing the platform selection, `AdvancedFilter` or the include/exclude groups, review the preview, then disable `ReportOnly` to let the sync apply.

## Parameter interactions

- `AdvancedFilter`, when set, replaces the Windows/macOS/iOS/Android platform selection entirely rather than combining with it.
- `RemoveUsersWhenNoDeviceMatch` controls both the real run and the `ReportOnly` preview: when disabled, no users are removed in either case, so the preview always reflects what a real run would do.

## Setup regarding email sending

Sending an email report is optional and only happens when the `ReportOnly` option is enabled; a recipient (`EmailTo`) is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-security-group'></a>

### Add Security Group
#### Create a security group in Entra ID

#### Description

Creates a security group in Entra ID with assigned membership, so it can be used for permissions and access assignments. Names that contain a blocked word or are already in use are rejected. An owner can be set right away.

#### Where to find

Org \ General \ Add Security Group


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-user'></a>

### Add User
#### Create a new user account in Entra ID

#### Description

Creates a cloud user in Entra ID with the usual profile details such as name, company, job title, manager, sponsors and address. Sign-in name, alias and display name are derived from the name when left empty, and a start password is generated when none is given. Optionally the user gets a license group, further groups and an Exchange Online archive mailbox.

#### Where to find

Org \ General \ Add User

## Offer locations and companies as templates

Address fields and company are free text by default. With runbook customization templates the operator picks an office location, which fills in and locks the address block, and a company from a list. The example below defines such templates and binds them to the runbook's fields:

```json
{
    "Templates": {
        "Options": [
            {
                "$id": "LocationOptions",
                "$values": [
                    {
                        "Display": "DE-OF",
                        "Customization": {
                            "Default": {
                                "StreetAddress": "Kaiserstraße 39",
                                "PostalCode": "63065",
                                "City": "Offenbach",
                                "Country": "Germany"
                            }
                        }
                    },
                    {
                        "Display": "DE-DEG",
                        "Customization": {
                            "Default": {
                                "StreetAddress": "Lateinschulgassse 24-26",
                                "PostalCode": "94469",
                                "City": "Deggendorf",
                                "Country": "Germany"
                            }
                        }
                    },
                    {
                        "Display": "DE-HH",
                        "Customization": {
                            "Default": {
                                "StreetAddress": "Hans-Henny-Jahnn-Weg 53",
                                "PostalCode": "22085",
                                "City": "Hamburg",
                                "Country": "Germany"
                            }
                        }
                    },
                    {
                        "Display": "FI-HS",
                        "Customization": {
                            "Default": {
                                "StreetAddress": "Somewhere 42",
                                "PostalCode": "12345",
                                "City": "Helsinki",
                                "Country": "Finland"
                            }
                        }
                    }
                ]
            },
            {
                "$id": "CompanyOptions",
                "$values": [
                    {
                        "Id": "gkg",
                        "Display": "glueckkanja-gab",
                        "Value": "glueckkanja-gab AG"
                    },
                    {
                        "Id": "pp",
                        "Display": "PrimePulse",
                        "Value": "PrimePulse AG"
                    }
                ]
            }
        ]
    },
    "Runbooks": {
        "rjgit-org_general_add-user": {
            "ParameterList": [
                {
                    "DisplayName": "Office Location",
                    "DisplayAfter": "CompanyName",
                    "Select": {
                        "Options": {
                            "$ref": "LocationOptions"
                        }
                    }
                },
                {
                    "Name": "CompanyName",
                    "Select": {
                        "Options": {
                            "$ref": "CompanyOptions"
                        },
                        "AllowEdit": false
                    }
                }
            ],
            "ReadOnly": [
                "StreetAddress",
                "PostalCode",
                "City",
                "Country"
            ]
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-add-viva-engange-community'></a>

### Add Viva Engange Community
#### Create a Viva Engage community with owners

#### Description

Creates a Viva Engage (Yammer) community with the given name, visibility and directory listing, and adds the named owners. The API user that creates the community can be removed from the resulting Microsoft 365 group once another owner exists.

#### Where to find

Org \ General \ Add Viva Engange Community


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-assign-groups-by-template-(scheduled)'></a>

### Assign Groups By Template (Scheduled)
#### Add the users of a group to a predefined set of groups

#### Description

Adds every user of a source group to the target groups of a template, on a schedule, so a whole population gets the same group set. Users in an exclusion group are skipped. The templates are defined in the runbook customization.

#### Where to find

Org \ General \ Assign Groups By Template_Scheduled

## Define the templates via runbook customization

The templates decide which target groups the users of the source group join. Each template presets the group list (`GroupsString`) and whether that list holds object IDs (`UseDisplaynames` = `false`) or display names (`true`).

```json
{
    "Templates": {
        "Options": [
            {
                "$id": "GroupsTemplates",
                "$values": [
                    {
                        "Display": "Template 1 (UseDisplaynames=false)",
                        "Customization": {
                            "Default": {
                                "GroupsString": "c1f8e69f-e6c0-4e7e-b49d-241046958aa3,98c19df0-0bc1-4236-92b9-12559e1127d3",
                                "UseDisplaynames": false
                            }
                        }
                    },
                    {
                        "Display": "Template 2 (UseDisplaynames=true)",
                        "Customization": {
                            "Default": {
                                "GroupsString": "app - Microsoft VC Redistributable 2013,app - VLC Player",
                                "UseDisplaynames": true
                            }
                        }
                    }
                ]
            }
        ]
    },
    "Runbooks": {
        "rjgit-org_general_assign-groups-by-template_scheduled": {
            "ParameterList": [
                {
                    "Name": "GroupsTemplate",
                    "Select": {
                        "Options": {
                            "$ref": "GroupsTemplates"
                        }
                    }
                },
                {
                    "Name": "UseDisplaynames",
                    "Default": false
                }
            ]
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-bulk-delete-devices-from-autopilot'></a>

### Bulk Delete Devices From Autopilot
#### Delete several Autopilot registrations by serial number

#### Description

Removes the Windows Autopilot registrations of the devices with the given serial numbers, for example before a device is handed to another tenant or disposed of. Serial numbers that are not found are reported and skipped.

#### Where to find

Org \ General \ Bulk Delete Devices From Autopilot


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-bulk-retire-devices-from-intune'></a>

### Bulk Retire Devices From Intune
#### Retire several Intune devices by serial number

#### Description

Retires the Intune devices with the given serial numbers. A retire removes company data and management from each device but leaves personal data in place. Serial numbers that are not found are reported and skipped.

#### Where to find

Org \ General \ Bulk Retire Devices From Intune


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-aad-sync-status-(scheduled)'></a>

### Check Aad Sync Status (Scheduled)
#### Check the last Entra Connect sync and alert when it is off

#### Description

Checks whether directory synchronization from on-premises Active Directory is enabled in the tenant. If it is not, an alert email is sent.

#### Where to find

Org \ General \ Check Aad Sync Status_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-assignments-of-devices'></a>

### Check Assignments Of Devices
#### Show which Intune policies and apps target given devices

#### Description

Lists the Intune policies, and optionally the apps, that apply to one or more devices by resolving the devices' group memberships and matching them against the assignments. Nothing is changed.

#### Where to find

Org \ General \ Check Assignments Of Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-assignments-of-groups'></a>

### Check Assignments Of Groups
#### Show which Intune policies and apps target given groups

#### Description

Lists the Intune policies, and optionally the apps, that are assigned to one or more groups. Nothing is changed.

#### Where to find

Org \ General \ Check Assignments Of Groups


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-assignments-of-users'></a>

### Check Assignments Of Users
#### Show which Intune policies and apps target given users

#### Description

Lists the Intune policies, and optionally the apps, that apply to one or more users by resolving their group memberships, nested groups included, and matching them against the assignments. Nothing is changed.

#### Where to find

Org \ General \ Check Assignments Of Users


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-autopilot-serialnumbers'></a>

### Check Autopilot Serialnumbers
#### Check which serial numbers are registered in Autopilot

#### Description

Checks for a list of serial numbers whether a Windows Autopilot registration exists and reports which were found and which are missing. Nothing is changed.

#### Where to find

Org \ General \ Check Autopilot Serialnumbers


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-check-device-onboarding-exclusion-(scheduled)'></a>

### Check Device Onboarding Exclusion (Scheduled)
#### Keep unenrolled Autopilot devices in a compliance exclusion group

#### Description

Puts Windows Autopilot devices that are not yet enrolled in Intune, plus devices enrolled only recently, into an exclusion group. Once they are past that grace period, they are taken out again. Devices in the group can get a longer compliance grace period after enrollment.

#### Where to find

Org \ General \ Check Device Onboarding Exclusion_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-enrolled-devices-report-(scheduled)'></a>

### Enrolled Devices Report (Scheduled)
#### Report first-time device enrollments of the last weeks

#### Description

Lists devices that enrolled for the first time within the chosen number of weeks. They are grouped by an attribute of your choice, such as country or department, so you can see where new devices show up. The report can be exported as CSV to an Azure Storage account and downloaded from there.

#### Where to find

Org \ General \ Enrolled Devices Report_Scheduled

## Configure the storage account for the CSV export

The CSV export uploads the report to an Azure Storage account. Its resource group, name, region and performance tier come from the tenant settings below; the container name is taken from `EnrolledDevicesReport.Container`.

```json
{
  "Settings": {
    "EnrolledDevicesReport": {
      "ResourceGroup": "rj-test-runbooks-01",
      "StorageAccount": {
        "Name": "rjrbexports01",
        "Location": "West Europe",
        "Sku": "Standard_LRS"
      }
    }
  }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-all-autopilot-devices'></a>

### Export All Autopilot Devices
#### List or export all Windows Autopilot devices

#### Description

Lists every Windows Autopilot registration with its details, either in the run output or as a CSV file uploaded to an Azure Storage account with a time-limited download link. Nothing is changed.

#### Where to find

Org \ General \ Export All Autopilot Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-all-intune-devices'></a>

### Export All Intune Devices
#### Export all Intune devices with their primary users' usage location

#### Description

Exports every Intune managed device together with details of its primary user, such as the usage location, as a CSV file to an Azure Storage account. Optionally only devices whose primary user is in a given group are exported. Nothing is changed.

#### Where to find

Org \ General \ Export All Intune Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-cloudpc-usage-(scheduled)'></a>

### Export Cloudpc Usage (Scheduled)
#### Write daily Windows 365 usage data to an Azure table

#### Description

Collects how the Windows 365 Cloud PCs were used, based on the remote connection reports of the chosen number of past days. The figures are written to an Azure Table so they can be tracked over time. The table is created when missing, and records for the same day are updated rather than duplicated.

#### Where to find

Org \ General \ Export Cloudpc Usage_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-non-compliant-devices'></a>

### Export Non Compliant Devices
#### Export non-compliant Intune devices with their failing settings

#### Description

Lists the Intune devices that are non-compliant or in a grace period, together with the policies and the individual settings that fail on each of them. The results can be exported as CSV files to an Azure Storage account with time-limited download links. Nothing is changed.

#### Where to find

Org \ General \ Export Non Compliant Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-export-policy-report'></a>

### Export Policy Report
#### Export Intune and Entra ID policies as a Markdown report

#### Description

Collects the configuration policies from Intune and Entra ID and writes them into one Markdown report, for documentation or review. The raw policy definitions can be exported as JSON as well. The files can be uploaded to an Azure Storage account with time-limited download links. Nothing is changed.

#### Where to find

Org \ General \ Export Policy Report


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-invite-external-guest-users'></a>

### Invite External Guest Users
#### Invite an external person as a guest user

#### Description

Sends a Microsoft Entra ID guest invitation to an external email address. Optionally the guest is added to a group, and profile details such as name, company, usage location, manager and sponsor are set on the guest account right away. The invitation email and the landing page can be customized.

#### Where to find

Org \ General \ Invite External Guest Users

## Common use cases

- Basic guest invite: provide only the email address and the display name; all profile and group parameters can be left blank.
- Full onboarding: supply all optional fields to set profile properties, assign a manager and a sponsor, and add the guest to a group in a single run.

## Parameter interactions

- Profile properties (`givenName`, `surname`, `companyName`, `usageLocation`) are applied only when they are not empty; omitting them skips the update call entirely.
- Manager assignment, sponsor assignment and group membership each require their respective parameters; all of them are skipped silently when not provided.



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-list-all-administrative-template-policies'></a>

### List All Administrative Template Policies
#### List administrative template policies with their assignments

#### Description

Lists every administrative template policy in Intune and shows the current assignments of each one. Nothing is changed.

#### Where to find

Org \ General \ List All Administrative Template Policies


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-list-group-license-assignment-errors'></a>

### List Group License Assignment Errors
#### List groups whose license assignments have errors

#### Description

Finds the Entra ID groups with members whose group-based license assignment failed and lists their names and object IDs. Nothing is changed.

#### Where to find

Org \ General \ List Group License Assignment Errors


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-monitor-service-health-(scheduled)'></a>

### Monitor Service Health (Scheduled)
#### Alert by email about new Microsoft 365 service health issues

#### Description

Checks the Microsoft 365 service health feed for issues that Microsoft announced within the chosen number of hours. Each new issue is sent as a separate alert email, with the tenant and issue title in the subject and all details in the body. Monitoring can be limited to certain services, and advisories and already resolved issues can be included. No report files are created.

#### Where to find

Org \ General \ Monitor Service Health_Scheduled

## Common use cases

- Schedule the runbook to run at or slightly more often than `LookbackHours` to catch every new Service Health issue exactly once.
- Set `Services` to a comma-separated list of service names or short ids (matched case-insensitively) to monitor only specific services, such as Exchange Online or Teams; leave it empty to monitor all services.
- Leave `IncludeAdvisories` and `IncludeResolvedIssues` at their default of `false` for the lowest-noise setup, which alerts only on unresolved incidents; set either to `true` to also surface advisories or issues Microsoft has already marked as resolved.

## Parameter interactions

- An issue counts as newly announced when its first Service Health post falls inside the `LookbackHours` window (falling back to `startDateTime` if the issue has no posts), not by `lastModifiedDateTime` alone. This avoids missing back-dated issues while preventing re-alerts on every status update of an ongoing incident.
- The runbook keeps no state between runs, so a failed or skipped run means those alerts are never sent unless `LookbackHours` is temporarily widened for a catch-up run.
- One email is sent per new issue, so a busy Service Health day can produce several emails per run.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-office365-license-report'></a>

### Office365 License Report
#### Report Microsoft 365 license usage and availability

#### Description

Creates a report of the Microsoft 365 licenses in the tenant, how many are in use and how many are free. Exchange Online details such as shared mailbox licensing can be added. The report files can be uploaded to an Azure Storage account, as single files or as one ZIP, with download links. Nothing is changed unless real user data is requested, which briefly switches off the report privacy setting and restores it afterwards.

#### Where to find

Org \ General \ Office365 License Report

## Configure the storage account for the export

The report files are uploaded to an Azure Storage account. Its subscription, resource group and name come from the tenant settings below; the container name is taken from `OfficeLicensingReport.Container`. The switches of this runbook are backed by `OfficeLicensingReport.*` settings as well, so their defaults can be fixed per tenant.

```json
{
	"Settings": {
		"OfficeLicensingReport": {
			"ResourceGroup": "rj-test-runbooks-01",
			"SubscriptionId": "00000000-0000-0000-0000-000000000000",
			"StorageAccount": {
				"Name": "rbexports01"
			}
		}
	}
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-report-apple-mdm-cert-expiry-(scheduled)'></a>

### Report Apple MDM Cert Expiry (Scheduled)
#### Alert before Apple MDM certificates and tokens expire

#### Description

Checks the expiry dates of the Apple Push certificate, the VPP tokens and the DEP tokens in Intune. An email report flags everything that expires within the chosen number of days, so Apple device management does not stop unexpectedly.

#### Where to find

Org \ General \ Report Apple MDM Cert Expiry_Scheduled

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-report-intune-enrollment-readiness'></a>

### Report Intune Enrollment Readiness
#### Report which users can enroll devices in Intune

#### Description

Checks for a set of users, given directly or through a group, whether they can enroll a device in Intune. Each user is reported as Ready, Ready with warnings or Not ready, together with the blockers found. The check covers account status, Intune license, enrollment limit, authentication methods and Conditional Access policies that target device registration or enrollment. Nothing is changed. The report can be sent by email.

#### Where to find

Org \ General \ Report Intune Enrollment Readiness

## Interpretation notes

- Checks performed per user: account state, Intune license and service plan, tenant MDM authority, device enrollment limit, platform restrictions, registered authentication methods, Conditional Access policies and, optionally, pilot group membership.
- Conditional Access is evaluated as a static "What If" against the enrollment sign-in for each user's `EnrollmentPlatform`; Entra's own What If tool remains the authority.
- Compliant-device requirements on "All resources" policies do not block enrollment (a documented Entra exemption); only policies targeting device registration or the Intune enrollment apps are treated as strict gates.
- Not evaluated statically: named locations, device filters, sign-in frequency and terms of use.
- Expired or already used Temporary Access Passes are not counted as usable methods.

## Prerequisites

At least one of `UserName` or `GroupName` is required; group memberships are resolved transitively.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-report-license-assignment-(scheduled)'></a>

### Report License Assignment (Scheduled)
#### Alert when license availability crosses thresholds

#### Description

Checks how many licenses of the configured SKUs are still available. When a count drops below a minimum or rises above a maximum threshold, the affected SKUs are reported so you can buy or reclaim licenses in time. The report can be sent by email or provided as a download link.

#### Where to find

Org \ General \ Report License Assignment_Scheduled

## Runbook Customization

### Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

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
#### Report the PIM role activations of the last month by email

#### Description

Reads the Entra ID audit log for Privileged Identity Management role activations of the last month and sends them as an email report, so privileged access can be reviewed regularly. Nothing is changed.

#### Where to find

Org \ General \ Report Pim Activations_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-sync-all-devices'></a>

### Sync All Devices
#### Trigger an Intune sync on all Windows devices

#### Description

Asks every Windows device managed by Intune to check in, so pending policies, apps and configuration are applied without waiting for the next regular check-in. Devices that are offline sync when they come back online.

#### Where to find

Org \ General \ Sync All Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-sync-apple-tokens'></a>

### Sync Apple Tokens
#### Sync Apple enrollment and VPP tokens with Intune

#### Description

Triggers a sync of the Apple tokens in Intune, so device enrollments from Apple Business Manager and app licenses from the Volume Purchase Program are up to date. Either token type or both can be synced.

#### Where to find

Org \ General \ Sync Apple Tokens


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-sync-channel-or-group-members-(scheduled)'></a>

### Sync Channel Or Group Members (Scheduled)
#### Mirror members between a Teams shared channel and a group

#### Description

Copies the members of a source into a target on every run. The source and target can be a shared channel and a security group, two groups, or a group and a shared channel. Missing members are always added; members that exist only in the target are removed only when asked. A dry run shows the changes without applying them, and the report can be sent by email or provided as a download link. Details on the options are in the runbook documentation (docs.realmjoin.com).

#### Where to find

Org \ General \ Sync Channel Or Group Members_Scheduled

## How it works

This scheduled runbook mirrors the membership of a **source** object into a **target** object in a
single direction per run. On each run it:

1. Resolves the source and target objects for the selected direction.
2. Reads the current member set of both sides.
3. Adds every source member that is missing from the target.
4. Optionally removes every target member that does not exist in the source (mirror mode).

### Directions

The `Direction` parameter selects what is synced into what:

- **`SharedChannelToGroup`** - the members of a Teams shared channel are copied into a target security group.
- **`GroupToGroup`** - the members of a source group are copied into a target group (for example a Microsoft 365 group into a security group, or the reverse by swapping source and target).
- **`GroupToSharedChannel`** - the members of a source group are copied into a Teams shared channel.

### Adding and removing

Adding missing members is always performed. Removing members that exist only in the target is **opt-in**
via `RemoveExtraMembers` (default off). With removal enabled, the target is mirrored exactly against the
source; with it disabled, the runbook is add-only.

### Group member expansion

Group members on the source side are resolved **transitively**, so users that are members through nested
groups are included. On the target side only **direct** members are considered, because add and remove
operations act on direct membership.

### Guest handling

`IncludeGuests` (default off) controls whether guest users take part in the sync. When it is off, guests
are skipped on both sides and are never added or removed. Shared channels frequently reject guests, so
this is off by default.

### Shared channel specifics

- When a group is synced **into** a shared channel, team membership is a prerequisite for channel
  membership, so the runbook first ensures the user is a member of the host team and then adds the user
  to the channel.
- When members are **removed** from a shared channel, only the channel membership is removed by default.
  Enable `RemoveFromTeam` to also remove the user from the host team membership.

### Dry run

Set `WhatIfMode` to log what would change without writing anything.

### Reporting (optional, both default off)

- **`SendEmailReport`** sends a RealmJoin-branded email (via `Send-RjReportEmail`) with run statistics and
  a CSV attachment listing every individual change. The sender is taken from the `RJReport.EmailSender`
  setting.
- **`CreateDownloadLink`** uploads the same CSV to a storage account and returns a time-limited SAS
  download link (also embedded into the email when both options are enabled). The target storage account
  is taken from the `RJReport.StorageAccount.*` settings.

The storage upload authenticates with the Automation account's managed identity; that identity needs the
**Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC
assignment, not a Graph application permission).

### Scheduling

Designed to run unattended on a schedule. Because the runbook is idempotent, a single recurring schedule
keeps the target in sync with the source as members come and go.

## Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-general-sync-shared-channel-owners-(scheduled)'></a>

### Sync Shared Channel Owners (Scheduled)
#### Make a group's members owners of mapped teams and shared channels

#### Description

Shared channels do not inherit the owners of their team. For every team named in the mapping, the members of the mapped security group are made owners of the team and of each shared channel it hosts. It only adds, never removes; new shared channels are picked up on the next run. A dry run shows the changes without applying them, and the report can be sent by email or provided as a download link. Details on the options are in the runbook documentation (docs.realmjoin.com).

#### Where to find

Org \ General \ Sync Shared Channel Owners_Scheduled

## How it works

On each run the runbook:

1. Reads the team-name-to-owner-group mapping from the org setting `SharedChannelOwners.Mapping`.
2. For each entry, looks up the team by its **exact display name**.
3. Expands that entry's owner group to its transitive **user** members (guests are skipped - they cannot belong to a shared channel).
4. Ensures those users are owners of the team and of every **hosted** shared channel of the team.

The runbook is **add-only**: it never demotes or removes existing owners or members. Newly created shared channels are therefore picked up automatically on the next scheduled run, without disturbing anything already in place.

### Mapping configuration

The mapping lives centrally in the RealmJoin org settings (Runbook Customization → `Settings` → `SharedChannelOwners.Mapping`) so it is maintained once and shared by every schedule. It is a list of `{ TeamName, OwnerGroupId }` objects, where `TeamName` is the **exact team display name**. The hidden `TeamOwnerGroupMapping` parameter is injected from this setting; the runbook accepts it either as a structured array (recommended sub-setting form) or as a JSON string and normalizes both.

Ready-to-use example for the org settings:

```json
{
    "Settings": {
        "SharedChannelOwners": {
            "Mapping": [
                { "TeamName": "EXT Service A", "OwnerGroupId": "11111111-1111-1111-1111-111111111111" },
                { "TeamName": "EXT Service B", "OwnerGroupId": "22222222-2222-2222-2222-222222222222" }
            ]
        }
    }
}
```

### Team matching

Each mapping entry targets one explicitly named team:

- A team is matched by its **exact display name** (case-insensitive, consistent with Microsoft Graph; surrounding whitespace in the configured name is ignored). Only that team is processed - there is no prefix or wildcard behaviour, so naming an entry `EXT Service A` never affects `EXT Service A Backup` or similar.
- Display names are not guaranteed unique in Entra ID. If several teams share the configured name, the owner group is applied to **all** of them. If no team matches, the entry is reported as *not found* and skipped.

### Team selection

For every configured `TeamName` the runbook runs a Graph `displayName eq '...'` lookup and keeps only Microsoft 365 groups that are provisioned as a **Team**.

### What gets changed

- **Team (optional, `IncludeTeamOwners`, default on):** the owner-group users are added as owners and members of the parent M365 group. Team membership is also the technical prerequisite for becoming a shared-channel owner, so this step enables the channel step.
- **Shared channels:** for every hosted shared channel (`membershipType eq 'shared'`), each owner-group user is ensured as a channel **owner** - added directly if absent, or promoted if already a member. If a direct owner-add is rejected (e.g. membership replication lag), the runbook falls back to adding the user as a member first and then promoting.

### Dry run

Set **`WhatIfMode`** to log what would change without writing anything. In this mode the runbook prints, up front, the teams it would process (with their owner group) and any configured team names that were not found.

### Reporting (optional, both default off)

- **`SendEmailReport`** sends a RealmJoin-branded email (via `Send-RjReportEmail`) with run statistics and two CSV attachments: a per-team summary and a per-change detail list. The sender is taken from the `RJReport.EmailSender` setting.
- **`CreateDownloadLink`** uploads the same CSVs to a storage account and returns time-limited SAS download links (also embedded into the email when both options are enabled). The target storage account is taken from the `RJReport.StorageAccount.*` settings.

The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

### Scheduling

Designed to run unattended on a schedule. Because configuration is centralized in the org settings and the runbook is add-only and idempotent, a single recurring schedule keeps all mapped teams and their shared channels in sync as people and channels come and go.

## Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org'></a>

# Org
<a name='org-mail'></a>

## Mail
<a name='org-mail-add-distribution-list'></a>

### Add Distribution List
#### Create a classic Exchange Online distribution group

#### Description

Creates a classic distribution group in Exchange Online, optionally as a room list, with an owner, or open to external senders. Without an email address the alias at the default domain of the tenant is used.

#### Where to find

Org \ Mail \ Add Distribution List


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-equipment-mailbox'></a>

### Add Equipment Mailbox
#### Create an equipment mailbox with optional delegate

#### Description

Creates an equipment mailbox in Exchange Online, for example for a projector or a pool car, so it can be booked in meeting requests. A delegate can get full access and manage the bookings, and meeting requests can be accepted automatically. The user account behind the mailbox can be disabled so nobody signs in with it.

#### Where to find

Org \ Mail \ Add Equipment Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-mail-contact'></a>

### Add Mail Contact
#### Create a mail contact for an external address

#### Description

Creates a mail contact in Exchange Online for an external email address, so the person can be found in the address book and added to groups. First name, last name, contact name and alias are optional; the contact can be hidden from the address lists.

#### Where to find

Org \ Mail \ Add Mail Contact


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-or-remove-public-folder'></a>

### Add Or Remove Public Folder
#### Create or remove an Exchange Online public folder

#### Description

Creates a public folder in Exchange Online, optionally in a chosen public folder mailbox, or removes an existing one. At least one public folder mailbox must already exist; the runbook does not create any.

#### Where to find

Org \ Mail \ Add Or Remove Public Folder


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-or-remove-teams-mailcontact'></a>

### Add Or Remove Teams Mailcontact
#### Give a Teams channel a friendly email address or remove it

#### Description

Creates a mail contact that forwards a friendly email address to the long address Teams generates for a channel. People can then email the channel with an address they can remember. The same runbook removes the friendly address again.

#### Where to find

Org \ Mail \ Add Or Remove Teams Mailcontact


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-or-remove-tenant-allow-block-list'></a>

### Add Or Remove Tenant Allow Block List
#### Add or remove a Tenant Allow/Block List entry

#### Description

Adds a sender, URL or file hash to the Tenant Allow/Block List of Defender for Office 365, or removes it again. New entries expire after the chosen number of days, so temporary exceptions clean themselves up.

#### Where to find

Org \ Mail \ Add Or Remove Tenant Allow Block List


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-room-mailbox'></a>

### Add Room Mailbox
#### Create a room mailbox with optional delegate

#### Description

Creates a room mailbox in Exchange Online so the room can be booked in meeting requests. A delegate can get full access and manage the bookings, and meeting requests can be accepted automatically. The user account behind the mailbox can be disabled so nobody signs in with it.

#### Where to find

Org \ Mail \ Add Room Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-add-shared-mailbox'></a>

### Add Shared Mailbox
#### Create a shared mailbox with optional delegate

#### Description

Creates a shared mailbox in Exchange Online with the chosen language and time zone. A delegate can get full access, and sent mails can be kept in the shared Sent Items folder. The user account behind the mailbox can be disabled so nobody signs in with it.

#### Where to find

Org \ Mail \ Add Shared Mailbox

## Offer the accepted domains as a list

The domain of the new mailbox is free text by default. With a runbook customization the operator picks it from the accepted domains of the tenant instead:

```json
{
        "Runbooks": {
        "rjgit-org_mail_add-shared-mailbox": {
            "ParameterList": [
                {
                    "Name": "DomainName",
                    "Select": {
                        "Options": [
                                {
                                    "Value": "contoso.onmicrosoft.com"
                                },
                                {
                                    "Value": "contoso.com"
                                }
                            ]
                    },
                    "DefaultValue": "contoso.com"
                }
            ]
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-hide-mailboxes-(scheduled)'></a>

### Hide Mailboxes (Scheduled)
#### Hide or show all Bookings calendars in the address book

#### Description

Hides every Microsoft Bookings calendar mailbox from the global address list, or shows them again, on each run. New Bookings calendars are covered automatically the next time the runbook runs.

#### Where to find

Org \ Mail \ Hide Mailboxes_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-mail-set-booking-config'></a>

### Set Booking Config
#### Configure the Microsoft Bookings settings of the tenant

#### Description

Sets the tenant-wide Microsoft Bookings settings in Exchange Online, such as whether Bookings is on, what customers may enter and how booking pages are named. Optionally an Outlook web policy for Bookings creators is created and Bookings is turned off in the default policy, so only members of that policy can create booking pages.

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

Looks up whether a phone number is assigned to a user in Microsoft Teams. If it is, the user and their voice policies are shown. Nothing is changed.

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
#### Add an allow or block indicator to Defender for Endpoint

#### Description

Creates a custom indicator in Microsoft Defender for Endpoint that allows, warns about, audits or blocks a file hash, certificate thumbprint, IP address, domain or URL on all onboarded devices. An alert can be raised whenever the indicator matches.

#### Where to find

Org \ Security \ Add Defender Indicator


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-backup-conditional-access-policies'></a>

### Backup Conditional Access Policies
#### Back up all Conditional Access policies to Azure Storage

#### Description

Exports every Conditional Access policy of the tenant as JSON and uploads them as one ZIP archive to an Azure Storage account. The backup lets you compare or restore policies later. Without a container name, a container named after the current date is used. Nothing is changed in the tenant.

#### Where to find

Org \ Security \ Backup Conditional Access Policies


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-find-sms-auth-phone-number'></a>

### Find SMS Auth Phone Number
#### Find the user who holds an SMS sign-in phone number

#### Description

Finds the user who has a given phone number registered for SMS sign-in in Entra ID. Such numbers must be unique in the tenant, so registering the same number for another user fails until the first registration is removed. Nothing is changed.

#### Where to find

Org \ Security \ Find SMS Auth Phone Number


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-admin-users'></a>

### List Admin Users
#### List all Entra ID admins and check their MFA methods

#### Description

Lists every user and service principal that holds a built-in Entra ID role, including PIM eligible assignments, as an admin-to-role report. Optionally the registered authentication methods of each admin are checked to show who is protected by MFA, with a choice of which methods count. The report can be uploaded as CSV to an Azure Storage account. Nothing is changed.

#### Where to find

Org \ Security \ List Admin Users


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-expiring-role-assignments'></a>

### List Expiring Role Assignments
#### List Entra ID role assignments that expire soon

#### Description

Lists the active and PIM eligible Entra ID role assignments that expire within the chosen number of days, so they can be renewed in time. Each entry shows the role, the principal and the expiry date. Nothing is changed.

#### Where to find

Org \ Security \ List Expiring Role Assignments


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-inactive-devices'></a>

### List Inactive Devices
#### List devices with no recent sign-in or Intune sync

#### Description

Lists the devices whose last Intune sync, or whose last sign-in recorded in Entra ID, is older than the chosen number of days. The result can be shown in the run output or exported as a CSV file to an Azure Storage account. Nothing is changed.

#### Where to find

Org \ Security \ List Inactive Devices


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-inactive-users'></a>

### List Inactive Users
#### List users with no recent interactive sign-in

#### Description

Lists the users and guests whose last interactive sign-in is older than the chosen number of days. Accounts that are blocked from signing in and accounts that never signed in can be included. Nothing is changed.

#### Where to find

Org \ Security \ List Inactive Users


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-information-protection-labels'></a>

### List Information Protection Labels
#### List the sensitivity labels of the tenant with their IDs

#### Description

Lists the Microsoft Purview Information Protection sensitivity labels of the tenant with their IDs, for example to pick the label ID needed by other runbooks. Nothing is changed.

#### Where to find

Org \ Security \ List Information Protection Labels


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-pim-rolegroups-without-owners-(scheduled)'></a>

### List Pim Rolegroups Without Owners (Scheduled)
#### Alert on PIM role groups that have no owner

#### Description

Finds role-assignable groups that hold eligible PIM role assignments but have no owner, so nobody is responsible for their membership. The group names are listed and can be sent by email. Nothing is changed.

#### Where to find

Org \ Security \ List Pim Rolegroups Without Owners_Scheduled


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-users-by-mfa-methods-count'></a>

### List Users By MFA Methods Count
#### List users by how many MFA methods they registered

#### Description

Counts the registered authentication methods of every enabled user and lists the users whose count falls into the chosen range, for example those with no MFA method at all. The list shows display name, sign-in name and the number of methods. Nothing is changed.

#### Where to find

Org \ Security \ List Users By MFA Methods Count


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-list-vulnerable-app-regs'></a>

### List Vulnerable App Regs
#### List app registrations possibly affected by CVE-2021-42306

#### Description

Checks the key credentials of every app registration in Entra ID for signs of CVE-2021-42306, where private key material was stored in the credential by mistake. App registrations that may be affected are listed. The result can be shown in the run output or exported as a CSV file to an Azure Storage account. Nothing is changed.

#### Where to find

Org \ Security \ List Vulnerable App Regs


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-monitor-pending-epm-requests-(scheduled)'></a>

### Monitor Pending EPM Requests (Scheduled)
#### Alert by email about pending EPM elevation requests

#### Description

Checks Intune for Endpoint Privilege Management elevation requests that are still waiting for a decision and sends an email when there are any, so approvers do not miss them. The email can carry a table with the request details and the report files. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Security \ Monitor Pending EPM Requests_Scheduled

## Endpoint Privilege Management context

- Endpoint Privilege Management (EPM) allows users to request temporary admin rights for specific applications.
- Pending requests require manual review and approval by security admins.
- Requests expire automatically if they are not reviewed within the configured timeframe.
- A timely review is critical for user productivity and for the security posture.

## Scheduling

An hourly schedule is recommended.

## Email behaviour

- Emails are sent individually to each recipient.
- No email is sent when there are no pending requests.
- Report file attachments (see `ReportFileFormat`) are only included when `DetailedReport` is enabled.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-notify-changed-ca-policies'></a>

### Notify Changed CA Policies
#### Alert by email about Conditional Access policy changes

#### Description

Checks which Conditional Access policies were created or changed within the last 24 hours and sends an email with the list attached. Without changes, no email is sent. Nothing is changed in the tenant.

#### Where to find

Org \ Security \ Notify Changed CA Policies


[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-report-epm-elevation-requests-(scheduled)'></a>

### Report EPM Elevation Requests (Scheduled)
#### Report EPM elevation requests by status and age

#### Description

Collects the Endpoint Privilege Management elevation requests from Intune, filtered by status and by how long ago they were created. An email report carries the counts and the full list as report files. Intune keeps request details for 30 days, so older requests cannot be reported. The report can be sent by email or provided as a download link.

#### Where to find

Org \ Security \ Report EPM Elevation Requests_Scheduled

## Purpose and use cases

- Regular reporting of Endpoint Privilege Management (EPM) activities
- Audit trail for approved and denied elevation requests
- Analysis of expired requests to identify process bottlenecks
- Identification of frequently requested applications for automatic elevation rules

A monthly schedule is recommended.

## Status types

- **Pending:** awaits an admin decision (use **Monitor Pending EPM Requests** for time-critical alerting)
- **Approved:** an admin approved the request, the user can proceed with the elevation
- **Denied:** an admin rejected the request due to security or policy concerns
- **Expired:** the request expired before an admin reviewed it, which may indicate slow response times
- **Revoked:** a previously approved elevation was later revoked by an admin
- **Completed:** the user successfully executed the elevated application after approval

## Data retention and time ranges

- Intune retains EPM request details for 30 days after creation.
- For long-term analysis, archive the CSV exports outside of Intune.
- The default filter covers the states Approved, Denied, Expired and Revoked over the last 30 days.

## Email and export details

- Generates CSV and/or Excel (xlsx) report files with the complete request details (see `ReportFileFormat`).
- Emails are sent individually to each recipient for privacy.
- No email is sent when no request matches the filter criteria.
- The report files include timestamps, users, devices, applications, justifications and file hashes.

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='org-security-sync-mfa-secure-users-to-group-(scheduled)'></a>

### Sync MFA Secure Users To Group (Scheduled)
#### Keep a group filled with users who registered a secure MFA method

#### Description

Keeps an Entra ID group in sync with the users who registered at least one secure authentication method, such as a passkey or the Microsoft Authenticator app. Users who lose their secure method are removed. Admins, an exclusion group and individual users can be kept out, for example when the group controls self-service password reset. A dry run only shows the changes, and the report can be sent by email or provided as a download link. Details on the options are in the runbook documentation (docs.realmjoin.com).

#### Where to find

Org \ Security \ Sync MFA Secure Users To Group_Scheduled

## How it works

The runbook reads the Entra ID [authentication methods registration report](https://learn.microsoft.com/en-us/graph/api/authenticationmethodsroot-list-userregistrationdetails) (`userRegistrationDetails`) and mirrors the target group against all **member users** that qualify:

- A user qualifies when at least one of their registered methods is in the configured **secure** set.
- In **strict mode** (`SecureOnly`), a user additionally must not have any method from the **unsecure** set registered — a passkey user who also keeps an SMS factor does not qualify.
- Qualifying users that are not yet group members are added; members that no longer qualify are removed (mirror sync).
- Guest users are never added or removed. Non-user group members (devices, service principals, nested groups) are never touched.

The target group should be managed exclusively by this runbook.

## Secure method groups

Each toggle controls which `methodsRegistered` values count as secure:

| Toggle | Default | Covered values |
| --- | --- | --- |
| Passkeys / FIDO2 security keys | on | `fido2SecurityKey`, `passKeyDeviceBound`, `passKeyDeviceBoundAuthenticator` |
| Platform credentials | on | `windowsHelloForBusiness`, `passKeyDeviceBoundWindowsHello`, `macOsSecureEnclaveKey` |
| Microsoft Authenticator app | on | `microsoftAuthenticatorPush`, `microsoftAuthenticatorPasswordless` |
| Software OTP | off | `softwareOneTimePasscode` |
| Hardware OTP | off | `hardwareOneTimePasscode` |
| Certificate-based authentication | on | `certificateBasedAuthentication` |

## Strict mode (SecureOnly)

With strict mode enabled, users with any of the following built-in unsecure methods never qualify:

`mobilePhone`, `alternateMobilePhone`, `officePhone`, `email`, `securityQuestion`

If a method ends up in both the secure and the unsecure set (only possible via the override parameters), unsecure wins — such users never qualify in strict mode. The runbook warns about this at startup.

## Exclusions

Excluded users never qualify regardless of their registered methods: they are never added to the target group and are removed if they are already members. The per-user report shows the reason in the `ExclusionReason` column.

### Exclude admin users (`ExcludeAdmins`, on by default)

Users holding an Entra ID directory role are excluded. This covers:

- **Active role assignments** (`roleManagement/directory/roleAssignments`)
- **PIM-eligible assignments** (`roleManagement/directory/roleEligibilitySchedules`, requires Entra ID P2 — without P2 the runbook falls back to active assignments and logs a warning)
- **Role-assignable groups**: groups holding a role are expanded to their transitive user members

Background: when the target group drives **SSPR** and the SSPR administrator policy is disabled, admins in the group would still be forced to register a second factor once two SSPR methods are required. Keeping admins out of the group avoids this.

This option requires the additional Graph permission `RoleManagement.Read.Directory` for the managed identity.

### Exclusion group (`ExcludeGroupId`, optional)

Transitive user members of the configured group are excluded — intended for accounts that must never be managed by this sync, such as **break glass accounts** or **service accounts**. Nested groups are honored. The exclusion group must not be the target group itself.

### Individually excluded users (`ExcludeUserIds`, optional)

Individual users can be excluded directly via the multi-user picker — for one-off exclusions where a dedicated exclusion group is not worth maintaining. The list accepts user **object IDs** and **user principal names** (UPNs). Unresolvable entries (e.g. a deleted account) log a warning and are ignored, so a stale entry never breaks a scheduled sync.

### Maintaining exclusions via Runbook Customization (without the pickers)

Both exclusion parameters can be pre-set centrally via [JSON-based Runbook Customization](https://docs.realmjoin.com/automation/runbooks/runbook-customization#json-based-customizing) (RealmJoin portal: **Settings** → **Runbook Customizations**) — useful when the exclusions are fixed for the tenant and should not be picked manually each time the runbook is started or scheduled:

```json
{
    "Runbooks": {
        "rjgit-org_security_sync-mfa-secure-users-to-group_scheduled": {
            "Parameters": {
                "ExcludeGroupId": {
                    "DefaultValue": "00000000-0000-0000-0000-000000000000",
                    "Hide": true
                },
                "ExcludeUserIds": {
                    "DefaultValue": [
                        "11111111-1111-1111-1111-111111111111",
                        "breakglass@contoso.com"
                    ],
                    "Hide": true
                }
            }
        }
    }
}
```

- **ExcludeGroupId** takes a single group **object ID** (GUID) as a plain string — copy it from the group's overview page in the Entra admin center or the RealmJoin portal.
- **ExcludeUserIds** takes a JSON **array of strings**; each entry can be a user **object ID** or a **UPN**. Entries are trimmed and deduplicated; the runbook resolves them at startup.
- **Recommended:** when the exclusions are maintained via Runbook Customization, also set `"Hide": true` on the parameter (as in the example above). This removes it from the start form entirely, so the centrally configured exclusions cannot be overridden in the UI when starting or scheduling the runbook. Without `Hide`, the configured values only appear pre-filled and can still be changed there.

## Method classification reference

Use the exact Graph values from this table when building the comma-separated override strings:

| `methodsRegistered` value | Friendly name | Classification | Covered by toggle (default) |
| --- | --- | --- | --- |
| `fido2SecurityKey` | FIDO2 security key | Secure | Passkeys / FIDO2 (on) |
| `passKeyDeviceBound` | Passkey (device-bound) | Secure | Passkeys / FIDO2 (on) |
| `passKeyDeviceBoundAuthenticator` | Passkey in Microsoft Authenticator | Secure | Passkeys / FIDO2 (on) |
| `windowsHelloForBusiness` | Windows Hello for Business | Secure | Platform credentials (on) |
| `passKeyDeviceBoundWindowsHello` | Passkey in Windows Hello | Secure | Platform credentials (on) |
| `macOsSecureEnclaveKey` | Platform Credential for macOS | Secure | Platform credentials (on) |
| `microsoftAuthenticatorPush` | Microsoft Authenticator (push notification) | Secure | Microsoft Authenticator app (on) |
| `microsoftAuthenticatorPasswordless` | Microsoft Authenticator (passwordless phone sign-in) | Secure | Microsoft Authenticator app (on) |
| `softwareOneTimePasscode` | Software OATH token (TOTP app) | Secure | Software OTP (off) |
| `hardwareOneTimePasscode` | Hardware OATH token | Secure | Hardware OTP (off) |
| `certificateBasedAuthentication` | Certificate-based authentication | Secure | Certificate-based authentication (on) |
| `mobilePhone` | Phone (SMS / voice call) | Unsecure | built-in unsecure list |
| `alternateMobilePhone` | Alternate phone (voice call) | Unsecure | built-in unsecure list |
| `officePhone` | Office phone (voice call) | Unsecure | built-in unsecure list |
| `email` | Email (SSPR only) | Unsecure | built-in unsecure list |
| `securityQuestion` | Security questions (SSPR only) | Unsecure | built-in unsecure list |
| `temporaryAccessPass` | Temporary Access Pass | Neutral | never qualifies, never disqualifies |

Unknown or future Graph values are treated as neutral unless explicitly listed in an override parameter.

## Override parameters

Both override parameters are hidden by default and intended for RealmJoin runbook customization:

- **SecureMethodsOverride** — comma-separated list of `methodsRegistered` values that defines the secure set. When set, **all** method group toggles are ignored. Example: `fido2SecurityKey,passKeyDeviceBound,passKeyDeviceBoundAuthenticator,windowsHelloForBusiness`
- **UnsecureMethodsOverride** — comma-separated list that replaces the built-in unsecure list. Only evaluated in strict mode. Example: `mobilePhone,alternateMobilePhone,officePhone,email,securityQuestion,softwareOneTimePasscode`

Unknown values produce a warning but are still evaluated, so future Graph values can be used before this documentation catches up.

## Email report and download links

Optionally, a detailed report can be delivered - especially useful for reviewing the very first run (ideally combined with the dry run mode):

- **Send report via email** (`SendEmail`, off by default): sends the report to the configured recipient(s). The recipient field only appears when email is enabled. Requires the `RJReport.EmailSender` tenant setting (see the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings)).
- **Create file download links** (`CreateDownloadLink`, off by default): uploads the report files to an Azure Storage Account and returns time-limited download links (uses the `RJReport.StorageAccount.*` tenant settings).

Report files are only generated when at least one of the two options is enabled. The report consists of:

- **mfa-secure-users-group-sync-changes.csv** - all performed (or, in dry run, pending) changes with per-user method details
- **mfa-secure-users-group-sync-all-users.csv** - the evaluation of every member user: registered methods, secure/unsecure classification, qualification, exclusion reason and group membership
- **mfa-secure-users-group-sync-report.xlsx** - the same data as a formatted Excel workbook: an "Info" cover sheet with the chosen parameters and result counts, a "Changes" worksheet (added users highlighted in green, removed in red) and an "All Users" worksheet

In large tenants the raw CSV files can exceed the email attachment size limit (Graph rejects mails at roughly 4 MB total). When the CSV files exceed a 2.5 MB budget, the email is sent with only the Excel workbook attached (which contains the complete data in compressed form) and a note explaining the omission; a failed full-size send is also retried automatically with the workbook only. The download link upload always includes all files regardless of size.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## Notes and limitations

- The registration report requires an **Entra ID P1 or P2** license.
- PIM-eligible role assignments (admin exclusion) require an **Entra ID P2** license — without it, only active role assignments are excluded.
- The report does not include **disabled** or soft-deleted users — such accounts are removed from the group on the next run.
- Report data can lag behind recent registration changes; a newly registered method may take one sync cycle to be reflected.
- The runbook processes large tenants (20k+ users) via paged report reads and batched group writes with automatic throttling retries.

## Scheduling

The sync is idempotent — a single recurring schedule (e.g. daily) keeps the group up to date, and reruns after partial failures self-heal. Recommendation: run once with **Dry run (WhatIf)** enabled and review the job output before scheduling the runbook in live mode.



[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-avd'></a>

## AVD
<a name='user-avd-user-signout'></a>

### User Signout
#### Sign this user out of their AVD sessions

#### Description

Finds the Azure Virtual Desktop sessions of this user, active or disconnected, in all host pools of the configured subscriptions and signs the user out of them. Unsaved work in those sessions is lost.

#### Where to find

User \ AVD \ User Signout


[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-general'></a>

## General
<a name='user-general-assign-groups-by-template'></a>

### Assign Groups By Template
#### Add this user to a predefined set of groups

#### Description

Adds this user to one or more Entra ID groups. The groups come from a template that an administrator defines in the runbook customization, so the person running it picks a template instead of individual groups.

#### Where to find

User \ General \ Assign Groups By Template

## Define the templates via runbook customization

The templates the users can pick are defined once per tenant in the runbook customization. Each template presets the group list (`GroupsString`); `UseDisplaynames` decides whether that list holds object IDs (`false`) or display names (`true`).

```json
{
    "Templates": {
        "Options": [
            {
                "$id": "GroupsTemplates",
                "$values": [
                    {
                        "Display": "User template 1 (object IDs)",
                        "Customization": {
                            "Default": {
                                "GroupsString": "c1f8e69f-e6c0-4e7e-b49d-241046958aa3,98c19df0-0bc1-4236-92b9-12559e1127d3"
                            }
                        }
                    },
                    {
                        "Display": "User template 2 (display names)",
                        "Customization": {
                            "Default": {
                                "GroupsString": "app - Microsoft VC Redistributable 2013"
                            }
                        }
                    }
                ]
            }
        ]
    },
    "Runbooks": {
        "rjgit-user_general_assign-groups-by-template": {
            "ParameterList": [
                {
                    "Name": "GroupsTemplate",
                    "Select": {
                        "Options": {
                            "$ref": "GroupsTemplates"
                        }
                    }
                },
                {
                    "Name": "UseDisplaynames",
                    "Default": false
                }
            ]
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-assign-or-unassign-license'></a>

### Assign Or Unassign License
#### Assign or remove a license for this user via a license group

#### Description

Adds this user to a license assignment group or removes the user from it, which assigns or removes the license the group carries.

#### Where to find

User \ General \ Assign Or Unassign License


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-assign-windows365'></a>

### Assign Windows365
#### Provision a Windows 365 Cloud PC for this user

#### Description

Assigns this user the groups that trigger Windows 365 provisioning: the provisioning policy or Frontline assignment, the user settings policy and, for a dedicated Cloud PC, the license group. Optionally the user gets an email once the Cloud PC is ready, and a service ticket is opened by email when no licenses or Frontline seats are left.

#### Where to find

User \ General \ Assign Windows365

## Offer the policy and license groups as dropdowns

The provisioning policy, user settings policy and license group are plain text fields by default. Turn them into dropdowns with the group names of your tenant via runbook customization:

```json
"rjgit-user_general_assign-windows365": {
    "Parameters": {
        "cfgProvisioningGroupName": {
            "SelectSimple": {
                "cfg - Windows 365 - Provisioning - Win11": "cfg - Windows 365 - Provisioning - Win11",
                "cfg - Windows 365 - Provisioning - Win10": "cfg - Windows 365 - Provisioning - Win10"
            }
        },
        "cfgUserSettingsGroupName": {
            "SelectSimple": {
                "cfg - Windows 365 - User Settings - restore allowed": "cfg - Windows 365 - User Settings - restore allowed",
                "cfg - Windows 365 - User Settings - no restore": "cfg - Windows 365 - User Settings - no restore"
            }
        },
        "licWin365GroupName": {
            "SelectSimple": {
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
            }
        }
    }
}
```

The group name prefixes (`cfgProvisioningGroupPrefix`, `cfgUserSettingsGroupPrefix`) decide which groups count as provisioning or user settings groups; adjust them in the same place when your naming differs.

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-check-intune-enrollment-readiness'></a>

### Check Intune Enrollment Readiness
#### Check whether this user can enroll devices in Intune

#### Description

Checks whether this user is ready to enroll a device in Intune and reports Ready, Ready with warnings or Not ready together with the blockers found. The check covers the account status, the Intune license, the device enrollment limit, platform restrictions and Conditional Access policies that target device registration or enrollment. Nothing is changed. Details on the checks are in the runbook documentation (docs.realmjoin.com).

#### Where to find

User \ General \ Check Intune Enrollment Readiness

## Interpretation notes

- Checks performed: account state, Intune license and service plan, tenant MDM authority, device enrollment limit, platform restrictions, registered authentication methods, Conditional Access policies and, optionally, pilot group membership.
- Conditional Access is evaluated as a static "What If" against the enrollment sign-in for the selected `EnrollmentPlatform`; Entra's own What If tool remains the authority.
- Compliant-device requirements on "All resources" policies do not block enrollment (a documented Entra exemption); only policies targeting device registration or the Intune enrollment apps are treated as strict gates.
- Not evaluated statically: named locations, device filters, sign-in frequency and terms of use.
- Expired or already used Temporary Access Passes are not counted as usable methods.

## Prerequisites

The tenant MDM authority must be "intune" or "office365"; other values block every user.

## What is checked

The readiness verdict combines these checks:

- Account status (enabled, not blocked) and an Intune license assigned to the user.
- The tenant's device enrollment limit for the user and the platform restrictions of the enrollment configuration.
- Conditional Access policies that explicitly target device registration or Intune enrollment. Policies that require a compliant device via *All resources* are exempted by Microsoft Entra design and therefore not counted as blockers.
- Platform-scoped policies and browser-only client-app requirements are evaluated against the chosen enrollment platform; with *All platforms* every platform is evaluated and reported separately.

The runbook only reads; it changes nothing on the user or the tenant.



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-list-group-memberships'></a>

### List Group Memberships
#### List the group memberships of this user

#### Description

Lists the groups this user is a member of, with filters for group type, membership type, role assignability, Teams, source and writeback. The result is shown as CSV text. The report can be sent by email or provided as a download link.

#### Where to find

User \ General \ List Group Memberships

## Setup regarding email sending

Sending an email report is optional and only happens when the `SendMail` option is enabled; a recipient (`EmailTo`) is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-list-group-ownerships'></a>

### List Group Ownerships
#### List the groups this user owns

#### Description

Lists the Entra ID groups this user owns, with their names and IDs. The report can be sent by email or provided as a download link.

#### Where to find

User \ General \ List Group Ownerships

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-list-manager'></a>

### List Manager
#### Show the manager of this user

#### Description

Shows who is set as the manager of this user in Entra ID, with the manager's display name, email address and phone numbers. Nothing is changed.

#### Where to find

User \ General \ List Manager


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-offboard-user-permanently'></a>

### Offboard User Permanently
#### Permanently offboard this user

#### Description

Offboards this user for good: access is revoked, the account is disabled or deleted, licenses and groups are adjusted, and the group memberships can be exported before they are changed. Group ownerships, direct reports and sponsorships of guests can be handed over to a replacement. A deleted account can be restored for 30 days only.

#### Where to find

User \ General \ Offboard User Permanently

## Preset the offboarding policy via tenant settings

Most switches of this runbook are backed by tenant settings, so an organization can fix its offboarding policy once and hide the corresponding fields from the operators. The example below presets every switch and hides the fields; keep only the fields the operators should still decide per run.

```json
{
    "Settings": {
        "OffboardUserPermanently": {
            "userTypeRestriction": 0,
            "deleteUser": true,
            "disableUser": true,
            "revokeAccess": true,
            "exportGroupMemberships": true,
            "licensesMode": 0,
            "groupsMode": 0,
            "groupToAdd": "",
            "groupsToRemovePrefix": "",
            "replaceManagerReferences": true,
            "replaceSponsorReferences": true
        },
        "RJReport": {
            "StorageAccount": {
                "ResourceGroup": "rj-test-runbooks-01",
                "StorageAccountName": "rjrbexports01",
                "LinkExpiryDays": 6
            }
        }
    },
    "Runbooks": {
        "rjgit-user_general_offboard-user-permanently": {
            "ParameterList": [
                { "Name": "UserTypeSelector", "Hide": true },
                { "Name": "DisableUser", "Hide": true },
                { "Name": "RevokeAccess", "Hide": true },
                { "Name": "ChangeLicensesSelector", "Hide": true },
                { "Name": "ChangeGroupsSelector", "Hide": true },
                { "Name": "GroupToAdd", "Hide": true },
                { "Name": "GroupsToRemovePrefix", "Hide": true },
                { "Name": "CallerName", "Hide": true }
            ]
        }
    }
}
```

Meaning of the settings:

- `userTypeRestriction`: `0` allows all user types, `1` members only, `2` guests only. A mismatching user stops the run before any change.
- `deleteUser`: delete the account (`true`) or keep it (`false`).
- `disableUser`, `revokeAccess`: block sign-in and end the user's sessions.
- `exportGroupMemberships`: export the group memberships to the report storage account (see `RJReport.StorageAccount`) and return a download link before groups and licenses are changed.
- `licensesMode`: `0` keeps the directly assigned licenses, `2` removes all of them.
- `groupsMode`: `0` keeps the groups, `1` removes the groups starting with `groupsToRemovePrefix`, `2` removes all groups. Both `1` and `2` add or keep `groupToAdd`.
- `replaceManagerReferences`, `replaceSponsorReferences`: hand the user's direct reports and sponsorships over to the replacement person.

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-offboard-user-temporarily'></a>

### Offboard User Temporarily
#### Temporarily offboard this user

#### Description

Offboards this user for a while, for example for parental leave or a sabbatical. Sign-in is blocked, licenses and groups are adjusted, and the group memberships can be exported before they are changed. Group ownerships, direct reports and sponsorships of guests can be handed over to a replacement. The account itself stays.

#### Where to find

User \ General \ Offboard User Temporarily

## Preset the offboarding policy via tenant settings

Most switches of this runbook are backed by tenant settings, so an organization can fix its offboarding policy once and hide the corresponding fields from the operators. The example below presets every switch and hides the fields; keep only the fields the operators should still decide per run.

```json
{
    "Settings": {
        "OffboardUserTemporarily": {
            "userTypeRestriction": 0,
            "disableUser": true,
            "revokeAccess": true,
            "exportGroupMemberships": true,
            "licensesMode": 0,
            "groupsMode": 0,
            "groupToAdd": "",
            "groupsToRemovePrefix": "",
            "replaceManagerReferences": true,
            "replaceSponsorReferences": true
        },
        "RJReport": {
            "StorageAccount": {
                "ResourceGroup": "rj-test-runbooks-01",
                "StorageAccountName": "rjrbexports01",
                "LinkExpiryDays": 6
            }
        }
    },
    "Runbooks": {
        "rjgit-user_general_offboard-user-temporarily": {
            "ParameterList": [
                { "Name": "UserTypeSelector", "Hide": true },
                { "Name": "DisableUser", "Hide": true },
                { "Name": "RevokeAccess", "Hide": true },
                { "Name": "ChangeLicensesSelector", "Hide": true },
                { "Name": "ChangeGroupsSelector", "Hide": true },
                { "Name": "GroupToAdd", "Hide": true },
                { "Name": "GroupsToRemovePrefix", "Hide": true },
                { "Name": "CallerName", "Hide": true }
            ]
        }
    }
}
```

Meaning of the settings:

- `userTypeRestriction`: `0` allows all user types, `1` members only, `2` guests only. A mismatching user stops the run before any change.
- `disableUser`, `revokeAccess`: block sign-in and end the user's sessions.
- `exportGroupMemberships`: export the group memberships to the report storage account (see `RJReport.StorageAccount`) and return a download link before groups and licenses are changed.
- `licensesMode`: `0` keeps the directly assigned licenses, `2` removes all of them.
- `groupsMode`: `0` keeps the groups, `1` removes the groups starting with `groupsToRemovePrefix`, `2` removes all groups. Both `1` and `2` add or keep `groupToAdd`.
- `replaceManagerReferences`, `replaceSponsorReferences`: hand the user's direct reports and sponsorships over to the replacement person.

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-reprovision-windows365'></a>

### Reprovision Windows365
#### Reprovision the Windows 365 Cloud PC of this user

#### Description

Reprovisions the existing Windows 365 Cloud PC of this user. The Cloud PC is rebuilt from scratch with the same license, so everything stored on it is lost; the user keeps the assignment. Optionally the user gets an email when the reprovisioning starts.

#### Where to find

User \ General \ Reprovision Windows365

## Offer the license groups as a dropdown

The license group is a text field by default. Offer the license groups of your tenant as a dropdown via runbook customization:

```json
"rjgit-user_general_reprovision-windows365": {
    "Parameters": {
        "licWin365GroupName": {
            "SelectSimple": {
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
            }
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-resize-windows365'></a>

### Resize Windows365
#### Resize the Windows 365 Cloud PC of this user

#### Description

Moves the Windows 365 Cloud PC of this user to a different size by removing the current license assignment and provisioning a new Cloud PC with the new license. The old Cloud PC is deprovisioned, so data stored only on it is lost; ask the user to back up first. Optionally the user gets an email when the new Cloud PC is ready.

#### Where to find

User \ General \ Resize Windows365

## Offer the license groups as dropdowns

Both license fields are text fields by default. Offer the license groups of your tenant as dropdowns via runbook customization (the same list for the current and the new license):

```json
"rjgit-user_general_resize-windows365": {
    "Parameters": {
        "currentLicWin365GroupName": {
            "SelectSimple": {
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
            }
        },
        "newLicWin365GroupName": {
            "SelectSimple": {
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
            }
        }
    }
}
```

The resize runs the *Unassign Windows 365* and *Assign Windows 365* runbooks in sequence; their Azure Automation names are preset in the hidden parameters `unassignRunbook` and `assignRunbook`.

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-general-unassign-windows365'></a>

### Unassign Windows365
#### Remove the Windows 365 Cloud PC of this user

#### Description

Removes the Windows 365 license or Frontline assignment of this user and, unless another Cloud PC remains, the provisioning and user settings groups, which deprovisions the Cloud PC. Data stored only on the Cloud PC is lost. Optionally the grace period is skipped so the Cloud PC is deleted right away.

#### Where to find

User \ General \ Unassign Windows365

## Offer the license groups as a dropdown

The license field is a text field by default. Offer the license groups (or Frontline provisioning policy groups) of your tenant as a dropdown via runbook customization:

```json
"rjgit-user_general_unassign-windows365": {
    "Parameters": {
        "licWin365GroupName": {
            "SelectSimple": {
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
            }
        }
    }
}
```

The group name prefixes (`cfgProvisioningGroupPrefix`, `cfgUserSettingsGroupPrefix`, `licWin365GroupPrefix`) decide which of the user's groups count as Windows 365 groups; adjust them in the same place when your naming differs.

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).



[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-mail'></a>

## Mail
<a name='user-mail-add-or-remove-email-address'></a>

### Add Or Remove Email Address
#### Add an email address to this user's mailbox or remove one

#### Description

Adds an alias address to the mailbox of this user or removes one. A new or existing address can also be made the primary address that outgoing mail is sent from.

#### Where to find

User \ Mail \ Add Or Remove Email Address


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-assign-owa-mailbox-policy'></a>

### Assign Owa Mailbox Policy
#### Assign an Outlook on the web policy to this user's mailbox

#### Description

Assigns an Outlook on the web (OWA) mailbox policy to the mailbox of this user. Policies switch features on or off, for example email signatures in the web client or the Bookings add-in for people who create Bookings appointments. Get current assignment shows the policy in place without changing it.

#### Where to find

User \ Mail \ Assign Owa Mailbox Policy


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-convert-to-shared-mailbox'></a>

### Convert To Shared Mailbox
#### Convert this user's mailbox to a shared mailbox or back

#### Description

Turns the mailbox of this user into a shared mailbox, or turns a shared mailbox back into a regular user mailbox. When converting to shared, a delegate can get full access and the user's group memberships can be removed. A license group can be assigned when the mailbox needs an Exchange Online Plan 2.

#### Where to find

User \ Mail \ Convert To Shared Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-delegate-full-access'></a>

### Delegate Full Access
#### Grant or remove full access to this user's mailbox

#### Description

Grants one or more people full access to the mailbox of this user, or removes that access again. Optionally the mailbox opens automatically in the delegates' Outlook. The permissions are shown before and after the change, and a failure for one delegate does not stop the others.

#### Where to find

User \ Mail \ Delegate Full Access

## How it works

On each run the runbook:

1. Connects to Exchange Online with the Automation account's managed identity.
2. Verifies that the selected mailbox owner (`UserName`) actually has a mailbox - if not, the run stops before anything is changed.
3. Resolves every selected delegate to its primary SMTP address and drops duplicates and the mailbox owner itself.
4. Reads and prints the current **FullAccess** delegations on the mailbox (the *status quo*).
5. Grants or removes FullAccess for each remaining delegate, one at a time.
6. Re-reads the mailbox permissions and prints the resulting state plus a per-run summary.

The runbook only ever touches the **FullAccess** right on the one selected mailbox. Send As, Send on Behalf and folder-level permissions are not affected.

### Selecting delegates

The **Delegate access to** field is a **multi-select** user picker. Select as many delegates as needed - all of them receive the same action (*Grant access* or *Remove access*) and the same AutoMapping setting from the form in a single run.

The picker is restricted to member accounts (`userType eq 'Member'`), so guest accounts are not offered. It hands over each selected delegate as a **user principal name**, so the very first log line already reads as a list of UPNs instead of raw object IDs. Each value is then resolved against Exchange Online, and from the preflight step onward all output shows the delegate's primary SMTP address.

Two picker entries that resolve to the same mailbox are de-duplicated, and a delegate that resolves to the mailbox owner is dropped with a warning - a mailbox cannot be delegated to itself.

### What gets changed

- **Grant access (`Remove` = false):** `Add-MailboxPermission` with `-AccessRights FullAccess` for each delegate.
- **Remove access (`Remove` = true):** `Remove-MailboxPermission` with `-AccessRights FullAccess -InheritanceType All` for each delegate.

### AutoMapping

**`AutoMapping`** is only evaluated when granting access; the portal hides the field when *Remove access* is selected. With AutoMapping enabled, Outlook adds the delegated mailbox to the delegate's profile automatically - but only after the client re-creates the mapping, which can take a while. Existing grants are not re-written to change their AutoMapping value; remove the delegation and grant it again if the mapping behaviour must change.

### Idempotent by design

Nothing is done twice and nothing fails just because it was already true:

- Granting access to a delegate who already holds FullAccess is reported as *unchanged*, not as an error.
- Removing access from a delegate who has no FullAccess entry is reported as *unchanged*, not as an error.
- When the pre-change snapshot cannot classify an existing permission entry, the runbook does **not** take the shortcut - it calls Exchange Online and lets its response decide, so a removable delegation is never silently skipped.

### Partial results

Delegates are processed independently:

- A delegate **without a mailbox** is skipped during the preflight check and counted as *skipped*; the remaining delegates are still processed. If none of the selected delegates has a mailbox, the run stops.
- A delegate whose change **fails** is reported with a targeted reason (directory-replication delay, insufficient Exchange Online permissions on the managed identity, a permission inherited from a group, or a shared/unlicensed mailbox) and the loop continues with the rest.

Every run ends with a summary line in the form `Summary: <changed>, <unchanged>, <failed>, <skipped (no mailbox)>`, followed by the resulting FullAccess delegations on the mailbox.

If **any** delegate failed, the runbook itself reports a failure. This is deliberate: with a multi-select picker, a partial success reported as a clean run would hide delegates that never received access.

### Limitations

- **Inherited permissions cannot be removed.** A FullAccess right that comes from a role group or security group membership is shown as *inherited* but cannot be revoked here - adjust the group membership or role assignment instead.
- **Only explicit Allow grants are managed.** An explicit **Deny** entry on the mailbox is displayed for transparency, but the runbook never adds or removes one.

### Prerequisites

The Automation account's managed identity connects to Exchange Online via `Connect-RjRbExchangeOnline` and needs:

- the `Exchange.ManageAsApp` application permission on *Office 365 Exchange Online*, and
- the **Exchange Administrator** role (or an equivalent Exchange Online RBAC role that includes `Add-MailboxPermission` and `Remove-MailboxPermission`).

The runbook makes no Microsoft Graph calls - the user picker is a portal-side annotation only, so no Graph application permissions are required.



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-delegate-send-as'></a>

### Delegate Send As
#### Grant or remove Send As permission on this user's mailbox

#### Description

Lets another person send email as this user, so messages appear to come from this mailbox, or removes that permission again. The permissions are shown before and after the change.

#### Where to find

User \ Mail \ Delegate Send As


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-delegate-send-on-behalf'></a>

### Delegate Send On Behalf
#### Grant or remove Send on Behalf permission on this user's mailbox

#### Description

Lets another person send email on behalf of this user, so recipients see the delegate's name with "on behalf of" this user, or removes that permission again. The resulting list of trustees is shown after the change.

#### Where to find

User \ Mail \ Delegate Send On Behalf


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-hide-or-unhide-in-addressbook'></a>

### Hide Or Unhide In Addressbook
#### Hide this user's mailbox in the address book or show it

#### Description

Hides the mailbox of this user from the global address list or shows it again. A hidden mailbox still receives email; it just does not appear when people browse the address book. The change can take up to 72 hours to show in the address list.

#### Where to find

User \ Mail \ Hide Or Unhide In Addressbook


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-list-mailbox-permissions'></a>

### List Mailbox Permissions
#### List who has access to this user's mailbox

#### Description

Shows who has permissions on the mailbox of this user: full access, Send As and Send on Behalf, each as a table. Works for shared mailboxes as well. Nothing is changed.

#### Where to find

User \ Mail \ List Mailbox Permissions


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-list-room-mailbox-configuration'></a>

### List Room Mailbox Configuration
#### Show the booking configuration of this room mailbox

#### Description

Shows the room details and the calendar processing settings of this room mailbox, such as how booking requests are handled. Nothing is changed.

#### Where to find

User \ Mail \ List Room Mailbox Configuration


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-manage-archive-mailbox'></a>

### Manage Archive Mailbox
#### Enable, disable or check the archive mailbox of this user

#### Description

Enables or disables the in-place archive mailbox of this user, or shows its current status. Nothing changes when the mailbox is already in the requested state. When enabling, an archive that was disabled within the last 30 days is reconnected instead of creating a new one.

#### Where to find

User \ Mail \ Manage Archive Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-remove-mailbox'></a>

### Remove Mailbox
#### Permanently delete this shared mailbox, room or Bookings calendar

#### Description

Deletes this shared mailbox, room mailbox or Bookings calendar for good. Before deleting, the runbook checks that the mailbox really is one of these types; regular user mailboxes are refused. The mailbox and its content are not recoverable afterwards.

#### Where to find

User \ Mail \ Remove Mailbox


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-set-out-of-office'></a>

### Set Out Of Office
#### Set or remove automatic replies for this user

#### Description

Turns on automatic replies for the mailbox of this user, with separate messages for people inside and outside the organization and for a period you choose. A matching out-of-office entry can be added to the calendar. Existing automatic replies can also be switched off again; a calendar entry created earlier is not removed.

#### Where to find

User \ Mail \ Set Out Of Office


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-mail-set-room-mailbox-configuration'></a>

### Set Room Mailbox Configuration
#### Configure the booking rules of this room mailbox

#### Description

Sets the booking rules of this room mailbox: who may book it, whether recurring meetings and conflicts are allowed, and how requests are processed. It also sets how far ahead and how long meetings may be, and the room capacity. All booking settings are written as shown; the capacity only when it is greater than 0.

#### Where to find

User \ Mail \ Set Room Mailbox Configuration


[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-phone'></a>

## Phone
<a name='user-phone-disable-teams-phone'></a>

### Disable Teams Phone
#### Remove Teams phone number and voice policies from this user

#### Description

Takes the assigned phone number away from this user and clears the Teams voice policies, so the user can no longer make or receive phone calls through Teams.

#### Where to find

User \ Phone \ Disable Teams Phone


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-phone-get-teams-user-info'></a>

### Get Teams User Info
#### Show the Teams voice setup of this user

#### Description

Shows the telephony setup of this user in Teams: the assigned phone number, call forwarding, voicemail, the assigned voice policies and call queue membership. Nothing is changed.

#### Where to find

User \ Phone \ Get Teams User Info


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-phone-grant-teams-user-policies'></a>

### Grant Teams User Policies
#### Assign Teams voice and meeting policies to this user

#### Description

Assigns Teams policies to this user: voice routing, dial plan, calling, IP phone, voicemail, meeting and live event policies. Only the policies you fill in are changed. Enter Global (Org Wide Default) to remove an assignment and fall back to the tenant default.

#### Where to find

User \ Phone \ Grant Teams User Policies


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-phone-set-teams-permanent-call-forwarding'></a>

### Set Teams Permanent Call Forwarding
#### Forward this user's calls immediately or turn forwarding off

#### Description

Sets up immediate call forwarding for this Teams Enterprise Voice user to another Teams user, a phone number, voicemail or the user's own delegates. It can also switch immediate forwarding off again. Unanswered-call handling is turned off at the same time.

#### Where to find

User \ Phone \ Set Teams Permanent Call Forwarding


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-phone-set-teams-phone'></a>

### Set Teams Phone
#### Assign a phone number and voice policies to this user

#### Description

Assigns a phone number to this Teams user and optionally sets the voice routing policy, dial plan, calling policy and IP phone policy. Only the policies you fill in are changed. Enter Global (Org Wide Default) to remove an assignment and fall back to the tenant default.

#### Where to find

User \ Phone \ Set Teams Phone


[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-security'></a>

## Security
<a name='user-security-confirm-or-dismiss-risky-user'></a>

### Confirm Or Dismiss Risky User
#### Confirm this user as compromised or dismiss the risk

#### Description

Tells Microsoft Entra ID Protection what to do with the risk flagged on this user. Confirm compromise marks the account as compromised, which sets the user risk to high. Dismiss risk clears the flag when the activity was legitimate.

#### Where to find

User \ Security \ Confirm Or Dismiss Risky User


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-create-temporary-access-pass'></a>

### Create Temporary Access Pass
#### Create a Temporary Access Pass for this user

#### Description

Creates a Temporary Access Pass (TAP) for this user, so they can sign in and set up their authentication methods without a password. Any existing pass is removed first and the new pass is shown in the runbook output. Optionally the user gets an email with the pass, in German for usage location DE and otherwise in English.

#### Where to find

User \ Security \ Create Temporary Access Pass

## Activate user notification

This runbook sends an email to the user with the temporary access pass. To enable this, you need to activate user notification in the runbook customization.

The json configuration for this is as follows:

```json
"rjgit-user_security_create-temporary-access-pass": {
    "parameters": {
        "UserName": {
            "Hide": true
        },
        "NotifyUser": {
            "Default": true,
            "Hide": true
        },
        "EmailFrom": {
            "Hide": true
        },
        "ServiceDeskDisplayName": {
            "Hide": true
        },
        "ServiceDeskEmail": {
            "Hide": true
        },
        "ServiceDeskPhone": {
            "Hide": true
        },
        "ServiceDeskPortalUrl": {
            "Hide": true
        },
        "ServiceDeskTicketUrl": {
            "Hide": true
        },
        "CallerName": {
            "Hide": true
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).

## Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-enable-or-disable-password-expiration'></a>

### Enable Or Disable Password Expiration
#### Turn password expiration on or off for this user

#### Description

Sets whether the password of this user expires. Turning expiration off keeps the current password valid indefinitely, for example for service or shared accounts; turning it on restores the tenant's default expiration.

#### Where to find

User \ Security \ Enable Or Disable Password Expiration


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-list-mfa-methods'></a>

### List MFA Methods
#### List the MFA and authentication methods of this user

#### Description

Shows every authentication method registered for this user in Entra ID, including the phone numbers of phone-based methods. Phone numbers can be masked to their last four digits. Optionally the user gets an email that an administrator has looked at their methods. Nothing is changed.

#### Where to find

User \ Security \ List MFA Methods

## Privacy and audit

This runbook reads sensitive identity data: the registered MFA methods of a user, including phone numbers. Phone numbers are masked by default. Set `MaskPhoneNumbers` to `false` only when the full numbers are required for legitimate support purposes; the action is logged together with the caller name.

## Activate user notification

This runbook can optionally send a notification email to the target user informing them that their MFA methods were retrieved by an administrator. To enable this, you need to activate user notification in the runbook customization.

The json configuration for this is as follows:

```json
"rjgit-user_security_list-mfa-methods": {
    "parameters": {
        "UserName": {
            "Hide": true
        },
        "NotifyUser": {
            "Default": true,
            "Hide": true
        },
        "MaskPhoneNumbers": {
            "Hide": true
        },
        "EmailFrom": {
            "Hide": true
        },
        "ServiceDeskDisplayName": {
            "Hide": true
        },
        "ServiceDeskEmail": {
            "Hide": true
        },
        "ServiceDeskPhone": {
            "Hide": true
        },
        "ServiceDeskPortalUrl": {
            "Hide": true
        },
        "ServiceDeskTicketUrl": {
            "Hide": true
        },
        "LanguageOverride": {
            "Hide": true
        },
        "CallerName": {
            "Hide": true
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).

## Setup regarding email sending

Sending a notification email is optional and only happens when `NotifyUser` is enabled. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-list-signin-events'></a>

### List Signin Events
#### Show the recent sign-ins of this user and their failures

#### Description

Lists the Entra ID sign-ins of this user for the chosen number of days with application, time, result, client app, device and location. Failures are summed up per application so support can see where sign-ins go wrong, and failed sign-ins also show the IP address. The report can be sent by email or provided as a download link.

#### Where to find

User \ Security \ List Signin Events

## Common use cases

- Investigate which application generates sign-in failures for a specific user and why, grouped by error code.
- Narrow the results with `ApplicationName` (partial match) or `FailedSignInsOnly` when a user reports access issues.
- Export the sign-in data to CSV or Excel for further analysis when the event count is too large to read in the portal.

## Behaviour

- Sign-in log data is retrieved from the Microsoft Graph beta endpoint, because sign-in event type filtering and the retrieval of non-interactive sign-ins require beta-only properties (`signInEventTypes`, `authenticationRequirement`).
- Non-interactive sign-ins vastly outnumber interactive ones; the console detail tables are capped at the 50 most recent entries, but the exported report files always contain the full result set.

## Required license and permissions

Reading sign-in logs through the Microsoft Graph API requires an **Entra ID P1 or P2 license** in the tenant. Tenants without it receive a 403 error from the sign-in log query even when all Graph permissions are granted. With P1/P2, sign-in logs are retained for up to 30 days; the 7-day retention of the free tier applies to the Entra portal, not to this runbook.

If the sign-in log query returns a 403 although `AuditLog.Read.All` is granted and the tenant is licensed, some tenants additionally require `Directory.Read.All` on the Entra reporting API. Granting it is the known workaround; it is not declared by default because it grants read access to every directory object.

## Report delivery

Report files are only generated when a delivery method is selected via the **Report delivery** option (email and/or download link). With *No report* selected, the sign-in analysis is read directly in the RealmJoin portal output. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

## Setup regarding email sending

Sending an email report is optional and only happens when the *Email report* delivery option is selected; a recipient (`EmailTo`) is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## Interpreting the results

Entra counts some sign-in interrupts as errors (for example 50140 "Keep me signed in", 50058 and 50076), so they appear as failures and are included in the per-application failure rate. Check the failure reason before treating a high failure rate as a genuine problem. Error codes are Entra ID sign-in error codes; look them up at [https://login.microsoftonline.com/error](https://login.microsoftonline.com/error).

Sign-in log data typically lags ~15 minutes but can take up to 2 hours for some records - a very recent sign-in may not yet appear. All timestamps are shown in UTC.



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-reset-mfa'></a>

### Reset MFA
#### Remove this user's app, phone, OATH and FIDO2 MFA methods

#### Description

Removes the authenticator app, phone, software OATH token and FIDO2 security key methods of this user, so they have to register MFA again at the next sign-in. Optionally the user gets an email about the reset.

#### Where to find

User \ Security \ Reset MFA

## Activate user notification

This runbook can optionally send a notification email to the target user informing them that their MFA methods were reset by an administrator. To enable this, you need to activate user notification in the runbook customization.

The json configuration for this is as follows:

```json
"rjgit-user_security_reset-mfa": {
    "parameters": {
        "UserName": {
            "Hide": true
        },
        "NotifyUser": {
            "Default": true,
            "Hide": true
        },
        "EmailFrom": {
            "Hide": true
        },
        "ServiceDeskDisplayName": {
            "Hide": true
        },
        "ServiceDeskEmail": {
            "Hide": true
        },
        "ServiceDeskPhone": {
            "Hide": true
        },
        "ServiceDeskPortalUrl": {
            "Hide": true
        },
        "ServiceDeskTicketUrl": {
            "Hide": true
        },
        "LanguageOverride": {
            "Hide": true
        },
        "CallerName": {
            "Hide": true
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).

## Setup regarding email sending

Sending a notification email is optional and only happens when `NotifyUser` is enabled. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).



[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-reset-password'></a>

### Reset Password
#### Set a new password for this user

#### Description

Sets a new password for this user in Entra ID and shows it in the output. A disabled account can be enabled first, and the user can be made to choose their own password at the next sign-in.

#### Where to find

User \ Security \ Reset Password


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-revoke-or-restore-access'></a>

### Revoke Or Restore Access
#### Block this user's sign-in and sessions, or restore access

#### Description

Blocks this user from signing in and ends the current sessions, so stolen tokens stop working immediately, for example during an incident. Re-enable user lifts the block again; ended sessions are not restored.

#### Where to find

User \ Security \ Revoke Or Restore Access


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-security-set-or-remove-mobile-phone-mfa'></a>

### Set Or Remove Mobile Phone MFA
#### Set or remove the mobile phone MFA method of this user

#### Description

Adds or updates the mobile phone of this user as an MFA method for calls and text messages, or removes it. Optionally the user gets an email about the change. When the tenant allows SMS sign-in, Microsoft also tries to register the number for it. A number already used by someone else then produces a warning; the MFA method is usually still set, and the runbook checks and reports the real state. Details on that conflict are in the runbook documentation (docs.realmjoin.com).

#### Where to find

User \ Security \ Set Or Remove Mobile Phone MFA

## Activate user notification

This runbook can optionally send a notification email to the target user informing them that their mobile phone MFA method was added, updated, or removed by an administrator. To enable this, you need to activate user notification in the runbook customization.

The json configuration for this is as follows:

```json
"rjgit-user_security_set-or-remove-mobile-phone-mfa": {
    "parameters": {
        "UserId": {
            "Hide": true
        },
        "NotifyUser": {
            "Default": true,
            "Hide": true
        },
        "EmailFrom": {
            "Hide": true
        },
        "ServiceDeskDisplayName": {
            "Hide": true
        },
        "ServiceDeskEmail": {
            "Hide": true
        },
        "ServiceDeskPhone": {
            "Hide": true
        },
        "ServiceDeskPortalUrl": {
            "Hide": true
        },
        "ServiceDeskTicketUrl": {
            "Hide": true
        },
        "LanguageOverride": {
            "Hide": true
        },
        "CallerName": {
            "Hide": true
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).

## Setup regarding email sending

Sending a notification email is optional and only happens when `NotifyUser` is enabled. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** – public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** – target of the footer image
- **Accent and text color** – 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email – the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## SMS sign-in conflicts

The Microsoft Graph phone methods API offers no way to add a phone number as an MFA-only method without Microsoft also attempting to register it for SMS sign-in. When the user is enabled for SMS sign-in by the tenant's authentication methods policy, Graph tries that registration right after the phone method is created or updated. If another user already uses the number for SMS sign-in, Graph answers with a `409 Conflict` and the error code `phoneNumberNotUnique`, although the phone method for regular MFA is usually created or updated anyway.

The `smsSignInState` property is read-only and cannot be set in the create or update request; SMS sign-in can only be switched explicitly through the separate `enableSmsSignIn` and `disableSmsSignIn` endpoints. The runbook therefore checks the real state after such an error and reports success with a warning when the MFA method was assigned. If the assignment really failed, it looks up the user who holds the number and names them in the output.



[Back to Table of Content](#table-of-contents)

 
 

<a name='user'></a>

# User
<a name='user-userinfo'></a>

## Userinfo
<a name='user-userinfo-rename-user'></a>

### Rename User
#### Change this user's sign-in name (UPN) and mailbox alias

#### Description

Gives this user a new user principal name in Entra ID and, optionally, updates the mailbox alias and the primary email address in Exchange Online to match. Display name, given name and surname are not touched.

#### Where to find

User \ Userinfo \ Rename User


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-userinfo-set-photo'></a>

### Set Photo
#### Set the profile photo of this user from a URL

#### Description

Downloads a JPEG image from the given URL and sets it as the profile photo of this user. The photo shows up in Microsoft 365 apps such as Teams and Outlook. An existing photo is replaced.

#### Where to find

User \ Userinfo \ Set Photo


[Back to Table of Content](#table-of-contents)

 
 

<a name='user-userinfo-update-user'></a>

### Update User
#### Update profile details, groups and mailbox settings of this user

#### Description

Updates the profile of this user in Entra ID, such as name, company, address, job title and manager. It can also add the user to a license group and further groups, enable the Exchange Online archive and reset the password. Only the fields you fill in are changed; a missing display name or company is filled in automatically.

#### Where to find

User \ Userinfo \ Update User

## Offer locations, companies, licenses and departments as templates

Most fields of this runbook are free text. With runbook customization templates the operator picks from predefined lists instead, and a location template can fill in and lock the whole address block. The example below defines such templates and binds them to the runbook's fields:

```json
"Templates": {
    "Options": [
        {
            "$id": "LocationOptions",
            "$values": [
                {
                    "Display": "Contoso DE",
                    "Value": "ContosoDe",
                    "Customization": {
                        "Default": {
                            "StreetAddress": "Demostr. 22",
                            "PostalCode": "80333",
                            "City": "Munich",
                            "State": "Bavaria",
                            "Country": "Germany",
                            "UsageLocation": "DE"
                        },
                        "ReadOnly": [
                            "StreetAddress",
                            "PostalCode",
                            "City",
                            "Country",
                            "UsageLocation"
                        ]
                    }
                }
            ]
        },
        {
            "$id": "CompanyOptions",
            "$values": [
                {
                    "Display": "CONTOSO",
                    "Value": "Contoso"
                }
            ]
        },
        {
            "$id": "LicenseOptions",
            "$values": [
                {
                    "Display": "M365 E3 + E5 Security + Audio Conferencing",
                    "Value": "LIC_M365_E3&E5_SecurityPlan&AudioConf"
                },
                {
                    "Display": "none",
                    "Value": ""
                }
            ]
        },
        {
            "$id": "DepartmentOptions",
            "$values": [
                {
                    "Display": "M&A",
                    "Value": "M&A"
                },
                {
                    "Display": "Tax & Legal",
                    "Value": "Tax & Legal"
                },
                {
                    "Display": "Controlling & Operations",
                    "Value": "Controlling & Operations"
                },
                {
                    "Display": "IT",
                    "Value": "IT"
                },
                {
                    "Display": "Communications",
                    "Value": "Communications"
                },
                {
                    "Display": "Strategy & Management",
                    "Value": "Strategy & Management"
                },
                {
                    "Display": "Accounting",
                    "Value": "Accounting"
                },
                {
                    "Display": "Insurance",
                    "Value": "Insurance"
                },
                {
                    "Display": "Treasury",
                    "Value": "Treasury"
                }
            ]
        }
    ]
},
"Runbooks": {
    "rjgit-user_userinfo_update-user": {
        "ParameterList": [
            {
                "Name": "LocationName",
                "DisplayName": "Office Location",
                "DisplayBefore": "StreetAddress",
                "Select": {
                    "Options": {
                        "$ref": "LocationOptions"
                    }
                },
                "Default": "ContosoDe"
            },
            {
                "Name": "CompanyName",
                "Select": {
                    "Options": {
                        "$ref": "CompanyOptions"
                    },
                    "AllowEdit": false
                },
                "Default": "Contoso"
            },
            {
                "Name": "DefaultLicense",
                "DisplayName": "License",
                "Select": {
                    "Options": {
                        "$ref": "LicenseOptions"
                    },
                    "AllowEdit": true
                },
                "Default": "LIC_M365_E3&E5_SecurityPlan&AudioConf"
            },
            {
                "Name": "Department",
                "Select": {
                    "Options": {
                        "$ref": "DepartmentOptions"
                    },
                    "AllowEdit": true
                }
            },
            {
                "Name": "ResetPassword",
                "Hide": true
            },
            {
                "Name": "DefaultGroups",
                "Default": "app - 7-Zip,app - Adobe Reader DC Continuous Track,app - glueckkanja-gab KONNEKT"
            }
        ]
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).



[Back to Table of Content](#table-of-contents)

 
 


# RealmJoin Runbooks Changelog

## 2026-02-25
- Update documentation for Notify Users About Stale Devices (Scheduled) Runbook
  - Added detailed instructions for email configuration and custom mail template usage in the runbook documentation to enhance clarity and usability for users setting up email notifications.
  - Added Mail Template Language Selection section (EN, DE, Custom)
  - Add **Show Bitlocker Recovery Key** Runbook to Device/Security section
   - This runbook retrieves and displays the BitLocker recovery key for a specified device.

## 2026-02-24

- Update **Unenroll Updatable Assets** to **Unenroll Updatable Assets (Scheduled)** (in group/general)
  - Add option to include user owned devices in the unenrollment process, which allows for a more comprehensive management of updatable assets by optionally targeting devices that are owned by users which are in membership of the specified group.
- Update **List Admin Users** Runbook
  - Add output of PIM role assignment status (permanent vs eligible) and expiration date to the runbook output and CSV export.

## 2026-02-20

- Add two new Endpoint Privilege Management (EPM) runbooks for org/security:
  - **Monitor Pending EPM Requests (Scheduled)**: Monitoring for pending elevation requests requiring admin review. Sends email notifications only when pending requests exist, includes optional detailed CSV export.
  - **Report EPM Elevation Requests (Scheduled)**: Reporting for EPM elevation requests with flexible filtering by status (Pending, Approved, Denied, Expired, Revoked, Completed) and time range.
- Update **Export All Intune Devices** Runbook
  - Fix issue, regarding some properties if the device primary user data is missing or incomplete
  - Add filtering option to only include devices that are members of a specific group to avoid exporting all devices in large tenants and to focus on relevant devices.
- Complete overhaul of the comment-based help in **all runbooks** to improve clarity, consistency and detail of the documentation, including:
  - More detailed descriptions of the runbooks' functionality and parameters
  - Clearer instructions for required permissions and setup steps
  - Improved formatting for better readability
- Removed **Report Last Device Contact by Range** Runbook, as the functionality is now covered by the updated **Report Stale Devices (Scheduled)** Runbook with enhanced filtering options.
- Add **Notify Users About Stale Devices (Scheduled)** Runbook, which sends email notifications to users with stale devices based on last activity date and platform. This runbook complements the reporting functionality by proactively notifying users about their stale devices and providing guidance for remediation.
- Update **Report Stale Devices (Scheduled)** Runbook, Include/Exclude User Groups

## 2026-02-04

- Update documentation for permissions used by the Application Registration runbooks
  - Replaced the required app role assignment **Application.ReadWrite.All** with **Application.ReadWrite.OwnedBy** to improve security.
  - Removed **Directory.ReadWrite.All**, as it is not required for the operations performed by these runbooks.

## 2026-01-30

- Update org/devices/outphase-devices Runbook
  - Added handling for serial numbers not found in Intune, but provided for outphasing regarding autopilot devices.

## 2026-01-27

- Update RealmJoin.RunbookHelper to v0.8.5 in all runbooks
- Remove redundant email functions following runbooks:
  - org/applications/report-expiring-application-credentials_scheduled
  - org/devices/report-devices-without-primary-user
  - org/devices/report-last-device-contact-by-range
  - org/devices/report-stale-devices_scheduled
  - org/devices/report-users-with-more-than-5-devices
  - org/general/report-apple-mdm-cert-expiry_scheduled
  - org/general/report-license-assignment_scheduled

## 2026-01-22

- Update Show LAPS Password Runbook
  - Add check for empty credentials to prevent script failure when no LAPS password exists
- Update List Admin Users Runbook
  - Add info, if PIM role assignments are permanent or eligible and their expiration date
  - Add switch to also enhance the csv export

## 2026-01-07

- Fix error handling in list inactive enterprise applications runbook
- Add parameter validation to rename device runbook

## 2026-01-06

- Update Graph PowerShell Module to 2.34.0 in following runbooks:
  - device/general/remove-primary-user
  - group/general/list-all-members
  - org/applications/report-application-registration
  - org/applications/report-expiring-application-credentials_scheduled
  - org/devices/report-devices-without-primary-user
  - org/devices/report-last-device-contact-by-range
  - org/devices/report-stale-devices_scheduled
  - org/devices/report-users-with-more-than-5-devices
  - org/general/Invite-external-guest-users
  - org/general/add-security-group
  - org/general/export-policy-report
  - org/general/report-apple-mdm-cert-expiry_scheduled
  - org/general/report-license-assignment_scheduled
  - org/security/list-users-by-MFA-methods-count

## 2025-12-30

- Add handling for skipping role and on-premises groups in offboarding scripts in following runbooks:
  - user/general/offboard-user-permanently
  - user/general/offboard-user-temporarily
  - user/mail/convert-to-shared-mailbox

## 2025-12-12

- Fix nested group handling in Add Devices of Users to Group (scheduled) Runbook

## 2025-11-20

- Add Report License Assignment Runbook (scheduled)
  - Thresholds for license availability reporting:
    - Minimum threshold: Alert when available licenses fall below this number
    - Maximum threshold: Alert when available licenses exceed this number

## 2025-11-13

- Enhance CSS part in all reporting runbooks
- Update PowerShell module version in all reporting runbooks

## 2025-11-10

- New Add or Remove Tenant Allow/Block List Runbook
- Update Teams PowerShell Module to 7.5.0 in all Teams Phone Runbooks
- Separate Exchange Module definitions

## 2025-11-06

- Update Set or Remove Mobile Phone MFA Runbook
  - Clarify phone number format in description and parameter help

## 2025-10-22

- Update Add Shared Mailbox Runbook
  - Add functionality to add shared mailbox with same alias but different domain
- Add List Group Memberships Runbook

## 2025-10-16

- Update Report Apple MDM Cert Expiry (scheduled) Runbook
  - Update regarding new email functions
- Update Report Devices Without Primary User Runbook
  - Update regarding new email functions
- Update Report Users With More Than Five Devices Runbook
  - Update regarding new email functions
- Update Report Last Device Contact By Range Runbook
  - Update regarding new email functions
- Update List Stale Devices Runbook
  - Update regarding new email functions
- Update general mail setup documentation
  - Improve clarity and detail on email configuration steps
- Upgrade to List Application Credentials Expiry to Report Expiring Application Credentials (Scheduled) Runbook


## 2025-10-06

- Update List Application Runbook
- Add Resource Account License Check to Get Teams User Info and Set Teams Phone Runbooks

## 2025-09-26

- Add runbook in Org/Applications
  - Updated/Added Versions add, update, delete and list application registrations

## 2025-08-27

- Add AVD runbook
  - device/avd/restart-host
    - Restart the AVD Session Host.
  - device/avd/toggle-drain-mode
    - Sets Drainmode on true or false for a specific AVD Session Host.
  - user/avd/user-signout
    - Removes (Signs Out) a specific User from their AVD Session.

## 2025-07-21

- Add runbook in Org/Devices:
  - "Delete stale devices (scheduled)"
    - Scheduled deletion of stale devices based on last activity date and platform.
    - Can be scheduled to run automatically and send a report via email.
  - "List stale devices (scheduled)"
    - Scheduled report of stale devices based on last activity date and platform.
    - Automatically sends a report via email.
  - "Sync device serial numbers to Entra ID (scheduled)"
    - Syncs serial numbers from Intune devices to Entra ID device extension attributes.
    - Helps maintain consistency between Intune and Entra ID device records.

## 2025-06-18

- Add runbook in Org/General:
  - "Invite external guest users"
    - Invite external guest users to the tenant and optionally add them to a specified group.
  - "Remove primary user"
    - Remove the primary user from devices in Intune.

## 2025-06-16

- Add runbook in Org/Devices:
  - "Report Last Device Contact by Range"
    - Get the devices based on the last device contact date and time, grouped by the specified ranges.
    - Also includes the filtering options for operating system.
  - "Report Users with more than five devices"
    - Get the users with more than five devices enrolled in Intune.
  - "Report devices without primary user"
    - Get the devices without a primary user assigned in Intune.

## 2025-05-02

- Update RealmJoin.RunbookHelper to v0.8.4 in all runbooks

## 2025-04-22

- Add documentation workflow and scripts to the repository

## 2025-03-05

- Update User/Phone/Set Teams permanent call forwarding
  - Make sure, that unanswered calls settings would be disabled before setting the forwarding

## 2025-02-24

- Update all phone related runbooks:
  - Teams PowerShell module updated to 6.8.0
  - Add Permissions in .Notes section
  - Remove outdated service user (credential) based connection
  - Update version number

## 2025-02-19

- New Runbook: Org/Phone/Get Teams Phone Number Assignment - Get the phone number assignment of the specified phone number and output the user if assigned

## 2025-02-13

- Update Runbook org/devices/ "outphase-devices" - add support for serialnumbers

## 2025-02-12

- Fix: add-devices-of-users-to-group_scheduled - add AndroidForWork condition

## 2025-02-11

- New Runbook: Group/General/List all members - list members of a specified EntraID group, including members from nested groups

## 2025-01-24

- Check UpdateAbleAssets (device and group): Adapted to new graph response, general rework
- Minor fixes (like typos) to multiple runbooks

## 2025-01-15

- Update Runbook: get-teams-user-info
  - Version 1.0.1
  - Changes:
    - Add support for group based policy assignment
    - Suppress warning for getting Call Queues
    - Enhance output for policies (TeamsVoiceApplicationsPolicy,CurrentTeamsSharedCallingRoutingPolicy)
    - Add current UsageLocation (important for Teams Dial Plan)
    - Update Teams PowerShell module version to 6.7.0
    - Add regions in the script
    - Remove old credential based connect from the Teams PowerShell Module

## 2024-12-05

- Add version info to all runbooks

## 2024-11-19

- Fix: Add devices of users to group: Filters for iOS/iPadOS updated

## 2024-11-27

- New Runbook: Multi-Device Outphasing

## 2024-11-14

- New Runbook: Add/remove a nested group to/from a group.

## 2024-11-11

- New Runbook: List all Administrative Template Policies

## 2024-11-08

- Updated runbook "Enroll updatableAssets" and moved to device

## 2024-11-07

- Fix: Autopilot Bulk Delete: Not all devices found.

## 2024-11-05

- New Runbook: Get BitLocker recovery key

## 2024-10-31

- Check/Unenroll-UpdateAbleAssets: Added option to unenroll from all categories. Several improvements in output and error handling. Bug fixes.

## 2024-10-30

- Check/Unenroll-UpdateAbleAssets: Relocated to groups and devices.
- Unenroll-UpdateAbleAssets: Fix issue with JSON encoding.

## 2024-10-28

- Get Teams User Info: Voicemail and CallQueue status added. Extended license check - is the application active in the license?
- All user/phone runbooks: Update MicrosoftTeams module

## 2024-10-21

- Add Security Group: Allowed characters for security groups added, Update of the required PowerShell module (newer version)

## 2024-10-14

- Fix: Show LAPS Password fails - MS Graph API change

## 2024-10-01

- New Runbook: Add Security Group

## 2024-10-07

- New Runbook: Add Microsoft Store App Logos

## 2024-10-12

- Fix: Export Policy Reports: Fixed issue where empty descriptions in settings would break the export.

## 2024-08-27

- New Runbook: Bulk retire devices from Intune
- New Runbook: Check Updatable Assets

## 2024-07-09

- New runbook: Check Assignments Of Users
- New runbook: Check Assignments Of Groups
- New runbook: Check Assignments Of Devices
- Resize W365: Added mail customization
- Resize W365: Fixed Info box
- Reporovision W365: Added mail customization

## 2024-06-20

- Add Devices Of Users To Group (Scheduled)
- Report Apple Mdm Cert Expiry
- List Application Creds Expiry - Supports App ID Filtering
- Allow "Enrolled Devices Report" to be scheduled

## 2024-06-19

- Moved "Check Device Onboarding Exlusion" into to repo
- Bulk Delete Devices From Autopilot
- Check AAD Sync Status
- Report Pim Activations
- Update: Export All Autopilot Devices

## 2024-06-12

- Office365 Support: Supprt for custom Azure Subscription ID
- Export Non Compliant Devices: Support for custom Azure Subscription ID
- Export All Intune Devices: Support for custom Azure Subscription ID

## 2024-06-04

- Fixed: Failed to add/remove owners from groups.

## 2024-04-05

- Set Room Mailbox Configuration: Only allow MailEnabled groups

## 2024-03-06

- Fix: Teams Phone Runbooks: Update phone number validation to include extension format

## 2024-03-01

- Fix: Convert to Shared Mailbox: Did not remove all groups
- Fix: Offboard User: Did not remove all groups

## 2024-02-29

- Show LAPS PW: Fix LAPS password retrieval and display device name

## 2024-02-28

- Updates to Teams Phone Runbooks

## 2024-02-20

- Export all Intune Devices: Added more fields (CompanyName and JobTitle)

## 2024-01-15

- New Runbook: Export all AutoPilot devices

## 2024-01-12

- Wipe Device: Support MacOS Obliteration Modes

## 2023-12-07

- Add/Remove Mail Address: Fix - Could not remove address

## 2023-12-05

- All Phone Runbooks: Update module versions and add validation for user input

## 2023-11-24

- Add Shread/Room/Equip. Mailbox: Add mailbox creation wait logic

## 2023-11-14

- List Mailbox Permissions: Only list Trustees with a mailbox in this tenant.
- Reset MFA: Handle token becoming invalid after failed auth. method deletion

## 2023-11-13

- (Un)Assign License: (fixed) Group prefix was case sensitive.
- Update User: (fixed) Fails if a group is not found.

## 2023-10-26

- List Inactive Devices: Fixed: Failed if the primary owner has been deleted from AAD.
- Assign groups by template: Performance improvements

## 2023-10-20

- Set User Photo: (fixed) Updated API Call

## 2023-10-17

- New Runbook: List a device's LAPS credentials (i.e. local admin passwords)

## 2023-09-28

- Avoid failed runs due to a known issue in Azure Automation / Avoid module dependency in param block

## 2023-09-18

- Update to RJRBHelper v0.8.3 - Fix problems with newer Azure Automation Containers

## 2023-09-07

- Teams Phone Runbooks: Bugfix (variables cleanup)

## 2023-08-18

- New Runbook: Assign groups by template (user and group scope)
- New Runbook: Reset mobile device PIN

## 2023-08-11

- Export Policy Report - Compatibility with Microsoft Graph PowerShell Module 2.x
- Updated Phone Runbooks

## 2023-08-04

- Updated Phone Runbooks

## 2023-08-02

- Updated Phone Runbooks

## 2023-07-20

- Set Out-of-Office: Allow blocking calendar for the Out-of-Office period

## 2023-07-19

- Export CloudPC Usage: Updated to reflect API changes.

## 2023-07-13

- New Runbook: Submit Defender Threat Indicator / Hash

## 2023-07-11

- New Runbook: Rename Device in Intune and Autopilot

## 2023-06-28

- Assign Windows 365 - Support FrontLine Worker (Shared Use Service Plan) Cloud PCs
- Unassign Windows 365 - Support FrontLine Worker (Shared Use Service Plan) Cloud PCs

## 2023-06-26

- Resize Windows 365 - Bugfix: Will not remove User Setting / Provisioning Policy

## 2023-06-21

- Export Policy Report - Ignore Cyrillic characters (as PanDocs does not support them).

## 2023-06-20

- Wipe Device: Support for Protected Wipe

## 2023-06-19

- Convert to Shared Mailbox - Dis-/Enable User on conversion and fixed potential issue with missing steps

## 2023-06-16

- Add equipment/room/shared mailbox: AAD user object is disabled by default.

## 2023-06-15

- Require update of RealmJoin.RunbookHelper to 0.8.1 prevent potential token leakage.
- New Runbook: Add Viva Engage (Yammer) Community

## 2023-05-26

- New Runbook: List/Export all non-compliant devices in Intune and corresponding compliance policies/settings
- Bugfix: List Admin Users: Some role assignments were not listed
- Change Exports to use ";" as delimiter and UTF8 file format for all runbooks

## 2023-05-11

- Assign Win365: Support long deployment times
- Convert to shared mailbox: Skip removing on-prem synced groups

## 2023-04-25

- New Runbook: Create an Application Registration

## 2023-03-29

- List inactive users: Supports listing users that have never logged on.
- New runbook: List PIM groups without owners

## 2023-03-28

- New Runbook: Create a report on a tenant's Intune and Conditional Access Policies

## 2023-03-23

- Configure Room Mailboxes: Allows setting Capacity
- Reprovision and Resize available for Windows 365 management

## 2023-03-15

- Added audit logging info to phone runbooks

## 2023-03-07

- Teams Phone: Update all user/phone runbook. Update to Teams Module v5. Better error handling.

## 2023-02-14

- Update User: Support User Templates, Group Management, PW Reset

## 2023-02-07

- New Runbook: Export CloudPC Usage Statistics

## 2023-02-01

- New Runbook: Remove Room/Shared/Booking Mailbox

## 2023-01-31

- New Feature: Assign/Unassign Windows365 Cloud PCs

## 2023-01-30

- New Feature: Manage MS Bookings
- New Runbook: set-booking-config: Enable Bookings (tenant-wide)

## 2023-01-13

- New Runbook: Sync all Intune Devices

## 2022-12-22

- Add Autopilot Device: Support assigning (optional) GroupTag

## 2022-12-02

- Report SPO Shared Links: Support anon. links

## 2022-12-01

- Import a device into Intune via corporate identifier.
- Add/remove user (from/to group): Support EXO based groups (Distribution Lists and Mail-enabled Sec. Groups)

## 2022-11-30

- Add shared mailbox: Option to localize new mailboxes.

## 2022-11-29

- Report SPO Shared Links: Support for private channels added

## 2022-11-28

- New runbook: Report extern. shared links in all teams to the respective teams owners

## 2022-11-25

- Bugfix - List Room Mailbox Config - Could not read config, if room UPN was not the same as primary eMail address
- Bugfix - Add/Remove eMail Address - Adding an address failed if mailbox has exactly one email address

## 2022-10-27

- Isolate Device / Restrict Device Code exec.: Bug fixed, incorrect behavior if device is not yet available in DefenderATP service.

## 2022-10-20

- Convert to shared mailbox:

* Assign EXO E2 License if needed when converting to shared mailbox
* Assign M365 Lic when converting back to user mailbox
* Nicer output (UPN vs ID)
* Remove groups when converting to shared mailbox

## 2022-10-04

- All runbooks report their Caller in Verbose output.

## 1.1.0 (2022-09-19)

## 2022-09-19

- List Admin Users: Export Admin-to-Role Overview as CSV (optional)

## 2022-09-15

- Add "Check-Autopilot-SerialNumbers" runbook

## 2022-09-13

- Add "List Room Mailbox Configuration" runbook
- "List Admin Users" will list/validate MFA Methods for each admin
- Reset PW allows to not "force change on next logon"

## 2022-09-7

- Add Shared Mailbox: Support Custom Domains

## 2022-08-02

- merge Teams Voice Runbook into master branch
- List mailbox permissions: add support for mail enabled groups as trustee

## 2022-07-22

- new runbook: List groups that have license assignment errors
- "Convert to shared mailbox" will now check for litigation holds, mbox size and archives and inform you if a license is needed.

## 2022-07-05

- new runbook: Add/Remove AzureAD group member

## 2022-06-20

- new runbook: Assign new AutoPilot GroupTag to a device

## 2022-06-14

- Add-User: Will only provision a license of there still licenses available
- new runbook: Add/Remove Public Folder
- Add Shared Mailbox: Support for redirecting sent mail

## 2022-06-08

- rewriting RBs to have max. one active "Customizing" block per Runbook
  - offboard-user-\*

## 2022-06-03

- moved all teams phone/voice related runbooks to branch "feature-teamsvoice".

## 2022-06-01

- rewriting RBs to have max. one active "Customizing" block per Runbook
  - outphase-device
- better output and error handling in several runbooks

## 2022-05-30

- offboard-user-\*:
  - Handle group ownership on offboarding (replace owner)
- new runbook: List a user's group ownerships

## 2022-05-25

- list-inactive-devices:
  - can read now alternatively query by last Intune sync
  - can export to CSV
- new runbook: list app registrations that are vulnerable to CVE-2021-42306.

## 2022-05-24

- list inactive app:
  - Fix - List of apps was truncated
  - Fix - Display AppId if DisplayName is not available

## 2022-05-20

- new runbook: List expiring AzureAD / PIM role assignments

## 2022-05-19

- new runbook: List/Add/Remove SmartScreen Exclusions (indicators) in MS Security Center

## 2022-05-16

- new runbook: Export all Intune devices (to a storage account)

## 2022-05-16

- Many runbooks: Improve output
- device wipe and device outphase: Show owner/user UPN for the device

## 2022-05-12

- Add User: Supports adding users to Exchange Distr. Lists / mail enabled groups

## 2022-05-11

- Offboard user permanently / temporarily: Added support for removing Exchange groups / distr. lists
- Multiple Runbooks: Use displaynames instead of UIDs in output were possible for better readability

## 2022-05-06

- List expiring app credentials: Can limit output to creds about to expire.
- New Runbook: Report changes to Cond. Access Policies via eMail
  - intended for scheduled execution (daily)
  - needs Send eMail permissions
- New Runbook: List devices of members (users) in a group
  - Can optionally collect the devices into an AAD group

## 2022-05-05

- New Runbooks using MDE / Defender ATP
  - Isolate Device
  - Restrict Code Execution

## 2022-04-28

- New Runbook: Convert user mailbox to shared mailbox
- Fixes to "Add/Remove Group Owner"
  - add owners as members if needed
  - delete owner was broken

## 2022-04-21

- New Runbook: Set Room Mailbox Configuration

  Configure BookIn Policy, Auto-acceptance and other settings specific to room resources.

## 2022-04-20

- Bugfix: Corrected reporting for SendOnBehalf Mailbox permissions in multiple runbooks
- Better usernames reporting in user/mail runbooks

## 2022-04-12

- new runbook: Archive Team

## 2022-04-11

- moved to licensing report v2
- report "SendAs" and "SendOnBehalf" in List Mailbox Permissions

## 2022-03-30

- new runbook: List mailbox permissions

## 2022-03-23

- user_security_reset-mfa: Include reset of OATH and FIDO2 methods

## 1.0.1 (2022-03-10)

- Office 365 Lic. Reporting v2
  - Merged with 'CloudEconimics' reports intended for PowerBI

## 2022-02-16

- New Runbook: Set PAL / Azure Management Partner Link

## 2022-02-14

- Split Wipe/Outphase Runbook into two to allow separate roles/defaults

## 2022-02-09

- Support to create Distribution Groups as Roomlists

## 2022-02-02

- Bugfix - `group\general\add-or-remove-owner` could break if multiple users have similar display names

## 1.0.0 (2022-02-01)

- Official release of Runbook Library for RealmJoin and start of ongoing change tracking.
- User assignment in `org/general/add-autopilot-device` hidden by default as Microsoft is not supporting that feature anymore
- When auto creating UPNs in `org/general/add-user` German umlauts are automatically transcribed.
- All runbooks that were using the AzureAD module have been ported to use MS Graph natively
- Enabling/Disabling devices in Graph is currently limited to Windows devices. (MS limitation)

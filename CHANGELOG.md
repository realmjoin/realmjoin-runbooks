# RealmJoin Runbooks Changelog 

## 2024-04-05
* Set Room Mailbox Configuration: Only allow MailEnabled groups

## 2024-03-06
* Fix: Teams Phone Runbooks: Update phone number validation to include extension format

## 2024-03-01
* Fix: Convert to Shared Mailbox: Did not remove all groups
* Fix: Offboard User: Did not remove all groups

## 2024-02-29
* Show LAPS PW: Fix LAPS password retrieval and display device name

## 2024-02-28 
* Updates to Teams Phone Runbooks

## 2024-02-20
* Export all Intune Devices: Added more fields (CompanyName and JobTitle)

## 2024-01-15
* New Runbook: Export all AutoPilot devices

## 2024-01-12
* Wipe Device: Support MacOS Obliteration Modes

## 2023-12-07
* Add/Remove Mail Address: Fix - Could not remove address

## 2023-12-05
* All Phone Runbooks: Update module versions and add validation for user input

## 2023-11-24
* Add Shread/Room/Equip. Mailbox: Add mailbox creation wait logic

## 2023-11-14
* List Mailbox Permissions: Only list Trustees with a mailbox in this tenant.
* Reset MFA: Handle token becoming invalid after failed auth. method deletion

## 2023-11-13
* (Un)Assign License: (fixed) Group prefix was case sensitive.
* Update User: (fixed) Fails if a group is not found.

## 2023-10-26
* List Inactive Devices: Fixed: Failed if the primary owner has been deleted from AAD.
* Assign groups by template: Performance improvements

## 2023-10-20
* Set User Photo: (fixed) Updated API Call

## 2023-10-17
* New Runbook: List a device's LAPS credentials (i.e. local admin passwords)

## 2023-09-28
* Avoid failed runs due to a known issue in Azure Automation / Avoid module dependency in param block

## 2023-09-18
* Update to RJRBHelper v0.8.3 - Fix problems with newer Azure Automation Containers

## 2023-09-07 
* Teams Phone Runbooks: Bugfix (variables cleanup)

## 2023-08-18
* New Runbook: Assign groups by template (user and group scope)
* New Runbook: Reset mobile device PIN

## 2023-08-11
* Export Policy Report - Compatibility with Microsoft Graph PowerShell Module 2.x
* Updated Phone Runbooks

## 2023-08-04
* Updated Phone Runbooks

## 2023-08-02
* Updated Phone Runbooks

## 2023-07-20
* Set Out-of-Office: Allow blocking calendar for the Out-of-Office period

## 2023-07-19
* Export CloudPC Usage: Updated to reflect API changes.

## 2023-07-13
* New Runbook: Submit Defender Threat Indicator / Hash

## 2023-07-11
* New Runbook: Rename Device in Intune and Autopilot

## 2023-06-28
* Assign Windows 365 - Support FrontLine Worker (Shared Use Service Plan) Cloud PCs
* Unassign Windows 365 - Support FrontLine Worker (Shared Use Service Plan) Cloud PCs

## 2023-06-26 
* Resize Windows 365 - Bugfix: Will not remove User Setting / Provisioning Policy

## 2023-06-21
* Export Policy Report - Ignore Cyrillic characters (as PanDocs does not support them).

## 2023-06-20
* Wipe Device: Support for Protected Wipe

## 2023-06-19
* Convert to Shared Mailbox - Dis-/Enable User on conversion and fixed potential issue with missing steps  

## 2023-06-16
* Add equipment/room/shared mailbox: AAD user object is disabled by default.

## 2023-06-15
* Require update of RealmJoin.RunbookHelper to 0.8.1 prevent potential token leakage.
* New Runbook: Add Viva Engage (Yammer) Community

## 2023-05-26
* New Runbook: List/Export all non-compliant devices in Intune and corresponding compliance policies/settings 
* Bugfix: List Admin Users: Some role assignments were not listed
* Change Exports to use ";" as delimiter and UTF8 file format for all runbooks

## 2023-05-11
* Assign Win365: Support long deployment times
* Convert to shared mailbox: Skip removing on-prem synced groups

## 2023-04-25
* New Runbook: Create an Application Registration

## 2023-03-29
* List inactive users: Supports listing users that have never logged on.
* New runbook: List PIM groups without owners

## 2023-03-28
* New Runbook: Create a report on a tenant's Intune and Conditional Access Policies

## 2023-03-23
* Configure Room Mailboxes: Allows setting Capacity
* Reprovision and Resize available for Windows 365 management

## 2023-03-15
* Added audit logging info to phone runbooks

## 2023-03-07
* Teams Phone: Update all user/phone runbook. Update to Teams Module v5. Better error handling.

## 2023-02-14 
* Update User: Support User Templates, Group Management, PW Reset

## 2023-02-07
* New Runbook: Export CloudPC Usage Statistics

## 2023-02-01
* New Runbook: Remove Room/Shared/Booking Mailbox

## 2023-01-31
* New Feature: Assign/Unassign Windows365 Cloud PCs

## 2023-01-30
* New Feature: Manage MS Bookings
* New Runbook: set-booking-config: Enable Bookings (tenant-wide)

## 2023-01-13
* New Runbook: Sync all Intune Devices

## 2022-12-22
* Add Autopilot Device: Support assigning (optional) GroupTag

## 2022-12-02
* Report SPO Shared Links: Support anon. links

## 2022-12-01
* Import a device into Intune via corporate identifier.
* Add/remove user (from/to group): Support EXO based groups (Distribution Lists and Mail-enabled Sec. Groups)

## 2022-11-30
* Add shared mailbox: Option to localize new mailboxes.

## 2022-11-29
* Report SPO Shared Links: Support for private channels added

## 2022-11-28
* New runbook: Report extern. shared links in all teams to the respective teams owners

## 2022-11-25
* Bugfix - List Room Mailbox Config - Could not read config, if room UPN was not the same as primary eMail address
* Bugfix - Add/Remove eMail Address - Adding an address failed if mailbox has exactly one email address
## 2022-10-27
* Isolate Device / Restrict Device Code exec.: Bug fixed, incorrect behavior if device is not yet available in DefenderATP service.

## 2022-10-20
* Convert to shared mailbox:
- Assign EXO E2 License if needed when converting to shared mailbox
- Assign M365 Lic when converting back to user mailbox
- Nicer output (UPN vs ID)
- Remove groups when converting to shared mailbox

## 2022-10-05
* New: Assign groups via template

## 2022-10-04
* All runbooks report their Caller in Verbose output.

## 1.1.0 (2022-09-19)

## 2022-09-19
* List Admin Users: Export Admin-to-Role Overview as CSV (optional)

## 2022-09-15
* Add "Check-Autopilot-SerialNumbers" runbook

## 2022-09-13
* Add "List Room Mailbox Configuration" runbook
* "List Admin Users" will list/validate MFA Methods for each admin
* Reset PW allows to not "force change on next logon"

## 2022-09-7
* Add Shared Mailbox: Support Custom Domains

## 2022-08-02
* merge Teams Voice Runbook into master branch
* List mailbox permissions: add support for mail enabled groups as trustee

## 2022-07-22
* new runbook: List groups that have license assignment errors
* "Convert to shared mailbox" will now check for litigation holds, mbox size and archives and inform you if a license is needed.

## 2022-07-05
* new runbook: Add/Remove AzureAD group member

## 2022-06-20
* new runbook: Assign new AutoPilot GroupTag to a device
  
## 2022-06-14
* Add-User: Will only provision a license of there still licenses available
* new runbook: Add/Remove Public Folder
* Add Shared Mailbox: Support for redirecting sent mail

## 2022-06-08
* rewriting RBs to have max. one active "Customizing" block per Runbook
  * offboard-user-*

## 2022-06-03
* moved all teams phone/voice related runbooks to branch "feature-teamsvoice".

## 2022-06-01
* rewriting RBs to have max. one active "Customizing" block per Runbook
  * outphase-device
* better output and error handling in several runbooks

## 2022-05-30
* offboard-user-*: 
  * Handle group ownership on offboarding (replace owner)
* new runbook: List a user's group ownerships

## 2022-05-25
* list-inactive-devices:
  * can read now alternatively query by last Intune sync
  * can export to CSV
* new runbook: list app registrations that are vulnerable to CVE-2021-42306.

## 2022-05-24
* list inactive app: 
  * Fix - List of apps was truncated
  * Fix - Display AppId if DisplayName is not available

## 2022-05-20
* new runbook: List expiring AzureAD / PIM role assignments

## 2022-05-19
* new runbook: List/Add/Remove SmartScreen Exclusions (indicators) in MS Security Center

## 2022-05-16
* new runbook: Export all Intune devices (to a storage account)

## 2022-05-16
* Many runbooks: Improve output 
* device wipe and device outphase: Show owner/user UPN for the device

## 2022-05-12
* Add User: Supports adding users to Exchange Distr. Lists / mail enabled groups

## 2022-05-11
* Offboard user permanently / temporarily: Added support for removing Exchange groups / distr. lists
* Multiple Runbooks: Use displaynames instead of UIDs in output were possible for better readability

## 2022-05-09
* MWP Rollout Report: Support corelating devices via "registered" relationship (not only "owned" relationship)

## 2022-05-06

* List expiring app credentials: Can limit output to creds about to expire.
* New Runbook: Report changes to Cond. Access Policies via eMail
  * intended for scheduled execution (daily)
  * needs Send eMail permissions 
* New Runbook: List devices of members (users) in a group
  * Can optionally collect the devices into an AAD group

## 2022-05-05

* New Runbooks using MDE / Defender ATP
  * Isolate Device
  * Restrict Code Execution

## 2022-04-28

* New Runbook: Convert user mailbox to shared mailbox
* Fixes to "Add/Remove Group Owner"
  *  add owners as members if needed
  *  delete owner was broken

## 2022-04-21

* New Runbook: Set Room Mailbox Configuration
  
  Configure BookIn Policy, Auto-acceptance and other settings specific to room resources.

## 2022-04-20
* Bugfix: Corrected reporting for SendOnBehalf Mailbox permissions in multiple runbooks
* Better usernames reporting in user/mail runbooks

## 2022-04-12
* new runbook: Archive Team

## 2022-04-11

* moved to licensing report v2 
* report "SendAs" and "SendOnBehalf" in List Mailbox Permissions

## 2022-03-30

* new runbook: List mailbox permissions

## 2022-03-23

* user_security_reset-mfa: Include reset of OATH and FIDO2 methods

## 1.0.1 (2022-03-10)

* Office 365 Lic. Reporting v2
  * Merged with 'CloudEconimics' reports intended for PowerBI

## 2022-02-16

* New Runbook: Set PAL / Azure Management Partner Link

## 2022-02-14

* Split Wipe/Outphase Runbook into two to allow separate roles/defaults

## 2022-02-09

* Support to create Distribution Groups as Roomlists

## 2022-02-02

* Bugfix - `group\general\add-or-remove-owner` could break if multiple users have similar display names
## 1.0.0 (2022-02-01)

* Official release of Runbook Library for RealmJoin and start of ongoing change tracking.
* User assignment in `org/general/add-autopilot-device` hidden by default as Microsoft is not supporting that feature anymore
* When auto creating UPNs in `org/general/add-user` German umlauts are automatically transcribed.
* All runbooks that were using the AzureAD module have been ported to use MS Graph natively
* Enabling/Disabling devices in Graph is currently limited to Windows devices. (MS limitation)

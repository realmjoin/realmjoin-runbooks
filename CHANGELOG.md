# RealmJoin Runbooks Changelog 

## 2023-06-19
* Convert to Shared Mailbox - Dis-/Enable User on cornversion and fixed potential issue with missing steps  

## 2023-06-16
* Add equipment/room/shared mailbox: AAD user object is disabled by default.

## 2023-06-15
* Require update of RealmJoin.RunbookHelper to 0.8.1 prevent potential token leakage.
* New Runbook: Add Viva Engage (Yammer) Community

## 2023-05-26
* New Runbook: List/Export all non-compliant devices in Intune and corresponding compliance policies/settings 
* Bugfix: List Admin Users: Some roleassignments were not listed
* Change Exports to use ";" as delimiter and UTF8 file format for all runbooks

## 2023-05-11
* Assign Win365: Support long deployment times
* Convert to shared mailbox: Skip removing on-prem synced groups

## 2023-04-25
* New Runbook: Create an Application Registration

## 2023-03-29
* List inactive users: Supports listing users that have never logged on.
* New runbook: List PIM groups wiothout owners

## 2023-03-28
* New Runbook: Create a report on a tenant's Intune and Conditional Access Policies

## 2023-03-23
* Configure Room Mailboxes: Allows setting Capacity
* Reprovision and Resize available for Windows 365 management

## 2023-03-15
* Added audit logging info to phone runbooks

## 2023-03-07
* Teams Phone: Update all user/phone runbook. Update to Teams Module v5. Better Errorhandling.

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
* Add Autopilot Device: Support assigning (optinal) GroupTag

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
* New runbook: Report extern. shared links in all teams to the repective teams owners

## 2022-11-25
* Bugfix - List Room Mailbox Config - Could not read config, if room UPN was not the same as primary eMail address
* Bugfix - Add/Remove eMail Address - Adding an address failed if mailbox has exactly one email address
## 2022-10-27
* Isolate Device / Restrict Device Code exec.: Bug fixed, incorrect behaviour if device is not yet available in DefenderATP service.

## 2022-10-20
* Convert to shared mailbox:
- Assign EXO E2 License if needed when converting to shared mailbox
- Assign M365 Lic when converting back to user mailbox
- Nicer output (UPN vs ID)
- Remove groups when converting to shared mailbox

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
* List mailbox permissions: add support for mail enbled groups as trustee

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
  * ouffboard-user-*

## 2022-06-03
* moved all teams phone/voice related runbooks to brach "feature-teamsvoice".

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
* device wipe and deveice outphase: Show owner/user UPN for the device

## 2022-05-12
* Add User: Supports adding users to Exchange Distr. Lists / mail enabled groups

## 2022-05-11
* Offboard user permanently / temporarily: Added support for removing Exchange groups / distr. lists
* Multiple Runbooks: Use displaynames instead of UIDs in output were possible for better readability

## 2022-05-06

* List expiring app credentials: Can limit output to creds about to expire.
* New Runbook: Report changes to Cond. Access Policies via eMail
  * intended for scheduled execution (daily)
  * needs Send eMail permissions 
* New Runbook: List devices of members (users) in a group
  * Can optionally collect the devices into an AAD group

## 2022-05-05

* New Runbooks using MDE / Defenter ATP
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

* moved to lincensing report v2 
* report "SendAs" and "SendOnBehalf" in List Mailbox Permissions

## 2022-03-30

* new runbook: List mailbox permissions

## 2022-03-23

* user_security_reset-mfa: Include reset of OATH and FIDO2 methods

## 1.0.1 (2022-03-10)

* Office 365 Lic. Reporting v2
  * Merged with 'CloudEconimics' reports intended for PowerBI

## 2022-02-16

* New Runbook: Set PAL / Azure Management Parner Link

## 2022-02-14

* Split Wipe/Outphase Runbook into two to allow separate roles/defaults

## 2022-02-09

* Support to create Distribution Groups as Roomlists

## 2022-02-02

* Bugfix - `group\general\add-or-remove-owner` could break if multiple users have similar display names
## 1.0.0 (2022-02-01)

* Official release of Runbook Library for RealmJoin and start of ongoing change tracking.
* User assignment in `org/general/add-autopilot-device` hidden by default as Microsoft is not supporting that feature anymore
* When autocreating UPNs in `org/general/add-user` german umlauts are automatically transcribed.
* All runbooks that were using the AzureAD module have been ported to use MS Graph natively
* Enabling/Disabling devices in Graph is currently limited to Windows devices. (MS limitation)

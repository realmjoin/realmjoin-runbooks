# RealmJoin Runbooks Changelog 

## 2022-05-16
* new runbook: Export all devices (to a storage account)

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

# RealmJoin Runbooks Changelog 

## 2022-04-28

* New Runbook: Convert user mailbox to shared mailbox

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

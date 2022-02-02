# RealmJoin Runbooks Changelog 

## 2022-02-02

* Bugfix - `group\general\add-or-remove-owner` could break if multiple users have similar display names
## 1.0.0 (2022-02-01)

* Official release of Runbook Library for RealmJoin and start of ongoing change tracking.
* User assignment in `org/general/add-autopilot-device` hidden by default as Microsoft is not supporting that feature anymore
* When autocreating UPNs in `org/general/add-user` german umlauts are automatically transcribed.
* All runbooks that were using the AzureAD module have been ported to use MS Graph natively
* Enabling/Disabling devices in Graph is currently limited to Windows devices. (MS limitation)

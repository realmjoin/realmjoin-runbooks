# Check Assignments Of Users

## Check Intune assignments for a given (or multiple) User Principal Names (UPNs).

## Description
This script checks the Intune assignments for a single or multiple specified UPNs.

## Where to find
Org \ General \ Check Assignments Of Users

## Notes
Permissions (Graph):
- User.Read.All
- Group.Read.All
- DeviceManagementConfiguration.Read.All
- DeviceManagementManagedDevices.Read.All
- Device.Read.All

## Parameters
### -UPN
Description: User Principal Names of the users to check assignments for, separated by commas.
Default Value: 
Required: true

### -IncludeApps
Description: Boolean to specify whether to include application assignments in the search.
Default Value: False
Required: false


[Back to Table of Content](../../../README.md)


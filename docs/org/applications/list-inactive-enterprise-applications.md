# List Inactive Enterprise Applications

List application registrations, which had no recent user logons.

## Detailed description
Identifies enterprise applications with no recent sign-in activity based on Entra ID audit logs.
The report includes Entra ID applications with last sign-in older than specified days (default: 90 days) or applications with no sign-in records in the audit log.

## Where to find
Org \ Applications \ List Inactive Enterprise Applications

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Directory.Read.All
  - Device.Read.All


## Parameters
### -Days
Description: 
Default Value: 90
Required: false


[Back to Table of Content](../../../README.md)


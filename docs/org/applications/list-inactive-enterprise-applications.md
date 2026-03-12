# List Inactive Enterprise Applications

List enterprise applications with no recent sign-ins

## Detailed description
This runbook identifies enterprise applications with no recent sign-in activity based on Microsoft Entra ID sign-in logs.
It lists apps that have not been used for the specified number of days and apps that have no sign-in records.
Use it to find candidates for review, cleanup, or decommissioning.

## Where to find
Org \ Applications \ List Inactive Enterprise Applications

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Directory.Read.All
  - Device.Read.All


## Parameters
### Days
Number of days without user logon to consider an application as inactive. Default is 90 days.

| Property | Value |
|----------|-------|
| Default Value | 90 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)


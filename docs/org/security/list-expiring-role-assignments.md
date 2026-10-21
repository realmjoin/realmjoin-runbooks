# List Expiring Role Assignments

List Entra ID role assignments that expire soon

## Detailed description
Lists the active and PIM eligible Entra ID role assignments that expire within the chosen number of days, so they can be renewed in time. Each entry shows the role, the principal and the expiry date. Nothing is changed.

## Where to find
Org \ Security \ List Expiring Role Assignments

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - RoleManagement.Read.All
  - User.Read.All


## Parameters
### Days
Assignments that expire within this many days are listed.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)


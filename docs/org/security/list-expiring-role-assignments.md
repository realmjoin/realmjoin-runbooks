# List Expiring Role Assignments

List Azure AD role assignments expiring within a given number of days

## Detailed description
Lists active and PIM-eligible Azure AD role assignments that expire within a specified number of days. The output includes role name, principal, and expiration date.

## Where to find
Org \ Security \ List Expiring Role Assignments

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Organization.Read.All
  - RoleManagement.Read.All


## Parameters
### Days
Maximum number of days until expiry.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)


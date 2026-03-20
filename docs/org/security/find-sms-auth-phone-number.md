# Find SMS Auth Phone Number

Find the user associated with a specific SMS-based authentication phone number

## Detailed description
This runbook searches for which user has a specific phone number registered with SMS Sign-In enabled in Microsoft Entra ID. Unlike regular phone MFA methods, SMS Sign-In numbers must be unique across the tenant. If a number is reserved for SMS Sign-In by one user, assigning it to another user will fail with a "phoneNumberNotUnique" error. Regular phone MFA methods do not enforce uniqueness. This runbook helps administrators identify which user holds a specific SMS Sign-In number for troubleshooting and remediation.

## Where to find
Org \ Security \ Find SMS Auth Phone Number

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AuditLog.Read.All
  - User.Read.All
  - UserAuthenticationMethod.Read.All


## Parameters
### PhoneNumber
Phone number to search for in E.164 format (e.g., +492349876543). The number must start with a "+" followed by the country code and subscriber number.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


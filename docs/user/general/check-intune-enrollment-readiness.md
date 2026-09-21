# Check Intune Enrollment Readiness

Check whether this user can enroll devices in Intune

## Detailed description
Checks whether this user is ready to enroll a device in Intune and reports Ready, Ready with warnings or Not ready together with the blockers found. The check covers the account status, the Intune license, the device enrollment limit, platform restrictions and Conditional Access policies that target device registration or enrollment. Nothing is changed. Details on the checks are in the runbook documentation (docs.realmjoin.com).

## Where to find
User \ General \ Check Intune Enrollment Readiness

## Interpretation notes

- Checks performed: account state, Intune license and service plan, tenant MDM authority, device enrollment limit, platform restrictions, registered authentication methods, Conditional Access policies and, optionally, pilot group membership.
- Conditional Access is evaluated as a static "What If" against the enrollment sign-in for the selected `EnrollmentPlatform`; Entra's own What If tool remains the authority.
- Compliant-device requirements on "All resources" policies do not block enrollment (a documented Entra exemption); only policies targeting device registration or the Intune enrollment apps are treated as strict gates.
- Not evaluated statically: named locations, device filters, sign-in frequency and terms of use.
- Expired or already used Temporary Access Passes are not counted as usable methods.

## Prerequisites

The tenant MDM authority must be "intune" or "office365"; other values block every user.

## What is checked

The readiness verdict combines these checks:

- Account status (enabled, not blocked) and an Intune license assigned to the user.
- The tenant's device enrollment limit for the user and the platform restrictions of the enrollment configuration.
- Conditional Access policies that explicitly target device registration or Intune enrollment. Policies that require a compliant device via *All resources* are exempted by Microsoft Entra design and therefore not counted as blockers.
- Platform-scoped policies and browser-only client-app requirements are evaluated against the chosen enrollment platform; with *All platforms* every platform is evaluated and reported separately.

The runbook only reads; it changes nothing on the user or the tenant.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementServiceConfig.Read.All
  - Group.Read.All
  - GroupMember.Read.All
  - Organization.Read.All
  - Policy.Read.All
  - RoleManagement.Read.Directory
  - User.Read.All
  - UserAuthenticationMethod.Read.All


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### EnrollmentPlatform
Platform of the device the user wants to enroll. Conditional Access policies scoped to other platforms are ignored; All platforms checks every platform and reports each one.

| Property | Value |
|----------|-------|
| Default Value | Windows |
| Required | false |
| Type | String |

### CheckPilotGroupMembership
Also requires the user to be in the pilot group. Non-members are reported as Not ready.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### PilotGroupDisplayName
Members of this group count as pilot users. The group is looked up by its display name.

| Property | Value |
|----------|-------|
| Default Value | col - All Users - Pilot (users) |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


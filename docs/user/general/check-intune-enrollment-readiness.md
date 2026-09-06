# Check Intune Enrollment Readiness

Check whether a user is ready to enrol devices in Microsoft Intune

## Detailed description
Evaluates a selected user account for Intune device enrollment readiness and reports a readiness result (Ready, Ready with warnings, or Not ready) along with specific blockers. The runbook checks account status, Intune licensing, device enrollment limits, platform restrictions, and Conditional Access policies that explicitly target device registration or Intune enrollment; policies requiring compliant devices via "All resources" are exempted by Microsoft Entra design. Platform-scoped policies and browser-only client-app requirements are evaluated against the specified enrollment platform, and the runbook performs read-only diagnostics only.

## Where to find
User \ General \ Check Intune Enrollment Readiness

## Notes
Interpretation notes:
- Checks performed: account state, Intune license and service plan, tenant MDM authority, device
  enrollment limit, platform restrictions, registered authentication methods, Conditional Access
  policies, and optionally pilot group membership.
- Conditional Access is evaluated as a static "What If" against the enrollment sign-in for the
  selected EnrollmentPlatform; Entra's own What If tool remains the authority.
- Compliant-device requirements on "All resources" policies do not block enrollment (documented
  Entra exemption); only policies targeting device registration or the Intune enrollment apps are
  treated as strict gates.
- Not evaluated statically: named locations, device filters, sign-in frequency, and terms of use.
- Expired or already-used Temporary Access Passes are not counted as usable methods.

Prerequisites:
- Tenant MDM authority must be "intune" or "office365"; other values block every user.

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
User principal name of the user to check for Intune enrolment readiness.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### EnrollmentPlatform
Device platform assumed during Conditional Access evaluation. Platform-scoped policies that do not cover this platform are ruled out. When set to 'All', the script evaluates every platform and reports results per platform.

| Property | Value |
|----------|-------|
| Default Value | Windows |
| Required | false |
| Type | String |

### CheckPilotGroupMembership
If set to true, the script checks whether the user is a member of the pilot group. Non-members are reported as Not ready; if the group cannot be found or membership cannot be verified, a warning is issued.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### PilotGroupDisplayName
Display name of the pilot group to check for membership. This parameter can be overridden per run or configured in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value | col - All Users - Pilot (users) |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


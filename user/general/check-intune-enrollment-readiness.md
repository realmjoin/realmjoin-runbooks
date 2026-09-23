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

## How it works

On each run the runbook:

1. Connects to Microsoft Graph and SharePoint Online (PnP PowerShell) with the Automation account's managed identity. The SharePoint admin center URL is derived automatically from the tenant root site.
2. Reads the selected user (`UserName`) from Microsoft Entra ID and stops if the account does not exist or is **disabled**.
3. Optionally verifies that the user has an enabled **SharePoint** service plan (see [License check](#license-check)).
4. Checks whether the user's OneDrive already exists as an active site collection - if so, the run ends without sending a request.
5. Looks for a deleted OneDrive of the user in the tenant recycle bin and shows a warning if one is found.
6. Queues the OneDrive creation via `New-PnPPersonalSite` and prints the result.

The runbook is started from the user object in the RealmJoin portal, so the user is always preselected - there is no free-text input.

### Account must be enabled

SharePoint only creates a OneDrive for users who are allowed to sign in. Requests for blocked users are accepted but silently ignored, which would result in a misleading "queued" message. The runbook therefore aborts with an error when `accountEnabled` is `false`. Enable the account first and run the runbook again.

A sign-in block enforced by **Conditional Access** cannot be detected by the runbook.

### License check

With **Verify SharePoint license before provisioning** (`CheckSharePointLicense`, enabled by default) the runbook aborts when the user has no enabled SharePoint service plan. The check evaluates the user's `assignedPlans`, so every license source counts:

- Microsoft 365 / Office 365 suites (e.g. E3, E5, F3, Business Standard)
- SharePoint Online Plan 1 / Plan 2 and OneDrive standalone plans
- Direct and group-based license assignments

If the check is disabled, the request is queued anyway - but SharePoint will not create the OneDrive as long as no SharePoint license is assigned. After assigning a license, allow some time for the assignment to take effect before running the runbook.

### Idempotent by design

- If the OneDrive already exists as an active site collection, the runbook reports `AlreadyProvisioned` and sends no request.
- Sending a request for a user who already has a OneDrive is harmless - SharePoint ignores it.

### Deleted OneDrive in the recycle bin

If a deleted OneDrive of the user (matched by the site owner) is found in the tenant recycle bin, the runbook shows a warning with the URL and deletion time. Restoring the existing OneDrive may be preferable to creating a new, empty one. The warning does not stop the run.

### Asynchronous provisioning

The runbook only **queues** the request; the OneDrive is created later by a SharePoint timer job. This usually takes a few minutes but can take up to 24 hours or longer. The runbook does not wait for completion - use the runbook **Check OneDrive Status** (Org \ Collab) to verify the result.

The runbook returns an object with `UserPrincipalName`, `Status` (`AlreadyProvisioned` or `ProvisioningRequested`), `OneDriveUrl` and `RequestedAt` (UTC).

### Prerequisites

The Automation account's system-assigned managed identity needs:

- **Microsoft Graph**: `User.Read.All` (user state and licenses) and `Sites.Read.All` (tenant root site to derive the SharePoint admin center URL).
- **Office 365 SharePoint Online**: `Sites.FullControl.All` and `User.ReadWrite.All`. These SharePoint app-only permissions must be granted manually per tenant.
- The **PnP.PowerShell** module (version 3.x) imported into the Automation account.

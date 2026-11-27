---
layout:
  width: wide
---

# Runbook Release Notes

Stay up to date with the latest changes to the RealmJoin Runbooks. Runbook updates are typically published here in monthly release cycles.

## v2026.11

> Faster for the help desk, simpler for admins, safer in daily use: the new `Sync Device` runbook sends an Intune check-in to a device right away, report runbooks need just one central storage configuration instead of one per runbook (existing runbook-specific settings keep working), and many of the 46 improved runbooks check more before they act and make problems visible in the job status — details below.

---

### Changes


<table data-full-width="true"><thead><tr><th width="64">Type</th><th width="82">Domain</th><th width="136">Subcategory</th><th width="176">Runbook</th><th>Details</th></tr></thead><tbody><tr><td>➕</td><td>device</td><td>general</td><td>Sync Device</td><td><strong>Sync:</strong> Starts an Intune sync for this device, so pending policies, apps and settings arrive without waiting for the next regular check-in; an offline device syncs once it is back online.<br><strong>Status first:</strong> Shows the device name, operating system, primary user, compliance state and last check-in; if the device is not enrolled in Intune, the run stops with a clear message.<br><strong>Permissions:</strong> Help desk staff can sync devices even if the RealmJoin app has no Intune permission for remote actions, because the Automation account sends the request.</td></tr><tr><td>✏️</td><td>org</td><td>applications</td><td>Export Enterprise Application Users</td><td><strong>Owners:</strong> If an app is owned by a service principal instead of a user, the owner appears as <code>ServicePrincipal</code> with name and app ID; owners, users and groups that cannot be read stay in the report, marked <code>(lookup failed)</code>.<br><strong>Large tenants:</strong> The report includes all entries.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Delete Stale Devices (Scheduled)</td><td><strong>Group filter:</strong> Only devices whose primary user is in the include group are deleted (devices without a primary user are kept); devices of exclude group members and devices in the exclude group itself are kept. Nested groups count.<br><strong>Matching:</strong> The groups apply whenever they are set, also without <code>UseUserScope</code>; users are matched by user ID, so a renamed or reused UPN does not matter. With a group filter, devices whose primary user has no user ID are kept and listed.<br><strong>Safeguard:</strong> Nothing is deleted when the device list or a group cannot be read, the include group has no users, or group filtering is selected without a group.<br><strong>Note:</strong> <code>Days</code> must be between 1 and 3650; a run with 0 or a negative value stops before anything is deleted.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Notify Users About Low Diskspace (Scheduled)</td><td><strong>Recipients:</strong> Each user gets one email listing only their own devices, even after a UPN was renamed or reused.<br><strong>Email:</strong> Device names and details cannot change the email's formatting; the mail template is a simple choice in the run dialog: English, German or a custom template.<br><strong>Output Data:</strong> Shows which users and devices were notified or skipped, and why.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Report Devices Low Diskspace (Scheduled)</td><td><strong>Email:</strong> Device names and details cannot change the formatting of the report email.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Report Stale Devices (Scheduled)</td><td><strong>Group filter:</strong> Members of nested groups count for the include and exclude user groups; devices that are members of the exclude group are left out as well.<br><strong>Day range:</strong> A warning appears when <code>MaxDays</code> is not greater than <code>Days</code>; in that case <code>MaxDays</code> has no effect.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Report Windows Devices Without Autopilot (Scheduled)</td><td><strong>Delivery:</strong> Chosen in the standard "Report delivery" field instead of two Yes/No switches; the default is still a download link, and existing schedules keep their settings.<br><strong>Join type:</strong> New column <code>JoinType</code> shows whether a device is Entra joined, hybrid joined or Entra registered; hybrid joined and Entra registered devices are not labeled orphaned.<br><strong>Note:</strong> When you edit a schedule saved before this release, the choice shows "Also create a download link" regardless of the saved settings; select the delivery again before saving.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Enrolled Devices Report (Scheduled)</td><td><strong>Large tenants:</strong> The report includes all entries.<br><strong>Grouping:</strong> Stops with a clear message when the attribute to group by is empty or one of the names the report reserves for itself, such as <code>IntuneEnrolledDate</code>.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Export All Autopilot Devices</td><td><strong>Export options:</strong> Now called "Output Data only" and "Also export to a CSV file".</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Export Non Compliant Devices</td><td><strong>Shared devices:</strong> Devices used by several people are included completely.<br><strong>Output Data:</strong> Shows for each device which settings are not compliant; the CSV stays the same.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Export Policy Report</td><td><strong>Storage check:</strong> Before collecting the policies, checks that a storage account is configured and otherwise stops with a hint.<br><strong>Groups and apps:</strong> Shows the name of each assigned group (its ID if the group cannot be read) and the descriptions of apps excluded in Conditional Access policies.<br><strong>Note:</strong> The default container is now <code>export-policy-report</code> instead of <code>rjrb-licensing-report-v2</code>, which <code>Office365 License Report</code> also uses. A container set in <code>TenantPolicyReport.Container</code> or in existing schedules is kept; earlier reports remain in the old container.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Invite External Guest Users</td><td><strong>New option:</strong> "Send the invitation email?" When turned off, the guest is created without an email, as in the Entra admin center, and the job output shows the invitation link to pass on. The email is still sent by default.<br><strong>Checks:</strong> A wrong usage location (for example <code>UK</code> instead of <code>GB</code>) stops the run before anything is created; existing users are recognized even with special characters such as an apostrophe in their email address.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Monitor Service Health (Scheduled)</td><td><strong>Note:</strong> "Include advisories?" is now on by default, so new runs also alert on advisories, not only on incidents.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Office365 License Report</td><td><strong>Privacy setting:</strong> If the tenant setting that conceals user names in Microsoft 365 reports cannot be read, the runbook leaves it unchanged.<br><strong>Report content:</strong> <code>SharedMailboxLicensing.csv</code> is created for any number of licensed shared mailboxes; with <code>printOverview</code> set to false, the license totals and the license overview are hidden as well.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Report Intune Enrollment Readiness</td><td><strong>Device limits:</strong> Checks both limits for each user: the Entra setting "Maximum number of devices per user" for Entra registered and joined devices, and the Intune device enrollment limit for devices enrolled in Intune. If a limit cannot be determined for a user, it shows as Unknown with a warning.<br><strong>Pilot group:</strong> If several groups match the pilot group name, the first one is used with a warning; the name field only appears when the pilot group check is selected. "Users checked" counts each user once.<br><strong>Note:</strong> The managed identity needs the new Graph permissions <code>Device.Read.All</code>, <code>DeviceManagementManagedDevices.Read.All</code> and <code>Policy.Read.DeviceConfiguration</code>.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Sync Channel Or Group Members (Scheduled)</td><td><strong>Safeguard:</strong> Nothing is changed when a member list cannot be read completely, so no member is removed by mistake.</td></tr><tr><td>✏️</td><td>org</td><td>mail</td><td>Add Shared Mailbox</td><td><strong>Delegates:</strong> Several can be selected at once; each is checked before the mailbox is created and gets Full Access and Send on Behalf.<br><strong>Time zones:</strong> All Windows time zones with offset and cities, as in Outlook, for example "(UTC+10:00) Canberra, Melbourne, Sydney".<br><strong>Sign-in block:</strong> Applies to the new mailbox's own account, even if another account has the same alias.<br><strong>Errors:</strong> If the mailbox cannot be created, the run stops with a clear error. If a later setting (Sent Items copies, language and time zone, sign-in block) cannot be applied, the other steps still run and the run is marked as failed at the end.</td></tr><tr><td>✏️</td><td>org</td><td>security</td><td>Backup Conditional Access Policies</td><td><strong>Completeness:</strong> The backup contains all policies, also in tenants with many policies and for names with square brackets such as <code>[CA001] Require MFA</code>.</td></tr><tr><td>✏️</td><td>org</td><td>security</td><td>List Admin Users</td><td><strong>Role groups:</strong> Users who get an admin role through a role-assignable group are listed as admins and checked for MFA; the new column <code>RoleGroups</code> shows the group, for example <code>Tier0 Admins (Global Administrator)</code>.<br><strong>MFA:</strong> Hardware OATH tokens, external authentication methods and the macOS platform credential count as MFA. Admins whose methods cannot be read are listed separately, so they are not reported as admins without MFA.<br><strong>PIM:</strong> In tenants without Entra ID P2, the report runs without PIM data and is not marked as failed.</td></tr><tr><td>✏️</td><td>org</td><td>security</td><td>List Inactive Devices</td><td><strong>Export options:</strong> Now called "Output Data only" and "Also export to a CSV file".</td></tr><tr><td>✏️</td><td>org</td><td>security</td><td>List Vulnerable App Regs</td><td><strong>CVE-2021-42306:</strong> The check (private keys stored in app credentials) examines every app registration with a credential from before 6 December 2021 and reports it if the credential contains a private key.<br><strong>Not checked:</strong> App registrations that cannot be checked are named in a warning and in the Output Data table <code>Not checked</code>.<br><strong>CSV:</strong> Lists <code>DisplayName</code> and <code>AppId</code> of the affected app registrations.</td></tr><tr><td>✏️</td><td>org</td><td>security</td><td>Monitor Pending EPM Requests (Scheduled)</td><td><strong>Approver email:</strong> Text from the request, such as the justification, appears as plain text and cannot add links or images; a warning appears when not every recipient got the email.<br><strong>Detailed report:</strong> With "CSV only", it is also sent by email; the Output Data lists the pending requests only when <code>DetailedReport</code> is on.<br><strong>Note:</strong> The managed identity needs <code>Organization.Read.All</code> to show the tenant name.</td></tr><tr><td>✏️</td><td>org</td><td>security</td><td>Sync MFA Secure Users To Group (Scheduled)</td><td><strong>Safeguard:</strong> Nothing is changed when the registered methods, the admin role assignments or the exclusion group cannot be read completely, so no user is removed by mistake and no admin or excluded user is added.<br><strong>Without Entra ID P2:</strong> The runbook still runs and keeps only admins with active role assignments out of the group.</td></tr><tr><td>✏️</td><td>user</td><td>general</td><td>Check Intune Enrollment Readiness</td><td><strong>Device limits:</strong> Checks both limits for the user: the Entra setting "Maximum number of devices per user" for Entra registered and joined devices, and the Intune device enrollment limit for devices enrolled in Intune; if something cannot be read, the result shows a warning.<br><strong>Pilot group:</strong> The name field only appears when the pilot group check is selected.<br><strong>Note:</strong> The managed identity needs the new Graph permissions <code>Device.Read.All</code>, <code>DeviceManagementManagedDevices.Read.All</code> and <code>Policy.Read.DeviceConfiguration</code>.</td></tr><tr><td>✏️</td><td>user</td><td>mail</td><td>Convert To Shared Mailbox</td><td><strong>Step by step:</strong> If a step fails, the run stops there and lists which steps were done and which were not; the user is removed from groups only once Exchange Online confirms the conversion.<br><strong>Safeguards:</strong> Nothing is changed when the mailbox cannot be converted (for example a Bookings mailbox) or the license group name matches several groups; a warning appears when it matches none.<br><strong>Converting back:</strong> The run announces that other users' Send on Behalf permissions will be removed and also finds license group memberships in groups with more than 100 members.</td></tr><tr><td>✏️</td><td>user</td><td>security</td><td>Reset Password</td><td><strong>Clear errors:</strong> If the user does not exist or Entra ID blocks the action because of an admin role, the run stops with a clear message naming the role and who may do it.<br><strong>Status first:</strong> Before any change, shows the user, the sign-in state and, with the optional <code>RoleManagement.Read.Directory</code> permission, their Entra ID roles.<br><strong>Order:</strong> Sets the new password first and only then enables a disabled account, so the account stays disabled if the password cannot be set.</td></tr><tr><td>✏️</td><td>user</td><td>security</td><td>Revoke Or Restore Access</td><td><strong>Clear errors:</strong> If the user does not exist or Entra ID blocks the action because of an admin role, the run stops with a clear message naming the role and who may do it.<br><strong>Status first:</strong> Before any change, shows the user, the sign-in state and, with the optional <code>RoleManagement.Read.Directory</code> permission, their Entra ID roles.<br><strong>Sign-in state:</strong> Left as it is when it already matches the requested action; revoking still signs the user out of all sessions. Access tokens already issued stay valid until they expire, except in apps with continuous access evaluation.</td></tr></tbody></table>


---

### General Changes

**All report runbooks now use the central report storage settings.** A storage account configured once in `RJReport.StorageAccount.ResourceGroup` and `RJReport.StorageAccount.StorageAccountName` now serves every report runbook, including the eleven runbooks below that had their own storage settings; `RJReport.StorageAccount.LinkExpiryDays` sets how long download links stay valid (default 6 days). Their own settings (`IntuneDevicesReport`, `EnrolledDevicesReport`, `TenantPolicyReport`, `OfficeLicensingReport`, `CaPoliciesExport`, `ListAdminsReport`, `InactiveDevices`, `VulnAppRegExport`, `EntAppsReport`) and the Automation variable `SettingsExports` keep working and take precedence, so existing schedules and API calls upload to the same place as before (except the new default container of `Export Policy Report`, see above). How to move to `RJReport.StorageAccount` is described in [Runbook Report Settings](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#runbook-specific-storage-settings-deprecated).<br>Note: these eleven runbooks no longer create the storage account. Create it beforehand and give the Automation account's managed identity the `Reader and Data Access` role (or `Storage Account Contributor`) on it; the container is created on the first upload. The parameters `StorageAccountLocation` and `StorageAccountSku` are ignored and will be removed in a later version; schedules that still pass them log a warning and should be re-created.

<details>
<summary>Affected runbooks (11)</summary>

- **org / applications**
  - `Export Enterprise Application Users`
- **org / general**
  - `Enrolled Devices Report (Scheduled)`
  - `Export All Autopilot Devices`
  - `Export All Intune Devices`
  - `Export Non Compliant Devices`
  - `Export Policy Report`
  - `Office365 License Report`
- **org / security**
  - `Backup Conditional Access Policies`
  - `List Admin Users`
  - `List Inactive Devices`
  - `List Vulnerable App Regs`

</details>
<br>

**New optional tenant setting `RJReport.StorageAccount.SubscriptionId`.** Recommended: set it to the subscription that contains the report storage account, so uploads always look there. Without it, Azure picks the subscription when the managed identity signs in. That works as long as the identity has roles in one subscription only; once it also has a role in another one, uploads may fail because the storage account is not found. In the eleven runbooks with their own storage settings, it applies when they use `RJReport.StorageAccount`; `IntuneDevicesReport.SubscriptionId` and `OfficeLicensingReport.SubscriptionId` still apply to their own storage accounts. Existing settings and schedules keep working.

<details>
<summary>Affected runbooks (38)</summary>

- **org / applications**
  - `Export Enterprise Application Users`
  - `List Inactive Enterprise Applications`
  - `Report Application Registration`
  - `Report Expiring Application Credentials (Scheduled)`
- **org / collab**
  - `Report Teams Channels (Scheduled)`
- **org / devices**
  - `Auto Approve Driver Updates (Scheduled)`
  - `Cleanup Autopilot Devices (Scheduled)`
  - `Delete Stale Devices (Scheduled)`
  - `List Mobile Devices`
  - `Report Devices Low Diskspace (Scheduled)`
  - `Report Devices Without Primary User (Scheduled)`
  - `Report Primary User Mismatch (Scheduled)`
  - `Report RealmJoin Agent Contact (Scheduled)`
  - `Report Stale Devices (Scheduled)`
  - `Report Users With More Than 5 Devices (Scheduled)`
  - `Report Windows Devices Without Autopilot (Scheduled)`
- **org / general**
  - `Enrolled Devices Report (Scheduled)`
  - `Export All Autopilot Devices`
  - `Export All Intune Devices`
  - `Export Non Compliant Devices`
  - `Export Policy Report`
  - `Office365 License Report`
  - `Report Intune Enrollment Readiness`
  - `Report License Assignment (Scheduled)`
  - `Sync Channel Or Group Members (Scheduled)`
  - `Sync Shared Channel Owners (Scheduled)`
- **org / security**
  - `Backup Conditional Access Policies`
  - `List Admin Users`
  - `List Inactive Devices`
  - `List Vulnerable App Regs`
  - `Monitor Pending EPM Requests (Scheduled)`
  - `Report EPM Elevation Requests (Scheduled)`
  - `Sync MFA Secure Users To Group (Scheduled)`
- **user / general**
  - `List Group Memberships`
  - `List Group Ownerships`
  - `Offboard User Permanently`
  - `Offboard User Temporarily`
- **user / security**
  - `List Signin Events`

</details>
<br>

**Failed steps show up in the job status.** When data cannot be read or an upload or email fails, these runbooks mark the run as failed, so a scheduled run without a complete result gets noticed; whatever was collected is still written to the Output Data and delivered where possible.

<details>
<summary>Affected runbooks (12)</summary>

- **org / applications**
  - `Export Enterprise Application Users`
- **org / devices**
  - `Delete Stale Devices (Scheduled)`
  - `Notify Users About Low Diskspace (Scheduled)`
- **org / general**
  - `Enrolled Devices Report (Scheduled)`
  - `Export All Autopilot Devices`
  - `Export All Intune Devices`
  - `Export Non Compliant Devices`
  - `Export Policy Report`
- **org / security**
  - `List Admin Users`
  - `List Inactive Devices`
  - `List Vulnerable App Regs`
  - `Monitor Pending EPM Requests (Scheduled)`

</details>
<br>

**Results as tables in the portal for fourteen more runbooks.** Results appear on the run's Output Data tab, where they can be sorted, filtered and exported to Excel or CSV, including a `Summary` table. Report files, uploads and emails stay the same.

<details>
<summary>Affected runbooks (14)</summary>

- **org / applications**
  - `Export Enterprise Application Users`
- **org / devices**
  - `Delete Stale Devices (Scheduled)`
  - `Notify Users About Low Diskspace (Scheduled)`
  - `Report Windows Devices Without Autopilot (Scheduled)`
- **org / general**
  - `Enrolled Devices Report (Scheduled)`
  - `Export All Autopilot Devices`
  - `Export Non Compliant Devices`
  - `Office365 License Report`
  - `Sync Channel Or Group Members (Scheduled)`
- **org / security**
  - `List Inactive Devices`
  - `Monitor Pending EPM Requests (Scheduled)`
  - `Sync MFA Secure Users To Group (Scheduled)`
- **user / general**
  - `List Group Memberships`
  - `List Group Ownerships`

</details>
<br>

**One "Report delivery" choice in four more runbooks.** It offers "Output Data only", "Also email the report", "Also create a download link" and "Also email & download link" and replaces the two Yes/No switches for the email and the download link. Scheduled runs and API calls that pass the email and download link parameters directly keep working.<br>Note: when you edit a schedule saved before this release, the choice shows "Output Data only" regardless of the saved settings; select the delivery again before saving.<br>Affected runbooks: `Sync Channel Or Group Members (Scheduled)`, `Sync MFA Secure Users To Group (Scheduled)`, `List Group Memberships` and `List Group Ownerships`.

**Modernized Microsoft Graph connection.** These runbooks connect through the `Microsoft.Graph.Authentication` module instead of the RealmJoin Graph helpers and send report emails over the same connection. Runbooks that used `Az.Storage` now upload with the RealmJoin.RunbookHelper storage functions.

<details>
<summary>Affected runbooks (15)</summary>

- **org / applications**
  - `Export Enterprise Application Users`
- **org / devices**
  - `Delete Stale Devices (Scheduled)`
  - `Notify Users About Low Diskspace (Scheduled)`
  - `Report Windows Devices Without Autopilot (Scheduled)`
- **org / general**
  - `Enrolled Devices Report (Scheduled)`
  - `Export All Autopilot Devices`
  - `Export All Intune Devices`
  - `Export Non Compliant Devices`
  - `Office365 License Report`
- **org / security**
  - `Backup Conditional Access Policies`
  - `List Inactive Devices`
  - `List Vulnerable App Regs`
  - `Monitor Pending EPM Requests (Scheduled)`
- **user / general**
  - `List Group Memberships`
  - `List Group Ownerships`

</details>

## Previous releases

<details>
<summary><strong>v2026.10.02</strong></summary>

> This patch release fixes report uploads and download links for report files with spaces or umlauts in their name.

---

### General Changes

**RealmJoin.RunbookHelper module raised to 0.8.10.** All 183 runbooks now require version 0.8.10 (previously 0.8.9). The new version encodes file names in storage uploads and download links (SAS links), so report files with spaces or umlauts in their name are uploaded and their download links open; this takes effect in the 29 runbooks that upload report files to a storage account or create a download link.

</details>

<details>
<summary><strong>v2026.10.01</strong></summary>

> This patch release fixes the Microsoft Graph connection in the RJ-PowerShell-7.4 runtime environment: all runbooks that use Microsoft Graph now require a module version that connects there.

---

### General Changes

**Microsoft Graph module raised to 2.41.2.** Versions 2.41.0 and 2.41.1 of `Microsoft.Graph.Authentication` require .NET 10 and fail to connect to Microsoft Graph in the RJ-PowerShell-7.4 runtime environment. All 65 runbooks that use Microsoft Graph now require version 2.41.2 (previously 2.39.0), which connects reliably there. Note: if the runtime environment contains other `Microsoft.Graph.*` modules, for example for your own runbooks, raise them to 2.41.2 as well.

</details>

<details>
<summary><strong>v2026.10</strong></summary>

> The highlight of this release is the new Output Data view: 28 runbooks now display their results as tables directly in the RealmJoin Portal (Output Data tab), where they can be sorted, filtered and exported to Excel — no report email or download link needed. In addition, seven new runbooks arrive for Teams call queues, device management (Autopilot device naming, RealmJoin agent health, Apple Lost Mode) and collaboration (Teams channel report, OneDrive pre-provisioning). In total, 38 existing runbooks were updated — 25 of them with the new Output Data view.

---

### Changes


<table data-full-width="true"><thead><tr><th width="62">Type</th><th width="82">Domain</th><th width="136">Subcategory</th><th width="140">Runbook</th><th>Details</th></tr></thead><tbody><tr><td>➕</td><td>device</td><td>security</td><td>Enable Or Disable Lost Mode</td><td>Locks a lost, supervised iOS or iPadOS device with Apple Lost Mode — with a message, a callback phone number and an optional footer on the lock screen — or lifts Lost Mode again. The device is checked for Intune enrollment, operating system and supervision before anything is sent.<br>Optionally requests the device location after locking and shows the coordinates with a map link when the device answers within a minute.<br>The documentation covers the supervision prerequisite and tenant-wide default lock screen texts via runbook customization.</td></tr><tr><td>➕</td><td>org</td><td>collab</td><td>Report Teams Channels (Scheduled)</td><td>Lists the private and shared channels of every team with their owners and, optionally, their members; members from other tenants are marked as external and channels without an owner are listed separately.<br>Teams that cannot be read are reported instead of aborting the run, so large tenants complete reliably.<br>Results appear as tables in the portal's Output Data tab (default) or are delivered as email report or time-limited download link.</td></tr><tr><td>➕</td><td>org</td><td>devices</td><td>Rename Devices By Group Tag (Scheduled)</td><td>Builds the computer name of every Windows Autopilot device from a template of group tag and serial number (for example <code>%GROUPTAG%-%SERIAL%</code>), stores it in the Autopilot record for the next deployment and renames already enrolled, Entra joined, corporate-owned devices.<br>Shortens serial numbers to the 15-character limit and skips name collisions, invalid names, hybrid joined and personal devices.<br>Dry run by default, group tag filter, exclude list with wildcards and a maximum number of changes per run for a staged rollout — replaces per-location Autopilot profiles and dynamic groups that only exist for device naming.</td></tr><tr><td>➕</td><td>org</td><td>devices</td><td>Report RealmJoin Agent Contact (Scheduled)</td><td>Compares the last contact of the RealmJoin agent with the last Intune sync of each Windows device and lists devices that Intune still sees but the agent no longer reports — a sign of a missing, blocked or broken agent.<br>Optionally lists devices the agent has never reported a user on and devices known to only one side; include and exclude device groups narrow the scope.<br>Results as tables in the Output Data tab, optionally as email report or download link. Uses the RealmJoin customer API (<code>RJAPI</code> credential, as <code>Report Primary User Mismatch</code>).</td></tr><tr><td>➕</td><td>org</td><td>phone</td><td>Add Or Remove Call Queue Agents</td><td>Adds or removes several users at once as agents of a Teams call queue selected by name; every user is checked for Enterprise Voice and the limit of 20 individually assigned agents is enforced before any change.<br>Call queues whose agents come from a Teams channel, a group or a Shifts schedule are recognized and left unchanged, with a hint where their members are managed; removing the last agent is refused.<br>The call queue is read back after the change to confirm the result.</td></tr><tr><td>➕</td><td>org</td><td>phone</td><td>Add Or Remove Call Queue Authorized Users</td><td>Adds or removes several users at once as authorized users of a Teams call queue selected by name; every user is checked for Enterprise Voice and the limit of 15 authorized users is enforced before any change.<br>Optionally assigns or removes the users' Teams voice applications policy; it is only removed when the user is not an authorized user of another call queue or auto attendant, and group-based assignments are reported instead of changed.</td></tr><tr><td>➕</td><td>user</td><td>collab</td><td>Pre-Provision OneDrive</td><td>Creates the selected user's OneDrive in advance, so it is available before the first sign-in (for example for onboarding or migrations).<br>Checks that the account is enabled and, optionally (on by default), that the user has a SharePoint license; nothing is requested if the OneDrive already exists, and a deleted OneDrive in the recycle bin is pointed out.<br>Provisioning runs asynchronously in SharePoint — use <code>Check OneDrive Status</code> to verify the result.</td></tr><tr><td>✏️</td><td>device</td><td>security</td><td>Reset Mobile Device Pin</td><td>New option <code>skipIfAtRisk</code> (off by default): the passcode is only reset when the device's Microsoft Defender for Endpoint risk score is not Medium or High, so a device possibly involved in a security incident is not unlocked without the security team.<br>Note: the option needs the optional <code>WindowsDefenderATP</code> permission <code>Machine.Read.All</code>; the documentation shows how to enable it by default via runbook customization.</td></tr><tr><td>✏️</td><td>device</td><td>security</td><td>Show Bitlocker Recovery Key</td><td>New option <code>skipIfAtRisk</code> (off by default): the recovery keys are only shown when the device's Microsoft Defender for Endpoint risk score is not Medium or High, so keys of a device possibly involved in a security incident are not disclosed without the security team.<br>Note: the option needs the optional <code>WindowsDefenderATP</code> permission <code>Machine.Read.All</code>; the documentation shows how to enable it by default via runbook customization.</td></tr><tr><td>✏️</td><td>group</td><td>general</td><td>Add Or Remove User</td><td>Distribution and mail-enabled security groups now accept every Exchange Online recipient as member, including mail users whose mailbox is hosted on-premises in a hybrid setup; users without an Exchange Online recipient get a clear message.</td></tr><tr><td>✏️</td><td>org</td><td>applications</td><td>List Inactive Enterprise Applications</td><td>The last sign-in now comes from the Entra sign-in activity report, which keeps the date per application, so thresholds beyond the 7/30-day sign-in log retention — such as the default of 90 days — are evaluated correctly.<br>Every application appears in exactly one of the two result lists, and tenants with many applications are processed noticeably faster.<br>The runbook is now report-only: it no longer writes the last sign-in date into the application's <code>notes</code> field.<br>Note: the managed identity needs the additional Graph permission <code>AuditLog.Read.All</code>.</td></tr><tr><td>✏️</td><td>org</td><td>applications</td><td>Report Application Registration</td><td>Shows whether the service principal of each app registration is enabled, marks apps without one and counts the enabled ones.</td></tr><tr><td>✏️</td><td>org</td><td>collab</td><td>Check OneDrive Status</td><td>Finds the active OneDrive by its site owner instead of the user profile, so the status is also reported when the profile cannot be read.<br>Searches up to 100,000 deleted OneDrive sites in the tenant recycle bin and reports the used storage in GB.</td></tr><tr><td>✏️</td><td>org</td><td>collab</td><td>Report SharePoint Tenant Storage (Scheduled)</td><td>The storage quota is now calculated correctly; storage values in the run output and the alert email are shown in GB, and the site list in the alert email is a proper table.<br>Note: the alert limits are now set in GB (<code>AlertLowStorageLimitInGB</code>, <code>AlertUnusedStorageLimitInGB</code>, previously <code>…InMB</code>) — review existing schedules. The managed identity needs the additional Graph permission <code>Sites.Read.All</code>.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Notify Users About Low Diskspace (Scheduled)</td><td>Devices just below the threshold are now reliably notified, and the most urgent devices are listed first.<br>Guest accounts and users with a changed UPN are reached, and all devices of a person arrive in a single notification.<br>The run reports the delivery result per recipient and fails when no notification could be delivered; custom mail templates keep their own language.<br>The documentation explains why an override mailbox can receive many emails within seconds and where to look when they do not arrive (junk folder, quarantine, message trace).</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Report Devices Low Diskspace (Scheduled)</td><td>Devices just below the threshold are now reliably reported and ranked by urgency.<br>The report email is sent even when the optional download link fails (shown as a warning); "CSV & XLSX" is now the default file format, and manufacturer and model filters match literally.<br>Only files that were actually written are attached, and the delivery result is reported per recipient.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Report Primary User Mismatch (Scheduled)</td><td>New check (off by default) for who actually uses a device: lists devices whose primary user has not logged on within a configurable number of days while someone else has, based on the Intune logon records and the users the RealmJoin agent saw signed in.<br>Shows the last logged-on user of both sources, the primary user's last logon and the last Intune sync per device; deleted accounts are marked.<br>Results as separate tables per category in the Output Data tab. The include and exclude device groups apply as soon as a group is selected.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Report Stale Devices (Scheduled)</td><td>The user group filter applies as soon as a group is selected — the separate "Filter by primary user group?" choice is gone; with an include group, only devices whose primary user is a member are listed.<br>iPadOS devices are included when iOS/iPadOS devices are selected.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Report Intune Enrollment Readiness</td><td>Can also provide the report as a time-limited download link.<br>The Conditional Access check reads all group and role memberships of a user and adds a warning when they cannot be read.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Sync Shared Channel Owners (Scheduled)</td><td>Teams whose owner group no longer exists are skipped, and the remaining teams are still processed.</td></tr><tr><td>✏️</td><td>org</td><td>mail</td><td>Add Equipment Mailbox</td><td>Booking delegates are now set through the calendar processing, like in the Exchange admin center: several delegates can be selected and every booking request waits for their approval; without delegates the mailbox accepts requests automatically when it is free.<br>Alias and delegates are checked before the mailbox is created, and a failed step ends the run with a clear error.<br>Note: delegates no longer receive Full Access or Send on Behalf, and the options "Accept meeting requests automatically?" and "Open automatically in the delegate's Outlook?" were removed.</td></tr><tr><td>✏️</td><td>org</td><td>mail</td><td>Add Room Mailbox</td><td>Same changes as <code>Add Equipment Mailbox</code>: booking delegates through the calendar processing with approval of every booking request, checks before the mailbox is created.<br>Note: delegates no longer receive Full Access or Send on Behalf, and the options "Accept meeting requests automatically?" and "Open automatically in the delegate's Outlook?" were removed.</td></tr><tr><td>✏️</td><td>org</td><td>security</td><td>Report EPM Elevation Requests (Scheduled)</td><td>Shows the reviewer, the device name and the product version of each request.<br>A time range above 30 days is reduced to the 30 days Intune keeps.</td></tr><tr><td>✏️</td><td>user</td><td>mail</td><td>List Room Mailbox Configuration</td><td>Now lists the booking delegates and the users and groups in the booking policies, and shows whether meeting requests are forwarded to the delegates and whether everyone may book in and out of policy.<br>Room details, calendar processing settings and delegates appear as tables in the Output Data tab.</td></tr><tr><td>✏️</td><td>user</td><td>mail</td><td>Set Room Mailbox Configuration</td><td>Booking delegates can now be added, replaced or removed; with "Let everyone else request the room?" requests from outside the booking group go to them for approval.<br>Shows the current booking rules and delegates before the change and the result as tables, and warns when the delegates would get no requests or a run switches off an existing delegate approval.</td></tr><tr><td>✏️</td><td>user</td><td>phone</td><td>Get Teams User Info</td><td>The assigned Teams voice applications policy is now reported correctly instead of always showing <code>Global</code>.</td></tr></tbody></table>


---

### General Changes

**New: results as tables directly in the portal.** 28 runbooks now display their results as named tables directly in the RealmJoin Portal (Output Data tab), where they can be sorted, filtered and exported to Excel; the console keeps short summaries with counts. Report runbooks get one unified "Report delivery" choice: "Output Data only" (default, no report files are created), "Also email the report", "Also create a download link" or "Also email & download link"; recipient and file format are only shown when a report file is wanted, and Excel worksheets carry the same names as the matching Output Data tables. Note: existing scheduled runs keep sending their email — when such a schedule is edited, choose the report delivery again before saving.<br>Existing runbooks (25): `List Owners`, `List User Devices`, `List Inactive Enterprise Applications`, `Report Application Registration`, `Report Expiring Application Credentials (Scheduled)`, `Report SharePoint Tenant Storage (Scheduled)`, `List Mobile Devices`, `Report Devices Low Diskspace (Scheduled)`, `Report Devices Without Primary User (Scheduled)`, `Report Primary User Mismatch (Scheduled)`, `Report Stale Devices (Scheduled)`, `Report Users With More Than 5 Devices (Scheduled)`, `Monitor Service Health (Scheduled)`, `Report Intune Enrollment Readiness`, `Report License Assignment (Scheduled)`, `Sync Shared Channel Owners (Scheduled)`, `Get Teams Phone Number Assignment`, `List Inactive Users`, `List Information Protection Labels`, `List Users By MFA Methods Count`, `Report EPM Elevation Requests (Scheduled)`, `List Mailbox Permissions`, `List Room Mailbox Configuration`, `Set Room Mailbox Configuration` and `List Signin Events`; new runbooks: `Report Teams Channels (Scheduled)`, `Rename Devices By Group Tag (Scheduled)` and `Report RealmJoin Agent Contact (Scheduled)`.<br>`Report Expiring Application Credentials (Scheduled)` and `Report EPM Elevation Requests (Scheduled)` now also send the email with the "CSV only" file format, and `List User Devices` adds devices to the target group in batches and skips existing members. Table titles and Excel worksheet names are limited to 31 characters, so "Export to Excel" works for every table.

**Exchange Online recipients addressed by unique identifiers.** Recipients whose name also matches other objects in the tenant (for example a shared mailbox named `Export`) are now handled reliably in `Delegate Full Access`, `Add Or Remove User`, `Add Or Remove Nested Group`, `Add Or Remove Owner`, `Hide Mailboxes (Scheduled)`, `List Room Mailbox Configuration`, `Delegate Send On Behalf` and `List Mailbox Permissions`. `Delegate Full Access` also shows the Exchange Online response when the connection, the mailbox lookup or the permission read-back fails.

**Help texts and documentation.** The portal help texts (synopsis, description and parameters) of all runbooks were revised for readability; technical background moved into the companion documentation, which is new or extended for 27 runbooks. The documentation of `Wipe Device` now describes its Defender risk check (`skipWipeIfAtRisk`), and the `Machine.Read.All` permission it uses is marked as optional.

</details>

<details>
<summary><strong>v2026.09</strong></summary>

> This release adds eight new runbooks — Intune disk-space and mobile-device inventory, SharePoint/OneDrive insights and Intune enrollment readiness checks — and extends the user offboarding runbooks with manager/sponsor replacement and a modernized group-membership export.
 
---
 
### Changes
 

<table data-full-width="true"><thead><tr><th width="62">Type</th><th width="82">Domain</th><th width="127">Subcategory</th><th width="140">Runbook</th><th>Details</th></tr></thead><tbody><tr><td>➕</td><td>org</td><td>collab</td><td>Check OneDrive Status</td><td>Shows whether a user's OneDrive still exists, is archived, locked or in the tenant recycle bin (with deletion time).<br>Also works for already-deleted accounts. Read-only.</td></tr><tr><td>➕</td><td>org</td><td>collab</td><td>List SharePoint Site Collection Permissions</td><td>Lists site collection administrators and the members of the Owners, Members and Visitors groups of a SharePoint site, including each member's type.<br>Works regardless of the site's display language. Read-only.</td></tr><tr><td>➕</td><td>org</td><td>collab</td><td>Report SharePoint Tenant Storage (Scheduled)</td><td>Monitors SharePoint tenant storage and lists the top site collections by consumed storage (OneDrive sites excluded).<br>Sends an alert email only when free storage drops below a low-storage limit or unused storage exceeds a configurable limit.</td></tr><tr><td>➕</td><td>org</td><td>devices</td><td>List Mobile Devices</td><td>Inventory of all Intune managed Android and iOS/iPadOS devices: IMEI, serial number, phone number, carrier, ownership, compliance and enrollment details.<br>Optional network details (IP/subnet, ICCID, eSIM, UDID, battery health) — one extra Graph request per device, so use with care in large tenants.<br>Scope by device group and/or user group; delivery as CSV/XLSX email report or time-limited download link.</td></tr><tr><td>➕</td><td>org</td><td>devices</td><td>Notify Users About Low Diskspace (Scheduled)</td><td>Emails primary users of Windows and macOS devices whose free disk space is below a configurable threshold, listing all affected devices with practical cleanup steps per platform.<br>English and German templates, custom template support and email branding as in <code>Notify Users About Stale Devices</code>.<br>Skips disabled accounts, devices without primary user and stale inventory (<code>MaxInventoryAgeDays</code>); <code>SimulationMode</code> and <code>OverrideEmailRecipient</code> for safe testing.</td></tr><tr><td>➕</td><td>org</td><td>devices</td><td>Report Devices Low Diskspace (Scheduled)</td><td>Scheduled report of Intune devices below a free-disk-space threshold (fixed GB or percentage), rated Critical or Warning.<br>Filters by platform, manufacturer and model; devices without usable storage inventory are excluded and counted.<br>Delivery as CSV/XLSX (with severity highlighting), email summary and/or time-limited download link.</td></tr><tr><td>➕</td><td>org</td><td>general</td><td>Report Intune Enrollment Readiness</td><td>Runs the enrollment readiness analysis for a set of users and/or all members of a group.<br>Per-user report with result, blockers and warnings; optional pilot group column. Delivery as CSV/XLSX and optional email.</td></tr><tr><td>➕</td><td>user</td><td>general</td><td>Check Intune Enrollment Readiness</td><td>Evaluates a single user for Intune enrollment readiness (Ready / Ready with warnings / Not ready) and names the concrete blockers.<br>Checks account state, license, MDM authority, enrollment limits and restrictions, authentication methods and a Conditional Access "What If" for the selected platform.<br>Optional pilot group membership check.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Add Primary Users Of Devices To Group (Scheduled)</td><td>New Report Only mode generates the report without changing any group memberships.</td></tr><tr><td>✏️</td><td>org</td><td>mail</td><td>Add Shared Mailbox</td><td>A specified Domain is now correctly applied to the primary SMTP address and the UPN.</td></tr><tr><td>✏️</td><td>user</td><td>general</td><td>Offboard User Permanently</td><td>New options <code>ReplaceManagerReferences</code> and <code>ReplaceSponsorReferences</code> reassign direct reports and sponsorships to the replacement person; <code>UserTypeSelector</code> restricts the runbook to member or guest accounts. All off by default.<br>Group membership export now uploads a timestamped JSON per run to the shared <code>RJReport.StorageAccount.*</code> storage account and returns a time-limited download link; the <code>OffboardUser*.export*</code> settings are replaced and the managed identity only needs <code>Storage Account Contributor</code> on the storage account.<br>Fix: <code>RevokeAccess</code> now reads the documented <code>revokeAccess</code> setting — tenants using the misspelled <code>revokaAccess</code> should rename it.<br>Guest accounts and names with special characters now resolve correctly.</td></tr><tr><td>✏️</td><td>user</td><td>general</td><td>Offboard User Temporarily</td><td>New options <code>ReplaceManagerReferences</code>, <code>ReplaceSponsorReferences</code> and <code>UserTypeSelector</code> as in <code>Offboard User Permanently</code>; <code>ManagerAsReplacementOwner</code> takes precedence over <code>ReplacementOwnerName</code>, which is now picked from the directory.<br>Group membership export now uses the shared <code>RJReport.StorageAccount.*</code> settings with a time-limited download link; the managed identity only needs <code>Storage Account Contributor</code> on the storage account.<br>Guest accounts and names with special characters now resolve correctly.</td></tr></tbody></table>

 
---
 
### General Changes
 
**Storage role documentation corrected.** Report uploads require the `Storage Account Contributor` role on the target storage account (not `Storage Blob Data Contributor`, which lacks `listKeys`). Corrected in permissions, documentation and error hints for `Report Devices Low Diskspace`, `Sync Channel Or Group Members (Scheduled)`, `Sync Shared Channel Owners (Scheduled)` and `List Signin Events`.
 
**Shared helper usage.** `List Mobile Devices` and `Notify Users About Low Diskspace (Scheduled)` use `Invoke-RjRbGraphBatch` for Graph batch requests (Retry-After-aware retries on throttling). `Offboard User Permanently` and `Offboard User Temporarily` use native `Connect-MgGraph` / `Invoke-MgGraphRequest` with `Get-GraphPagedResult`; their export uses the `RealmJoin.RunbookHelper` storage functions, dropping `Az.Storage` in favor of `Az.Accounts` and avoiding the known assembly conflict with `ExchangeOnlineManagement`.

</details>

<details>
<summary><strong>v2026.08.01</strong></summary>

> This patch release centers on configurable per-tenant email branding for all 28 report runbooks, and also adds a new user sign-in event analysis, safer stale-device notification routing, and broad module updates.
 
---
 
### Changes
 

<table data-full-width="true"><thead><tr><th width="62">Type</th><th width="82">Domain</th><th width="127">Subcategory</th><th width="140">Runbook</th><th>Details</th></tr></thead><tbody><tr><td>➕</td><td>user</td><td>security</td><td>List Signin Events</td><td>Retrieves and analyzes a user's Entra ID sign-in events over a configurable lookback window (1–30 days, default 7), with filters for sign-in type (interactive, non-interactive or both), failed sign-ins only, and an optional app-name filter.<br>Shows a per-application summary (success/failure counts, failure rate, most common error codes and their reasons), a failed sign-in detail view and the most recent events.<br>Optional report delivery as an email report and/or a time-limited download link; CSV and Excel report files are only created when a delivery method is selected and events were found.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Notify Users About Stale Devices (Scheduled)</td><td><code>OverrideEmailRecipient</code> now acts as a true global override: when set, all notifications (regular users, name-pattern matches, and the combined "no primary user" email) are redirected to that address, with a warning logged on every run.<br>Adds dedicated recipients for the combined no-primary-user email and for name-pattern matches (e.g. <code>DEM-*</code> accounts), so pattern routing works independently of the no-primary-user option.<br>Incomplete routing setups now stop with a clear error instead of silently changing delivery, and the run summary always states what was redirected versus sent directly to end users.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Add Or Remove SafeLinks Exclusion</td><td>The "Remove URL Pattern from Policy" action now reliably removes the given URL pattern from the policy's Do-Not-Rewrite list.</td></tr></tbody></table>

 
---
 
### General Changes
 
**Configurable email branding for reports and notifications.** Across all 28 runbooks that send report or notification emails, the header image, footer image and footer link can now be overridden per tenant via new `RJReport.Branding.HeaderImageUrl`, `RJReport.Branding.FooterImageUrl` and `RJReport.Branding.FooterLink` settings. In addition, the accent color (table headers, buttons, accent borders) and the primary text color can be set via `RJReport.Branding.AccentColor` and `RJReport.Branding.TextColor` (6-digit hex, e.g. `#0052cc`). Images are fetched from the configured public HTTPS URL on each run and validated (PNG, JPEG or GIF by file signature, max 200 KB); empty or invalid values fall back to the default RealmJoin graphics and colors and never prevent an email from being sent.
 
**Module updates.** Required PowerShell modules were raised to current, runtime-compatible versions across the repository: `RealmJoin.RunbookHelper` to 0.8.9 across all 168 runbooks (first bumped repo-wide to 0.8.8, then the 28 report runbooks and 4 batch-API runbooks to 0.8.9, and finally the remaining 136 runbooks so every runbook now uses the same current version); `ExchangeOnlineManagement` to 3.9.2 (29 previously older-pinned runbooks, so all 32 Exchange Online runbooks are now consistent — 3.9.2 is the latest version supported on the current PowerShell 7.4 runtime, with 3.10.x deferred until a 7.6 runtime is available); `MicrosoftTeams` to 7.9.0 (6 Teams phone runbooks); and the `Az.*` modules to `Az.Accounts` 5.5.2 (27 runbooks), `Az.Storage` 9.7.2 (includes a `Get-AzStorageBlobContent` security fix), `Az.DesktopVirtualization` 6.0.0, `Az.Compute` 11.8.0 and `Az.ManagementPartner` 0.8.0. `Az.Resources` was dropped from `List Inactive Devices`, `List Vulnerable App Regs` and `Export CloudPC Usage (Scheduled)` where it was no longer required.
 
**Shared helper consolidation.** Inline helpers were replaced with functions from `RealmJoin.RunbookHelper`: `Export-RjRbXlsx` moved into the module (20 runbooks), plus the branding mail parameters and image validation, and the report-email attachment size guard. Hand-rolled Graph `$batch` loops were replaced with `Invoke-RjRbGraphBatch`, which adds Retry-After–aware handling of Graph throttling (HTTP 429) in `Sync MFA Secure Users To Group (Scheduled)`, `Check Device Onboarding Exclusion (Scheduled)`, `Add Primary Users Of Devices To Group (Scheduled)`, `Find SMS Auth Phone Number` and `Set Or Remove Mobile Phone MFA`.
 
**Permissions model.** Internal maintenance only: the runbook permission definitions moved to a new schema with least-privilege reconciliation and optional permissions; the permissions required to run the runbooks are effectively unchanged.

</details>

<details>
<summary><strong>v2026.08</strong></summary>

> Adds scheduled Microsoft 365 service health monitoring and focuses on safer bulk operations — refined MFA-group syncing with admin and break-glass exclusions, multi-delegate mailbox access, and more granular out-of-office control.
 
---
 
#### Changes
 

<table data-full-width="true"><thead><tr><th width="62">Type</th><th width="82">Domain</th><th width="127">Subcategory</th><th width="140">Runbook</th><th>Details</th></tr></thead><tbody><tr><td>➕</td><td>org</td><td>general</td><td>Monitor Service Health (Scheduled)</td><td>Keeps an eye on the Microsoft 365 service health of your tenant on a schedule, so incidents and advisories affecting your services are noticed without having to watch the admin center.<br>Results can be delivered as a summary email report, with the sender taken from the <code>RJReport.EmailSender</code> tenant setting.<br>The report can be limited to selected services (e.g. Exchange, SharePoint, Teams) and optionally include historical service health data.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Notify Users About Stale Devices (Scheduled)</td><td>Adds optional override routing so stale devices without a primary user are gathered into a single summary email to a chosen recipient instead of being skipped, while everyone else is still notified directly.<br>A new name-pattern option (e.g. <code>DEM-*</code>) lets you redirect notifications for special accounts such as Device Enrollment Manager users to the same override recipient.</td></tr><tr><td>✏️</td><td>org</td><td>security</td><td>Sync MFA Secure Users To Group (Scheduled)</td><td>Admins are now excluded from the synced group by default: people holding an Entra ID directory role are never added and are removed if already present — useful when the group drives self-service password reset.<br>Adds flexible exclusions via a dedicated exclusion group and individually picked users (e.g. break-glass or service accounts), and the report now shows an exclusion reason per user.<br>Note: the managed identity needs an additional Graph permission, and with admin exclusion on by default existing admins are removed on the next run — review your schedules if that isn't intended.</td></tr><tr><td>✏️</td><td>user</td><td>mail</td><td>Delegate Full Access</td><td>You can now grant or remove Exchange Online Full Access for several delegates in one run via a multi-user picker, applying the same action and automapping setting to all of them.<br>Delegates without a mailbox are skipped instead of aborting the run, already-granted or already-removed permissions are treated as no-ops, and you get a per-delegate summary of what changed, stayed the same, failed or was skipped.</td></tr><tr><td>✏️</td><td>user</td><td>mail</td><td>Set Out Of Office</td><td>Adds control over who receives the external automatic reply (nobody, known contacts only, or everyone).<br>Shows the current auto-reply configuration before making changes and gives clearer, step-by-step status and error messages.</td></tr></tbody></table>

 
---
 
#### General Changes
 
The required `Microsoft.Graph.Authentication` PowerShell module was updated to version 2.39.0 across all runbooks that use the Microsoft Graph PowerShell modules (**40 runbooks**) to address S360 open-source vulnerability findings (SFI-ES5.2).

</details>

<details>
<summary><strong>v2026.07.01</strong></summary>

> Intermediate patch release: rolls out a new dependency-free Excel report writer across all report runbooks (with flexible CSV/XLSX delivery and download links) and adds new runbooks for Global Secure Access, MAM app-data wipe, membership synchronization and MFA-secure user grouping.
 
---
 
#### Changes
 

<table data-full-width="true"><thead><tr><th width="62">Type</th><th width="82">Domain</th><th width="136">Subcategory</th><th width="140">Runbook</th><th>Details</th></tr></thead><tbody><tr><td>➕</td><td>device</td><td>general</td><td>Wipe Managed App Data</td><td>Removes company data from apps protected by app protection policies (MAM) on a device, without wiping the whole device — mirroring the Intune "App selective wipe" flow.<br>Ideal for lost or stolen devices that are managed only through app protection policies. Wipe requests can be tracked and cancelled in the Intune portal.</td></tr><tr><td>➕</td><td>org</td><td>applications</td><td>Add GSA Application Registration</td><td>Creates a Global Secure Access application (Enterprise App or Quick Access App), assigns a connector group and adds an application segment (FQDN, IP, CIDR or IP range).<br>Automatically creates a matching security group following a configurable naming scheme and assigns it to the app. Includes pre-flight validation, an update mode to add further segments, and automatic rollback if a run fails.</td></tr><tr><td>➕</td><td>org</td><td>applications</td><td>Delete GSA Application Registration</td><td>Removes a Global Secure Access application by display name, together with its naming-scheme security group, after confirming the target really is a GSA / App Proxy application.<br>Any other assigned groups are listed but only removed when explicitly confirmed.</td></tr><tr><td>➕</td><td>org</td><td>general</td><td>Sync Channel Or Group Members</td><td>Keeps membership in sync in one direction — shared channel members into a security group, group members into another group, or group members into a shared channel.<br>Missing members are always added; removing extra members in the target is opt-in. Supports transitive group expansion, guest handling and a dry-run mode, with an optional email report and download link. Change reports are also delivered as an Excel workbook.</td></tr><tr><td>➕</td><td>org</td><td>security</td><td>Sync MFA Secure Users To Group (Scheduled)</td><td>Keeps an Entra ID group in sync with all users that have at least one "secure" MFA method registered (e.g. passkeys/FIDO2, Windows Hello / Secure Enclave, Authenticator app, OTP or certificate-based).<br>Which methods count as secure is configurable via toggles; an optional strict mode excludes anyone who also has an unsecure method (phone, email, security questions).<br>Offers an optional email report and download link, with results delivered as CSV and a formatted Excel workbook showing added/removed users and the per-user method evaluation.</td></tr><tr><td>✏️</td><td>device</td><td>general</td><td>Wipe Device</td><td>The Microsoft Defender for Endpoint risk check now runs as an upfront preflight check: when the device's risk score is Medium or High the wipe is aborted with a clear warning, protecting forensic data on devices that may be part of a security incident.<br>Adds an optional switch to place a (Windows) device into the compliance exclusion group after the wipe, giving it a longer compliance grace period once it re-enrolls via Autopilot. The exclusion group is validated up front, so a run aborts safely before any destructive action if it is missing.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Auto Approve Driver Updates (Scheduled)</td><td>Now produces a detailed driver approval report (policy, driver name, version, manufacturer, driver class, release date and per-driver outcome) as a CSV/Excel attachment and download.<br>The per-policy driver lists in the email body are capped at 15 entries with a pointer to the full attached report.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Delete Stale Devices (Scheduled)</td><td>Simplifies deletion control to a single setting with a clear choice between a report-only simulation (default, safe for scheduled runs) and actually deleting stale devices from Intune.<br>The report now reflects the real per-device outcome (Deleted/Failed) and adopts the standard email reporting with CSV and a formatted Excel workbook, plus an optional storage download link.<br>Adds optional user-scope filtering based on primary-user group membership.<br>Note: parameters changed (the old <code>ConfirmDeletion</code> / <code>sendAlertTo</code> / <code>sendAlertFrom</code> were replaced) — existing schedules and customizations should be reviewed.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Report Devices Without Primary User (Scheduled)</td><td>Now available as a scheduled runbook. Adds the device operating system to the output, CSV and email report, and platform filters to limit the report to selected platforms (all included by default).<br>Adds an optional storage download link for the report.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Report Users With More Than 5 Devices (Scheduled)</td><td>Now available as a scheduled runbook. The detailed report gains the device display name, clearer device-ID columns, an "InIntune" indicator and a new "Compliant" column (yes/no/unknown), with an option to limit the report to devices present in Intune.<br>Summary and details are delivered as a single Excel workbook (green/red highlighting for InIntune and Compliant), with an optional storage download link.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Report Windows Devices Without Autopilot (Scheduled)</td><td>Can now run as a scheduled runbook.</td></tr><tr><td>✏️</td><td>user</td><td>general</td><td>List Group Memberships</td><td>Adds optional email delivery of the result as a CSV attachment and an optional time-limited download link.<br>The report is now also delivered as a formatted Excel workbook.</td></tr><tr><td>✏️</td><td>user</td><td>general</td><td>List Group Ownerships</td><td>Adds optional email delivery of the result as a CSV attachment and an optional time-limited download link.<br>The report is now also delivered as a formatted Excel workbook.</td></tr></tbody></table>

 
---
 
#### General Changes
 
A new dependency-free Excel (xlsx) report writer (`Export-RjRbXlsx`, pure .NET — no additional PowerShell modules required) was introduced and rolled out across all modern report runbooks (**19 in total**). Highlights of the rollout:
 
- Every affected report now delivers its data as CSV and/or a RealmJoin-branded, formatted Excel workbook (typed and sortable cells, conditional highlighting, in-cell data bars, clickable links, an optional "Info" cover worksheet, and one worksheet per result set for multi-result reports).
- A new report file-format selection (**CSV only** / **CSV & XLSX** / **XLSX only**, default **CSV & XLSX**) controls which files are generated, attached to the report email and uploaded to storage.
- Every report email gained an attachment size guard (new inline helper `Send-RjRbGuardedReportEmail`) that automatically falls back to the Excel workbook alone when the attachments exceed the ~4 MB Graph sendMail limit, with a retry safety net.
- Several reports that previously only supported email delivery gained a storage download-link option (`CreateDownloadLink`): Report EPM Elevation Requests, Monitor Pending EPM Requests, Report License Assignment, Report Application Registration, Report Expiring Application Credentials, Cleanup Autopilot Devices, Report Stale Devices and Report Primary User Mismatch.
- Export Enterprise Application Users gained an email report option for the first time (previously storage-only), and List Inactive Enterprise Applications now delivers its results via email and/or download link (previously console output only).
Affected runbooks: **Export Enterprise Application Users** (Org/Applications), **List Inactive Enterprise Applications** (Org/Applications), **Report Application Registration** (Org/Applications), **Report Expiring Application Credentials (Scheduled)** (Org/Applications), **Auto Approve Driver Updates (Scheduled)** (Org/Devices), **Cleanup Autopilot Devices (Scheduled)** (Org/Devices), **Report Devices Without Primary User (Scheduled)** (Org/Devices), **Report Primary User Mismatch (Scheduled)** (Org/Devices), **Report Stale Devices (Scheduled)** (Org/Devices), **Report Users With More Than 5 Devices (Scheduled)** (Org/Devices), **Report Windows Devices Without Autopilot (Scheduled)** (Org/Devices), **Report License Assignment (Scheduled)** (Org/General), **Sync Channel Or Group Members (Scheduled)** (Org/General), **Sync Shared Channel Owners (Scheduled)** (Org/General), **Monitor Pending EPM Requests (Scheduled)** (Org/Security), **Report EPM Elevation Requests (Scheduled)** (Org/Security), **Sync MFA Secure Users To Group (Scheduled)** (Org/Security), **List Group Memberships** (User/General), **List Group Ownerships** (User/General).

</details>

<details>
<summary><strong>v2026.07</strong></summary>

> This release strengthens device security and Defender for Endpoint integration, automates Autopilot cleanup, and adds Exchange Online contact management — backed by module updates and improved notification emails.
 
---
 
### Changes
 

<table data-full-width="true"><thead><tr><th width="62">Type</th><th width="82">Domain</th><th width="127">Subcategory</th><th width="140">Runbook</th><th>Details</th></tr></thead><tbody><tr><td>➕</td><td>device</td><td>security</td><td>Check Defender Status</td><td>Compares a device between Entra ID and Microsoft Defender for Endpoint using its Entra device ID.<br>Reports whether the device is present in both systems, its onboarding and health state, and its Defender risk score.</td></tr><tr><td>➕</td><td>org</td><td>devices</td><td>Cleanup Autopilot Devices (Scheduled)</td><td>Identifies and removes orphaned or never-enrolled Autopilot devices based on configurable criteria, with optional email reporting of the results.<br>Can optionally also delete the matching Entra ID device objects to keep the directory clean.<br>Supports filtering by <code>Manufacturer</code> and <code>Model</code> to target specific device types.<br>Designed to run on a schedule for ongoing inventory maintenance.</td></tr><tr><td>➕</td><td>org</td><td>mail</td><td>Add Exchange Online Mail Contact</td><td>Creates an Exchange Online external mail contact, validating the email address format and checking for duplicate contacts, aliases, and display names before creation.<br>Optionally sets first name, last name, and alias, and can hide the contact from the Global Address List.</td></tr><tr><td>✏️</td><td>device</td><td>general</td><td>Wipe Device</td><td>Adds an optional <code>skipWipeIfAtRisk</code> setting (off by default): when enabled, the wipe only runs if the device's Microsoft Defender for Endpoint risk score is not Medium or High.<br>This protects forensic data (e.g. logs) on devices potentially involved in a security incident from being destroyed.<br>Requires the new Defender for Endpoint permission <code>Machine.Read.All</code>.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Report Primary User Mismatch (Scheduled)</td><td>Can now optionally include devices whose Intune primary user has been deleted from Entra ID in the report (off by default).</td></tr><tr><td>✏️</td><td>user</td><td>userinfo</td><td>Add User</td><td>Now supports setting the new user's sponsor during creation.</td></tr></tbody></table>

 
---
 
### General Changes
 
- Updated the `RealmJoin.RunbookHelper` module to **>= 0.8.7** across all runbooks. This version adds new functions for password/key vault handling and further improves the email-sending function, including better Outlook Classic compatibility. Each affected runbook's internal `$Version` was incremented by one patch level.
- Updated the `Microsoft.Graph.Authentication` module to **>= 2.38.0** across all affected runbooks.
- Improved notification emails across all email-sending runbooks: a localized "do not reply" footer was added, plus two optional, hidden-by-default parameters for runbooks that include Service Desk contact information — `ServiceDeskPortalUrl` (sourced from the RJReport tenant setting `RJReport.ServiceDesk_PortalUrl`) and `ServiceDeskTicketUrl` (a direct link to the related ticket). When set, each is rendered as a clickable link. Affected runbooks: **Reset MFA**, **List MFA Methods**, **Set or Remove Mobile Phone MFA**, **Create Temporary Access Pass** (User/Security) and **Notify Users About Stale Devices (Scheduled)** (Org/Devices).

</details>

<details>
<summary><strong>v2026.06.01</strong></summary>

> This patch centers on the reworked `RealmJoin.RunbookHelper` email engine — extensive improvements to report mailing (image embedding and Outlook Classic compatibility) rolled out across all runbooks — plus a fix for out-of-memory failures on large Intune tenants.
 
### Changes
 

<table data-full-width="true"><thead><tr><th width="62">Type</th><th width="82">Domain</th><th width="127">Subcategory</th><th width="140">Runbook</th><th>Details</th></tr></thead><tbody><tr><td>➕</td><td>org</td><td>devices</td><td>Report Windows Devices Without Autopilot</td><td>Lists all Windows Entra device objects that have no associated Windows Autopilot object, so you can spot devices missing from Autopilot enrollment.<br>Matching is done via the Autopilot object's Azure AD device ID (<code>azureActiveDirectoryDeviceId</code>).</td></tr><tr><td>➕</td><td>org</td><td>devices</td><td>Report Primary User Mismatch (Scheduled)</td><td>Compares the primary user recorded in Intune against the primary user recorded in the RealmJoin customer API for Windows managed devices, flags every device where the two differ, and emails the differences with a CSV attachment on a scheduled basis.</td></tr><tr><td>➕</td><td>org</td><td>general</td><td>Sync Shared Channel Owners (Scheduled)</td><td>Keeps the members of a mapped security group as owners of selected Teams and of every shared channel those teams host (shared channels do not inherit ownership from their parent team).<br>Teams are matched by exact display name; the team-name-to-owner-group mapping is maintained centrally via the <code>SharedChannelOwners.Mapping</code> org setting.<br>Add-only — existing owners and members are never removed — with a <code>WhatIfMode</code> dry run.<br>Optional email report and/or storage download link, each with per-team and per-change CSV output (both off by default).</td></tr><tr><td>✏️</td><td>device</td><td>general</td><td>Outphase Device</td><td>Can now optionally exclude a device from Microsoft Defender for Endpoint remediation by applying a configurable exclusion tag (default <code>ExcludeFromRemediation</code>); opt-in and off by default.<br>Requires the new Defender for Endpoint permissions <code>Machine.Read.All</code> and <code>Machine.ReadWrite.All</code>.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Outphase Devices</td><td>Adds the same optional Microsoft Defender for Endpoint exclusion tagging as the single-device runbook, applied to every device in the list (opt-in, off by default).<br>Requires the new Defender for Endpoint permissions <code>Machine.Read.All</code> and <code>Machine.ReadWrite.All</code>.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Check Device Onboarding Exclusion (Scheduled)</td><td>Fixes out-of-memory failures on tenants with large Intune inventories — managed devices are now filtered server-side instead of loading the full inventory into memory.<br>Migrated to native Microsoft Graph for better reliability.</td></tr></tbody></table>

 
### General Changes
 
- Updated the `RealmJoin.RunbookHelper` module to **>= 0.8.6** across every runbook that uses it. This version ships an extensive rework of the email-sending function around image embedding and Outlook Classic compatibility. As part of this change, the inline `Publish-RjRbFilesToStorageContainer` helper function was removed from two runbooks (now provided by the module): **Export Enterprise Application Users** (Org/Applications) and **Office 365 License Report** (Org/General).
- Updated the `Microsoft.Graph.Authentication` module to **>= 2.37.0** across all runbooks that use it.

</details>

<details>
<summary><strong>v2026.06</strong></summary>

> This release focuses on user security and MFA management, introducing a new runbook for listing authentication methods and adding optional user notification emails across multiple MFA-related runbooks. Additional improvements cover archive mailbox management, guest user invitations, and several reliability fixes.
 
---
 
### Changes
 

<table data-full-width="true"><thead><tr><th width="62">Type</th><th width="82">Domain</th><th width="127">Subcategory</th><th width="140">Runbook</th><th>Details</th></tr></thead><tbody><tr><td>➕</td><td>user</td><td>mail</td><td>Manage Archive Mailbox</td><td>Enables, disables, or retrieves the current status of the in-place archive mailbox for an Exchange Online user.<br>When enabling, automatically reconnects a soft-deleted archive mailbox (within the 30-day recovery window) instead of creating a new one.<br>The disable action includes a note confirming that the archive can be recovered within 30 days.</td></tr><tr><td>➕</td><td>user</td><td>security</td><td>List MFA Methods</td><td>Lists all Microsoft Entra ID MFA and authentication methods registered for a target user.<br>Phone numbers can optionally be masked to show only the last 4 digits (default off, setting hidden).<br>Optionally sends a notification email to the user when an administrator retrieves their MFA methods (default off, setting hidden).<br>The notification email language is auto-detected via usage location, with an override parameter to force German or English.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Invite External Guest Users</td><td>Added a sponsor assignment parameter.<br>Manager and sponsor are now shown by UPN instead of object ID in the summary, improving readability.<br>Added support for a customized email invitation message and a configurable invite redirection URL.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Report Apple MDM Cert Expiry (Scheduled)</td><td>Fixed an issue where VPP tokens were silently dropped from the report due to a faulty paged-result check.<br>Applied the same fix to DEP onboarding settings, which used the same faulty check.<br>The email report is now only sent when at least one alert is detected, avoiding unnecessary notifications when everything is in order.</td></tr><tr><td>✏️</td><td>org</td><td>mail</td><td>Add Shared Mailbox</td><td>Added a time zone selection parameter with predefined options and a default value, allowing the shared mailbox time zone to be configured directly during creation.</td></tr><tr><td>✏️</td><td>user</td><td>security</td><td>Reset MFA</td><td>Added an optional <code>NotifyUser</code> parameter that sends a notification email to the target user when an administrator resets their MFA methods (default off, setting hidden).<br>Email configuration (sender address, service desk display name, email, and phone number) is sourced from RJ tenant settings and hidden by default.<br>Email language is auto-detected via usage location, with a <code>LanguageOverride</code> parameter to force German or English.<br>Added a StatusQuo section that resolves the user's display name, primary email, and usage location before execution.</td></tr><tr><td>✏️</td><td>user</td><td>security</td><td>Set Or Remove Mobile Phone MFA</td><td>Added an optional <code>NotifyUser</code> parameter that sends a notification email to the target user when an administrator adds or removes their mobile phone MFA method (default off, setting hidden).<br>Email configuration (sender address, service desk display name, email, and phone number) is sourced from RJ tenant settings and hidden by default.<br>Email language is auto-detected via usage location, with a <code>LanguageOverride</code> parameter to force German or English.<br>The notification email text distinguishes between add and remove actions.</td></tr><tr><td>✏️</td><td>user</td><td>userinfo</td><td>Update User</td><td>Added support for updating the user's manager directly from within the runbook.</td></tr></tbody></table>

 
---
 
### General Changes
 
**PSScriptAnalyzer improvements across 6 runbooks** — Internal code quality fixes with no functional impact for end users. Includes removal of unused parameters, replacement of empty try/catch blocks, and suppression of false positive warnings. Affected runbooks:
 
- `org/applications` — Export Enterprise Application Users
- `org/devices` — Create Endpoint Analytics Baseline (Scheduled)
- `org/general` — Assign Groups By Template (Scheduled), Export Policy Report, Office 365 License Report
- `org/security` — List Admin Users

</details>

<details>
<summary><strong>v2026.05</strong></summary>

> This release introduces automated duplicate device name resolution for Intune environments, alongside targeted improvements to license reporting, guest user invitations, and policy export reliability.
 
---
 
### Changes
 

<table data-full-width="true"><thead><tr><th width="62">Type</th><th width="82">Domain</th><th width="136">Subcategory</th><th width="140">Runbook</th><th>Details</th></tr></thead><tbody><tr><td>➕</td><td>org</td><td>devices</td><td>Dedup Device Names (Scheduled)</td><td>Automatically detects and resolves duplicate device names in Intune on a scheduled basis.<br>The most recently enrolled duplicate is renamed using a configurable prefix and a random digit suffix; resolved names are synced back to Autopilot.<br>Supports an OS filter parameter (All / Windows / macOS / Other) and skips personal-owned devices and unsupported platforms with warnings.<br>Checks for pending rename actions before queuing to avoid issuing duplicate MDM commands.</td></tr><tr><td>✏️</td><td>org</td><td>applications</td><td>Export Enterprise Application Users</td><td>Updated the internal export function to the enhanced version introduced in the <code>Office 365 License Report</code> runbook, aligning export behaviour and capabilities across both runbooks.</td></tr><tr><td>✏️</td><td>device</td><td>general</td><td>Enroll Updatable Assets</td><td>Added an <code>All</code> option to the <code>UpdateCategory</code> parameter, which sequentially enrolls devices into Driver, Feature, and Quality updates in a single run — removing the need to execute the runbook separately for each update category.<br>Script restructured with proper regions and parameter logging for improved maintainability.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Export Policy Report</td><td>Improved pagination handling by replacing static <code>$top=1000</code> Graph API calls with <code>Get-GraphPagedResult</code> to ensure complete results in large tenants.<br>Added logging of the retrieved policy count per policy type for better transparency during execution.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Invite External Guest Users</td><td>Added new parameters: Given Name, Surname, Manager, Usage Location, and Company.<br>Display name is now automatically generated from the given name and surname if no explicit display name is provided, reducing manual input for standard guest invitations.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Office 365 License Report</td><td>Added an <code>includeUserData</code> parameter that optionally includes real user UPNs in Graph activity reports by temporarily disabling the Microsoft 365 report privacy setting during execution.<br>Note: the additional <code>ReportSettings.ReadWrite.All</code> permission is only required when <code>includeUserData</code> is enabled — tenants using this feature should update their permission assignments accordingly.<br>Script fully restructured with proper regions, parameter logging, and enhanced error handling.</td></tr></tbody></table>


</details>

<details>
<summary><strong>v2026.04.01</strong></summary>

> Patch release with three new runbooks for device and endpoint management, significant improvements to phone MFA handling for guest users, targeted bug fixes in the security domain, and a broad internal code quality pass across 25 runbooks.
 
---
 
### Changes
 

<table data-full-width="true"><thead><tr><th width="62">Type</th><th width="82">Domain</th><th width="127">Subcategory</th><th width="140">Runbook</th><th>Details</th></tr></thead><tbody><tr><td>➕</td><td>device</td><td>security</td><td>Show FileVault Recovery Key</td><td>Retrieves and displays the FileVault recovery key for a specified Mac device directly from Intune.<br>Provides a quick lookup for administrators without requiring manual navigation through the Intune portal.</td></tr><tr><td>➕</td><td>device</td><td>general</td><td>Assign Groups By Template</td><td>Adds a device to one or more Entra ID groups using either group object IDs or display names.<br>Enables structured, template-based group assignments for devices without requiring manual portal interaction.</td></tr><tr><td>➕</td><td>org</td><td>devices</td><td>Create Endpoint Analytics Baseline (Scheduled)</td><td>Creates a new Endpoint Analytics Baseline in Microsoft Intune on a scheduled basis.<br>The naming schema is configurable via runbook parameters, e.g. to include a timestamp for better tracking of baseline versions over time.</td></tr><tr><td>✏️</td><td>org</td><td>security</td><td>Find SMS Auth Phone Number</td><td>Added dynamic progress reporting based on total user count, making batch processing output more informative in large tenants.<br>Updated the "not found" message to indicate that soft-deleted user accounts may still hold a phone number reservation — helping administrators investigate cases where no active user is identified.</td></tr><tr><td>✏️</td><td>org</td><td>security</td><td>Add Defender Indicator</td><td>Fixed a logic issue in alert handling that could cause incorrect behavior when processing indicator responses.<br>Fixed the severity parameter not being passed correctly to the Microsoft Defender API.<br>Optimized runbook output to provide clearer information about the created indicator and its current status.</td></tr><tr><td>✏️</td><td>org</td><td>security</td><td>Notify Changed CA Policies</td><td>Optimized runbook output for improved readability and clarity of reported policy changes.</td></tr><tr><td>✏️</td><td>user</td><td>security</td><td>Set Or Remove Mobile Phone MFA</td><td>Switched from UPN-based to Object ID-based user identification, fixing 404 errors that occurred for guest users.<br>The runbook now displays the user's UPN, display name, and guest status after connecting, as well as the current phone number and SMS Sign-In state before any changes are made.<br>Restructured error handling for Graph API 409 Conflict ("phoneNumberNotUnique") errors: the runbook now suppresses the error, waits, verifies the actual MFA assignment state, and reports success with a conflict note if MFA was successfully assigned despite the SMS Sign-In conflict.<br>Added an embedded <code>Find-PhoneNumberOwner</code> function that searches for the user holding a phone number when MFA assignment truly fails, enabling administrators to identify and resolve conflicts directly.</td></tr><tr><td>✏️</td><td>user</td><td>general</td><td>Resize Windows 365</td><td>Fixed an issue where the <code>fromMailAddress</code> parameter was not being passed to the API, which could result in notification emails being sent without a valid sender address.</td></tr></tbody></table>

 
---
 
### General Changes
 
**Code quality improvements across 25 runbooks** — Internal PSScriptAnalyzer fixes to improve code consistency and static analysis compliance. These changes have no functional impact for end users. Improvements include suppression of false positive warnings, renaming of internal functions to use approved PowerShell verbs, and singular naming corrections. Affected runbooks:
 
- `device/security` — Show LAPS Password
- `device/general` — Enroll Updatable Assets, Unenroll Updatable Assets
- `group/devices` — Unenroll Updatable Assets (Scheduled)
- `org/applications` — Add Application Registration, Report Expiring Application Credentials (Scheduled), Update Application Registration
- `org/devices` — Outphase Devices
- `org/general` — Add Devices Of Users To Group (Scheduled), Add Primary Users Of Devices To Group (Scheduled), Add Security Group, Add Viva Engage Community, Assign Groups By Template (Scheduled), Check Assignments Of Devices, Check Assignments Of Users, Export CloudPC Usage (Scheduled), Export Policy Report, Office365 License Report
- `org/phone` — Get Teams Phone Number Assignment
- `org/security` — Backup Conditional Access Policies
- `user/general` — Assign Groups By Template
- `user/phone` — Disable Teams Phone, Get Teams User Info, Set Teams Permanent Call Forwarding
- `user/userinfo` — Update User
 
**Minor fixes** — Removed an unused parameter from an internal function in `Add Security Group` (org/general); simplified the internal `Save-ToDataTable` function in `Export CloudPC Usage (Scheduled)` (org/general); fixed a typo in `Office 365 License Report` (org/general).

</details>

<details>
<summary><strong>v2026.04</strong></summary>

> This release expands automation coverage with new runbooks for device management, compliance checking, and security, alongside reliability improvements across a broad set of existing runbooks.
 
---
 
### Changes
 

<table data-full-width="true"><thead><tr><th width="62">Type</th><th width="82">Domain</th><th width="136">Subcategory</th><th width="140">Runbook</th><th>Details</th></tr></thead><tbody><tr><td>➕</td><td>device</td><td>general</td><td>Set Primary User</td><td>Sets or changes the primary user of a device in Intune.<br>Ensures accurate device ownership for reporting and device management purposes.</td></tr><tr><td>➕</td><td>group</td><td>general</td><td>Add Primary Users Of Devices To Group (Scheduled)</td><td>Automatically adds the primary users of devices to a designated group on a scheduled basis.<br>Devices can be filtered by platform and last activity date to target only relevant devices.</td></tr><tr><td>➕</td><td>org</td><td>devices</td><td>Auto Approve Driver Updates (Scheduled)</td><td>Automatically approves pending driver updates in Intune based on configurable criteria such as device category and driver update class.<br>Reduces manual effort for routine driver update approvals in managed environments.</td></tr><tr><td>➕</td><td>org</td><td>devices</td><td>Check Device Compliance</td><td>Checks the compliance status of devices in Intune and identifies the specific reason for any non-compliant status.<br>Useful for targeted troubleshooting and compliance reporting without requiring manual inspection in the Intune portal.</td></tr><tr><td>➕</td><td>org</td><td>general</td><td>Sync Apple Tokens</td><td>Synchronizes Apple MDM push notification tokens between Intune and the Apple Push Notification Service (APNS).<br>Ensures that managed Apple devices continue to receive timely updates and push notifications.</td></tr><tr><td>➕</td><td>org</td><td>security</td><td>Find SMS Auth Phone Number</td><td>Searches for which user has a specific phone number registered as an SMS Sign-In or phone MFA method in Microsoft Entra ID.<br>Designed to help administrators resolve "phoneNumberNotUnique" errors by identifying the conflicting account.</td></tr><tr><td>✏️</td><td>org</td><td>applications</td><td>Export Enterprise Application Users</td><td>Added a generalized export function for Azure Storage Account.<br>Simplifies configuration when exporting user data to storage and aligns the export logic with other runbooks in this category.</td></tr><tr><td>✏️</td><td>org</td><td>applications</td><td>Update Application Registration</td><td>The updated list of redirect URIs is now included in the runbook output after changes are applied.<br>Provides immediate visibility into the current state of the registration without requiring a separate lookup.</td></tr><tr><td>✏️</td><td>user</td><td>security</td><td>Create Temporary Access Pass</td><td>Added parameter validation to ensure the pass duration falls within acceptable limits before execution.<br>Added optional email notification when a Temporary Access Pass is created, configurable via Runbook Customization parameters.<br>The notification language is automatically selected based on the user's usage location — German for users located in Germany, English otherwise.</td></tr><tr><td>✏️</td><td>user</td><td>security</td><td>Set Or Remove Mobile Phone MFA</td><td>Added detection and reporting for "phoneNumberNotUnique" errors, which occur when the target phone number is already registered for SMS Sign-In by another user.<br>Migrated all API calls to native Microsoft Graph API.<br>Pagination reliability improved as part of the broader Get-GraphPagedResult update (see General Changes).</td></tr></tbody></table>

 
---
 
### General Changes
 
**Pagination fix across 14 runbooks** — Replaced the previous custom pagination function with the simplified `Get-GraphPagedResult` function to improve reliability and consistency when handling large data sets. Without this fix, some runbooks could return incomplete results in large tenants. Affected runbooks:
 
- `org/applications` — Report Application Registration, Report Expiring Application Credentials (Scheduled)
- `org/devices` — Notify Users About Stale Devices (Scheduled), Report Devices Without Primary User, Report Stale Devices (Scheduled), Report Users With More Than 5 Devices
- `org/general` — Add Primary Users Of Devices To Group (Scheduled), Report Apple MDM Cert Expiry (Scheduled), Report License Assignment (Scheduled)
- `org/security` — Find SMS Auth Phone Number, List Admin Users, Monitor Pending EPM Requests (Scheduled), Report EPM Elevation Requests (Scheduled)
- `user/security` — Set Or Remove Mobile Phone MFA

</details>

<details>
<summary><strong>v2026.03</strong></summary>

> This release introduces two new Endpoint Privilege Management runbooks for org/security, expands stale device management with proactive user notifications, and brings significant usability improvements across reporting and assignment runbooks. A complete documentation overhaul across all runbooks improves clarity and onboarding for new administrators.
 
---
 
### Changes
 

<table data-full-width="true"><thead><tr><th width="62">Type</th><th width="82">Domain</th><th width="127">Subcategory</th><th width="140">Runbook</th><th>Details</th></tr></thead><tbody><tr><td>➕</td><td>device</td><td>security</td><td>Show Bitlocker Recovery Key</td><td>Retrieves and displays the BitLocker recovery key for a specified device directly from Intune.<br>Provides a quick way to look up recovery keys without navigating through the Intune portal manually.</td></tr><tr><td>➕</td><td>org</td><td>devices</td><td>Notify Users About Stale Devices (Scheduled)</td><td>Sends email notifications to users whose devices have been inactive beyond a configurable threshold, based on last activity date and platform.<br>Supports English, German, and fully customizable mail templates.<br>Complements the existing <code>Report Stale Devices (Scheduled)</code> runbook by proactively notifying users rather than just generating reports for administrators.</td></tr><tr><td>➕</td><td>org</td><td>security</td><td>Monitor Pending EPM Requests (Scheduled)</td><td>Monitors pending Endpoint Privilege Management (EPM) elevation requests that require admin review.<br>Sends email notifications only when pending requests are present, avoiding unnecessary noise.<br>Includes an optional detailed CSV export for audit purposes.</td></tr><tr><td>➕</td><td>org</td><td>security</td><td>Report EPM Elevation Requests (Scheduled)</td><td>Generates reports on EPM elevation requests with flexible filtering by status (Pending, Approved, Denied, Expired, Revoked, Completed) and configurable time range.<br>Designed to support regular EPM audit workflows and compliance reporting.</td></tr><tr><td>✏️</td><td>group</td><td>general</td><td>Unenroll Updatable Assets (Scheduled)</td><td>Renamed from <code>Unenroll Updatable Assets</code> to reflect the scheduled execution model.<br>Added an option to include user-owned devices in the unenrollment process, enabling more comprehensive management of updatable assets beyond corporate-owned devices.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Export All Intune Devices</td><td>Fixed an issue where devices with missing or incomplete primary user data caused export errors.<br>Added group-based filtering with a group picker, allowing exports to be scoped to members of a specific group — particularly useful in large tenants where exporting all devices is not practical.</td></tr><tr><td>✏️</td><td>org</td><td>devices</td><td>Report Stale Devices (Scheduled)</td><td>Added Include/Exclude User Groups filtering, allowing administrators to focus the report on devices belonging to specific user groups or explicitly exclude certain groups from the results.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Check Assignments Of Groups</td><td>Added a multi-group picker, enabling administrators to process multiple groups in a single run instead of executing the runbook separately for each group.</td></tr><tr><td>✏️</td><td>org</td><td>general</td><td>Check Assignments Of Users</td><td>Added a multi-user picker, enabling administrators to process multiple users in a single run.<br>Added required permissions for app assignment checks to the runbook documentation.</td></tr><tr><td>✏️</td><td>org</td><td>security</td><td>List Admin Users</td><td>The runbook output and CSV export now include PIM role assignment status (permanent vs. eligible) and the expiration date for eligible assignments.<br>Provides a more complete picture of privileged access without requiring a separate PIM report.</td></tr><tr><td>✏️</td><td>user</td><td>mail</td><td>Assign OWA Mailbox Policy</td><td>Added three new policy options to the selection:<br><code>OwaMailboxPolicy-NoSignatures</code> — for users who should not have email signatures in OWA<br><code>BookingsCreators</code> — for users who create Bookings appointments and need the corresponding add-in enabled<br><code>GetCurrent</code> — assigns the currently active policy for the user</td></tr><tr><td>➖</td><td>org</td><td>devices</td><td>Report Last Device Contact by Range</td><td>Removed — functionality is now fully covered by the updated <code>Report Stale Devices (Scheduled)</code> runbook, which includes enhanced filtering options that supersede this runbook's capabilities.</td></tr></tbody></table>

 
---
 
### General Changes
 
**Documentation overhaul across all runbooks** — Comprehensive rewrite of comment-based help in every runbook, including more detailed descriptions of functionality and parameters, clearer instructions for required permissions and setup steps, and improved formatting for better readability. This is particularly relevant for administrators onboarding new runbooks or setting up automation for the first time.
 
**Application Registration runbooks — permission tightening** — The required app role `Application.ReadWrite.All` has been replaced with the more restrictive `Application.ReadWrite.OwnedBy`, and `Directory.ReadWrite.All` has been removed as it is no longer required. Tenants using these runbooks should update their permission assignments accordingly to follow the principle of least privilege.

</details>

***

Prefer a different view? Browse these notes on the [GitHub Releases page](https://github.com/realmjoin/realmjoin-runbooks/releases) of the runbooks repository.

Looking for a more detailed, dated log of every individual runbook change? See the full [changelog](https://github.com/realmjoin/realmjoin-runbooks/blob/production/CHANGELOG.md) in the runbooks repository.

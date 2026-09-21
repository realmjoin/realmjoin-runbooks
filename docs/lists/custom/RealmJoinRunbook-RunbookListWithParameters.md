# Overview
This document combines the permission requirements and RBAC roles with the exposed parameters of each runbook. It helps to understand which access levels are needed alongside the required inputs to execute the runbooks.

| Category | Subcategory | Runbook Name | Synopsis | Permissions | RBAC Roles | Parameter | Required | Type | Parameter Description |
|----------|-------------|--------------|----------|-------------|------------|-----------|----------|------|-----------------------|
| Device | AVD | Restart Host | Restart this AVD session host and return it to service | Azure: Desktop Virtualization Host Pool Contributor and Virtual Machine Contributor on Subscription which contains the Hostpool<br> |  | DeviceName | ✓ | String | Name of the AVD session host. Set by the portal from the selected device. |
|  |  |  |  |  |  | SubscriptionIds | ✓ | String Array | Azure subscriptions that hold the AVD host pools. Taken from the tenant setting AVD.SubscriptionIds. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Toggle Drain Mode | Enable or disable drain mode on this AVD session host | Azure: Desktop Virtualization Host Pool Contributor on Subscription which contains the Hostpool<br> |  | DeviceName | ✓ | String | Name of the AVD session host. Set by the portal from the selected device. |
|  |  |  |  |  |  | DrainMode | ✓ | Boolean | Whether the host should stop accepting new sessions (drain mode on) or take new sessions again (drain mode off). |
|  |  |  |  |  |  | SubscriptionIds | ✓ | String Array | Azure subscriptions that hold the AVD host pools. Taken from the tenant setting AVD.SubscriptionIds. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | General | Assign Groups By Template | Add this device to a predefined set of groups | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- GroupMember.ReadWrite.All<br> |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | GroupsTemplate |  | String | Template that decides which groups the device joins. The available templates are set up in the runbook customization. |
|  |  |  |  |  |  | GroupsString | ✓ | String | Groups to add the device to, separated by commas. Usually filled in by the selected template. |
|  |  |  |  |  |  | UseDisplaynames |  | Boolean | Whether the group list contains display names instead of object IDs. Preset in the runbook customization. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Change Grouptag | Assign a new Autopilot group tag to this device | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br> |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | newGroupTag |  | String | Group tag that decides which Autopilot profile and dynamic groups the device gets. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Check Device Compliance | Check the Intune compliance status of this device | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- Organization.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | DetailedOutput |  | Boolean | Simple shows the overall state and the non-compliant policies. Detailed also lists every failing setting with its reason. |
|  |  |  |  |  |  | EmailTo |  | String | Send the compliance report to these addresses, separated by commas. Leave empty to only show the result in the run output. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Check Updatable Assets | Check whether this device is enrolled in Windows Update for Business | - **Type**: Microsoft Graph<br>&emsp;- WindowsUpdates.ReadWrite.All<br>&emsp;- Device.Read.All<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  | Enroll Updatable Assets | Enroll this device in Windows Update for Business | - **Type**: Microsoft Graph<br>&emsp;- WindowsUpdates.ReadWrite.All<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | UpdateCategory | ✓ | String | Update category to enroll the device in. All enrolls it in driver, feature and quality updates. |
|  |  | Outphase Device | Wipe this Windows device and clean up Intune, Autopilot and Entra ID | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br>&emsp;- Device.Read.All<br>- **Type**: WindowsDefenderATP<br>&emsp;- Machine.Read.All<br>&emsp;- Machine.ReadWrite.All<br> | - Cloud Device Administrator<br> | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | intuneAction |  | Int32 | Completely wipe erases all user and enrollment data on the device. Delete from Intune only removes the device record, for devices that are already wiped or destroyed. Do not wipe or remove leaves Intune untouched. |
|  |  |  |  |  |  | aadAction |  | Int32 | Delete removes the device object from Entra ID, Disable keeps it but blocks sign-ins from the device, and Keep leaves Entra ID untouched. |
|  |  |  |  |  |  | wipeDevice |  | Boolean | Legacy switch kept for compatibility. The choice under "Intune action" decides whether the device is wiped. |
|  |  |  |  |  |  | removeIntuneDevice |  | Boolean | Legacy switch kept for compatibility. The choice under "Intune action" decides whether the Intune record is deleted. |
|  |  |  |  |  |  | removeAutopilotDevice |  | Boolean | Removing the device from the Autopilot database lets it leave the tenant and be registered elsewhere. Keeping it allows a later redeployment in this tenant. |
|  |  |  |  |  |  | removeAADDevice |  | Boolean | Legacy switch kept for compatibility. The choice under "Entra ID object" decides whether the Entra ID object is deleted. |
|  |  |  |  |  |  | disableAADDevice |  | Boolean | Legacy switch kept for compatibility. The choice under "Entra ID object" decides whether the Entra ID object is disabled. |
|  |  |  |  |  |  | excludeFromDefender |  | Boolean | Tags the device in Microsoft Defender for Endpoint with the exclusion tag so rules that use the tag can exclude it from automated remediation. Skip leaves Defender untouched. |
|  |  |  |  |  |  | defenderExclusionTag |  | String | Tag name written to the device in Defender for Endpoint, for use in your exclusion rules. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Remove Primary User | Remove the primary user from this device | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br> |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Rename Device | Rename this device in Intune and Autopilot | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br> |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | NewDeviceName | ✓ | String | Up to 15 letters, digits and hyphens, starting and ending with a letter or digit, not digits only. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Set Primary User | Set a new primary user on this device | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br>&emsp;- User.Read.All<br> |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | NewPrimaryUserId | ✓ | String | User to assign. The current primary user is replaced; both are shown in the output. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Unenroll Updatable Assets | Unenroll this device from Windows Update for Business | - **Type**: Microsoft Graph<br>&emsp;- WindowsUpdates.ReadWrite.All<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | UpdateCategory | ✓ | String | Update category to unenroll the device from. Choosing all removes the device from Windows Update for Business entirely. |
|  |  | Wipe Device | Wipe this Windows or macOS device and clean up its records | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br>&emsp;- Device.Read.All<br>&emsp;- GroupMember.ReadWrite.All<br>- **Type**: WindowsDefenderATP<br>&emsp;- Machine.Read.All *(optional: Defender risk check)*<br> | - Cloud Device Administrator<br> | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | wipeDevice |  | Boolean | Completely wipe erases all user and enrollment data on the device. Do not wipe leaves the device untouched and only runs the selected cleanup steps. |
|  |  |  |  |  |  | useProtectedWipe |  | Boolean | Keeps trying to wipe even if the device is switched off in between, so the wipe cannot be dodged by powering off. Windows only. |
|  |  |  |  |  |  | removeIntuneDevice |  | Boolean | Deletes the device record in Intune. Only sensible when the device is already wiped or destroyed. |
|  |  |  |  |  |  | removeAutopilotDevice |  | Boolean | Removing the device from the Autopilot database lets it leave the tenant and be registered elsewhere. Keeping it allows a later redeployment in this tenant. Windows only. |
|  |  |  |  |  |  | removeAADDevice |  | Boolean | Whether the Entra ID device object is deleted after the wipe. Preset in the runbook customization. |
|  |  |  |  |  |  | disableAADDevice |  | Boolean | Disabling blocks sign-ins from the device but keeps its object in Entra ID. Keep leaves the Entra ID object unchanged. |
|  |  |  |  |  |  | skipWipeIfAtRisk |  | Boolean | Skips the wipe when Microsoft Defender for Endpoint rates the device as medium or high risk. That keeps evidence intact on a device that may be part of a security incident. |
|  |  |  |  |  |  | addToExclusionGroup |  | Boolean | Adds the device to the compliance exclusion group so it gets a longer compliance grace period when it is re-enrolled through Autopilot. Windows only. |
|  |  |  |  |  |  | exclusionGroupName |  | String | Display name of the exclusion group the device is added to. An object ID preset in the runbook customization takes precedence. |
|  |  |  |  |  |  | exclusionGroupId |  | String | Object ID of the exclusion group. Preset in the runbook customization and used instead of the group name to avoid name clashes. |
|  |  |  |  |  |  | macOsRecoveryCode |  | String | Recovery code for older Macs that need one to be wiped. Newer devices ignore it. Preset in the runbook customization. |
|  |  |  |  |  |  | macOsObliterationBehavior |  | String | How a Mac is erased: erase user data first and fall back to erasing the OS, never erase the OS, warn before erasing the OS, or always erase the OS. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Wipe Managed App Data | Remove company app data from this MAM-managed device | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementApps.ReadWrite.All<br>&emsp;- Device.Read.All<br>&emsp;- User.Read.All<br> | - Intune Administrator<br> | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | Security | Check Defender Status | Check this device in Entra ID and Defender for Endpoint | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>- **Type**: WindowsDefenderATP<br>&emsp;- Machine.Read.All<br> |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Enable Or Disable Device | Enable or disable this device in Entra ID | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br> | - Cloud Device Administrator<br> | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | Enable |  | Boolean | Disable blocks sign-ins from the device. Enable again lifts an earlier block. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Isolate Or Release Device | Isolate this device from the network or release it | - **Type**: WindowsDefenderATP<br>&emsp;- Machine.Read.All<br>&emsp;- Machine.Isolate<br> |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | Release | ✓ | Boolean | Isolate cuts the device off from the network, with full isolation except for the Defender service. Release restores its normal connectivity. |
|  |  |  |  |  |  | IsolationType |  | String | Full blocks all traffic except to Defender; Selective keeps Outlook, Teams and Skype for Business working. Preset in the runbook customization. |
|  |  |  |  |  |  | Comment | ✓ | String | Short reason for the isolation or release. It is stored with the action in Defender for Endpoint. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Reset Mobile Device Pin | Reset the passcode of this mobile device | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br>- **Type**: WindowsDefenderATP<br>&emsp;- Machine.Read.All *(optional: Defender risk check)*<br> |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | skipIfAtRisk |  | Boolean | Skips the reset when Microsoft Defender for Endpoint rates the device as medium or high risk, so a reset cannot open a device that is under investigation. Devices unknown to Defender are not blocked. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Restrict Or Release Code Execution | Restrict this device to Microsoft-signed code or lift the restriction | - **Type**: WindowsDefenderATP<br>&emsp;- Machine.Read.All<br>&emsp;- Machine.RestrictExecution<br> |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | Release | ✓ | Boolean | Restrict allows only Microsoft-signed code to run on the device. Remove lifts an existing restriction. |
|  |  |  |  |  |  | Comment | ✓ | String | Short reason for the restriction or its removal. It is stored with the action in Defender for Endpoint. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Show Bitlocker Recovery Key | Show the BitLocker recovery keys of this device | - **Type**: Microsoft Graph<br>&emsp;- BitlockerKey.Read.All<br>- **Type**: WindowsDefenderATP<br>&emsp;- Machine.Read.All *(optional: Defender risk check)*<br> |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | skipIfAtRisk |  | Boolean | Withholds the keys when Microsoft Defender for Endpoint rates the device as medium or high risk, so the security team can be consulted first. Devices unknown to Defender are not blocked. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Show Filevault Recovery Key | Show the FileVault recovery key of this Mac | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br>&emsp;- DeviceManagementManagedDevices.Read.All<br> |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Show LAPS Password | Show the local admin password of this device | - **Type**: Microsoft Graph<br>&emsp;- DeviceLocalCredential.Read.All<br> |  | DeviceId | ✓ | String | Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
| Group | Devices | Check Updatable Assets | Check Windows Update for Business enrollment of this group's devices | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- WindowsUpdates.ReadWrite.All<br>Azure: Contributor on Storage Account<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | GroupId | ✓ | String | Object ID of the group the runbook acts on. Set by the portal from the selected group. |
|  |  | Unenroll Updatable Assets (Scheduled) | Unenroll this group's devices from Windows Update for Business | - **Type**: Microsoft Graph<br>&emsp;- Group.Read.All<br>&emsp;- WindowsUpdates.ReadWrite.All<br>&emsp;- User.Read.All *(optional: User-owned devices)*<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | GroupId | ✓ | String | Object ID of the group the runbook acts on. Set by the portal from the selected group. |
|  |  |  |  |  |  | UpdateCategory | ✓ | String | Update category (driver, feature or quality) to unenroll the devices from. Choose all to delete the updatable asset registration entirely. |
|  |  |  |  |  |  | IncludeUserOwnedDevices |  | Boolean | Also unenrolls every device owned by the users in this group, nested groups included. |
|  | General | Add Or Remove Nested Group | Add a nested group to this group or remove it | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br>&emsp;- GroupMember.ReadWrite.All<br>- **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp *(optional: Mail-enabled groups)*<br> | - Exchange Administrator *(optional: Mail-enabled groups)*<br> | GroupID | ✓ | String | Object ID of the group the runbook acts on. Set by the portal from the selected group. |
|  |  |  |  |  |  | NestedGroupID | ✓ | String | Group that becomes a member of this group, or stops being one. |
|  |  |  |  |  |  | Remove |  | Boolean | Add makes the chosen group a member of this group. Remove takes an existing nesting away. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Or Remove Owner | Add an owner to this group or remove one | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- GroupMember.ReadWrite.All<br>- **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | GroupID | ✓ | String | Object ID of the group the runbook acts on. Set by the portal from the selected group. |
|  |  |  |  |  |  | UserId | ✓ | String | User who gets or loses the ownership. |
|  |  |  |  |  |  | Remove |  | Boolean | Add makes the user an owner. Remove takes the user off the owner list. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Or Remove User | Add a user to this group or remove one | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- GroupMember.ReadWrite.All<br>- **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp *(optional: Mail-enabled groups)*<br> | - Exchange Administrator *(optional: Mail-enabled groups)*<br> | GroupID | ✓ | String | Object ID of the group the runbook acts on. Set by the portal from the selected group. |
|  |  |  |  |  |  | UserId | ✓ | String | User who is added to or removed from the group. |
|  |  |  |  |  |  | Remove |  | Boolean | Add makes the user a member. Remove takes the membership away. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Change Visibility | Make this group public or private | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br> |  | GroupID | ✓ | String | Object ID of the group the runbook acts on. Set by the portal from the selected group. |
|  |  |  |  |  |  | Public |  | Boolean | Public groups can be found and joined by anyone in the organization, private groups only by their members. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List All Members | List all members of this group, nested groups included | - **Type**: Microsoft Graph<br>&emsp;- Group.Read.All<br>&emsp;- User.Read.All<br> |  | GroupId | ✓ | String | Object ID of the group the runbook acts on. Set by the portal from the selected group. |
|  |  |  |  |  |  | CallerName |  | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Owners | List the owners of this group | - **Type**: Microsoft Graph<br>&emsp;- Group.Read.All<br>&emsp;- User.Read.All<br> |  | GroupID | ✓ | String | Object ID of the group the runbook acts on. Set by the portal from the selected group. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List User Devices | List the devices registered to this group's members | - **Type**: Microsoft Graph<br>&emsp;- Group.Read.All<br>&emsp;- Device.Read.All<br>&emsp;- GroupMember.ReadWrite.All *(optional: Move devices to group)*<br> |  | GroupID | ✓ | String | Object ID of the group the runbook acts on. Set by the portal from the selected group. |
|  |  |  |  |  |  | moveGroup |  | Boolean | Whether the found devices are added to the chosen device group. Set by the "Action" choice. |
|  |  |  |  |  |  | targetgroup |  | String | Group the found devices are added to. Only used when "Action" adds the devices. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Remove Group | Delete this group and its Microsoft 365 resources | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br> |  | GroupId | ✓ | String | Object ID of the group the runbook acts on. Set by the portal from the selected group. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Rename Group | Rename this group or change its description | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br> |  | GroupId | ✓ | String | Object ID of the group the runbook acts on. Set by the portal from the selected group. |
|  |  |  |  |  |  | DisplayName |  | String | New name of the group, for a team also the team name. Leave empty to keep the current name. |
|  |  |  |  |  |  | MailNickname |  | String | New alias (mail nickname) of the group. The existing email addresses stay. Leave empty to keep the current alias. |
|  |  |  |  |  |  | Description |  | String | New description shown for the group. Leave empty to keep the current one. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | Mail | Enable Or Disable External Mail | Allow or block external senders for this Microsoft 365 group | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | GroupId | ✓ | String | Object ID of the group the runbook acts on. Set by the portal from the selected group. |
|  |  |  |  |  |  | Action |  | Int32 | Allow lets external senders email the group. Block limits it to internal senders. Query only shows the current state. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Show Or Hide In Address Book | Show or hide this group in the address book | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | GroupName | ✓ | String | Identity of the group in Exchange Online, such as its name or alias. Set by the portal from the selected group. |
|  |  |  |  |  |  | Action |  | Int32 | Show lists the group in the address book, Hide removes it from the lists, Query only shows the current state. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | Teams | Archive Team | Archive the team of this group | - **Type**: Microsoft Graph<br>&emsp;- TeamSettings.ReadWrite.All<br>&emsp;- Group.Read.All<br> |  | GroupID | ✓ | String | Object ID of the group the runbook acts on. Set by the portal from the selected group. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
| Organization | Applications | Add Application Registration | Create an application registration in Entra ID | - **Type**: Microsoft Graph<br>&emsp;- Application.ReadWrite.OwnedBy<br>&emsp;- Organization.Read.All<br>&emsp;- Group.ReadWrite.All<br> | - Application Developer<br> | ApplicationName | ✓ | String | Display name of the new application registration. |
|  |  |  |  |  |  | RedirectURI |  | String | Type of sign-in to set up: none, a web redirect URI, SAML, a public client (mobile and desktop) or a single-page application. The matching fields appear once you choose. |
|  |  |  |  |  |  | signInAudience |  | String | Who may sign in to the application. Preset to accounts in this tenant only (AzureADMyOrg). |
|  |  |  |  |  |  | webRedirectURI |  | String | Redirect URI of a web application, for example https://myapp.com/auth. Separate several with semicolons. |
|  |  |  |  |  |  | spaRedirectURI |  | String | Redirect URI of a single-page application, for example https://myapp.com. Separate several with semicolons. |
|  |  |  |  |  |  | publicClientRedirectURI |  | String | Redirect URI of a mobile or desktop client, for example myapp://auth. Separate several with semicolons. |
|  |  |  |  |  |  | EnableSAML |  | Boolean | Whether SAML sign-in is configured. Set by the "Redirect URI" choice. |
|  |  |  |  |  |  | SAMLReplyURL |  | String | Where the SAML response is sent (assertion consumer service URL). |
|  |  |  |  |  |  | SAMLSignOnURL |  | String | URL where users start the sign-in to the application. |
|  |  |  |  |  |  | SAMLLogoutURL |  | String | URL the application uses to sign users out. |
|  |  |  |  |  |  | SAMLIdentifier |  | String | Identifier of the application in SAML (entity ID). Leave empty to use urn:app: followed by the client ID. |
|  |  |  |  |  |  | SAMLRelayState |  | String | Value the application receives back after sign-in, for example to return to a page. |
|  |  |  |  |  |  | SAMLExpiryNotificationEmail |  | String | Email address that is notified before the SAML signing certificate expires. |
|  |  |  |  |  |  | SAMLCertificateLifeYears |  | Int32 | How many years the SAML signing certificate stays valid. |
|  |  |  |  |  |  | isApplicationVisible |  | Boolean | Lists the application in the users' My Apps portal. |
|  |  |  |  |  |  | UserAssignmentRequired |  | Boolean | Only assigned users can use the application. An access group is created for the assignment. |
|  |  |  |  |  |  | groupAssignmentPrefix |  | String | Text put in front of the access group name. Only used when user assignment is required. |
|  |  |  |  |  |  | implicitGrantAccessTokens |  | Boolean | Lets the application receive access tokens through the implicit flow. Needed only for older single-page apps. |
|  |  |  |  |  |  | implicitGrantIDTokens |  | Boolean | Lets the application receive ID tokens through the implicit flow. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add GSA Application Registration | Create a Global Secure Access application with its access group | - **Type**: Microsoft Graph<br>&emsp;- Application.ReadWrite.All<br>&emsp;- Directory.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- AppRoleAssignment.ReadWrite.All<br> |  | name | ✓ | String | Base name of the application. The final name is prefix plus name, for example GSA-MyApp. |
|  |  |  |  |  |  | prefix | ✓ | String | Text put in front of the name. A space is inserted unless the prefix ends with a hyphen, underscore or space. |
|  |  |  |  |  |  | groupPrefix |  | String | Text put in front of the access group name, independent of the application prefix. Usually preset in the runbook customization. |
|  |  |  |  |  |  | groupSuffix |  | String | Text appended to the access group name, for example " (users)". Leave empty for none. |
|  |  |  |  |  |  | applicationType | ✓ | String | Enterprise App creates a new GSA application. Quick Access App adds the segment to the tenant's existing Quick Access app instead. |
|  |  |  |  |  |  | connectorGroup |  | String | Connector group that publishes the application. The available groups are set up in the runbook customization. |
|  |  |  |  |  |  | destinationHost |  | String | Where the application lives: a host name (example.com), a single IP (192.168.0.1), a CIDR range (192.168.0.1/24) or an IP range (192.168.0.1..192.168.0.20). |
|  |  |  |  |  |  | destinationType |  | String | Kind of destination, derived automatically from the format of the destination host. |
|  |  |  |  |  |  | ports |  | String | Ports to publish: a single port (443), several (80,443) or a range (8000-8080). |
|  |  |  |  |  |  | protocol |  | String | TCP, UDP or both. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Delete Application Registration | Delete an application registration and its service principal | - **Type**: Microsoft Graph<br>&emsp;- Application.ReadWrite.OwnedBy<br>&emsp;- Group.ReadWrite.All<br> | - Application Developer<br> | ClientId | ✓ | String | Client ID (appId) of the application registration to delete. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Delete GSA Application Registration | Delete a Global Secure Access application and its access group | - **Type**: Microsoft Graph<br>&emsp;- Application.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br> |  | applicationName | ✓ | String | Full display name of the application, for example GSA-MyApp. |
|  |  |  |  |  |  | groupPrefix |  | String | Prefix of the access group's naming scheme, the same as in the add runbook. Usually preset in the runbook customization. |
|  |  |  |  |  |  | groupSuffix |  | String | Suffix of the access group's naming scheme, if one was used. |
|  |  |  |  |  |  | deleteAllAssignedGroups |  | Boolean | Also deletes every other group assigned to the application. Careful, such groups may be shared with other applications. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Export Enterprise Application Users | Export the owners and users of all enterprise applications | - **Type**: Microsoft Graph<br>&emsp;- Directory.Read.All<br>&emsp;- Application.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>Azure IaaS: - Contributor - access on subscription or resource group used for the export<br> |  | entAppsOnly |  | Boolean | Enterprise applications only, or every service principal in the tenant. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Taken from the tenant setting EntAppsReport.Container. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting EntAppsReport.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting EntAppsReport.StorageAccount.Name. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting EntAppsReport.LinkExpiryDays. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Inactive Enterprise Applications | List enterprise applications with no recent sign-ins | - **Type**: Microsoft Graph<br>&emsp;- AuditLog.Read.All<br>&emsp;- Directory.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | Days |  | Int32 | Applications with no sign-in for at least this many days are listed as inactive. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Report Application Registration | Report all application registrations, including deleted ones | - **Type**: Microsoft Graph<br>&emsp;- Application.Read.All<br>&emsp;- Directory.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- Organization.Read.All<br> |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | IncludeDeletedApps |  | Boolean | Also lists application registrations that were deleted within the last 30 days. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Report Expiring Application Credentials (Scheduled) | Report expiring client secrets and certificates of app registrations | - **Type**: Microsoft Graph<br>&emsp;- Application.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- Organization.Read.All<br> |  | listOnlyExpiring |  | Boolean | Only credentials that expire within the given number of days, or all credentials. |
|  |  |  |  |  |  | Days |  | Int32 | Credentials that expire within this many days count as about to expire. |
|  |  |  |  |  |  | CredentialType |  | String | Client secrets, certificates, or both. |
|  |  |  |  |  |  | ApplicationIds |  | String | Limits the report to these application (client) IDs, separated by commas. Leave empty for all applications. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Update Application Registration | Update redirect URIs, SAML and sign-in settings of an app registration | - **Type**: Microsoft Graph<br>&emsp;- Application.ReadWrite.OwnedBy<br>&emsp;- Group.ReadWrite.All<br> | - Application Developer<br> | ClientId | ✓ | String | Client ID (appId) of the application registration to update. |
|  |  |  |  |  |  | RedirectURI |  | String | Type of sign-in to set up: none, a web redirect URI, SAML, a public client (mobile and desktop) or a single-page application. The matching fields appear once you choose. |
|  |  |  |  |  |  | webRedirectURI |  | String | Redirect URI of a web application, for example https://myapp.com/auth. Separate several with semicolons. |
|  |  |  |  |  |  | publicClientRedirectURI |  | String | Redirect URI of a mobile or desktop client, for example myapp://auth. Separate several with semicolons. |
|  |  |  |  |  |  | spaRedirectURI |  | String | Redirect URI of a single-page application, for example https://myapp.com. Separate several with semicolons. |
|  |  |  |  |  |  | EnableSAML |  | Boolean | Whether SAML sign-in is configured. Set by the "Redirect URI" choice. |
|  |  |  |  |  |  | SAMLReplyURL |  | String | Where the SAML response is sent (assertion consumer service URL). |
|  |  |  |  |  |  | SAMLSignOnURL |  | String | URL where users start the sign-in to the application. |
|  |  |  |  |  |  | SAMLLogoutURL |  | String | URL the application uses to sign users out. |
|  |  |  |  |  |  | SAMLIdentifier |  | String | Identifier of the application in SAML (entity ID). |
|  |  |  |  |  |  | SAMLRelayState |  | String | Value the application receives back after sign-in, for example to return to a page. |
|  |  |  |  |  |  | SAMLExpiryNotificationEmail |  | String | Email address that is notified before the SAML signing certificate expires. |
|  |  |  |  |  |  | isApplicationVisible |  | Boolean | Lists the application in the users' My Apps portal. |
|  |  |  |  |  |  | UserAssignmentRequired |  | Boolean | Only assigned users can use the application. An access group is created for the assignment. |
|  |  |  |  |  |  | groupAssignmentPrefix |  | String | Text put in front of the access group name. Only used when user assignment is required. |
|  |  |  |  |  |  | implicitGrantAccessTokens |  | Boolean | Lets the application receive access tokens through the implicit flow. Needed only for older single-page apps. |
|  |  |  |  |  |  | implicitGrantIDTokens |  | Boolean | Lets the application receive ID tokens through the implicit flow. |
|  |  |  |  |  |  | disableImplicitGrant |  | Boolean | Switches implicit grant off for both token types, regardless of "Implicit grant for access tokens?" and "Implicit grant for ID tokens?". |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | Collab | Check Onedrive Status | Check whether a user's OneDrive is active, locked or deleted | - **Type**: Office 365 SharePoint Online<br>&emsp;- Sites.FullControl.All<br>SharePoint Online: grant 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API (AppId 00000003-0000-0ff1-ce00-000000000000) to the Automation account's system-assigned managed identity. This SharePoint app-only grant cannot be made through the standard Entra app-role-assignment automation used for Microsoft Graph and must be assigned manually per tenant (e.g. via the SharePoint admin center or the Grant-PnPAzureADAppSitePermission equivalent for managed identities).<br> |  | UserPrincipalName | ✓ | String | User principal name of the user whose OneDrive is checked. Deleted users are accepted. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Sharepoint Sitecollection Permission | List the administrators and members of a SharePoint site | - **Type**: Office 365 SharePoint Online<br>&emsp;- Sites.FullControl.All<br>Grant admin consent for the 'Sites.FullControl.All' application permission on the Office 365 SharePoint Online API (App ID 00000003-0000-0ff1-ce00-000000000000) to the Azure Automation account's system-assigned managed identity; this SharePoint app-only-via-managed-identity consent cannot be assigned through the standard Microsoft Graph app-role automation used for Graph permissions. See the runbook's documentation file for the assignment commands.<br> |  | SiteUrl | ✓ | String | Full URL of the site, for example https://contoso.sharepoint.com/sites/marketing. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Report Sharepoint Tenant Storage (Scheduled) | Monitor SharePoint storage and alert when limits are exceeded | - **Type**: Microsoft Graph<br>&emsp;- Mail.Send<br>&emsp;- Organization.Read.All<br>- **Type**: Office 365 SharePoint Online<br>&emsp;- Sites.FullControl.All<br>SharePoint Online: grant Sites.FullControl.All on the 'Office 365 SharePoint Online' resource (appId 00000003-0000-0ff1-ce00-000000000000) to the Automation Account's managed identity — this app-only grant cannot be made through the standard Entra app-role-assignment flow used for Microsoft Graph and must be assigned manually per tenant.<br> |  | AlertLowStorageLimitInGB | ✓ | Int32 | Send an alert when the free tenant storage drops below this many gigabytes. |
|  |  |  |  |  |  | AlertUnusedStorageLimitInGB |  | Int32 | Send an alert when the licensed storage that no site uses exceeds this many gigabytes. That storage could be reclaimed. |
|  |  |  |  |  |  | TopSiteCount |  | Int32 | How many of the largest site collections are listed. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the alert email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | AlertEmailTo | ✓ | String | Address the alert goes to when a limit is exceeded. |
|  |  |  |  |  |  | AlertEmailSubject | ✓ | String | Subject line of the alert email. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | Devices | Add Autopilot Device | Register a Windows device in Windows Autopilot | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br>&emsp;- User.Read.All *(optional: User assignment)*<br> |  | SerialNumber | ✓ | String | Serial number of the device as reported by Get-WindowsAutopilotInfo. |
|  |  |  |  |  |  | HardwareIdentifier | ✓ | String | Hardware hash of the device as reported by Get-WindowsAutopilotInfo. |
|  |  |  |  |  |  | AssignedUser |  | String | User to assign during the import. Microsoft no longer accepts this, so leave it empty. |
|  |  |  |  |  |  | Wait |  | Boolean | Keeps the runbook running until Autopilot has processed the import, so the result shows in the output. |
|  |  |  |  |  |  | GroupTag |  | String | Group tag to set on the device, for example to steer it into an Autopilot profile. Leave empty for none. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Device Via Corporate Identifier | Register a device in Intune by its corporate identifier | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br> |  | CorpIdentifierType | ✓ | String | Serial number for most devices, IMEI for cellular devices. |
|  |  |  |  |  |  | CorpIdentifier | ✓ | String | Value of the chosen identifier, exactly as printed on or reported by the device. |
|  |  |  |  |  |  | DeviceDescripton |  | String | Free text stored with the identifier, for example the device model or its owner. |
|  |  |  |  |  |  | OverwriteExistingEntry |  | Boolean | Replaces an entry that already exists for the same identifier. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Auto Approve Driver Updates (Scheduled) | Approve pending driver updates in Intune driver update policies | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementConfiguration.ReadWrite.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- Organization.Read.All<br> |  | PolicyNames |  | String | Only these driver update policies, separated by commas. Leave empty for all policies. |
|  |  |  |  |  |  | PolicyIds |  | String | Only these policy IDs, separated by commas. Leave empty for all policies. |
|  |  |  |  |  |  | DriverDisplayNamePattern |  | String | Only drivers whose name matches this pattern; wildcards such as * are allowed. |
|  |  |  |  |  |  | DriverClass |  | String | Only these driver classes, separated by commas, for example Bluetooth,Networking,Firmware. |
|  |  |  |  |  |  | DriverManufacturer |  | String | Only drivers from this manufacturer. |
|  |  |  |  |  |  | MaximumDriverAge |  | Int32 | Only drivers released within this many days, for example 30. Leave empty for any age. |
|  |  |  |  |  |  | OnlyNeedsReview |  | Boolean | Approves only drivers with the status "needs review". Turn off to also re-approve suspended or declined drivers. |
|  |  |  |  |  |  | WhatIf |  | SwitchParameter | Only shows which drivers would be approved and sends the report; nothing is approved. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | EmailTo |  | String | Send the approval report to these addresses, separated by commas. Leave empty to send no email. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Cleanup Autopilot Devices (Scheduled) | Remove orphaned and never-enrolled Autopilot registrations | - **Type**: Microsoft Graph<br>&emsp;- Device.ReadWrite.All<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- Organization.Read.All<br> |  | DeleteMode |  | String | WhatIf only reports the candidates. Delete Autopilot device removes the Autopilot registrations. Delete Autopilot and Entra device also removes the matching Entra ID device objects. |
|  |  |  |  |  |  | GroupTagFilter |  | String | Only devices with one of these Autopilot group tags, separated by commas and matched exactly. Leave empty for all. |
|  |  |  |  |  |  | ManufacturerFilter |  | String | Only these manufacturers, separated by commas; Dell also matches Dell Inc. Leave empty for all. |
|  |  |  |  |  |  | ModelFilter |  | String | Only these models, separated by commas; Surface also matches Surface Laptop 3. Leave empty for all. |
|  |  |  |  |  |  | ExcludeSerialNumbers |  | String | Serial numbers that are never touched, separated by commas. Leave empty to exclude nothing. |
|  |  |  |  |  |  | CleanupOrphanedDevices |  | Boolean | Removes registrations of devices that once contacted Intune but no longer exist there. |
|  |  |  |  |  |  | OrphanedLastContactedDays |  | Int32 | A device counts as orphaned only when its last contact with Intune is older than this many days, so recently active devices are safe. |
|  |  |  |  |  |  | CleanupNeverEnrolledDevices |  | Boolean | Removes registrations of devices that never contacted Intune and are older than "Never-enrolled after (days)". |
|  |  |  |  |  |  | NeverEnrolledAgeDays |  | Int32 | Never-enrolled registrations older than this many days, counted from their creation date, are removed. |
|  |  |  |  |  |  | EmailTo |  | String | Send the cleanup report to these addresses, separated by commas. Leave empty to send no email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Create Endpoint Analytics Baseline | Create an Endpoint Analytics baseline with a naming schema | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br> |  | BaselineNamingSchema | ✓ | String | Name pattern with placeholders such as {Year}, {Month}, {Date} or {DateTime}, for example EA-Baseline-{Year}-{Month}. |
|  |  |  |  |  |  | RemoveOldestBaseline |  | Boolean | Deletes the oldest baseline when 20 already exist. Turn off to stop with an error instead. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Dedup Device Names (Scheduled) | Rename Intune devices that share a display name | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br> |  | NamePrefix | ✓ | String | Fixed start of every generated name, for example PC-. |
|  |  |  |  |  |  | NameLength | ✓ | Int32 | Length of the generated name including the prefix; the rest is filled with random digits, so it must be longer than the prefix. |
|  |  |  |  |  |  | OsFilter |  | String | Which platforms are checked: all, Windows only, macOS only, or the others (Android, iOS, ChromeOS). |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Delete Stale Devices (Scheduled) | Delete Intune devices that have been inactive for too long | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br>&emsp;- Directory.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | Days |  | Int32 | Devices with no check-in for at least this many days count as stale. |
|  |  |  |  |  |  | Windows |  | Boolean | Includes Windows devices. |
|  |  |  |  |  |  | MacOS |  | Boolean | Includes macOS devices. |
|  |  |  |  |  |  | iOS |  | Boolean | Includes iOS and iPadOS devices. |
|  |  |  |  |  |  | Android |  | Boolean | Includes Android devices. |
|  |  |  |  |  |  | DeleteDevices |  | Boolean | Delete removes the stale devices from Intune. Report only lists them and changes nothing. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | UseUserScope |  | Boolean | Whether devices are filtered by the group membership of their primary user. Set by the "Filter by primary user group?" choice. |
|  |  |  |  |  |  | IncludeUserGroup |  | String | Only devices whose primary user is in this group. |
|  |  |  |  |  |  | ExcludeUserGroup |  | String | Skips devices whose primary user is in this group. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Get Bitlocker Recovery Key | Look up a BitLocker recovery key by its key ID | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>&emsp;- BitlockerKey.Read.All<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | bitlockeryRecoveryKeyId | ✓ | String | The key ID displayed on the BitLocker recovery screen of the device. |
|  |  | List Mobile Devices | List managed mobile devices with inventory and network details | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- Directory.Read.All *(optional: Group scope filtering)*<br>&emsp;- Organization.Read.All *(optional: Email report / download link)*<br>&emsp;- Mail.Send *(optional: Email report)*<br>Azure Storage Account: 'Storage Account Contributor' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required when CreateDownloadLink is used)<br> |  | Android |  | Boolean | Includes Android devices. |
|  |  |  |  |  |  | iOS |  | Boolean | Includes iOS and iPadOS devices. |
|  |  |  |  |  |  | IncludeNetworkDetails |  | Boolean | Adds IP address, subnet, ICCID, eSIM identifier, cellular technology, UDID, battery health and Shared iPad state. Needs one extra request per device, so large tenants take longer. |
|  |  |  |  |  |  | IncludePhoneNumber |  | Boolean | Shows the phone number column. Intune masks part of the number on personally owned devices anyway. |
|  |  |  |  |  |  | IncludeDeviceGroup |  | String | Only devices in this Entra ID group, nested groups included. Leave empty for all mobile devices. |
|  |  |  |  |  |  | IncludeUserGroup |  | String | Only devices whose primary user is in this group, nested groups included. Leave empty for all. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses, separated by commas. Leave empty to only show the result in the run output. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Notify Users About Low Diskspace (Scheduled) | Email users whose devices are running out of disk space | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- User.Read.All<br>&emsp;- Mail.Send<br>&emsp;- Organization.Read.All *(optional: Tenant name in email footer)*<br>&emsp;- Directory.Read.All *(optional: Group scope filtering)*<br> |  | ThresholdType |  | String | By a fixed amount of free gigabytes or by the percentage of free space on the disk. |
|  |  |  |  |  |  | FreeSpaceThresholdGB |  | Int32 | Devices with less free space than this many gigabytes are affected. |
|  |  |  |  |  |  | FreeSpacePercentThreshold |  | Int32 | Devices with less free space than this percentage of the disk are affected. |
|  |  |  |  |  |  | NotifyOnSeverity |  | String | Every device below the limit (Warning and Critical), or only devices below half of it (Critical only). |
|  |  |  |  |  |  | Windows |  | Boolean | Includes Windows devices. |
|  |  |  |  |  |  | MacOS |  | Boolean | Includes macOS devices. |
|  |  |  |  |  |  | MaxInventoryAgeDays |  | Int32 | Devices whose last Intune sync is older than this many days are skipped, as their disk data is stale. 0 disables the check. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the notification email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ServiceDeskDisplayName |  | String | Service desk name shown in the email. Taken from the tenant setting RJReport.ServiceDesk_DisplayName. |
|  |  |  |  |  |  | ServiceDeskEmail |  | String | Service desk email address shown in the email. Taken from the tenant setting RJReport.ServiceDesk_EMail. |
|  |  |  |  |  |  | ServiceDeskPhone |  | String | Service desk phone number shown in the email. Taken from the tenant setting RJReport.ServiceDesk_Phone. |
|  |  |  |  |  |  | ServiceDeskPortalUrl |  | String | Link to the service desk portal shown in the email. Taken from the tenant setting RJReport.ServiceDesk_PortalUrl. |
|  |  |  |  |  |  | ServiceDeskTicketUrl |  | String | Link to the service desk ticket shown in the email. Taken from the tenant setting RJReport.ServiceDesk_TicketUrl; empty means no link. |
|  |  |  |  |  |  | UseUserScope |  | Boolean | Whether users are filtered by group membership. Set by the "Filter users by group?" choice. |
|  |  |  |  |  |  | IncludeUserGroup |  | String | Only users in this group, nested groups included, are notified. |
|  |  |  |  |  |  | ExcludeUserGroup |  | String | Users in this group, nested groups included, are not notified. |
|  |  |  |  |  |  | IncludeDeviceGroup |  | String | Only devices in this Entra ID group, nested groups included, are checked. Can be combined with the user filter. |
|  |  |  |  |  |  | OverrideEmailRecipient |  | String | Sends every email to these addresses instead of the users, for tests and pilots. The mailbox gets one email per affected user within seconds, which mail filters may treat as spam; prefer a mailbox in your own tenant. |
|  |  |  |  |  |  | SimulationMode |  | Boolean | Simulation only lists the affected users and devices; nothing is sent. |
|  |  |  |  |  |  | MailTemplateLanguage |  | String | English, German, or the custom template from the runbook customization; English is used where the custom template is empty. |
|  |  |  |  |  |  | CustomMailTemplateSubject |  | String | Subject of the email when the custom template is used, for Warning and Critical alike. |
|  |  |  |  |  |  | CustomMailTemplateBeforeDeviceDetails |  | String | Text above the device list when the custom template is used. Markdown is allowed. |
|  |  |  |  |  |  | CustomMailTemplateAfterDeviceDetails |  | String | Text below the device list when the custom template is used; it replaces the built-in cleanup steps. Markdown is allowed. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Notify Users About Stale Devices (Scheduled) | Email users about devices they have not used for a while | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- Directory.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- Mail.Send<br> |  | Days |  | Int32 | Devices inactive for at least this many days count as stale. |
|  |  |  |  |  |  | MaxDays |  | Int32 | Only devices inactive for at most this many days are included. Leave empty for no upper limit. |
|  |  |  |  |  |  | Windows |  | Boolean | Includes Windows devices. |
|  |  |  |  |  |  | MacOS |  | Boolean | Includes macOS devices. |
|  |  |  |  |  |  | iOS |  | Boolean | Includes iOS and iPadOS devices. |
|  |  |  |  |  |  | Android |  | Boolean | Includes Android devices. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the notification email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ServiceDeskDisplayName |  | String | Service desk name shown in the email. Taken from the tenant setting RJReport.ServiceDesk_DisplayName. |
|  |  |  |  |  |  | ServiceDeskEmail |  | String | Service desk email address shown in the email. Taken from the tenant setting RJReport.ServiceDesk_EMail. |
|  |  |  |  |  |  | ServiceDeskPhone |  | String | Service desk phone number shown in the email. Taken from the tenant setting RJReport.ServiceDesk_Phone. |
|  |  |  |  |  |  | ServiceDeskPortalUrl |  | String | Link to the service desk portal shown in the email. Taken from the tenant setting RJReport.ServiceDesk_PortalUrl. |
|  |  |  |  |  |  | ServiceDeskTicketUrl |  | String | Link to the service desk ticket shown in the email. Leave empty for no link. |
|  |  |  |  |  |  | UseUserScope |  | Boolean | Whether users are filtered by group membership. Set by the "Filter users by group?" choice. |
|  |  |  |  |  |  | IncludeUserGroup |  | String | Only users in this group are notified. |
|  |  |  |  |  |  | ExcludeUserGroup |  | String | Users in this group are not notified. |
|  |  |  |  |  |  | OverrideEmailRecipient |  | String | Sends every email, including pattern-routed ones and the combined email, to these addresses instead of the normal recipients. For tests, pilots or a ticket system. |
|  |  |  |  |  |  | OverrideUserNamePattern |  | String | Wildcard patterns for user names, separated by commas, for example DEM-*,KIOSK-*. Emails of matching users go to the "Recipient for pattern-matched users" instead. |
|  |  |  |  |  |  | UserNamePatternEmailRecipient |  | String | Addresses that receive the emails of users matching the pattern, separated by commas. Required when a pattern is set and no override is active. |
|  |  |  |  |  |  | SendNoPrimaryUserDevicesToOverride |  | Boolean | Collects stale devices that have no primary user into one combined email to the "Recipient for devices without primary user". Those devices ignore the user filter. |
|  |  |  |  |  |  | NoPrimaryUserEmailRecipient |  | String | Addresses for the combined email, separated by commas. Required when the combined email is enabled and no override is set. |
|  |  |  |  |  |  | MailTemplateLanguage |  | String | English, German, or the custom template from the runbook customization; English is used where the custom template is empty. |
|  |  |  |  |  |  | CustomMailTemplateSubject |  | String | Subject of the email when the custom template is used. |
|  |  |  |  |  |  | CustomMailTemplateBeforeDeviceDetails |  | String | Text above the device list when the custom template is used. Markdown is allowed. |
|  |  |  |  |  |  | CustomMailTemplateAfterDeviceDetails |  | String | Text below the device list when the custom template is used. Markdown is allowed. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Outphase Devices | Wipe and clean up several devices at once | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br>&emsp;- Device.Read.All<br>- **Type**: WindowsDefenderATP<br>&emsp;- Machine.Read.All<br>&emsp;- Machine.ReadWrite.All<br> | - Cloud Device Administrator<br> | DeviceListChoice | ✓ | Int32 | Whether the list holds Entra ID device IDs or serial numbers. |
|  |  |  |  |  |  | DeviceList | ✓ | String | Device IDs or serial numbers, separated by commas. |
|  |  |  |  |  |  | intuneAction |  | Int32 | Completely wipe erases all user and enrollment data on the devices. Delete from Intune only removes the device records, for devices that are already wiped or destroyed. Do not wipe or remove leaves Intune untouched. |
|  |  |  |  |  |  | aadAction |  | Int32 | Delete removes the device objects from Entra ID, Disable keeps them but blocks sign-ins from the devices, and Keep leaves Entra ID untouched. |
|  |  |  |  |  |  | wipeDevice |  | Boolean | Legacy switch kept for compatibility. The choice under "Intune action" decides whether the devices are wiped. |
|  |  |  |  |  |  | removeIntuneDevice |  | Boolean | Legacy switch kept for compatibility. The choice under "Intune action" decides whether the Intune records are deleted. |
|  |  |  |  |  |  | removeAutopilotDevice |  | Boolean | Removing the devices from the Autopilot database lets them leave the tenant and be registered elsewhere. Keeping them allows a later redeployment in this tenant. |
|  |  |  |  |  |  | removeAADDevice |  | Boolean | Legacy switch kept for compatibility. The choice under "Entra ID object" decides whether the Entra ID objects are deleted. |
|  |  |  |  |  |  | disableAADDevice |  | Boolean | Legacy switch kept for compatibility. The choice under "Entra ID object" decides whether the Entra ID objects are disabled. |
|  |  |  |  |  |  | excludeFromDefender |  | Boolean | Tags the devices in Microsoft Defender for Endpoint with the exclusion tag so rules that use the tag can exclude them from automated remediation. Skip leaves Defender untouched. |
|  |  |  |  |  |  | defenderExclusionTag |  | String | Tag name written to the devices in Defender for Endpoint, for use in your exclusion rules. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Report Devices Low Diskspace (Scheduled) | Report devices that are running out of disk space | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- Organization.Read.All *(optional: Email report / download link)*<br>&emsp;- Mail.Send *(optional: Email report)*<br>Azure Storage Account: 'Storage Account Contributor' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required when CreateDownloadLink is used)<br> |  | ThresholdType |  | String | By a fixed amount of free gigabytes or by the percentage of free space on the disk. |
|  |  |  |  |  |  | FreeSpaceThresholdGB |  | Int32 | Devices with less free space than this many gigabytes are reported. |
|  |  |  |  |  |  | FreeSpacePercentThreshold |  | Int32 | Devices with less free space than this percentage of the disk are reported. |
|  |  |  |  |  |  | Windows |  | Boolean | Includes Windows devices. |
|  |  |  |  |  |  | MacOS |  | Boolean | Includes macOS devices. |
|  |  |  |  |  |  | iOS |  | Boolean | Includes iOS and iPadOS devices. |
|  |  |  |  |  |  | Android |  | Boolean | Includes Android devices. |
|  |  |  |  |  |  | ManufacturerFilter |  | String | Only these manufacturers, separated by commas; Dell also matches Dell Inc. Leave empty for all. |
|  |  |  |  |  |  | ModelFilter |  | String | Only these models, separated by commas; Surface also matches Surface Laptop 3. Leave empty for all. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Report Devices Without Primary User (Scheduled) | Report Intune devices without a primary user | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | IncludeWindows |  | Boolean | Includes Windows devices. |
|  |  |  |  |  |  | IncludeMacOS |  | Boolean | Includes macOS devices. |
|  |  |  |  |  |  | IncludeIOS |  | Boolean | Includes iOS and iPadOS devices. |
|  |  |  |  |  |  | IncludeAndroid |  | Boolean | Includes Android devices. |
|  |  |  |  |  |  | IncludeOther |  | Boolean | Includes devices with any other operating system, such as Linux or ChromeOS. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Report Primary User Mismatch (Scheduled) | Compare primary users between Intune and RealmJoin | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- Directory.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- Organization.Read.All<br> |  | SyncThresholdDays |  | Int32 | Only devices that synced with Intune within this many days are compared. |
|  |  |  |  |  |  | DeviceNamePrefix |  | String | Only devices whose name starts with this text. Leave empty for all. |
|  |  |  |  |  |  | IncludeMismatches |  | Boolean | Lists devices whose primary user differs between Intune and RealmJoin. |
|  |  |  |  |  |  | IncludeMissingInRealmJoin |  | Boolean | Lists devices that exist in Intune but not in RealmJoin. |
|  |  |  |  |  |  | IncludeMissingInIntune |  | Boolean | Lists devices that exist in RealmJoin but not in Intune. |
|  |  |  |  |  |  | IncludePrimaryUserDeleted |  | Boolean | Lists devices whose Intune primary user was deleted from Entra ID. Without this they would look like mismatches, because Intune rewrites the name of a deleted user. |
|  |  |  |  |  |  | UseDeviceScope |  | Boolean | Whether devices are filtered by group membership. Set by the "Filter by device group?" choice. |
|  |  |  |  |  |  | IncludeDeviceGroup |  | String | Only devices in this Entra ID group. |
|  |  |  |  |  |  | ExcludeDeviceGroup |  | String | Skips devices in this Entra ID group. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Report Stale Devices (Scheduled) | Report devices that have been inactive for too long | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- Directory.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | Days |  | Int32 | Devices with no check-in for at least this many days count as stale. |
|  |  |  |  |  |  | MaxDays |  | Int32 | Only devices inactive for at most this many days are included. Leave empty for no upper limit. |
|  |  |  |  |  |  | Windows |  | Boolean | Includes Windows devices. |
|  |  |  |  |  |  | MacOS |  | Boolean | Includes macOS devices. |
|  |  |  |  |  |  | iOS |  | Boolean | Includes iOS and iPadOS devices. |
|  |  |  |  |  |  | Android |  | Boolean | Includes Android devices. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | UseUserScope |  | Boolean | Whether devices are filtered by the group membership of their primary user. Set by the "Filter by primary user group?" choice. |
|  |  |  |  |  |  | IncludeUserGroup |  | String | Only devices whose primary user is in this group. |
|  |  |  |  |  |  | ExcludeUserGroup |  | String | Skips devices whose primary user is in this group. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Report Users With More Than 5-Devices (Scheduled) | Report users with more than five registered devices | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- DeviceManagementManagedDevices.Read.All<br> |  | IntuneOnlyDevices |  | Boolean | Counts only devices that are also managed by Intune, so unmanaged registrations are ignored. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Report Windows Devices Without Autopilot (Scheduled) | Report Windows devices in Entra ID without an Autopilot record | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>&emsp;- DeviceManagementServiceConfig.Read.All<br>&emsp;- Organization.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>Azure IaaS: - Contributor - access on subscription or resource group used for the export<br> |  | SendMail |  | Boolean | Send the report to the recipient email address. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Sync Device Serialnumbers To Entraid (Scheduled) | Copy Intune serial numbers into an Entra ID extension attribute | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br>&emsp;- Device.ReadWrite.All<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | ExtensionAttributeNumber |  | Int32 | Which of the Entra ID extension attributes (1 to 15) receives the serial number. |
|  |  |  |  |  |  | ProcessAllDevices |  | Boolean | Writes the attribute on every device, not only where it is missing or differs. |
|  |  |  |  |  |  | MaxDevicesToProcess |  | Int32 | Stops after this many devices; 0 means no limit. |
|  |  |  |  |  |  | sendReportTo |  | String | Address the report is sent to. Leave empty to send none. |
|  |  |  |  |  |  | sendReportFrom |  | String | Sender address of the report email. Use a mailbox that exists in the tenant. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | General | Add Devices Of Users To Group (Scheduled) | Add the devices of a user group's members to a device group | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br>&emsp;- User.Read.All<br>&emsp;- GroupMember.ReadWrite.All<br> |  | UserGroup | ✓ | String | Name or object ID of the group whose members' devices are collected. |
|  |  |  |  |  |  | DeviceGroup | ✓ | String | Name or object ID of the group the devices are added to. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | IncludeWindowsDevice |  | Boolean | Includes Windows devices. |
|  |  |  |  |  |  | IncludeMacOSDevice |  | Boolean | Includes macOS devices. |
|  |  |  |  |  |  | IncludeLinuxDevice |  | Boolean | Includes Linux devices. |
|  |  |  |  |  |  | IncludeAndroidDevice |  | Boolean | Includes Android devices. |
|  |  |  |  |  |  | IncludeIOSDevice |  | Boolean | Includes iOS devices. |
|  |  |  |  |  |  | IncludeIPadOSDevice |  | Boolean | Includes iPadOS devices. |
|  |  | Add Management Partner | List or add a Partner Admin Link (PAL) for the tenant | Owner or Contributor role on the Azure Subscription<br> |  | Action | ✓ | Int32 | List shows the current links, Add creates one for the "Partner ID". |
|  |  |  |  |  |  | PartnerId |  | Int32 | Microsoft Partner Network ID of the partner to link. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Microsoft Store App Logos | Add missing logos to Microsoft Store apps in Intune | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementApps.ReadWrite.All<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Office365 Group | Create a Microsoft 365 group, optionally with a team | - **Type**: Microsoft Graph<br>&emsp;- Group.Create<br>&emsp;- Team.Create<br>&emsp;- Group.Read.All<br>&emsp;- User.Read.All *(optional: Owner assignment)*<br> |  | MailNickname | ✓ | String | Alias of the group, used for its email address and SharePoint URL. |
|  |  |  |  |  |  | DisplayName |  | String | Name shown for the group. Leave empty to use the mail nickname. |
|  |  |  |  |  |  | CreateTeam |  | Boolean | Creates only the group with its SharePoint site, or also a Microsoft Teams team on top of it. |
|  |  |  |  |  |  | Private |  | Boolean | Public groups can be found and joined by anyone in the organization, private groups only by their members. |
|  |  |  |  |  |  | MailEnabled |  | Boolean | Gives the group a mailbox and email address. |
|  |  |  |  |  |  | SecurityEnabled |  | Boolean | Lets the group be used for permissions and access assignments. |
|  |  |  |  |  |  | Owner |  | String | Owner of the group. Leave empty for none; a team then gets the caller as owner. |
|  |  |  |  |  |  | Owner2 |  | String | Additional owner. Leave empty for none. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Or Remove Safelinks Exclusion | Allow a URL pattern in a Safe Links policy or remove it | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | Action |  | Int32 | Add puts the pattern on the exclusion list, Remove takes it off, List shows the policies and their settings. |
|  |  |  |  |  |  | LinkPattern |  | String | Pattern to exclude; * works as a wildcard for host and path, for example https://*.microsoft.com/*. |
|  |  |  |  |  |  | DefaultPolicyName | ✓ | String | Policy used when no policy name is given. |
|  |  |  |  |  |  | PolicyName |  | String | Policy to change. Leave empty to use the default policy. |
|  |  |  |  |  |  | CreateNewPolicyIfNeeded |  | Boolean | Creates the Safe Links policy and its assignment group when it does not exist yet. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Or Remove Smartscreen Exclusion | Allow, warn or block a URL in Defender SmartScreen | - **Type**: WindowsDefenderATP<br>&emsp;- Ti.ReadWrite.All<br> |  | action |  | Int32 | List shows all URL indicators, Add creates one for the domain, Remove deletes every indicator for it. |
|  |  |  |  |  |  | Url |  | String | Domain to manage, for example exclusiondemo.com. |
|  |  |  |  |  |  | mode |  | Int32 | What SmartScreen does with the domain: allow it, only audit access, warn the user, or block it. |
|  |  |  |  |  |  | explanationTitle |  | String | Short title stored with the indicator. |
|  |  |  |  |  |  | explanationDescription |  | String | Reason stored with the indicator, for example who requested the exclusion. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Or Remove Trusted Site | Add a URL to the Intune trusted sites list or remove it | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementConfiguration.ReadWrite.All<br> |  | Action | ✓ | Int32 | Add puts the URL into the policy, Remove takes it out, List shows the policies and their entries. |
|  |  |  |  |  |  | Url |  | String | Address to add or remove, starting with http:// or https://. |
|  |  |  |  |  |  | Zone |  | Int32 | Security zone the URL is assigned to: My computer (0), Local intranet (1), Trusted sites (2), Internet (3) or Restricted sites (4). |
|  |  |  |  |  |  | DefaultPolicyName |  | String | Policy used when several trusted sites policies exist and none is named. |
|  |  |  |  |  |  | IntunePolicyName |  | String | Policy to change. Leave empty to pick one automatically. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Primary Users Of Devices To Group (Scheduled) | Keep a group in sync with the primary users of Intune devices | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- User.Read.All<br> |  | TargetGroupId | ✓ | String | Group that receives the primary users. Its membership is managed by this runbook alone. |
|  |  |  |  |  |  | Windows |  | Boolean | Includes the primary users of Windows devices. |
|  |  |  |  |  |  | MacOS |  | Boolean | Includes the primary users of macOS devices. |
|  |  |  |  |  |  | iOS |  | Boolean | Includes the primary users of iOS and iPadOS devices. |
|  |  |  |  |  |  | Android |  | Boolean | Includes the primary users of Android devices. |
|  |  |  |  |  |  | AdvancedFilter |  | String | OData filter for the devices instead of the platform switches, for example startsWith(deviceName,'FWP-') and operatingSystem eq 'Windows'. |
|  |  |  |  |  |  | RemoveUsersWhenNoDeviceMatch |  | Boolean | Removes users from the target group when they are no longer primary user of a matching device. Turn off to only ever add. |
|  |  |  |  |  |  | IncludeGroupId |  | String | Only members of this group can be added to the target group. |
|  |  |  |  |  |  | ExcludeGroupId |  | String | Members of this group are never added and are removed if present. |
|  |  |  |  |  |  | ReportOnly |  | Boolean | Previews the changes without applying them. The preview goes by email, with the first 10 users per list in the body and the complete lists attached. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | EmailTo |  | String | Address the preview goes to. Only used in report-only mode. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Attach the complete lists as CSV, as an Excel workbook, or both. Only used in report-only mode. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Security Group | Create a security group in Entra ID | - **Type**: Microsoft Graph<br>&emsp;- Group.Create<br>&emsp;- Group.Read.All<br> |  | GroupName | ✓ | String | Name shown in Entra ID. Must be unique and must not contain a blocked word. |
|  |  |  |  |  |  | GroupDescription |  | String | Short text that explains what the group is for. Leave empty for none. |
|  |  |  |  |  |  | Owner |  | String | User who becomes owner of the group. Leave empty for no owner. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add User | Create a new user account in Entra ID | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - User Administrator<br>- Exchange Administrator<br> | GivenName | ✓ | String | First name of the user. |
|  |  |  |  |  |  | Surname | ✓ | String | Last name of the user. |
|  |  |  |  |  |  | UserPrincipalName |  | String | Sign-in name of the user. Derived from the name when empty. |
|  |  |  |  |  |  | MailNickname |  | String | Alias of the mailbox. Derived from the sign-in name when empty. |
|  |  |  |  |  |  | DisplayName |  | String | Derived from first and last name when empty. |
|  |  |  |  |  |  | CompanyName |  | String | Company the user belongs to. |
|  |  |  |  |  |  | JobTitle |  | String | Shown in the profile and in the address book. |
|  |  |  |  |  |  | Department |  | String | Department the user works in. |
|  |  |  |  |  |  | ManagerId |  | String | User who becomes the manager. |
|  |  |  |  |  |  | SponsorIds |  | String Array | Users recorded as sponsors of the new user. Several can be picked. |
|  |  |  |  |  |  | MobilePhone |  | String | Shown in the profile and in the address book. |
|  |  |  |  |  |  | LocationName |  | String | Office location shown in the profile. With templates from the runbook customization, picking one also fills in the address fields. |
|  |  |  |  |  |  | StreetAddress |  | String | Part of the postal address shown in the profile. Filled in by the office location template when one is picked. |
|  |  |  |  |  |  | PostalCode |  | String | Part of the postal address shown in the profile. Filled in by the office location template when one is picked. |
|  |  |  |  |  |  | City |  | String | Part of the postal address shown in the profile. Filled in by the office location template when one is picked. |
|  |  |  |  |  |  | State |  | String | Part of the postal address shown in the profile. |
|  |  |  |  |  |  | Country |  | String | Part of the postal address shown in the profile. Filled in by the office location template when one is picked. |
|  |  |  |  |  |  | UsageLocation |  | String | Two-letter country code that decides which licenses the user may get, for example DE. |
|  |  |  |  |  |  | DefaultLicense |  | String | Display name of the group that assigns the license; the user is added to it. Leave empty for none. |
|  |  |  |  |  |  | DefaultGroups |  | String | Display names of further groups the user is added to, separated by commas. |
|  |  |  |  |  |  | InitialPassword |  | String | Start password for the user. Leave empty to have one generated and shown in the output. |
|  |  |  |  |  |  | EnableEXOArchive |  | Boolean | Turns on the Exchange Online archive mailbox for the new user. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Viva Engange Community | Create a Viva Engage community with owners | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- GroupMember.ReadWrite.All<br> |  | CommunityName | ✓ | String | Name of the community, up to 264 characters. |
|  |  |  |  |  |  | CommunityPrivate |  | Boolean | A private community is visible only to its members. |
|  |  |  |  |  |  | CommunityShowInDirectory |  | Boolean | Lists the community in the Viva Engage directory so people can find it. |
|  |  |  |  |  |  | CommunityOwners |  | String | Sign-in names of the owners, separated by commas. |
|  |  |  |  |  |  | removeCreatorFromGroup |  | Boolean | Takes the API user that created the community out of the group, as long as at least one other owner exists. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Assign Groups By Template (Scheduled) | Add the users of a group to a predefined set of groups | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- Group.ReadWrite.All<br> |  | SourceGroupId | ✓ | String | Every user in this group is processed. |
|  |  |  |  |  |  | ExclusionGroupId |  | String | Users in this group are skipped. Leave empty to process all users. |
|  |  |  |  |  |  | GroupsTemplate |  | String | Template that decides which groups the users join. The available templates are set up in the runbook customization. |
|  |  |  |  |  |  | GroupsString | ✓ | String | Target groups, separated by commas. Usually filled in by the selected template. |
|  |  |  |  |  |  | UseDisplaynames |  | Boolean | Turn on when the group list holds display names instead of object IDs. Can be preset per template. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Bulk Delete Devices From Autopilot | Delete several Autopilot registrations by serial number | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br> |  | SerialNumbers | ✓ | String | Serial numbers of the devices to remove, separated by commas. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Bulk Retire Devices From Intune | Retire several Intune devices by serial number | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br> |  | SerialNumbers | ✓ | String | Serial numbers of the devices to retire, separated by commas. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Check AAD Sync Status (Scheduled) | Check the last Entra Connect sync and alert when it is off | - **Type**: Microsoft Graph<br>&emsp;- Directory.Read.All<br>&emsp;- Mail.Send<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | sendAlertTo |  | String | Gets the alert email when directory synchronization is found disabled. |
|  |  |  |  |  |  | sendAlertFrom |  | String | User in the tenant the alert is sent as; needs a mailbox. |
|  |  | Check Assignments Of Devices | Show which Intune policies and apps target given devices | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- DeviceManagementApps.Read.All<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | DeviceNames | ✓ | String | Names of the devices to check, separated by commas. |
|  |  |  |  |  |  | IncludeApps |  | Boolean | Also lists the apps assigned to the devices. |
|  |  | Check Assignments Of Groups | Show which Intune policies and apps target given groups | - **Type**: Microsoft Graph<br>&emsp;- Group.Read.All<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- DeviceManagementApps.Read.All<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | GroupIDs | ✓ | String Array | Assignments are matched against each picked group directly; assignments to parent groups are not included. |
|  |  |  |  |  |  | IncludeApps |  | Boolean | Also lists the apps assigned to the groups. |
|  |  | Check Assignments Of Users | Show which Intune policies and apps target given users | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- DeviceManagementApps.Read.All<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | UserPrincipalName | ✓ | String Array | Each picked user is checked separately through their group memberships, nested groups included. |
|  |  |  |  |  |  | IncludeApps |  | Boolean | Also lists the apps assigned to the users. |
|  |  | Check Autopilot Serialnumbers | Check which serial numbers are registered in Autopilot | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementServiceConfig.Read.All<br> |  | SerialNumbers | ✓ | String | Serial numbers to check, separated by commas. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Check Device Onboarding Exclusion (Scheduled) | Keep unenrolled Autopilot devices in a compliance exclusion group | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br>&emsp;- Device.Read.All<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- DeviceManagementServiceConfig.Read.All<br> |  | exclusionGroupName |  | String | Display name of the group that holds the excluded devices. |
|  |  |  |  |  |  | maxAgeInDays |  | Int32 | Devices enrolled within this many days stay in the group; older ones are removed. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Enrolled Devices Report (Scheduled) | Report first-time device enrollments of the last weeks | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementServiceConfig.Read.All<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- User.Read.All<br>&emsp;- Device.ReadWrite.All<br>Azure: Contributor on Storage Account<br> |  | Weeks |  | Int32 | How many weeks back to look for first enrollments. |
|  |  |  |  |  |  | dataSource |  | Int32 | Date of Autopilot profile assignment counts a device from the day its Autopilot profile was assigned, Date of Intune enrollment from the day it enrolled in Intune. |
|  |  |  |  |  |  | groupingSource |  | Int32 | Where the grouping attribute comes from: no grouping, Entra ID user or device properties, Intune device properties, or Autopilot device properties. |
|  |  |  |  |  |  | groupingAttribute |  | String | Name of the attribute the devices are grouped by, for example country or department. |
|  |  |  |  |  |  | exportCsv |  | Boolean | Uploads the report as CSV to the storage account and returns a download link. Needs a configured storage account. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report is uploaded to. Taken from the tenant setting EnrolledDevicesReport.Container. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account. Taken from the tenant setting EnrolledDevicesReport.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for the export. Taken from the tenant setting EnrolledDevicesReport.StorageAccount.Name. |
|  |  |  |  |  |  | StorageAccountLocation |  | String | Azure region used when the storage account has to be created. Taken from the tenant setting EnrolledDevicesReport.StorageAccount.Location. |
|  |  |  |  |  |  | StorageAccountSku |  | String | Performance tier used when the storage account has to be created. Taken from the tenant setting EnrolledDevicesReport.StorageAccount.Sku. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Export All Autopilot Devices | List or export all Windows Autopilot devices | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- DeviceManagementServiceConfig.Read.All<br> |  | ExportToFile |  | Boolean | List in the run output, or export to a CSV file with a download link. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the CSV file is uploaded to. Taken from the tenant setting IntuneDevicesReport.Container. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account. Taken from the tenant setting IntuneDevicesReport.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for the export. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Name. |
|  |  |  |  |  |  | StorageAccountLocation |  | String | Azure region used when the storage account has to be created. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Location. |
|  |  |  |  |  |  | StorageAccountSku |  | String | Performance tier used when the storage account has to be created. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Sku. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Export All Intune Devices | Export all Intune devices with their primary users' usage location | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- GroupMember.Read.All<br>&emsp;- Group.Read.All<br> |  | ContainerName |  | String | Storage container the CSV file is uploaded to. Taken from the tenant setting IntuneDevicesReport.Container. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account. Taken from the tenant setting IntuneDevicesReport.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for the export. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Name. |
|  |  |  |  |  |  | StorageAccountLocation |  | String | Azure region used when the storage account has to be created. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Location. |
|  |  |  |  |  |  | StorageAccountSku |  | String | Performance tier used when the storage account has to be created. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Sku. |
|  |  |  |  |  |  | SubscriptionId |  | String | Azure subscription that holds the storage account. Taken from the tenant setting IntuneDevicesReport.SubscriptionId. |
|  |  |  |  |  |  | FilterGroupID |  | String | Only devices whose primary user is in this group. Leave empty for all devices. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Export Cloudpc Usage (Scheduled) | Write daily Windows 365 usage data to an Azure table | - **Type**: Microsoft Graph<br>&emsp;- CloudPC.Read.All<br>&emsp;- Organization.Read.All<br>Azure IaaS: `Contributor` role on the Azure Storage Account used for storing CloudPC usage data<br> |  | Table |  | String | Table in the storage account the usage data is written to. Created when it does not exist yet. |
|  |  |  |  |  |  | ResourceGroupName | ✓ | String | Resource group that holds the storage account. |
|  |  |  |  |  |  | StorageAccountName | ✓ | String | Storage account that holds the table. |
|  |  |  |  |  |  | Days |  | Int32 | Usage of the past this many days is collected; days already in the table are updated, not added again. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Export Non Compliant Devices | Export non-compliant Intune devices with their failing settings | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>Azure IaaS: Access to create/manage Azure Storage resources if producing links<br> |  | produceLinks |  | Boolean | Uploads the CSV files to the storage account configured in the tenant settings and returns download links. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Taken from the tenant setting IntuneDevicesReport.Container. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account. Taken from the tenant setting IntuneDevicesReport.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for the export. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Name. |
|  |  |  |  |  |  | StorageAccountLocation |  | String | Azure region used when the storage account has to be created. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Location. |
|  |  |  |  |  |  | StorageAccountSku |  | String | Performance tier used when the storage account has to be created. Taken from the tenant setting IntuneDevicesReport.StorageAccount.Sku. |
|  |  |  |  |  |  | SubscriptionId |  | String | Azure subscription that holds the storage account. Taken from the tenant setting IntuneDevicesReport.SubscriptionId. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Export Policy Report | Export Intune and Entra ID policies as a Markdown report | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- Policy.Read.All<br>&emsp;- Directory.Read.All *(optional: Name resolution)*<br>Azure Storage Account: Contributor role on the Storage Account used for exporting reports<br> |  | produceLinks |  | Boolean | Uploads the report files to the storage account configured in the tenant settings and returns download links. |
|  |  |  |  |  |  | exportJson |  | Boolean | Also exports the raw policy definitions as JSON files. |
|  |  |  |  |  |  | renderLatexPagebreaks |  | Boolean | Adds LaTeX page breaks to the Markdown, so each policy starts on a new page when the Markdown is converted to PDF. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Taken from the tenant setting TenantPolicyReport.Container. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account. Taken from the tenant setting TenantPolicyReport.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for the export. Taken from the tenant setting TenantPolicyReport.StorageAccount.Name. |
|  |  |  |  |  |  | StorageAccountLocation |  | String | Azure region used when the storage account has to be created. Taken from the tenant setting TenantPolicyReport.StorageAccount.Location. |
|  |  |  |  |  |  | StorageAccountSku |  | String | Performance tier used when the storage account has to be created. Taken from the tenant setting TenantPolicyReport.StorageAccount.Sku. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Invite External Guest Users | Invite an external person as a guest user | - **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- Organization.Read.All<br> |  | InvitedUserEmail | ✓ | String | Email address of the person to invite. |
|  |  |  |  |  |  | InvitedUserDisplayName |  | String | Name shown for the guest in the directory. |
|  |  |  |  |  |  | GroupId |  | String | Group the guest is added to. Preset in the runbook customization; empty means none. |
|  |  |  |  |  |  | GivenName |  | String | First name of the guest. |
|  |  |  |  |  |  | Surname |  | String | Last name of the guest. |
|  |  |  |  |  |  | CompanyName |  | String | Company the guest works for. |
|  |  |  |  |  |  | ManagerName |  | String | User who becomes the guest's manager. |
|  |  |  |  |  |  | SponsorName |  | String | User recorded as the guest's sponsor. |
|  |  |  |  |  |  | CustomizeInvitation |  | Boolean | Shows fields for an own invitation message and redirect URL. |
|  |  |  |  |  |  | InvitationMessage |  | String | Text included in the invitation email. |
|  |  |  |  |  |  | InviteRedirectUrl |  | String | Page the guest lands on after accepting, for example a SharePoint site. |
|  |  |  |  |  |  | UsageLocation |  | String | Two-letter country code, for example US or DE, needed before licenses can be assigned. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List All Administrative Template Policies | List administrative template policies with their assignments | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- Group.Read.All<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Group License Assignment Errors | List groups whose license assignments have errors | - **Type**: Microsoft Graph<br>&emsp;- GroupMember.Read.All<br>&emsp;- Group.Read.All<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Monitor Service Health (Scheduled) | Alert by email about new Microsoft 365 service health issues | - **Type**: Microsoft Graph<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- Organization.Read.All<br>&emsp;- ServiceHealth.Read.All<br> |  | Services |  | String | Services to watch, separated by commas, for example Microsoft Intune, Microsoft Entra, Exchange Online. Leave empty for all services. Short names such as Intune work too. |
|  |  |  |  |  |  | LookbackHours |  | Int32 | How many hours back to look for newly announced issues, 1 to 168. Use the same interval as the schedule, for example 24 for a daily run, so nothing is missed or alerted twice. |
|  |  |  |  |  |  | IncludeAdvisories |  | Boolean | Also alerts on advisories, not only on incidents. |
|  |  |  |  |  |  | IncludeResolvedIssues |  | Boolean | Also alerts on issues Microsoft has already resolved by the time the runbook runs. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the alert email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | EmailTo | ✓ | String | Addresses that receive the alert emails, separated by commas. At least one is required. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Office365 License Report | Report Microsoft 365 license usage and availability | - **Type**: Microsoft Graph<br>&emsp;- Reports.Read.All<br>&emsp;- Directory.Read.All<br>&emsp;- User.Read.All<br>&emsp;- ReportSettings.ReadWrite.All<br>&emsp;- AuditLog.Read.All *(optional: Sign-in export)*<br>- **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp *(optional: Exchange licensing report)*<br> | - Exchange Administrator *(optional: Exchange licensing report)*<br> | printOverview |  | Boolean | Prints a table per license SKU with total, used, available and suspended counts in the run output. |
|  |  |  |  |  |  | includeExchange |  | Boolean | Adds Exchange Online reports such as shared mailbox licensing. |
|  |  |  |  |  |  | includeUserData |  | Boolean | Shows real user names in the activity reports by switching off the report privacy setting for the run; it is restored afterwards. The reports then contain personal data, so check your data protection rules first. |
|  |  |  |  |  |  | exportToFile |  | Boolean | Uploads the report files to the Azure Storage account configured in the tenant settings. |
|  |  |  |  |  |  | exportAsZip |  | Boolean | Uploads one ZIP file instead of the single report files. |
|  |  |  |  |  |  | produceLinks |  | Boolean | Returns time-limited download links for the uploaded files. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Taken from the tenant setting OfficeLicensingReport.Container. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account. Taken from the tenant setting OfficeLicensingReport.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for the export. Taken from the tenant setting OfficeLicensingReport.StorageAccount.Name. |
|  |  |  |  |  |  | SubscriptionId |  | String | Azure subscription that holds the storage account. Taken from the tenant setting OfficeLicensingReport.SubscriptionId. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Report Apple MDM Cert Expiry (Scheduled) | Alert before Apple MDM certificates and tokens expire | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementServiceConfig.Read.All<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | Days |  | Int32 | Certificates and tokens that expire within this many days are flagged. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  | Report Intune Enrollment Readiness | Report which users can enroll devices in Intune | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementServiceConfig.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- GroupMember.Read.All<br>&emsp;- Organization.Read.All<br>&emsp;- Policy.Read.All<br>&emsp;- RoleManagement.Read.Directory<br>&emsp;- User.Read.All<br>&emsp;- UserAuthenticationMethod.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | UserName |  | String Array | Each picked user is checked on its own. Leave empty to check only the members of the group. |
|  |  |  |  |  |  | GroupName |  | String | Group whose members are checked, nested groups included. Can be combined with individual users. |
|  |  |  |  |  |  | EnrollmentPlatform |  | String | Platform of the device the users want to enroll. Conditional Access policies scoped to other platforms are ignored; All platforms checks every platform and reports each one. |
|  |  |  |  |  |  | CheckPilotGroupMembership |  | Boolean | Adds a column with the pilot group membership; non-members are reported as Not ready. |
|  |  |  |  |  |  | PilotGroupDisplayName |  | String | Members of this group count as pilot users. The group is looked up by its display name. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | SendEmailReport |  | Boolean | Send the report to the recipient email address. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Report License Assignment (Scheduled) | Alert when license availability crosses thresholds | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | InputJson | ✓ | Object | SKU list with friendly names and minimum and maximum thresholds, as a JSON array. Preset in the runbook customization. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Report PIM Activations (Scheduled) | Report the PIM role activations of the last month by email | - **Type**: Microsoft Graph<br>&emsp;- AuditLog.Read.All<br>&emsp;- Mail.Send<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | sendAlertTo |  | String | Gets the monthly PIM activation report. |
|  |  |  |  |  |  | sendAlertFrom |  | String | User in the tenant the report is sent as; needs a mailbox. |
|  |  | Sync All Devices | Trigger an Intune sync on all Windows devices | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Sync Apple Tokens | Sync Apple enrollment and VPP tokens with Intune | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementApps.ReadWrite.All<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br> |  | SyncType | ✓ | String | Sync the Enrollment Program tokens, the VPP tokens, or both. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Sync Channel Or Group Members (Scheduled) | Mirror members between a Teams shared channel and a group | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- Channel.ReadBasic.All<br>&emsp;- ChannelMember.ReadWrite.All<br>&emsp;- TeamMember.ReadWrite.All<br>&emsp;- User.Read.All<br>&emsp;- Organization.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | Direction | ✓ | String | What is copied where: shared channel members into the target group, source group members into the target group, or source group members into the shared channel. |
|  |  |  |  |  |  | TeamId |  | String | Team that hosts the shared channel. Needed for the shared channel directions only. |
|  |  |  |  |  |  | ChannelName |  | String | Exact name of the shared channel in that team. Needed for the shared channel directions only. |
|  |  |  |  |  |  | SourceGroupId |  | String | Group whose members are copied. Needed when the source is a group. |
|  |  |  |  |  |  | TargetGroupId |  | String | Security group that receives the members. Needed when the target is a group. |
|  |  |  |  |  |  | RemoveExtraMembers |  | Boolean | Also removes members that exist only in the target, so it mirrors the source exactly. Otherwise members are only added. |
|  |  |  |  |  |  | IncludeGuests |  | Boolean | Also adds and removes guest users. Otherwise guests are left untouched on both sides. |
|  |  |  |  |  |  | RemoveFromTeam |  | Boolean | When a member is removed from the shared channel, also removes them from the host team. Only applies when a group is copied into a shared channel. |
|  |  |  |  |  |  | WhatIfMode |  | Boolean | Only logs what would change without writing anything. |
|  |  |  |  |  |  | SendEmailReport |  | Boolean | Send the report to the recipient email address. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Sync Shared Channel Owners (Scheduled) | Make a group's members owners of mapped teams and shared channels | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- Channel.ReadBasic.All<br>&emsp;- ChannelMember.ReadWrite.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- User.Read.All<br>&emsp;- Organization.Read.All *(optional: Email report)*<br> |  | TeamOwnerGroupMapping |  | Object | List of team names with the security group whose members become owners. Taken from the tenant setting SharedChannelOwners.Mapping. |
|  |  |  |  |  |  | IncludeTeamOwners |  | Boolean | Also makes the group members owners and members of the team itself, which is required for owning its channels. |
|  |  |  |  |  |  | WhatIfMode |  | Boolean | Only logs what would change without writing anything. |
|  |  |  |  |  |  | SendEmailReport |  | Boolean | Send the report by email after the run. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | Mail | Add Distribution List | Create a classic Exchange Online distribution group | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br>- **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | Alias | ✓ | String | Short name that becomes the part of the email address in front of the @ sign, for example MKTG for the marketing team. |
|  |  |  |  |  |  | PrimarySMTPAddress |  | String | Address the group sends and receives with. Leave empty to use the alias at the default domain. |
|  |  |  |  |  |  | GroupName |  | String | Name shown in the address book. Leave empty to use the alias. |
|  |  |  |  |  |  | Owner |  | String | User who manages the members of the group. Leave empty for none. |
|  |  |  |  |  |  | Roomlist |  | Boolean | Creates the group as a room list, so its rooms can be picked together in the Outlook room finder. |
|  |  |  |  |  |  | AllowExternalSenders |  | Boolean | Lets people outside the organization send email to the group. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Equipment Mailbox | Create an equipment mailbox with optional delegate | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br>- **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All *(optional: Disable user account)*<br> | - Exchange Administrator<br> | MailboxName | ✓ | String | Alias of the mailbox, which becomes the part of the email address in front of the @ sign. |
|  |  |  |  |  |  | DisplayName |  | String | Name shown in the address book. Leave empty to use the alias. |
|  |  |  |  |  |  | DelegateTo |  | String | User who gets full access to the mailbox and handles its booking requests. Leave empty for none. |
|  |  |  |  |  |  | AutoAccept |  | Boolean | Meeting requests are accepted automatically when the equipment is free. |
|  |  |  |  |  |  | AutoMapping |  | Boolean | The mailbox opens automatically in the delegate's Outlook. |
|  |  |  |  |  |  | DisableUser |  | Boolean | Blocks sign-in for the user account behind the mailbox. Booking keeps working. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Mail Contact | Create a mail contact for an external address | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | ExternalEmailAddress | ✓ | String | External address of the person. Mail to the contact is delivered there. |
|  |  |  |  |  |  | DisplayName | ✓ | String | Name shown in the address book. |
|  |  |  |  |  |  | Name |  | String | Unique name used to manage the contact in Exchange Online. Leave empty to use the display name. |
|  |  |  |  |  |  | FirstName |  | String | First name of the person. Can stay empty. |
|  |  |  |  |  |  | LastName |  | String | Last name of the person. Can stay empty. |
|  |  |  |  |  |  | Alias |  | String | Mail alias of the contact. Leave empty to have Exchange derive one from the contact name. |
|  |  |  |  |  |  | HideFromAddressLists |  | Boolean | Hides the contact from the global address list and the other address lists. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Or Remove Public Folder | Create or remove an Exchange Online public folder | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | PublicFolderName | ✓ | String | Name of the public folder to create or remove. |
|  |  |  |  |  |  | MailboxName |  | String | Public folder mailbox the new folder is created in. Leave empty to let Exchange choose. |
|  |  |  |  |  |  | AddPublicFolder | ✓ | Boolean | Whether the folder is created or removed. Set by the action selected in the portal. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Or Remove Teams Mailcontact | Give a Teams channel a friendly email address or remove it | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | RealAddress | ✓ | String | Email address that Teams generated for the channel. |
|  |  |  |  |  |  | DesiredAddress | ✓ | String | Friendly address that should forward to the channel. |
|  |  |  |  |  |  | DisplayName |  | String | Name shown for the contact in the address book. Leave empty to use the part of the friendly address before the @ sign. |
|  |  |  |  |  |  | Remove |  | Boolean | Set up the friendly address creates the mail contact; Remove the friendly address deletes it again. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Or Remove Tenant Allow Block List | Add or remove a Tenant Allow/Block List entry | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | Entry | ✓ | String | What to allow or block: a domain, an email address, a URL, or a file hash, matching the entry type. |
|  |  |  |  |  |  | ListType |  | String | Sender takes a domain or email address, URL a web address, File hash a SHA-256 hash. |
|  |  |  |  |  |  | Block |  | Boolean | Block list rejects matching mail, URLs or files; Allow list lets them through even when Defender would filter them. |
|  |  |  |  |  |  | Remove |  | Boolean | Add the entry creates it with the chosen expiry; Remove the entry deletes the existing entry with the same value. |
|  |  |  |  |  |  | DaysToExpire |  | Int32 | Days until a new entry expires and is removed automatically. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Room Mailbox | Create a room mailbox with optional delegate | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br>- **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All *(optional: Disable user account)*<br> | - Exchange Administrator<br> | MailboxName | ✓ | String | Alias of the mailbox, which becomes the part of the email address in front of the @ sign. |
|  |  |  |  |  |  | DisplayName |  | String | Name shown in the address book and the room finder. Leave empty to use the alias. |
|  |  |  |  |  |  | DelegateTo |  | String | User who gets full access to the mailbox and handles its booking requests. Leave empty for none. |
|  |  |  |  |  |  | Capacity |  | Int32 | How many people fit in the room. Shown in the room finder. |
|  |  |  |  |  |  | AutoAccept |  | Boolean | Meeting requests are accepted automatically when the room is free. |
|  |  |  |  |  |  | AutoMapping |  | Boolean | The mailbox opens automatically in the delegate's Outlook. |
|  |  |  |  |  |  | DisableUser |  | Boolean | Blocks sign-in for the user account behind the mailbox. Booking keeps working. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Add Shared Mailbox | Create a shared mailbox with optional delegate | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br>- **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All *(optional: Disable user account)*<br> | - Exchange Administrator<br> | MailboxName | ✓ | String | Alias of the mailbox, which becomes the part of the email address in front of the @ sign. |
|  |  |  |  |  |  | DisplayName |  | String | Name shown in the address book. Leave empty to use the alias. |
|  |  |  |  |  |  | DomainName |  | String | Domain of the email address. Leave empty to use the default domain of the tenant. |
|  |  |  |  |  |  | Language |  | String | Language of the mailbox, which sets the names of the default folders such as Inbox. |
|  |  |  |  |  |  | TimeZone |  | String | Time zone used for the calendar and timestamps of the mailbox. |
|  |  |  |  |  |  | DelegateTo |  | String | User who gets full access to the mailbox. Leave empty for none. |
|  |  |  |  |  |  | AutoMapping |  | Boolean | The mailbox opens automatically in the delegate's Outlook. |
|  |  |  |  |  |  | MessageCopyForSentAsEnabled |  | Boolean | Mails sent as the shared mailbox are also stored in its Sent Items folder. |
|  |  |  |  |  |  | MessageCopyForSendOnBehalfEnabled |  | Boolean | Mails sent on behalf of the shared mailbox are also stored in its Sent Items folder. |
|  |  |  |  |  |  | DisableUser |  | Boolean | Blocks sign-in for the user account behind the mailbox. Delegates keep their access. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Hide Mailboxes (Scheduled) | Hide or show all Bookings calendars in the address book | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | HideBookingCalendars | ✓ | Boolean | Hidden calendars cannot be found in Outlook or the address book; turn off to list them again. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Set Booking Config | Configure the Microsoft Bookings settings of the tenant | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | BookingsEnabled |  | Boolean | Turns Microsoft Bookings on for the tenant. |
|  |  |  |  |  |  | BookingsAuthEnabled |  | Boolean | Customers must sign in before they can book. |
|  |  |  |  |  |  | BookingsSocialSharingRestricted |  | Boolean | Removes the social sharing options from booking pages. |
|  |  |  |  |  |  | BookingsExposureOfStaffDetailsRestricted |  | Boolean | Keeps staff details such as email addresses off the booking pages. |
|  |  |  |  |  |  | BookingsMembershipApprovalRequired |  | Boolean | Staff must approve before they are added to a booking page. |
|  |  |  |  |  |  | BookingsSmsMicrosoftEnabled |  | Boolean | Customers can get SMS notifications about their bookings. |
|  |  |  |  |  |  | BookingsSearchEngineIndexDisabled |  | Boolean | Keeps booking pages out of search engine results. |
|  |  |  |  |  |  | BookingsAddressEntryRestricted |  | Boolean | Customers cannot enter their address when booking. |
|  |  |  |  |  |  | BookingsCreationOfCustomQuestionsRestricted |  | Boolean | Staff cannot add custom questions to booking forms. |
|  |  |  |  |  |  | BookingsNotesEntryRestricted |  | Boolean | Customers cannot add notes when booking. |
|  |  |  |  |  |  | BookingsPhoneNumberEntryRestricted |  | Boolean | Customers cannot enter their phone number when booking. |
|  |  |  |  |  |  | BookingsNamingPolicyEnabled |  | Boolean | Applies the prefix, suffix and blocked words rules to new booking page names. |
|  |  |  |  |  |  | BookingsBlockedWordsEnabled |  | Boolean | Rejects booking page names that contain a word from the blocked words list of the Microsoft 365 groups naming policy. |
|  |  |  |  |  |  | BookingsNamingPolicyPrefixEnabled |  | Boolean | Adds the prefix to every new booking page name. |
|  |  |  |  |  |  | BookingsNamingPolicyPrefix |  | String | Text put in front of new booking page names. |
|  |  |  |  |  |  | BookingsNamingPolicySuffixEnabled |  | Boolean | Adds the suffix to every new booking page name. |
|  |  |  |  |  |  | BookingsNamingPolicySuffix |  | String | Text appended to new booking page names. |
|  |  |  |  |  |  | CreateOwaPolicy |  | Boolean | Creates the Outlook web policy for Bookings creators if it is missing and turns off Bookings in the default policy. |
|  |  |  |  |  |  | OwaPolicyName |  | String | Name of the Outlook web policy for Bookings creators. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | Phone | Get Teams Phone Number Assignment | Check whether a phone number is assigned in Microsoft Teams | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> | PhoneNumber | ✓ | String | Number in international format without spaces, for example +49321987654, optionally with an extension as +49321987654;ext=123. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | Security | Add Defender Indicator | Add an allow or block indicator to Defender for Endpoint | - **Type**: WindowsDefenderATP<br>&emsp;- Ti.ReadWrite.All<br> |  | IndicatorValue | ✓ | String | The hash, thumbprint, IP address, domain name or URL the indicator applies to. Must match the indicator type. |
|  |  |  |  |  |  | IndicatorType | ✓ | String | File hash (SHA-256, SHA-1 or MD5), certificate thumbprint, IP address, domain name or URL. The value must be of this type. |
|  |  |  |  |  |  | Title | ✓ | String | Short name shown for the indicator in the Defender portal. |
|  |  |  |  |  |  | Description | ✓ | String | Why the indicator exists. Shown in the Defender portal and in alerts. |
|  |  |  |  |  |  | Action | ✓ | String | What Defender does on a match: Allow, Warn, Audit, Block, Block and remediate, or Alert and block. |
|  |  |  |  |  |  | Severity | ✓ | String | Severity of the alerts raised for this indicator. |
|  |  |  |  |  |  | GenerateAlert |  | Boolean | Raises an alert in the Defender portal each time the indicator matches. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Backup Conditional Access Policies | Back up all Conditional Access policies to Azure Storage | - **Type**: Microsoft Graph<br>&emsp;- Policy.Read.All<br>Azure IaaS: Access to the given Azure Storage Account / Resource Group<br> |  | ContainerName |  | String | Storage container the archive is uploaded to. Taken from the tenant setting CaPoliciesExport.Container; empty means a container named after the current date. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account. Taken from the tenant setting CaPoliciesExport.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for the backup. Taken from the tenant setting CaPoliciesExport.StorageAccount.Name. |
|  |  |  |  |  |  | StorageAccountLocation |  | String | Azure region used when the storage account has to be created. Taken from the tenant setting CaPoliciesExport.StorageAccount.Location. |
|  |  |  |  |  |  | StorageAccountSku |  | String | Performance tier used when the storage account has to be created. Taken from the tenant setting CaPoliciesExport.StorageAccount.Sku. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Find SMS Auth Phone Number | Find the user who holds an SMS sign-in phone number | - **Type**: Microsoft Graph<br>&emsp;- AuditLog.Read.All<br>&emsp;- User.Read.All<br>&emsp;- UserAuthenticationMethod.Read.All<br> |  | PhoneNumber | ✓ | String | Number in international format without spaces, for example +492349876543. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Admin Users | List all Entra ID admins and check their MFA methods | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- Directory.Read.All<br>&emsp;- RoleManagement.Read.All<br>&emsp;- RoleAssignmentSchedule.Read.Directory<br>&emsp;- UserAuthenticationMethod.Read.All *(optional: MFA state)*<br> |  | ExportToFile |  | Boolean | Uploads the report as CSV to the storage account configured in the tenant settings. |
|  |  |  |  |  |  | PimEligibleUntilInCSV |  | Boolean | Adds the end dates of PIM eligible and active assignments to the CSV report. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Taken from the tenant setting ListAdminsReport.Container. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account. Taken from the tenant setting ListAdminsReport.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for the export. Taken from the tenant setting ListAdminsReport.StorageAccount.Name. |
|  |  |  |  |  |  | StorageAccountLocation |  | String | Azure region used when the storage account has to be created. Taken from the tenant setting ListAdminsReport.StorageAccount.Location. |
|  |  |  |  |  |  | StorageAccountSku |  | String | Performance tier used when the storage account has to be created. Taken from the tenant setting ListAdminsReport.StorageAccount.Sku. |
|  |  |  |  |  |  | QueryMfaState |  | Boolean | With the check, each admin gets a column showing whether a method that counts as MFA is registered; without it, the report lists only the role assignments. |
|  |  |  |  |  |  | TrustEmailMfa |  | Boolean | Counts email as a valid MFA method. |
|  |  |  |  |  |  | TrustPhoneMfa |  | Boolean | Counts phone calls and SMS as a valid MFA method. |
|  |  |  |  |  |  | TrustSoftwareOathMfa |  | Boolean | Counts software OATH tokens as a valid MFA method. |
|  |  |  |  |  |  | TrustWinHelloMFA |  | Boolean | Counts Windows Hello for Business as a valid MFA method. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Expiring Role Assignments | List Entra ID role assignments that expire soon | - **Type**: Microsoft Graph<br>&emsp;- RoleManagement.Read.All<br>&emsp;- User.Read.All<br> |  | Days |  | Int32 | Assignments that expire within this many days are listed. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Inactive Devices | List devices with no recent sign-in or Intune sync | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- Directory.Read.All<br>&emsp;- Device.Read.All<br> |  | Days |  | Int32 | Devices with no sync or sign-in for at least this many days are listed. |
|  |  |  |  |  |  | Sync |  | Boolean | Last Intune sync looks at managed devices and their last check-in; Last sign-in looks at Entra ID device objects and their approximate last sign-in date. |
|  |  |  |  |  |  | ExportToFile |  | Boolean | List in the run output, or export to a CSV file in the storage account configured in the tenant settings. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Taken from the tenant setting InactiveDevices.Container. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account. Taken from the tenant setting InactiveDevices.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for the export. Taken from the tenant setting InactiveDevices.StorageAccount.Name. |
|  |  |  |  |  |  | StorageAccountLocation |  | String | Azure region used when the storage account has to be created. Taken from the tenant setting InactiveDevices.StorageAccount.Location. |
|  |  |  |  |  |  | StorageAccountSku |  | String | Performance tier used when the storage account has to be created. Taken from the tenant setting InactiveDevices.StorageAccount.Sku. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Inactive Users | List users with no recent interactive sign-in | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- AuditLog.Read.All<br>&emsp;- Organization.Read.All<br> |  | Days |  | Int32 | Users with no interactive sign-in for at least this many days are listed. |
|  |  |  |  |  |  | ShowBlockedUsers |  | Boolean | Also lists users and guests whose sign-in is blocked. |
|  |  |  |  |  |  | ShowUsersThatNeverLoggedIn |  | Boolean | Also lists users and guests that never signed in. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Information Protection Labels | List the sensitivity labels of the tenant with their IDs | - **Type**: Microsoft Graph<br>&emsp;- InformationProtectionPolicy.Read.All<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List PIM Rolegroups Without Owners (Scheduled) | Alert on PIM role groups that have no owner | - **Type**: Microsoft Graph<br>&emsp;- Group.Read.All<br>&emsp;- RoleManagement.Read.Directory<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- Organization.Read.All *(optional: Email report)*<br> |  | SendEmailIfFound |  | Boolean | Sends an email with the group names when such groups are found. |
|  |  |  |  |  |  | From |  | String | User in the tenant the alert is sent as; needs a mailbox. |
|  |  |  |  |  |  | To |  | String | Gets the email with the group names. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Users By MFA Methods Count | List users by how many MFA methods they registered | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- UserAuthenticationMethod.Read.All<br> |  | mfaMethodsRange | ✓ | String | No methods lists users without any registered method; the other ranges list users with that many registered methods. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Vulnerable App Regs | List app registrations possibly affected by CVE-2021-42306 | - **Type**: Microsoft Graph<br>&emsp;- Application.Read.All<br> |  | ExportToFile |  | Boolean | List in the run output, or export to a CSV file in the storage account configured in the tenant settings. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Taken from the tenant setting VulnAppRegExport.Container. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account. Taken from the tenant setting VulnAppRegExport.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for the export. Taken from the tenant setting VulnAppRegExport.StorageAccount.Name. |
|  |  |  |  |  |  | StorageAccountLocation |  | String | Azure region used when the storage account has to be created. Taken from the tenant setting VulnAppRegExport.StorageAccount.Location. |
|  |  |  |  |  |  | StorageAccountSku |  | String | Performance tier used when the storage account has to be created. Taken from the tenant setting VulnAppRegExport.StorageAccount.Sku. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Monitor Pending EPM Requests (Scheduled) | Alert by email about pending EPM elevation requests | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | DetailedReport |  | Boolean | Adds a table with every pending request and attaches the report files. Otherwise the email only states how many requests are pending. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  | Notify Changed CA Policies | Alert by email about Conditional Access policy changes | - **Type**: Microsoft Graph<br>&emsp;- Policy.Read.All<br>&emsp;- Mail.Send<br>&emsp;- User.Read.All<br> |  | From | ✓ | String | User in the tenant the alert is sent as; needs a mailbox. |
|  |  |  |  |  |  | To | ✓ | String | Gets the email with the list of changed policies. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Report EPM Elevation Requests (Scheduled) | Report EPM elevation requests by status and age | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  |  |  |  |  | IncludeApproved |  | Boolean | Includes requests an administrator approved. |
|  |  |  |  |  |  | IncludeDenied |  | Boolean | Includes requests an administrator rejected. |
|  |  |  |  |  |  | IncludeExpired |  | Boolean | Includes requests that expired before a decision was made. |
|  |  |  |  |  |  | IncludeRevoked |  | Boolean | Includes requests whose approval was withdrawn later. |
|  |  |  |  |  |  | IncludePending |  | Boolean | Includes requests that are still waiting for a decision. |
|  |  |  |  |  |  | IncludeCompleted |  | Boolean | Includes requests that were approved and used. |
|  |  |  |  |  |  | MaxAgeInDays |  | Int32 | Only requests created within this many days are reported. Intune keeps request details for 30 days. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  | Sync MFA Secure Users To Group (Scheduled) | Keep a group filled with users who registered a secure MFA method | - **Type**: Microsoft Graph<br>&emsp;- AuditLog.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- RoleManagement.Read.Directory<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- User.Read.All<br>&emsp;- Organization.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | TargetGroupId | ✓ | String | Group whose members are managed by this runbook. Members that no longer qualify are removed. |
|  |  |  |  |  |  | IncludePasskeys |  | Boolean | Passkeys and FIDO2 security keys, which are phishing-resistant, count as secure. |
|  |  |  |  |  |  | IncludePlatformCredentials |  | Boolean | Windows Hello for Business and macOS platform credentials count as secure. |
|  |  |  |  |  |  | IncludeMicrosoftAuthenticator |  | Boolean | The Microsoft Authenticator app, with push or passwordless sign-in, counts as secure. |
|  |  |  |  |  |  | IncludeSoftwareOtp |  | Boolean | Time-based one-time codes from authenticator apps count as secure. |
|  |  |  |  |  |  | IncludeHardwareOtp |  | Boolean | Hardware one-time password tokens count as secure. |
|  |  |  |  |  |  | IncludeCertificateBasedAuth |  | Boolean | Sign-in with a certificate, for example from a smart card, counts as secure. |
|  |  |  |  |  |  | SecureOnly |  | Boolean | Strict mode: users who also have a phone, email or security question method registered never qualify, even with a secure method. |
|  |  |  |  |  |  | SecureMethodsOverride |  | String | Custom list of method names that count as secure, separated by commas. When set, the individual method switches are ignored. Preset in the runbook customization; the method names are listed in the runbook documentation. |
|  |  |  |  |  |  | UnsecureMethodsOverride |  | String | Custom list of method names that count as unsecure in strict mode, separated by commas. Preset in the runbook customization. |
|  |  |  |  |  |  | ExcludeAdmins |  | Boolean | Users with an Entra ID directory role, active or eligible, never qualify and are removed from the group. Useful when the group drives self-service password reset. |
|  |  |  |  |  |  | ExcludeGroupId |  | String | Members of this group, for example break glass or service accounts, never qualify and are removed from the target group. Leave empty for none. |
|  |  |  |  |  |  | ExcludeUserIds |  | String Array | Users who never qualify and are removed from the target group. Several can be picked. |
|  |  |  |  |  |  | WhatIfMode |  | Boolean | Only logs which users would be added or removed without changing the group. |
|  |  |  |  |  |  | SendEmail |  | Boolean | Send the report by email after the run. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
| User | AVD | User Signout | Sign this user out of their AVD sessions | Azure: Desktop Virtualization Host Pool Contributor on Subscription which contains the Hostpool<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | SubscriptionIds | ✓ | String Array | Azure subscriptions that hold the AVD host pools. Taken from the tenant setting AVD.SubscriptionIds. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | General | Assign Groups By Template | Add this user to a predefined set of groups | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br> |  | UserId | ✓ | String | Object ID of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | GroupsTemplate |  | String | Template that decides which groups the user joins. The available templates are set up in the runbook customization. |
|  |  |  |  |  |  | GroupsString | ✓ | String | Groups to add the user to, separated by commas. Usually filled in by the selected template. |
|  |  |  |  |  |  | UseDisplaynames |  | Boolean | Whether the group list contains display names instead of object IDs. Preset in the runbook customization. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Assign Or Unassign License | Assign or remove a license for this user via a license group | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | GroupID_License | ✓ | String | Group that carries the license. Only groups whose name starts with LIC_ are offered. |
|  |  |  |  |  |  | Remove |  | Boolean | Assign adds the user to the group. Remove takes the user out of it. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Assign Windows365 | Provision a Windows 365 Cloud PC for this user | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- CloudPC.Read.All<br>&emsp;- Organization.Read.All<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | cfgProvisioningGroupName |  | String | Provisioning policy group for a dedicated Cloud PC, or the name of the Frontline provisioning policy. Type the name, or pick it when your runbook customization offers a list. |
|  |  |  |  |  |  | cfgUserSettingsGroupName |  | String | Group that carries the user settings policy, for example whether the user may restore the Cloud PC. |
|  |  |  |  |  |  | licWin365GroupName |  | String | License group for a dedicated Cloud PC. Not needed for Frontline. |
|  |  |  |  |  |  | cfgProvisioningGroupPrefix |  | String | Name prefix that identifies provisioning policy groups. Preset in the runbook customization. |
|  |  |  |  |  |  | cfgUserSettingsGroupPrefix |  | String | Name prefix that identifies user settings policy groups. Preset in the runbook customization. |
|  |  |  |  |  |  | sendMailWhenProvisioned |  | Boolean | Sends the user an email as soon as provisioning has finished. |
|  |  |  |  |  |  | customizeMail |  | Boolean | Replaces the standard notification text with your own message. Only used when the user is notified. |
|  |  |  |  |  |  | customMailMessage |  | String | Text of the notification email. |
|  |  |  |  |  |  | createTicketOutOfLicenses |  | Boolean | Sends a ticket email to the service desk when no license or Frontline seat is available. |
|  |  |  |  |  |  | ticketQueueAddress |  | String | Mailbox of the service desk that turns the email into a ticket. |
|  |  |  |  |  |  | fromMailAddress |  | String | Mailbox the notification and ticket emails are sent from. |
|  |  |  |  |  |  | ticketCustomerId |  | String | Customer identifier put into the ticket subject. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Check Intune Enrollment Readiness | Check whether this user can enroll devices in Intune | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementServiceConfig.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- GroupMember.Read.All<br>&emsp;- Organization.Read.All<br>&emsp;- Policy.Read.All<br>&emsp;- RoleManagement.Read.Directory<br>&emsp;- User.Read.All<br>&emsp;- UserAuthenticationMethod.Read.All<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | EnrollmentPlatform |  | String | Platform of the device the user wants to enroll. Conditional Access policies scoped to other platforms are ignored; All platforms checks every platform and reports each one. |
|  |  |  |  |  |  | CheckPilotGroupMembership |  | Boolean | Also requires the user to be in the pilot group. Non-members are reported as Not ready. |
|  |  |  |  |  |  | PilotGroupDisplayName |  | String | Members of this group count as pilot users. The group is looked up by its display name. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Group Memberships | List the group memberships of this user | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- Organization.Read.All<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | GroupType |  | String | Security groups only, Microsoft 365 groups only, or all groups. |
|  |  |  |  |  |  | MembershipType |  | String | Assigned memberships, dynamic memberships, or all. |
|  |  |  |  |  |  | RoleAssignable |  | String | Yes limits the list to groups that can be assigned Entra ID roles. |
|  |  |  |  |  |  | TeamsEnabled |  | String | Yes limits the list to groups that back a Microsoft Teams team. |
|  |  |  |  |  |  | Source |  | String | Cloud-only groups, groups synchronized from on-premises Active Directory, or all. |
|  |  |  |  |  |  | WritebackEnabled |  | String | Groups with writeback to on-premises Active Directory, groups without, or all. |
|  |  |  |  |  |  | SendMail |  | Boolean | Send the report to the recipient email address. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Group Ownerships | List the groups this user owns | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- Organization.Read.All<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | SendMail |  | Boolean | Send the report to the recipient email address. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Manager | Show the manager of this user | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Offboard User Permanently | Permanently offboard this user | - **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- GroupMember.ReadWrite.All<br>- **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br>Azure Storage Account: 'Storage Account Contributor' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required when exportGroupMemberships is used)<br> | - User Administrator<br>- Exchange Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | UserTypeSelector |  | Int32 | Runs only for the chosen user type: all users, members only or guests only. With a mismatch the run stops before any change. |
|  |  |  |  |  |  | DeleteUser |  | Boolean | Delete removes the user object. Keep leaves the account in place; what happens to it follows the other switches. |
|  |  |  |  |  |  | DisableUser |  | Boolean | Blocks the account from signing in. |
|  |  |  |  |  |  | RevokeAccess |  | Boolean | Ends the user's active sessions and invalidates their refresh tokens. |
|  |  |  |  |  |  | exportGroupMemberships |  | Boolean | Exports the user's group memberships to a file and returns a download link before groups and licenses are changed. Taken from the tenant setting OffboardUserPermanently.exportGroupMemberships. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the export is uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | ChangeLicensesSelector |  | Int32 | Remove all takes away every directly assigned license; licenses inherited from groups stay. |
|  |  |  |  |  |  | ChangeGroupsSelector |  | Int32 | Remove groups with the prefix removes the groups named by the prefix, Remove all groups removes every group. Both add or keep the group under "Group to add or keep". Dynamic, role-assignable and on-premises groups are skipped and listed. |
|  |  |  |  |  |  | GroupToAdd |  | String | Group the user still needs after offboarding, for example a leaver license group. It is added if missing and never removed. |
|  |  |  |  |  |  | GroupsToRemovePrefix |  | String | Groups whose name starts with this text are removed, for example LIC_ for all license groups. Only used with "Remove groups with the prefix". |
|  |  |  |  |  |  | RevokeGroupOwnership |  | Boolean | Remove or replace takes the user's group ownerships away. Where this user is the last owner, the replacement takes over; without a replacement the group is listed for manual follow-up. Keep leaves the ownerships as they are. |
|  |  |  |  |  |  | ManagerAsReplacementOwner |  | Boolean | Takes the user's manager from Entra ID as the replacement owner, manager and sponsor. If a manager is set, it is used instead of the "Replacement person". |
|  |  |  |  |  |  | ReplacementOwnerName |  | String | Person who takes over ownerships, direct reports and sponsorships when the manager is not used or this user has none. |
|  |  |  |  |  |  | ReplaceManagerReferences |  | Boolean | Sets the replacement as manager of everyone who reports to this user. Without a replacement, those users are only listed. |
|  |  |  |  |  |  | ReplaceSponsorReferences |  | Boolean | Replaces this user as sponsor wherever they are set as one, typically on guest users. Without a replacement, those users are only listed. Sponsorships held through a group stay. This scans all users of the tenant. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Offboard User Temporarily | Temporarily offboard this user | - **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- GroupMember.ReadWrite.All<br>- **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br>Azure Storage Account: 'Storage Account Contributor' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required when exportGroupMemberships is used)<br> | - User Administrator<br>- Exchange Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | UserTypeSelector |  | Int32 | Runs only for the chosen user type: all users, members only or guests only. With a mismatch the run stops before any change. |
|  |  |  |  |  |  | DisableUser |  | Boolean | Blocks the account from signing in. |
|  |  |  |  |  |  | RevokeAccess |  | Boolean | Ends the user's active sessions and invalidates their refresh tokens. |
|  |  |  |  |  |  | exportGroupMemberships |  | Boolean | Exports the user's group memberships to a file and returns a download link before groups and licenses are changed. Taken from the tenant setting OffboardUserTemporarily.exportGroupMemberships. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the export is uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | ChangeLicensesSelector |  | Int32 | Remove all takes away every directly assigned license; licenses inherited from groups stay. |
|  |  |  |  |  |  | ChangeGroupsSelector |  | Int32 | Remove groups with the prefix removes the groups named by the prefix, Remove all groups removes every group. Both add or keep the group under "Group to add or keep". Dynamic, role-assignable and on-premises groups are skipped and listed. |
|  |  |  |  |  |  | GroupToAdd |  | String | Group the user still needs after offboarding, for example a leaver license group. It is added if missing and never removed. |
|  |  |  |  |  |  | GroupsToRemovePrefix |  | String | Groups whose name starts with this text are removed, for example LIC_ for all license groups. Only used with "Remove groups with the prefix". |
|  |  |  |  |  |  | RevokeGroupOwnership |  | Boolean | Remove or replace takes the user's group ownerships away. Where this user is the last owner, the replacement takes over; without a replacement the group is listed for manual follow-up. Keep leaves the ownerships as they are. |
|  |  |  |  |  |  | ManagerAsReplacementOwner |  | Boolean | Takes the user's manager from Entra ID as the replacement owner, manager and sponsor. If a manager is set, it is used instead of the "Replacement person". |
|  |  |  |  |  |  | ReplacementOwnerName |  | String | Person who takes over ownerships, direct reports and sponsorships when the manager is not used or this user has none. |
|  |  |  |  |  |  | ReplaceManagerReferences |  | Boolean | Sets the replacement as manager of everyone who reports to this user. Without a replacement, those users are only listed. |
|  |  |  |  |  |  | ReplaceSponsorReferences |  | Boolean | Replaces this user as sponsor wherever they are set as one, typically on guest users. Without a replacement, those users are only listed. Sponsorships held through a group stay. This scans all users of the tenant. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Reprovision Windows365 | Reprovision the Windows 365 Cloud PC of this user | - **Type**: Microsoft Graph<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- Directory.Read.All<br>&emsp;- CloudPC.ReadWrite.All<br>&emsp;- User.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | licWin365GroupName | ✓ | String | License group of the Cloud PC to reprovision. Type the group name, or pick it when your runbook customization offers a list. |
|  |  |  |  |  |  | sendMailWhenReprovisioning |  | Boolean | Sends the user an email as soon as the reprovisioning has begun. |
|  |  |  |  |  |  | fromMailAddress |  | String | Mailbox the notification email is sent from. |
|  |  |  |  |  |  | customizeMail |  | Boolean | Replaces the standard notification text with your own message. |
|  |  |  |  |  |  | customMailMessage |  | String | Text of the notification email. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Resize Windows365 | Resize the Windows 365 Cloud PC of this user | - **Type**: Microsoft Graph<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- Directory.Read.All<br>&emsp;- CloudPC.ReadWrite.All<br>&emsp;- User.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | currentLicWin365GroupName | ✓ | String | License group the user is removed from; the Cloud PC behind it is deprovisioned. |
|  |  |  |  |  |  | newLicWin365GroupName | ✓ | String | License group that provides the new size. Must differ from the current one. |
|  |  |  |  |  |  | sendMailWhenDoneResizing |  | Boolean | Sends the user an email once the new Cloud PC is ready. |
|  |  |  |  |  |  | fromMailAddress |  | String | Mailbox the notification email is sent from. |
|  |  |  |  |  |  | customizeMail |  | Boolean | Replaces the standard notification text with your own message. |
|  |  |  |  |  |  | customMailMessage |  | String | Text of the notification email. |
|  |  |  |  |  |  | cfgProvisioningGroupPrefix |  | String | Name prefix that identifies provisioning policy groups. Preset in the runbook customization. |
|  |  |  |  |  |  | cfgUserSettingsGroupPrefix |  | String | Name prefix that identifies user settings policy groups. Preset in the runbook customization. |
|  |  |  |  |  |  | unassignRunbook |  | String | Name of the runbook that removes the current assignment. Preset in the runbook customization. |
|  |  |  |  |  |  | assignRunbook |  | String | Name of the runbook that assigns the new size. Preset in the runbook customization. |
|  |  |  |  |  |  | skipGracePeriod |  | Boolean | Deletes the old Cloud PC right away instead of after the 7-day grace period. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Unassign Windows365 | Remove the Windows 365 Cloud PC of this user | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- CloudPC.ReadWrite.All<br>&emsp;- Organization.Read.All<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | licWin365GroupName |  | String | License group to remove the user from, or the name of the Frontline provisioning policy whose assignment is removed. |
|  |  |  |  |  |  | cfgProvisioningGroupPrefix |  | String | Name prefix that identifies provisioning policy groups. Preset in the runbook customization. |
|  |  |  |  |  |  | cfgUserSettingsGroupPrefix |  | String | Name prefix that identifies user settings policy groups. Preset in the runbook customization. |
|  |  |  |  |  |  | licWin365GroupPrefix |  | String | Name prefix that identifies Windows 365 license groups. Preset in the runbook customization. |
|  |  |  |  |  |  | skipGracePeriod |  | Boolean | Deletes the Cloud PC right away instead of after the 7-day grace period. |
|  |  |  |  |  |  | KeepUserSettingsAndProvisioningGroups |  | Boolean | Leaves the user in the provisioning and user settings groups and removes only the license. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | Mail | Add Or Remove Email Address | Add an email address to this user's mailbox or remove one | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | EmailAddress | ✓ | String | Address to add or remove, for example jane.doe@contoso.com. |
|  |  |  |  |  |  | Remove |  | Boolean | Whether the address is removed instead of added. Set by the "Action" choice. |
|  |  |  |  |  |  | asPrimary |  | Boolean | Makes this address the primary one that outgoing mail is sent from. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Assign OWA Mailbox Policy | Assign an Outlook on the web policy to this user's mailbox | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | OwaPolicyName | ✓ | String | Policy to assign. Get current assignment only shows which policy the mailbox has today. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Convert To Shared Mailbox | Convert this user's mailbox to a shared mailbox or back | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br>- **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br>&emsp;- Group.Read.All *(optional: Group and license handling)*<br>&emsp;- GroupMember.ReadWrite.All *(optional: Group and license handling)*<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | delegateTo |  | String | User who gets full access to the shared mailbox. Leave empty to grant no access. |
|  |  |  |  |  |  | Remove |  | Boolean | Whether the shared mailbox is turned back into a regular mailbox. Set by the "Action" choice. |
|  |  |  |  |  |  | AutoMapping |  | Boolean | Makes the shared mailbox appear automatically in the delegate's Outlook. |
|  |  |  |  |  |  | RemoveGroups |  | Boolean | Takes the user out of all groups, including license groups, when converting to shared. |
|  |  |  |  |  |  | ArchivalLicenseGroup |  | String | Group that assigns an Exchange Online Plan 2 license, needed when the shared mailbox has an archive, is larger than 50 GB or is on litigation hold. Leave empty if not needed. |
|  |  |  |  |  |  | RegularLicenseGroup |  | String | Group that assigns the mailbox license when converting back to a regular mailbox. Leave empty to assign none. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Delegate Full Access | Grant or remove full access to this user's mailbox | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | delegateTo | ✓ | String Array | People who get or lose full access. You can pick several at once. |
|  |  |  |  |  |  | Remove |  | Boolean | Grant gives the selected people full access, Remove takes it away. |
|  |  |  |  |  |  | AutoMapping |  | Boolean | Makes the mailbox appear automatically in the delegates' Outlook. Has no effect when access is removed. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Delegate Send As | Grant or remove Send As permission on this user's mailbox | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | delegateTo | ✓ | String | Person who gets or loses the Send As permission. |
|  |  |  |  |  |  | Remove |  | Boolean | Whether the permission is removed instead of granted. Set by the "Action" choice. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Delegate Send On Behalf | Grant or remove Send on Behalf permission on this user's mailbox | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | delegateTo | ✓ | String | Person who gets or loses the Send on Behalf permission. |
|  |  |  |  |  |  | Remove |  | Boolean | Whether the permission is removed instead of granted. Set by the "Action" choice. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Hide Or Unhide In Addressbook | Hide this user's mailbox in the address book or show it | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | HideMailbox |  | Boolean | Whether the mailbox is hidden or shown. Set by the "Action" choice. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Mailbox Permissions | List who has access to this user's mailbox | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Room Mailbox Configuration | Show the booking configuration of this room mailbox | - **Type**: Microsoft Graph<br>&emsp;- Place.Read.All<br>&emsp;- User.Read.All<br>- **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the room mailbox the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Manage Archive Mailbox | Enable, disable or check the archive mailbox of this user | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | Action |  | String | Whether the archive is enabled, disabled or only its status shown. Set by the "Action" choice. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Remove Mailbox | Permanently delete this shared mailbox, room or Bookings calendar | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the mailbox the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Set Out Of Office | Set or remove automatic replies for this user | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the mailbox the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | Disable |  | Boolean | Enable automatic replies turns them on for the period and messages below. Disable switches existing automatic replies off. |
|  |  |  |  |  |  | Start |  | DateTime | When the automatic replies begin. |
|  |  |  |  |  |  | End |  | DateTime | When the automatic replies stop. |
|  |  |  |  |  |  | MessageInternal |  | String | Reply sent to people inside the organization. |
|  |  |  |  |  |  | MessageExternal |  | String | Reply sent to people outside the organization. |
|  |  |  |  |  |  | ExternalAudience |  | String | None sends no external replies, Known only to saved contacts, All to every external sender. |
|  |  |  |  |  |  | CreateEvent |  | Boolean | Puts a matching out-of-office entry into the user's calendar for the same period. |
|  |  |  |  |  |  | EventSubject |  | String | Subject of the out-of-office entry as colleagues see it in the calendar. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Set Room Mailbox Configuration | Configure the booking rules of this room mailbox | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br>- **Type**: Microsoft Graph<br>&emsp;- Group.Read.All *(optional: Book-in policy group)*<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the room mailbox the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | AllBookInPolicy |  | Boolean | Everyone lets all users book the room. Only members of a group restricts booking to the "Booking group". |
|  |  |  |  |  |  | BookInPolicyGroup |  | String | Mail-enabled security group whose members may book the room. |
|  |  |  |  |  |  | AllowRecurringMeetings |  | Boolean | Turn off to decline recurring meeting requests; single meetings are still accepted. |
|  |  |  |  |  |  | AutomateProcessing |  | String | Auto accept books the room automatically. Auto update only marks requests as tentative for a delegate to decide. None leaves requests untouched. |
|  |  |  |  |  |  | BookingWindowInDays |  | Int32 | Requests further ahead than this many days are declined. |
|  |  |  |  |  |  | MaximumDurationInMinutes |  | Int32 | Longest meeting the room accepts, in minutes. |
|  |  |  |  |  |  | AllowConflicts |  | Boolean | Lets overlapping bookings through instead of declining them. |
|  |  |  |  |  |  | Capacity |  | Int32 | Number of seats. Leave at 0 to keep the current value. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | Phone | Disable Teams Phone | Remove Teams phone number and voice policies from this user | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Get Teams User Info | Show the Teams voice setup of this user | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Grant Teams User Policies | Assign Teams voice and meeting policies to this user | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | OnlineVoiceRoutingPolicy |  | String | Voice routing policy to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it. |
|  |  |  |  |  |  | TenantDialPlan |  | String | Dial plan to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it. |
|  |  |  |  |  |  | TeamsCallingPolicy |  | String | Calling policy to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it. |
|  |  |  |  |  |  | TeamsIPPhonePolicy |  | String | IP phone policy to assign, typically for common area phones. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it. |
|  |  |  |  |  |  | OnlineVoicemailPolicy |  | String | Voicemail policy to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it. |
|  |  |  |  |  |  | TeamsMeetingPolicy |  | String | Meeting policy to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it. |
|  |  |  |  |  |  | TeamsMeetingBroadcastPolicy |  | String | Live event (meeting broadcast) policy to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Set Teams Permanent Call Forwarding | Forward this user's calls immediately or turn forwarding off | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | ForwardTargetPhoneNumber |  | String | Number that receives the calls, in E.164 format such as +49123456789. |
|  |  |  |  |  |  | ForwardTargetTeamsUser |  | String | Colleague whose Teams account rings instead of this user's. |
|  |  |  |  |  |  | ForwardToVoicemail |  | Boolean | Sends the calls to voicemail. Set by the "Forward calls to" choice. |
|  |  |  |  |  |  | ForwardToDelegates |  | Boolean | Sends the calls to the delegates the user has defined in Teams. Set by the "Forward calls to" choice. |
|  |  |  |  |  |  | TurnOffForward |  | Boolean | Switches immediate forwarding off. Set by the "Forward calls to" choice. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Set Teams Phone | Assign a phone number and voice policies to this user | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | PhoneNumber | ✓ | String | Number to assign, in E.164 format such as +49123456789. |
|  |  |  |  |  |  | OnlineVoiceRoutingPolicy |  | String | Voice routing policy to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it. |
|  |  |  |  |  |  | TenantDialPlan |  | String | Dial plan to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it. |
|  |  |  |  |  |  | TeamsCallingPolicy |  | String | Calling policy to assign. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it. |
|  |  |  |  |  |  | TeamsIPPhonePolicy |  | String | IP phone policy to assign, typically for common area phones. Leave empty to keep the current one, or enter Global (Org Wide Default) to reset it. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | Security | Confirm Or Dismiss Risky User | Confirm this user as compromised or dismiss the risk | - **Type**: Microsoft Graph<br>&emsp;- IdentityRiskyUser.ReadWrite.All<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | Dismiss |  | Boolean | Confirm compromise marks the account as compromised. Dismiss risk clears the risk flag. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Create Temporary Access Pass | Create a Temporary Access Pass for this user | - **Type**: Microsoft Graph<br>&emsp;- UserAuthenticationMethod.ReadWrite.All<br>&emsp;- User.Read.All<br>&emsp;- Mail.Send *(optional: Email notification)*<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | LifetimeInMinutes |  | Int32 | How long the pass stays valid, between 60 and 480 minutes. |
|  |  |  |  |  |  | OneTimeUseOnly |  | Boolean | A one-time pass works for a single sign-in; otherwise it can be reused until it expires. |
|  |  |  |  |  |  | NotifyUser |  | Boolean | Whether the user is emailed the new pass. Preset in the runbook customization. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the notification email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ServiceDeskDisplayName |  | String | Service desk name shown in the email. Taken from the tenant setting RJReport.ServiceDesk_DisplayName. |
|  |  |  |  |  |  | ServiceDeskEmail |  | String | Service desk email address shown in the email. Taken from the tenant setting RJReport.ServiceDesk_EMail. |
|  |  |  |  |  |  | ServiceDeskPhone |  | String | Service desk phone number shown in the email. Taken from the tenant setting RJReport.ServiceDesk_Phone. |
|  |  |  |  |  |  | ServiceDeskPortalUrl |  | String | Link to the service desk portal shown in the email. Taken from the tenant setting RJReport.ServiceDesk_PortalUrl. |
|  |  |  |  |  |  | ServiceDeskTicketUrl |  | String | Link to the ticket for this request, shown in the email. Preset per run or in the runbook customization; empty means no link. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Enable Or Disable Password Expiration | Turn password expiration on or off for this user | - **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | DisablePasswordExpiration |  | Boolean | Yes stops the password from expiring. No applies the tenant's default expiration again. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List MFA Methods | List the MFA and authentication methods of this user | - **Type**: Microsoft Graph<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- Organization.Read.All<br>&emsp;- User.Read.All<br>&emsp;- UserAuthenticationMethod.Read.All<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | NotifyUser |  | Boolean | Whether the user is emailed that their methods were looked up. Preset in the runbook customization. |
|  |  |  |  |  |  | MaskPhoneNumbers |  | Boolean | Whether phone numbers are shown masked, with only the last four digits. Preset in the runbook customization. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the notification email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ServiceDeskDisplayName |  | String | Service desk name shown in the email. Taken from the tenant setting RJReport.ServiceDesk_DisplayName. |
|  |  |  |  |  |  | ServiceDeskEmail |  | String | Service desk email address shown in the email. Taken from the tenant setting RJReport.ServiceDesk_EMail. |
|  |  |  |  |  |  | ServiceDeskPhone |  | String | Service desk phone number shown in the email. Taken from the tenant setting RJReport.ServiceDesk_Phone. |
|  |  |  |  |  |  | ServiceDeskPortalUrl |  | String | Link to the service desk portal shown in the email. Taken from the tenant setting RJReport.ServiceDesk_PortalUrl. |
|  |  |  |  |  |  | ServiceDeskTicketUrl |  | String | Link to the ticket for this request, shown in the email. Preset per run or in the runbook customization; empty means no link. |
|  |  |  |  |  |  | LanguageOverride |  | String | Forces the email language, DE or EN. Empty picks the language from the user's usage location. Preset in the runbook customization. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | List Signin Events | Show the recent sign-ins of this user and their failures | - **Type**: Microsoft Graph<br>&emsp;- AuditLog.Read.All<br>&emsp;- User.Read.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- Organization.Read.All *(optional: Email report)*<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | Days |  | Int32 | How many days of sign-in logs to include, 1 to 30. |
|  |  |  |  |  |  | SignInType |  | String | Interactive sign-ins by the user, non-interactive ones by apps and tokens, or both. |
|  |  |  |  |  |  | FailedSignInsOnly |  | Boolean | Hides successful sign-ins so the failures and their reasons stand out. |
|  |  |  |  |  |  | ApplicationName |  | String | Shows only sign-ins to applications whose name contains this text. Leave empty for all applications. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the report email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | SendEmailReport |  | Boolean | Whether the report is sent by email. Preset in the runbook customization. |
|  |  |  |  |  |  | EmailTo |  | String | Send the report to these addresses. Separate several with commas; each recipient gets a separate email. |
|  |  |  |  |  |  | ReportFileFormat |  | String | Deliver the report as CSV, as an Excel workbook, or both. |
|  |  |  |  |  |  | CreateDownloadLink |  | Boolean | Also upload the report and return a download link that expires after a few days. |
|  |  |  |  |  |  | ContainerName |  | String | Storage container the report files are uploaded to. Set per runbook. |
|  |  |  |  |  |  | ResourceGroupName |  | String | Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup. |
|  |  |  |  |  |  | StorageAccountName |  | String | Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName. |
|  |  |  |  |  |  | LinkExpiryDays |  | Int32 | Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Reset MFA | Remove this user's app, phone, OATH and FIDO2 MFA methods | - **Type**: Microsoft Graph<br>&emsp;- UserAuthenticationMethod.ReadWrite.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- User.Read.All<br>&emsp;- Organization.Read.All *(optional: Email notification)*<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | NotifyUser |  | Boolean | Whether the user is emailed about the reset. Preset in the runbook customization. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the notification email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ServiceDeskDisplayName |  | String | Service desk name shown in the email. Taken from the tenant setting RJReport.ServiceDesk_DisplayName. |
|  |  |  |  |  |  | ServiceDeskEmail |  | String | Service desk email address shown in the email. Taken from the tenant setting RJReport.ServiceDesk_EMail. |
|  |  |  |  |  |  | ServiceDeskPhone |  | String | Service desk phone number shown in the email. Taken from the tenant setting RJReport.ServiceDesk_Phone. |
|  |  |  |  |  |  | ServiceDeskPortalUrl |  | String | Link to the service desk portal shown in the email. Taken from the tenant setting RJReport.ServiceDesk_PortalUrl. |
|  |  |  |  |  |  | ServiceDeskTicketUrl |  | String | Link to the ticket for this request, shown in the email. Preset per run or in the runbook customization; empty means no link. |
|  |  |  |  |  |  | LanguageOverride |  | String | Forces the email language, DE or EN. Empty picks the language from the user's usage location. Preset in the runbook customization. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Reset Password | Set a new password for this user |  | - User Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | EnableUserIfNeeded |  | Boolean | Enables a disabled account before the password is set. |
|  |  |  |  |  |  | ForceChangePasswordNextSignIn |  | Boolean | Makes the user choose their own password at the next sign-in. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Revoke Or Restore Access | Block this user's sign-in and sessions, or restore access | - **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br> | - User Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | Revoke |  | Boolean | Revoke access blocks sign-in and ends the sessions. Re-enable user lets the user sign in again. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Set Or Remove Mobile Phone MFA | Set or remove the mobile phone MFA method of this user | - **Type**: Microsoft Graph<br>&emsp;- AuditLog.Read.All<br>&emsp;- User.Read.All<br>&emsp;- UserAuthenticationMethod.ReadWrite.All<br>&emsp;- Mail.Send *(optional: Email report)*<br>&emsp;- Organization.Read.All *(optional: Email notification)*<br> |  | UserId | ✓ | String | Object ID of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | phoneNumber | ✓ | String | Number in E.164 format such as +491701234567. |
|  |  |  |  |  |  | Remove |  | Boolean | Add or update stores the number as the MFA method for calls and text messages. Remove deletes it. |
|  |  |  |  |  |  | NotifyUser |  | Boolean | Whether the user is emailed about the change. Preset in the runbook customization. |
|  |  |  |  |  |  | EmailFrom |  | String | Sender address of the notification email. Taken from the tenant setting RJReport.EmailSender. |
|  |  |  |  |  |  | BrandingHeaderImageUrl |  | String | Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty. |
|  |  |  |  |  |  | BrandingFooterImageUrl |  | String | Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty. |
|  |  |  |  |  |  | BrandingFooterLink |  | String | Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty. |
|  |  |  |  |  |  | BrandingAccentColor |  | String | Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | BrandingTextColor |  | String | Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid. |
|  |  |  |  |  |  | ServiceDeskDisplayName |  | String | Service desk name shown in the email. Taken from the tenant setting RJReport.ServiceDesk_DisplayName. |
|  |  |  |  |  |  | ServiceDeskEmail |  | String | Service desk email address shown in the email. Taken from the tenant setting RJReport.ServiceDesk_EMail. |
|  |  |  |  |  |  | ServiceDeskPhone |  | String | Service desk phone number shown in the email. Taken from the tenant setting RJReport.ServiceDesk_Phone. |
|  |  |  |  |  |  | ServiceDeskPortalUrl |  | String | Link to the service desk portal shown in the email. Taken from the tenant setting RJReport.ServiceDesk_PortalUrl. |
|  |  |  |  |  |  | ServiceDeskTicketUrl |  | String | Link to the ticket for this request, shown in the email. Preset per run or in the runbook customization; empty means no link. |
|  |  |  |  |  |  | LanguageOverride |  | String | Forces the email language, DE or EN. Empty picks the language from the user's usage location. Preset in the runbook customization. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  | Userinfo | Rename User | Change this user's sign-in name (UPN) and mailbox alias | - **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br>- **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | NewUpn | ✓ | String | New sign-in name, for example jane.doe@contoso.com. |
|  |  |  |  |  |  | ChangeMailnickname |  | Boolean | Sets the mailbox alias and name from the new user principal name. |
|  |  |  |  |  |  | UpdatePrimaryAddress |  | Boolean | Makes the new user principal name the primary email address; the previous addresses stay as aliases. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Set Photo | Set the profile photo of this user from a URL | - **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br> |  | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | PhotoURI | ✓ | String | Web address of a JPEG image the runbook can download. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |
|  |  | Update User | Update profile details, groups and mailbox settings of this user | - **Type**: Microsoft Graph<br>&emsp;- UserAuthenticationMethod.Read.All<br>- **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - User Administrator<br>- Exchange Administrator<br> | UserName | ✓ | String | User principal name of the user the runbook acts on. Set by the portal from the selected user. |
|  |  |  |  |  |  | GivenName |  | String | New first name. |
|  |  |  |  |  |  | Surname |  | String | New last name. |
|  |  |  |  |  |  | DisplayName |  | String | New display name as shown in Microsoft 365. |
|  |  |  |  |  |  | CompanyName |  | String | Company the user belongs to. |
|  |  |  |  |  |  | City |  | String | City of the user's address. |
|  |  |  |  |  |  | Country |  | String | Country of the user's address. |
|  |  |  |  |  |  | JobTitle |  | String | Job title shown in the profile. |
|  |  |  |  |  |  | Department |  | String | Department the user works in. |
|  |  |  |  |  |  | OfficeLocation |  | String | Office or building the user works at. |
|  |  |  |  |  |  | PostalCode |  | String | Postal code of the user's address. |
|  |  |  |  |  |  | PreferredLanguage |  | String | Language code such as en-US or de-DE. |
|  |  |  |  |  |  | State |  | String | State or region of the user's address. |
|  |  |  |  |  |  | StreetAddress |  | String | Street and house number of the user's address. |
|  |  |  |  |  |  | UsageLocation |  | String | Two-letter country code that decides which licenses the user may get, for example DE. |
|  |  |  |  |  |  | ManagerId |  | String | User who becomes the manager of this user. |
|  |  |  |  |  |  | DefaultLicense |  | String | Display name of the group that assigns the license; the user is added to it. |
|  |  |  |  |  |  | DefaultGroups |  | String | Display names of groups the user is added to, separated by commas. |
|  |  |  |  |  |  | EnableEXOArchive |  | Boolean | Turns on the Exchange Online archive mailbox for the user. |
|  |  |  |  |  |  | ResetPassword |  | Boolean | Sets a generated start password, shown in the output, that must be changed at the next sign-in. Skipped when the user already has MFA methods. |
|  |  |  |  |  |  | CallerName | ✓ | String | Name of the user who started the runbook. Set by the portal and recorded for auditing. |

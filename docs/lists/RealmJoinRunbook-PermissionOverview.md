# Overview
This document provides an overview of the permissions and RBAC roles required for each runbook in the RealmJoin portal. The permissions and roles are listed to ensure that the necessary access rights are granted to the appropriate users and groups.

| Category | Subcategory | Runbook Name | Synopsis | Permissions | RBAC Roles |
|----------|-------------|--------------|----------|-------------|------------|
| Device | General | Change Grouptag | Assign a new AutoPilot GroupTag to this device. | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br> |  |
|  | General | Check Updatable Assets | Check if a device is onboarded to Windows Update for Business. | - **Type**: Microsoft Graph<br>&emsp;- WindowsUpdates.ReadWrite.All<br> |  |
|  | General | Enroll Updatable Assets | Enroll device into Windows Update for Business. | - **Type**: Microsoft Graph<br>&emsp;- WindowsUpdates.ReadWrite.All<br> |  |
|  | General | Outphase Device | Remove/Outphase a windows device | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br>&emsp;- Device.Read.All<br> | - Cloud device administrator<br> |
|  | General | Remove Primary User | Removes the primary user from a device. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br> |  |
|  | General | Rename Device | Rename a device. | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br> |  |
|  | General | Unenroll Updatable Assets | Unenroll device from Windows Update for Business. | - **Type**: Microsoft Graph<br>&emsp;- WindowsUpdates.ReadWrite.All<br> |  |
|  | General | Wipe Device | Wipe a Windows or MacOS device | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br>&emsp;- Device.Read.All<br> | - Cloud device administrator<br> |
|  | Security | Enable Or Disable Device | Disable a device in AzureAD. | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br> | - Cloud device administrator<br> |
|  | Security | Isolate Or Release Device | Isolate this device. | - **Type**: WindowsDefenderATP<br>&emsp;- Machine.Read.All<br>&emsp;- Machine.Isolate<br> |  |
|  | Security | Reset Mobile Device Pin | Reset a mobile device's password/PIN code. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br> |  |
|  | Security | Restrict Or Release Code Execution | Restrict code execution. | - **Type**: WindowsDefenderATP<br>&emsp;- Machine.Read.All<br>&emsp;- Machine.RestrictExecution<br> |  |
|  | Security | Show Laps Password | Show a local admin password for a device. | - **Type**: Microsoft Graph<br>&emsp;- DeviceLocalCredential.Read.All<br> |  |
| Group | Devices | Check Updatable Assets | Check if devices in a group are onboarded to Windows Update for Business. | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- WindowsUpdates.ReadWrite.All<br>Azure: Contributor on Storage Account<br> |  |
|  | Devices | Unenroll Updatable Assets | Unenroll devices from Windows Update for Business. | - **Type**: Microsoft Graph<br>&emsp;- Group.Read.All<br>&emsp;- WindowsUpdates.ReadWrite.All<br> |  |
|  | General | Add Or Remove Nested Group | Add/remove a nested group to/from a group. | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br>&emsp;- Directory.ReadWrite.All<br> |  |
|  | General | Add Or Remove Owner | Add/remove owners to/from an Office 365 group. | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br>&emsp;- Directory.ReadWrite.All<br>- **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | General | Add Or Remove User | Add/remove users to/from a group. | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br>&emsp;- Directory.ReadWrite.All<br> |  |
|  | General | Change Visibility | Change a group's visibility | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br>&emsp;- Directory.ReadWrite.All<br> |  |
|  | General | List All Members | Retrieves the members of a specified EntraID group, including members from nested groups. | - **Type**: Microsoft Graph<br>&emsp;- Group.Read.All<br>&emsp;- User.Read.All<br> |  |
|  | General | List Owners | List all owners of an Office 365 group. | - **Type**: Microsoft Graph<br>&emsp;- Group.Read.All<br> |  |
|  | General | List User Devices | List all devices owned by group members. | - **Type**: Microsoft Graph<br>&emsp;- Group.Read.All<br> |  |
|  | General | Remove Group | Removes a group, incl. SharePoint site and Teams team. | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br> |  |
|  | General | Rename Group | Rename a group. | - **Type**: Microsoft Graph<br>&emsp;- Group.ReadWrite.All<br> |  |
|  | Mail | Enable Or Disable External Mail | Enable/disable external parties to send eMails to O365 groups. | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | Show Or Hide In Address Book | (Un)hide an O365- or static Distribution-group in Address Book. | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Teams | Archive Team | Archive a team. | - **Type**: Microsoft Graph<br>&emsp;- TeamSettings.ReadWrite.All<br> |  |
| Org | Devices | Delete Stale Devices_Scheduled | Scheduled deletion of stale devices based on last activity date and platform. |  |  |
|  | Devices | Get Bitlocker Recovery Key | Get BitLocker recovery key | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>&emsp;- BitlockerKey.Read.All<br> |  |
|  | Devices | List Stale Devices_Scheduled | Scheduled report of stale devices based on last activity date and platform. |  |  |
|  | Devices | Outphase Devices | Remove/Outphase multiple devices | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br>&emsp;- Device.Read.All<br> | - Cloud device administrator<br> |
|  | Devices | Report Devices Without Primary User | Reports all managed devices in Intune that do not have a primary user assigned. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br> |  |
|  | Devices | Report Last Device Contact By Range | Reports Windows devices with last device contact within a specified date range. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br> |  |
|  | Devices | Report Users With More Than 5-Devices | Reports users with more than five registered devices in Entra ID. | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br> |  |
|  | Devices | Sync Device Serialnumbers To Entraid_Scheduled | Syncs serial numbers from Intune devices to Azure AD device extension attributes. |  |  |
|  | General | Add Application Registration | Add an application registration to Azure AD | - **Type**: Microsoft Graph<br>&emsp;- Application.ReadWrite.All<br>&emsp;- RoleManagement.ReadWrite.Directory<br> |  |
|  | General | Add Autopilot Device | Import a windows device into Windows Autopilot. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br> |  |
|  | General | Add Device Via Corporate Identifier | Import a device into Intune via corporate identifier. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br> |  |
|  | General | Add Devices Of Users To Group_Scheduled | Sync devices of users in a specific group to another device group. |  |  |
|  | General | Add Management Partner | List or add or Management Partner Links (PAL) |  |  |
|  | General | Add Microsoft Store App Logos | Update logos of Microsoft Store Apps (new) in Intune. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementApps.ReadWrite.All<br> |  |
|  | General | Add Office365 Group | Create an Office 365 group and SharePoint site, optionally create a (Teams) team. | - **Type**: Microsoft Graph<br>&emsp;- Group.Create<br>&emsp;- Team.Create<br> |  |
|  | General | Add Or Remove Safelinks Exclusion | Add or remove a SafeLinks URL exclusion to/from a given policy. | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | General | Add Or Remove Smartscreen Exclusion | Add/Remove a SmartScreen URL Exception/Rule in MS Security Center Indicators | - **Type**: WindowsDefenderATP<br>&emsp;- Ti.ReadWrite.All<br> |  |
|  | General | Add Or Remove Trusted Site | Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementConfiguration.ReadWrite.All<br> |  |
|  | General | Add Security Group | This runbook creates a Microsoft Entra ID security group with membership type "Assigned". | - **Type**: Microsoft Graph<br>&emsp;- Group.Create<br> |  |
|  | General | Add User | Create a new user account. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- DeviceManagementManagedDevices.PrivilegedOperations.All<br> | - User Administrator<br> |
|  | General | Add Viva Engange Community | Creates a Viva Engage (Yammer) community via the Yammer API |  |  |
|  | General | Assign Groups By Template_Scheduled | Assign cloud-only groups to many users based on a predefined template. |  |  |
|  | General | Bulk Delete Devices From Autopilot | Mass-Delete Autopilot objects based on Serial Number. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementServiceConfig.ReadWrite.All<br> |  |
|  | General | Bulk Retire Devices From Intune | Bulk retire devices from Intune using serial numbers | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.ReadWrite.All<br>&emsp;- Device.Read.All<br> |  |
|  | General | Check Aad Sync Status_Scheduled | Check for last Azure AD Connect Sync Cycle. | - **Type**: Microsoft Graph<br>&emsp;- Directory.Read.All<br> |  |
|  | General | Check Assignments Of Devices | Check Intune assignments for a given (or multiple) Device Names. | - **Type**: Microsoft Graph<br>&emsp;- Device.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- DeviceManagementApps.Read.All<br> |  |
|  | General | Check Assignments Of Groups | Check Intune assignments for a given (or multiple) Group Names. |  |  |
|  | General | Check Assignments Of Users | Check Intune assignments for a given (or multiple) User Principal Names (UPNs). | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- Group.Read.All<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- Device.Read.All<br> |  |
|  | General | Check Autopilot Serialnumbers | Check if given serial numbers are present in AutoPilot. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementServiceConfig.Read.All<br> |  |
|  | General | Check Device Onboarding Exclusion_Schedule | Check for Autopilot devices not yet onboarded to Intune. Add these to an exclusion group. |  |  |
|  | General | Enrolled Devices Report_Scheduled | Show recent first-time device enrollments. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementServiceConfig.Read.All<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- User.Read.All<br>&emsp;- Device.ReadWrite.All<br>Azure: Contributor on Storage Account<br> |  |
|  | General | Export All Autopilot Devices | List/export all AutoPilot devices. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- Directory.Read.All<br>&emsp;- Device.Read.All<br> |  |
|  | General | Export All Intune Devices | Export a list of all Intune devices and where they are registered. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br> |  |
|  | General | Export Cloudpc Usage_Scheduled | Write daily Windows 365 Utilization Data to Azure Tables | - **Type**: Microsoft Graph<br>&emsp;- CloudPC.Read.All<br>Azure IaaS: `Contributor` role on the Azure Storage Account used for storing CloudPC usage data<br> |  |
|  | General | Export Non Compliant Devices | Report on non-compliant devices and policies | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementConfiguration.Read.All<br>Azure IaaS: Access to create/manage Azure Storage resources if producing links<br> |  |
|  | General | Export Policy Report | Create a report of a tenant's polcies from Intune and AAD and write them to a markdown file. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- Policy.Read.All<br>Azure Storage Account: Contributor role on the Storage Account used for exporting reports<br> |  |
|  | General | Invite External Guest Users | Invites external guest users to the organization using Microsoft Graph. | - **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br> |  |
|  | General | List All Administrative Template Policies | List all Administrative Template policies and their assignments. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- Group.Read.All<br> |  |
|  | General | List Group License Assignment Errors | Report groups that have license assignment errors | - **Type**: Microsoft Graph<br>&emsp;- GroupMember.Read.All<br>&emsp;- Group.Read.All<br> |  |
|  | General | Office365 License Report | Generate an Office 365 licensing report. | - **Type**: Microsoft Graph<br>&emsp;- Reports.Read.All<br>&emsp;- Directory.Read.All<br>&emsp;- User.Read.All<br> |  |
|  | General | Report Apple Mdm Cert Expiry_Scheduled | Monitor/Report expiry of Apple device management certificates. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- DeviceManagementServiceConfig.Read.All<br>&emsp;- DeviceManagementConfiguration.Read.All<br>&emsp;- Mail.Send<br> |  |
|  | General | Report Pim Activations_Scheduled | Scheduled Report on PIM Activations. | - **Type**: Microsoft Graph<br>&emsp;- AuditLog.Read.All<br>&emsp;- Mail.Send<br> |  |
|  | General | Sync All Devices | Sync all Intune devices. |  |  |
|  | Mail | Add Distribution List | Create a classic distribution group. | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br>- **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | Add Equipment Mailbox | Create an equipment mailbox. | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | Add Or Remove Public Folder | Add or remove a public folder. | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | Add Or Remove Teams Mailcontact | Create/Remove a contact, to allow pretty email addresses for Teams channels. | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | Add Room Mailbox | Create a room resource. | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | Add Shared Mailbox | Create a shared mailbox. | - **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | Hide Mailboxes_Scheduled | Hide / Unhide special mailboxes in Global Address Book |  | - Exchange administrator<br> |
|  | Mail | Set Booking Config |  |  |  |
|  | Phone | Get Teams Phone Number Assignment | Looks up, if the given phone number is assigned to a user in Microsoft Teams. | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> |
|  | Security | Add Defender Indicator | Create new Indicator in Defender for Endpoint. | - **Type**: WindowsDefenderATP<br>&emsp;- Ti.ReadWrite.All<br> |  |
|  | Security | Backup Conditional Access Policies | Exports the current set of Conditional Access policies to an Azure storage account. | - **Type**: Microsoft Graph<br>&emsp;- Policy.Read.All<br>Azure IaaS: Access to the given Azure Storage Account / Resource Group<br> |  |
|  | Security | Export Enterprise App Users | Export a CSV of all (entprise) app owners and users | - **Type**: Microsoft Graph<br>&emsp;- Directory.Read.All<br>&emsp;- Application.Read.All<br>Azure IaaS: - Contributor - access on subscription or resource group used for the export<br> |  |
|  | Security | List Admin Users | List AzureAD role holders and their MFA state. | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- Directory.Read.All<br>&emsp;- RoleManagement.Read.All<br> |  |
|  | Security | List Application Creds Expiry | List expiry date of all AppRegistration credentials | - **Type**: Microsoft Graph<br>&emsp;- Application.Read.All<br> |  |
|  | Security | List Expiring Role Assignments | List Azure AD role assignments that will expire before a given number of days. | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br>&emsp;- RoleManagement.Read.All<br> |  |
|  | Security | List Inactive Devices | List/export inactive evices, which had no recent user logons. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br>&emsp;- Directory.Read.All<br>&emsp;- Device.Read.All<br> |  |
|  | Security | List Inactive Enterprise Apps | List App registrations, which had no recent user logons. | - **Type**: Microsoft Graph<br>&emsp;- Directory.Read.All<br>&emsp;- Device.Read.All<br> |  |
|  | Security | List Inactive Users | List users, that have no recent interactive signins. | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- AuditLog.Read.All<br>&emsp;- Organization.Read.All<br> |  |
|  | Security | List Information Protection Labels | Prints a list of all available InformationProtectionPolicy labels. | - **Type**: Microsoft Graph<br>&emsp;- InformationProtectionPolicy.Read.All<br> |  |
|  | Security | List Pim Rolegroups Without Owners_Scheduled | List role-assignable groups with eligible role assignments but without owners | - **Type**: Microsoft Graph<br>&emsp;- Group.Read.All<br>&emsp;- RoleManagement.Read.Directory<br>&emsp;- Mail.Send<br> |  |
|  | Security | List Vulnerable App Regs | List all app registrations that suffer from the CVE-2021-42306 vulnerability. | - **Type**: Microsoft Graph<br>&emsp;- DeviceManagementManagedDevices.Read.All<br> |  |
|  | Security | Notify Changed CA Policies | Exports the current set of Conditional Access policies to an Azure storage account. | - **Type**: Microsoft Graph<br>&emsp;- Policy.Read.All<br>&emsp;- Mail.Send<br> |  |
| User | General | Assign Groups By Template | Assign cloud-only groups to a user based on a predefined template. |  |  |
|  | General | Assign Or Unassign License | (Un-)Assign a license to a user via group membership. | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br> |  |
|  | General | Assign Windows365 | Assign/Provision a Windows 365 instance | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- User.SendMail<br> |  |
|  | General | List Group Ownerships | List group ownerships for this user. | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- Group.Read.All<br> |  |
|  | General | List Manager | List manager information for this user. | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br> |  |
|  | General | Offboard User Permanently | Permanently offboard a user. | - **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- Directory.ReadWrite.All<br>Azure IaaS: Contributor access on subscription or resource group used for the export<br> | - User administrator<br> |
|  | General | Offboard User Temporarily | Temporarily offboard a user. | - **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- Directory.ReadWrite.All<br>Azure IaaS: Contributor access on subscription or resource group used for the export<br> | - User administrator<br> |
|  | General | Reprovision Windows365 | Reprovision a Windows 365 Cloud PC | - **Type**: Microsoft Graph<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- Directory.Read.All<br>&emsp;- CloudPC.ReadWrite.All<br>&emsp;- User.Read.All<br>&emsp;- User.SendMail<br> |  |
|  | General | Resize Windows365 | Resize a Windows 365 Cloud PC | - **Type**: Microsoft Graph<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- Directory.Read.All<br>&emsp;- CloudPC.ReadWrite.All<br>&emsp;- User.Read.All<br>&emsp;- User.SendMail<br> |  |
|  | General | Unassign Windows365 | Remove/Deprovision a Windows 365 instance | - **Type**: Microsoft Graph<br>&emsp;- User.Read.All<br>&emsp;- GroupMember.ReadWrite.All<br>&emsp;- Group.ReadWrite.All<br>&emsp;- CloudPC.ReadWrite.All<br> |  |
|  | Mail | Add Or Remove Email Address | Add/remove eMail address to/from mailbox. | - **Type**: Office 365 Exchange Online API<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | Assign Owa Mailbox Policy | Assign a given OWA mailbox policy to a user. |  | - Exchange administrator<br> |
|  | Mail | Convert To Shared Mailbox | Turn this users mailbox into a shared mailbox. | - **Type**: Office 365 Exchange Online API<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | Delegate Full Access | Grant another user full access to this mailbox. | - **Type**: Office 365 Exchange Online API<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | Delegate Send As | Grant another user sendAs permissions on this mailbox. | - **Type**: Office 365 Exchange Online API<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | Delegate Send On Behalf | Grant another user sendOnBehalf permissions on this mailbox. | - **Type**: Office 365 Exchange Online API<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | Hide Or Unhide In Addressbook | (Un)Hide this mailbox in address book. | - **Type**: Office 365 Exchange Online API<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | List Mailbox Permissions | List permissions on a (shared) mailbox. | - **Type**: Office 365 Exchange Online API<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | List Room Mailbox Configuration | List Room configuration. | - **Type**: MS Graph<br>&emsp;- Place.Read.All<br> |  |
|  | Mail | Remove Mailbox | Hard delete a shared mailbox, room or bookings calendar. |  | - Exchange administrator<br> |
|  | Mail | Set Out Of Office | En-/Disable Out-of-office-notifications for a user/mailbox. | - **Type**: Office 365 Exchange Online API<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Mail | Set Room Mailbox Configuration | Set room resource policies. | - **Type**: Office 365 Exchange Online API<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Phone | Disable Teams Phone | Microsoft Teams telephony offboarding | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> |
|  | Phone | Get Teams User Info | Get the status quo of a Microsoft Teams user in terms of phone number, if any, and certain Microsoft Teams policies. | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> |
|  | Phone | Grant Teams User Policies | Grant specific Microsoft Teams policies to a Microsoft Teams enabled user. | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> |
|  | Phone | Set Teams Permanent Call Forwarding | Set up immediate call forwarding for a Microsoft Teams Enterprise Voice user. | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> |
|  | Phone | Set Teams Phone | Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies. | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> |
|  | Security | Confirm Or Dismiss Risky User | Confirm compromise / Dismiss a "risky user" | - **Type**: Microsoft Graph<br>&emsp;- IdentityRiskyUser.ReadWrite.All<br> |  |
|  | Security | Create Temporary Access Pass | Create an AAD temporary access pass for a user. | - **Type**: Microsoft Graph<br>&emsp;- UserAuthenticationMethod.ReadWrite.All<br> |  |
|  | Security | Enable Or Disable Password Expiration | Set a users password policy to "(Do not) Expire" | - **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br> |  |
|  | Security | Reset Mfa | Remove all App- and Mobilephone auth methods for a user. | - **Type**: Microsoft Graph<br>&emsp;- UserAuthenticationMethod.ReadWrite.All<br> |  |
|  | Security | Reset Password | Reset a user's password. |  | - User administrator<br> |
|  | Security | Revoke Or Restore Access | Revoke user access and all active tokens or re-enable user. | - **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br>&emsp;- Directory.ReadWrite.All<br> | - User Administrator<br> |
|  | Security | Set Or Remove Mobile Phone Mfa | Add, update or remove a user's mobile phone MFA information. | - **Type**: Microsoft Graph<br>&emsp;- UserAuthenticationMethod.ReadWrite.All<br> |  |
|  | Userinfo | Rename User | Rename a user or mailbox. Will not update metadata like DisplayName, GivenName, Surname. | - **Type**: Microsoft Graph<br>&emsp;- Directory.Read.All<br>&emsp;- User.ReadWrite.All<br>- **Type**: Office 365 Exchange Online<br>&emsp;- Exchange.ManageAsApp<br> | - Exchange administrator<br> |
|  | Userinfo | Set Photo | Set / update the photo / avatar picture of a user. | - **Type**: Microsoft Graph<br>&emsp;- User.ReadWrite.All<br> |  |
|  | Userinfo | Update User | Update/Finalize an existing user object. | - **Type**: Microsoft Graph<br>&emsp;- UserAuthenticationMethod.Read.All<br> | - User administrator<br>- Exchange Administrator<br> |

# Overview
This document provides an overview of the permissions and RBAC roles required for each runbook in the RealmJoin portal. The permissions and roles are listed to ensure that the necessary access rights are granted to the appropriate users and groups.

| Category | Subcategory | Runbook Name | Synopsis | Permissions | RBAC Roles |
|----------|-------------|--------------|----------|-------------|------------|
| Device | General | Change Grouptag | Assign a new AutoPilot GroupTag to this device. |  |  |
|  | General | Check Updatable Assets | Check if a device is onboarded to Windows Update for Business. |  |  |
|  | General | Enroll Updatable Assets | Enroll device into Windows Update for Business. |  |  |
|  | General | Outphase Device | Remove/Outphase a windows device |  |  |
|  | General | Rename Device | Rename a device. |  |  |
|  | General | Unenroll Updatable Assets | Unenroll device from Windows Update for Business. |  |  |
|  | General | Wipe Device | Wipe a Windows or MacOS device |  |  |
|  | Security | Enable Or Disable Device | Disable a device in AzureAD. |  |  |
|  | Security | Isolate Or Release Device | Isolate this device. |  |  |
|  | Security | Reset Mobile Device Pin | Reset a mobile device's password/PIN code. |  |  |
|  | Security | Restrict Or Release Code Execution | Restrict code execution. |  |  |
|  | Security | Show Laps Password | Show a local admin password for a device. |  |  |
| Group | Devices | Check Updatable Assets | Check if devices in a group are onboarded to Windows Update for Business. |  |  |
|  | Devices | Unenroll Updatable Assets | Unenroll devices from Windows Update for Business. |  |  |
|  | General | Add Or Remove Nested Group | Add/remove a nested group to/from a group. |  |  |
|  | General | Add Or Remove Owner | Add/remove owners to/from an Office 365 group. |  |  |
|  | General | Add Or Remove User | Add/remove users to/from a group. |  |  |
|  | General | Change Visibility | Change a group's visibility |  |  |
|  | General | List All Members | Retrieves the members of a specified EntraID group, including members from nested groups. |  |  |
|  | General | List Owners | List all owners of an Office 365 group. |  |  |
|  | General | List User Devices | List all devices owned by group members. |  |  |
|  | General | Remove Group | Removes a group, incl. SharePoint site and Teams team. |  |  |
|  | General | Rename Group | Rename a group. |  |  |
|  | Mail | Enable Or Disable External Mail | Enable/disable external parties to send eMails to O365 groups. |  |  |
|  | Mail | Show Or Hide In Address Book | (Un)hide an O365- or static Distribution-group in Address Book. |  |  |
|  | Teams | Archive Team | Archive a team. |  |  |
| Org | Devices | Get Bitlocker Recovery Key | Get BitLocker recovery key |  |  |
|  | Devices | Outphase Devices | Remove/Outphase multiple devices |  |  |
|  | General | Add Application Registration | Add an application registration to Azure AD |  |  |
|  | General | Add Autopilot Device | Import a windows device into Windows Autopilot. |  |  |
|  | General | Add Device Via Corporate Identifier | Import a device into Intune via corporate identifier. |  |  |
|  | General | Add Devices Of Users To Group_Scheduled | Sync devices of users in a specific group to another device group. |  |  |
|  | General | Add Management Partner | List or add or Management Partner Links (PAL) |  |  |
|  | General | Add Microsoft Store App Logos | Update logos of Microsoft Store Apps (new) in Intune. |  |  |
|  | General | Add Office365 Group | Create an Office 365 group and SharePoint site, optionally create a (Teams) team. |  |  |
|  | General | Add Or Remove Safelinks Exclusion | Add or remove a SafeLinks URL exclusion to/from a given policy. |  |  |
|  | General | Add Or Remove Smartscreen Exclusion | Add/Remove a SmartScreen URL Exception/Rule in MS Security Center Indicators |  |  |
|  | General | Add Or Remove Trusted Site | Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy |  |  |
|  | General | Add Security Group | This runbook creates a Microsoft Entra ID security group with membership type "Assigned". |  |  |
|  | General | Add User | Create a new user account. |  |  |
|  | General | Add Viva Engange Community | Creates a Viva Engage (Yammer) community via the Yammer API |  |  |
|  | General | Assign Groups By Template_Scheduled | Assign cloud-only groups to many users based on a predefined template. |  |  |
|  | General | Bulk Delete Devices From Autopilot | Mass-Delete Autopilot objects based on Serial Number. |  |  |
|  | General | Bulk Retire Devices From Intune | Bulk retire devices from Intune using serial numbers |  |  |
|  | General | Check Aad Sync Status_Scheduled | Check for last Azure AD Connect Sync Cycle. |  |  |
|  | General | Check Assignments Of Devices | Check Intune assignments for a given (or multiple) Device Names. |  |  |
|  | General | Check Assignments Of Groups | Check Intune assignments for a given (or multiple) Group Names. |  |  |
|  | General | Check Assignments Of Users | Check Intune assignments for a given (or multiple) User Principal Names (UPNs). |  |  |
|  | General | Check Autopilot Serialnumbers | Check if given serial numbers are present in AutoPilot. |  |  |
|  | General | Check Device Onboarding Exclusion_Schedule | Check for Autopilot devices not yet onboarded to Intune. Add these to an exclusion group. |  |  |
|  | General | Enrolled Devices Report_Scheduled | Show recent first-time device enrollments. |  |  |
|  | General | Export All Autopilot Devices | List/export all AutoPilot devices. |  |  |
|  | General | Export All Intune Devices | Export a list of all Intune devices and where they are registered. |  |  |
|  | General | Export Cloudpc Usage_Scheduled | Write daily Windows 365 Utilization Data to Azure Tables |  |  |
|  | General | Export Non Compliant Devices | Report on non-compliant devices and policies |  |  |
|  | General | Export Policy Report | Create a report of a tenant's polcies from Intune and AAD and write them to a markdown file. |  |  |
|  | General | List All Administrative Template Policies | List all Administrative Template policies and their assignments. |  |  |
|  | General | List Group License Assignment Errors | Report groups that have license assignment errors |  |  |
|  | General | Office365 License Report | Generate an Office 365 licensing report. |  |  |
|  | General | Report Apple Mdm Cert Expiry_Scheduled | Monitor/Report expiry of Apple device management certificates. |  |  |
|  | General | Report Pim Activations_Scheduled | Scheduled Report on PIM Activations. |  |  |
|  | General | Sync All Devices | Sync all Intune devices. |  |  |
|  | Mail | Add Distribution List | Create a classic distribution group. |  |  |
|  | Mail | Add Equipment Mailbox | Create an equipment mailbox. |  |  |
|  | Mail | Add Or Remove Public Folder | Add or remove a public folder. |  |  |
|  | Mail | Add Or Remove Teams Mailcontact | Create/Remove a contact, to allow pretty email addresses for Teams channels. |  |  |
|  | Mail | Add Room Mailbox | Create a room resource. |  |  |
|  | Mail | Add Shared Mailbox | Create a shared mailbox. |  |  |
|  | Mail | Hide Mailboxes_Scheduled | Hide / Unhide special mailboxes in Global Address Book |  |  |
|  | Mail | Set Booking Config |  |  |  |
|  | Phone | Get Teams Phone Number Assignment | Looks up, if the given phone number is assigned to a user in Microsoft Teams. | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> |
|  | Security | Add Defender Indicator | Create new Indicator in Defender for Endpoint. |  |  |
|  | Security | Backup Conditional Access Policies | Exports the current set of Conditional Access policies to an Azure storage account. |  |  |
|  | Security | Export Enterprise App Users | Export a CSV of all (entprise) app owners and users |  |  |
|  | Security | List Admin Users | List AzureAD role holders and their MFA state. |  |  |
|  | Security | List Application Creds Expiry | List expiry date of all AppRegistration credentials |  |  |
|  | Security | List Expiring Role Assignments | List Azure AD role assignments that will expire before a given number of days. |  |  |
|  | Security | List Inactive Devices | List/export inactive evices, which had no recent user logons. |  |  |
|  | Security | List Inactive Enterprise Apps | List App registrations, which had no recent user logons. |  |  |
|  | Security | List Inactive Users | List users, that have no recent interactive signins. |  |  |
|  | Security | List Information Protection Labels | Prints a list of all available InformationProtectionPolicy labels. |  |  |
|  | Security | List Pim Rolegroups Without Owners_Scheduled | List role-assignable groups with eligible role assignments but without owners |  |  |
|  | Security | List Vulnerable App Regs | List all app registrations that suffer from the CVE-2021-42306 vulnerability. |  |  |
|  | Security | Notify Changed CA Policies | Exports the current set of Conditional Access policies to an Azure storage account. |  |  |
| User | General | Assign Groups By Template | Assign cloud-only groups to a user based on a predefined template. |  |  |
|  | General | Assign Or Unassign License | (Un-)Assign a license to a user via group membership. |  |  |
|  | General | Assign Windows365 | Assign/Provision a Windows 365 instance |  |  |
|  | General | List Group Ownerships | List group ownerships for this user. |  |  |
|  | General | List Manager | List manager information for this user. |  |  |
|  | General | Offboard User Permanently | Permanently offboard a user. |  |  |
|  | General | Offboard User Temporarily | Temporarily offboard a user. |  |  |
|  | General | Reprovision Windows365 | Reprovision a Windows 365 Cloud PC |  |  |
|  | General | Resize Windows365 | Resize a Windows 365 Cloud PC |  |  |
|  | General | Unassign Windows365 | Remove/Deprovision a Windows 365 instance |  |  |
|  | Mail | Add Or Remove Email Address | Add/remove eMail address to/from mailbox. |  |  |
|  | Mail | Assign Owa Mailbox Policy | Assign a given OWA mailbox policy to a user. |  |  |
|  | Mail | Convert To Shared Mailbox | Turn this users mailbox into a shared mailbox. |  |  |
|  | Mail | Delegate Full Access | Grant another user full access to this mailbox. |  |  |
|  | Mail | Delegate Send As | Grant another user sendAs permissions on this mailbox. |  |  |
|  | Mail | Delegate Send On Behalf | Grant another user sendOnBehalf permissions on this mailbox. |  |  |
|  | Mail | Hide Or Unhide In Addressbook | (Un)Hide this mailbox in address book. |  |  |
|  | Mail | List Mailbox Permissions | List permissions on a (shared) mailbox. |  |  |
|  | Mail | List Room Mailbox Configuration | List Room configuration. |  |  |
|  | Mail | Remove Mailbox | Hard delete a shared mailbox, room or bookings calendar. |  |  |
|  | Mail | Set Out Of Office | En-/Disable Out-of-office-notifications for a user/mailbox. |  |  |
|  | Mail | Set Room Mailbox Configuration | Set room resource policies. |  |  |
|  | Phone | Disable Teams Phone | Microsoft Teams telephony offboarding | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> |
|  | Phone | Get Teams User Info | Get the status quo of a Microsoft Teams user in terms of phone number, if any, and certain Microsoft Teams policies. | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> |
|  | Phone | Grant Teams User Policies | Grant specific Microsoft Teams policies to a Microsoft Teams enabled user. | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> |
|  | Phone | Set Teams Permanent Call Forwarding | Set up immediate call forwarding for a Microsoft Teams Enterprise Voice user. | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> |
|  | Phone | Set Teams Phone | Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies. | - **Type**: Microsoft Graph<br>&emsp;- Organization.Read.All<br> | - Teams Administrator<br> |
|  | Security | Confirm Or Dismiss Risky User | Confirm compromise / Dismiss a "risky user" |  |  |
|  | Security | Create Temporary Access Pass | Create an AAD temporary access pass for a user. |  |  |
|  | Security | Enable Or Disable Password Expiration | Set a users password policy to "(Do not) Expire" |  |  |
|  | Security | Reset Mfa | Remove all App- and Mobilephone auth methods for a user. |  |  |
|  | Security | Reset Password | Reset a user's password. |  |  |
|  | Security | Revoke Or Restore Access | Revoke user access and all active tokens or re-enable user. |  |  |
|  | Security | Set Or Remove Mobile Phone Mfa | Add, update or remove a user's mobile phone MFA information. |  |  |
|  | Userinfo | Rename User | Rename a user or mailbox. Will not update metadata like DisplayName, GivenName, Surname. |  |  |
|  | Userinfo | Set Photo | Set / update the photo / avatar picture of a user. |  |  |
|  | Userinfo | Update User | Update/Finalize an existing user object. |  |  |

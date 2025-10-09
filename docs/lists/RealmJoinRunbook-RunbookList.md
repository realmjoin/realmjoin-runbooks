<a name='runbook-overview'></a>
# Overview
This document provides a comprehensive overview of all runbooks currently available in the RealmJoin portal. Each runbook is listed along with a brief description or synopsis to give a clear understanding of its purpose and functionality.

To ensure easy navigation, the runbooks are categorized into different sections based on their area of application. The following categories are currently available:
- device
- group
- org
- user

Each category contains multiple runbooks that are further divided into subcategories based on their functionality. The runbooks are listed in alphabetical order within each subcategory.

# Table of Contents
- [Device](#device)
  - [Avd](#device-avd)
    - Restart Host
    - Toggle Drain Mode
  - [General](#device-general)
    - Change Grouptag
    - Check Updatable Assets
    - Enroll Updatable Assets
    - Outphase Device
    - Remove Primary User
    - Rename Device
    - Unenroll Updatable Assets
    - Wipe Device
  - [Security](#device-security)
    - Enable Or Disable Device
    - Isolate Or Release Device
    - Reset Mobile Device Pin
    - Restrict Or Release Code Execution
    - Show Laps Password
- [Group](#group)
  - [Devices](#group-devices)
    - Check Updatable Assets
    - Unenroll Updatable Assets
  - [General](#group-general)
    - Add Or Remove Nested Group
    - Add Or Remove Owner
    - Add Or Remove User
    - Change Visibility
    - List All Members
    - List Owners
    - List User Devices
    - Remove Group
    - Rename Group
  - [Mail](#group-mail)
    - Enable Or Disable External Mail
    - Show Or Hide In Address Book
  - [Teams](#group-teams)
    - Archive Team
- [Org](#org)
  - [Applications](#org-applications)
    - Add Application Registration
    - Delete Application Registration
    - Export Enterprise App Users
    - List Application Creds Expiry
    - List Inactive Enterprise Apps
    - Report App Registration
    - Update Application Registration
  - [Devices](#org-devices)
    - Delete Stale Devices_Scheduled
    - Get Bitlocker Recovery Key
    - List Stale Devices_Scheduled
    - Outphase Devices
    - Report Devices Without Primary User
    - Report Last Device Contact By Range
    - Report Users With More Than 5-Devices
    - Sync Device Serialnumbers To Entraid_Scheduled
  - [General](#org-general)
    - Add Autopilot Device
    - Add Device Via Corporate Identifier
    - Add Devices Of Users To Group_Scheduled
    - Add Management Partner
    - Add Microsoft Store App Logos
    - Add Office365 Group
    - Add Or Remove Safelinks Exclusion
    - Add Or Remove Smartscreen Exclusion
    - Add Or Remove Trusted Site
    - Add Security Group
    - Add User
    - Add Viva Engange Community
    - Assign Groups By Template_Scheduled
    - Bulk Delete Devices From Autopilot
    - Bulk Retire Devices From Intune
    - Check Aad Sync Status_Scheduled
    - Check Assignments Of Devices
    - Check Assignments Of Groups
    - Check Assignments Of Users
    - Check Autopilot Serialnumbers
    - Check Device Onboarding Exclusion_Schedule
    - Enrolled Devices Report_Scheduled
    - Export All Autopilot Devices
    - Export All Intune Devices
    - Export Cloudpc Usage_Scheduled
    - Export Non Compliant Devices
    - Export Policy Report
    - Invite External Guest Users
    - List All Administrative Template Policies
    - List Group License Assignment Errors
    - Office365 License Report
    - Report Apple Mdm Cert Expiry_Scheduled
    - Report Pim Activations_Scheduled
    - Sync All Devices
  - [Mail](#org-mail)
    - Add Distribution List
    - Add Equipment Mailbox
    - Add Or Remove Public Folder
    - Add Or Remove Teams Mailcontact
    - Add Room Mailbox
    - Add Shared Mailbox
    - Hide Mailboxes_Scheduled
    - Set Booking Config
  - [Phone](#org-phone)
    - Get Teams Phone Number Assignment
  - [Security](#org-security)
    - Add Defender Indicator
    - Backup Conditional Access Policies
    - List Admin Users
    - List Expiring Role Assignments
    - List Inactive Devices
    - List Inactive Users
    - List Information Protection Labels
    - List Pim Rolegroups Without Owners_Scheduled
    - List Users By MFA Methods Count
    - List Vulnerable App Regs
    - Notify Changed CA Policies
- [User](#user)
  - [Avd](#user-avd)
    - User Signout
  - [General](#user-general)
    - Assign Groups By Template
    - Assign Or Unassign License
    - Assign Windows365
    - List Group Ownerships
    - List Manager
    - Offboard User Permanently
    - Offboard User Temporarily
    - Reprovision Windows365
    - Resize Windows365
    - Unassign Windows365
  - [Mail](#user-mail)
    - Add Or Remove Email Address
    - Assign Owa Mailbox Policy
    - Convert To Shared Mailbox
    - Delegate Full Access
    - Delegate Send As
    - Delegate Send On Behalf
    - Hide Or Unhide In Addressbook
    - List Mailbox Permissions
    - List Room Mailbox Configuration
    - Remove Mailbox
    - Set Out Of Office
    - Set Room Mailbox Configuration
  - [Phone](#user-phone)
    - Disable Teams Phone
    - Get Teams User Info
    - Grant Teams User Policies
    - Set Teams Permanent Call Forwarding
    - Set Teams Phone
  - [Security](#user-security)
    - Confirm Or Dismiss Risky User
    - Create Temporary Access Pass
    - Enable Or Disable Password Expiration
    - Reset Mfa
    - Reset Password
    - Revoke Or Restore Access
    - Set Or Remove Mobile Phone Mfa
  - [Userinfo](#user-userinfo)
    - Rename User
    - Set Photo
    - Update User

<a name='device'></a>
# Device
<a name='device-avd'></a>
## Avd
| Runbook Name | Synopsis |
|--------------|----------|
| Restart Host | Reboots a specific AVD Session Host. |
| Toggle Drain Mode | Sets Drainmode on true or false for a specific AVD Session Host. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='device-general'></a>
## General
| Runbook Name | Synopsis |
|--------------|----------|
| Change Grouptag | Assign a new AutoPilot GroupTag to this device. |
| Check Updatable Assets | Check if a device is onboarded to Windows Update for Business. |
| Enroll Updatable Assets | Enroll device into Windows Update for Business. |
| Outphase Device | Remove/Outphase a windows device |
| Remove Primary User | Removes the primary user from a device. |
| Rename Device | Rename a device. |
| Unenroll Updatable Assets | Unenroll device from Windows Update for Business. |
| Wipe Device | Wipe a Windows or MacOS device |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='device-security'></a>
## Security
| Runbook Name | Synopsis |
|--------------|----------|
| Enable Or Disable Device | Disable a device in AzureAD. |
| Isolate Or Release Device | Isolate this device. |
| Reset Mobile Device Pin | Reset a mobile device's password/PIN code. |
| Restrict Or Release Code Execution | Restrict code execution. |
| Show Laps Password | Show a local admin password for a device. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='group'></a>
# Group
<a name='group-devices'></a>
## Devices
| Runbook Name | Synopsis |
|--------------|----------|
| Check Updatable Assets | Check if devices in a group are onboarded to Windows Update for Business. |
| Unenroll Updatable Assets | Unenroll devices from Windows Update for Business. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='group-general'></a>
## General
| Runbook Name | Synopsis |
|--------------|----------|
| Add Or Remove Nested Group | Add/remove a nested group to/from a group. |
| Add Or Remove Owner | Add/remove owners to/from an Office 365 group. |
| Add Or Remove User | Add/remove users to/from a group. |
| Change Visibility | Change a group's visibility |
| List All Members | Retrieves the members of a specified EntraID group, including members from nested groups. |
| List Owners | List all owners of an Office 365 group. |
| List User Devices | List all devices owned by group members. |
| Remove Group | Removes a group, incl. SharePoint site and Teams team. |
| Rename Group | Rename a group. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='group-mail'></a>
## Mail
| Runbook Name | Synopsis |
|--------------|----------|
| Enable Or Disable External Mail | Enable/disable external parties to send eMails to O365 groups. |
| Show Or Hide In Address Book | (Un)hide an O365- or static Distribution-group in Address Book. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='group-teams'></a>
## Teams
| Runbook Name | Synopsis |
|--------------|----------|
| Archive Team | Archive a team. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='org'></a>
# Org
<a name='org-applications'></a>
## Applications
| Runbook Name | Synopsis |
|--------------|----------|
| Add Application Registration | Add an application registration to Azure AD |
| Delete Application Registration | Delete an application registration from Azure AD |
| Export Enterprise App Users | Export a CSV of all (entprise) app owners and users |
| List Application Creds Expiry | List expiry date of all AppRegistration credentials |
| List Inactive Enterprise Apps | List App registrations, which had no recent user logons. |
| Report App Registration | Generate and email a comprehensive App Registration report |
| Update Application Registration | Update an application registration in Azure AD |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='org-devices'></a>
## Devices
| Runbook Name | Synopsis |
|--------------|----------|
| Delete Stale Devices_Scheduled | Scheduled deletion of stale devices based on last activity date and platform. |
| Get Bitlocker Recovery Key | Get BitLocker recovery key |
| List Stale Devices_Scheduled | Scheduled report of stale devices based on last activity date and platform. |
| Outphase Devices | Remove/Outphase multiple devices |
| Report Devices Without Primary User | Reports all managed devices in Intune that do not have a primary user assigned. |
| Report Last Device Contact By Range | Reports Windows devices with last device contact within a specified date range. |
| Report Users With More Than 5-Devices | Reports users with more than five registered devices in Entra ID. |
| Sync Device Serialnumbers To Entraid_Scheduled | Syncs serial numbers from Intune devices to Azure AD device extension attributes. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='org-general'></a>
## General
| Runbook Name | Synopsis |
|--------------|----------|
| Add Autopilot Device | Import a windows device into Windows Autopilot. |
| Add Device Via Corporate Identifier | Import a device into Intune via corporate identifier. |
| Add Devices Of Users To Group_Scheduled | Sync devices of users in a specific group to another device group. |
| Add Management Partner | List or add or Management Partner Links (PAL) |
| Add Microsoft Store App Logos | Update logos of Microsoft Store Apps (new) in Intune. |
| Add Office365 Group | Create an Office 365 group and SharePoint site, optionally create a (Teams) team. |
| Add Or Remove Safelinks Exclusion | Add or remove a SafeLinks URL exclusion to/from a given policy. |
| Add Or Remove Smartscreen Exclusion | Add/Remove a SmartScreen URL Exception/Rule in MS Security Center Indicators |
| Add Or Remove Trusted Site | Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy |
| Add Security Group | This runbook creates a Microsoft Entra ID security group with membership type "Assigned". |
| Add User | Create a new user account. |
| Add Viva Engange Community | Creates a Viva Engage (Yammer) community via the Yammer API |
| Assign Groups By Template_Scheduled | Assign cloud-only groups to many users based on a predefined template. |
| Bulk Delete Devices From Autopilot | Mass-Delete Autopilot objects based on Serial Number. |
| Bulk Retire Devices From Intune | Bulk retire devices from Intune using serial numbers |
| Check Aad Sync Status_Scheduled | Check for last Azure AD Connect Sync Cycle. |
| Check Assignments Of Devices | Check Intune assignments for a given (or multiple) Device Names. |
| Check Assignments Of Groups | Check Intune assignments for a given (or multiple) Group Names. |
| Check Assignments Of Users | Check Intune assignments for a given (or multiple) User Principal Names (UPNs). |
| Check Autopilot Serialnumbers | Check if given serial numbers are present in AutoPilot. |
| Check Device Onboarding Exclusion_Schedule | Check for Autopilot devices not yet onboarded to Intune. Add these to an exclusion group. |
| Enrolled Devices Report_Scheduled | Show recent first-time device enrollments. |
| Export All Autopilot Devices | List/export all AutoPilot devices. |
| Export All Intune Devices | Export a list of all Intune devices and where they are registered. |
| Export Cloudpc Usage_Scheduled | Write daily Windows 365 Utilization Data to Azure Tables |
| Export Non Compliant Devices | Report on non-compliant devices and policies |
| Export Policy Report | Create a report of a tenant's polcies from Intune and AAD and write them to a markdown file. |
| Invite External Guest Users | Invites external guest users to the organization using Microsoft Graph. |
| List All Administrative Template Policies | List all Administrative Template policies and their assignments. |
| List Group License Assignment Errors | Report groups that have license assignment errors |
| Office365 License Report | Generate an Office 365 licensing report. |
| Report Apple Mdm Cert Expiry_Scheduled | Monitor/Report expiry of Apple device management certificates. |
| Report Pim Activations_Scheduled | Scheduled Report on PIM Activations. |
| Sync All Devices | Sync all Intune devices. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='org-mail'></a>
## Mail
| Runbook Name | Synopsis |
|--------------|----------|
| Add Distribution List | Create a classic distribution group. |
| Add Equipment Mailbox | Create an equipment mailbox. |
| Add Or Remove Public Folder | Add or remove a public folder. |
| Add Or Remove Teams Mailcontact | Create/Remove a contact, to allow pretty email addresses for Teams channels. |
| Add Room Mailbox | Create a room resource. |
| Add Shared Mailbox | Create a shared mailbox. |
| Hide Mailboxes_Scheduled | Hide / Unhide special mailboxes in Global Address Book |
| Set Booking Config | Configure Microsoft Bookings settings for the organization. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='org-phone'></a>
## Phone
| Runbook Name | Synopsis |
|--------------|----------|
| Get Teams Phone Number Assignment | Looks up, if the given phone number is assigned to a user in Microsoft Teams. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='org-security'></a>
## Security
| Runbook Name | Synopsis |
|--------------|----------|
| Add Defender Indicator | Create new Indicator in Defender for Endpoint. |
| Backup Conditional Access Policies | Exports the current set of Conditional Access policies to an Azure storage account. |
| List Admin Users | List AzureAD role holders and their MFA state. |
| List Expiring Role Assignments | List Azure AD role assignments that will expire before a given number of days. |
| List Inactive Devices | List/export inactive evices, which had no recent user logons. |
| List Inactive Users | List users, that have no recent interactive signins. |
| List Information Protection Labels | Prints a list of all available InformationProtectionPolicy labels. |
| List Pim Rolegroups Without Owners_Scheduled | List role-assignable groups with eligible role assignments but without owners |
| List Users By MFA Methods Count | Reports users by the count of their registered MFA methods. |
| List Vulnerable App Regs | List all app registrations that suffer from the CVE-2021-42306 vulnerability. |
| Notify Changed CA Policies | Exports the current set of Conditional Access policies to an Azure storage account. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user'></a>
# User
<a name='user-avd'></a>
## Avd
| Runbook Name | Synopsis |
|--------------|----------|
| User Signout | Removes (Signs Out) a specific User from their AVD Session. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-general'></a>
## General
| Runbook Name | Synopsis |
|--------------|----------|
| Assign Groups By Template | Assign cloud-only groups to a user based on a predefined template. |
| Assign Or Unassign License | (Un-)Assign a license to a user via group membership. |
| Assign Windows365 | Assign/Provision a Windows 365 instance |
| List Group Ownerships | List group ownerships for this user. |
| List Manager | List manager information for this user. |
| Offboard User Permanently | Permanently offboard a user. |
| Offboard User Temporarily | Temporarily offboard a user. |
| Reprovision Windows365 | Reprovision a Windows 365 Cloud PC |
| Resize Windows365 | Resize a Windows 365 Cloud PC |
| Unassign Windows365 | Remove/Deprovision a Windows 365 instance |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-mail'></a>
## Mail
| Runbook Name | Synopsis |
|--------------|----------|
| Add Or Remove Email Address | Add/remove eMail address to/from mailbox. |
| Assign Owa Mailbox Policy | Assign a given OWA mailbox policy to a user. |
| Convert To Shared Mailbox | Turn this users mailbox into a shared mailbox. |
| Delegate Full Access | Grant another user full access to this mailbox. |
| Delegate Send As | Grant another user sendAs permissions on this mailbox. |
| Delegate Send On Behalf | Grant another user sendOnBehalf permissions on this mailbox. |
| Hide Or Unhide In Addressbook | (Un)Hide this mailbox in address book. |
| List Mailbox Permissions | List permissions on a (shared) mailbox. |
| List Room Mailbox Configuration | List Room configuration. |
| Remove Mailbox | Hard delete a shared mailbox, room or bookings calendar. |
| Set Out Of Office | En-/Disable Out-of-office-notifications for a user/mailbox. |
| Set Room Mailbox Configuration | Set room resource policies. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-phone'></a>
## Phone
| Runbook Name | Synopsis |
|--------------|----------|
| Disable Teams Phone | Microsoft Teams telephony offboarding |
| Get Teams User Info | Get the status quo of a Microsoft Teams user in terms of phone number, if any, and certain Microsoft Teams policies. |
| Grant Teams User Policies | Grant specific Microsoft Teams policies to a Microsoft Teams enabled user. |
| Set Teams Permanent Call Forwarding | Set up immediate call forwarding for a Microsoft Teams Enterprise Voice user. |
| Set Teams Phone | Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-security'></a>
## Security
| Runbook Name | Synopsis |
|--------------|----------|
| Confirm Or Dismiss Risky User | Confirm compromise / Dismiss a "risky user" |
| Create Temporary Access Pass | Create an AAD temporary access pass for a user. |
| Enable Or Disable Password Expiration | Set a users password policy to "(Do not) Expire" |
| Reset Mfa | Remove all App- and Mobilephone auth methods for a user. |
| Reset Password | Reset a user's password. |
| Revoke Or Restore Access | Revoke user access and all active tokens or re-enable user. |
| Set Or Remove Mobile Phone Mfa | Add, update or remove a user's mobile phone MFA information. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-userinfo'></a>
## Userinfo
| Runbook Name | Synopsis |
|--------------|----------|
| Rename User | Rename a user or mailbox. Will not update metadata like DisplayName, GivenName, Surname. |
| Set Photo | Set / update the photo / avatar picture of a user. |
| Update User | Update/Finalize an existing user object. |

[Back to the RealmJoin runbook overview](#table-of-contents)


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
  - [AVD](#device-avd)
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
    - Show LAPS Password
- [Group](#group)
  - [Devices](#group-devices)
    - Check Updatable Assets
    - Unenroll Updatable Assets (Scheduled)
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
- [Organization](#organization)
  - [Applications](#organization-applications)
    - Add Application Registration
    - Delete Application Registration
    - Export Enterprise Application Users
    - List Inactive Enterprise Applications
    - Report Application Registration
    - Report Expiring Application Credentials (Scheduled)
    - Update Application Registration
  - [Devices](#organization-devices)
    - Add Autopilot Device
    - Add Device Via Corporate Identifier
    - Delete Stale Devices (Scheduled)
    - Get Bitlocker Recovery Key
    - Notify Users About Stale Devices (Scheduled)
    - Outphase Devices
    - Report Devices Without Primary User
    - Report Stale Devices (Scheduled)
    - Report Users With More Than 5-Devices
    - Sync Device Serialnumbers To Entraid (Scheduled)
  - [General](#organization-general)
    - Add Devices Of Users To Group (Scheduled)
    - Add Management Partner
    - Add Microsoft Store App Logos
    - Add Office365 Group
    - Add Or Remove Safelinks Exclusion
    - Add Or Remove Smartscreen Exclusion
    - Add Or Remove Trusted Site
    - Add Security Group
    - Add User
    - Add Viva Engange Community
    - Assign Groups By Template (Scheduled)
    - Bulk Delete Devices From Autopilot
    - Bulk Retire Devices From Intune
    - Check AAD Sync Status (Scheduled)
    - Check Assignments Of Devices
    - Check Assignments Of Groups
    - Check Assignments Of Users
    - Check Autopilot Serialnumbers
    - Check Device Onboarding Exclusion (Scheduled)
    - Enrolled Devices Report (Scheduled)
    - Export All Autopilot Devices
    - Export All Intune Devices
    - Export Cloudpc Usage (Scheduled)
    - Export Non Compliant Devices
    - Export Policy Report
    - Invite External Guest Users
    - List All Administrative Template Policies
    - List Group License Assignment Errors
    - Office365 License Report
    - Report Apple MDM Cert Expiry (Scheduled)
    - Report License Assignment (Scheduled)
    - Report PIM Activations (Scheduled)
    - Sync All Devices
  - [Mail](#organization-mail)
    - Add Distribution List
    - Add Equipment Mailbox
    - Add Or Remove Public Folder
    - Add Or Remove Teams Mailcontact
    - Add Or Remove Tenant Allow Block List
    - Add Room Mailbox
    - Add Shared Mailbox
    - Hide Mailboxes (Scheduled)
    - Set Booking Config
  - [Phone](#organization-phone)
    - Get Teams Phone Number Assignment
  - [Security](#organization-security)
    - Add Defender Indicator
    - Backup Conditional Access Policies
    - List Admin Users
    - List Expiring Role Assignments
    - List Inactive Devices
    - List Inactive Users
    - List Information Protection Labels
    - List PIM Rolegroups Without Owners (Scheduled)
    - List Users By MFA Methods Count
    - List Vulnerable App Regs
    - Monitor Pending EPM Requests (Scheduled)
    - Notify Changed CA Policies
    - Report EPM Elevation Requests (Scheduled)
- [User](#user)
  - [AVD](#user-avd)
    - User Signout
  - [General](#user-general)
    - Assign Groups By Template
    - Assign Or Unassign License
    - Assign Windows365
    - List Group Memberships
    - List Group Ownerships
    - List Manager
    - Offboard User Permanently
    - Offboard User Temporarily
    - Reprovision Windows365
    - Resize Windows365
    - Unassign Windows365
  - [Mail](#user-mail)
    - Add Or Remove Email Address
    - Assign OWA Mailbox Policy
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
    - Reset MFA
    - Reset Password
    - Revoke Or Restore Access
    - Set Or Remove Mobile Phone MFA
  - [Userinfo](#user-userinfo)
    - Rename User
    - Set Photo
    - Update User

<a name='device'></a>
# Device
<a name='device-avd'></a>
## AVD
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
| Check Updatable Assets | Check if a device is onboarded to Windows Update for Business |
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
| Enable Or Disable Device | Enable or disable a device in Entra ID |
| Isolate Or Release Device | Isolate this device. |
| Reset Mobile Device Pin | Reset a mobile device's password/PIN code. |
| Restrict Or Release Code Execution | Only allow Microsoft-signed code to run on a device, or remove an existing restriction. |
| Show LAPS Password | Show a local admin password for a device. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='group'></a>
# Group
<a name='group-devices'></a>
## Devices
| Runbook Name | Synopsis |
|--------------|----------|
| Check Updatable Assets | Check if devices in a group are onboarded to Windows Update for Business. |
| Unenroll Updatable Assets (Scheduled) | Unenroll devices from Windows Update for Business. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='group-general'></a>
## General
| Runbook Name | Synopsis |
|--------------|----------|
| Add Or Remove Nested Group | Add/remove a nested group to/from a group |
| Add Or Remove Owner | Add or remove a Office 365 group owner |
| Add Or Remove User | Add or remove a group member |
| Change Visibility | Change a group's visibility |
| List All Members | List all members of a group, including members that are part of nested groups |
| List Owners | List all owners of an Office 365 group. |
| List User Devices | List devices owned by group members. |
| Remove Group | Remove a group. For Microsoft 365 groups, also the associated resources (Teams, SharePoint site) will be removed. |
| Rename Group | Rename a group. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='group-mail'></a>
## Mail
| Runbook Name | Synopsis |
|--------------|----------|
| Enable Or Disable External Mail | Enable or disable external parties to send emails to a Microsoft 365 group |
| Show Or Hide In Address Book | Show or hide a group in the address book |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='group-teams'></a>
## Teams
| Runbook Name | Synopsis |
|--------------|----------|
| Archive Team | Archive a team |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='organization'></a>
# Organization
<a name='organization-applications'></a>
## Applications
| Runbook Name | Synopsis |
|--------------|----------|
| Add Application Registration | Add an application registration to Azure AD |
| Delete Application Registration | Delete an application registration from Azure AD |
| Export Enterprise Application Users | Export a CSV of all (enterprise) application owners and users |
| List Inactive Enterprise Applications | List enterprise applications with no recent sign-ins |
| Report Application Registration | Generate and email a comprehensive Application Registration report |
| Report Expiring Application Credentials (Scheduled) | List expiry date of all Application Registration credentials |
| Update Application Registration | Update an application registration in Azure AD |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='organization-devices'></a>
## Devices
| Runbook Name | Synopsis |
|--------------|----------|
| Add Autopilot Device | Import a Windows device into Windows Autopilot |
| Add Device Via Corporate Identifier | Import a device into Intune via corporate identifier |
| Delete Stale Devices (Scheduled) | Scheduled deletion of stale devices based on last activity |
| Get Bitlocker Recovery Key | Get the BitLocker recovery key |
| Notify Users About Stale Devices (Scheduled) | Notify primary users about their stale devices via email |
| Outphase Devices | Remove or outphase multiple devices |
| Report Devices Without Primary User | Reports all managed devices in Intune that do not have a primary user assigned. |
| Report Stale Devices (Scheduled) | Scheduled report of stale devices based on last activity date and platform. |
| Report Users With More Than 5-Devices | Report users with more than five registered devices |
| Sync Device Serialnumbers To Entraid (Scheduled) | Sync Intune serial numbers to Entra ID extension attributes |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='organization-general'></a>
## General
| Runbook Name | Synopsis |
|--------------|----------|
| Add Devices Of Users To Group (Scheduled) | Sync devices of users in a specific group to another device group |
| Add Management Partner | List or add Management Partner Links (PAL) |
| Add Microsoft Store App Logos | Update logos of Microsoft Store Apps (new) in Intune |
| Add Office365 Group | Create an Office 365 group and SharePoint site, optionally create a (Teams) team. |
| Add Or Remove Safelinks Exclusion | Add or remove a SafeLinks URL exclusion from a policy |
| Add Or Remove Smartscreen Exclusion | Add or remove a SmartScreen URL indicator in Microsoft Defender |
| Add Or Remove Trusted Site | Add or remove a URL entry in the Intune Trusted Sites policy |
| Add Security Group | Create a Microsoft Entra ID security group |
| Add User | Create a new user account |
| Add Viva Engange Community | Create a Viva Engage (Yammer) community |
| Assign Groups By Template (Scheduled) | Assign cloud-only groups to many users based on a predefined template |
| Bulk Delete Devices From Autopilot | Bulk delete Autopilot objects by serial number |
| Bulk Retire Devices From Intune | Bulk retire devices from Intune using serial numbers |
| Check AAD Sync Status (Scheduled) | Check last Azure AD Connect sync status |
| Check Assignments Of Devices | Check Intune assignments for one or more device names |
| Check Assignments Of Groups | Check Intune assignments for one or more group names |
| Check Assignments Of Users | Check Intune assignments for one or more user principal names |
| Check Autopilot Serialnumbers | Check if given serial numbers are present in Autopilot |
| Check Device Onboarding Exclusion (Scheduled) | Add unenrolled Autopilot devices to an exclusion group |
| Enrolled Devices Report (Scheduled) | Show recent first-time device enrollments |
| Export All Autopilot Devices | List or export all Windows Autopilot devices |
| Export All Intune Devices | Export a list of all Intune devices and where they are registered |
| Export Cloudpc Usage (Scheduled) | Write daily Windows 365 utilization data to Azure Table Storage |
| Export Non Compliant Devices | Export non-compliant Intune devices and settings |
| Export Policy Report | Create a report of tenant policies from Intune and Entra ID. |
| Invite External Guest Users | Invite external guest users to the organization |
| List All Administrative Template Policies | List all Administrative Template policies and their assignments |
| List Group License Assignment Errors | Report groups that have license assignment errors |
| Office365 License Report | Generate an Office 365 licensing report |
| Report Apple MDM Cert Expiry (Scheduled) | Monitor/Report expiry of Apple device management certificates |
| Report License Assignment (Scheduled) | Generate and email a license availability report based on thresholds |
| Report PIM Activations (Scheduled) | Scheduled report on PIM activations |
| Sync All Devices | Sync all Intune Windows devices |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='organization-mail'></a>
## Mail
| Runbook Name | Synopsis |
|--------------|----------|
| Add Distribution List | Create a classic distribution group |
| Add Equipment Mailbox | Create an equipment mailbox |
| Add Or Remove Public Folder | Add or remove a public folder |
| Add Or Remove Teams Mailcontact | Create/Remove a contact, to allow pretty email addresses for Teams channels. |
| Add Or Remove Tenant Allow Block List | Add or remove entries from the Tenant Allow/Block List |
| Add Room Mailbox | Create a room mailbox resource |
| Add Shared Mailbox | Create a shared mailbox |
| Hide Mailboxes (Scheduled) | Hide or unhide special mailboxes in the Global Address List |
| Set Booking Config | Configure Microsoft Bookings settings for the organization |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='organization-phone'></a>
## Phone
| Runbook Name | Synopsis |
|--------------|----------|
| Get Teams Phone Number Assignment | Check whether a phone number is assigned in Microsoft Teams |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='organization-security'></a>
## Security
| Runbook Name | Synopsis |
|--------------|----------|
| Add Defender Indicator | Create a new Microsoft Defender for Endpoint indicator |
| Backup Conditional Access Policies | Export Conditional Access policies to an Azure Storage account |
| List Admin Users | List Entra ID role holders and optionally evaluate their MFA methods |
| List Expiring Role Assignments | List Azure AD role assignments expiring within a given number of days |
| List Inactive Devices | List or export inactive devices with no recent logon or Intune sync |
| List Inactive Users | List users with no recent interactive sign-ins |
| List Information Protection Labels | List Microsoft Information Protection labels |
| List PIM Rolegroups Without Owners (Scheduled) | List role-assignable groups with eligible role assignments but without owners |
| List Users By MFA Methods Count | Report users by the count of their registered MFA methods |
| List Vulnerable App Regs | List app registrations potentially vulnerable to CVE-2021-42306 |
| Monitor Pending EPM Requests (Scheduled) | Monitor and report pending Endpoint Privilege Management (EPM) elevation requests |
| Notify Changed CA Policies | Send notification email if Conditional Access policies have been created or modified in the last 24 hours. |
| Report EPM Elevation Requests (Scheduled) | Generate report for Endpoint Privilege Management (EPM) elevation requests |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user'></a>
# User
<a name='user-avd'></a>
## AVD
| Runbook Name | Synopsis |
|--------------|----------|
| User Signout | Removes (Signs Out) a specific User from their AVD Session. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-general'></a>
## General
| Runbook Name | Synopsis |
|--------------|----------|
| Assign Groups By Template | Assign cloud-only groups to a user based on a template |
| Assign Or Unassign License | Assign or remove a license for a user via group membership |
| Assign Windows365 | Assign and provision a Windows 365 Cloud PC for a user |
| List Group Memberships | List group memberships for this user |
| List Group Ownerships | List group ownerships for this user. |
| List Manager | List manager information for this user |
| Offboard User Permanently | Permanently offboard a user |
| Offboard User Temporarily | Temporarily offboard a user |
| Reprovision Windows365 | Reprovision a Windows 365 Cloud PC |
| Resize Windows365 | Resize an existing Windows 365 Cloud PC for a user |
| Unassign Windows365 | Remove and deprovision a Windows 365 Cloud PC for a user |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-mail'></a>
## Mail
| Runbook Name | Synopsis |
|--------------|----------|
| Add Or Remove Email Address | Add or remove an email address for a mailbox |
| Assign OWA Mailbox Policy | Assign an OWA mailbox policy to a user |
| Convert To Shared Mailbox | Convert a user mailbox to a shared mailbox and back |
| Delegate Full Access | Delegate FullAccess permissions to another user on a mailbox or remove existing delegation |
| Delegate Send As | Delegate SendAs permissions for other user on his/her mailbox or remove existing delegation |
| Delegate Send On Behalf | Delegate SendOnBehalf permissions for the user's mailbox |
| Hide Or Unhide In Addressbook | Hide or unhide a mailbox in the address book |
| List Mailbox Permissions | List mailbox permissions for a mailbox |
| List Room Mailbox Configuration | List room mailbox configuration |
| Remove Mailbox | Hard delete a shared mailbox, room or bookings calendar |
| Set Out Of Office | Enable or disable out-of-office notifications for a mailbox |
| Set Room Mailbox Configuration | Set room mailbox resource policies |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-phone'></a>
## Phone
| Runbook Name | Synopsis |
|--------------|----------|
| Disable Teams Phone | Microsoft Teams telephony offboarding |
| Get Teams User Info | Get Microsoft Teams voice status for a user |
| Grant Teams User Policies | Grant Microsoft Teams policies to a Microsoft Teams enabled user |
| Set Teams Permanent Call Forwarding | Set immediate call forwarding for a Teams user |
| Set Teams Phone | Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies. |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-security'></a>
## Security
| Runbook Name | Synopsis |
|--------------|----------|
| Confirm Or Dismiss Risky User | Confirm compromise or dismiss a risky user |
| Create Temporary Access Pass | Create a temporary access pass for a user |
| Enable Or Disable Password Expiration | Enable or disable password expiration for a user |
| Reset MFA | Remove all App- and Mobilephone auth methods for a user |
| Reset Password | Reset a user's password |
| Revoke Or Restore Access | Revoke or restore user access |
| Set Or Remove Mobile Phone MFA | Set or remove a user's mobile phone MFA method |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-userinfo'></a>
## Userinfo
| Runbook Name | Synopsis |
|--------------|----------|
| Rename User | Rename a user or mailbox |
| Set Photo | Set the profile photo for a user |
| Update User | Update user metadata and memberships |

[Back to the RealmJoin runbook overview](#table-of-contents)


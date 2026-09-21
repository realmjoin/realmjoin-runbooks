<a name='runbook-overview'></a>
# Runbook overview
This document provides a comprehensive overview of all runbooks currently available in the RealmJoin portal. Each runbook is listed along with a brief description or synopsis to give a clear understanding of its purpose and functionality.

To ensure easy navigation, the runbooks are categorized into different sections based on their area of application. The following categories are currently available:
- Device
- Group
- Organization
- User

Each category contains multiple runbooks that are further divided into subcategories based on their functionality. The runbooks are listed in alphabetical order within each subcategory.

## Table of Contents
- [Device](#device)
  - [AVD](#device-avd)
    - Restart Host
    - Toggle Drain Mode
  - [General](#device-general)
    - Assign Groups By Template
    - Change Grouptag
    - Check Device Compliance
    - Check Updatable Assets
    - Enroll Updatable Assets
    - Outphase Device
    - Remove Primary User
    - Rename Device
    - Set Primary User
    - Unenroll Updatable Assets
    - Wipe Device
    - Wipe Managed App Data
  - [Security](#device-security)
    - Check Defender Status
    - Enable Or Disable Device
    - Isolate Or Release Device
    - Reset Mobile Device Pin
    - Restrict Or Release Code Execution
    - Show Bitlocker Recovery Key
    - Show Filevault Recovery Key
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
    - Add GSA Application Registration
    - Delete Application Registration
    - Delete GSA Application Registration
    - Export Enterprise Application Users
    - List Inactive Enterprise Applications
    - Report Application Registration
    - Report Expiring Application Credentials (Scheduled)
    - Update Application Registration
  - [Collab](#organization-collab)
    - Check Onedrive Status
    - List Sharepoint Sitecollection Permission
    - Report Sharepoint Tenant Storage (Scheduled)
  - [Devices](#organization-devices)
    - Add Autopilot Device
    - Add Device Via Corporate Identifier
    - Auto Approve Driver Updates (Scheduled)
    - Cleanup Autopilot Devices (Scheduled)
    - Create Endpoint Analytics Baseline
    - Dedup Device Names (Scheduled)
    - Delete Stale Devices (Scheduled)
    - Get Bitlocker Recovery Key
    - List Mobile Devices
    - Notify Users About Low Diskspace (Scheduled)
    - Notify Users About Stale Devices (Scheduled)
    - Outphase Devices
    - Rename Devices By Group Tag (Scheduled)
    - Report Devices Low Diskspace (Scheduled)
    - Report Devices Without Primary User (Scheduled)
    - Report Primary User Mismatch (Scheduled)
    - Report Stale Devices (Scheduled)
    - Report Users With More Than 5-Devices (Scheduled)
    - Report Windows Devices Without Autopilot (Scheduled)
    - Sync Device Serialnumbers To Entraid (Scheduled)
  - [General](#organization-general)
    - Add Devices Of Users To Group (Scheduled)
    - Add Management Partner
    - Add Microsoft Store App Logos
    - Add Office365 Group
    - Add Or Remove Safelinks Exclusion
    - Add Or Remove Smartscreen Exclusion
    - Add Or Remove Trusted Site
    - Add Primary Users Of Devices To Group (Scheduled)
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
    - Monitor Service Health (Scheduled)
    - Office365 License Report
    - Report Apple MDM Cert Expiry (Scheduled)
    - Report Intune Enrollment Readiness
    - Report License Assignment (Scheduled)
    - Report PIM Activations (Scheduled)
    - Sync All Devices
    - Sync Apple Tokens
    - Sync Channel Or Group Members (Scheduled)
    - Sync Shared Channel Owners (Scheduled)
  - [Mail](#organization-mail)
    - Add Distribution List
    - Add Equipment Mailbox
    - Add Mail Contact
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
    - Find SMS Auth Phone Number
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
    - Sync MFA Secure Users To Group (Scheduled)
- [User](#user)
  - [AVD](#user-avd)
    - User Signout
  - [General](#user-general)
    - Assign Groups By Template
    - Assign Or Unassign License
    - Assign Windows365
    - Check Intune Enrollment Readiness
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
    - Manage Archive Mailbox
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
    - List MFA Methods
    - List Signin Events
    - Reset MFA
    - Reset Password
    - Revoke Or Restore Access
    - Set Or Remove Mobile Phone MFA
  - [Userinfo](#user-userinfo)
    - Rename User
    - Set Photo
    - Update User

<a name='device'></a>
## Device
<a name='device-avd'></a>
### AVD
| Runbook Name | Synopsis |
|--------------|----------|
| Restart Host | Restart this AVD session host and return it to service |
| Toggle Drain Mode | Enable or disable drain mode on this AVD session host |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='device-general'></a>
### General
| Runbook Name | Synopsis |
|--------------|----------|
| Assign Groups By Template | Add this device to a predefined set of groups |
| Change Grouptag | Assign a new Autopilot group tag to this device |
| Check Device Compliance | Check the Intune compliance status of this device |
| Check Updatable Assets | Check whether this device is enrolled in Windows Update for Business |
| Enroll Updatable Assets | Enroll this device in Windows Update for Business |
| Outphase Device | Wipe this Windows device and clean up Intune, Autopilot and Entra ID |
| Remove Primary User | Remove the primary user from this device |
| Rename Device | Rename this device in Intune and Autopilot |
| Set Primary User | Set a new primary user on this device |
| Unenroll Updatable Assets | Unenroll this device from Windows Update for Business |
| Wipe Device | Wipe this Windows or macOS device and clean up its records |
| Wipe Managed App Data | Remove company app data from this MAM-managed device |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='device-security'></a>
### Security
| Runbook Name | Synopsis |
|--------------|----------|
| Check Defender Status | Check this device in Entra ID and Defender for Endpoint |
| Enable Or Disable Device | Enable or disable this device in Entra ID |
| Isolate Or Release Device | Isolate this device from the network or release it |
| Reset Mobile Device Pin | Reset the passcode of this mobile device |
| Restrict Or Release Code Execution | Restrict this device to Microsoft-signed code or lift the restriction |
| Show Bitlocker Recovery Key | Show the BitLocker recovery keys of this device |
| Show Filevault Recovery Key | Show the FileVault recovery key of this Mac |
| Show LAPS Password | Show the local admin password of this device |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='group'></a>
## Group
<a name='group-devices'></a>
### Devices
| Runbook Name | Synopsis |
|--------------|----------|
| Check Updatable Assets | Check Windows Update for Business enrollment of this group's devices |
| Unenroll Updatable Assets (Scheduled) | Unenroll this group's devices from Windows Update for Business |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='group-general'></a>
### General
| Runbook Name | Synopsis |
|--------------|----------|
| Add Or Remove Nested Group | Add a nested group to this group or remove it |
| Add Or Remove Owner | Add an owner to this group or remove one |
| Add Or Remove User | Add a user to this group or remove one |
| Change Visibility | Make this group public or private |
| List All Members | List all members of this group, nested groups included |
| List Owners | List the owners of this group |
| List User Devices | List the devices registered to this group's members |
| Remove Group | Delete this group and its Microsoft 365 resources |
| Rename Group | Rename this group or change its description |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='group-mail'></a>
### Mail
| Runbook Name | Synopsis |
|--------------|----------|
| Enable Or Disable External Mail | Allow or block external senders for this Microsoft 365 group |
| Show Or Hide In Address Book | Show or hide this group in the address book |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='group-teams'></a>
### Teams
| Runbook Name | Synopsis |
|--------------|----------|
| Archive Team | Archive the team of this group |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='organization'></a>
## Organization
<a name='organization-applications'></a>
### Applications
| Runbook Name | Synopsis |
|--------------|----------|
| Add Application Registration | Create an application registration in Entra ID |
| Add GSA Application Registration | Create a Global Secure Access application with its access group |
| Delete Application Registration | Delete an application registration and its service principal |
| Delete GSA Application Registration | Delete a Global Secure Access application and its access group |
| Export Enterprise Application Users | Export the owners and users of all enterprise applications |
| List Inactive Enterprise Applications | List enterprise applications with no recent sign-ins |
| Report Application Registration | Report all application registrations, including deleted ones |
| Report Expiring Application Credentials (Scheduled) | Report expiring client secrets and certificates of app registrations |
| Update Application Registration | Update redirect URIs, SAML and sign-in settings of an app registration |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='organization-collab'></a>
### Collab
| Runbook Name | Synopsis |
|--------------|----------|
| Check Onedrive Status | Check whether a user's OneDrive is active, locked or deleted |
| List Sharepoint Sitecollection Permission | List the administrators and members of a SharePoint site |
| Report Sharepoint Tenant Storage (Scheduled) | Monitor SharePoint storage and alert when limits are exceeded |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='organization-devices'></a>
### Devices
| Runbook Name | Synopsis |
|--------------|----------|
| Add Autopilot Device | Register a Windows device in Windows Autopilot |
| Add Device Via Corporate Identifier | Register a device in Intune by its corporate identifier |
| Auto Approve Driver Updates (Scheduled) | Approve pending driver updates in Intune driver update policies |
| Cleanup Autopilot Devices (Scheduled) | Remove orphaned and never-enrolled Autopilot registrations |
| Create Endpoint Analytics Baseline | Create an Endpoint Analytics baseline with a naming schema |
| Dedup Device Names (Scheduled) | Rename Intune devices that share a display name |
| Delete Stale Devices (Scheduled) | Delete Intune devices that have been inactive for too long |
| Get Bitlocker Recovery Key | Look up a BitLocker recovery key by its key ID |
| List Mobile Devices | List managed mobile devices with inventory and network details |
| Notify Users About Low Diskspace (Scheduled) | Email users whose devices are running out of disk space |
| Notify Users About Stale Devices (Scheduled) | Email users about devices they have not used for a while |
| Outphase Devices | Wipe and clean up several devices at once |
| Rename Devices By Group Tag (Scheduled) | Name Autopilot devices after their group tag and serial number |
| Report Devices Low Diskspace (Scheduled) | Report devices that are running out of disk space |
| Report Devices Without Primary User (Scheduled) | Report Intune devices without a primary user |
| Report Primary User Mismatch (Scheduled) | Compare primary users between Intune and RealmJoin |
| Report Stale Devices (Scheduled) | Report devices that have been inactive for too long |
| Report Users With More Than 5-Devices (Scheduled) | Report users with more than five registered devices |
| Report Windows Devices Without Autopilot (Scheduled) | Report Windows devices in Entra ID without an Autopilot record |
| Sync Device Serialnumbers To Entraid (Scheduled) | Copy Intune serial numbers into an Entra ID extension attribute |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='organization-general'></a>
### General
| Runbook Name | Synopsis |
|--------------|----------|
| Add Devices Of Users To Group (Scheduled) | Add the devices of a user group's members to a device group |
| Add Management Partner | List or add a Partner Admin Link (PAL) for the tenant |
| Add Microsoft Store App Logos | Add missing logos to Microsoft Store apps in Intune |
| Add Office365 Group | Create a Microsoft 365 group, optionally with a team |
| Add Or Remove Safelinks Exclusion | Allow a URL pattern in a Safe Links policy or remove it |
| Add Or Remove Smartscreen Exclusion | Allow, warn or block a URL in Defender SmartScreen |
| Add Or Remove Trusted Site | Add a URL to the Intune trusted sites list or remove it |
| Add Primary Users Of Devices To Group (Scheduled) | Keep a group in sync with the primary users of Intune devices |
| Add Security Group | Create a security group in Entra ID |
| Add User | Create a new user account in Entra ID |
| Add Viva Engange Community | Create a Viva Engage community with owners |
| Assign Groups By Template (Scheduled) | Add the users of a group to a predefined set of groups |
| Bulk Delete Devices From Autopilot | Delete several Autopilot registrations by serial number |
| Bulk Retire Devices From Intune | Retire several Intune devices by serial number |
| Check AAD Sync Status (Scheduled) | Check the last Entra Connect sync and alert when it is off |
| Check Assignments Of Devices | Show which Intune policies and apps target given devices |
| Check Assignments Of Groups | Show which Intune policies and apps target given groups |
| Check Assignments Of Users | Show which Intune policies and apps target given users |
| Check Autopilot Serialnumbers | Check which serial numbers are registered in Autopilot |
| Check Device Onboarding Exclusion (Scheduled) | Keep unenrolled Autopilot devices in a compliance exclusion group |
| Enrolled Devices Report (Scheduled) | Report first-time device enrollments of the last weeks |
| Export All Autopilot Devices | List or export all Windows Autopilot devices |
| Export All Intune Devices | Export all Intune devices with their primary users' usage location |
| Export Cloudpc Usage (Scheduled) | Write daily Windows 365 usage data to an Azure table |
| Export Non Compliant Devices | Export non-compliant Intune devices with their failing settings |
| Export Policy Report | Export Intune and Entra ID policies as a Markdown report |
| Invite External Guest Users | Invite an external person as a guest user |
| List All Administrative Template Policies | List administrative template policies with their assignments |
| List Group License Assignment Errors | List groups whose license assignments have errors |
| Monitor Service Health (Scheduled) | Alert by email about new Microsoft 365 service health issues |
| Office365 License Report | Report Microsoft 365 license usage and availability |
| Report Apple MDM Cert Expiry (Scheduled) | Alert before Apple MDM certificates and tokens expire |
| Report Intune Enrollment Readiness | Report which users can enroll devices in Intune |
| Report License Assignment (Scheduled) | Alert when license availability crosses thresholds |
| Report PIM Activations (Scheduled) | Report the PIM role activations of the last month by email |
| Sync All Devices | Trigger an Intune sync on all Windows devices |
| Sync Apple Tokens | Sync Apple enrollment and VPP tokens with Intune |
| Sync Channel Or Group Members (Scheduled) | Mirror members between a Teams shared channel and a group |
| Sync Shared Channel Owners (Scheduled) | Make a group's members owners of mapped teams and shared channels |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='organization-mail'></a>
### Mail
| Runbook Name | Synopsis |
|--------------|----------|
| Add Distribution List | Create a classic Exchange Online distribution group |
| Add Equipment Mailbox | Create an equipment mailbox with optional delegate |
| Add Mail Contact | Create a mail contact for an external address |
| Add Or Remove Public Folder | Create or remove an Exchange Online public folder |
| Add Or Remove Teams Mailcontact | Give a Teams channel a friendly email address or remove it |
| Add Or Remove Tenant Allow Block List | Add or remove a Tenant Allow/Block List entry |
| Add Room Mailbox | Create a room mailbox with optional delegate |
| Add Shared Mailbox | Create a shared mailbox with optional delegate |
| Hide Mailboxes (Scheduled) | Hide or show all Bookings calendars in the address book |
| Set Booking Config | Configure the Microsoft Bookings settings of the tenant |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='organization-phone'></a>
### Phone
| Runbook Name | Synopsis |
|--------------|----------|
| Get Teams Phone Number Assignment | Check whether a phone number is assigned in Microsoft Teams |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='organization-security'></a>
### Security
| Runbook Name | Synopsis |
|--------------|----------|
| Add Defender Indicator | Add an allow or block indicator to Defender for Endpoint |
| Backup Conditional Access Policies | Back up all Conditional Access policies to Azure Storage |
| Find SMS Auth Phone Number | Find the user who holds an SMS sign-in phone number |
| List Admin Users | List all Entra ID admins and check their MFA methods |
| List Expiring Role Assignments | List Entra ID role assignments that expire soon |
| List Inactive Devices | List devices with no recent sign-in or Intune sync |
| List Inactive Users | List users with no recent interactive sign-in |
| List Information Protection Labels | List the sensitivity labels of the tenant with their IDs |
| List PIM Rolegroups Without Owners (Scheduled) | Alert on PIM role groups that have no owner |
| List Users By MFA Methods Count | List users by how many MFA methods they registered |
| List Vulnerable App Regs | List app registrations possibly affected by CVE-2021-42306 |
| Monitor Pending EPM Requests (Scheduled) | Alert by email about pending EPM elevation requests |
| Notify Changed CA Policies | Alert by email about Conditional Access policy changes |
| Report EPM Elevation Requests (Scheduled) | Report EPM elevation requests by status and age |
| Sync MFA Secure Users To Group (Scheduled) | Keep a group filled with users who registered a secure MFA method |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user'></a>
## User
<a name='user-avd'></a>
### AVD
| Runbook Name | Synopsis |
|--------------|----------|
| User Signout | Sign this user out of their AVD sessions |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-general'></a>
### General
| Runbook Name | Synopsis |
|--------------|----------|
| Assign Groups By Template | Add this user to a predefined set of groups |
| Assign Or Unassign License | Assign or remove a license for this user via a license group |
| Assign Windows365 | Provision a Windows 365 Cloud PC for this user |
| Check Intune Enrollment Readiness | Check whether this user can enroll devices in Intune |
| List Group Memberships | List the group memberships of this user |
| List Group Ownerships | List the groups this user owns |
| List Manager | Show the manager of this user |
| Offboard User Permanently | Permanently offboard this user |
| Offboard User Temporarily | Temporarily offboard this user |
| Reprovision Windows365 | Reprovision the Windows 365 Cloud PC of this user |
| Resize Windows365 | Resize the Windows 365 Cloud PC of this user |
| Unassign Windows365 | Remove the Windows 365 Cloud PC of this user |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-mail'></a>
### Mail
| Runbook Name | Synopsis |
|--------------|----------|
| Add Or Remove Email Address | Add an email address to this user's mailbox or remove one |
| Assign OWA Mailbox Policy | Assign an Outlook on the web policy to this user's mailbox |
| Convert To Shared Mailbox | Convert this user's mailbox to a shared mailbox or back |
| Delegate Full Access | Grant or remove full access to this user's mailbox |
| Delegate Send As | Grant or remove Send As permission on this user's mailbox |
| Delegate Send On Behalf | Grant or remove Send on Behalf permission on this user's mailbox |
| Hide Or Unhide In Addressbook | Hide this user's mailbox in the address book or show it |
| List Mailbox Permissions | List who has access to this user's mailbox |
| List Room Mailbox Configuration | Show the booking configuration of this room mailbox |
| Manage Archive Mailbox | Enable, disable or check the archive mailbox of this user |
| Remove Mailbox | Permanently delete this shared mailbox, room or Bookings calendar |
| Set Out Of Office | Set or remove automatic replies for this user |
| Set Room Mailbox Configuration | Configure the booking rules of this room mailbox |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-phone'></a>
### Phone
| Runbook Name | Synopsis |
|--------------|----------|
| Disable Teams Phone | Remove Teams phone number and voice policies from this user |
| Get Teams User Info | Show the Teams voice setup of this user |
| Grant Teams User Policies | Assign Teams voice and meeting policies to this user |
| Set Teams Permanent Call Forwarding | Forward this user's calls immediately or turn forwarding off |
| Set Teams Phone | Assign a phone number and voice policies to this user |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-security'></a>
### Security
| Runbook Name | Synopsis |
|--------------|----------|
| Confirm Or Dismiss Risky User | Confirm this user as compromised or dismiss the risk |
| Create Temporary Access Pass | Create a Temporary Access Pass for this user |
| Enable Or Disable Password Expiration | Turn password expiration on or off for this user |
| List MFA Methods | List the MFA and authentication methods of this user |
| List Signin Events | Show the recent sign-ins of this user and their failures |
| Reset MFA | Remove this user's app, phone, OATH and FIDO2 MFA methods |
| Reset Password | Set a new password for this user |
| Revoke Or Restore Access | Block this user's sign-in and sessions, or restore access |
| Set Or Remove Mobile Phone MFA | Set or remove the mobile phone MFA method of this user |

[Back to the RealmJoin runbook overview](#table-of-contents)

<a name='user-userinfo'></a>
### Userinfo
| Runbook Name | Synopsis |
|--------------|----------|
| Rename User | Change this user's sign-in name (UPN) and mailbox alias |
| Set Photo | Set the profile photo of this user from a URL |
| Update User | Update profile details, groups and mailbox settings of this user |

[Back to the RealmJoin runbook overview](#table-of-contents)


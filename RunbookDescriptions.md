
# Device \ General \ Change Grouptag
## Assign a new AutoPilot GroupTag to this device.

## Description
Assign a new AutoPilot GroupTag to this device.

## Permissions (Notes)
```
Permissions: 
MS Graph (API):
- Device.Read.All
- DeviceManagementServiceConfig.ReadWrite.All
```

# Device \ General \ Check Updatable Assets
## Check if a device is onboarded to Windows Update for Business.

## Description
This script checks if single device is onboarded to Windows Update for Business.

## Permissions (Notes)
```
Permissions (Graph):
- Device.Read.All
- WindowsUpdates.ReadWrite.All
```

# Device \ General \ Enroll Updatable Assets
## Enroll device into Windows Update for Business.

## Description
This script enrolls devices into Windows Update for Business.

## Permissions (Notes)
```
Permissions (Graph):
- WindowsUpdates.ReadWrite.All
```

# Device \ General \ Outphase Device
## Remove/Outphase a windows device

## Description
Remove/Outphase a windows device. You can choose if you want to wipe the device and/or delete it from Intune an AutoPilot.

## Permissions (Notes)
```
PERMISSIONS
 DeviceManagementManagedDevices.PrivilegedOperations.All (Wipe,Retire / seems to allow us to delete from AzureAD)
 DeviceManagementManagedDevices.ReadWrite.All (Delete Inunte Device)
 DeviceManagementServiceConfig.ReadWrite.All (Delete Autopilot enrollment)
 Device.Read.All
ROLES
 Cloud device administrator
```

# Device \ General \ Rename Device
## Rename a device.

## Description
Rename a device (in Intune and Autopilot).

## Permissions (Notes)
```
Permissions: 
MS Graph (API):
- Device.Read.All
- DeviceManagementManagedDevices.Read.All
- DeviceManagementServiceConfig.ReadWrite.All
- DeviceManagementManagedDevices.PrivilegedOperations.All
```

# Device \ General \ Unenroll Updatable Assets
## Unenroll device from Windows Update for Business.

## Description
This script unenrolls devices from Windows Update for Business.

## Permissions (Notes)
```
Permissions (Graph):
- WindowsUpdates.ReadWrite.All
```

# Device \ General \ Wipe Device
## Wipe a Windows or MacOS device

## Description
Wipe a Windows or MacOS device.

## Permissions (Notes)
```
PERMISSIONS
 DeviceManagementManagedDevices.PrivilegedOperations.All (Wipe,Retire / seems to allow us to delete from AzureAD)
 DeviceManagementManagedDevices.ReadWrite.All (Delete Inunte Device)
 DeviceManagementServiceConfig.ReadWrite.All (Delete Autopilot enrollment)
 Device.Read.All
ROLES
 Cloud device administrator
```

# Device \ Security \ Enable Or Disable Device
## Disable a device in AzureAD.

## Description
Disable a device in AzureAD.

## Permissions (Notes)
```
Permissions (Graph):
- Device.Read.All
Roles (AzureAD):
- Cloud Device Administrator
```

# Device \ Security \ Isolate Or Release Device
## Isolate this device.

## Description
Isolate this device using Defender for Endpoint.

## Permissions (Notes)
```
Permissions (WindowsDefenderATP, Application):
- Machine.Read.All
- Machine.Isolate
```

# Device \ Security \ Reset Mobile Device Pin
## Reset a mobile device's password/PIN code.

## Description
Reset a mobile device's password/PIN code. Warning: Not possible for all types of devices.

## Permissions (Notes)
```
Permissions needed:
- DeviceManagementManagedDevices.Read.All,
- DeviceManagementManagedDevices.PrivilegedOperations.All
```

# Device \ Security \ Restrict Or Release Code Execution
## Restrict code execution.

## Description
Only allow Microsoft signed code to be executed.

## Permissions (Notes)
```
Permissions (WindowsDefenderATP, Application):
- Machine.Read.All
- Machine.RestrictExecution
```

# Device \ Security \ Show Laps Password
## Show a local admin password for a device.

## Description
Show a local admin password for a device.

## Permissions (Notes)
```
Permissions (Graph):
- DeviceLocalCredential.Read.All
```

# Group \ Devices \ Check Updatable Assets
## Check if devices in a group are onboarded to Windows Update for Business.

## Description
This script checks if single or multiple devices (by Group Object ID) are onboarded to Windows Update for Business.

## Permissions (Notes)
```
Permissions (Graph):
- Device.Read.All
- Group.Read.All
- WindowsUpdates.ReadWrite.All
```

# Group \ Devices \ Unenroll Updatable Assets
## Unenroll devices from Windows Update for Business.

## Description
This script unenrolls devices from Windows Update for Business.

## Permissions (Notes)
```
Permissions (Graph):
- Group.Read.All
- WindowsUpdates.ReadWrite.All
```

# Group \ General \ Add Or Remove Nested Group
## Add/remove a nested group to/from a group.

## Description
Add/remove a nested group to/from an AzureAD or Exchange Online group.

## Permissions (Notes)
```
Permissions: 
MS Graph (API)
- Group.ReadWrite.All
- Directory.ReadWrite.All
```

# Group \ General \ Add Or Remove Owner
## Add/remove owners to/from an Office 365 group.

## Description
Add/remove owners to/from an Office 365 group.

## Permissions (Notes)
```
Permissions: 
MS Graph (API)
- Group.ReadWrite.All
- Directory.ReadWrite.All
Office 365 Exchange Online
 - Exchange.ManageAsApp
Azure AD Roles
 - Exchange administrator
```

# Group \ General \ Add Or Remove User
## Add/remove users to/from a group.

## Description
Add/remove users to/from an AzureAD or Exchange Online group.

## Permissions (Notes)
```
Permissions: 
MS Graph (API)
- Group.ReadWrite.All
- Directory.ReadWrite.All
```

# Group \ General \ Change Visibility
## Change a group's visibility

## Description
Change a group's visibility

## Permissions (Notes)
```
Permissions: 
MS Graph (API)
- Group.ReadWrite.All
- Directory.ReadWrite.All
```

# Group \ General \ List All Members
## Retrieves the members of a specified EntraID group, including members from nested groups.

## Description
This script retrieves the members of a specified EntraID group, including both direct members and those from nested groups. 
The output is a CSV file with columns for User Principal Name (UPN), direct membership status, and group path. 
The group path reflects the membership hierarchy—for example, “Primary, Secondary” if a user belongs to “Primary” via the nested group “Secondary.”

## Permissions (Notes)
```
Required Permissions:
- Group.Read.All
- User.Read.All
```

# Group \ General \ List Owners
## List all owners of an Office 365 group.

## Description
List all owners of an Office 365 group.

## Permissions (Notes)
```
Permissions: 
MS Graph (API)
- Group.Read.All
```

# Group \ General \ List User Devices
## List all devices owned by group members.

## Description
List all devices owned by group members.

## Permissions (Notes)
```
Permissions: 
MS Graph (API)
- Group.Read.All
```

# Group \ General \ Remove Group
## Removes a group, incl. SharePoint site and Teams team.

## Description
Removes a group, incl. SharePoint site and Teams team.

## Permissions (Notes)
```
MS Graph (API): 
- Group.ReadWrite.All
```

# Group \ General \ Rename Group
## Rename a group.

## Description
Rename a group MailNickname, DisplayName and Description. Will NOT change eMail addresses!

## Permissions (Notes)
```
Permissions: MS Graph (API):
 - Group.ReadWrite.All
```

# Group \ Mail \ Enable Or Disable External Mail
## Enable/disable external parties to send eMails to O365 groups.

## Description
Enable/disable external parties to send eMails to O365 groups.

## Permissions (Notes)
```
Permissions: 
 Office 365 Exchange Online
 - Exchange.ManageAsApp
Azure AD Roles
 - Exchange administrator
Notes: Setting this via graph is currently broken as of 2021-06-28: 
 attribute: allowExternalSenders
 https://docs.microsoft.com/en-us/graph/known-issues#setting-the-allowexternalsenders-property
```

# Group \ Mail \ Show Or Hide In Address Book
## (Un)hide an O365- or static Distribution-group in Address Book.

## Description
(Un)hide an O365- or static Distribution-group in Address Book. Can also show the current state.

## Permissions (Notes)
```
Permissions: 
 Office 365 Exchange Online
 - Exchange.ManageAsApp
 Azure AD Roles
 - Exchange administrator
 Note, as of 2021-06-28 MS Graph does not support updating existing groups - only on initial creation.
  PATCH : https://graph.microsoft.com/v1.0/groups/{id}
  body = { "resourceBehaviorOptions":["HideGroupInOutlook"] }
```

# Group \ Teams \ Archive Team
## Archive a team.

## Description
Decomission an inactive team while preserving its contents for review.

## Permissions (Notes)
```
Permissions: 
MS Graph - Application
- TeamSettings.ReadWrite.All
```

# Internal \ Device \ Assign Group
## Add a device to a group.

## Description
Add a device to a group. Primarily intended for Windows 11 Self Service upgrades.

## Permissions (Notes)
```
Permissions: 
MS Graph (API)
- Group.ReadWrite.All
- Directory.ReadWrite.All

if "UserGroupId"/"AddUserToGroup" is used:
- DeviceManagementManagedDevices.Read.All
```

# Org \ Devices \ Get Bitlocker Recovery Key
## Get BitLocker recovery key

## Description
Get BitLocker recovery key via supplying bitlockeryRecoveryKeyId.

## Permissions (Notes)
```
Permissions (Graph):
- Device.Read.All
- BitlockerKey.Read.All
```

# Org \ Devices \ Outphase Devices
## Remove/Outphase multiple devices

## Description
Remove/Outphase multiple devices. You can choose if you want to wipe the device and/or delete it from Intune an AutoPilot.

## Permissions (Notes)
```
PERMISSIONS
 DeviceManagementManagedDevices.PrivilegedOperations.All (Wipe,Retire / seems to allow us to delete from AzureAD)
 DeviceManagementManagedDevices.ReadWrite.All (Delete Inunte Device)
 DeviceManagementServiceConfig.ReadWrite.All (Delete Autopilot enrollment)
 Device.Read.All
ROLES
 Cloud device administrator
```

# Org \ General \ Add Application Registration
## Add an application registration to Azure AD

## Description
Add an application registration to Azure AD

## Permissions (Notes)
```
Permissions: 
MS Graph (API):
- Application.ReadWrite.All
- RoleManagement.ReadWrite.Directory
```

# Org \ General \ Add Autopilot Device
## Import a windows device into Windows Autopilot.

## Description
Import a windows device into Windows Autopilot.

## Permissions (Notes)
```
Permissions: 
MS Graph (API):
- DeviceManagementServiceConfig.ReadWrite.All
```

# Org \ General \ Add Device Via Corporate Identifier
## Import a device into Intune via corporate identifier.

## Description
Import a device into Intune via corporate identifier.

## Permissions (Notes)
```
Permissions: 
MS Graph (API):
- DeviceManagementServiceConfig.ReadWrite.All
```

# Org \ General \ Add Devices Of Users To Group_Scheduled
## Sync devices of users in a specific group to another device group.

## Description
This runbook reads accounts from a specified Users group and adds their devices to a specified Devices group. It ensures new devices are also added.

## Permissions (Notes)
```
```

# Org \ General \ Add Management Partner
## List or add or Management Partner Links (PAL)

## Description
List or add or Management Partner Links (PAL)

## Permissions (Notes)
```
```

# Org \ General \ Add Microsoft Store App Logos
## Update logos of Microsoft Store Apps (new) in Intune.

## Description
This script updates the logos for Microsoft Store Apps (new) in Intune by fetching them from the Microsoft Store.

## Permissions (Notes)
```
Permissions:
MS Graph (API):
- DeviceManagementApps.ReadWrite.All
```

# Org \ General \ Add Office365 Group
## Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

## Description
Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

## Permissions (Notes)
```
Permissions (according to https://docs.microsoft.com/en-us/graph/api/group-post-groups?view=graph-rest-1.0 )
MS Graph (API): 
- Group.Create 
- Team.Create
```

# Org \ General \ Add Or Remove Safelinks Exclusion
## Add or remove a SafeLinks URL exclusion to/from a given policy.

## Description
Add or remove a SafeLinks URL exclusion to/from a given policy.
It can also be used to initially create a new policy if required.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# Org \ General \ Add Or Remove Smartscreen Exclusion
## Add/Remove a SmartScreen URL Exception/Rule in MS Security Center Indicators

## Description
List/Add/Remove URL indicators entries in MS Security Center.

## Permissions (Notes)
```
Permissions: WindowsDefenderATP:
- Ti.ReadWrite.All
```

# Org \ General \ Add Or Remove Trusted Site
## Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy

## Description
Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy

## Permissions (Notes)
```
Permissions: MS Graph API permissions:
- DeviceManagementConfiguration.ReadWrite.All

This runbook uses calls as described in 
https://call4cloud.nl/2021/09/the-isencrypted-with-steve-zissou/
to decrypt omaSettings. It currently needs to use the MS Graph Beta Endpoint for this. 
Please switch to "v1.0" as soon, as this funtionality is available.
```

# Org \ General \ Add Security Group
## This runbook creates a Microsoft Entra ID security group with membership type "Assigned".

## Description
This runbook creates a Microsoft Entra ID security group with membership type "Assigned".

## Permissions (Notes)
```
Permissions (according to https://docs.microsoft.com/en-us/graph/api/group-post-groups?view=graph-rest-1.0 )
GraphAPI: 
- Group.Create 

AssignableToRoles is currently deactivated, as extended rights are required. 
“RoleManagement.ReadWrite.Directory” permission is required to set the ‘isAssignableToRole’ property or update the membership of such groups. 
Reference is made to this in a comment in the course of the code.
(according to https://learn.microsoft.com/en-us/graph/api/group-post-groups?view=graph-rest-1.0&tabs=http#example-3-create-a-microsoft-365-group-that-can-be-assigned-to-a-microsoft-entra-role)
Also to reactivate this feature, the following extra is in the .INPUTS are required:
"AssignableToRoles": {
    "DisplayName":  "Microsoft Entra roles can be assigned to the group"
},
```

# Org \ General \ Add User
## Create a new user account.

## Description
Create a new user account.

## Permissions (Notes)
```
Permissions
AzureAD Roles
- User administrator
```

# Org \ General \ Add Viva Engange Community
## Creates a Viva Engage (Yammer) community via the Yammer API

## Description
Creates a Viva Engage (Yammer) community using a Yammer dev token. The API-calls used are subject to change, so this script might break in the future.

## Permissions (Notes)
```
```

# Org \ General \ Assign Groups By Template_Scheduled
## Assign cloud-only groups to many users based on a predefined template.

## Description
Assign cloud-only groups to many users based on a predefined template.

## Permissions (Notes)
```
```

# Org \ General \ Bulk Delete Devices From Autopilot
## Mass-Delete Autopilot objects based on Serial Number.

## Description
This runbook deletes Autopilot objects in bulk based on a list of serial numbers.

## Permissions (Notes)
```
Permissions:
MS Graph (API)
- DeviceManagementServiceConfig.ReadWrite.All
```

# Org \ General \ Bulk Retire Devices From Intune
## Bulk retire devices from Intune using serial numbers

## Description
This runbook retires multiple devices from Intune based on a list of serial numbers.

## Permissions (Notes)
```
Permissions:
MS Graph (API):
- DeviceManagementManagedDevices.ReadWrite.All
- Device.Read.All
```

# Org \ General \ Check Aad Sync Status_Scheduled
## Check for last Azure AD Connect Sync Cycle.

## Description
This runbook checks the Azure AD Connect sync status and the last sync date and time.

## Permissions (Notes)
```
Permissions:
MS Graph (API)
- Directory.Read.All
```

# Org \ General \ Check Assignments Of Devices
## Check Intune assignments for a given (or multiple) Device Names.

## Description
This script checks the Intune assignments for a single or multiple specified Device Names.

## Permissions (Notes)
```
Permissions (Graph):
- Device.Read.All
- Group.Read.All
- DeviceManagementConfiguration.Read.All
- DeviceManagementManagedDevices.Read.All
- DeviceManagementApps.Read.All
```

# Org \ General \ Check Assignments Of Groups
## Check Intune assignments for a given (or multiple) Group Names.

## Description
This script checks the Intune assignments for a single or multiple specified Group Names.

## Permissions (Notes)
```
Permissions (Graph):
- User.Read.All
- Group.Read.All
- DeviceManagementConfiguration.Read.All
- DeviceManagementManagedDevices.Read.All
- Device.Read.All
```

# Org \ General \ Check Assignments Of Users
## Check Intune assignments for a given (or multiple) User Principal Names (UPNs).

## Description
This script checks the Intune assignments for a single or multiple specified UPNs.

## Permissions (Notes)
```
Permissions (Graph):
- User.Read.All
- Group.Read.All
- DeviceManagementConfiguration.Read.All
- DeviceManagementManagedDevices.Read.All
- Device.Read.All
```

# Org \ General \ Check Autopilot Serialnumbers
## Check if given serial numbers are present in AutoPilot.

## Description
Check if given serial numbers are present in AutoPilot.

## Permissions (Notes)
```
Permissions (Graph):
- DeviceManagementServiceConfig.Read.All
```

# Org \ General \ Check Device Onboarding Exclusion_Schedule
## Check for Autopilot devices not yet onboarded to Intune. Add these to an exclusion group.

## Description
Check for Autopilot devices not yet onboarded to Intune. Add these to an exclusion group.

## Permissions (Notes)
```
Permissions
 MS Graph (API):
```

# Org \ General \ Enrolled Devices Report_Scheduled
## Show recent first-time device enrollments.

## Description
Show recent first-time device enrollments, grouped by a category/attribute.

## Permissions (Notes)
```
Permissions: 
MS Graph (API):
- DeviceManagementServiceConfig.Read.All
- DeviceManagementManagedDevices.Read.All
- User.Read.All
- Device.ReadWrite.All
Azure Subscription (for Storage Account)
- Contributor on Storage Account
```

# Org \ General \ Export All Autopilot Devices
## List/export all AutoPilot devices.

## Description
List/export all AutoPilot devices.

## Permissions (Notes)
```
Permissions
MS Graph (API):
- DeviceManagementManagedDevices.Read.All
- Directory.Read.All
- Device.Read.All
```

# Org \ General \ Export All Intune Devices
## Export a list of all Intune devices and where they are registered.

## Description
Export all Intune devices and metadata based on their owner, like usageLocation.

## Permissions (Notes)
```
Permissions
 MS Graph (API): 
 - DeviceManagementManagedDevices.Read.All
```

# Org \ General \ Export Cloudpc Usage_Scheduled
## Write daily Windows 365 Utilization Data to Azure Tables

## Description
Write daily Windows 365 Utilization Data to Azure Tables. Will write data about the last full day.

## Permissions (Notes)
```
Permissions: 
MS Graph: CloudPC.Read.All
StorageAccount: Contributor
```

# Org \ General \ Export Non Compliant Devices
## Report on non-compliant devices and policies

## Description
Report on non-compliant devices and policies

## Permissions (Notes)
```
Permissions
MS Graph
- DeviceManagementConfiguration.Read.All
Storage Account (optional)
```

# Org \ General \ Export Policy Report
## Create a report of a tenant's polcies from Intune and AAD and write them to a markdown file.

## Description

## Permissions (Notes)
```
Permissions (Graph):
   - DeviceManagementConfiguration.Read.All
   - Policy.Read.All
Permissions AzureRM:
   - Storage Account Contributor
```

# Org \ General \ List All Administrative Template Policies
## List all Administrative Template policies and their assignments.

## Description
This script retrieves all Administrative Template policies from Intune and displays their assignments.

## Permissions (Notes)
```
Permissions (Graph):
- DeviceManagementConfiguration.Read.All
- Group.Read.All
```

# Org \ General \ List Group License Assignment Errors
## Report groups that have license assignment errors

## Description
Report groups that have license assignment errors

## Permissions (Notes)
```
Permissions (MS Graph, API)
- GroupMember.Read.All
- Group.Read.All
```

# Org \ General \ Office365 License Report
## Generate an Office 365 licensing report.

## Description
Generate an Office 365 licensing report.

## Permissions (Notes)
```
New permission: 
MSGraph 
- Reports.Read.All
```

# Org \ General \ Report Apple Mdm Cert Expiry_Scheduled
## Monitor/Report expiry of Apple device management certificates.

## Description
Monitor/Report expiry of Apple device management certificates.

## Permissions (Notes)
```
Permissions: 
MS Graph (API)
- DeviceManagementManagedDevices.Read.All,
- DeviceManagementServiceConfig.Read.All,
- DeviceManagementConfiguration.Read.All,
- Mail.Send
```

# Org \ General \ Report Pim Activations_Scheduled
## Scheduled Report on PIM Activations.

## Description
This runbook collects and reports PIM activation details, including date, requestor, UPN, role, primary target, PIM group, reason, and status, and sends it via email.

## Permissions (Notes)
```
Permissions:
MS Graph (API)
- AuditLog.Read.All
- Mail.Send
```

# Org \ General \ Sync All Devices
## Sync all Intune devices.

## Description
Sync all Intune devices.

## Permissions (Notes)
```
```

# Org \ Mail \ Add Distribution List
## Create a classic distribution group.

## Description
Create a classic distribution group.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
MS Graph (API):
-Oranization.Read.All
```

# Org \ Mail \ Add Equipment Mailbox
## Create an equipment mailbox.

## Description
Create an equipment mailbox.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# Org \ Mail \ Add Or Remove Public Folder
## Add or remove a public folder.

## Description
Assumes you already have at least on Public Folder Mailbox. It will not provision P.F. Mailboxes.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# Org \ Mail \ Add Or Remove Teams Mailcontact
## Create/Remove a contact, to allow pretty email addresses for Teams channels.

## Description
Create/Remove a contact, to allow pretty email addresses for Teams channels.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# Org \ Mail \ Add Room Mailbox
## Create a room resource.

## Description
Create a room resource.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# Org \ Mail \ Add Shared Mailbox
## Create a shared mailbox.

## Description
Create a shared mailbox.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# Org \ Mail \ Hide Mailboxes_Scheduled
## Hide / Unhide special mailboxes in Global Address Book

## Description
Hide / Unhide special mailboxes in Global Address Book. Currently intended for Booking calendars.

## Permissions (Notes)
```
Permissions
Exchange Administrator access
```

# Set Booking Config
## set-booking-config.ps1 [[-BookingsEnabled] <bool>] [[-BookingsAuthEnabled] <bool>] [[-BookingsSocialSharingRestricted] <bool>] [[-BookingsExposureOfStaffDetailsRestricted] <bool>] [[-BookingsMembershipApprovalRequired] <bool>] [[-BookingsSmsMicrosoftEnabled] <bool>] [[-BookingsSearchEngineIndexDisabled] <bool>] [[-BookingsAddressEntryRestricted] <bool>] [[-BookingsCreationOfCustomQuestionsRestricted] <bool>] [[-BookingsNotesEntryRestricted] <bool>] [[-BookingsPhoneNumberEntryRestricted] <bool>] [[-BookingsNamingPolicyEnabled] <bool>] [[-BookingsBlockedWordsEnabled] <bool>] [[-BookingsNamingPolicyPrefixEnabled] <bool>] [[-BookingsNamingPolicyPrefix] <string>] [[-BookingsNamingPolicySuffixEnabled] <bool>] [[-BookingsNamingPolicySuffix] <string>] [[-CreateOwaPolicy] <bool>] [[-OwaPolicyName] <string>] [-CallerName] <string> [<CommonParameters>]


## Description

## Permissions (Notes)
```
```

# Org \ Phone \ Get Teams Phonenumber Assignment
## Looks up, if the given phone number is assigned to a user in Microsoft Teams.

## Description
This runbook looks up, if the given phone number is assigned to a user in Microsoft Teams. If the phone number is assigned to a user, information about the user will be returned.

## Permissions (Notes)
```
```

# Org \ Security \ Add Defender Indicator
## Create new Indicator in Defender for Endpoint.

## Description
Create a new Indicator in Defender for Endpoint e.g. to allow a specific file using it's hash value or allow a specific url that by default is blocked by Defender for Endpoint

## Permissions (Notes)
```
Permissions (WindowsDefenderATP, Application):
- Ti.ReadWrite.All
```

# Org \ Security \ Backup Conditional Access Policies
## Exports the current set of Conditional Access policies to an Azure storage account.

## Description
Exports the current set of Conditional Access policies to an Azure storage account.

## Permissions (Notes)
```
Permissions
 MS Graph (API): 
 - Policy.Read.All
 Azure IaaS: Access to the given Azure Storage Account / Resource Group
```

# Org \ Security \ Export Enterprise App Users
## Export a CSV of all (entprise) app owners and users

## Description
Export a CSV of all (entprise) app owners and users.

## Permissions (Notes)
```
Permissions: 
MS Graph (API)
- Directory.Read.All
- Application.Read.All
Azure IaaS: "Contributor" access on subscription or resource group used for the export
```

# Org \ Security \ List Admin Users
## List AzureAD role holders and their MFA state.

## Description
Will list users and service principals that hold a builtin AzureAD role. 
Admins will be queried for valid MFA methods.

## Permissions (Notes)
```
Permissions: MS Graph
- User.Read.All
- Directory.Read.All
- RoleManagement.Read.All
```

# Org \ Security \ List Application Creds Expiry
## List expiry date of all AppRegistration credentials

## Description
List expiry date of all AppRegistration credentials

## Permissions (Notes)
```
Permissions: 
 MS Graph - Application Permission
  Application.Read.All
```

# Org \ Security \ List Expiring Role Assignments
## List Azure AD role assignments that will expire before a given number of days.

## Description
List Azure AD role assignments that will expire before a given number of days.

## Permissions (Notes)
```
Permissions: MS Graph
- Organization.Read.All
- RoleManagement.Read.All
```

# Org \ Security \ List Inactive Devices
## List/export inactive evices, which had no recent user logons.

## Description
Collect devices based on the date of last user logon or last Intune sync.

## Permissions (Notes)
```
Permissions
MS Graph (API):
- DeviceManagementManagedDevices.Read.All
- Directory.Read.All
- Device.Read.All
```

# Org \ Security \ List Inactive Enterprise Apps
## List App registrations, which had no recent user logons.

## Description
List App registrations, which had no recent user logons.

## Permissions (Notes)
```
Permissions
MS Graph (API):
- Directory.Read.All
- Device.Read.All
```

# Org \ Security \ List Inactive Users
## List users, that have no recent interactive signins.

## Description
List users, that have no recent interactive signins.

## Permissions (Notes)
```
Permissions: MS Graph
- User.Read.All
- AuditLog.Read.All
- Organization.Read.All
```

# Org \ Security \ List Information Protection Labels
## Prints a list of all available InformationProtectionPolicy labels.

## Description
Prints a list of all available InformationProtectionPolicy labels.

## Permissions (Notes)
```
Permissions MS Graph, at least:
- InformationProtectionPolicy.Read.All
```

# Org \ Security \ List Pim Rolegroups Without Owners_Scheduled
## List role-assignable groups with eligible role assignments but without owners

## Description

## Permissions (Notes)
```
```

# Org \ Security \ List Vulnerable App Regs
## List all app registrations that suffer from the CVE-2021-42306 vulnerability.

## Description
List all app registrations that suffer from the CVE-2021-42306 vulnerability.

## Permissions (Notes)
```
Permissions
 MS Graph (API): 
 - DeviceManagementManagedDevices.Read.All
```

# Org \ Security \ Notify Changed CA Policies
## Exports the current set of Conditional Access policies to an Azure storage account.

## Description
Exports the current set of Conditional Access policies to an Azure storage account.

## Permissions (Notes)
```
Permissions
 MS Graph (API): 
 - Policy.Read.All
 - User.SendMail
```

# User \ General \ Assign Groups By Template
## Assign cloud-only groups to a user based on a predefined template.

## Description
Assign cloud-only groups to a user based on a predefined template.

## Permissions (Notes)
```
```

# User \ General \ Assign Or Unassign License
## (Un-)Assign a license to a user via group membership.

## Description
(Un-)Assign a license to a user via group membership

## Permissions (Notes)
```
Permissions:
MS Graph (API):
- User.Read.All
- GroupMember.ReadWrite.All 
- Group.ReadWrite.All
```

# User \ General \ Assign Windows365
## Assign/Provision a Windows 365 instance

## Description
Assign/Provision a Windows 365 instance for this user.

## Permissions (Notes)
```
Permissions:
MS Graph (API):
- User.Read.All
- GroupMember.ReadWrite.All 
- Group.ReadWrite.All
- User.SendMail
```

# User \ General \ List Group Ownerships
## List group ownerships for this user.

## Description
List group ownerships for this user.

## Permissions (Notes)
```
Permissions
 MS Graph (API): 
 - User.Read.All
 - Group.Read.All
```

# User \ General \ List Manager
## List manager information for this user.

## Description
List manager information for the specified user.

## Permissions (Notes)
```
Permissions
 MS Graph (API): 
 - User.Read.All
```

# User \ General \ Offboard User Permanently
## Permanently offboard a user.

## Description
Permanently offboard a user.

## Permissions (Notes)
```
Permissions
AzureAD Roles
- User administrator
Azure IaaS: "Contributor" access on subscription or resource group used for the export
```

# User \ General \ Offboard User Temporarily
## Temporarily offboard a user.

## Description
Temporarily offboard a user in cases like parental leaves or sabaticals.

## Permissions (Notes)
```
Permissions
AzureAD Roles
- User administrator
Azure IaaS: "Contributor" access on subscription or resource group used for the export
```

# User \ General \ Reprovision Windows365
## Reprovision a Windows 365 Cloud PC

## Description
Reprovision an already existing Windows 365 Cloud PC without reassigning a new instance for this user.

## Permissions (Notes)
```
Permissions:
MS Graph (API):
- GroupMember.ReadWrite.All 
- Group.ReadWrite.All
- Directory.Read.All
- CloudPC.ReadWrite.All (Beta)
- User.Read.All
- User.SendMail
```

# User \ General \ Resize Windows365
## Resize a Windows 365 Cloud PC

## Description
Resize an already existing Windows 365 Cloud PC by derpovisioning and assigning a new differently sized license to the user. Warning: All local data will be lost. Proceed with caution.

## Permissions (Notes)
```
Permissions:
MS Graph (API):
- GroupMember.ReadWrite.All 
- Group.ReadWrite.All
- Directory.Read.All
- CloudPC.ReadWrite.All (Beta)
- User.Read.All
- User.SendMail
```

# User \ General \ Unassign Windows365
## Remove/Deprovision a Windows 365 instance

## Description
Remove/Deprovision a Windows 365 instance

## Permissions (Notes)
```
Permissions:
MS Graph (API):
- User.Read.All
- GroupMember.ReadWrite.All 
- Group.ReadWrite.All
- CloudPC.ReadWrite.All (Beta)
```

# User \ Mail \ Add Or Remove Email Address
## Add/remove eMail address to/from mailbox.

## Description
Add/remove eMail address to/from mailbox, update primary eMail address.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# User \ Mail \ Assign Owa Mailbox Policy
## Assign a given OWA mailbox policy to a user.

## Description
Assign a given OWA mailbox policy to a user. E.g. to allow MS Bookings.

## Permissions (Notes)
```
Permissions
Exchange Administrator access
```

# User \ Mail \ Convert To Shared Mailbox
## Turn this users mailbox into a shared mailbox.

## Description
Turn this users mailbox into a shared mailbox.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# User \ Mail \ Delegate Full Access
## Grant another user full access to this mailbox.

## Description
Grant another user full access to this mailbox.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# User \ Mail \ Delegate Send As
## Grant another user sendAs permissions on this mailbox.

## Description
Grant another user sendAs permissions on this mailbox.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# User \ Mail \ Delegate Send On Behalf
## Grant another user sendOnBehalf permissions on this mailbox.

## Description
Grant another user sendOnBehalf permissions on this mailbox.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# User \ Mail \ Hide Or Unhide In Addressbook
## (Un)Hide this mailbox in address book.

## Description
(Un)Hide this mailbox in address book.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# User \ Mail \ List Mailbox Permissions
## List permissions on a (shared) mailbox.

## Description
List permissions on a (shared) mailbox.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# User \ Mail \ List Room Mailbox Configuration
## List Room configuration.

## Description
List Room configuration.

## Permissions (Notes)
```
Permissions
MS Graph (API):
- Place.Read.All
```

# User \ Mail \ Remove Mailbox
## Hard delete a shared mailbox, room or bookings calendar.

## Description
Hard delete a shared mailbox, room or bookings calendar.

## Permissions (Notes)
```
Permissions
Exchange Administrator access
```

# User \ Mail \ Set Out Of Office
## En-/Disable Out-of-office-notifications for a user/mailbox.

## Description
En-/Disable Out-of-office-notifications for a user/mailbox.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# User \ Mail \ Set Room Mailbox Configuration
## Set room resource policies.

## Description
Set room resource policies.

## Permissions (Notes)
```
Permissions given to the Az Automation RunAs Account:
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# User \ Phone \ Disable Teams Phone
## Microsoft Teams telephony offboarding

## Description
Remove the phone number and specific policies from a teams-enabled user.

## Permissions (Notes)
```
Permissions: 
The connection of the Microsoft Teams PowerShell module is ideally done through the Managed Identity of the Automation account of RealmJoin.
If this has not yet been set up and the old "Service User" is still stored, the connect is still included for stability reasons. 
However, it should be switched to Managed Identity as soon as possible!
```

# User \ Phone \ Get Teams User Info
## Get the status quo of a Microsoft Teams user in terms of phone number, if any, and certain Microsoft Teams policies.

## Description
Get the status quo of a Microsoft Teams user in terms of phone number, if any, and certain Microsoft Teams policies.

## Permissions (Notes)
```
Permissions: 
The connection of the Microsoft Teams PowerShell module is ideally done through the Managed Identity of the Automation account of RealmJoin.
If this has not yet been set up and the old "Service User" is still stored, the connect is still included for stability reasons. 
However, it should be switched to Managed Identity as soon as possible!
```

# User \ Phone \ Grant Teams User Policies
## Grant specific Microsoft Teams policies to a Microsoft Teams enabled user.

## Description
Grant specific Microsoft Teams policies to a Microsoft Teams enabled user. 
If the policy name of a policy is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

## Permissions (Notes)
```
Permissions: 
The connection of the Microsoft Teams PowerShell module is ideally done through the Managed Identity of the Automation account of RealmJoin.
If this has not yet been set up and the old "Service User" is still stored, the connect is still included for stability reasons. 
However, it should be switched to Managed Identity as soon as possible!
```

# User \ Phone \ Set Teams Permanent Call Forwarding
## Set up immediate call forwarding for a Microsoft Teams Enterprise Voice user.

## Description
Set up instant call forwarding for a Microsoft Teams Enterprise Voice user. Forwarding to another Microsoft Teams Enterprise Voice user or to an external phone number.

## Permissions (Notes)
```
Permissions: 
The connection of the Microsoft Teams PowerShell module is ideally done through the Managed Identity of the Automation account of RealmJoin.
If this has not yet been set up and the old "Service User" is still stored, the connect is still included for stability reasons. 
However, it should be switched to Managed Identity as soon as possible!
```

# User \ Phone \ Set Teams Phone
## Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies.

## Description
Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies.
If the policy name of a policy is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered.

## Permissions (Notes)
```
Permissions: 
The connection of the Microsoft Teams PowerShell module is ideally done through the Managed Identity of the Automation account of RealmJoin.
If this has not yet been set up and the old "Service User" is still stored, the connect is still included for stability reasons. 
However, it should be switched to Managed Identity as soon as possible!
```

# User \ Security \ Confirm Or Dismiss Risky User
## Confirm compromise / Dismiss a "risky user"

## Description
Confirm compromise / Dismiss a "risky user"

## Permissions (Notes)
```
Permissions needed:
- IdentityRiskyUser.ReadWrite.All
```

# User \ Security \ Create Temporary Access Pass
## Create an AAD temporary access pass for a user.

## Description
Create an AAD temporary access pass for a user.

## Permissions (Notes)
```
Permissions needed:
- UserAuthenticationMethod.ReadWrite.All
```

# User \ Security \ Enable Or Disable Password Expiration
## Set a users password policy to "(Do not) Expire"

## Description
Set a users password policy to "(Do not) Expire"

## Permissions (Notes)
```
Permissions needed:
 MS Graph (API Permissions):
 - User.ReadWrite.All
```

# User \ Security \ Reset Mfa
## Remove all App- and Mobilephone auth methods for a user.

## Description
Remove all App- and Mobilephone auth methods for a user. User can re-enroll MFA.

## Permissions (Notes)
```
Permissions needed:
- UserAuthenticationMethod.ReadWrite.All
```

# User \ Security \ Reset Password
## Reset a user's password.

## Description
Reset a user's password. The user will have to change it on signin. Does not work with PW writeback to onprem AD.

## Permissions (Notes)
```
Permissions:
- AzureAD Role: User administrator
```

# User \ Security \ Revoke Or Restore Access
## Revoke user access and all active tokens or re-enable user.

## Description
Revoke user access and all active tokens or re-enable user.

## Permissions (Notes)
```
Permissions:
MS Graph (API)
- User.ReadWrite.All, Directory.ReadWrite.All,
AzureAD Roles
- User Administrator
```

# User \ Security \ Set Or Remove Mobile Phone Mfa
## Add, update or remove a user's mobile phone MFA information.

## Description
Add, update or remove a user's mobile phone MFA information.

## Permissions (Notes)
```
Permissions needed:
- UserAuthenticationMethod.ReadWrite.All
```

# User \ Userinfo \ Rename User
## Rename a user or mailbox. Will not update metadata like DisplayName, GivenName, Surname.

## Description
Rename a user or mailbox. Will not update metadata like DisplayName, GivenName, Surname.

## Permissions (Notes)
```
Permissions: 
MS Graph API
- Directory.Read.All
- User.ReadWrite.All
AzureAD Roles:
- Exchange administrator
Office 365 Exchange Online API
- Exchange.ManageAsApp
```

# User \ Userinfo \ Set Photo
## Set / update the photo / avatar picture of a user.

## Description
Set / update the photo / avatar picture of a user.

## Permissions (Notes)
```
Permissions:
- MS Graph (API): User.ReadWrite.All
```

# User \ Userinfo \ Update User
## Update/Finalize an existing user object.

## Description
Update the metadata, group memberships and Exchange settings of an existing user object.

## Permissions (Notes)
```
Permissions
Graph
- UserAuthenticationMethod.Read.All
AzureAD Roles
- User administrator
Exchange
- Exchange Admin
```


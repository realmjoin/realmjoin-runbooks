<a name='runbook-parameter-overview'></a>
# Overview
This document provides a comprehensive overview of all parameters used in the runbooks available in the RealmJoin portal. Each parameter is listed with its type and whether it is required or optional.

To ensure easy navigation, the runbooks are categorized into different sections based on their area of application. The following categories are currently available:
- device
- group
- org
- user

Each category contains multiple runbooks that are further divided into subcategories based on their functionality. For runbooks with multiple parameters, each parameter is listed in a separate row. The runbook name and synopsis are only shown once per runbook to improve readability.

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
- [Organization](#organization)
  - [Applications](#organization-applications)
    - Add Application Registration
    - Delete Application Registration
    - Export Enterprise Application Users
    - List Inactive Enterprise Applications
    - Report Application Registration
    - Report Expiring Application Credentials_Scheduled
    - Update Application Registration
  - [Devices](#organization-devices)
    - Add Autopilot Device
    - Add Device Via Corporate Identifier
    - Delete Stale Devices_Scheduled
    - Get Bitlocker Recovery Key
    - Outphase Devices
    - Report Devices Without Primary User
    - Report Last Device Contact By Range
    - Report Stale Devices_Scheduled
    - Report Users With More Than 5-Devices
    - Sync Device Serialnumbers To Entraid_Scheduled
  - [General](#organization-general)
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
    - Check AAD Sync Status_Scheduled
    - Check Assignments Of Devices
    - Check Assignments Of Groups
    - Check Assignments Of Users
    - Check Autopilot Serialnumbers
    - Check Device Onboarding Exclusion_Scheduled
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
    - Report Apple MDM Cert Expiry_Scheduled
    - Report License Assignment_Scheduled
    - Report PIM Activations_Scheduled
    - Sync All Devices
  - [Mail](#organization-mail)
    - Add Distribution List
    - Add Equipment Mailbox
    - Add Or Remove Public Folder
    - Add Or Remove Teams Mailcontact
    - Add Or Remove Tenant Allow Block List
    - Add Room Mailbox
    - Add Shared Mailbox
    - Hide Mailboxes_Scheduled
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
    - List PIM Rolegroups Without Owners_Scheduled
    - List Users By MFA Methods Count
    - List Vulnerable App Regs
    - Notify Changed CA Policies
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

### Restart Host
Reboots a specific AVD Session Host.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceName | ✓ | String |  |
| SubscriptionIds | ✓ | String Array |  |
| CallerName | ✓ | String |  |

### Toggle Drain Mode
Sets Drainmode on true or false for a specific AVD Session Host.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceName | ✓ | String |  |
| DrainMode | ✓ | Boolean |  |
| SubscriptionIds | ✓ | String Array |  |
| CallerName | ✓ | String |  |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='device-general'></a>
## General

### Change Grouptag
Assign a new AutoPilot GroupTag to this device.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String |  |
| newGroupTag |  | String |  |
| CallerName | ✓ | String |  |

### Check Updatable Assets
Check if a device is onboarded to Windows Update for Business.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| DeviceId | ✓ | String | DeviceId of the device to check onboarding status for. |

### Enroll Updatable Assets
Enroll device into Windows Update for Business.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| DeviceId | ✓ | String | DeviceId of the device to unenroll. |
| UpdateCategory | ✓ | String | Category of updates to enroll into. Possible values are: driver, feature or quality. |

### Outphase Device
Remove/Outphase a windows device

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String |  |
| intuneAction |  | Int32 |  |
| aadAction |  | Int32 |  |
| wipeDevice |  | Boolean |  |
| removeIntuneDevice |  | Boolean |  |
| removeAutopilotDevice |  | Boolean |  |
| removeAADDevice |  | Boolean |  |
| disableAADDevice |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Remove Primary User
Removes the primary user from a device.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String | The unique identifier of the device from which the primary user will be removed.
It will be prefilled from the RealmJoin Portal and is hidden in the UI. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Rename Device
Rename a device.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String |  |
| NewDeviceName | ✓ | String |  |
| CallerName | ✓ | String |  |

### Unenroll Updatable Assets
Unenroll device from Windows Update for Business.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| DeviceId | ✓ | String | DeviceId of the device to unenroll. |
| UpdateCategory | ✓ | String | Category of updates to unenroll from. Possible values are: driver, feature, quality or all (delete). |

### Wipe Device
Wipe a Windows or MacOS device

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String |  |
| wipeDevice |  | Boolean |  |
| useProtectedWipe |  | Boolean |  |
| removeIntuneDevice |  | Boolean |  |
| removeAutopilotDevice |  | Boolean |  |
| removeAADDevice |  | Boolean |  |
| disableAADDevice |  | Boolean |  |
| macOsRecevoryCode |  | String | Only for old MacOS devices. Newer devices can be wiped without a recovery code. |
| macOsObliterationBehavior |  | String | "default": Use EACS to wipe user data, reatining the OS. Will wipe the OS, if EACS fails. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='device-security'></a>
## Security

### Enable Or Disable Device
Disable a device in AzureAD.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String |  |
| Enable |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Isolate Or Release Device
Isolate this device.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String |  |
| Release | ✓ | Boolean |  |
| IsolationType |  | String |  |
| Comment | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Reset Mobile Device Pin
Reset a mobile device's password/PIN code.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String |  |
| CallerName | ✓ | String |  |

### Restrict Or Release Code Execution
Restrict code execution.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String |  |
| Release | ✓ | Boolean |  |
| Comment | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Show LAPS Password
Show a local admin password for a device.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceId | ✓ | String |  |
| CallerName | ✓ | String |  |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='group'></a>
# Group
<a name='group-devices'></a>
## Devices

### Check Updatable Assets
Check if devices in a group are onboarded to Windows Update for Business.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| GroupId | ✓ | String | Object ID of the group to check onboarding status for its members. |

### Unenroll Updatable Assets
Unenroll devices from Windows Update for Business.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| GroupId | ✓ | String | Object ID of the group to unenroll its members. |
| UpdateCategory | ✓ | String | Category of updates to unenroll from. Possible values are: driver, feature, quality or all (delete). |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='group-general'></a>
## General

### Add Or Remove Nested Group
Add/remove a nested group to/from a group.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String |  |
| NestedGroupID | ✓ | String |  |
| Remove |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Or Remove Owner
Add/remove owners to/from an Office 365 group.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String |  |
| UserId | ✓ | String |  |
| Remove |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Or Remove User
Add/remove users to/from a group.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String |  |
| UserId | ✓ | String |  |
| Remove |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Change Visibility
Change a group's visibility

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String |  |
| Public |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### List All Members
Retrieves the members of a specified EntraID group, including members from nested groups.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupId | ✓ | String | The ObjectId of the EntraID group whose membership is to be retrieved. |
| CallerName |  | String | The name of the caller, used for auditing purposes. |

### List Owners
List all owners of an Office 365 group.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### List User Devices
List all devices owned by group members.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String |  |
| moveGroup |  | Boolean |  |
| targetgroup |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Remove Group
Removes a group, incl. SharePoint site and Teams team.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupId | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Rename Group
Rename a group.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupId | ✓ | String |  |
| DisplayName |  | String |  |
| MailNickname |  | String |  |
| Description |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='group-mail'></a>
## Mail

### Enable Or Disable External Mail
Enable/disable external parties to send eMails to O365 groups.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupId | ✓ | String |  |
| Action |  | Int32 |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Show Or Hide In Address Book
(Un)hide an O365- or static Distribution-group in Address Book.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupName | ✓ | String |  |
| Action |  | Int32 |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='group-teams'></a>
## Teams

### Archive Team
Archive a team.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupID | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='organization'></a>
# Organization
<a name='organization-applications'></a>
## Applications

### Add Application Registration
Add an application registration to Azure AD

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ApplicationName | ✓ | String | The display name of the application registration to create. |
| RedirectURI |  | String | Used for UI selection only. Determines which redirect URI type to configure (None, Web, SAML, Public Client, or SPA). |
| signInAudience |  | String | Specifies who can use the application. Default is "AzureADMyOrg" (single tenant). Hidden in UI. |
| webRedirectURI |  | String | Redirect URI(s) for web applications. Supports multiple URIs separated by semicolons (e.g., "https://app1.com/auth;https://app2.com/auth"). |
| spaRedirectURI |  | String | Redirect URI(s) for single-page applications (SPA). Supports multiple URIs separated by semicolons. |
| publicClientRedirectURI |  | String | Redirect URI(s) for public client/native applications (mobile & desktop). Supports multiple URIs separated by semicolons (e.g., "myapp://auth"). |
| EnableSAML |  | Boolean | Enable SAML-based authentication for the application. When enabled, SAML-specific parameters are required. |
| SAMLReplyURL |  | String | The reply URL for SAML authentication. Required when EnableSAML is true. |
| SAMLSignOnURL |  | String | The sign-on URL for SAML authentication. |
| SAMLLogoutURL |  | String | The logout URL for SAML authentication. |
| SAMLIdentifier |  | String | The SAML identifier (Entity ID). If not specified, defaults to "urn:app:{AppId}". |
| SAMLRelayState |  | String | The SAML relay state parameter for maintaining application state during authentication. |
| SAMLExpiryNotificationEmail |  | String | Email address to receive notifications when the SAML token signing certificate is about to expire. |
| SAMLCertificateLifeYears |  | Int32 | Lifetime of the SAML token signing certificate in years. Default is 3 years. |
| isApplicationVisible |  | Boolean | Determines whether the application is visible in the My Apps portal. Default is true. |
| UserAssignmentRequired |  | Boolean | Determines whether users must be assigned to the application before accessing it. When enabled, an EntraID group is created for user assignment. Default is false. |
| groupAssignmentPrefix |  | String | Prefix for the automatically created EntraID group when UserAssignmentRequired is enabled. Default is "col - Entra - users - ". |
| implicitGrantAccessTokens |  | Boolean | Enable implicit grant flow for access tokens. Default is false. |
| implicitGrantIDTokens |  | Boolean | Enable implicit grant flow for ID tokens. Default is false. |
| CallerName | ✓ | String | The name of the user executing the runbook. Used for auditing purposes. |

### Delete Application Registration
Delete an application registration from Azure AD

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ClientId | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Export Enterprise Application Users
Export a CSV of all (enterprise) application owners and users

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| entAppsOnly |  | Boolean |  |
| ContainerName |  | String |  |
| ResourceGroupName |  | String |  |
| StorageAccountName |  | String |  |
| StorageAccountLocation |  | String |  |
| StorageAccountSku |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### List Inactive Enterprise Applications
List application registrations, which had no recent user logons.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Days |  | Int32 |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Report Application Registration
Generate and email a comprehensive Application Registration report

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| EmailTo | ✓ | String | Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons. |
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization |
| IncludeDeletedApps |  | Boolean | Whether to include deleted application registrations in the report (default: true) |
| CallerName | ✓ | String | Internal parameter for tracking purposes |

### Report Expiring Application Credentials_Scheduled
List expiry date of all Application Registration credentials

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| listOnlyExpiring |  | Boolean | If set to true, only credentials that are about to expire within the specified number of days will be listed.
If set to false, all credentials will be listed regardless of their expiry date. |
| Days |  | Int32 | The number of days before a credential expires to consider it "about to expire". |
| CredentialType |  | String | Filter by credential type: "Both" (default), "ClientSecrets", or "Certificates". |
| ApplicationIds |  | String | Optional - comma-separated list of Application IDs to filter the credentials. |
| EmailTo | ✓ | String | If specified, an email with the report will be sent to the provided address(es).
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons. |
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Update Application Registration
Update an application registration in Azure AD

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ClientId | ✓ | String |  |
| RedirectURI |  | String |  |
| webRedirectURI |  | String | Only for UI used |
| publicClientRedirectURI |  | String |  |
| spaRedirectURI |  | String |  |
| EnableSAML |  | Boolean |  |
| SAMLReplyURL |  | String |  |
| SAMLSignOnURL |  | String |  |
| SAMLLogoutURL |  | String |  |
| SAMLIdentifier |  | String |  |
| SAMLRelayState |  | String |  |
| SAMLExpiryNotificationEmail |  | String |  |
| isApplicationVisible |  | Boolean |  |
| UserAssignmentRequired |  | Boolean |  |
| groupAssignmentPrefix |  | String |  |
| implicitGrantAccessTokens |  | Boolean |  |
| implicitGrantIDTokens |  | Boolean |  |
| disableImplicitGrant |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='organization-devices'></a>
## Devices

### Add Autopilot Device
Import a windows device into Windows Autopilot.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| SerialNumber | ✓ | String |  |
| HardwareIdentifier | ✓ | String |  |
| AssignedUser |  | String | MS removed the ability to assign users directly via Autopilot |
| Wait |  | Boolean |  |
| GroupTag |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Device Via Corporate Identifier
Import a device into Intune via corporate identifier.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CorpIdentifierType | ✓ | String |  |
| CorpIdentifier | ✓ | String |  |
| DeviceDescripton |  | String |  |
| OverwriteExistingEntry |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Delete Stale Devices_Scheduled
Scheduled deletion of stale devices based on last activity date and platform.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Days |  | Int32 | Number of days without activity to be considered stale. |
| Windows |  | Boolean | Include Windows devices in the results. |
| MacOS |  | Boolean | Include macOS devices in the results. |
| iOS |  | Boolean | Include iOS devices in the results. |
| Android |  | Boolean | Include Android devices in the results. |
| DeleteDevices |  | Boolean | If set to true, the script will delete the stale devices. If false, it will only report them. |
| ConfirmDeletion |  | Boolean | If set to true, the script will prompt for confirmation before deleting devices.
Should be set to false for scheduled runs. |
| sendAlertTo |  | String | Email address to send the report to. |
| sendAlertFrom |  | String | Email address to send the report from. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

### Get Bitlocker Recovery Key
Get BitLocker recovery key

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| bitlockeryRecoveryKeyId | ✓ | String | bitlockeryRecoveryKeyId of the desired recovery key. Displayed in the BitLocker recovery screen (format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX). |

### Outphase Devices
Remove/Outphase multiple devices

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| DeviceListChoice | ✓ | Int32 |  |
| DeviceList | ✓ | String |  |
| intuneAction |  | Int32 |  |
| aadAction |  | Int32 |  |
| wipeDevice |  | Boolean |  |
| removeIntuneDevice |  | Boolean |  |
| removeAutopilotDevice |  | Boolean |  |
| removeAADDevice |  | Boolean |  |
| disableAADDevice |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Report Devices Without Primary User
Reports all managed devices in Intune that do not have a primary user assigned.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization. |
| EmailTo |  | String | If specified, an email with the report will be sent to the provided address(es).
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons. |
| CallerName | ✓ | String | Internal parameter for tracking purposes |

### Report Last Device Contact By Range
Reports devices with last contact within a specified date range.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| dateRange | ✓ | String | Date range for filtering devices based on their last contact time. |
| systemType | ✓ | String | The operating system type of the devices to filter. |
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization |
| EmailTo |  | String | If specified, an email with the report will be sent to the provided address(es).
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons. |
| CallerName | ✓ | String | Internal parameter for tracking purposes |

### Report Stale Devices_Scheduled
Scheduled report of stale devices based on last activity date and platform.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Days |  | Int32 | Number of days without activity to be considered stale. |
| Windows |  | Boolean | Include Windows devices in the results. |
| MacOS |  | Boolean | Include macOS devices in the results. |
| iOS |  | Boolean | Include iOS devices in the results. |
| Android |  | Boolean | Include Android devices in the results. |
| EmailTo | ✓ | String | Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons. |
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization |
| CallerName | ✓ | String | Caller name for auditing purposes. |

### Report Users With More Than 5-Devices
Reports users with more than five registered devices in Entra ID.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization. |
| EmailTo |  | String | If specified, an email with the report will be sent to the provided address(es).
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons. |
| CallerName | ✓ | String | Internal parameter for tracking purposes |

### Sync Device Serialnumbers To Entraid_Scheduled
Syncs serial numbers from Intune devices to Azure AD device extension attributes.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ExtensionAttributeNumber |  | Int32 |  |
| ProcessAllDevices |  | Boolean | If true, processes all devices. If false, only processes devices with missing or mismatched serial numbers in AAD. |
| MaxDevicesToProcess |  | Int32 | Maximum number of devices to process in a single run. Use 0 for unlimited. |
| sendReportTo |  | String | Email address to send the report to. If empty, no email will be sent. |
| sendReportFrom |  | String | Email address to send the report from. |
| CallerName | ✓ | String | Caller name for auditing purposes. |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='organization-general'></a>
## General

### Add Devices Of Users To Group_Scheduled
Sync devices of users in a specific group to another device group.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserGroup | ✓ | String |  |
| DeviceGroup | ✓ | String |  |
| CallerName | ✓ | String |  |
| IncludeWindowsDevice |  | Boolean |  |
| IncludeMacOSDevice |  | Boolean |  |
| IncludeLinuxDevice |  | Boolean |  |
| IncludeAndroidDevice |  | Boolean |  |
| IncludeIOSDevice |  | Boolean |  |
| IncludeIPadOSDevice |  | Boolean |  |

### Add Management Partner
List or add or Management Partner Links (PAL)

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Action | ✓ | Int32 |  |
| PartnerId |  | Int32 |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Microsoft Store App Logos
Update logos of Microsoft Store Apps (new) in Intune.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Office365 Group
Create an Office 365 group and SharePoint site, optionally create a (Teams) team.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| MailNickname | ✓ | String |  |
| DisplayName |  | String |  |
| CreateTeam |  | Boolean |  |
| Private |  | Boolean |  |
| MailEnabled |  | Boolean |  |
| SecurityEnabled |  | Boolean |  |
| Owner |  | String |  |
| Owner2 |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Or Remove Safelinks Exclusion
Add or remove a SafeLinks URL exclusion to/from a given policy.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Action |  | Int32 |  |
| LinkPattern |  | String | URL to allow, can contain '*' as wildcard for host and paths |
| DefaultPolicyName | ✓ | String | If only one policy exists, no need to specify. Will use "DefaultPolicyName" as default otherwise. |
| PolicyName |  | String | Optional, will overwrite default values |
| CreateNewPolicyIfNeeded |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Or Remove Smartscreen Exclusion
Add/Remove a SmartScreen URL Exception/Rule in MS Security Center Indicators

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| action |  | Int32 | 0 - list, 1 - add, 2 - remove |
| Url |  | String | please give just the name of the domain, like "exclusiondemo.com" |
| mode |  | Int32 | 0 - allow, 1 - audit, 2 - warn, 3 - block |
| explanationTitle |  | String |  |
| explanationDescription |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Or Remove Trusted Site
Add/Remove an entry to/from the Intune Windows 10 Trusted Sites Policy

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Action | ✓ | Int32 |  |
| Url |  | String | Needs to be prefixed with "http://" or "https://" |
| Zone |  | Int32 |  |
| DefaultPolicyName |  | String |  |
| IntunePolicyName |  | String | Will use an existing policy or default policy name if left empty. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Security Group
This runbook creates a Microsoft Entra ID security group with membership type "Assigned".

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GroupName | ✓ | String | The name of the security group. |
| GroupDescription |  | String | The description of the security group. |
| Owner |  | String | The owner of the security group. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add User
Create a new user account.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| GivenName | ✓ | String |  |
| Surname | ✓ | String |  |
| UserPrincipalName |  | String |  |
| MailNickname |  | String |  |
| DisplayName |  | String |  |
| CompanyName |  | String |  |
| JobTitle |  | String |  |
| Department |  | String |  |
| ManagerId |  | String |  |
| MobilePhone |  | String |  |
| LocationName |  | String |  |
| StreetAddress |  | String |  |
| PostalCode |  | String |  |
| City |  | String |  |
| State |  | String |  |
| Country |  | String |  |
| UsageLocation |  | String |  |
| DefaultLicense |  | String |  |
| DefaultGroups |  | String | Comma separated list of groups to assign. e.g. "DL Sales,LIC Internal Product" |
| InitialPassword |  | String | Password will be autogenerated if left empty |
| EnableEXOArchive |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Viva Engange Community
Creates a Viva Engage (Yammer) community via the Yammer API

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CommunityName | ✓ | String | The name of the community to create. max 264 chars. |
| CommunityPrivate |  | Boolean |  |
| CommunityShowInDirectory |  | Boolean |  |
| CommunityOwners |  | String | The owners of the community. Comma seperated list of UPNs. |
| removeCreatorFromGroup |  | Boolean |  |
| CallerName | ✓ | String |  |

### Assign Groups By Template_Scheduled
Assign cloud-only groups to many users based on a predefined template.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| SourceGroupId | ✓ | String |  |
| ExclusionGroupId |  | String |  |
| GroupsTemplate |  | String | GroupsTemplate is not used directly, but is used to populate the GroupsString parameter via RJ Portal Customization |
| GroupsString | ✓ | String |  |
| UseDisplaynames |  | Boolean | $UseDisplayname = $false: GroupsString contains Group object ids, $true: GroupsString contains Group displayNames |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Bulk Delete Devices From Autopilot
Mass-Delete Autopilot objects based on Serial Number.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| SerialNumbers | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Bulk Retire Devices From Intune
Bulk retire devices from Intune using serial numbers

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| SerialNumbers | ✓ | String |  |
| CallerName | ✓ | String |  |

### Check AAD Sync Status_Scheduled
Check for last Azure AD Connect Sync Cycle.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |
| sendAlertTo |  | String |  |
| sendAlertFrom |  | String |  |

### Check Assignments Of Devices
Check Intune assignments for a given (or multiple) Device Names.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| DeviceNames | ✓ | String | Device Names of the devices to check assignments for, separated by commas. |
| IncludeApps |  | Boolean | Boolean to specify whether to include application assignments in the search. |

### Check Assignments Of Groups
Check Intune assignments for a given (or multiple) Group Names.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| GroupNames | ✓ | String | Group Names of the groups to check assignments for, separated by commas. |
| IncludeApps |  | Boolean | Boolean to specify whether to include application assignments in the search. |

### Check Assignments Of Users
Check Intune assignments for a given (or multiple) User Principal Names (UPNs).

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |
| UPN | ✓ | String | User Principal Names of the users to check assignments for, separated by commas. |
| IncludeApps |  | Boolean | Boolean to specify whether to include application assignments in the search. |

### Check Autopilot Serialnumbers
Check if given serial numbers are present in AutoPilot.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| SerialNumbers | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Check Device Onboarding Exclusion_Scheduled
Check for Autopilot devices not yet onboarded to Intune. Add these to an exclusion group.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| exclusionGroupName |  | String | EntraID exclusion group for Defender Compliance. |
| maxAgeInDays |  | Int32 |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Enrolled Devices Report_Scheduled
Show recent first-time device enrollments.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Weeks |  | Int32 |  |
| dataSource |  | Int32 | Where to look for a devices "birthday"?
0 - AutoPilot profile assignment date
1 - Intune object creation date |
| groupingSource |  | Int32 | How to group results?
0 - no grouping
1 - AzureAD User properties
2 - AzureAD Device properties
3 - Intune device properties
4 - AutoPilot properties |
| groupingAttribute |  | String | Examples:

Autopilot:
- "groupTag"
- "systemFamily"
- "skuNumber"

AzureAD User:
- "city"
- "companyName"
- "department"
- "officeLocation"
- "preferredLanguage"
- "state"
- "usageLocation"
- "manager"?

AzureAD Device:
- "manufacturer"
- "model"

Intune Device:
- "isEncrypted" |
| exportCsv |  | Boolean | Please configure an Azure Storage Account to use this feature. |
| ContainerName |  | String |  |
| ResourceGroupName |  | String |  |
| StorageAccountName |  | String |  |
| StorageAccountLocation |  | String |  |
| StorageAccountSku |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Export All Autopilot Devices
List/export all AutoPilot devices.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ExportToFile |  | Boolean |  |
| ContainerName |  | String |  |
| ResourceGroupName |  | String |  |
| StorageAccountName |  | String |  |
| StorageAccountLocation |  | String |  |
| StorageAccountSku |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Export All Intune Devices
Export a list of all Intune devices and where they are registered.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ContainerName |  | String |  |
| ResourceGroupName |  | String |  |
| StorageAccountName |  | String |  |
| StorageAccountLocation |  | String |  |
| StorageAccountSku |  | String |  |
| SubscriptionId |  | String |  |
| CallerName | ✓ | String |  |

### Export Cloudpc Usage_Scheduled
Write daily Windows 365 Utilization Data to Azure Tables

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Table |  | String | CallerName is tracked purely for auditing purposes |
| ResourceGroupName | ✓ | String |  |
| StorageAccountName | ✓ | String |  |
| days |  | Int32 |  |
| CallerName | ✓ | String |  |

### Export Non Compliant Devices
Report on non-compliant devices and policies

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| produceLinks |  | Boolean |  |
| ContainerName |  | String |  |
| ResourceGroupName |  | String |  |
| StorageAccountName |  | String |  |
| StorageAccountLocation |  | String |  |
| StorageAccountSku |  | String |  |
| SubscriptionId |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Export Policy Report
Create a report of a tenant's polcies from Intune and AAD and write them to a markdown file.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| produceLinks |  | Boolean |  |
| exportJson |  | Boolean |  |
| renderLatexPagebreaks |  | Boolean |  |
| ContainerName |  | String |  |
| ResourceGroupName |  | String |  |
| StorageAccountName |  | String |  |
| StorageAccountLocation |  | String |  |
| StorageAccountSku |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Invite External Guest Users
Invites external guest users to the organization using Microsoft Graph.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| InvitedUserEmail | ✓ | String | The email address of the guest user to invite. |
| InvitedUserDisplayName | ✓ | String | The display name for the guest user. |
| GroupId |  | String | The object ID of the group to add the guest user to.
If not specified, the user will not be added to any group. |

### List All Administrative Template Policies
List all Administrative Template policies and their assignments.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Caller name for auditing purposes. |

### List Group License Assignment Errors
Report groups that have license assignment errors

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Office365 License Report
Generate an Office 365 licensing report.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| printOverview |  | Boolean |  |
| includeExhange |  | Boolean |  |
| exportToFile |  | Boolean |  |
| exportAsZip |  | Boolean |  |
| produceLinks |  | Boolean |  |
| ContainerName |  | String | Make a persistent container the default, so you can simply update PowerBI's report from the same source |
| ResourceGroupName |  | String |  |
| StorageAccountName |  | String |  |
| StorageAccountLocation |  | String |  |
| StorageAccountSku |  | String |  |
| SubscriptionId |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Report Apple MDM Cert Expiry_Scheduled
Monitor/Report expiry of Apple device management certificates.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | Internal parameter for tracking purposes |
| Days |  | Int32 | The warning threshold in days. Certificates and tokens expiring within this many days will be
flagged as alerts in the report. Default is 300 days (approximately 10 months). |
| EmailTo |  | String | Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons. |
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization |

### Report License Assignment_Scheduled
Generate and email a license availability report based on configured thresholds

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| InputJson | ✓ | Object | JSON array containing SKU configurations with thresholds. Each entry should include:
- SKUPartNumber: The Microsoft SKU identifier
- FriendlyName: Display name for the license
- MinThreshold: (Optional) Minimum number of licenses that should be available
- MaxThreshold: (Optional) Maximum number of licenses that should be available

This needs to be configured in the runbook customization |
| EmailTo | ✓ | String | Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons. |
| EmailFrom |  | String | The sender email address. This needs to be configured in the runbook customization |
| CallerName | ✓ | String | Internal parameter for tracking purposes |

### Report PIM Activations_Scheduled
Scheduled Report on PIM Activations.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |
| sendAlertTo |  | String |  |
| sendAlertFrom |  | String |  |

### Sync All Devices
Sync all Intune devices.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='organization-mail'></a>
## Mail

### Add Distribution List
Create a classic distribution group.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Alias | ✓ | String |  |
| PrimarySMTPAddress |  | String |  |
| GroupName |  | String |  |
| Owner |  | String |  |
| Roomlist |  | Boolean |  |
| AllowExternalSenders |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Equipment Mailbox
Create an equipment mailbox.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| MailboxName | ✓ | String |  |
| DisplayName |  | String |  |
| DelegateTo |  | String |  |
| AutoAccept |  | Boolean |  |
| AutoMapping |  | Boolean |  |
| DisableUser |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Or Remove Public Folder
Add or remove a public folder.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| PublicFolderName | ✓ | String |  |
| MailboxName |  | String |  |
| AddPublicFolder | ✓ | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Or Remove Teams Mailcontact
Create/Remove a contact, to allow pretty email addresses for Teams channels.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| RealAddress | ✓ | String | Enter the address created by MS Teams for a channel |
| DesiredAddress | ✓ | String | Will forward/relay to the real address. |
| DisplayName |  | String |  |
| Remove |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Or Remove Tenant Allow Block List
Add or remove entries from the Tenant Allow/Block List.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Entry | ✓ | String | The entry to add or remove (e.g., domain, email address, URL, or file hash). |
| ListType |  | String | The type of entry: Sender, Url, or FileHash. |
| Block |  | Boolean | Decides whether to block or allow the entry. |
| Remove |  | Boolean | Decides whether to remove or add the entry. |
| DaysToExpire |  | Int32 | Number of days until the entry expires. Default is 30 days. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Add Room Mailbox
Create a room resource.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| MailboxName | ✓ | String |  |
| DisplayName |  | String |  |
| DelegateTo |  | String |  |
| Capacity |  | Int32 |  |
| AutoAccept |  | Boolean |  |
| AutoMapping |  | Boolean |  |
| DisableUser |  | Boolean | CallerName is tracked purely for auditing purposes |
| CallerName | ✓ | String |  |

### Add Shared Mailbox
Create a shared mailbox.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| MailboxName | ✓ | String | The alias (mailbox name) for the shared mailbox. |
| DisplayName |  | String | The display name for the shared mailbox. |
| DomainName |  | String | The domain name to be used for the primary SMTP address of the shared mailbox. If not specified, the default domain will be used. |
| Language |  | String | The language/locale for the shared mailbox. This setting affects folder names like "Inbox". Default is "en-US". |
| DelegateTo |  | String | The user to delegate access to the shared mailbox. |
| AutoMapping |  | Boolean | If set to true, the shared mailbox will be automatically mapped in Outlook for the delegate user. |
| MessageCopyForSentAsEnabled |  | Boolean | If set to true, a copy of sent emails will be saved in the shared mailbox's Sent Items folder when sent as the shared mailbox. |
| MessageCopyForSendOnBehalfEnabled |  | Boolean | If set to true, a copy of sent emails will be saved in the shared mailbox's Sent Items folder when sent on behalf of the shared mailbox. |
| DisableUser |  | Boolean | If set to true, the associated EntraID user account will be disabled. |
| CallerName | ✓ | String | The name of the caller executing this script. This parameter is used for auditing purposes. |

### Hide Mailboxes_Scheduled
Hide / Unhide special mailboxes in Global Address Book

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| HideBookingCalendars | ✓ | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Set Booking Config
Configure Microsoft Bookings settings for the organization.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| BookingsEnabled |  | Boolean |  |
| BookingsAuthEnabled |  | Boolean |  |
| BookingsSocialSharingRestricted |  | Boolean |  |
| BookingsExposureOfStaffDetailsRestricted |  | Boolean |  |
| BookingsMembershipApprovalRequired |  | Boolean |  |
| BookingsSmsMicrosoftEnabled |  | Boolean |  |
| BookingsSearchEngineIndexDisabled |  | Boolean |  |
| BookingsAddressEntryRestricted |  | Boolean |  |
| BookingsCreationOfCustomQuestionsRestricted |  | Boolean |  |
| BookingsNotesEntryRestricted |  | Boolean |  |
| BookingsPhoneNumberEntryRestricted |  | Boolean |  |
| BookingsNamingPolicyEnabled |  | Boolean |  |
| BookingsBlockedWordsEnabled |  | Boolean |  |
| BookingsNamingPolicyPrefixEnabled |  | Boolean |  |
| BookingsNamingPolicyPrefix |  | String |  |
| BookingsNamingPolicySuffixEnabled |  | Boolean |  |
| BookingsNamingPolicySuffix |  | String |  |
| CreateOwaPolicy |  | Boolean |  |
| OwaPolicyName |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='organization-phone'></a>
## Phone

### Get Teams Phone Number Assignment
Looks up, if the given phone number is assigned to a user in Microsoft Teams.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| PhoneNumber | ✓ | String | The phone number must be in E.164 format. Example: +49321987654 or +49321987654;ext=123. It must start with a '+' followed by the country code and subscriber number, with an optional ';ext=' followed by the extension number, without spaces or special characters. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='organization-security'></a>
## Security

### Add Defender Indicator
Create new Indicator in Defender for Endpoint.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| IndicatorValue | ✓ | String |  |
| IndicatorType | ✓ | String |  |
| Title | ✓ | String |  |
| Description | ✓ | String |  |
| Action | ✓ | String |  |
| Severity | ✓ | String |  |
| GenerateAlert | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Backup Conditional Access Policies
Exports the current set of Conditional Access policies to an Azure storage account.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ContainerName |  | String | Will be autogenerated if left empty |
| ResourceGroupName |  | String |  |
| StorageAccountName |  | String |  |
| StorageAccountLocation |  | String |  |
| StorageAccountSku |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### List Admin Users
List AzureAD role holders and their MFA state.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| exportToFile |  | Boolean |  |
| ContainerName |  | String |  |
| ResourceGroupName |  | String |  |
| StorageAccountName |  | String |  |
| StorageAccountLocation |  | String |  |
| StorageAccountSku |  | String |  |
| QueryMfaState |  | Boolean |  |
| TrustEmailMfa |  | Boolean |  |
| TrustPhoneMfa |  | Boolean |  |
| TrustSoftwareOathMfa |  | Boolean |  |
| TrustWinHelloMFA |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### List Expiring Role Assignments
List Azure AD role assignments that will expire before a given number of days.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Days |  | Int32 |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### List Inactive Devices
List/export inactive devices, which had no recent user logons.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Days |  | Int32 |  |
| Sync |  | Boolean |  |
| ExportToFile |  | Boolean |  |
| ContainerName |  | String |  |
| ResourceGroupName |  | String |  |
| StorageAccountName |  | String |  |
| StorageAccountLocation |  | String |  |
| StorageAccountSku |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### List Inactive Users
List users, that have no recent interactive signins.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| Days |  | Int32 | Number of days without interactive signin. |
| showBlockedUsers |  | Boolean | Include users/guests that can not sign in (accountEnabled = false). |
| showUsersThatNeverLoggedIn |  | Boolean | Beware: This has to enumerate all users / Can take a long time. |
| CallerName | ✓ | String | Name of the caller (tracked for auditing purposes). |

### List Information Protection Labels
Prints a list of all available InformationProtectionPolicy labels.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### List PIM Rolegroups Without Owners_Scheduled
List role-assignable groups with eligible role assignments but without owners

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| sendEmailIfFound |  | Boolean |  |
| From |  | String |  |
| To |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### List Users By MFA Methods Count
Reports users by the count of their registered MFA methods.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| mfaMethodsRange | ✓ | String | Range for filtering users based on the count of their registered MFA methods. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### List Vulnerable App Regs
List all app registrations that suffer from the CVE-2021-42306 vulnerability.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| ExportToFile |  | Boolean |  |
| ContainerName |  | String |  |
| ResourceGroupName |  | String |  |
| StorageAccountName |  | String |  |
| StorageAccountLocation |  | String |  |
| StorageAccountSku |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Notify Changed CA Policies
Exports the current set of Conditional Access policies to an Azure storage account.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| From | ✓ | String |  |
| To | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='user'></a>
# User
<a name='user-avd'></a>
## AVD

### User Signout
Removes (Signs Out) a specific User from their AVD Session.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| SubscriptionIds | ✓ | String Array |  |
| CallerName | ✓ | String |  |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='user-general'></a>
## General

### Assign Groups By Template
Assign cloud-only groups to a user based on a predefined template.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserId | ✓ | String |  |
| GroupsTemplate |  | String | GroupsTemplate is not used directly, but is used to populate the GroupsString parameter via RJ Portal Customization |
| GroupsString | ✓ | String |  |
| UseDisplaynames |  | Boolean | $UseDisplayname = $false: GroupsString contains Group object ids, $true: GroupsString contains Group displayNames |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Assign Or Unassign License
(Un-)Assign a license to a user via group membership.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| GroupID_License | ✓ | String | production does not supprt "ref:LicenseGroup" yet |
| Remove |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Assign Windows365
Assign/Provision a Windows 365 instance

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| cfgProvisioningGroupName |  | String |  |
| cfgUserSettingsGroupName |  | String |  |
| licWin365GroupName |  | String |  |
| cfgProvisioningGroupPrefix |  | String |  |
| cfgUserSettingsGroupPrefix |  | String |  |
| sendMailWhenProvisioned |  | Boolean |  |
| customizeMail |  | Boolean |  |
| customMailMessage |  | String |  |
| createTicketOutOfLicenses |  | Boolean |  |
| ticketQueueAddress |  | String |  |
| fromMailAddress |  | String |  |
| ticketCustomerId |  | String |  |
| CallerName | ✓ | String |  |

### List Group Memberships
List group memberships for this user.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| GroupType |  | String | Filter by group type: Security (security permissions only), M365 (Microsoft 365 groups with mailbox), or All (default). |
| MembershipType |  | String | Filter by membership type: Assigned (manually added members), Dynamic (rule-based membership), or All (default). |
| RoleAssignable |  | String | Filter groups that can be assigned to Azure AD roles: Yes (role-assignable only) or NotSet (all groups, default). |
| TeamsEnabled |  | String | Filter groups with Microsoft Teams functionality: Yes (Teams-enabled only) or NotSet (all groups, default). |
| Source |  | String | Filter by group origin: Cloud (Azure AD only), OnPrem (synchronized from on-premises AD), or All (default). |
| WritebackEnabled |  | String | Filter groups with writeback to on-premises AD enabled: Yes (writeback enabled), No (writeback disabled), or All (default). |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### List Group Ownerships
List group ownerships for this user.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### List Manager
List manager information for this user.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Offboard User Permanently
Permanently offboard a user.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| DeleteUser |  | Boolean |  |
| DisableUser |  | Boolean |  |
| RevokeAccess |  | Boolean |  |
| exportResourceGroupName |  | String |  |
| exportStorAccountName |  | String |  |
| exportStorAccountLocation |  | String |  |
| exportStorAccountSKU |  | String |  |
| exportStorContainerGroupMembershipExports |  | String |  |
| exportGroupMemberships |  | Boolean |  |
| ChangeLicensesSelector |  | Int32 |  |
| ChangeGroupsSelector |  | Int32 | "Change" and "Remove all" will both honour "groupToAdd" |
| GroupToAdd |  | String |  |
| GroupsToRemovePrefix |  | String |  |
| RevokeGroupOwnership |  | Boolean |  |
| ManagerAsReplacementOwner |  | Boolean |  |
| ReplacementOwnerName |  | String | Who will take over group ownership if the offboarded user is the last remaining group owner? Will only be used if needed. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Offboard User Temporarily
Temporarily offboard a user.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| RevokeAccess |  | Boolean |  |
| DisableUser |  | Boolean |  |
| exportResourceGroupName |  | String |  |
| exportStorAccountName |  | String |  |
| exportStorAccountLocation |  | String |  |
| exportStorAccountSKU |  | String |  |
| exportStorContainerGroupMembershipExports |  | String |  |
| exportGroupMemberships |  | Boolean |  |
| ChangeLicensesSelector |  | Int32 |  |
| ChangeGroupsSelector |  | Int32 | "Change" and "Remove all" will both honour "groupToAdd" |
| GroupToAdd |  | String |  |
| GroupsToRemovePrefix |  | String |  |
| RevokeGroupOwnership |  | Boolean |  |
| ReplacementOwnerName |  | String | Who will take over group ownership if the offboarded user is the last remaining group owner? Will only be used if needed. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Reprovision Windows365
Reprovision a Windows 365 Cloud PC

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| licWin365GroupName | ✓ | String |  |
| sendMailWhenReprovisioning |  | Boolean |  |
| fromMailAddress |  | String |  |
| customizeMail |  | Boolean |  |
| customMailMessage |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Resize Windows365
Resize a Windows 365 Cloud PC

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| currentLicWin365GroupName | ✓ | String |  |
| newLicWin365GroupName | ✓ | String |  |
| sendMailWhenDoneResizing |  | Boolean |  |
| fromMailAddress |  | String |  |
| customizeMail |  | Boolean |  |
| customMailMessage |  | String |  |
| cfgProvisioningGroupPrefix |  | String |  |
| cfgUserSettingsGroupPrefix |  | String |  |
| unassignRunbook |  | String |  |
| assignRunbook |  | String |  |
| skipGracePeriod |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Unassign Windows365
Remove/Deprovision a Windows 365 instance

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| licWin365GroupName |  | String |  |
| cfgProvisioningGroupPrefix |  | String |  |
| cfgUserSettingsGroupPrefix |  | String |  |
| licWin365GroupPrefix |  | String |  |
| skipGracePeriod |  | Boolean |  |
| KeepUserSettingsAndProvisioningGroups |  | Boolean |  |
| CallerName | ✓ | String |  |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='user-mail'></a>
## Mail

### Add Or Remove Email Address
Add/remove eMail address to/from mailbox.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| eMailAddress | ✓ | String |  |
| Remove |  | Boolean |  |
| asPrimary |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Assign OWA Mailbox Policy
Assign a given OWA mailbox policy to a user.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| OwaPolicyName | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Convert To Shared Mailbox
Turn this users mailbox into a shared mailbox.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| delegateTo |  | String |  |
| Remove |  | Boolean |  |
| AutoMapping |  | Boolean |  |
| RemoveGroups |  | Boolean |  |
| ArchivalLicenseGroup |  | String |  |
| RegularLicenseGroup |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Delegate Full Access
Grant another user full access to this mailbox.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| delegateTo | ✓ | String |  |
| Remove |  | Boolean |  |
| AutoMapping |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Delegate Send As
Grant another user sendAs permissions on this mailbox.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| delegateTo | ✓ | String |  |
| Remove |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Delegate Send On Behalf
Grant another user sendOnBehalf permissions on this mailbox.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| delegateTo | ✓ | String |  |
| Remove |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Hide Or Unhide In Addressbook
(Un)Hide this mailbox in address book.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| HideMailbox |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### List Mailbox Permissions
List permissions on a (shared) mailbox.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| CallerName | ✓ | String |  |

### List Room Mailbox Configuration
List Room configuration.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Remove Mailbox
Hard delete a shared mailbox, room or bookings calendar.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Set Out Of Office
En-/Disable Out-of-office-notifications for a user/mailbox.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| Disable |  | Boolean |  |
| Start |  | DateTime |  |
| End |  | DateTime | 10 years into the future ("forever") if left empty |
| MessageInternal |  | String |  |
| MessageExternal |  | String |  |
| CreateEvent |  | Boolean |  |
| EventSubject |  | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Set Room Mailbox Configuration
Set room resource policies.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| AllBookInPolicy |  | Boolean |  |
| BookInPolicyGroup |  | String |  |
| AllowRecurringMeetings |  | Boolean |  |
| AutomateProcessing |  | String |  |
| BookingWindowInDays |  | Int32 |  |
| MaximumDurationInMinutes |  | Int32 |  |
| AllowConflicts |  | Boolean |  |
| Capacity |  | Int32 |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='user-phone'></a>
## Phone

### Disable Teams Phone
Microsoft Teams telephony offboarding

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User which should be cleared. Could be filled with the user picker in the UI. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Get Teams User Info
Get the status quo of a Microsoft Teams user in terms of phone number, if any, and certain Microsoft Teams policies.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | The user for whom the status quo should be retrieved. This can be filled in with the user picker in the UI. |
| CallerName |  | String | CallerName is tracked purely for auditing purposes |

### Grant Teams User Policies
Grant specific Microsoft Teams policies to a Microsoft Teams enabled user.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User which should be granted the policies. Could be filled with the user picker in the UI. |
| OnlineVoiceRoutingPolicy |  | String | Microsoft Teams Online Voice Routing Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TenantDialPlan |  | String | Microsoft Teams Tenant Dial Plan Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TeamsCallingPolicy |  | String | Microsoft Teams Calling Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TeamsIPPhonePolicy |  | String | Microsoft Teams IP-Phone Policy Name (a.o. for Common Area Phone Users). If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| OnlineVoicemailPolicy |  | String | Microsoft Teams Online Voicemail Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TeamsMeetingPolicy |  | String | Microsoft Teams Meeting Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TeamsMeetingBroadcastPolicy |  | String | Microsoft Teams Meeting Broadcast Policy Name (Live Event Policy). If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Set Teams Permanent Call Forwarding
Set up immediate call forwarding for a Microsoft Teams Enterprise Voice user.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User which should be set up. Could be filled with the user picker in the UI. |
| ForwardTargetPhoneNumber |  | String | Phone number to which calls should be forwarded. Must be in E.164 format (e.g. +49123456789). |
| ForwardTargetTeamsUser |  | String | Teams user to which calls should be forwarded. Could be filled with the user picker in the UI. |
| ForwardToVoicemail |  | Boolean | Forward calls to voicemail. |
| ForwardToDelegates |  | Boolean | Forward calls to delegates which are defined by the user. |
| TurnOffForward |  | Boolean | Turn off immediate call forwarding. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Set Teams Phone
Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String | User which should be assigned. Could be filled with the user picker in the UI. |
| PhoneNumber | ✓ | String | Phone number which should be assigned to the user. The number must be in E.164 format (e.g. +49123456789). |
| OnlineVoiceRoutingPolicy |  | String | Microsoft Teams Online Voice Routing Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TenantDialPlan |  | String | Microsoft Teams DialPlan Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TeamsCallingPolicy |  | String | Microsoft Teams Calling Policy Name. If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| TeamsIPPhonePolicy |  | String | Microsoft Teams IP Phone Policy Name (a.o. for Common Area Phone Users). If the policy name is left blank, the corresponding policy will not be changed. To clear the policies assignment, the value "Global (Org Wide Default)" has to be entered. |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='user-security'></a>
## Security

### Confirm Or Dismiss Risky User
Confirm compromise / Dismiss a "risky user"

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| Dismiss |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Create Temporary Access Pass
Create an AAD temporary access pass for a user.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| LifetimeInMinutes |  | Int32 | Time the pass will stay valid in minutes |
| OneTimeUseOnly |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Enable Or Disable Password Expiration
Set a users password policy to "(Do not) Expire"

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| DisablePasswordExpiration |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Reset MFA
Remove all App- and Mobilephone auth methods for a user.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Reset Password
Reset a user's password.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| EnableUserIfNeeded |  | Boolean |  |
| ForceChangePasswordNextSignIn |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Revoke Or Restore Access
Revoke user access and all active tokens or re-enable user.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| Revoke |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Set Or Remove Mobile Phone MFA
Add, update or remove a user's mobile phone MFA information.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| phoneNumber | ✓ | String | Enter the user's mobile number in international format (e.g. +491701234567) to add, update, or remove. |
| Remove |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)

<a name='user-userinfo'></a>
## Userinfo

### Rename User
Rename a user or mailbox. Will not update metadata like DisplayName, GivenName, Surname.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| NewUpn | ✓ | String |  |
| ChangeMailnickname |  | Boolean |  |
| UpdatePrimaryAddress |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes
Currently, removing the old eMail-address "in one go" seems not to work reliably
[bool] $RemoveOldAddress = $false |

### Set Photo
Set / update the photo / avatar picture of a user.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| PhotoURI | ✓ | String | Needs to be a JPEG |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

### Update User
Update/Finalize an existing user object.

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| UserName | ✓ | String |  |
| GivenName |  | String |  |
| Surname |  | String |  |
| DisplayName |  | String |  |
| CompanyName |  | String |  |
| City |  | String |  |
| Country |  | String |  |
| JobTitle |  | String |  |
| Department |  | String |  |
| OfficeLocation |  | String | think "physicalDeliveryOfficeName" if you are coming from on-prem |
| PostalCode |  | String |  |
| PreferredLanguage |  | String | Examples: 'en-US' or 'de-DE' |
| State |  | String |  |
| StreetAddress |  | String |  |
| UsageLocation |  | String | Examples: "DE" or "US" |
| DefaultLicense |  | String |  |
| DefaultGroups |  | String |  |
| EnableEXOArchive |  | Boolean |  |
| ResetPassword |  | Boolean |  |
| CallerName | ✓ | String | CallerName is tracked purely for auditing purposes |

[Back to the RealmJoin runbook parameter overview](#table-of-contents)


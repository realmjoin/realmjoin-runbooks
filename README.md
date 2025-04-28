# RealmJoin runbook repository
This repository contains all runbooks for the RealmJoin portal. The runbooks are organized into different folders based on their area of application.
The following categories are currently available:
- device
- group
- org
- user

Each category contains multiple runbooks that are further divided into subcategories based on their functionality. The runbooks are listed in alphabetical order within each subcategory.
<a name='runbook-overview'></a>
# RealmJoin runbook overview
In the following, each runbook is listed along with a brief description or synopsis to give a clear understanding of its purpose and functionality.
Also the document for each runbook contains information about permissions, where to find, notes, and parameters and further information in general.


## Additional information
Apart from the following runbook descriptions, further content such as runbook overview lists or permission summaries can be found here:
- [List based content](docs/lists)
- [JSON based content](docs/other/json)
- [Other content](docs/other)

## Table of contents

- [Device](docs/device/README.md)
  - [General](docs/device/README.md#device-general)

    - [Change Grouptag](docs/device/general/change-grouptag.md)
    - [Check Updatable Assets](docs/device/general/check-updatable-assets.md)
    - [Enroll Updatable Assets](docs/device/general/enroll-updatable-assets.md)
    - [Outphase Device](docs/device/general/outphase-device.md)
    - [Rename Device](docs/device/general/rename-device.md)
    - [Unenroll Updatable Assets](docs/device/general/unenroll-updatable-assets.md)
    - [Wipe Device](docs/device/general/wipe-device.md)
  - [Security](docs/device/README.md#device-security)

    - [Enable Or Disable Device](docs/device/security/enable-or-disable-device.md)
    - [Isolate Or Release Device](docs/device/security/isolate-or-release-device.md)
    - [Reset Mobile Device Pin](docs/device/security/reset-mobile-device-pin.md)
    - [Restrict Or Release Code Execution](docs/device/security/restrict-or-release-code-execution.md)
    - [Show Laps Password](docs/device/security/show-laps-password.md)
- [Group](docs/group/README.md)
  - [Devices](docs/group/README.md#group-devices)

    - [Check Updatable Assets](docs/group/devices/check-updatable-assets.md)
    - [Unenroll Updatable Assets](docs/group/devices/unenroll-updatable-assets.md)
  - [General](docs/group/README.md#group-general)

    - [Add Or Remove Nested Group](docs/group/general/add-or-remove-nested-group.md)
    - [Add Or Remove Owner](docs/group/general/add-or-remove-owner.md)
    - [Add Or Remove User](docs/group/general/add-or-remove-user.md)
    - [Change Visibility](docs/group/general/change-visibility.md)
    - [List All Members](docs/group/general/list-all-members.md)
    - [List Owners](docs/group/general/list-owners.md)
    - [List User Devices](docs/group/general/list-user-devices.md)
    - [Remove Group](docs/group/general/remove-group.md)
    - [Rename Group](docs/group/general/rename-group.md)
  - [Mail](docs/group/README.md#group-mail)

    - [Enable Or Disable External Mail](docs/group/mail/enable-or-disable-external-mail.md)
    - [Show Or Hide In Address Book](docs/group/mail/show-or-hide-in-address-book.md)
  - [Teams](docs/group/README.md#group-teams)

    - [Archive Team](docs/group/teams/archive-team.md)
- [Org](docs/org/README.md)
  - [Devices](docs/org/README.md#org-devices)

    - [Get Bitlocker Recovery Key](docs/org/devices/get-bitlocker-recovery-key.md)
    - [Outphase Devices](docs/org/devices/outphase-devices.md)
  - [General](docs/org/README.md#org-general)

    - [Add Application Registration](docs/org/general/add-application-registration.md)
    - [Add Autopilot Device](docs/org/general/add-autopilot-device.md)
    - [Add Device Via Corporate Identifier](docs/org/general/add-device-via-corporate-identifier.md)
    - [Add Devices Of Users To Group_Scheduled](docs/org/general/add-devices-of-users-to-group_scheduled.md)
    - [Add Management Partner](docs/org/general/add-management-partner.md)
    - [Add Microsoft Store App Logos](docs/org/general/add-microsoft-store-app-logos.md)
    - [Add Office365 Group](docs/org/general/add-office365-group.md)
    - [Add Or Remove Safelinks Exclusion](docs/org/general/add-or-remove-safelinks-exclusion.md)
    - [Add Or Remove Smartscreen Exclusion](docs/org/general/add-or-remove-smartscreen-exclusion.md)
    - [Add Or Remove Trusted Site](docs/org/general/add-or-remove-trusted-site.md)
    - [Add Security Group](docs/org/general/add-security-group.md)
    - [Add User](docs/org/general/add-user.md)
    - [Add Viva Engange Community](docs/org/general/add-viva-engange-community.md)
    - [Assign Groups By Template_Scheduled](docs/org/general/assign-groups-by-template_scheduled.md)
    - [Bulk Delete Devices From Autopilot](docs/org/general/bulk-delete-devices-from-autopilot.md)
    - [Bulk Retire Devices From Intune](docs/org/general/bulk-retire-devices-from-intune.md)
    - [Check Aad Sync Status_Scheduled](docs/org/general/check-aad-sync-status_scheduled.md)
    - [Check Assignments Of Devices](docs/org/general/check-assignments-of-devices.md)
    - [Check Assignments Of Groups](docs/org/general/check-assignments-of-groups.md)
    - [Check Assignments Of Users](docs/org/general/check-assignments-of-users.md)
    - [Check Autopilot Serialnumbers](docs/org/general/check-autopilot-serialnumbers.md)
    - [Check Device Onboarding Exclusion_Schedule](docs/org/general/check-device-onboarding-exclusion_schedule.md)
    - [Enrolled Devices Report_Scheduled](docs/org/general/enrolled-devices-report_scheduled.md)
    - [Export All Autopilot Devices](docs/org/general/export-all-autopilot-devices.md)
    - [Export All Intune Devices](docs/org/general/export-all-intune-devices.md)
    - [Export Cloudpc Usage_Scheduled](docs/org/general/export-cloudpc-usage_scheduled.md)
    - [Export Non Compliant Devices](docs/org/general/export-non-compliant-devices.md)
    - [Export Policy Report](docs/org/general/export-policy-report.md)
    - [List All Administrative Template Policies](docs/org/general/list-all-administrative-template-policies.md)
    - [List Group License Assignment Errors](docs/org/general/list-group-license-assignment-errors.md)
    - [Office365 License Report](docs/org/general/office365-license-report.md)
    - [Report Apple Mdm Cert Expiry_Scheduled](docs/org/general/report-apple-mdm-cert-expiry_scheduled.md)
    - [Report Pim Activations_Scheduled](docs/org/general/report-pim-activations_scheduled.md)
    - [Sync All Devices](docs/org/general/sync-all-devices.md)
  - [Mail](docs/org/README.md#org-mail)

    - [Add Distribution List](docs/org/mail/add-distribution-list.md)
    - [Add Equipment Mailbox](docs/org/mail/add-equipment-mailbox.md)
    - [Add Or Remove Public Folder](docs/org/mail/add-or-remove-public-folder.md)
    - [Add Or Remove Teams Mailcontact](docs/org/mail/add-or-remove-teams-mailcontact.md)
    - [Add Room Mailbox](docs/org/mail/add-room-mailbox.md)
    - [Add Shared Mailbox](docs/org/mail/add-shared-mailbox.md)
    - [Hide Mailboxes_Scheduled](docs/org/mail/hide-mailboxes_scheduled.md)
    - [Set Booking Config](docs/org/mail/set-booking-config.md)
  - [Phone](docs/org/README.md#org-phone)

    - [Get Teams Phone Number Assignment](docs/org/phone/get-teams-phone-number-assignment.md)
  - [Security](docs/org/README.md#org-security)

    - [Add Defender Indicator](docs/org/security/add-defender-indicator.md)
    - [Backup Conditional Access Policies](docs/org/security/backup-conditional-access-policies.md)
    - [Export Enterprise App Users](docs/org/security/export-enterprise-app-users.md)
    - [List Admin Users](docs/org/security/list-admin-users.md)
    - [List Application Creds Expiry](docs/org/security/list-application-creds-expiry.md)
    - [List Expiring Role Assignments](docs/org/security/list-expiring-role-assignments.md)
    - [List Inactive Devices](docs/org/security/list-inactive-devices.md)
    - [List Inactive Enterprise Apps](docs/org/security/list-inactive-enterprise-apps.md)
    - [List Inactive Users](docs/org/security/list-inactive-users.md)
    - [List Information Protection Labels](docs/org/security/list-information-protection-labels.md)
    - [List Pim Rolegroups Without Owners_Scheduled](docs/org/security/list-pim-rolegroups-without-owners_scheduled.md)
    - [List Vulnerable App Regs](docs/org/security/list-vulnerable-app-regs.md)
    - [Notify Changed CA Policies](docs/org/security/notify-changed-ca-policies.md)
- [User](docs/user/README.md)
  - [General](docs/user/README.md#user-general)

    - [Assign Groups By Template](docs/user/general/assign-groups-by-template.md)
    - [Assign Or Unassign License](docs/user/general/assign-or-unassign-license.md)
    - [Assign Windows365](docs/user/general/assign-windows365.md)
    - [List Group Ownerships](docs/user/general/list-group-ownerships.md)
    - [List Manager](docs/user/general/list-manager.md)
    - [Offboard User Permanently](docs/user/general/offboard-user-permanently.md)
    - [Offboard User Temporarily](docs/user/general/offboard-user-temporarily.md)
    - [Reprovision Windows365](docs/user/general/reprovision-windows365.md)
    - [Resize Windows365](docs/user/general/resize-windows365.md)
    - [Unassign Windows365](docs/user/general/unassign-windows365.md)
  - [Mail](docs/user/README.md#user-mail)

    - [Add Or Remove Email Address](docs/user/mail/add-or-remove-email-address.md)
    - [Assign Owa Mailbox Policy](docs/user/mail/assign-owa-mailbox-policy.md)
    - [Convert To Shared Mailbox](docs/user/mail/convert-to-shared-mailbox.md)
    - [Delegate Full Access](docs/user/mail/delegate-full-access.md)
    - [Delegate Send As](docs/user/mail/delegate-send-as.md)
    - [Delegate Send On Behalf](docs/user/mail/delegate-send-on-behalf.md)
    - [Hide Or Unhide In Addressbook](docs/user/mail/hide-or-unhide-in-addressbook.md)
    - [List Mailbox Permissions](docs/user/mail/list-mailbox-permissions.md)
    - [List Room Mailbox Configuration](docs/user/mail/list-room-mailbox-configuration.md)
    - [Remove Mailbox](docs/user/mail/remove-mailbox.md)
    - [Set Out Of Office](docs/user/mail/set-out-of-office.md)
    - [Set Room Mailbox Configuration](docs/user/mail/set-room-mailbox-configuration.md)
  - [Phone](docs/user/README.md#user-phone)

    - [Disable Teams Phone](docs/user/phone/disable-teams-phone.md)
    - [Get Teams User Info](docs/user/phone/get-teams-user-info.md)
    - [Grant Teams User Policies](docs/user/phone/grant-teams-user-policies.md)
    - [Set Teams Permanent Call Forwarding](docs/user/phone/set-teams-permanent-call-forwarding.md)
    - [Set Teams Phone](docs/user/phone/set-teams-phone.md)
  - [Security](docs/user/README.md#user-security)

    - [Confirm Or Dismiss Risky User](docs/user/security/confirm-or-dismiss-risky-user.md)
    - [Create Temporary Access Pass](docs/user/security/create-temporary-access-pass.md)
    - [Enable Or Disable Password Expiration](docs/user/security/enable-or-disable-password-expiration.md)
    - [Reset Mfa](docs/user/security/reset-mfa.md)
    - [Reset Password](docs/user/security/reset-password.md)
    - [Revoke Or Restore Access](docs/user/security/revoke-or-restore-access.md)
    - [Set Or Remove Mobile Phone Mfa](docs/user/security/set-or-remove-mobile-phone-mfa.md)
  - [Userinfo](docs/user/README.md#user-userinfo)

    - [Rename User](docs/user/userinfo/rename-user.md)
    - [Set Photo](docs/user/userinfo/set-photo.md)
    - [Update User](docs/user/userinfo/update-user.md)

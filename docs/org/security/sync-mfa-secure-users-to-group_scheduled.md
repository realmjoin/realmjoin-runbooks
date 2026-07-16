# Sync MFA Secure Users To Group (Scheduled)

Sync users with secure MFA methods registered into an Entra ID group

## Detailed description
This runbook synchronizes an Entra ID group with all member users that have at least one "secure" authentication method registered, based on the Entra ID authentication methods registration report. Which method groups count as secure is configurable via toggles (Passkeys/FIDO2, platform credentials, Microsoft Authenticator app, software OTP, hardware OTP, certificate-based authentication). Users that no longer have a secure method registered are removed from the group. An optional strict mode ("SecureOnly") additionally disqualifies users that have any unsecure method (phone, email, security questions) registered alongside their secure method. Guest users and non-user group members are never touched.

Optionally, a detailed report can be sent via email and/or uploaded to an Azure Storage Account (returning time-limited download links). The report contains CSV files and a formatted Excel workbook with an info cover sheet (chosen parameters and result counts), the performed changes and a per-user evaluation of all member users. Report files are only generated when email or download link is enabled.

## Where to find
Org \ Security \ Sync MFA Secure Users To Group_Scheduled

## How it works

The runbook reads the Entra ID [authentication methods registration report](https://learn.microsoft.com/en-us/graph/api/authenticationmethodsroot-list-userregistrationdetails) (`userRegistrationDetails`) and mirrors the target group against all **member users** that qualify:

- A user qualifies when at least one of their registered methods is in the configured **secure** set.
- In **strict mode** (`SecureOnly`), a user additionally must not have any method from the **unsecure** set registered — a passkey user who also keeps an SMS factor does not qualify.
- Qualifying users that are not yet group members are added; members that no longer qualify are removed (mirror sync).
- Guest users are never added or removed. Non-user group members (devices, service principals, nested groups) are never touched.

The target group should be managed exclusively by this runbook.

## Secure method groups

Each toggle controls which `methodsRegistered` values count as secure:

| Toggle | Default | Covered values |
| --- | --- | --- |
| Passkeys / FIDO2 security keys | on | `fido2SecurityKey`, `passKeyDeviceBound`, `passKeyDeviceBoundAuthenticator` |
| Platform credentials | on | `windowsHelloForBusiness`, `passKeyDeviceBoundWindowsHello`, `macOsSecureEnclaveKey` |
| Microsoft Authenticator app | on | `microsoftAuthenticatorPush`, `microsoftAuthenticatorPasswordless` |
| Software OTP | off | `softwareOneTimePasscode` |
| Hardware OTP | off | `hardwareOneTimePasscode` |
| Certificate-based authentication | on | `certificateBasedAuthentication` |

## Strict mode (SecureOnly)

With strict mode enabled, users with any of the following built-in unsecure methods never qualify:

`mobilePhone`, `alternateMobilePhone`, `officePhone`, `email`, `securityQuestion`

If a method ends up in both the secure and the unsecure set (only possible via the override parameters), unsecure wins — such users never qualify in strict mode. The runbook warns about this at startup.

## Method classification reference

Use the exact Graph values from this table when building the comma-separated override strings:

| `methodsRegistered` value | Friendly name | Classification | Covered by toggle (default) |
| --- | --- | --- | --- |
| `fido2SecurityKey` | FIDO2 security key | Secure | Passkeys / FIDO2 (on) |
| `passKeyDeviceBound` | Passkey (device-bound) | Secure | Passkeys / FIDO2 (on) |
| `passKeyDeviceBoundAuthenticator` | Passkey in Microsoft Authenticator | Secure | Passkeys / FIDO2 (on) |
| `windowsHelloForBusiness` | Windows Hello for Business | Secure | Platform credentials (on) |
| `passKeyDeviceBoundWindowsHello` | Passkey in Windows Hello | Secure | Platform credentials (on) |
| `macOsSecureEnclaveKey` | Platform Credential for macOS | Secure | Platform credentials (on) |
| `microsoftAuthenticatorPush` | Microsoft Authenticator (push notification) | Secure | Microsoft Authenticator app (on) |
| `microsoftAuthenticatorPasswordless` | Microsoft Authenticator (passwordless phone sign-in) | Secure | Microsoft Authenticator app (on) |
| `softwareOneTimePasscode` | Software OATH token (TOTP app) | Secure | Software OTP (off) |
| `hardwareOneTimePasscode` | Hardware OATH token | Secure | Hardware OTP (off) |
| `certificateBasedAuthentication` | Certificate-based authentication | Secure | Certificate-based authentication (on) |
| `mobilePhone` | Phone (SMS / voice call) | Unsecure | built-in unsecure list |
| `alternateMobilePhone` | Alternate phone (voice call) | Unsecure | built-in unsecure list |
| `officePhone` | Office phone (voice call) | Unsecure | built-in unsecure list |
| `email` | Email (SSPR only) | Unsecure | built-in unsecure list |
| `securityQuestion` | Security questions (SSPR only) | Unsecure | built-in unsecure list |
| `temporaryAccessPass` | Temporary Access Pass | Neutral | never qualifies, never disqualifies |

Unknown or future Graph values are treated as neutral unless explicitly listed in an override parameter.

## Override parameters

Both override parameters are hidden by default and intended for RealmJoin runbook customization:

- **SecureMethodsOverride** — comma-separated list of `methodsRegistered` values that defines the secure set. When set, **all** method group toggles are ignored. Example: `fido2SecurityKey,passKeyDeviceBound,passKeyDeviceBoundAuthenticator,windowsHelloForBusiness`
- **UnsecureMethodsOverride** — comma-separated list that replaces the built-in unsecure list. Only evaluated in strict mode. Example: `mobilePhone,alternateMobilePhone,officePhone,email,securityQuestion,softwareOneTimePasscode`

Unknown values produce a warning but are still evaluated, so future Graph values can be used before this documentation catches up.

## Email report and download links

Optionally, a detailed report can be delivered - especially useful for reviewing the very first run (ideally combined with the dry run mode):

- **Send report via email** (`SendEmail`, off by default): sends the report to the configured recipient(s). The recipient field only appears when email is enabled. Requires the `RJReport.EmailSender` tenant setting (see the [email reporting setup](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md)).
- **Create file download links** (`CreateDownloadLink`, off by default): uploads the report files to an Azure Storage Account and returns time-limited download links (uses the `RJReport.StorageAccount.*` tenant settings).

Report files are only generated when at least one of the two options is enabled. The report consists of:

- **mfa-secure-users-group-sync-changes.csv** - all performed (or, in dry run, pending) changes with per-user method details
- **mfa-secure-users-group-sync-all-users.csv** - the evaluation of every member user: registered methods, secure/unsecure classification, qualification and group membership
- **mfa-secure-users-group-sync-report.xlsx** - the same data as a formatted Excel workbook: an "Info" cover sheet with the chosen parameters and result counts, a "Changes" worksheet (added users highlighted in green, removed in red) and an "All Users" worksheet

In large tenants the raw CSV files can exceed the email attachment size limit (Graph rejects mails at roughly 4 MB total). When the CSV files exceed a 2.5 MB budget, the email is sent with only the Excel workbook attached (which contains the complete data in compressed form) and a note explaining the omission; a failed full-size send is also retried automatically with the workbook only. The download link upload always includes all files regardless of size.

## Notes and limitations

- The registration report requires an **Entra ID P1 or P2** license.
- The report does not include **disabled** or soft-deleted users — such accounts are removed from the group on the next run.
- Report data can lag behind recent registration changes; a newly registered method may take one sync cycle to be reflected.
- The runbook processes large tenants (20k+ users) via paged report reads and batched group writes with automatic throttling retries.

## Scheduling

The sync is idempotent — a single recurring schedule (e.g. daily) keeps the group up to date, and reruns after partial failures self-heal. Recommendation: run once with **Dry run (WhatIf)** enabled and review the job output before scheduling the runbook in live mode.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - AuditLog.Read.All
  - Group.Read.All
  - GroupMember.ReadWrite.All
  - User.Read.All
  - Organization.Read.All
  - Mail.Send


## Parameters
### TargetGroupId
The Entra ID group to synchronize into. Members of this group will be managed exclusively by this runbook.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### IncludePasskeys
Count passkeys and FIDO2 security keys as secure (fido2SecurityKey, passKeyDeviceBound, passKeyDeviceBoundAuthenticator).

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludePlatformCredentials
Count platform credentials as secure (windowsHelloForBusiness, passKeyDeviceBoundWindowsHello, macOsSecureEnclaveKey).

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeMicrosoftAuthenticator
Count the Microsoft Authenticator app as secure (microsoftAuthenticatorPush, microsoftAuthenticatorPasswordless).

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeSoftwareOtp
Count software OTP / authenticator TOTP apps as secure (softwareOneTimePasscode).

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeHardwareOtp
Count hardware OTP tokens as secure (hardwareOneTimePasscode).

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeCertificateBasedAuth
Count certificate-based authentication as secure (certificateBasedAuthentication).

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### SecureOnly
Strict mode: users that have any unsecure method registered (mobilePhone, alternateMobilePhone, officePhone, email, securityQuestion) never qualify, even if they also have a secure method. They are removed from the group if already a member.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### SecureMethodsOverride
Optional. Comma-separated list of methodsRegistered values that define the secure set. When set, ALL method group toggles are ignored. See the runbook documentation for all known values.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### UnsecureMethodsOverride
Optional. Comma-separated list of methodsRegistered values that replace the built-in unsecure list. Only evaluated in strict mode (SecureOnly).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### WhatIfMode
Dry run: log which users would be added or removed without changing the group.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### SendEmail
If enabled, the report is sent via email with CSV and Excel (xlsx) attachments. Disabled by default.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Recipient email address(es) for the report. Can be a single address or multiple comma-separated addresses (string). Only used when SendEmail is enabled.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
The sender email address. Sourced from the RJReport tenant settings.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CreateDownloadLink
If enabled, the report files are uploaded to an Azure Storage Account and time-limited download links are returned. Disabled by default.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

| Property | Value |
|----------|-------|
| Default Value | sync-mfa-secure-users-to-group |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group that contains the storage account. Sourced from the RJReport tenant settings.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account name used for the upload. Sourced from the RJReport tenant settings.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LinkExpiryDays
Number of days until the generated download link expires. Sourced from the RJReport tenant settings.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)


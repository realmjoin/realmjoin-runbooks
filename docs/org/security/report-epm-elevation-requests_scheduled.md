# Report EPM Elevation Requests (Scheduled)

Generate report for Endpoint Privilege Management (EPM) elevation requests

## Detailed description
Queries Microsoft Intune for EPM elevation requests with flexible filtering options.
Supports filtering by multiple status types and time range.
Sends an email report with summary statistics and detailed CSV attachment.

## Where to find
Org \ Security \ Report EPM Elevation Requests_Scheduled

## Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.


## Notes
Runbook Type: Scheduled (recommended: monthly)

Purpose & Use Cases:
- Regular reporting of EPM activities
- Audit trail for approved/denied elevation requests
- Analysis of expired requests to identify process bottlenecks
- Identification of frequently requested applications for automatic elevation rules

Status Types Explained:
- Pending: Awaits admin decision (use monitor-pending-EPM-requests for time-critical alerting)
- Approved: Admin approved the request, user can proceed with elevation
- Denied: Admin rejected the request due to security/policy concerns
- Expired: Request expired before admin review (may indicate slow response times)
- Revoked: Previously approved elevation was later revoked by admin
- Completed: User successfully executed the elevated application after approval

Data Retention & Time Ranges:
- Intune retains EPM request details for 30 days after creation
- For long-term analysis, archive CSV exports outside of Intune
- Default filter (Approved/Denied/Expired/Revoked, 30 days)

Email & Export Details:
- Always generates CSV attachment with complete request details
- Emails sent individually to each recipient for privacy
- No email sent when zero requests match the filter criteria
- CSV includes: timestamps, users, devices, applications, justifications, file hashes

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.Read.All
  - Mail.Send


## Parameters
### IncludeApproved
Include requests with status "Approved" - Request has been approved by an administrator.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeDenied
Include requests with status "Denied" - Request was rejected by an administrator.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeExpired
Include requests with status "Expired" - Request expired before approval/denial.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludeRevoked
Include requests with status "Revoked" - Previously approved request was revoked.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### IncludePending
Include requests with status "Pending" - Awaiting approval decision.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### IncludeCompleted
Include requests with status "Completed" - Request was approved and executed successfully.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### MaxAgeInDays
Filter requests created within the last X days (default: 30).
Note: Request details are retained in Intune for 30 days after creation.

| Property | Value |
|----------|-------|
| Default Value | 30 |
| Required | false |
| Type | Int32 |

### EmailTo
Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EmailFrom
The sender email address. This needs to be configured in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


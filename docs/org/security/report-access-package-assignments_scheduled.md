# Report Access Package Assignments (Scheduled)

List access packages with their assignments, requests and policies

## Detailed description
Lists the access packages of Entra ID entitlement management, all or those matching a name or catalog filter, with everyone assigned to them. Users, guests and service principals are listed, whether they requested access, were added by an admin or by an auto-assignment policy. Further tables show the resource roles each package grants, open requests and assignment policies. The report can be sent by email or provided as a download link.

## Where to find
Org \ Security \ Report Access Package Assignments_Scheduled

## How it works

The runbook reads the access packages of Entra ID entitlement management, all of them or only those that match the access package or catalog filter, and for each package its assignments, its assignment requests, its assignment policies and the resource roles it grants. The resources of the catalogs involved are read as well, so groups, applications and SharePoint sites appear with their names.

The results are split into separate tables:

- **Summary** - counts for the whole report.
- **Access packages** - one row per package with catalog, description, whether it is hidden, the number of active assignments (members, guests, service principals), assignments expiring within 30 days, delivery problems, expired assignments, open requests, policies and resource roles.
- **Assignments** - one row per active assignment.
- **Expired assignments** - only when *Include expired assignments?* is selected.
- **Open requests** - requests that are not finished yet.
- **Resource roles** - what each package grants.
- **Policies** - who can get each package and under which conditions.

Entitlement management requires a Microsoft Entra ID P2 or Microsoft Entra ID Governance license in the tenant.

### Access package and catalog filter

*Access package name filter* selects packages by their name, *Catalog name filter* by the name of the catalog they belong to. Both work the same way and apply together: `Sales -*` as name filter with `HR` as catalog filter reports the packages starting with `Sales -` that sit in a catalog with `HR` in its name. Leave both empty to report every access package of the tenant. Upper and lower case do not matter.

- **Starts with** - `Sales -*` reports all packages whose name starts with `Sales -`.
- **Ends with** - `*- Pilot` reports all packages whose name ends with `- Pilot`.
- **Contains** - `*Finance*`, or just `Finance` without a wildcard, reports all packages with `Finance` anywhere in the name.
- **Pattern** - `Sales*Pilot` reports all packages whose name starts with `Sales` and ends with `Pilot`.

A filter with `*` must match the whole name; a filter without `*` matches anywhere in the name. `*` is the only wildcard. Other characters such as `?`, `[` and `]` are matched as they are, so names containing them need no escaping. When the filters match no package, the run fails and lists the access packages of the tenant with their catalogs. When the catalogs cannot be read, a catalog filter cannot be applied and the run fails as well.

### Assignments

Every assignment of the package is listed, whatever its origin: users who requested access, users and service principals an admin assigned directly, and users added by an auto-assignment policy. The **AssignedVia** column shows the origin:

- **User request** - the user requested the package in the My Access portal.
- **Admin assignment** - an admin assigned the package directly.
- **Auto-assignment** - an auto-assignment policy added the user based on an attribute rule.
- **Not recorded** - the request that created the assignment is no longer available and the policy allows more than one way. When the policy allows only admin assignments or is an auto-assignment policy, the origin is taken from the policy instead.

The **SubjectType** column distinguishes **Member**, **Guest**, **External (not in tenant yet)** and **Service principal**. Guests are recognized by the `#EXT#` marker in their user principal name or by a guest lifecycle governed by entitlement management. **External (not in tenant yet)** is a requestor from a connected organization whose guest account has not been created yet.

**State** shows whether the access was delivered (*Delivered*, *Delivering*, *Partially delivered*, *Delivery failed*). **Status** adds the detailed lifecycle status from entitlement management, for example `AutoAssignmentInGracePeriod` or `NearExpiry1DayNotificationTriggered`. **Start** and **End** are given in UTC; **End** is *Never* for assignments without expiration. **DaysLeft** counts the full days until the end; the summary counts assignments that end within 30 days.

### Expired assignments

Expired assignments are always counted in the summary and per package. With *Include expired assignments?* they are also listed in their own table with the date they expired. Tenants that have used access packages for years can have a long history, so the option is off by default.

### Open requests

Requests in the states *Submitted*, *Pending approval*, *Scheduled* and *Delivering* are listed with the request type, the requested start and end and the justification. This includes requests to remove or extend access, not only new requests. Finished, denied and canceled requests are not listed.

### Resource roles

Each row names a resource the package grants, its type (*Group*, *Application*, *SharePoint site*, *Azure resource*, *Custom data*) and the role in it, for example *Member* or *Owner* of a group, an app role of an application or a SharePoint site group. **ResourceId** is the object ID of the group or service principal, or the site URL.

### Policies

Each row describes one assignment policy of a package:

- **PolicyType** - *Request* (users request access), *Admin assignment only* or *Auto-assignment*.
- **WhoCanBeAssigned** and **AllowedTargets** - the principals the policy is meant for; for auto-assignment policies the attribute rule.
- **ApprovalRequired** and **Approvers** - approval stages with their primary approvers.
- **Expiration**, **UsersCanExtend** and **AccessReviews** - how long assignments last, whether users can extend them and how often they are reviewed.
- **Assignments** - the number of active assignments made through the policy.

Approvers and allowed users or groups are shown with the description stored in the policy. When the policy stores no description, the object ID is shown, because resolving names would need further directory permissions.

### Gaps in the report

The runbook never shortens a list silently. When the assignments, requests, policies or resource roles of a package cannot be read, or a further page of them fails, the reason is in the **Note** column of *Access packages* and the package is counted in *Packages not fully read*; the job log then shows a warning that the report is incomplete. When the resources of a catalog cannot be read, resources are shown by their origin ID instead of their name.

## Report delivery

The results always appear as named tables in the Output Data tab of the run in the RealmJoin portal. Report files are only generated when the **Report delivery** option includes an email and/or a download link; *Output Data only* creates no report files. Email delivery and download link generation are independent and can be combined.

The Excel workbook holds one worksheet per table plus a cover sheet with the summary. With CSV, each table is written to its own CSV file. When the CSV files and the workbook together exceed the email attachment limit, the email carries the workbook only.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Reader and Data Access** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

## Setup regarding email sending

Sending an email report is optional and only happens when *Also email the report* or *Also email & download link* is selected as report delivery; a recipient is then required. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details on all available settings.

### Email branding

The report email honors the optional `RJReport.Branding.*` tenant settings:

- **Header and footer image** - public HTTPS URLs, PNG/JPEG/GIF, max. 200 KB each
- **Footer link** - target of the footer image
- **Accent and text color** - 6-digit hex values, e.g. `#0052cc`

When these settings are not configured, the default RealmJoin graphics and colors are used. An image that cannot be downloaded or validated, or an invalid color value, never prevents the report email - the corresponding default is used instead.

Setup instructions and image requirements: [Email branding](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings#email-branding-optional).

## Notes and limitations

- The report is read-only. Assignments, requests and policies are changed in the Entra admin center under Identity Governance.
- Group memberships the package delivers are not expanded: the report lists who is assigned to the package and which resource roles it grants, not every member of those groups.
- Incompatible access packages and groups, custom extensions and the answers to requestor questions are not part of the report.
- All dates and times are in UTC.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - EntitlementManagement.Read.All
  - Mail.Send *(optional: Email report)*
  - Organization.Read.All *(optional: Email report)*

### Permission notes
Azure Storage Account: 'Reader and Data Access' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required for the download link options)


## Parameters
### AccessPackageName
Only access packages whose name matches are reported. Use * as a wildcard, for example "Sales -*" for names starting with "Sales -"; text without * matches anywhere in the name. Case does not matter. Leave empty for all packages.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CatalogName
Only access packages in catalogs whose name matches are reported, with the same rules as "Access package name filter". Both filters apply together. Leave empty for all catalogs.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### IncludeExpiredAssignments
Also list the assignments that have already expired, in a separate table. Expired assignments are always counted; the list can be long in tenants that have used access packages for years.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailFrom
Sender address of the report email. Taken from the tenant setting RJReport.EmailSender.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingHeaderImageUrl
Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterImageUrl
Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingFooterLink
Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingAccentColor
Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### BrandingTextColor
Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SendEmailReport
Send the report to the recipient email address.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### EmailTo
Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ReportFileFormat
Deliver the report as CSV, as an Excel workbook, or both.

| Property | Value |
|----------|-------|
| Default Value | CSV & XLSX |
| Required | false |
| Type | String |

### CreateDownloadLink
Also upload the report and return a download link that expires after a few days.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ContainerName
Storage container the report files are uploaded to. Set per runbook.

| Property | Value |
|----------|-------|
| Default Value | report-access-package-assignments |
| Required | false |
| Type | String |

### ResourceGroupName
Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StorageAccountName
Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SubscriptionId
Subscription ID of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.SubscriptionId; the subscription the managed identity signs in to is used when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LinkExpiryDays
Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)


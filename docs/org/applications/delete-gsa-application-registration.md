# Delete Gsa Application Registration

Delete a GSA application registration from Azure AD including associated objects

## Detailed description
This runbook deletes a Global Secure Access application registration created by the
"add-gsa-application-registration" runbook, including everything provisioned with it:
the application (and thereby its service principal, application segments and connector
group assignment) and the security group created by the naming scheme.

The naming scheme group is identified via the groups assigned to the application whose
display name matches the admin-defined group prefix. If the group was created but never
assigned (partial provisioning), a best-effort lookup by naming scheme is performed.

Safety measures:
- The runbook verifies the application is actually a GSA / App Proxy application
  (onPremisesPublishing) before deleting anything.
- By default only security group(s) matching the naming scheme are deleted. Other
  groups assigned to the application are listed but NOT deleted, as they may be
  shared with other applications. Set deleteAllAssignedGroups to change this.

## Where to find
Org \ Applications \ Delete Gsa Application Registration

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.ReadWrite.All
  - Group.ReadWrite.All


## Parameters
### applicationName
The full display name of the GSA application to delete, e.g. "GSA-MyApp".

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### groupPrefix
Prefix of the security group naming scheme, used to identify the group(s) to delete.
Must match the groupPrefix of the add-gsa-application-registration runbook.
Default: "App - Entra - GSA - ".

| Property | Value |
|----------|-------|
| Default Value | App - Entra - GSA - |
| Required | false |
| Type | String |

### groupSuffix
Optional suffix of the security group naming scheme. Default: empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### deleteAllAssignedGroups
If true, ALL groups assigned to the application are deleted, not only the naming scheme group(s).
Use with care - assigned groups may be shared with other applications. Default: false.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


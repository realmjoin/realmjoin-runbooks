# Report License Assignment (Scheduled)

Alert when license availability crosses thresholds

## Detailed description
Checks how many licenses of the configured SKUs are still available. When a count drops below a minimum or rises above a maximum threshold, the affected SKUs are reported so you can buy or reclaim licenses in time. The report can be sent by email or provided as a download link.

## Where to find
Org \ General \ Report License Assignment_Scheduled

## License configuration

The SKUs to check and their thresholds are preset in the runbook customization as the hidden `InputJson` value. Each license configuration requires:

- **SKUPartNumber** (required): Microsoft SKU identifier
- **FriendlyName** (required): Display name
- **MinThreshold** (optional): Alert when available licenses < threshold
- **MaxThreshold** (optional): Alert when available licenses > threshold

At least one threshold must be set per license.

### Configuration examples

**Minimum threshold only** (prevent shortages):

```json
[
    {
        "SKUPartNumber": "ENTERPRISEPACK",
        "FriendlyName": "Microsoft 365 E3",
        "MinThreshold": 50
    }
]
```

**Maximum threshold only** (prevent over-provisioning):

```json
[
    {
        "SKUPartNumber": "POWER_BI_PRO",
        "FriendlyName": "Power BI Pro",
        "MaxThreshold": 500
    }
]
```

**Both thresholds** (maintain range):

```json
[
    {
        "SKUPartNumber": "ENTERPRISEPREMIUM",
        "FriendlyName": "Microsoft 365 E5",
        "MinThreshold": 50,
        "MaxThreshold": 150
    }
]
```

### Complete runbook customization

```json
{
    "Settings": {
        "RJReport": {
            "EmailSender": "sender@contoso.com"
        }
    },
    "Runbooks": {
        "rjgit-org_general_report-license-assignment_scheduled": {
            "Parameters": {
                "InputJson": {
                    "Hide": true,
                    "DefaultValue": [
                        {
                            "SKUPartNumber": "SPE_E5",
                            "FriendlyName": "Microsoft 365 E5",
                            "MinThreshold": 20,
                            "MaxThreshold": 30
                        },
                        {
                            "SKUPartNumber": "FLOW_FREE",
                            "FriendlyName": "Microsoft Power Automate Free",
                            "MinThreshold": 10
                        }
                    ]
                }
            }
        }
    }
}
```

See the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization) for the syntax.

## Finding SKU part numbers

```powershell
Connect-MgGraph -Scopes "Organization.Read.All"
Get-MgSubscribedSku | Select-Object SkuPartNumber, SkuId | Sort-Object SkuPartNumber
```

Common SKUs:

- `ENTERPRISEPACK` - Microsoft 365 E3
- `ENTERPRISEPREMIUM` - Microsoft 365 E5
- `EMS` - Enterprise Mobility + Security E3

## Results

Every run writes its results to the Output Data tab of the RealmJoin portal: a summary, the licenses outside their thresholds, the configured SKUs that do not exist in the tenant and the licenses within their thresholds. Each table can be exported to Excel there.

- **When violations are detected:** the report files (CSV and/or Excel workbook) list the licenses outside their thresholds, and the email contains the summary, the violations, recommendations and the files as attachments.
- **When a configured SKU is not found:** the email lists the SKU as a configuration issue.
- **When all licenses are within their thresholds:** no email is sent, no report file is created and the run completes successfully.

## Report delivery

Report files are only generated when a delivery method is selected via the **Report delivery** option (email and/or download link) and at least one license is outside its thresholds. With *Output Data only* selected, the results are read directly in the Output Data tab of the RealmJoin portal, where each table can also be exported to Excel. Email delivery and download link generation are independent and can be combined.

For the download link, the report files are uploaded to the Azure storage account configured in the `RJReport.StorageAccount.*` tenant settings, and time-limited SAS download links are returned. The storage upload authenticates with the Automation account's managed identity; that identity needs the **Storage Account Contributor** RBAC role on the target storage account (this is an Azure RBAC assignment, not a Graph application permission).

Schedules that were created before the **Report delivery** option existed keep sending their email: a stored recipient alone still enables the email for them. When such a schedule is opened for editing, the option shows *Output Data only*; select the delivery again before saving, otherwise the schedule stops sending the report.

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

## Troubleshooting

**SKU not found**: Verify that the SKU exists using `Get-MgSubscribedSku`.

**Email not sent**: Check the `RJReport.EmailSender` setting and the Mail.Send permission of the managed identity. No email is sent when all licenses are within their thresholds.

**Invalid JSON**: Validate the JSON format before configuring it.

## Migration note

Legacy `WarningThreshold` automatically maps to `MinThreshold` - old configurations continue to work.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Organization.Read.All
  - Mail.Send *(optional: Email report)*

### Permission notes
Azure Storage Account: 'Storage Account Contributor' role for the Automation Account's managed identity on the target storage account - the upload retrieves the account keys via listKeys (only required for the download link options)


## Parameters
### InputJson
SKU list with friendly names and minimum and maximum thresholds, as a JSON array. Preset in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | Object |

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
| Default Value | report-license-assignment |
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

### LinkExpiryDays
Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

| Property | Value |
|----------|-------|
| Default Value | 6 |
| Required | false |
| Type | Int32 |

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


[Back to Table of Content](../../../README.md)


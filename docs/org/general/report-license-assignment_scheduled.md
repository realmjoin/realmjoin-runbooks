# Report License Assignment (Scheduled)

Generate and email a license availability report based on thresholds

## Detailed description
This runbook checks the license availability based on the transmitted SKUs and sends an email report if any thresholds are reached.
Two types of thresholds can be configured. The first type is a minimum threshold, which triggers an alert when the number of available licenses falls below a specified number.
The second type is a maximum threshold, which triggers an alert when the number of available licenses exceeds a specified number.
The report includes detailed information about licenses that are outside the configured thresholds, exports them to CSV files, and sends them via email.

## Where to find
Org \ General \ Report License Assignment_Scheduled

## Runbook Customization

### Setup regarding email sending

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

This process is described in detail in the [Setup Email Reporting](https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md) documentation.

### InputJson Configuration

Each license configuration requires:

- **SKUPartNumber** (required): Microsoft SKU identifier
- **FriendlyName** (required): Display name
- **MinThreshold** (optional): Alert when available licenses < threshold
- **MaxThreshold** (optional): Alert when available licenses > threshold

At least one threshold must be set per license.

### Configuration Examples

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

### Complete Runbook Customization

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
                "EmailTo": {
                    "DisplayName": "Recipient Email Address(es)"
                },
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
                },
                "EmailFrom": {
                    "Hide": true
                },
                "CallerName": {
                    "Hide": true
                }
            }
        }
    }
}
```

## Finding SKU Part Numbers

```powershell
Connect-MgGraph -Scopes "Organization.Read.All"
Get-MgSubscribedSku | Select-Object SkuPartNumber, SkuId | Sort-Object SkuPartNumber
```

Common SKUs:

- `ENTERPRISEPACK` - Microsoft 365 E3
- `ENTERPRISEPREMIUM` - Microsoft 365 E5
- `EMS` - Enterprise Mobility + Security E3

## Output

**When violations detected:**

- Console output in job log
- CSV export (`License_Threshold_Violations.csv`)
- Email report with summary, violations, recommendations, and CSV attachment

**When all within thresholds:**

- No email sent
- Job completes successfully

## Troubleshooting

**SKU Not Found**: Verify SKU exists using `Get-MgSubscribedSku`

**Email Not Sent**: Check EmailFrom configuration and Mail.Send permission

**Invalid JSON**: Validate JSON format before configuration

## Migration Note

Legacy `WarningThreshold` automatically maps to `MinThreshold` - old configurations continue to work.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Organization.Read.All
  - User.Read.All
  - Mail.Send


## Parameters
### InputJson
JSON array containing SKU configurations with thresholds. Each entry should include a SKUPartNumber for the Microsoft SKU identifier, a FriendlyName as the display name for the license, an optional MinThreshold specifying the minimum number of licenses that should be available, and an optional MaxThreshold specifying the maximum number of licenses that should be available.

This needs to be configured in the runbook customization

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | Object |

### EmailTo
Recipient email address or comma-separated recipient list.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### EmailFrom
Sender email address resolved from settings.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


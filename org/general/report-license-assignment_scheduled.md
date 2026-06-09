## Runbook Customization

### Setup regarding email sending

Sending an email report is optional and only happens when a recipient (`EmailTo`) is provided. The sender address is taken from the `RJReport.EmailSender` tenant setting.

This runbook sends emails using the Microsoft Graph API. To send emails via Graph API, you need to configure an existing email address in the runbook customization.

See the [RealmJoin Report Settings documentation](https://docs.realmjoin.com/automation/runbooks/runbook-report-settings) for details.

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

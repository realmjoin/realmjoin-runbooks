## Offer the license groups as dropdowns

Both license fields are text fields by default. Offer the license groups of your tenant as dropdowns via runbook customization (the same list for the current and the new license):

```json
"rjgit-user_general_resize-windows365": {
    "Parameters": {
        "currentLicWin365GroupName": {
            "SelectSimple": {
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
            }
        },
        "newLicWin365GroupName": {
            "SelectSimple": {
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
            }
        }
    }
}
```

The resize runs the *Unassign Windows 365* and *Assign Windows 365* runbooks in sequence; their Azure Automation names are preset in the hidden parameters `unassignRunbook` and `assignRunbook`.

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).

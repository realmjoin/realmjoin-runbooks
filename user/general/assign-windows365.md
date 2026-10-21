## Offer the policy and license groups as dropdowns

The provisioning policy, user settings policy and license group are plain text fields by default. Turn them into dropdowns with the group names of your tenant via runbook customization:

```json
"rjgit-user_general_assign-windows365": {
    "Parameters": {
        "cfgProvisioningGroupName": {
            "SelectSimple": {
                "cfg - Windows 365 - Provisioning - Win11": "cfg - Windows 365 - Provisioning - Win11",
                "cfg - Windows 365 - Provisioning - Win10": "cfg - Windows 365 - Provisioning - Win10"
            }
        },
        "cfgUserSettingsGroupName": {
            "SelectSimple": {
                "cfg - Windows 365 - User Settings - restore allowed": "cfg - Windows 365 - User Settings - restore allowed",
                "cfg - Windows 365 - User Settings - no restore": "cfg - Windows 365 - User Settings - no restore"
            }
        },
        "licWin365GroupName": {
            "SelectSimple": {
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
            }
        }
    }
}
```

The group name prefixes (`cfgProvisioningGroupPrefix`, `cfgUserSettingsGroupPrefix`) decide which groups count as provisioning or user settings groups; adjust them in the same place when your naming differs.

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).

## Preset the groups via runbook customization

The two groups are normally fixed per tenant, so preset them in the runbook customization:

```json
"rjgit-internal_device_assign-group": {
    "Parameters": {
        "AddDeviceToGroup": {
            "Default": true
        },
        "GroupID": {
            "Default": "9d7b59ac-89dd-4b6b-a37a-22a94f886904"
        },
        "AddUserToGroup": {
            "Default": true
        },
        "UserGroupID": {
            "Default": "9d7b59ac-89dd-4b6b-a37a-22a94f886905"
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).

## Offer locations, companies, licenses and departments as templates

Most fields of this runbook are free text. With runbook customization templates the operator picks from predefined lists instead, and a location template can fill in and lock the whole address block. The example below defines such templates and binds them to the runbook's fields:

```json
"Templates": {
    "Options": [
        {
            "$id": "LocationOptions",
            "$values": [
                {
                    "Display": "Contoso DE",
                    "Value": "ContosoDe",
                    "Customization": {
                        "Default": {
                            "StreetAddress": "Demostr. 22",
                            "PostalCode": "80333",
                            "City": "Munich",
                            "State": "Bavaria",
                            "Country": "Germany",
                            "UsageLocation": "DE"
                        },
                        "ReadOnly": [
                            "StreetAddress",
                            "PostalCode",
                            "City",
                            "Country",
                            "UsageLocation"
                        ]
                    }
                }
            ]
        },
        {
            "$id": "CompanyOptions",
            "$values": [
                {
                    "Display": "CONTOSO",
                    "Value": "Contoso"
                }
            ]
        },
        {
            "$id": "LicenseOptions",
            "$values": [
                {
                    "Display": "M365 E3 + E5 Security + Audio Conferencing",
                    "Value": "LIC_M365_E3&E5_SecurityPlan&AudioConf"
                },
                {
                    "Display": "none",
                    "Value": ""
                }
            ]
        },
        {
            "$id": "DepartmentOptions",
            "$values": [
                {
                    "Display": "M&A",
                    "Value": "M&A"
                },
                {
                    "Display": "Tax & Legal",
                    "Value": "Tax & Legal"
                },
                {
                    "Display": "Controlling & Operations",
                    "Value": "Controlling & Operations"
                },
                {
                    "Display": "IT",
                    "Value": "IT"
                },
                {
                    "Display": "Communications",
                    "Value": "Communications"
                },
                {
                    "Display": "Strategy & Management",
                    "Value": "Strategy & Management"
                },
                {
                    "Display": "Accounting",
                    "Value": "Accounting"
                },
                {
                    "Display": "Insurance",
                    "Value": "Insurance"
                },
                {
                    "Display": "Treasury",
                    "Value": "Treasury"
                }
            ]
        }
    ]
},
"Runbooks": {
    "rjgit-user_userinfo_update-user": {
        "ParameterList": [
            {
                "Name": "LocationName",
                "DisplayName": "Office Location",
                "DisplayBefore": "StreetAddress",
                "Select": {
                    "Options": {
                        "$ref": "LocationOptions"
                    }
                },
                "Default": "ContosoDe"
            },
            {
                "Name": "CompanyName",
                "Select": {
                    "Options": {
                        "$ref": "CompanyOptions"
                    },
                    "AllowEdit": false
                },
                "Default": "Contoso"
            },
            {
                "Name": "DefaultLicense",
                "DisplayName": "License",
                "Select": {
                    "Options": {
                        "$ref": "LicenseOptions"
                    },
                    "AllowEdit": true
                },
                "Default": "LIC_M365_E3&E5_SecurityPlan&AudioConf"
            },
            {
                "Name": "Department",
                "Select": {
                    "Options": {
                        "$ref": "DepartmentOptions"
                    },
                    "AllowEdit": true
                }
            },
            {
                "Name": "ResetPassword",
                "Hide": true
            },
            {
                "Name": "DefaultGroups",
                "Default": "app - 7-Zip,app - Adobe Reader DC Continuous Track,app - glueckkanja-gab KONNEKT"
            }
        ]
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).

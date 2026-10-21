## Offer locations and companies as templates

Address fields and company are free text by default. With runbook customization templates the operator picks an office location, which fills in and locks the address block, and a company from a list. The example below defines such templates and binds them to the runbook's fields:

```json
{
    "Templates": {
        "Options": [
            {
                "$id": "LocationOptions",
                "$values": [
                    {
                        "Display": "DE-OF",
                        "Customization": {
                            "Default": {
                                "StreetAddress": "Kaiserstraße 39",
                                "PostalCode": "63065",
                                "City": "Offenbach",
                                "Country": "Germany"
                            }
                        }
                    },
                    {
                        "Display": "DE-DEG",
                        "Customization": {
                            "Default": {
                                "StreetAddress": "Lateinschulgassse 24-26",
                                "PostalCode": "94469",
                                "City": "Deggendorf",
                                "Country": "Germany"
                            }
                        }
                    },
                    {
                        "Display": "DE-HH",
                        "Customization": {
                            "Default": {
                                "StreetAddress": "Hans-Henny-Jahnn-Weg 53",
                                "PostalCode": "22085",
                                "City": "Hamburg",
                                "Country": "Germany"
                            }
                        }
                    },
                    {
                        "Display": "FI-HS",
                        "Customization": {
                            "Default": {
                                "StreetAddress": "Somewhere 42",
                                "PostalCode": "12345",
                                "City": "Helsinki",
                                "Country": "Finland"
                            }
                        }
                    }
                ]
            },
            {
                "$id": "CompanyOptions",
                "$values": [
                    {
                        "Id": "gkg",
                        "Display": "glueckkanja-gab",
                        "Value": "glueckkanja-gab AG"
                    },
                    {
                        "Id": "pp",
                        "Display": "PrimePulse",
                        "Value": "PrimePulse AG"
                    }
                ]
            }
        ]
    },
    "Runbooks": {
        "rjgit-org_general_add-user": {
            "ParameterList": [
                {
                    "DisplayName": "Office Location",
                    "DisplayAfter": "CompanyName",
                    "Select": {
                        "Options": {
                            "$ref": "LocationOptions"
                        }
                    }
                },
                {
                    "Name": "CompanyName",
                    "Select": {
                        "Options": {
                            "$ref": "CompanyOptions"
                        },
                        "AllowEdit": false
                    }
                }
            ],
            "ReadOnly": [
                "StreetAddress",
                "PostalCode",
                "City",
                "Country"
            ]
        }
    }
}
```

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).

## Offer the accepted domains as a list

The domain of the new mailbox is free text by default. With a runbook customization the operator picks it from the accepted domains of the tenant instead:

```json
{
        "Runbooks": {
        "rjgit-org_mail_add-shared-mailbox": {
            "ParameterList": [
                {
                    "Name": "DomainName",
                    "Select": {
                        "Options": [
                                {
                                    "Value": "contoso.onmicrosoft.com"
                                },
                                {
                                    "Value": "contoso.com"
                                }
                            ]
                    },
                    "DefaultValue": "contoso.com"
                }
            ]
        }
    }
}
```

## Offer only the time zones you use

The time zone list holds the Windows time zones named after places, sorted by their offset from UTC as in Windows and Outlook. The offset in each entry is the standard time. Exchange Online applies daylight saving time on its own, so Sydney is listed as UTC+10:00 and runs at UTC+11:00 from October to April.

With a runbook customization the operator sees only the time zones of your locations:

```json
{
    "Runbooks": {
        "rjgit-org_mail_add-shared-mailbox": {
            "ParameterList": [
                {
                    "Name": "TimeZone",
                    "SelectSimple": {
                        "(UTC-05:00) Eastern Time (US & Canada)": "Eastern Standard Time",
                        "(UTC+00:00) Dublin, Edinburgh, Lisbon, London": "GMT Standard Time",
                        "(UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna": "W. Europe Standard Time",
                        "(UTC+10:00) Canberra, Melbourne, Sydney": "AUS Eastern Standard Time"
                    },
                    "Default": "W. Europe Standard Time"
                }
            ]
        }
    }
}
```

The text on the left is shown in the portal, the value on the right is the Windows time zone ID that Exchange Online stores. Take both from the portal options of the time zone parameter below. `Default` names the ID that is preselected.

For more information on how to customize runbooks, please refer to the [Runbook Customization Guide](https://docs.realmjoin.com/automation/runbooks/runbook-customization).

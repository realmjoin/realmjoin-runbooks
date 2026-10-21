# Add User

Create a new user account in Entra ID

## Detailed description
Creates a cloud user in Entra ID with the usual profile details such as name, company, job title, manager, sponsors and address. Sign-in name, alias and display name are derived from the name when left empty, and a start password is generated when none is given. Optionally the user gets a license group, further groups and an Exchange Online archive mailbox.

## Where to find
Org \ General \ Add User

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


## Permissions
### Application permissions
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- User Administrator
- Exchange Administrator


## Parameters
### GivenName
First name of the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### Surname
Last name of the user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UserPrincipalName
Sign-in name of the user. Derived from the name when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### MailNickname
Alias of the mailbox. Derived from the sign-in name when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DisplayName
Derived from first and last name when empty.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CompanyName
Company the user belongs to.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### JobTitle
Shown in the profile and in the address book.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Department
Department the user works in.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ManagerId
User who becomes the manager.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SponsorIds
Users recorded as sponsors of the new user. Several can be picked.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String Array |

### MobilePhone
Shown in the profile and in the address book.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### LocationName
Office location shown in the profile. With templates from the runbook customization, picking one also fills in the address fields.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StreetAddress
Part of the postal address shown in the profile. Filled in by the office location template when one is picked.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### PostalCode
Part of the postal address shown in the profile. Filled in by the office location template when one is picked.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### City
Part of the postal address shown in the profile. Filled in by the office location template when one is picked.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### State
Part of the postal address shown in the profile.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Country
Part of the postal address shown in the profile. Filled in by the office location template when one is picked.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### UsageLocation
Two-letter country code that decides which licenses the user may get, for example DE.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DefaultLicense
Display name of the group that assigns the license; the user is added to it. Leave empty for none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DefaultGroups
Display names of further groups the user is added to, separated by commas.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### InitialPassword
Start password for the user. Leave empty to have one generated and shown in the output.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EnableEXOArchive
Turns on the Exchange Online archive mailbox for the new user.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


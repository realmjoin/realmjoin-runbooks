# Update User

Update profile details, groups and mailbox settings of this user

## Detailed description
Updates the profile of this user in Entra ID, such as name, company, address, job title and manager. It can also add the user to a license group and further groups, enable the Exchange Online archive and reset the password. Only the fields you fill in are changed; a missing display name or company is filled in automatically.

## Where to find
User \ Userinfo \ Update User

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


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - UserAuthenticationMethod.Read.All
- **Type**: Office 365 Exchange Online
  - Exchange.ManageAsApp

### RBAC roles
- User Administrator
- Exchange Administrator


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### GivenName
New first name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Surname
New last name.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DisplayName
New display name as shown in Microsoft 365.

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

### City
City of the user's address.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Country
Country of the user's address.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### JobTitle
Job title shown in the profile.

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

### OfficeLocation
Office or building the user works at.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### PostalCode
Postal code of the user's address.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### PreferredLanguage
Language code such as en-US or de-DE.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### State
State or region of the user's address.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### StreetAddress
Street and house number of the user's address.

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

### ManagerId
User who becomes the manager of this user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DefaultLicense
Display name of the group that assigns the license; the user is added to it.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### DefaultGroups
Display names of groups the user is added to, separated by commas.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### EnableEXOArchive
Turns on the Exchange Online archive mailbox for the user.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### ResetPassword
Sets a generated start password, shown in the output, that must be changed at the next sign-in. Skipped when the user already has MFA methods.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


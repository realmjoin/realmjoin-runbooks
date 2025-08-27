# List Application Creds Expiry

## List expiry date of all AppRegistration credentials

## Description
List the expiry date of all AppRegistration credentials, including Client Secrets and Certificates.
Optionally, filter by Application IDs and list only those credentials that are about to expire.

## Where to find
Org \ Security \ List Application Creds Expiry

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.Read.All


## Parameters
### -listOnlyExpiring
Description: If set to true, only credentials that are about to expire within the specified number of days will be listed.
If set to false, all credentials will be listed regardless of their expiry date.
Default Value: True
Required: false

### -Days
Description: The number of days before a credential expires to consider it "about to expire".
Default Value: 30
Required: false

### -ApplicationIds
Description: A comma-separated list of Application IDs to filter the credentials.
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)


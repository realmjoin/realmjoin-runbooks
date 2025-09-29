# Report App Registration

## Generate and email a comprehensive App Registration report

## Description
This runbook generates a report of all Entra ID Application Registrations and deleted Application Registrations,
exports them to CSV files, and sends them via email.

## Where to find
Org \ Applications \ Report App Registration

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.Read.All
  - Directory.Read.All
  - Mail.Send
  - Organization.Read.All


## Parameters
### -EmailTo
Description: The recipient email address for the report. Must be a valid email format!
Default Value: 
Required: true

### -EmailFrom
Description: The sender email address (optional, will use default if not specified)
Default Value: 
Required: false

### -IncludeDeletedApps
Description: Whether to include deleted application registrations in the report (default: true)
Default Value: True
Required: false


[Back to Table of Content](../../../README.md)


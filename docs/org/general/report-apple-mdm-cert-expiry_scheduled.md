# Report Apple Mdm Cert Expiry_Scheduled

Monitor/Report expiry of Apple device management certificates.

## Detailed description
Monitors expiration dates of Apple Push certificates, VPP tokens, and DEP tokens in Microsoft Intune.
Sends an email report with alerts for certificates/tokens expiring within the specified threshold.

## Where to find
Org \ General \ Report Apple Mdm Cert Expiry_Scheduled

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.Read.All
  - DeviceManagementServiceConfig.Read.All
  - DeviceManagementConfiguration.Read.All
  - Mail.Send


## Parameters
### -Days
Description: The warning threshold in days. Certificates and tokens expiring within this many days will be
flagged as alerts in the report. Default is 300 days (approximately 10 months).
Default Value: 30
Required: false

### -EmailTo
Description: Can be a single address or multiple comma-separated addresses (string).
The function sends individual emails to each recipient for privacy reasons.
Default Value: 
Required: false

### -EmailFrom
Description: The sender email address. This needs to be configured in the runbook customization
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)


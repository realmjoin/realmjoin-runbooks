# Create Endpoint Analytics Baseline

Create an Endpoint Analytics baseline with a naming schema

## Detailed description
Creates a new Endpoint Analytics baseline in Intune, named after a schema with placeholders such as the current date, so baselines can be created regularly and compared over time. Intune allows at most 20 baselines; the oldest can be removed automatically when the limit is reached.

## Where to find
Org \ Devices \ Create Endpoint Analytics Baseline

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementManagedDevices.ReadWrite.All


## Parameters
### BaselineNamingSchema
Name pattern with placeholders such as {Year}, {Month}, {Date} or {DateTime}, for example EA-Baseline-{Year}-{Month}.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### RemoveOldestBaseline
Deletes the oldest baseline when 20 already exist. Turn off to stop with an error instead.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


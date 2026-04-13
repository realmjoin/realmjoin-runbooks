# Create Endpoint Analytics Baseline

Creates Endpoint Analytics baselines in Microsoft Intune with a specified naming schema.

## Detailed description
This runbook creates new Endpoint Analytics baselines in Intune using a customizable naming schema. Endpoint Analytics baselines allow organizations to measure and track device performance metrics over time. The naming schema can include placeholders that will be replaced with contextual values during baseline creation.

## Where to find
Org \ Devices \ Create Endpoint Analytics Baseline

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - DeviceManagementConfiguration.ReadWrite.All


## Parameters
### BaselineNamingSchema
The naming schema to use for the Endpoint Analytics baseline. Can include placeholders like {Date}, {DateTime}, {Month}, {Year}, or other tokens that will be replaced during creation. Example: "EA-Baseline-{Year}-{Month}" or "Analytics-{Date}".

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### RemoveOldestBaseline
When enabled (default), automatically removes the oldest baseline if the maximum limit of 20 baselines is reached. Set to false to prevent automatic deletion and fail the runbook when the limit is reached.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |


[Back to Table of Content](../../../README.md)


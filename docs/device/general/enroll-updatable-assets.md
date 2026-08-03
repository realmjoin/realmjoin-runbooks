# Enroll Updatable Assets

Enroll device into Windows Update for Business

## Detailed description
This script enrolls a device into Windows Update for Business by registering it as an updatable asset for the specified update category.

## Where to find
Device \ General \ Enroll Updatable Assets

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - WindowsUpdates.ReadWrite.All


## Parameters
### DeviceId
DeviceId of the device to enroll.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### UpdateCategory
Category of updates to enroll into. Possible values are: Driver, Feature, Quality or All. Selecting All will enroll the device into all three categories sequentially.

| Property | Value |
|----------|-------|
| Default Value | Feature |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


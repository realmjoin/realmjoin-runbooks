# Restrict Or Release Code Execution

Restrict code execution.

## Detailed description
Only allow Microsoft signed code to be executed.

## Where to find
Device \ Security \ Restrict Or Release Code Execution

## Notes
Permissions (WindowsDefenderATP, Application):
- Machine.Read.All
- Machine.RestrictExecution

## Permissions
### Application permissions
- **Type**: WindowsDefenderATP
  - Machine.Read.All
  - Machine.RestrictExecution


## Parameters
### -DeviceId

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### -Release

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | true |
| Type | Boolean |

### -Comment

| Property | Value |
|----------|-------|
| Default Value | Possible security risk. |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


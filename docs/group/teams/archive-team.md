# Archive Team

Archive a team

## Detailed description
This runbook archives a Microsoft Teams team backed by the specified Microsoft 365 group.
It verifies that the group is provisioned as a team and then triggers the archive action via Microsoft Graph.
Use this to decommission inactive teams while preserving their contents for review.

## Where to find
Group \ Teams \ Archive Team

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - TeamSettings.ReadWrite.All


## Parameters
### GroupID
Object ID of the Microsoft 365 group that backs the team.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


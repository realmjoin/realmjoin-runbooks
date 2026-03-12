# Add Management Partner

List or add Management Partner Links (PAL)

## Detailed description
This runbook lists existing Partner Admin Links (PAL) for the tenant or adds a new PAL.
It uses the Azure Management Partner API and supports an interactive action selection.

## Where to find
Org \ General \ Add Management Partner

## Permissions
### Permission notes
Owner or Contributor role on the Azure Subscription


## Parameters
### Action
Choice of action to perform: list existing PALs or add a new PAL.

| Property | Value |
|----------|-------|
| Default Value | 0 |
| Required | true |
| Type | Int32 |

### PartnerId
Partner ID to set when adding a PAL.

| Property | Value |
|----------|-------|
| Default Value | 6457701 |
| Required | false |
| Type | Int32 |


[Back to Table of Content](../../../README.md)


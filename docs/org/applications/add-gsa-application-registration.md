# Add GSA Application Registration

Create a Global Secure Access application with its access group

## Detailed description
Creates a Global Secure Access (GSA) application in Entra ID with its application segment (destination, ports, protocol) and connector group, plus a security group that controls who may use it. If the application already exists, only the segment, group and assignment are updated. Everything is validated before anything is created, and objects created in a failed run are removed again.

## Where to find
Org \ Applications \ Add GSA Application Registration

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Application.ReadWrite.All
  - Directory.ReadWrite.All
  - Group.ReadWrite.All
  - AppRoleAssignment.ReadWrite.All


## Parameters
### name
Base name of the application. The final name is prefix plus name, for example GSA-MyApp.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### prefix
Text put in front of the name. A space is inserted unless the prefix ends with a hyphen, underscore or space.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### groupPrefix
Text put in front of the access group name, independent of the application prefix. Usually preset in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value | App - Entra - GSA - |
| Required | false |
| Type | String |

### groupSuffix
Text appended to the access group name, for example " (users)". Leave empty for none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### applicationType
Enterprise App creates a new GSA application. Quick Access App adds the segment to the tenant's existing Quick Access app instead.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### connectorGroup
Connector group that publishes the application. The available groups are set up in the runbook customization.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### destinationHost
Where the application lives: a host name (example.com), a single IP (192.168.0.1), a CIDR range (192.168.0.1/24) or an IP range (192.168.0.1..192.168.0.20).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### destinationType
Kind of destination, derived automatically from the format of the destination host.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ports
Ports to publish: a single port (443), several (80,443) or a range (8000-8080).

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### protocol
TCP, UDP or both.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


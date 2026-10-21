# Set Photo

Set the profile photo of this user from a URL

## Detailed description
Downloads a JPEG image from the given URL and sets it as the profile photo of this user. The photo shows up in Microsoft 365 apps such as Teams and Outlook. An existing photo is replaced.

## Where to find
User \ Userinfo \ Set Photo

## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - User.ReadWrite.All


## Parameters
### UserName
User principal name of the user the runbook acts on. Set by the portal from the selected user.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### PhotoURI
Web address of a JPEG image the runbook can download.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |


[Back to Table of Content](../../../README.md)


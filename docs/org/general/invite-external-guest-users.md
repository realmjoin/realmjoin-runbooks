# Invite External Guest Users

Invite an external person as a guest user

## Detailed description
Sends a Microsoft Entra ID guest invitation to an external email address. Optionally the guest is added to a group, and profile details such as name, company, usage location, manager and sponsor are set on the guest account right away. The invitation email and the landing page can be customized. Without the email, the job output shows the link the guest uses to accept the invitation.

## Where to find
Org \ General \ Invite External Guest Users

## Common use cases

- Basic guest invite: provide only the email address and the display name; all profile and group parameters can be left blank.
- Full onboarding: supply all optional fields to set profile properties, assign a manager and a sponsor, and add the guest to a group in a single run.

## Parameter interactions

- Profile properties (`givenName`, `surname`, `companyName`, `usageLocation`) are applied only when they are not empty; omitting them skips the update call entirely.
- Manager assignment, sponsor assignment and group membership each require their respective parameters; all of them are skipped silently when not provided.

## Invitation without email

When "Send the invitation email?" is turned off, Entra ID creates the guest account without sending an email, the same as clearing "Send invite message" in the Entra admin center. The guest stays in the state "pending acceptance" until the first sign-in.

- The job output shows the redemption link once, in the section "Invite Guest User". Pass it to the guest through another channel, for example your own email or a chat message.
- Instead of the redemption link, the guest can sign in through a link that contains your tenant, for example `https://myapps.microsoft.com/?tenantid=<tenant id>`. The consent prompt appears at the first sign-in.
- Guests who sign in with an alias of the invited address need the redemption link.
- The redirect URL from "Customize the invitation?" still applies: after accepting through the redemption link, the guest lands there.
- The invitation message is part of the email only and is not used without it.


## Permissions
### Application permissions
- **Type**: Microsoft Graph
  - Group.ReadWrite.All
  - Organization.Read.All
  - User.ReadWrite.All


## Parameters
### InvitedUserEmail
Email address of the person to invite.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | true |
| Type | String |

### InvitedUserDisplayName
Name shown for the guest in the directory.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GroupId
Group the guest is added to. Preset in the runbook customization; empty means none.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### GivenName
First name of the guest.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### Surname
Last name of the guest.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### CompanyName
Company the guest works for.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### ManagerName
User who becomes the guest's manager.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SponsorName
User recorded as the guest's sponsor.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### SendInvitationMessage
Emails the invitation to the guest. Without the email, the job output shows the link the guest uses to accept the invitation, to pass on by other means.

| Property | Value |
|----------|-------|
| Default Value | True |
| Required | false |
| Type | Boolean |

### CustomizeInvitation
Shows fields for an own invitation message and redirect URL.

| Property | Value |
|----------|-------|
| Default Value | False |
| Required | false |
| Type | Boolean |

### InvitationMessage
Text included in the invitation email. Not used when no invitation email is sent.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### InviteRedirectUrl
Page the guest lands on after accepting, for example a SharePoint site.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |

### UsageLocation
Two-letter country code, for example US or DE, needed before licenses can be assigned.

| Property | Value |
|----------|-------|
| Default Value |  |
| Required | false |
| Type | String |


[Back to Table of Content](../../../README.md)


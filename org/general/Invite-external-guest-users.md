## Common use cases

- Basic guest invite: provide only the email address and the display name; all profile and group parameters can be left blank.
- Full onboarding: supply all optional fields to set profile properties, assign a manager and a sponsor, and add the guest to a group in a single run.

## Parameter interactions

- Profile properties (`givenName`, `surname`, `companyName`, `usageLocation`) are applied only when they are not empty; omitting them skips the update call entirely.
- Manager assignment, sponsor assignment and group membership each require their respective parameters; all of them are skipped silently when not provided.
- The usage location must be a two-letter ISO 3166-1 country code, for example `GB` for the United Kingdom (not `UK`) and `GR` for Greece (not `EL`). An unknown code stops the run before the invitation is sent, so no guest account and no invitation email are created.

## Invitation without email

When "Send the invitation email?" is turned off, Entra ID creates the guest account without sending an email, the same as clearing "Send invite message" in the Entra admin center. The guest stays in the state "pending acceptance" until the first sign-in.

- The job output shows the redemption link once, in the section "Invite Guest User". Pass it to the guest through another channel, for example your own email or a chat message.
- Instead of the redemption link, the guest can sign in through a link that contains your tenant, for example `https://myapps.microsoft.com/?tenantid=<tenant id>`. The consent prompt appears at the first sign-in.
- Guests who sign in with an alias of the invited address need the redemption link.
- The redirect URL from "Customize the invitation?" still applies: after accepting through the redemption link, the guest lands there.
- The invitation message is part of the email only and is not used without it.

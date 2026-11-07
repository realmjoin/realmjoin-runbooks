## How it works

The auto attendant is looked up by its exact name. Upper and lower case do not matter. If no auto attendant matches, the runbook lists similar names it found; if two auto attendants share the same name, it stops and asks for unique names.

Before anything is changed, the runbook prints the current authorized users of the auto attendant with their voice applications policy, then the planned change per selected user. A user who cannot be found in Microsoft Teams, is not a regular user account or is not enabled for Enterprise Voice is skipped with the reason and the remaining users are still processed. Users who are already authorized (when adding) or not authorized at all (when removing) are reported and left alone.

Microsoft allows 15 authorized users per auto attendant. If the selection would push the auto attendant over that limit, the runbook stops before any change instead of applying part of it.

Auto attendants also keep a list of hidden authorized users. When an authorized user is removed, the runbook removes them from that list in the same write, so no entry is left dangling.

Teams PowerShell can only save an auto attendant as a whole. The runbook therefore reads the full configuration right before the change, replaces only the authorized users (and, on removal, the hidden authorized users) and saves it back. Greetings, call flows, schedules and the other settings stay as they are.

After the write, the auto attendant is read again and the resulting list is compared with the expected one. A mismatch is reported as a warning rather than an error, because the service applies the change asynchronously.

## Voice applications policy

Being an authorized user is only half of the permission. To actually change auto attendant settings in Teams, the user also needs a Teams voice applications policy that allows the auto attendant changes, for example the business hours, after hours or holiday greetings. The Global policy usually does not, which is why the runbook warns about it when it adds an authorized user who has no policy of their own.

The policy field offers three options:

- **Leave the policy unchanged** does not touch any policy assignment.
- **Assign a voice applications policy** grants the named policy to every user that was added or was already authorized. The policy has to exist in the tenant; the name is checked before any change is made. A user who already uses that policy is reported and not touched again.
- **Remove the voice applications policy** resets the per-user assignment of every user that was taken off the list.

Assigning a policy is only offered together with adding users, removing one only together with removing users. The other two combinations are rejected right away, because they would change permissions in the opposite direction of the auto attendant change.

A policy that reaches the user through a group policy assignment cannot be removed per user. The runbook reports the policy and the group instead, so the assignment can be changed where it comes from. If a user has both a direct and a group assignment, removing the direct one lets the group assignment take over; the runbook says so in the output.

Before removing a policy, the runbook scans all other auto attendants and all call queues for that user. If the user is still an authorized user somewhere else, the policy is kept and the affected objects are named in a warning. The user is still removed from this auto attendant.

## Output Data

At the end of every run the results are listed in the Output Data tab, one table per outcome:

- **Authorized user changes**: users that were added or removed, with their voice applications policy and what happened to it.
- **Skipped users**: users that could not be processed, with the reason.
- **No change needed**: users that were already authorized when adding, or not authorized when removing.
- **Authorized users**: the authorized users of the auto attendant after the run, with their policy and whether they are hidden.

A table only appears when it has rows.

## Notes and limitations

Authorized users have to be enabled for Enterprise Voice, which in practice means a Teams Phone license. A freshly licensed user can take up to an hour to become visible to Teams PowerShell; until then the runbook reports them as not found.

Greetings can be changed by authorized users directly in the Teams desktop client; the new options show up after they sign out and sign in again. Changing the call routing for business hours, after hours and holidays requires the Queues app, which needs a Teams Premium license for every user of the app. The runbook only grants the permission and does not check the licensing of the app.

Changes to authorized users and policy assignments are replicated by the service and can take a few minutes to show up in the Teams admin center and in the Teams client.

Whether an authorized user is hidden is only maintained, never changed on purpose. Hiding or unhiding an authorized user is only possible with Teams PowerShell (`Set-CsAutoAttendant`), not in the Teams admin center.

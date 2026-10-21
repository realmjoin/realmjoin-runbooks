## Booking modes

"Who may book the room" and the fields shown with "Restricted" decide what happens to a meeting request:

- **Everyone** - every user books the room directly; the request is accepted when the room is free.
- **Restricted with a booking group** - members of the "Booking group" book directly. Requests from everyone else are declined.
- **Restricted with "Let everyone else request the room?"** - requests from users outside the booking group go to the booking delegates, who approve or decline them. Leave the "Booking group" empty when the booking delegates decide every request. This is the same as the option "Select delegates who can accept or decline booking requests" in the Exchange admin center.

Booking delegates get requests only with the request processing "Auto accept". With "Auto update" Exchange marks requests as tentative and sends nothing to the delegates. The runbook warns about both cases and about a run that switches off an existing delegate approval.

## Booking delegates

- A booking delegate approves or declines requests for the room in their own mailbox. They need no full access to the room mailbox; Exchange grants them Send on Behalf on its own. Grant full access with the runbook "Delegate Full Access" only when someone has to work in the room mailbox itself.
- "Booking delegate change" decides what happens with the users selected in "Booking delegates": Add keeps the current delegates and adds the selected ones, Replace makes the selected users the only delegates, Remove takes them off the list. With no users selected the delegates stay as they are.
- Users without a mailbox are skipped with a warning. Current delegates whose name does not resolve to exactly one recipient are kept unchanged.
- The runbook "List Room Mailbox Configuration" shows the current booking delegates, the booking group and the request settings of a room.

## Notes and limitations

- Every run writes all booking rules as shown in the dialog. Running the runbook only to change the capacity therefore also resets "Who may book the room" to the selected option.
- An empty "Booking group" keeps the current group; the runbook cannot clear it.
- Tenant-wide defaults for the booking rules can be set as RealmJoin settings: `RoomMailbox.AllBookInPolicy`, `RoomMailbox.AllRequestInPolicy`, `RoomMailbox.AllowRecurringMeetings`, `RoomMailbox.AutomateProcessing`, `RoomMailbox.BookingWindowInDays`, `RoomMailbox.MaximumDurationInMinutes` and `RoomMailbox.AllowConflicts`. A field with a setting is shown read-only in the dialog. See [Settings](https://docs.realmjoin.com/automation/runbooks/runbook-customization#settings) in the Runbook Customization Guide.

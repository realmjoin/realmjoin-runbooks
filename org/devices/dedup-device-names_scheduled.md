## Common use cases

- Schedule the runbook weekly to resolve duplicate device names that arise from re-enrollment, OS reimaging or cloning workflows automatically.
- The Autopilot sync path is idempotent, so unique devices are normalized in Autopilot as well, also on the first run.

## Parameter interactions

- `NameLength` must be strictly greater than the number of characters in `NamePrefix`. The difference determines how many random digits are appended; for example, `NamePrefix` "CORP" with `NameLength` 8 produces names like "CORP4271".
- The runbook validates this constraint at startup and fails fast when it is violated.

## Behaviour

Autopilot display name changes made via `updateDeviceProperties` take effect at the next device sync and may not be reflected in the portal immediately.

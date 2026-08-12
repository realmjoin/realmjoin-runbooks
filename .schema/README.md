# Permissions File Schema

Every runbook has a companion `<runbook-name>.permissions.json` in the same folder describing the permissions it needs. These files follow the JSON Schema in [permissions.schema.json](./permissions.schema.json) (schema version 2).

VS Code picks up the schema automatically via the workspace settings ([.vscode/settings.json](../.vscode/settings.json)) and provides autocompletion and live validation. The PR validation workflow additionally validates the content of changed permission files against the schema.

## Structure

```json
{
    "SchemaVersion": 2,
    "Permissions": [
        {
            "Name": "Microsoft Graph",
            "Id": "00000003-0000-0000-c000-000000000000",
            "AppRoleAssignments": [
                "User.Read.All",
                {
                    "Value": "Mail.Send",
                    "Optional": true,
                    "Feature": "Email report",
                    "Reason": "Only required when the optional email notification of this runbook is configured"
                }
            ]
        }
    ],
    "Roles": [
        {
            "Name": "User Administrator",
            "TemplateId": "fe930be7-5e62-47db-91af-98c3a49a38b1"
        }
    ],
    "ManualPermissions": []
}
```

- **`SchemaVersion`** — always `2`. Bump only happens together with a schema change in this folder.
- **`Permissions`** — API permissions (app role assignments) per resource application, granted to the Automation Account's managed identity.
  - A **plain string** entry is a required permission.
  - Use the **object form** to mark a permission as `Optional` (only needed when a specific runbook feature is used — name it in `Feature`) or to document a `Reason`. Optional permissions can be skipped in environments that do not use the feature.
- **`Roles`** — Microsoft Entra directory roles. Always use the object form with the display name and the tenant-stable `TemplateId` ([role template IDs](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference)).
- **`ManualPermissions`** — free-text entries for permissions that cannot be assigned automatically (for example Azure RBAC roles on customer resources or third-party prerequisites).

## Notes for authors

- Keep every runbook's permission list minimal: only what the runbook actually calls.
- When you add an optional feature to a runbook (for example an email report that is only sent when a recipient is configured), add the extra permission in the object form with `Optional: true` so it shows up as optional in the generated documentation.
- The aggregated permission export (`Get-UniquePermissions.ps1`) intentionally flattens everything to the complete permission set, including optional entries.

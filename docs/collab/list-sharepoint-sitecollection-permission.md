## Setup regarding SharePoint access

This runbook connects to SharePoint Online with the Azure Automation account's system-assigned managed identity. The required `Sites.FullControl.All` application permission on the **Office 365 SharePoint Online** API is a SharePoint app-only grant that cannot be assigned through the standard Microsoft Graph permission automation - assign it once to the managed identity with Microsoft Graph PowerShell (requires a Global Administrator or Privileged Role Administrator):

```powershell
Connect-MgGraph -Scopes "AppRoleAssignment.ReadWrite.All", "Application.Read.All"

$managedIdentity = Get-MgServicePrincipal -Filter "displayName eq '<automation-account-name>'"
$sharePointApi   = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0ff1-ce00-000000000000'"
$appRole         = $sharePointApi.AppRoles | Where-Object { $_.Value -eq "Sites.FullControl.All" }

New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentity.Id `
    -PrincipalId $managedIdentity.Id -ResourceId $sharePointApi.Id -AppRoleId $appRole.Id
```

A lower privilege such as `Sites.Read.All` is enough to connect and read the site, but listing the site collection administrators needs full-control access - with a read-only grant the runbook connects successfully and then fails on the administrator query.

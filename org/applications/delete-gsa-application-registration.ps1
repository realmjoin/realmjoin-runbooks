<#

.SYNOPSIS
    Delete a GSA application registration from Azure AD including associated objects

.DESCRIPTION
    This runbook deletes a Global Secure Access application registration created by the
    "add-gsa-application-registration" runbook, including everything provisioned with it:
    the application (and thereby its service principal, application segments and connector
    group assignment) and the security group created by the naming scheme.

    The naming scheme group is identified via the groups assigned to the application whose
    display name matches the admin-defined group prefix. If the group was created but never
    assigned (partial provisioning), a best-effort lookup by naming scheme is performed.

    Safety measures:
    - The runbook verifies the application is actually a GSA / App Proxy application
      (onPremisesPublishing) before deleting anything.
    - By default only security group(s) matching the naming scheme are deleted. Other
      groups assigned to the application are listed but NOT deleted, as they may be
      shared with other applications. Set deleteAllAssignedGroups to change this.

.PARAMETER applicationName
    The full display name of the GSA application to delete, e.g. "GSA-MyApp".

.PARAMETER groupPrefix
    Prefix of the security group naming scheme, used to identify the group(s) to delete.
    Must match the groupPrefix of the add-gsa-application-registration runbook.
    Default: "App - Entra - GSA - ".

.PARAMETER groupSuffix
    Optional suffix of the security group naming scheme. Default: empty.

.PARAMETER deleteAllAssignedGroups
    If true, ALL groups assigned to the application are deleted, not only the naming scheme group(s).
    Use with care - assigned groups may be shared with other applications. Default: false.

.PARAMETER CallerName
    Caller name for auditing purposes.

.INPUTS
    RunbookCustomization: {
    "Parameters": {
        "applicationName": {
            "DisplayName": "Application Name (full display name, e.g. GSA-MyApp)",
            "Hide": false
        },
        "groupPrefix": {
            "Default": "App - Entra - GSA - ",
            "Hide": true
        },
        "groupSuffix": {
            "Default": "",
            "Hide": true
        },
        "deleteAllAssignedGroups": {
            "DisplayName": "Also delete ALL other groups assigned to the application (careful - groups may be shared)",
            "Default": false,
            "Hide": false
        },
        "CallerName": {
            "Hide": true
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.38.0" }

param(
    [Parameter(Mandatory = $true)]
    [string] $applicationName,
    [string] $groupPrefix = "App - Entra - GSA - ",
    [string] $groupSuffix = "",
    [bool] $deleteAllAssignedGroups = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
##
########################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.2.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

#endregion

########################################################
#region     Connect Part
##
########################################################

Connect-MgGraph -Identity -NoWelcome

#endregion

########################################################
#region     Resolve Application Part
##
########################################################

# Validate input - invalid characters (e.g. quotes) would break the Graph queries
if ($applicationName -notmatch '^[a-zA-Z0-9-_ ]+$') {
    throw "Application name '$applicationName' contains invalid characters. Only letters, numbers, blanks, hyphens, and underscores are allowed."
}

"## Application name: '$applicationName'"

# Find the application by display name
$existingApp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=displayName eq '$applicationName'" -ContentType "application/json" -ErrorAction Stop

if (-not $existingApp.value -or $existingApp.value.Count -eq 0) {
    throw "Application '$applicationName' does not exist. Nothing was deleted."
}
if ($existingApp.value.Count -gt 1) {
    throw "Multiple applications found with display name '$applicationName'. Please clean up manually to avoid deleting the wrong application. Nothing was deleted."
}

$applicationId = $existingApp.value[0].id
$appId = $existingApp.value[0].appId
"## Found application '$applicationName', id: $applicationId, appId: $appId"

# Safety check: verify this is a GSA / App Proxy application before deleting anything
$isGsaApp = $false
try {
    $betaApp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/applications/$applicationId`?`$select=onPremisesPublishing" -ErrorAction Stop
    if ($betaApp.onPremisesPublishing -and $betaApp.onPremisesPublishing.applicationType) {
        $isGsaApp = $true
        "## Verified GSA application, type: $($betaApp.onPremisesPublishing.applicationType)"
    }
}
catch {
    Write-RjRbLog -Message "Could not read onPremisesPublishing: $_" -Verbose
}

if (-not $isGsaApp) {
    throw "Application '$applicationName' does not appear to be a GSA / App Proxy application (no onPremisesPublishing configuration). Deletion aborted as a safety measure - use the generic 'delete-application-registration' runbook instead."
}

#endregion

########################################################
#region     Collect Assigned Groups Part
##
########################################################

$assignedGroups = @()
$spResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$appId'" -ContentType "application/json" -ErrorAction Stop
if ($spResponse.value -and $spResponse.value.Count -gt 0) {
    $servicePrincipalId = $spResponse.value[0].id
    $existingAssignments = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$servicePrincipalId/appRoleAssignedTo" -ErrorAction Stop
    $assignedGroups = @($existingAssignments.value | Where-Object { $_.principalType -eq "Group" })
}
else {
    "## No service principal found for application '$applicationName'."
}

# Split assigned groups into naming scheme group(s) vs. others.
# A scheme group starts with the admin-defined groupPrefix (and ends with groupSuffix, if set).
$schemeGroups = @($assignedGroups | Where-Object {
        $_.principalDisplayName -like "$groupPrefix*" -and
        ([string]::IsNullOrEmpty($groupSuffix) -or $_.principalDisplayName -like "*$groupSuffix")
    })
$otherGroups = @($assignedGroups | Where-Object { $schemeGroups -notcontains $_ })

#endregion

########################################################
#region     Deletion Part
##
########################################################

# Delete the application first (this also removes the service principal,
# application segments, connector group assignment and app role assignments)
"## Deleting the application '$applicationName'"
Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/applications/$applicationId" -ErrorAction Stop
"## Application '$applicationName' deleted (moved to deleted items)"

# Delete the naming scheme group(s) that were assigned to the app
foreach ($group in $schemeGroups) {
    try {
        Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/groups/$($group.principalId)" -ErrorAction Stop
        "## Deleted group '$($group.principalDisplayName)' (id: $($group.principalId))"
    }
    catch {
        Write-Warning "Failed to delete group '$($group.principalDisplayName)' (id: $($group.principalId)): $_ - please remove it manually."
    }
}

# The naming scheme group may exist without being assigned (e.g. partial provisioning).
# Best-effort lookup: find groups starting with the groupPrefix whose base name matches
# the end of the application name (the app prefix is unknown here).
if ($schemeGroups.Count -eq 0) {
    # groupPrefix comes from Runbook Customization - escape single quotes for the OData filter.
    # Follow paging in case many groups share the prefix.
    $groupPrefixEscaped = $groupPrefix -replace "'", "''"
    $uri = "https://graph.microsoft.com/v1.0/groups?`$filter=startswith(displayName,'$groupPrefixEscaped')&`$select=id,displayName&`$top=999"
    $candidateGroups = @()
    do {
        $page = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
        $candidateGroups += $page.value
        $uri = $page.'@odata.nextLink'
    } while ($uri)
    $orphanGroups = @($candidateGroups | Where-Object {
            $baseName = $_.displayName.Substring($groupPrefix.Length)
            if (![string]::IsNullOrEmpty($groupSuffix) -and $baseName.EndsWith($groupSuffix)) {
                $baseName = $baseName.Substring(0, $baseName.Length - $groupSuffix.Length)
            }
            (![string]::IsNullOrWhiteSpace($baseName)) -and $applicationName.EndsWith($baseName)
        })

    if ($orphanGroups.Count -gt 0) {
        foreach ($group in $orphanGroups) {
            try {
                Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/groups/$($group.id)" -ErrorAction Stop
                "## Deleted (unassigned) naming scheme group '$($group.displayName)' (id: $($group.id))"
            }
            catch {
                Write-Warning "Failed to delete group '$($group.displayName)' (id: $($group.id)): $_ - please remove it manually."
            }
        }
    }
    else {
        "## No naming scheme group matching prefix '$groupPrefix' found for this application - nothing to delete."
    }
}

# Handle other assigned groups
if ($otherGroups.Count -gt 0) {
    if ($deleteAllAssignedGroups) {
        "## Deleting all other assigned groups (deleteAllAssignedGroups = true)"
        foreach ($group in $otherGroups) {
            try {
                Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/groups/$($group.principalId)" -ErrorAction Stop
                "## Deleted group '$($group.principalDisplayName)' (id: $($group.principalId))"
            }
            catch {
                Write-Warning "Failed to delete group '$($group.principalDisplayName)' (id: $($group.principalId)): $_ - please remove it manually."
            }
        }
    }
    else {
        "## The following assigned groups were NOT deleted (they may be shared with other applications):"
        foreach ($group in $otherGroups) {
            "## - '$($group.principalDisplayName)' (id: $($group.principalId))"
        }
        "## Re-run with 'deleteAllAssignedGroups' enabled to delete them as well."
    }
}

"## Cleanup of GSA application '$applicationName' completed."

#endregion

<#
.SYNOPSIS
Add or remove sponsors or owners on agent identities and blueprints
.DESCRIPTION
Revalidates the typed target and every directory object, enforces owner and sponsor object-type restrictions, checks sponsor-group eligibility, and changes the selected relationship through the current v1.0 typed cast endpoint.
.PARAMETER TargetKind
Target resource type: Identity or Blueprint.
.PARAMETER TargetObjectId
Object ID of the target service principal (Identity) or application (Blueprint).
.PARAMETER Relationship
Relationship to change: Sponsor or Owner.
.PARAMETER Action
Operation to perform: Add or Remove.
.PARAMETER DirectoryObjectIds
Comma-separated directory object IDs to add or remove.
.PARAMETER CallerName
Name of the user or system that started the runbook. Used for auditing.
.OUTPUTS
Named raw-object tables for the RealmJoin Output Data tab. Summary rows remain available when no
detail rows match. Console progress, warnings, and errors remain separate from table data.
.INPUTS
RunbookCustomization: {
  "Parameters": {
    "TargetKind": {
      "DisplayName": "Target kind",
      "Description": "Target resource type: Identity or Blueprint.",
      "SelectSimple": {
        "Identity": "Identity",
        "Blueprint": "Blueprint"
      }
    },
    "TargetObjectId": {
      "DisplayName": "Target object ID",
      "Description": "Object ID of the target service principal (Identity) or application (Blueprint)."
    },
    "Relationship": {
      "DisplayName": "Relationship",
      "Description": "Relationship to change: Sponsor or Owner.",
      "SelectSimple": {
        "Sponsor": "Sponsor",
        "Owner": "Owner"
      }
    },
    "Action": {
      "DisplayName": "Action",
      "Description": "Operation to perform: Add or Remove.",
      "SelectSimple": {
        "Add": "Add",
        "Remove": "Remove"
      }
    },
    "DirectoryObjectIds": {
      "DisplayName": "Directory object IDs (comma-separated)",
      "Description": "Comma-separated directory object IDs to add or remove."
    },
    "CallerName": {
      "Hide": true,
      "Description": "Name of the user or system that started the runbook. Used for auditing."
    }
  }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }

param(
    [Parameter(Mandatory = $true)][ValidateSet("Identity", "Blueprint")][string]$TargetKind,
    [Parameter(Mandatory = $true)][ValidatePattern("^[0-9a-fA-F-]{36}$")][string]$TargetObjectId,
    [Parameter(Mandatory = $true)][ValidateSet("Sponsor", "Owner")][string]$Relationship,
    [Parameter(Mandatory = $true)][ValidateSet("Add", "Remove")][string]$Action,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$DirectoryObjectIds,
    [Parameter(Mandatory = $true)][string]$CallerName
)

$ErrorActionPreference = "Stop"
$graph = "https://graph.microsoft.com/v1.0"
$headers = @{ "OData-Version" = "4.0"; "Content-Type" = "application/json" }
function Invoke-Graph {
    param([string]$Uri, [ValidateSet("GET", "POST", "DELETE")][string]$Method = "GET", [hashtable]$Body)
    $a = @{ Uri = $Uri; Method = $Method; Headers = $headers; ErrorAction = "Stop" }
    if ($Body) { $a.Body = ($Body | ConvertTo-Json -Depth 6 -Compress) }
    Invoke-MgGraphRequest @a
}
function Get-Paged {
    param([string]$Uri)
    $items = [System.Collections.Generic.List[object]]::new()
    while ($Uri) {
        $page = Invoke-Graph -Uri $Uri
        foreach ($item in @($page.value)) { $items.Add($item) }
        $Uri = $page.'@odata.nextLink'
    }
    return $items
}

try {
    Write-RjRbLog -Message "Caller: '$CallerName'; $Action $Relationship on $TargetKind '$TargetObjectId'." -Verbose
    Connect-MgGraph -Identity -NoWelcome | Out-Null
    $castBase = if ($TargetKind -eq "Identity") {
        [void](Invoke-Graph -Uri "$graph/servicePrincipals/$TargetObjectId/microsoft.graph.agentIdentity?`$select=id,displayName")
        "$graph/servicePrincipals/$TargetObjectId/microsoft.graph.agentIdentity"
    } else {
        [void](Invoke-Graph -Uri "$graph/applications/$TargetObjectId/microsoft.graph.agentIdentityBlueprint?`$select=id,displayName")
        "$graph/applications/$TargetObjectId/microsoft.graph.agentIdentityBlueprint"
    }
    $relationshipName = if ($Relationship -eq "Sponsor") { "sponsors" } else { "owners" }
    $current = @(Get-Paged -Uri "${castBase}/${relationshipName}?`$select=id,displayName")
    $ids = @($DirectoryObjectIds -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($id in $ids) {
        $object = Invoke-Graph -Uri "$graph/directoryObjects/$id"
        $type = $object.'@odata.type'
        if ($Relationship -eq "Owner" -and $type -notin @("#microsoft.graph.user", "#microsoft.graph.servicePrincipal")) {
            throw "Owner '$id' has unsupported type '$type'. Groups aren't allowed as owners."
        }
        if ($Relationship -eq "Sponsor") {
            if ($type -notin @("#microsoft.graph.user", "#microsoft.graph.group")) { throw "Sponsor '$id' has unsupported type '$type'." }
            if ($type -eq "#microsoft.graph.group") {
                $group = Invoke-Graph -Uri "$graph/groups/${id}?`$select=id,displayName,groupTypes,membershipRule,isAssignableToRole"
                $eligible = ($group.groupTypes -contains "Unified") -or -not [string]::IsNullOrWhiteSpace($group.membershipRule)
                if ($group.isAssignableToRole -or -not $eligible) { throw "Sponsor group '$($group.displayName)' isn't eligible. It must be Microsoft 365 or dynamic and not role-assignable." }
            }
        }

        $alreadyPresent = $id -in @($current.id)
        if (($Action -eq "Add" -and $alreadyPresent) -or ($Action -eq "Remove" -and -not $alreadyPresent)) {
            $results.Add([pscustomobject]@{ ObjectId = $id; Status = "NoChange"; Reason = if ($alreadyPresent) { "Already assigned" } else { "Not assigned" } })
            continue
        }
        if ($Action -eq "Remove" -and $Relationship -eq "Sponsor" -and $current.Count -le 1) { throw "Refusing to remove the final sponsor." }
        if ($Action -eq "Add") {
            [void](Invoke-Graph -Uri "$castBase/$relationshipName/`$ref" -Method POST -Body @{ "@odata.id" = "$graph/directoryObjects/$id" })
            $current += $object
        } else {
            [void](Invoke-Graph -Uri "$castBase/$relationshipName/$id/`$ref" -Method DELETE)
            $current = @($current | Where-Object { $_.id -ne $id })
        }
        $results.Add([pscustomobject]@{ ObjectId = $id; Status = $Action; Relationship = $Relationship; TargetKind = $TargetKind })
    }
    [PSCustomObject]@{ RjTableTitle = 'Relationship update summary' }
    [PSCustomObject]@{ TargetObjectId = $TargetObjectId; TargetKind = $TargetKind; Relationship = $Relationship; Action = $Action; ResultCount = $results.Count }
    [PSCustomObject]@{ RjTableTitle = 'Relationship updates' }
    $results | Select-Object ObjectId, Status, Reason, Relationship, TargetKind
}
catch {
    Write-Error "Relationship update failed: $($_.Exception.Message)"
    throw
}
finally { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null }

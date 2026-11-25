<#
.SYNOPSIS
Transfer direct agent identity and blueprint sponsorships
.DESCRIPTION
Enumerates Agent Identities and blueprints with pagination, finds sponsorship references held by the source user, and reports them by default. Execute mode requires explicit confirmation, revalidates each typed object and both users, adds the target first, removes the source second, enforces a cap, and is idempotent.
.PARAMETER SourceUserObjectId
Object ID of the user whose sponsorship references are being transferred.
.PARAMETER TargetUserObjectId
Object ID of the user receiving sponsorship references.
.PARAMETER SelectedTargetObjectIds
Optional comma-separated Agent Identity or blueprint object IDs. Leave empty to consider all discovered references.
.PARAMETER Execute
When false, produces a report only. Set true to request changes.
.PARAMETER ConfirmExecute
Second interlock that must be true with Execute.
.PARAMETER MaxChanges
Maximum number of objects changed in one execution.
.PARAMETER CallerName
Name of the user or system that started the runbook. Used for auditing.
.OUTPUTS
Named raw-object tables for the RealmJoin Output Data tab. Summary rows remain available when no
detail rows match. Console progress, warnings, and errors remain separate from table data.
.INPUTS
RunbookCustomization: {
  "Parameters": {
    "SourceUserObjectId": {
      "DisplayName": "Source user object ID",
      "Description": "Object ID of the user whose sponsorship references are being transferred."
    },
    "TargetUserObjectId": {
      "DisplayName": "Target user object ID",
      "Description": "Object ID of the user receiving sponsorship references."
    },
    "SelectedTargetObjectIds": {
      "DisplayName": "Selected identity/blueprint object IDs (optional)",
      "Description": "Optional comma-separated Agent Identity or blueprint object IDs. Leave empty to consider all discovered references."
    },
    "Execute": {
      "DisplayName": "Execute transfer",
      "Description": "When false, produces a report only. Set true to request changes.",
      "Select": {
        "Options": [
          {
            "Display": "Report only",
            "ParameterValue": false,
            "Customization": {
              "Default": {
                "ConfirmExecute": false
              },
              "Hide": [
                "ConfirmExecute",
                "MaxChanges"
              ]
            }
          },
          {
            "Display": "Transfer sponsorships",
            "ParameterValue": true,
            "Customization": {
              "Show": [
                "ConfirmExecute",
                "MaxChanges"
              ],
              "Mandatory": [
                "ConfirmExecute"
              ]
            }
          }
        ],
        "ShowValue": false
      }
    },
    "ConfirmExecute": {
      "DisplayName": "Confirm transfer execution",
      "Description": "Second interlock that must be true with Execute."
    },
    "MaxChanges": {
      "DisplayName": "Maximum objects to change",
      "Description": "Maximum number of objects changed in one execution."
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
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Source sponsor" } )]
    [ValidatePattern("^[0-9a-fA-F-]{36}$")][string]$SourceUserObjectId,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Target sponsor" } )]
    [ValidatePattern("^[0-9a-fA-F-]{36}$")][string]$TargetUserObjectId,
    [string]$SelectedTargetObjectIds = "",
    [bool]$Execute = $false,
    [bool]$ConfirmExecute = $false,
    [ValidateRange(1, 100)][int]$MaxChanges = 20,
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
    Write-RjRbLog -Message "Caller: '$CallerName'; sponsorship transfer report/execute requested." -Verbose
    if ($SourceUserObjectId -eq $TargetUserObjectId) { throw "Source and target users must differ." }
    if ($Execute -and -not $ConfirmExecute) { throw "Execute mode requires ConfirmExecute=true." }
    Connect-MgGraph -Identity -NoWelcome | Out-Null
    $source = Invoke-Graph -Uri "$graph/users/${SourceUserObjectId}?`$select=id,displayName,userPrincipalName"
    $target = Invoke-Graph -Uri "$graph/users/${TargetUserObjectId}?`$select=id,displayName,userPrincipalName"
    $selected = @($SelectedTargetObjectIds -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)

    $objects = [System.Collections.Generic.List[object]]::new()
    foreach ($identity in @(Get-Paged -Uri "$graph/servicePrincipals/microsoft.graph.agentIdentity?`$select=id,displayName")) {
        $objects.Add([pscustomobject]@{ Kind = "Identity"; Id = $identity.id; DisplayName = $identity.displayName; Base = "$graph/servicePrincipals/$($identity.id)/microsoft.graph.agentIdentity" })
    }
    foreach ($blueprint in @(Get-Paged -Uri "$graph/applications/microsoft.graph.agentIdentityBlueprint?`$select=id,displayName")) {
        $objects.Add([pscustomobject]@{ Kind = "Blueprint"; Id = $blueprint.id; DisplayName = $blueprint.displayName; Base = "$graph/applications/$($blueprint.id)/microsoft.graph.agentIdentityBlueprint" })
    }
    if ($selected.Count -gt 0) {
        $filteredObjects = [System.Collections.Generic.List[object]]::new()
        foreach ($object in @($objects | Where-Object { $_.Id -in $selected })) { $filteredObjects.Add($object) }
        $objects = $filteredObjects
    }

    $candidates = [System.Collections.Generic.List[object]]::new()
    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($object in $objects) {
        $sponsors = $null
        try { $sponsors = @(Get-Paged -Uri "$($object.Base)/sponsors?`$select=id,displayName") }
        catch {
            $results.Add([pscustomobject]@{ Mode = if ($Execute) { "Execute" } else { "ReportOnly" }; Kind = $object.Kind; ObjectId = $object.Id; DisplayName = $object.DisplayName; Status = "Unknown (sponsor lookup failed)"; Reason = $_.Exception.Message })
            continue
        }
        if ($SourceUserObjectId -in @($sponsors.id)) {
            $candidates.Add([pscustomobject]@{
                Kind = $object.Kind
                ObjectId = $object.Id
                DisplayName = $object.DisplayName
                TargetAlreadySponsor = $TargetUserObjectId -in @($sponsors.id)
                SponsorCount = $sponsors.Count
                Base = $object.Base
            })
        }
    }
    if ($Execute -and $candidates.Count -gt $MaxChanges) { throw "Found $($candidates.Count) candidates, exceeding MaxChanges=$MaxChanges. Narrow SelectedTargetObjectIds or raise the cap deliberately." }

    [PSCustomObject]@{ RjTableTitle = 'Transfer summary' }
    [PSCustomObject]@{ SourceUserId = $SourceUserObjectId; TargetUserId = $TargetUserObjectId; Mode = if ($Execute) { 'Execute' } else { 'ReportOnly' }; Candidates = $candidates.Count; MaxChanges = $MaxChanges }
    foreach ($candidate in $candidates) {
        if (-not $Execute) {
            $results.Add([pscustomobject]@{ Mode = "ReportOnly"; Kind = $candidate.Kind; ObjectId = $candidate.ObjectId; DisplayName = $candidate.DisplayName; Status = 'WouldTransfer'; TargetAlreadySponsor = $candidate.TargetAlreadySponsor })
            continue
        }
        # Each candidate is isolated: a Graph rejection (for example the documented 100-sponsor / 5-group limits)
        # is reported for that object and must not abort the remaining transfers.
        try {
            [void](Invoke-Graph -Uri "$graph/users/${SourceUserObjectId}?`$select=id")
            [void](Invoke-Graph -Uri "$graph/users/${TargetUserObjectId}?`$select=id")
            [void](Invoke-Graph -Uri "$($candidate.Base)?`$select=id,displayName")
            $current = @(Get-Paged -Uri "$($candidate.Base)/sponsors?`$select=id")
            if ($SourceUserObjectId -notin @($current.id)) {
                $results.Add([pscustomobject]@{ Mode = "Execute"; Kind = $candidate.Kind; ObjectId = $candidate.ObjectId; DisplayName = $candidate.DisplayName; Status = "NoChange"; Reason = "Source no longer sponsors this object." })
                continue
            }
            if ($TargetUserObjectId -notin @($current.id)) {
                [void](Invoke-Graph -Uri "$($candidate.Base)/sponsors/`$ref" -Method POST -Body @{ "@odata.id" = "$graph/directoryObjects/$TargetUserObjectId" })
                $afterAdd = @(Get-Paged -Uri "$($candidate.Base)/sponsors?`$select=id")
                if ($TargetUserObjectId -notin @($afterAdd.id)) {
                    $results.Add([pscustomobject]@{ Mode = "Execute"; Kind = $candidate.Kind; ObjectId = $candidate.ObjectId; DisplayName = $candidate.DisplayName; Status = "Blocked"; Reason = "Target sponsor add could not be verified; source sponsor left in place." })
                    continue
                }
            }
            [void](Invoke-Graph -Uri "$($candidate.Base)/sponsors/$SourceUserObjectId/`$ref" -Method DELETE)
            $results.Add([pscustomobject]@{ Mode = "Execute"; Kind = $candidate.Kind; ObjectId = $candidate.ObjectId; DisplayName = $candidate.DisplayName; Status = "Transferred"; Source = $source.userPrincipalName; Target = $target.userPrincipalName })
        }
        catch {
            $results.Add([pscustomobject]@{ Mode = "Execute"; Kind = $candidate.Kind; ObjectId = $candidate.ObjectId; DisplayName = $candidate.DisplayName; Status = "Failed safely"; Reason = $_.Exception.Message })
        }
    }
    [PSCustomObject]@{ RjTableTitle = 'Sponsorship transfer results' }
    $results | Select-Object Mode, Kind, ObjectId, DisplayName, Status, Reason, TargetAlreadySponsor, Source, Target
}
catch {
    Write-Error "Sponsorship transfer failed: $($_.Exception.Message)"
    throw
}
finally { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null }

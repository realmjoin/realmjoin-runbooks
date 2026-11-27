<#
.SYNOPSIS
Create an Entra agent identity blueprint and its principal
.DESCRIPTION
Creates an agent identity blueprint through the v1.0 typed application endpoint, waits for directory propagation, and creates the associated blueprint principal through the typed service principal endpoint. Sponsors are mandatory. Optional owners, manager applications, tags, and description are validated and added when supplied.
.PARAMETER DisplayName
Display name for the new agent identity blueprint.
.PARAMETER SponsorObjectIds
Comma-separated directory object IDs of user or supported group sponsors. At least one is required.
.PARAMETER OwnerObjectIds
Optional comma-separated user or service principal object IDs to assign as owners. Groups aren't accepted as owners.
.PARAMETER ManagerApplicationAppIds
Optional comma-separated application (client) IDs that manage the blueprint. Agent ID stores these as a GUID collection, not as directory-object references.
.PARAMETER Tags
Optional comma-separated blueprint tags.
.PARAMETER Description
Optional blueprint description.
.PARAMETER MaxRetryAttempts
Maximum attempts while waiting for the blueprint to become visible to blueprint-principal creation.
.PARAMETER CallerName
Name of the user or system that started the runbook. Used for auditing.
.OUTPUTS
Named raw-object tables for the RealmJoin Output Data tab. Summary rows remain available when no
detail rows match. Console progress, warnings, and errors remain separate from table data.
.INPUTS
RunbookCustomization: {
  "Parameters": {
    "DisplayName": {
      "DisplayName": "Blueprint display name",
      "Description": "Display name for the new agent identity blueprint."
    },
    "SponsorObjectIds": {
      "DisplayName": "Sponsor object IDs (comma-separated)",
      "Description": "Comma-separated directory object IDs of user or supported group sponsors. At least one is required."
    },
    "OwnerObjectIds": {
      "DisplayName": "Owner object IDs (optional)",
      "Description": "Optional comma-separated user or service principal object IDs to assign as owners. Groups aren't accepted as owners."
    },
    "ManagerApplicationAppIds": {
      "DisplayName": "Manager application client IDs (optional)",
      "Description": "Optional comma-separated application (client) IDs that manage the blueprint. Agent ID stores these as a GUID collection, not as directory-object references."
    },
    "Tags": {
      "DisplayName": "Tags (optional, comma-separated)",
      "Description": "Optional comma-separated blueprint tags."
    },
    "Description": {
      "DisplayName": "Description (optional)",
      "Description": "Optional blueprint description."
    },
    "MaxRetryAttempts": {
      "Hide": true,
      "Description": "Maximum attempts while waiting for the blueprint to become visible to blueprint-principal creation."
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
    [ValidateNotNullOrEmpty()]
    [string]$DisplayName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SponsorObjectIds,

    [string]$OwnerObjectIds = "",

    [string]$ManagerApplicationAppIds = "",

    [string]$Tags = "",

    [string]$Description = "",

    [ValidateRange(2, 10)]
    [int]$MaxRetryAttempts = 6,

    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

$ErrorActionPreference = "Stop"
$graph = "https://graph.microsoft.com/v1.0"
$headers = @{ "OData-Version" = "4.0"; "Content-Type" = "application/json" }

function ConvertTo-IdList {
    param([string]$Value)
    return @($Value -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
}

function Invoke-Graph {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [ValidateSet("GET", "POST")][string]$Method = "GET",
        [hashtable]$Body
    )
    $arguments = @{ Uri = $Uri; Method = $Method; Headers = $headers; ErrorAction = "Stop" }
    if ($Body) { $arguments.Body = ($Body | ConvertTo-Json -Depth 10 -Compress) }
    return Invoke-MgGraphRequest @arguments
}

function Get-DirectoryObject {
    param([Parameter(Mandatory = $true)][string]$Id)
    if ($Id -notmatch "^[0-9a-fA-F-]{36}$") { throw "Directory object ID '$Id' isn't a GUID." }
    return Invoke-Graph -Uri "$graph/directoryObjects/$Id"
}

function Get-GraphStatusCode {
    param([Parameter(Mandatory = $true)]$ErrorRecord)
    try {
        $statusCode = $ErrorRecord.Exception.Response.StatusCode
        if ($null -ne $statusCode) {
            if ($statusCode.PSObject.Properties['value__']) { return [int]$statusCode.value__ }
            return [int]$statusCode
        }
    }
    catch { Write-Debug "Graph response did not expose a parseable status code." }
    if ($ErrorRecord.Exception.Message -match '(?<!\d)(?<Status>4\d\d|5\d\d)(?!\d)') { return [int]$Matches.Status }
    return $null
}

function Assert-Sponsor {
    param([Parameter(Mandatory = $true)][string]$Id)
    $object = Get-DirectoryObject -Id $Id
    $type = $object.'@odata.type'
    if ($type -eq "#microsoft.graph.user") { return }
    if ($type -ne "#microsoft.graph.group") { throw "Sponsor '$Id' has unsupported type '$type'. Only users and eligible groups are supported." }
    $group = Invoke-Graph -Uri "$graph/groups/${Id}?`$select=id,displayName,groupTypes,membershipRule,isAssignableToRole"
    $eligible = ($group.groupTypes -contains "Unified") -or -not [string]::IsNullOrWhiteSpace($group.membershipRule)
    if ($group.isAssignableToRole -or -not $eligible) { throw "Sponsor group '$($group.displayName)' must be a Microsoft 365 or dynamic group and must not be role-assignable." }
}

$blueprint = $null
try {
    Write-RjRbLog -Message "Caller: '$CallerName'; creating Agent ID blueprint '$DisplayName'." -Verbose
    Connect-MgGraph -Identity -NoWelcome | Out-Null

    $sponsors = @(ConvertTo-IdList -Value $SponsorObjectIds)
    if ($sponsors.Count -eq 0) { throw "At least one sponsor object ID is required." }
    foreach ($id in $sponsors) { Assert-Sponsor -Id $id }

    $owners = @(ConvertTo-IdList -Value $OwnerObjectIds)
    foreach ($id in $owners) {
        $type = (Get-DirectoryObject -Id $id).'@odata.type'
        if ($type -notin @("#microsoft.graph.user", "#microsoft.graph.servicePrincipal")) { throw "Owner '$id' has unsupported type '$type'; groups aren't allowed." }
    }

    $managerIds = @(ConvertTo-IdList -Value $ManagerApplicationAppIds)
    if ($managerIds.Count -gt 10) { throw "ManagerApplicationAppIds accepts at most 10 application (client) IDs." }
    foreach ($id in $managerIds) {
        if ($id -notmatch "^[0-9a-fA-F-]{36}$") { throw "Manager application ID '$id' isn't a GUID." }
    }

    $body = @{
        displayName = $DisplayName
        "sponsors@odata.bind" = @($sponsors | ForEach-Object { "$graph/directoryObjects/$_" })
    }
    if ($owners.Count -gt 0) { $body["owners@odata.bind"] = @($owners | ForEach-Object { "$graph/directoryObjects/$_" }) }
    if ($managerIds.Count -gt 0) { $body.managerApplications = $managerIds }
    if ($Description) { $body.description = $Description }
    $tagList = @(ConvertTo-IdList -Value $Tags)
    if ($tagList.Count -gt 0) { $body.tags = $tagList }

    $blueprint = Invoke-Graph -Uri "$graph/applications/microsoft.graph.agentIdentityBlueprint" -Method POST -Body $body
    if (-not $blueprint.id -or -not $blueprint.appId) { throw "Blueprint creation returned no object ID or app ID." }

    $principal = $null
    for ($attempt = 1; $attempt -le $MaxRetryAttempts; $attempt++) {
        try {
            $principal = Invoke-Graph -Uri "$graph/servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal" -Method POST -Body @{ appId = $blueprint.appId }
            break
        }
        catch {
            # A server error can arrive after creation succeeded, so never retry an ambiguous POST.
            $statusCode = Get-GraphStatusCode -ErrorRecord $_
            $detailText = "$($_.Exception.Message) $($_.ErrorDetails.Message)"
            $isPropagation400 = $statusCode -eq 400 -and $detailText -match 'does not reference a valid application object|Request_ResourceNotFound'
            if ($null -eq $statusCode -or $statusCode -ge 500) {
                throw "Principal creation has an unknown outcome. The POST was not retried. Inspect the principal for blueprint app ID '$($blueprint.appId)' before retrying. $($_.Exception.Message)"
            }
            $retryable = $statusCode -eq 404 -or $isPropagation400 -or $statusCode -eq 429
            if (-not $retryable -or $attempt -eq $MaxRetryAttempts) { throw }
            $delay = [Math]::Min(30, [Math]::Pow(2, $attempt))
            Write-RjRbLog -Message "Principal creation returned HTTP $statusCode; retry $attempt/$MaxRetryAttempts in $delay seconds." -Verbose
            Start-Sleep -Seconds $delay
        }
    }

    [PSCustomObject]@{ RjTableTitle = 'Created blueprint' }
    Write-Output ([pscustomobject]@{
        Status = "Created"
        BlueprintObjectId = $blueprint.id
        BlueprintAppId = $blueprint.appId
        BlueprintPrincipalObjectId = $principal.id
        DisplayName = $blueprint.displayName
        SponsorCount = $sponsors.Count
        OwnerCount = $owners.Count
    })
}
catch {
    if ($blueprint.id) { Write-Warning "Blueprint '$($blueprint.id)' (app ID '$($blueprint.appId)') was created and retained. Inspect it before starting another creation run." }
    Write-Error "Agent ID blueprint creation failed: $($_.Exception.Message)"
    throw
}
finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

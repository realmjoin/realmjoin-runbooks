<#
.SYNOPSIS
Create an Entra agent identity from a blueprint
.DESCRIPTION
Validates the selected blueprint, its principal, mandatory sponsors and optional owners. Creates an agent identity through the typed v1.0 endpoint, retrying only throttling and recognized propagation failures.
.PARAMETER BlueprintAppId
Application (client) ID of the selected agent identity blueprint.
.PARAMETER SponsorObjectIds
Comma-separated user or supported group object IDs. At least one sponsor is required.
.PARAMETER OwnerObjectIds
Optional comma-separated user or service principal object IDs. Groups aren't accepted as owners.
.PARAMETER DisplayName
Optional display name for the agent identity. If omitted, the runbook uses the validated blueprint's display name.
.PARAMETER Tags
Optional comma-separated tags for the agent identity.
.PARAMETER MaxRetryAttempts
Maximum creation attempts while blueprint data propagates.
.PARAMETER CallerName
Name of the user or system that started the runbook. Used for auditing.
.OUTPUTS
Named raw-object tables for the RealmJoin Output Data tab. Summary rows remain available when no
detail rows match. Console progress, warnings, and errors remain separate from table data.
.INPUTS
RunbookCustomization: {
  "Parameters": {
    "BlueprintAppId": {
      "DisplayName": "Blueprint application ID",
      "Description": "Application (client) ID of the selected agent identity blueprint."
    },
    "SponsorObjectIds": {
      "DisplayName": "Sponsor object IDs (comma-separated)",
      "Description": "Comma-separated user or supported group object IDs. At least one sponsor is required."
    },
    "OwnerObjectIds": {
      "DisplayName": "Owner object IDs (optional)",
      "Description": "Optional comma-separated user or service principal object IDs. Groups aren't accepted as owners."
    },
    "DisplayName": {
      "DisplayName": "Identity display name (optional)",
      "Description": "Optional display name for the agent identity. If omitted, the runbook uses the validated blueprint's display name."
    },
    "Tags": {
      "DisplayName": "Tags (optional, comma-separated)",
      "Description": "Optional comma-separated tags for the agent identity."
    },
    "MaxRetryAttempts": {
      "Hide": true,
      "Description": "Maximum creation attempts while blueprint data propagates."
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
    [Parameter(Mandatory = $true)][ValidatePattern("^[0-9a-fA-F-]{36}$")][string]$BlueprintAppId,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$SponsorObjectIds,
    [string]$OwnerObjectIds = "",
    [string]$DisplayName = "",
    [string]$Tags = "",
    [ValidateRange(2, 10)][int]$MaxRetryAttempts = 6,
    [Parameter(Mandatory = $true)][string]$CallerName
)

$ErrorActionPreference = "Stop"
$graph = "https://graph.microsoft.com/v1.0"
$headers = @{ "OData-Version" = "4.0"; "Content-Type" = "application/json" }

function ConvertTo-IdList { param([string]$Value) @($Value -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique) }
function Invoke-Graph {
    param([string]$Uri, [ValidateSet("GET", "POST")][string]$Method = "GET", [hashtable]$Body)
    $arguments = @{ Uri = $Uri; Method = $Method; Headers = $headers; ErrorAction = "Stop" }
    if ($Body) { $arguments.Body = ($Body | ConvertTo-Json -Depth 8 -Compress) }
    Invoke-MgGraphRequest @arguments
}
function Get-Object { param([string]$Id) Invoke-Graph -Uri "$graph/directoryObjects/$Id" }
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
    param([string]$Id)
    $object = Get-Object -Id $Id
    if ($object.'@odata.type' -eq "#microsoft.graph.user") { return }
    if ($object.'@odata.type' -ne "#microsoft.graph.group") { throw "Sponsor '$Id' isn't a user or group." }
    $group = Invoke-Graph -Uri "$graph/groups/${Id}?`$select=id,displayName,groupTypes,membershipRule,isAssignableToRole"
    if ($group.isAssignableToRole -or (($group.groupTypes -notcontains "Unified") -and [string]::IsNullOrWhiteSpace($group.membershipRule))) {
        throw "Sponsor group '$($group.displayName)' must be Microsoft 365 or dynamic and not role-assignable."
    }
}

try {
    Write-RjRbLog -Message "Caller: '$CallerName'; creating identity from blueprint '$BlueprintAppId'." -Verbose
    Connect-MgGraph -Identity -NoWelcome | Out-Null

    $encodedAppId = [uri]::EscapeDataString($BlueprintAppId)
    $blueprints = Invoke-Graph -Uri "$graph/applications/microsoft.graph.agentIdentityBlueprint?`$filter=appId%20eq%20'$encodedAppId'&`$select=id,appId,displayName"
    $blueprint = @($blueprints.value) | Select-Object -First 1
    if (-not $blueprint) { throw "No Agent ID blueprint with app ID '$BlueprintAppId' was found." }
    $principals = Invoke-Graph -Uri "$graph/servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal?`$filter=appId%20eq%20'$encodedAppId'&`$select=id,appId"
    if (@($principals.value).Count -eq 0) { throw "The selected blueprint has no associated blueprint principal." }

    $sponsors = @(ConvertTo-IdList -Value $SponsorObjectIds)
    if ($sponsors.Count -eq 0) { throw "Supply at least one sponsor." }
    foreach ($id in $sponsors) { Assert-Sponsor -Id $id }

    $owners = @(ConvertTo-IdList -Value $OwnerObjectIds)
    foreach ($id in $owners) {
        $type = (Get-Object -Id $id).'@odata.type'
        if ($type -notin @("#microsoft.graph.user", "#microsoft.graph.servicePrincipal")) { throw "Owner '$id' has unsupported type '$type'; groups aren't allowed." }
    }

    $effectiveDisplayName = if ([string]::IsNullOrWhiteSpace($DisplayName)) { "$($blueprint.displayName)" } else { $DisplayName.Trim() }
    if ([string]::IsNullOrWhiteSpace($effectiveDisplayName)) { throw "DisplayName is required because the selected blueprint has no usable display name." }
    $body = @{
        displayName = $effectiveDisplayName
        agentIdentityBlueprintId = $BlueprintAppId
        "sponsors@odata.bind" = @($sponsors | ForEach-Object { "$graph/directoryObjects/$_" })
    }
    if ($owners.Count -gt 0) { $body["owners@odata.bind"] = @($owners | ForEach-Object { "$graph/directoryObjects/$_" }) }
    $tagList = @(ConvertTo-IdList -Value $Tags)
    if ($tagList.Count -gt 0) { $body.tags = $tagList }

    $identity = $null
    for ($attempt = 1; $attempt -le $MaxRetryAttempts; $attempt++) {
        try {
            $identity = Invoke-Graph -Uri "$graph/servicePrincipals/microsoft.graph.agentIdentity" -Method POST -Body $body
            break
        }
        catch {
            # A server error can arrive after creation succeeded, so never retry an ambiguous POST.
            $statusCode = Get-GraphStatusCode -ErrorRecord $_
            $detailText = "$($_.Exception.Message) $($_.ErrorDetails.Message)"
            $isPropagation400 = $statusCode -eq 400 -and $detailText -match 'does not reference a valid application object|Request_ResourceNotFound'
            if ($null -eq $statusCode -or $statusCode -ge 500) {
                throw "Identity creation has an unknown outcome. The POST was not retried because it may already have created an identity. Inspect identities for blueprint '$BlueprintAppId' before retrying. $($_.Exception.Message)"
            }
            $retryable = $statusCode -eq 404 -or $isPropagation400 -or $statusCode -eq 429
            if (-not $retryable -or $attempt -eq $MaxRetryAttempts) { throw }
            $delay = [Math]::Min(30, [Math]::Pow(2, $attempt))
            Write-RjRbLog -Message "Identity creation returned HTTP $statusCode; retry $attempt/$MaxRetryAttempts in $delay seconds." -Verbose
            Start-Sleep -Seconds $delay
        }
    }

    [PSCustomObject]@{ RjTableTitle = 'Created agent identity' }
    Write-Output ([pscustomobject]@{
        Status = "Created"
        IdentityObjectId = $identity.id
        IdentityAppId = $identity.appId
        DisplayName = $identity.displayName
        BlueprintAppId = $BlueprintAppId
        SponsorCount = $sponsors.Count
        OwnerCount = $owners.Count
    })
}
catch {
    Write-Error "Agent Identity creation failed: $($_.Exception.Message)"
    throw
}
finally { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null }

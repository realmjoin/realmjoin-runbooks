<#
    .SYNOPSIS
Inventory Entra agent identities, blueprints and agent users

    .DESCRIPTION
    Inventories v1.0 agent identities, blueprints, blueprint principals, and agent users. For every
agent identity it records enablement, Microsoft disablement, sponsors, owners, creation, tags,
manager applications, custom security attributes, and blueprint population. Relationship failures
remain Unknown. It warns when app-only creation approaches the documented 250 identities per
blueprint constraint; it does not describe this as a tenant-wide quota.

    .PARAMETER BlueprintQuotaWarningPercent
    Percentage of the documented app-only 250-per-blueprint constraint at which to warn.

    .PARAMETER IncludeCustomSecurityAttributes
    Request customSecurityAttributes. Disable if the managed identity lacks that separate permission.
    .PARAMETER EmailTo
    Optional comma- or semicolon-separated recipients for the report.

    .PARAMETER EmailFrom
    Sender mailbox from the RJReport.EmailSender tenant setting. Required only when EmailTo is set.

    .PARAMETER CallerName
    Name of the caller. This mandatory hidden parameter is used for auditing.
.PARAMETER BrandingHeaderImageUrl
Header image URL for report emails.
.PARAMETER BrandingFooterImageUrl
Footer image URL for report emails.
.PARAMETER BrandingFooterLink
Destination link for the report email footer.
.PARAMETER BrandingAccentColor
Accent color for report emails.
.PARAMETER BrandingTextColor
Text color for report emails.
.OUTPUTS
Named raw-object tables for the RealmJoin Output Data tab. Summary rows remain available when no
detail rows match. Console progress, warnings, and errors remain separate from table data.

    .INPUTS
    RunbookCustomization: {
  "Parameters": {
    "BlueprintQuotaWarningPercent": {
      "DisplayName": "Blueprint app-only quota warning (%)",
      "Description": "Percentage of the documented app-only 250-per-blueprint constraint at which to warn."
    },
    "IncludeCustomSecurityAttributes": {
      "DisplayName": "Include custom security attributes",
      "Description": "Request customSecurityAttributes. Disable if the managed identity lacks that separate permission."
    },
    "EmailTo": {
      "DisplayName": "Report recipient(s)",
      "Description": "Optional comma- or semicolon-separated recipients for the report."
    },
    "EmailFrom": {
      "Hide": true,
      "Description": "Sender mailbox from the RJReport.EmailSender tenant setting. Required only when EmailTo is set."
    },
    "CallerName": {
      "Hide": true,
      "Description": "Name of the caller. This mandatory hidden parameter is used for auditing."
    },
    "BrandingHeaderImageUrl": {
      "Hide": true,
      "Description": "Header image URL for report emails."
    },
    "BrandingFooterImageUrl": {
      "Hide": true,
      "Description": "Footer image URL for report emails."
    },
    "BrandingFooterLink": {
      "Hide": true,
      "Description": "Destination link for the report email footer."
    },
    "BrandingAccentColor": {
      "Hide": true,
      "Description": "Accent color for report emails."
    },
    "BrandingTextColor": {
      "Hide": true,
      "Description": "Text color for report emails."
    }
  }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }

param(
    [ValidateRange(1, 100)]
    [int]$BlueprintQuotaWarningPercent = 80,

    [bool]$IncludeCustomSecurityAttributes = $true,

    [string]$EmailTo,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" } )]
    [string]$BrandingHeaderImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" } )]
    [string]$BrandingFooterImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" } )]
    [string]$BrandingFooterLink,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" } )]
    [string]$BrandingAccentColor,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" } )]
    [string]$BrandingTextColor,

    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

$ErrorActionPreference = 'Stop'
$brandingMailParams = @{}
try {
if ($EmailTo) { $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor }


$ErrorActionPreference = 'Stop'
$Version = '1.0.2'
Write-RjRbLog -Message "Caller: '$CallerName'; version: $Version" -Verbose

if ($EmailTo -and [string]::IsNullOrWhiteSpace($EmailFrom)) {
    throw 'EmailTo requires the RJReport.EmailSender setting.'
}

function Get-GraphErrorInfo {
    param([Parameter(Mandatory = $true)]$ErrorRecord)
    $statusCode = $null
    $graphCode = $null
    try {
        $rawStatus = $ErrorRecord.Exception.Response.StatusCode
        if ($null -ne $rawStatus) {
            $statusCode = if ($rawStatus.PSObject.Properties['value__']) { [int]$rawStatus.value__ } else { [int]$rawStatus }
        }
    }
    catch { Write-Debug 'Graph response did not expose a structured HTTP status.' }
    foreach ($candidate in @($ErrorRecord.ErrorDetails.Message, $ErrorRecord.Exception.Message)) {
        if (-not $candidate) { continue }
        try {
            $payload = $candidate | ConvertFrom-Json -ErrorAction Stop
            if ($payload.error.code) { $graphCode = "$($payload.error.code)"; break }
        }
        catch { Write-Debug 'Graph error content was not JSON.' }
    }
    [PSCustomObject]@{ StatusCode = $statusCode; GraphCode = $graphCode }
}

function Invoke-GraphRequestWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')][string]$Method = 'GET',
        [AllowNull()][object]$Body,
        [ValidateRange(1, 10)][int]$MaxAttempts = 5
    )
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            $arguments = @{ Uri = $Uri; Method = $Method; ErrorAction = 'Stop' }
            if ($PSBoundParameters.ContainsKey('Body')) {
                $arguments.Body = ($Body | ConvertTo-Json -Depth 20 -Compress)
                $arguments.ContentType = 'application/json'
            }
            return Invoke-MgGraphRequest @arguments
        }
        catch {
            $info = Get-GraphErrorInfo -ErrorRecord $_
            $transient = $info.StatusCode -eq 429 -or ($info.StatusCode -ge 500 -and $info.StatusCode -le 599)
            if (-not $transient -or $attempt -eq $MaxAttempts) {
                throw "Graph request failed: $Method $Uri; HTTP $($info.StatusCode); code '$($info.GraphCode)'; $($_.Exception.Message)"
            }
            $delay = [int][math]::Min(120, [math]::Pow(2, $attempt))
            try {
                $retryAfter = $_.Exception.Response.Headers.RetryAfter
                if ($retryAfter.Delta) { $delay = [math]::Max($delay, [math]::Ceiling($retryAfter.Delta.TotalSeconds)) }
            }
            catch { Write-Debug 'No structured Retry-After value was available.' }
            Write-RjRbLog -Message "Graph returned HTTP $($info.StatusCode). Retrying in $delay second(s)." -Verbose
            Start-Sleep -Seconds $delay
        }
    }
}

function Get-GraphPagedResult {
    param([Parameter(Mandatory = $true)][string]$Uri)
    $items = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    do {
        $response = Invoke-GraphRequestWithRetry -Uri $nextLink
        if ($null -ne $response.value) { $items.AddRange([object[]]$response.value) }
        elseif ($response) { $items.Add($response) }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)
    $items.ToArray()
}

function Send-AgentIdReport {
    param([string]$Title, [string]$Summary, [object[]]$Rows)
    if (-not $EmailTo) { return }
    $preview = @($Rows | Select-Object -First 100 | ConvertTo-Csv -NoTypeInformation) -join "`n"
    $omitted = if ($Rows.Count -gt 100) { "`n`n$($Rows.Count - 100) additional row(s) are available in job output." } else { '' }
    $markdown = "# $Title`n`n$Summary`n`n## Preview`n`n``````text`n$preview`n``````$omitted"
    Send-RjRbReportEmail @brandingMailParams -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $Title -MarkdownContent ($markdown + "`n`n---`n`n*This email was automatically generated. Please do not reply to this email.*") -ReportVersion $Version -UseNativeGraphRequest
}

Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop | Out-Null

try {
    $snapshotTime = [datetime]::UtcNow.ToString('o')
    $select = 'id,appId,displayName,accountEnabled,disabledByMicrosoftStatus,createdDateTime,tags,agentIdentityBlueprintId,managerApplications'
    if ($IncludeCustomSecurityAttributes) { $select += ',customSecurityAttributes' }
    $agents = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/microsoft.graph.agentIdentity?`$select=$select")
    $blueprints = @(Get-GraphPagedResult -Uri 'https://graph.microsoft.com/v1.0/applications/microsoft.graph.agentIdentityBlueprint')
    $principals = @(Get-GraphPagedResult -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal?$select=id,appId,displayName,accountEnabled')
    $agentUsers = @(Get-GraphPagedResult -Uri 'https://graph.microsoft.com/v1.0/users/microsoft.graph.agentUser?$select=id,displayName,accountEnabled,createdDateTime,identityParentId')
    $blueprintByAppId = @{}
    foreach ($blueprint in $blueprints) { $blueprintByAppId["$($blueprint.appId)"] = $blueprint }
    $counts = @{}
    foreach ($agent in $agents) {
        $key = "$($agent.agentIdentityBlueprintId)"
        if (-not $counts.ContainsKey($key)) { $counts[$key] = 0 }
        $counts[$key]++
    }
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($agent in $agents) {
        $sponsorState = 'Known'; $ownerState = 'Known'; $sponsors = @(); $owners = @()
        try { $sponsors = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($agent.id)/microsoft.graph.agentIdentity/sponsors?`$select=id,displayName,userPrincipalName,appId") }
        catch { $sponsorState = 'Unknown'; Write-Error "Sponsor lookup failed for '$($agent.id)': $($_.Exception.Message)" -ErrorAction Continue }
        try { $owners = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($agent.id)/microsoft.graph.agentIdentity/owners?`$select=id,displayName,userPrincipalName,appId") }
        catch { $ownerState = 'Unknown'; Write-Error "Owner lookup failed for '$($agent.id)': $($_.Exception.Message)" -ErrorAction Continue }
        $bpCount = $counts["$($agent.agentIdentityBlueprintId)"]
        $rows.Add([PSCustomObject]@{
            ObjectType = 'AgentIdentity'; Id = $agent.id; DisplayName = $agent.displayName; AppId = $agent.appId
            BlueprintAppId = $agent.agentIdentityBlueprintId; Blueprint = $blueprintByAppId["$($agent.agentIdentityBlueprintId)"].displayName
            AccountEnabled = $agent.accountEnabled; DisabledByMicrosoftStatus = $agent.disabledByMicrosoftStatus
            Sponsors = if ($sponsorState -eq 'Known') { ($sponsors.displayName -join '; ') } else { 'Unknown (lookup failed)' }
            Owners = if ($ownerState -eq 'Known') { ($owners.displayName -join '; ') } else { 'Unknown (lookup failed)' }
            CreatedDateTime = $agent.createdDateTime; Tags = ($agent.tags -join '; ')
            ManagerApplications = (@($agent.managerApplications) -join '; ')
            CustomSecurityAttributes = if ($IncludeCustomSecurityAttributes) { $agent.customSecurityAttributes | ConvertTo-Json -Depth 10 -Compress } else { 'Not requested' }
            BlueprintAgentCount = $bpCount
            QuotaWarning = $bpCount -ge [math]::Ceiling(250 * $BlueprintQuotaWarningPercent / 100)
        })
    }
    foreach ($blueprint in $blueprints) { $rows.Add([PSCustomObject]@{ ObjectType = 'AgentIdentityBlueprint'; Id = $blueprint.id; DisplayName = $blueprint.displayName; AppId = $blueprint.appId; BlueprintAppId = $blueprint.appId; BlueprintAgentCount = $counts["$($blueprint.appId)"] }) }
    foreach ($principal in $principals) { $rows.Add([PSCustomObject]@{ ObjectType = 'AgentIdentityBlueprintPrincipal'; Id = $principal.id; DisplayName = $principal.displayName; AppId = $principal.appId; AccountEnabled = $principal.accountEnabled }) }
    foreach ($agentUser in $agentUsers) { $rows.Add([PSCustomObject]@{ ObjectType = 'AgentUser'; Id = $agentUser.id; DisplayName = $agentUser.displayName; AccountEnabled = $agentUser.accountEnabled; CreatedDateTime = $agentUser.createdDateTime }) }
    $summary = "Snapshot UTC: $snapshotTime; agent identities: $($agents.Count); blueprints: $($blueprints.Count); blueprint principals: $($principals.Count); agent users: $($agentUsers.Count). All returned objects are included, including any test objects present at collection time. Counts are inventory, not a health assessment."
    Write-Output $summary
    [PSCustomObject]@{ RjTableTitle = 'Inventory summary' }
    [PSCustomObject]@{ SnapshotUtc = $snapshotTime; AgentIdentities = $agents.Count; Blueprints = $blueprints.Count; BlueprintPrincipals = $principals.Count; AgentUsers = $agentUsers.Count; Summary = $summary }
    [PSCustomObject]@{ RjTableTitle = 'Agent inventory' }
    $rows | Select-Object ObjectType, Id, DisplayName, AppId, BlueprintAppId, Blueprint, AccountEnabled, DisabledByMicrosoftStatus, Sponsors, Owners, CreatedDateTime, Tags, ManagerApplications, CustomSecurityAttributes, BlueprintAgentCount, QuotaWarning
    Send-AgentIdReport -Title 'Agent Identity Inventory' -Summary $summary -Rows $rows.ToArray()
}
finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

}
finally {
    foreach ($key in @('HeaderImage', 'FooterImage')) {
        if ($brandingMailParams -and $brandingMailParams.ContainsKey($key) -and (Test-Path -LiteralPath $brandingMailParams[$key])) {
            Remove-Item -LiteralPath $brandingMailParams[$key] -Force -ErrorAction Continue
        }
    }
}

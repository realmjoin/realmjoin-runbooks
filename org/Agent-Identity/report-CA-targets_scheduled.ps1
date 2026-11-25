<#
    .SYNOPSIS
Report Conditional Access targeting of Entra agent identities

    .DESCRIPTION
    Compares agent identity and blueprint principal service-principal object IDs with Conditional Access
clientApplications includeServicePrincipals and excludeServicePrincipals. This assesses autonomous,
app-only workload-identity targeting. OBO access is governed through the signed-in user and cannot be
inferred as agent coverage from this report.

    .PARAMETER IncludeDisabledPolicies
    Include disabled policies as informational, non-enforced coverage.
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
    "IncludeDisabledPolicies": {
      "DisplayName": "Include disabled policies",
      "Description": "Include disabled policies as informational, non-enforced coverage."
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
    [bool]$IncludeDisabledPolicies = $true,

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
if ($EmailTo) { $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor }


$ErrorActionPreference = 'Stop'
$Version = '1.0.1'
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
    $principals = [System.Collections.Generic.List[object]]::new()
    foreach ($agent in @(Get-GraphPagedResult -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals/microsoft.graph.agentIdentity?$select=id,appId,displayName')) { $principals.Add([PSCustomObject]@{ Type = 'AgentIdentity'; Id = $agent.id; AppId = $agent.appId; DisplayName = $agent.displayName }) }
    foreach ($blueprint in @(Get-GraphPagedResult -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal?$select=id,appId,displayName')) { $principals.Add([PSCustomObject]@{ Type = 'AgentIdentityBlueprintPrincipal'; Id = $blueprint.id; AppId = $blueprint.appId; DisplayName = $blueprint.displayName }) }
    $policies = @(Get-GraphPagedResult -Uri 'https://graph.microsoft.com/beta/identity/conditionalAccess/policies')
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($principal in $principals) {
        $matched = $false
        foreach ($policy in $policies) {
            if (-not $IncludeDisabledPolicies -and $policy.state -eq 'disabled') { continue }
            $clientApps = $policy.conditions.clientApplications
            if (-not $clientApps) { continue }
            foreach ($targetKind in @('AgentIdentity', 'WorkloadIdentity')) {
                if ($targetKind -eq 'AgentIdentity') {
                    $includes = @($clientApps.includeAgentIdServicePrincipals | Where-Object { $_ })
                    $excludes = @($clientApps.excludeAgentIdServicePrincipals | Where-Object { $_ })
                    $filter = $clientApps.agentIdServicePrincipalFilter
                } else {
                    $includes = @($clientApps.includeServicePrincipals | Where-Object { $_ })
                    $excludes = @($clientApps.excludeServicePrincipals | Where-Object { $_ })
                    $filter = $clientApps.servicePrincipalFilter
                }
                $included = $includes -contains $principal.Id -or ($targetKind -eq 'WorkloadIdentity' -and $includes -contains 'ServicePrincipalsInMyTenant')
                $excluded = $excludes -contains $principal.Id
                $unknownSelector = @(@($includes) + @($excludes) | Where-Object {
                    $selectorId = [guid]::Empty
                    $_ -ne $principal.Id -and -not [guid]::TryParse($_, [ref]$selectorId) -and
                    -not ($targetKind -eq 'WorkloadIdentity' -and $_ -eq 'ServicePrincipalsInMyTenant')
                }).Count -gt 0
                if (-not ($included -or $excluded -or $filter -or $unknownSelector)) { continue }
                $targeting = if ($excluded) { 'Excluded' } elseif ($filter -or $unknownSelector) { 'Unknown - filter or selector not evaluated' } else { 'Included' }
                $matched = $true
                $rows.Add([PSCustomObject]@{ PrincipalType = $principal.Type; Principal = $principal.DisplayName; PrincipalObjectId = $principal.Id; Policy = $policy.displayName; PolicyId = $policy.id; PolicyState = $policy.state; TargetKind = $targetKind; Targeting = $targeting; Enforcement = if ($policy.state -eq 'enabled') { 'Enabled policy' } elseif ($policy.state -eq 'enabledForReportingButNotEnforced') { 'Report-only' } else { 'Disabled' }; AccessPattern = 'Selector match only; applicability and effective enforcement not inferred' })
            }
        }
        if (-not $matched) { $rows.Add([PSCustomObject]@{ PrincipalType = $principal.Type; Principal = $principal.DisplayName; PrincipalObjectId = $principal.Id; Policy = $null; PolicyId = $null; PolicyState = $null; TargetKind = $null; Targeting = 'No explicit target found'; Enforcement = 'None inferred'; AccessPattern = 'Selector match only; applicability and effective enforcement not inferred' }) }
    }
    Write-Output "Agent/blueprint principals: $($principals.Count); policies: $($policies.Count); coverage rows: $($rows.Count). OBO is governed through the user and is not inferred here."
    [PSCustomObject]@{ RjTableTitle = 'Coverage summary' }
    [PSCustomObject]@{ Principals = $principals.Count; Policies = $policies.Count; CoverageRows = $rows.Count; Scope = 'Agent-specific and ordinary workload selectors are reported separately. Filters, other conditions, grant controls and OBO coverage are not evaluated.' }
    [PSCustomObject]@{ RjTableTitle = 'Conditional access coverage' }
    $rows | Sort-Object PrincipalType, Principal, Policy
    Send-AgentIdReport -Title 'Agent Conditional Access Targeting' -Summary 'Selector matches are not proof of effective protection. Agent-specific and ordinary workload selectors are separate; filters, other conditions, grant controls and OBO coverage are not evaluated.' -Rows $rows.ToArray()
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

<#
    .SYNOPSIS
Report missing, disabled or guest sponsors of agent identities

    .DESCRIPTION
    Checks v1.0 sponsors for agent identities and blueprints. It reports missing sponsors and sponsors
that are disabled, soft-deleted, or guest users. A lookup failure is Unknown and is never relabeled
as missing. This runbook does not assign fallback sponsors; that remediation belongs to an interactive
runbook.

    .PARAMETER IncludeBlueprints
    Include agent identity blueprints as well as agent identities.
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
    "IncludeBlueprints": {
      "DisplayName": "Include blueprints",
      "Description": "Include agent identity blueprints as well as agent identities."
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
    [bool]$IncludeBlueprints = $true,

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
    $targets = [System.Collections.Generic.List[object]]::new()
    foreach ($agent in @(Get-GraphPagedResult -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals/microsoft.graph.agentIdentity?$select=id,displayName,appId')) { $targets.Add([PSCustomObject]@{ Type = 'AgentIdentity'; Id = $agent.id; DisplayName = $agent.displayName; SponsorUri = "https://graph.microsoft.com/v1.0/servicePrincipals/$($agent.id)/microsoft.graph.agentIdentity/sponsors" }) }
    if ($IncludeBlueprints) {
        foreach ($blueprint in @(Get-GraphPagedResult -Uri 'https://graph.microsoft.com/v1.0/applications/microsoft.graph.agentIdentityBlueprint?$select=id,displayName,appId')) { $targets.Add([PSCustomObject]@{ Type = 'AgentIdentityBlueprint'; Id = $blueprint.id; DisplayName = $blueprint.displayName; SponsorUri = "https://graph.microsoft.com/v1.0/applications/$($blueprint.id)/microsoft.graph.agentIdentityBlueprint/sponsors" }) }
    }
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($target in $targets) {
        try { $sponsors = @(Get-GraphPagedResult -Uri $target.SponsorUri) }
        catch { $rows.Add([PSCustomObject]@{ TargetType = $target.Type; Target = $target.DisplayName; TargetId = $target.Id; Sponsor = 'Unknown'; SponsorId = $null; Finding = 'Unknown (sponsor lookup failed)' }); continue }
        if ($sponsors.Count -eq 0) { $rows.Add([PSCustomObject]@{ TargetType = $target.Type; Target = $target.DisplayName; TargetId = $target.Id; Sponsor = 'None'; SponsorId = $null; Finding = 'Missing sponsor' }); continue }
        foreach ($sponsor in $sponsors) {
            $finding = 'Healthy'
            $odataType = "$($sponsor.'@odata.type')"
            if ($odataType -eq '#microsoft.graph.user' -or $sponsor.userPrincipalName) {
                try {
                    $user = Invoke-GraphRequestWithRetry -Uri "https://graph.microsoft.com/v1.0/users/$($sponsor.id)?`$select=id,displayName,accountEnabled,userType"
                    if ($user.accountEnabled -eq $false) { $finding = 'Disabled sponsor' }
                    elseif ($user.userType -eq 'Guest') { $finding = 'Guest sponsor' }
                }
                catch {
                    $info = Get-GraphErrorInfo $_
                    if ($info.StatusCode -eq 404) {
                        try { [void](Invoke-GraphRequestWithRetry -Uri "https://graph.microsoft.com/v1.0/directory/deletedItems/$($sponsor.id)"); $finding = 'Deleted sponsor' }
                        catch { $finding = 'Unknown (sponsor lookup failed)' }
                    }
                    else { $finding = 'Unknown (sponsor lookup failed)' }
                }
            }
            $rows.Add([PSCustomObject]@{ TargetType = $target.Type; Target = $target.DisplayName; TargetId = $target.Id; Sponsor = $sponsor.displayName; SponsorId = $sponsor.id; Finding = $finding })
        }
    }
    $unknownCount = @($rows | Where-Object Finding -like 'Unknown*').Count
    $findings = @($rows | Where-Object { $_.Finding -ne 'Healthy' -and $_.Finding -notlike 'Unknown*' })
    $summary = "Targets: $($targets.Count); sponsor rows: $($rows.Count); actionable findings: $($findings.Count); unknown lookups: $unknownCount. Existing sponsor findings are reported, not remediated automatically."
    if ($unknownCount) { Write-Warning 'Sponsor assessment is partial because some lookups failed.' }
    Write-Output $summary
    [PSCustomObject]@{ RjTableTitle = 'Sponsor assessment' }
    [PSCustomObject]@{ Targets = $targets.Count; SponsorRows = $rows.Count; ActionableFindings = $findings.Count; UnknownLookups = $unknownCount; Summary = $summary }
    [PSCustomObject]@{ RjTableTitle = 'Sponsor findings' }
    $rows | Sort-Object Finding, Target
    Send-AgentIdReport -Title 'Agent Sponsors at Risk' -Summary $summary -Rows $rows.ToArray()
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

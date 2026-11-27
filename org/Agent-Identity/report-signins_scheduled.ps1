<#
    .SYNOPSIS
Report retained Entra agent identity sign-in events

    .DESCRIPTION
    Uses the documented Microsoft Graph beta auditLogs/signIns query for service-principal events whose
agent/agentType is agenticAppInstance. Applies an explicit UTC time window, follows pagination, summarizes
success, failure, resources, and identities, and optionally emails the result.

    .PARAMETER LookbackHours
    UTC lookback window in hours.

    .PARAMETER MaxEvents
    Maximum events retained in the report; collection stops at the cap.
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
    "LookbackHours": {
      "DisplayName": "Lookback window (hours)",
      "Description": "UTC lookback window in hours."
    },
    "MaxEvents": {
      "DisplayName": "Maximum sign-in events",
      "Description": "Maximum events retained in the report; collection stops at the cap."
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
    [ValidateRange(1, 720)]
    [int]$LookbackHours = 24,

    [ValidateRange(1, 100000)]
    [int]$MaxEvents = 10000,

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
    $windowEnd = [datetime]::UtcNow
    $from = $windowEnd.AddHours(-$LookbackHours).ToString('o')
    $to = $windowEnd.ToString('o')
    $filter = "createdDateTime ge $from and createdDateTime le $to and signInEventTypes/any(t: t eq 'servicePrincipal') and agent/agentType eq 'agenticAppInstance'"
    $uri = "https://graph.microsoft.com/beta/auditLogs/signIns?`$filter=$([uri]::EscapeDataString($filter))&`$orderby=createdDateTime%20desc"
    $events = [System.Collections.Generic.List[object]]::new()
    $truncated = $false
    $nextLink = $uri
    while ($nextLink -and $events.Count -lt $MaxEvents) {
        $response = Invoke-GraphRequestWithRetry -Uri $nextLink
        foreach ($event in @($response.value)) {
            if ($events.Count -lt $MaxEvents) { $events.Add($event) }
            else { $truncated = $true }
        }
        $nextLink = $response.'@odata.nextLink'
    }
    if ($nextLink) { $truncated = $true }
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($event in $events) {
        $result = if ($null -eq $event.status.errorCode) { 'Unknown' } elseif ($event.status.errorCode -eq 0) { 'Success' } else { 'Failure' }
        $rows.Add([PSCustomObject]@{ CreatedDateTime = $event.createdDateTime; AgentIdentity = $event.servicePrincipalName; ServicePrincipalId = $event.servicePrincipalId; AppId = $event.appId; Resource = $event.resourceDisplayName; ResourceId = $event.resourceId; Result = $result; ErrorCode = $event.status.errorCode; FailureReason = $event.status.failureReason; IPAddress = $event.ipAddress; CorrelationId = $event.correlationId })
    }
    $success = @($rows | Where-Object Result -eq 'Success').Count
    $failures = @($rows | Where-Object Result -eq 'Failure').Count
    $unknown = @($rows | Where-Object Result -eq 'Unknown').Count
    $state = if ($truncated) { 'Truncated' } elseif (-not $rows.Count) { 'NoRetainedEvents' } else { 'Collected' }
    $summary = "Window: $from through $to UTC; state: $state; events: $($rows.Count); successes: $success; failures: $failures; unknown results: $unknown."
    if ($truncated) {
        $summary += " MaxEvents=$MaxEvents was exceeded; counts describe the retained subset only."
        Write-Warning $summary
    }
    if (-not $rows.Count) {
        $summary += ' No matching events were returned. This is not proof of inactivity or a clean security assessment; check log retention, licensing, ingestion delay, and the selected window.'
        Write-Warning $summary
    }
    Write-Output $summary
    [PSCustomObject]@{ RjTableTitle = 'Sign-in assessment' }
    [PSCustomObject]@{ WindowStartUtc = $from; WindowEndUtc = $to; State = $state; Events = $rows.Count; Successes = $success; Failures = $failures; UnknownResults = $unknown; Truncated = $truncated; Summary = $summary }
    [PSCustomObject]@{ RjTableTitle = 'Agent sign-ins' }
    Write-Output $rows
    [PSCustomObject]@{ RjTableTitle = 'Sign-ins by identity' }
    $rows | Group-Object ServicePrincipalId | Select-Object @{ Name = 'ServicePrincipalId'; Expression = { $_.Name } }, Count
    [PSCustomObject]@{ RjTableTitle = 'Sign-ins by resource' }
    $rows | Group-Object ResourceId | Select-Object @{ Name = 'ResourceId'; Expression = { $_.Name } }, Count
    Send-AgentIdReport -Title 'Agent Identity Sign-ins' -Summary $summary -Rows $rows.ToArray()
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

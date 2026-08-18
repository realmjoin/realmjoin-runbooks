<#
    .SYNOPSIS
    Report Entra Agent Identities without sponsors or owners

    .DESCRIPTION
    Lists Entra Agent Identities and reports identities that have no sponsor, no owner, or either,
    depending on ReportScope. A missing sponsor is labeled as an anomaly because Agent Identities
    and Agent Identity Blueprints are expected to have at least one sponsor. A missing owner is
    labeled as legitimate because owners are optional.

    The runbook uses the Microsoft Graph beta API. Sponsor and owner lookup failures are included
    in the report as unknown findings instead of being treated as an empty relationship.

    .PARAMETER ReportScope
    Controls which Agent Identities are included: identities missing a sponsor, identities missing
    an owner, identities missing either relationship, or all identities.

    .PARAMETER IncludeInactive
    Include disabled Agent Identities. By default, only active identities are evaluated.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "ReportScope": {
                "DisplayName": "Report scope",
                "Select": {
                    "Options": [
                        {
                            "Display": "Missing sponsor or owner",
                            "ParameterValue": "Missing sponsor or owner"
                        },
                        {
                            "Display": "Missing sponsor",
                            "ParameterValue": "Missing sponsor"
                        },
                        {
                            "Display": "Missing owner",
                            "ParameterValue": "Missing owner"
                        },
                        {
                            "Display": "All Agent Identities",
                            "ParameterValue": "All identities"
                        }
                    ],
                    "ShowValue": false
                }
            },
            "IncludeInactive": {
                "DisplayName": "Include inactive Agent Identities?",
                "SelectSimple": {
                    "Yes - include active and inactive identities": true,
                    "No - only report active identities": false
                }
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.8" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param(
    [ValidateSet('Missing sponsor', 'Missing owner', 'Missing sponsor or owner', 'All identities')]
    [string]$ReportScope = 'Missing sponsor or owner',

    [bool]$IncludeInactive = $false,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "ReportScope: $ReportScope" -Verbose
Write-RjRbLog -Message "IncludeInactive: $IncludeInactive" -Verbose

#endregion RJ Log Part

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri

    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink -ErrorAction Stop
        if ($response.value) {
            $results.AddRange([object[]]$response.value)
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $results.ToArray()
}

function Get-DirectoryObjectLabel {
    param(
        [Parameter(Mandatory = $true)]
        $DirectoryObject
    )

    foreach ($propertyName in @('displayName', 'userPrincipalName', 'appId', 'id')) {
        $value = $DirectoryObject[$propertyName]
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    return 'Unknown directory object'
}

function Test-InReportScope {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Scope,

        [Parameter(Mandatory = $true)]
        [bool]$MissingSponsor,

        [Parameter(Mandatory = $true)]
        [bool]$MissingOwner,

        [Parameter(Mandatory = $true)]
        [bool]$SponsorLookupFailed,

        [Parameter(Mandatory = $true)]
        [bool]$OwnerLookupFailed
    )

    switch ($Scope) {
        'Missing sponsor' {
            return $MissingSponsor -or $SponsorLookupFailed
        }
        'Missing owner' {
            return $MissingOwner -or $OwnerLookupFailed
        }
        'Missing sponsor or owner' {
            return $MissingSponsor -or $MissingOwner -or $SponsorLookupFailed -or $OwnerLookupFailed
        }
        'All identities' {
            return $true
        }
    }
}

#endregion Function Definitions

########################################################
#region     Connect to Microsoft Graph
########################################################

Write-Output "Connecting to Microsoft Graph..."
Connect-RjRbGraph

#endregion Connect to Microsoft Graph

########################################################
#region     Retrieve Agent Identities and Blueprints
########################################################

$agentIdentityUri = 'https://graph.microsoft.com/beta/servicePrincipals/microsoft.graph.agentIdentity?$select=id,appId,displayName,accountEnabled,createdDateTime,agentIdentityBlueprintId'
$blueprintUri = 'https://graph.microsoft.com/beta/applications/microsoft.graph.agentIdentityBlueprint?$select=id,appId,displayName'

try {
    $agentIdentities = @(Get-GraphPagedResult -Uri $agentIdentityUri)
}
catch {
    Write-Error "Failed to list Entra Agent Identities: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

$blueprintsById = @{}
try {
    $blueprints = @(Get-GraphPagedResult -Uri $blueprintUri)
    foreach ($blueprint in $blueprints) {
        $blueprintsById[$blueprint.id] = $blueprint
    }
}
catch {
    Write-RjRbLog -Message "WARNING: Agent Identity Blueprint enrichment failed: $($_.Exception.Message)" -NoDebugOnly -Verbose
}

if (-not $IncludeInactive) {
    $agentIdentities = @($agentIdentities | Where-Object { $_.accountEnabled -eq $true })
}

Write-Output "Evaluating $($agentIdentities.Count) Agent Identity object(s)..."

#endregion Retrieve Agent Identities and Blueprints

########################################################
#region     Evaluate Sponsors and Owners
########################################################

$report = [System.Collections.Generic.List[object]]::new()

foreach ($agentIdentity in $agentIdentities) {
    $sponsors = @()
    $owners = @()
    $sponsorLookupFailed = $false
    $ownerLookupFailed = $false

    try {
        $sponsorUri = "https://graph.microsoft.com/beta/servicePrincipals/$($agentIdentity.id)/microsoft.graph.agentIdentity/sponsors?`$select=id,displayName,userPrincipalName,appId"
        $sponsors = @(Get-GraphPagedResult -Uri $sponsorUri)
    }
    catch {
        $sponsorLookupFailed = $true
        Write-RjRbLog -Message "WARNING: Sponsor lookup failed for '$($agentIdentity.displayName)' ($($agentIdentity.id)): $($_.Exception.Message)" -NoDebugOnly -Verbose
    }

    try {
        $ownerUri = "https://graph.microsoft.com/beta/servicePrincipals/$($agentIdentity.id)/microsoft.graph.agentIdentity/owners?`$select=id,displayName,userPrincipalName,appId"
        $owners = @(Get-GraphPagedResult -Uri $ownerUri)
    }
    catch {
        $ownerLookupFailed = $true
        Write-RjRbLog -Message "WARNING: Owner lookup failed for '$($agentIdentity.displayName)' ($($agentIdentity.id)): $($_.Exception.Message)" -NoDebugOnly -Verbose
    }

    $missingSponsor = -not $sponsorLookupFailed -and $sponsors.Count -eq 0
    $missingOwner = -not $ownerLookupFailed -and $owners.Count -eq 0

    if (-not (Test-InReportScope -Scope $ReportScope -MissingSponsor $missingSponsor -MissingOwner $missingOwner -SponsorLookupFailed $sponsorLookupFailed -OwnerLookupFailed $ownerLookupFailed)) {
        continue
    }

    $findings = [System.Collections.Generic.List[string]]::new()
    if ($sponsorLookupFailed) {
        $findings.Add('UNKNOWN: Sponsor lookup failed')
    }
    elseif ($missingSponsor) {
        $findings.Add('ANOMALY: No sponsor')
    }

    if ($ownerLookupFailed) {
        $findings.Add('UNKNOWN: Owner lookup failed')
    }
    elseif ($missingOwner) {
        $findings.Add('Ownerless (legitimate)')
    }

    if ($findings.Count -eq 0) {
        $findings.Add('No finding')
    }

    $blueprint = $blueprintsById[$agentIdentity.agentIdentityBlueprintId]
    $createdOn = if ($agentIdentity.createdDateTime) {
        ([datetime]$agentIdentity.createdDateTime).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
    }
    else {
        'Unknown'
    }

    $report.Add([PSCustomObject]@{
        Status             = if ($agentIdentity.accountEnabled) { 'Active' } else { 'Inactive' }
        Finding            = $findings -join '; '
        Sponsors           = if ($sponsorLookupFailed) { 'Unknown (lookup failed)' } elseif ($sponsors.Count -eq 0) { '-' } else { ($sponsors | ForEach-Object { Get-DirectoryObjectLabel -DirectoryObject $_ }) -join '; ' }
        Owners             = if ($ownerLookupFailed) { 'Unknown (lookup failed)' } elseif ($owners.Count -eq 0) { '-' } else { ($owners | ForEach-Object { Get-DirectoryObjectLabel -DirectoryObject $_ }) -join '; ' }
        BlueprintAppId     = if ($blueprint) { $blueprint.appId } elseif ($agentIdentity.agentIdentityBlueprintId) { $agentIdentity.agentIdentityBlueprintId } else { 'Unknown' }
        ObjectId           = $agentIdentity.id
        AppId              = $agentIdentity.appId
        AgentIdentity      = $agentIdentity.displayName
        AgentBlueprint     = if ($blueprint) { $blueprint.displayName } else { 'Unknown' }
        CreatedOnUtc       = $createdOn
    })
}

#endregion Evaluate Sponsors and Owners

########################################################
#region     Report Results
########################################################

$sortedReport = @($report | Sort-Object Finding, AgentIdentity)
$sponsorlessCount = @($sortedReport | Where-Object { $_.Finding -like '*ANOMALY: No sponsor*' }).Count
$ownerlessCount = @($sortedReport | Where-Object { $_.Finding -like '*Ownerless (legitimate)*' }).Count
$lookupFailureCount = @($sortedReport | Where-Object { $_.Finding -like '*UNKNOWN:*' }).Count

Write-Output ""
Write-Output "## Entra Agent Identity sponsor and owner report"
Write-Output "Scope: $ReportScope"
Write-Output "Reported identities: $($sortedReport.Count)"
Write-Output "Sponsorless anomalies: $sponsorlessCount"
Write-Output "Ownerless identities (legitimate): $ownerlessCount"
Write-Output "Identities with lookup failures: $lookupFailureCount"
Write-Output ""

if ($sortedReport.Count -eq 0) {
    Write-Output "No Agent Identities matched the selected report scope."
}
else {
    $sortedReport | Format-List Status, Finding, Sponsors, Owners, BlueprintAppId, ObjectId, AppId, AgentIdentity, AgentBlueprint, CreatedOnUtc
}

#endregion Report Results
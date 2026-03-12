<#
    .SYNOPSIS
    Generate and email a comprehensive Application Registration report

    .DESCRIPTION
    This runbook generates a report of all application registrations in Microsoft Entra ID and can optionally include deleted registrations.
    It exports the results to CSV files and sends them via email.
    Use it for periodic inventory, review, and audit purposes.

    .PARAMETER EmailTo
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization.

    .PARAMETER IncludeDeletedApps
    Whether to include deleted application registrations in the report (default: true)

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)"
            },
            "EmailFrom": {
                "Hide": true
            },
            "IncludeDeletedApps": {
                "DisplayName": "Include Deleted Applications"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1" }

param(
    [Parameter(Mandatory = $true)]
    [string]$EmailTo,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom,

    [bool]$IncludeDeletedApps = $true,

    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "Include Deleted Apps: $IncludeDeletedApps" -Verbose

#endregion

########################################################
#region     Parameter Validation
########################################################

# Validate Email Addresses
if (-not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -Verbose
    throw "This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
    exit
}

if (-not $EmailTo) {
    Write-RjRbLog -Message "The recipient email address is required. It could be a single address or multiple comma-separated addresses." -Verbose
    throw "The recipient email address is required."
}

if ($IncludeDeletedApps -notin $true, $false) {
    Write-RjRbLog -Message "Invalid value for IncludeDeletedApps. Please specify true or false." -Verbose
    throw "Invalid value for IncludeDeletedApps. Please specify true or false."
}

########################################################
#region     Email Function Definitions
########################################################
function Get-AllGraphPage {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Get-AllGraphPage takes an initial Microsoft Graph API URI and retrieves all items across
        multiple pages by following the @odata.nextLink property in the response. It aggregates
        all items into a single array and returns it.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/applications".

        .EXAMPLE
        PS C:\> $allApps = Get-AllGraphPage -Uri "https://graph.microsoft.com/v1.0/applications"
#>
    param(
        [string]$Uri
    )

    $allResults = @()
    $nextLink = $Uri

    do {
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET

        if ($response.value) {
            $allResults += $response.value
        }
        elseif ($response.'@odata.context') {
            # Single item response
            $allResults += $response
        }

        if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
            $nextLink = $response.'@odata.nextLink'
        }
        else {
            $nextLink = $null
        }
    } while ($nextLink)

    return $allResults
}

#endregion

########################################################
#region     Connect and Initialize
########################################################

Write-Output "Connecting to Microsoft Graph..."
Connect-MgGraph -Identity -NoWelcome

Write-Output "Getting basic tenant information..."
# Get tenant information
$tenant = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method GET
if ($tenant.value -and (($(($tenant.value) | Measure-Object).Count) -gt 0)) {
    $tenant = $tenant.value[0]
}
elseif ($tenant.'@odata.context') {
    # Single tenant response
    $tenant = $tenant
}
else {
    Write-Error "Could not retrieve tenant information" -ErrorAction Continue
    throw "Could not retrieve tenant information"
}

$tenantDisplayName = $tenant.displayName
$tenantId = $tenant.id

Write-RjRbLog -Message "Tenant: $tenantDisplayName ($tenantId)" -Verbose

# Connect RJ RunbookHelper for email reporting
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

Write-Output "Preparing temporary directory for CSV files..."
# Create temporary directory for CSV files
$tempDir = Join-Path (Get-Location).Path "AppRegReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

#endregion

########################################################
#region     Get App Registrations
########################################################

Write-Output "Retrieving all App Registrations..."

$allAppRegs = Get-AllGraphPage -Uri "https://graph.microsoft.com/v1.0/applications"
Write-Output "Found $((($(($allAppRegs) | Measure-Object).Count))) App Registrations..."

$appRegResults = @()
$processedCount = 0

foreach ($appReg in $allAppRegs) {
    $processedCount++
    if ($processedCount % 50 -eq 0) {
        Write-RjRbLog -Message "Processed $processedCount of $((($(($allAppRegs) | Measure-Object).Count))) App Registrations..." -Verbose
    }

    # Create standardized object
    $tempObj = [PSCustomObject]@{
        AppId             = $appReg.appId
        AppRegObjectId    = $appReg.id
        DisplayName       = $appReg.displayName
        CreatedDateTime   = $appReg.createdDateTime
        PublisherDomain   = $appReg.publisherDomain
        SignInAudience    = $appReg.signInAudience
        AppRegPortalLink  = "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($appReg.appId)"
        AccountEnabled    = $false
        TenantId          = $tenantId
        IsDeleted         = $false
        HasSecrets        = ((($(($appReg.passwordCredentials) | Measure-Object).Count) -gt 0))
        HasCertificates   = ((($(($appReg.keyCredentials) | Measure-Object).Count) -gt 0))
        SecretsCount      = (($(($appReg.passwordCredentials) | Measure-Object).Count))
        CertificatesCount = (($(($appReg.keyCredentials) | Measure-Object).Count))
    }

    # Get associated Service Principal
    try {
        $spnUri = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$($appReg.appId)'"
        $spnResponse = Invoke-MgGraphRequest -Uri $spnUri -Method GET -ErrorAction SilentlyContinue

        if ($spnResponse.value -and (($(($spnResponse.value) | Measure-Object).Count) -gt 0)) {
            $spn = $spnResponse.value[0]
            $tempObj.SpnObjectId = $spn.id
            $tempObj.SpnPortalLink = "https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($spn.id)/appId/$($appReg.appId)"
            $tempObj.AccountEnabled = $spn.accountEnabled
        }
    }
    catch {
        Write-RjRbLog -Message "Could not retrieve Service Principal for App: $($appReg.displayName)" -Verbose
    }

    $appRegResults += $tempObj
}

Write-RjRbLog -Message "Processed all $((($(($appRegResults) | Measure-Object).Count))) App Registrations" -Verbose

#endregion

########################################################
#region     Get Deleted App Registrations (if requested)
########################################################

$deletedAppRegResults = @()

if ($IncludeDeletedApps) {
    Write-Output "Retrieving deleted App Registrations..."

    try {
        $deletedAppRegs = Get-AllGraphPage -Uri "https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.application"
        Write-Output "Found $((($(($deletedAppRegs) | Measure-Object).Count))) deleted App Registrations"

        foreach ($appReg in $deletedAppRegs) {
            $tempObj = [PSCustomObject]@{
                AppId             = $appReg.appId
                AppRegObjectId    = $appReg.id
                DisplayName       = $appReg.displayName
                CreatedDateTime   = $appReg.createdDateTime
                DeletedDateTime   = $appReg.deletedDateTime
                PublisherDomain   = $appReg.publisherDomain
                SignInAudience    = $appReg.signInAudience
                AppRegPortalLink  = "" # Not accessible for deleted apps
                AccountEnabled    = $false
                TenantId          = $tenantId
                IsDeleted         = $true
                HasSecrets        = ((($(($appReg.passwordCredentials) | Measure-Object).Count) -gt 0))
                HasCertificates   = ((($(($appReg.keyCredentials) | Measure-Object).Count) -gt 0))
                SecretsCount      = (($(($appReg.passwordCredentials) | Measure-Object).Count))
                CertificatesCount = (($(($appReg.keyCredentials) | Measure-Object).Count))
            }

            $deletedAppRegResults += $tempObj
        }

        Write-RjRbLog -Message "Processed $((($(($deletedAppRegResults) | Measure-Object).Count))) deleted App Registrations" -Verbose
    }
    catch {
        Write-RjRbLog -Message "Warning: Could not retrieve deleted App Registrations: $($_.Exception.Message)" -Verbose
    }
}

#endregion

########################################################
#region     Export to CSV Files
########################################################

$csvFiles = @()

# Export active App Registrations
$activeAppRegCsv = Join-Path $tempDir "AppRegistrations_Active.csv"
$appRegResults | Export-Csv -Path $activeAppRegCsv -NoTypeInformation -Encoding UTF8
$csvFiles += $activeAppRegCsv
Write-Verbose "Exported active App Registrations to: $activeAppRegCsv"

# Export deleted App Registrations (if any)
if ((($(($deletedAppRegResults) | Measure-Object).Count) -gt 0)) {
    $deletedAppRegCsv = Join-Path $tempDir "AppRegistrations_Deleted.csv"
    $deletedAppRegResults | Export-Csv -Path $deletedAppRegCsv -NoTypeInformation -Encoding UTF8
    $csvFiles += $deletedAppRegCsv
    Write-Verbose "Exported deleted App Registrations to: $deletedAppRegCsv"
}

#endregion

########################################################
#region     Prepare Email Content
########################################################

Write-Output "Preparing email content..."
# Generate statistics
$activeAppsWithSecrets = (($(($appRegResults | Where-Object { $_.HasSecrets }) | Measure-Object).Count))
$activeAppsWithCerts = (($(($appRegResults | Where-Object { $_.HasCertificates }) | Measure-Object).Count))
$enabledApps = (($appRegResults | Where-Object { $_.AccountEnabled }) | Measure-Object).Count

# Create markdown content for email
$markdownContent = @"
# Application Registration Report

This report provides a comprehensive overview of all Application Registrations in your Entra ID.

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Active App Registrations** | $($appRegResults.Count) |
| **Deleted App Registrations** | $($deletedAppRegResults.Count) |
| **Enabled Service Principals** | $($enabledApps) |
| **Apps with Client Secrets** | $($activeAppsWithSecrets) |
| **Apps with Certificates** | $($activeAppsWithCerts) |

## Report Details

### Active Application Registrations
- **File:** AppRegistrations_Active.csv
- **Count:** $($appRegResults.Count) applications
- Contains all currently active App Registrations with their associated Service Principals

$(if ($deletedAppRegResults.Count -gt 0) {
@"

### Deleted Application Registrations
- **File:** AppRegistrations_Deleted.csv
- **Count:** $($deletedAppRegResults.Count) applications
- Contains App Registrations that have been deleted but are still recoverable
"@
} else {
"### Deleted Application Registrations
No deleted App Registrations found in the tenant."
})

## Security Recommendations

### Applications with Client Secrets
$($activeAppsWithSecrets) applications have client secrets configured. Please review these regularly:
- Ensure secrets are rotated according to your security policy
- Remove unused secrets to reduce attack surface
- Consider migrating to certificate-based authentication where possible

### Applications with Certificates
$($activeAppsWithCerts) applications use certificate-based authentication:
- Monitor certificate expiration dates
- Ensure certificates are stored securely
- Have a renewal process in place

## Data Export Information

The attached CSV files contain detailed information including:
- Application ID and Object ID
- Display Name and Creation Date
- Publisher Domain and Sign-in Audience
- Authentication method details (secrets/certificates)
- Direct links to Azure Portal for management
"@

#endregion

########################################################
#region     Send Email Report
########################################################

Write-Output "Send email report..."
Write-Output ""

$emailSubject = "App Registration Report - $($tenantDisplayName) - $(Get-Date -Format 'yyyy-MM-dd')"

try {
    Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -Attachments $csvFiles -TenantDisplayName $tenantDisplayName -ReportVersion $Version

    Write-RjRbLog -Message "Email report sent successfully to: $($EmailTo)" -Verbose
    Write-Output "✅ App Registration report generated and sent successfully"
    Write-Output "📧 Recipient: $($EmailTo)"
    Write-Output "📊 Active Apps: $($appRegResults.Count)"
    Write-Output "🗑️ Deleted Apps: $($deletedAppRegResults.Count)"
}
catch {
    Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
    throw "Failed to send email report: $($_.Exception.Message)"
}

#endregion

########################################################
#region     Cleanup
########################################################

# Clean up temporary files
try {
    Remove-Item -Path $tempDir -Recurse -Force
    Write-RjRbLog -Message "Cleaned up temporary directory: $($tempDir)" -Verbose
}
catch {
    Write-RjRbLog -Message "Warning: Could not clean up temporary directory: $($_.Exception.Message)" -Verbose
}

Write-RjRbLog -Message "App Registration email report completed successfully" -Verbose

#endregion
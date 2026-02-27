<#
    .SYNOPSIS
    Monitor and report pending Endpoint Privilege Management (EPM) elevation requests

    .DESCRIPTION
    Queries Microsoft Intune for pending EPM elevation requests and sends an email report.
    Email is only sent when there are pending requests.
    Optionally includes detailed information about each request in a table and CSV attachment.

    .NOTES
    Runbook Type: Scheduled (recommended: hourly or every 1 hours)

    Endpoint Privilege Management (EPM) Context:
    - EPM allows users to request temporary admin rights for specific applications
    - Pending requests require manual review and approval by security admins
    - Requests expire automatically if not reviewed within the configured timeframe
    - Timely review is critical for user productivity and security posture

    Email Behavior:
    - Emails are sent individually to each recipient
    - No email is sent when there are zero pending requests
    - CSV attachment is only included when DetailedReport is enabled


    .PARAMETER EmailTo
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization.

    .PARAMETER DetailedReport
    When enabled, includes detailed request information in a table and as CSV attachment.
    When disabled, only provides a summary count of pending requests.

    .PARAMETER CallerName
    Internal parameter for tracking purposes

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
			"DetailedReport": {
				"DisplayName": "Include detailed request information"
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1" }

param(
    [Parameter(Mandatory = $true)]
    [string] $CallerName,
    [bool] $DetailedReport = $false,
    [string] $EmailTo,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom
)

########################################################
#region     RJ Log Part
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "Detailed Report: $DetailedReport" -Verbose

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

#endregion

########################################################
#region     Function Definitions
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

# Connect RJ RunbookHelper for email reporting
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

#endregion

########################################################
#region     Get Pending EPM Elevation Requests
########################################################

Write-Output "## Querying pending EPM elevation requests..."

$currentDate = Get-Date

try {
    $filter = [System.Uri]::EscapeDataString("status eq 'Pending'")
    $Uri = "https://graph.microsoft.com/beta/deviceManagement/elevationRequests?`$filter=$filter"

    $pendingRequests = Get-AllGraphPage -Uri $Uri -ErrorAction Stop

    Write-Output "Found $($pendingRequests.Count) pending elevation request(s)."

    # If no pending requests, exit without sending email
    if ($pendingRequests.Count -eq 0) {
        Write-Output ""
        Write-Output "## No pending EPM elevation requests found."
        Write-Output "No email will be sent as there are no pending requests."
        exit 0
    }

}
catch {
    Write-Error "Failed to retrieve EPM elevation requests: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

#endregion

########################################################
#region     Process and Prepare Data
########################################################

# Prepare structured data for display and export
$processedRequests = @()

foreach ($request in $pendingRequests) {
    $requestCreated = if ($request.requestCreatedDateTime) {
        [datetime]$request.requestCreatedDateTime
    } else {
        $null
    }

    $requestExpiry = if ($request.requestExpiryDateTime) {
        [datetime]$request.requestExpiryDateTime
    } else {
        $null
    }

    $daysUntilExpiry = if ($requestExpiry) {
        [math]::Floor(($requestExpiry - $currentDate).TotalDays)
    } else {
        $null
    }

    $fileName = if ($request.applicationDetail.fileName) {
        $request.applicationDetail.fileName
    } else {
        "Unknown"
    }

    $productName = if ($request.applicationDetail.productName) {
        $request.applicationDetail.productName
    } else {
        "Unknown"
    }

    $processedRequests += [PSCustomObject]@{
        RequestId               = $request.id
        RequestedBy             = $request.requestedByUserPrincipalName
        DeviceId                = $request.requestedOnDeviceId
        FileName                = $fileName
        ProductName             = $productName
        FileHash                = if ($request.applicationDetail.fileHash) { $request.applicationDetail.fileHash } else { "N/A" }
        Justification           = if ($request.requestJustification) { $request.requestJustification } else { "None provided" }
        RequestCreated          = $requestCreated
        RequestExpiry           = $requestExpiry
        DaysUntilExpiry         = $daysUntilExpiry
        Status                  = $request.status
    }
}

# Display summary
Write-Output ""
Write-Output "## Summary of Pending EPM Elevation Requests:"
Write-Output "Total pending requests: $($processedRequests.Count)"

if ($DetailedReport) {
    Write-Output ""
    Write-Output "## Detailed list:"
    Write-Output ""
    $processedRequests | Sort-Object -Property RequestCreated | Format-Table -AutoSize
}

#endregion

########################################################
#region     Generate Email Report
########################################################

Write-Output ""
Write-Output "## Preparing email report to send to $($EmailTo)"

# Build markdown table for detailed view
$detailedTable = if ($DetailedReport -and $processedRequests.Count -gt 0) {
    $sortedRequests = $processedRequests | Sort-Object -Property RequestCreated
    $maxRowsInEmail = 10
    $displayRequests = if ($sortedRequests.Count -gt $maxRowsInEmail) {
        $sortedRequests | Select-Object -First $maxRowsInEmail
    } else {
        $sortedRequests
    }

    $rows = foreach ($req in $displayRequests) {
        $createdText = if ($req.RequestCreated) { $req.RequestCreated.ToString("yyyy-MM-dd HH:mm") } else { "Unknown" }
        $expiryText = if ($req.RequestExpiry) {
            "$($req.RequestExpiry.ToString('yyyy-MM-dd HH:mm')) ($($req.DaysUntilExpiry) days)"
        } else {
            "Unknown"
        }
        $justificationText = $req.Justification -replace '\|', '&#124;' -replace '\n', ' ' -replace '\r', ''

        "| $createdText | $($req.RequestedBy) | $($req.FileName) | $($req.DeviceId) | $expiryText | $justificationText |"
    }

    $additionalRowsNote = if ($sortedRequests.Count -gt $maxRowsInEmail) {
        "`n`nShowing first $maxRowsInEmail of $($sortedRequests.Count) pending requests. See attached CSV file for complete list."
    } else {
        ""
    }

    @"

## Detailed Request Information

| Created | Requested By | File Name | DeviceId | Expires | Justification |
|---------|--------------|-----------|----------|---------|---------------|
$($rows -join "`n")$additionalRowsNote

"@
} else {
    ""
}

# Create markdown content
$markdownContent = @"
# Pending EPM Elevation Requests Report

Tenant **$($tenantDisplayName)** (ID: $($tenantId))

- Report date: $($currentDate.ToString('yyyy-MM-dd HH:mm'))
- Pending requests: **$($processedRequests.Count)**

## Summary

There are currently **$($processedRequests.Count)** pending Endpoint Privilege Management elevation request(s) awaiting review.

### Statistics

| Metric | Value |
|--------|-------|
| **Total Pending Requests** | $($processedRequests.Count) |
| **Unique Users** | $(($processedRequests | Select-Object -ExpandProperty RequestedBy -Unique | Measure-Object).Count) |
| **Unique Devices** | $(($processedRequests | Select-Object -ExpandProperty DeviceId -Unique | Measure-Object).Count) |
| **Applications Requested** | $(($processedRequests | Select-Object -ExpandProperty FileName -Unique | Measure-Object).Count) |

$detailedTable

## Next Steps

**1. Access Intune Admin Center:**

- Go to [Intune Admin Center](https://intune.microsoft.com)
- Navigate to: Endpoint Security > Endpoint Privilege Management > Elevation requests

**2. Review Each Request:**

- Verify user identity and business need
- Check application details and file hash
- Review justification provided by the user

**3. Take Action:**

- Approve legitimate requests
- Deny suspicious or unjustified requests
- Add approved items to EPM automatic elevation rules if appropriate

$(if ($DetailedReport) {
@"

## Attachments

The CSV file attached to this email contains the complete list of pending elevation requests for further analysis and tracking.
"@
} else {
@"

## Detailed Information

To receive detailed request information including a CSV export, enable the "Include detailed request information" option in the runbook parameters.
"@
})

"@

# Create CSV file if detailed report is requested
$attachments = @()
if ($DetailedReport) {
    $csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath "$(Get-Date -Format 'yyyyMMdd_HHmmss')_PendingEPMRequests_$($tenantDisplayName).csv"
    $processedRequests | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
    $attachments += $csvFilePath
    Write-RjRbLog -Message "Exported pending requests to CSV: $($csvFilePath)" -Verbose
}

# Send email report
$emailSubject = "[Action Required] $($processedRequests.Count) Pending EPM Elevation Request(s) - $($tenantDisplayName)"

Write-Output "Sending report to '$($EmailTo)'..."
try {
    Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version -Attachments $attachments
    Write-RjRbLog -Message "Email sent successfully to: $($EmailTo)" -Verbose
    Write-Output "Email report sent to '$($EmailTo)'."
}
catch {
    Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

#endregion

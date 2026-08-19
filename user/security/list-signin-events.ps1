<#
    .SYNOPSIS
    Retrieve and analyze sign-in events for a target user

    .DESCRIPTION
    Retrieves the target user's Entra ID sign-in logs from the Microsoft Graph beta endpoint and analyzes them: each sign-in's application, timestamp, status (with error codes and failure reasons if applicable), client app, device and location information is displayed, and a per-application failure summary helps support teams identify which applications are experiencing issues and diagnose the underlying causes. IP addresses are shown in the failed sign-in view; conditional access details are included in the exported report files. The runbook can optionally export the full data set to CSV and XLSX files and deliver them by email and/or a time-limited download link.

    .PARAMETER UserName
    User principal name of the target user.

    .PARAMETER Days
    Number of days to retrieve sign-in logs for (1 to 30 days). Default is 7 days.

    .PARAMETER SignInType
    Filter sign-in events by type: Interactive only, Non-interactive only, or both.

    .PARAMETER FailedSignInsOnly
    If set to true, only failed sign-in attempts are displayed. If false, all sign-in events are shown.

    .PARAMETER ApplicationName
    Optional filter to display sign-ins for a specific application only (partial match). Leave empty to include all applications.

    .PARAMETER EmailFrom
    The sender email address. Sourced from the RJReport.EmailSender tenant setting. This needs to be configured in the runbook customization.

    .PARAMETER BrandingHeaderImageUrl
    Optional public HTTPS URL of a custom header image (PNG/JPEG/GIF, max. 200 KB) for the report email.
    Sourced from the RJReport.Branding.HeaderImageUrl tenant setting. When empty, the default RealmJoin header graphic is used.

    .PARAMETER BrandingFooterImageUrl
    Optional public HTTPS URL of a custom footer image (PNG/JPEG/GIF, max. 200 KB) for the report email.
    Sourced from the RJReport.Branding.FooterImageUrl tenant setting. When empty, the default RealmJoin footer graphic is used.

    .PARAMETER BrandingFooterLink
    Optional URL the footer image links to. Sourced from the RJReport.Branding.FooterLink tenant setting.
    When empty, the default link (https://www.realmjoin.com) is used.

    .PARAMETER BrandingAccentColor
    Optional accent color override (6-digit hex, e.g. '#0052cc') for the report email template.
    Sourced from the RJReport.Branding.AccentColor tenant setting. When empty or invalid, the default RealmJoin accent color is used.

    .PARAMETER BrandingTextColor
    Optional text color override (6-digit hex) for the report email template.
    Sourced from the RJReport.Branding.TextColor tenant setting. When empty or invalid, the default RealmJoin text color is used.

    .PARAMETER SendEmailReport
    If set to true, the sign-in report will be sent by email. If false, no email is sent.

    .PARAMETER EmailTo
    Recipient email address(es) for the report. Can be a single address or multiple comma-separated addresses.
    Emails are sent individually to each recipient.

    .PARAMETER ReportFileFormat
    Select the report file format: CSV & XLSX (both files), CSV only, or XLSX only. Only used when a delivery method (email or download link) is selected.

    .PARAMETER CreateDownloadLink
    If set to true, the report files will be uploaded to Azure Storage and a time-limited download link will be generated. If false, no upload occurs.

    .PARAMETER ContainerName
    Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

    .PARAMETER ResourceGroupName
    Resource group that contains the storage account. Sourced from the RJReport tenant settings.

    .PARAMETER StorageAccountName
    Storage account name used for the upload. Sourced from the RJReport tenant settings.

    .PARAMETER LinkExpiryDays
    Number of days until the generated download link expires (1 to 3650 days). Sourced from the RJReport tenant settings. Default is 6 days.

    .PARAMETER CallerName
    Name of the user or system that started the runbook. Tracked for auditing purposes.

    .NOTES
    Common Use Cases:
    - Investigate which application is generating sign-in failures for a specific user and why (grouped by error code).
    - Narrow results with ApplicationName (partial match) or FailedSignInsOnly when a user reports access issues.
    - Export sign-in data to CSV/XLSX for further analysis in Excel when the event count is too large to read in the portal.

    Behavior:
    - Sign-in log data is retrieved from the Microsoft Graph beta endpoint because sign-in event type filtering
      and non-interactive sign-in retrieval require beta-only properties (signInEventTypes, authenticationRequirement).
    - Non-interactive sign-ins vastly outnumber interactive ones; the console detail tables are capped at the
      50 most recent entries, but exported report files always contain the full result set.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "Days": {
                "DisplayName": "Lookback Period (Days)"
            },
            "SignInType": {
                "DisplayName": "Sign-In Type"
            },
            "FailedSignInsOnly": {
                "DisplayName": "Show Failed Sign-Ins Only"
            },
            "ApplicationName": {
                "DisplayName": "Filter by Application Name (optional)"
            },
            "EmailFrom": {
                "Hide": true
            },
            "BrandingHeaderImageUrl": {
                "Hide": true
            },
            "BrandingFooterImageUrl": {
                "Hide": true
            },
            "BrandingFooterLink": {
                "Hide": true
            },
            "BrandingAccentColor": {
                "Hide": true
            },
            "BrandingTextColor": {
                "Hide": true
            },
            "SendEmailReport": {
                "Hide": true
            },
            "CreateDownloadLink": {
                "Hide": true
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)",
                "Hide": true
            },
            "ReportFileFormat": {
                "DisplayName": "Report file format",
                "Hide": true,
                "Select": {
                    "Options": [
                        { "Display": "CSV & XLSX", "ParameterValue": "CSV & XLSX" },
                        { "Display": "CSV only", "ParameterValue": "CSV only" },
                        { "Display": "XLSX only", "ParameterValue": "XLSX only" }
                    ],
                    "ShowValue": false
                }
            },
            "ContainerName": {
                "Hide": true
            },
            "ResourceGroupName": {
                "Hide": true
            },
            "StorageAccountName": {
                "Hide": true
            },
            "LinkExpiryDays": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        },
        "ParameterList": [
            {
                "DisplayName": "Report delivery",
                "DisplayAfter": "ApplicationName",
                "Select": {
                    "Options": [
                        {
                            "Display": "No report",
                            "Customization": {
                                "Default": { "SendEmailReport": false, "CreateDownloadLink": false },
                                "Hide": [ "EmailTo", "ReportFileFormat" ]
                            }
                        },
                        {
                            "Display": "Email report",
                            "Customization": {
                                "Default": { "SendEmailReport": true, "CreateDownloadLink": false },
                                "Show": [ "EmailTo", "ReportFileFormat" ],
                                "Mandatory": [ "EmailTo" ]
                            }
                        },
                        {
                            "Display": "Report download link",
                            "Customization": {
                                "Default": { "SendEmailReport": false, "CreateDownloadLink": true },
                                "Show": [ "ReportFileFormat" ],
                                "Hide": [ "EmailTo" ]
                            }
                        },
                        {
                            "Display": "Email report & download link",
                            "Customization": {
                                "Default": { "SendEmailReport": true, "CreateDownloadLink": true },
                                "Show": [ "EmailTo", "ReportFileFormat" ],
                                "Mandatory": [ "EmailTo" ]
                            }
                        }
                    ]
                },
                "Default": "No report"
            }
        ]
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param (
    [Parameter(Mandatory = $true)]
    [String]$UserName,

    [ValidateRange(1, 30)]
    [int]$Days = 7,

    [ValidateSet('Interactive only', 'Non-interactive only', 'Interactive & non-interactive')]
    [string]$SignInType = 'Interactive only',

    [bool]$FailedSignInsOnly = $false,

    [string]$ApplicationName = "",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ } )]
    [string]$EmailFrom,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ } )]
    [string]$BrandingHeaderImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ } )]
    [string]$BrandingFooterImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ } )]
    [string]$BrandingFooterLink,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" -Value $_ } )]
    [string]$BrandingAccentColor,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" -Value $_ } )]
    [string]$BrandingTextColor,

    [bool]$SendEmailReport = $false,

    [string]$EmailTo,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "user-signin-events",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ } )]
    [string]$ResourceGroupName,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ } )]
    [string]$StorageAccountName,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ } )]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,

    # CallerName is tracked purely for auditing purposes
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

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "Days: $Days" -Verbose
Write-RjRbLog -Message "SignInType: $SignInType" -Verbose
Write-RjRbLog -Message "FailedSignInsOnly: $FailedSignInsOnly" -Verbose
Write-RjRbLog -Message "ApplicationName: $ApplicationName" -Verbose
Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

$UserName = $UserName.Trim()
if ([string]::IsNullOrWhiteSpace($UserName)) {
    Write-Error "No user was supplied. Start this runbook from a user in the RealmJoin portal." -ErrorAction Continue
    throw "UserName is empty"
}

if (-not [string]::IsNullOrWhiteSpace($ApplicationName)) {
    $ApplicationName = $ApplicationName.Trim()
}

# Email report requested but no recipient specified - fail loudly instead of silently sending nothing.
# (The portal's delivery selector marks EmailTo mandatory for the email options, but this guard
# still fires for scheduled runs and API starts that bypass the portal customization.)
if ($SendEmailReport -and -not $EmailTo) {
    Write-Error "Email report was requested (SendEmailReport = true) but no EmailTo recipient was specified." -ErrorAction Continue
    throw "Missing EmailTo recipient for email report delivery."
}

# A sender address is required before any mail can be sent
if ($SendEmailReport -and -not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -Verbose
    throw "This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings"
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

#endregion Parameter Validation

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response. Logs progress for slow or
        large pulls and surfaces Graph errors with the failing URI for easier troubleshooting.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/beta/auditLogs/signIns".

        .EXAMPLE
        PS C:\> $allSignIns = Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/auditLogs/signIns?`$top=1000"
    #>
    param(
        [string]$Uri
    )

    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    $pageCount = 0

    do {
        try {
            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to retrieve paged data from '$nextLink': $($_.Exception.Message)" -ErrorAction Continue
            throw
        }

        $pageCount++
        if ($response.value) {
            $allResults.AddRange([object[]]$response.value)
        }

        if ($pageCount % 5 -eq 0) {
            Write-RjRbLog -Message "Pagination progress: $pageCount pages, $($allResults.Count) items retrieved so far" -Verbose
        }

        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    if ($pageCount -gt 1) {
        Write-RjRbLog -Message "Pagination complete: $pageCount pages, $($allResults.Count) total items" -Verbose
    }

    return $allResults.ToArray()
}

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph using the managed identity. Ensure the Automation Account's managed identity is enabled and has the required Graph API permissions assigned. Error: $_" -ErrorAction Continue
    throw
}

$tenantDisplayName = "Unknown Tenant"

if ($SendEmailReport) {
    # Connect RJ RunbookHelper for email reporting
    try {
        Connect-RjRbGraph
    }
    catch {
        Write-Error "Failed to establish the RealmJoin Graph connection required to send the email report. Error: $_" -ErrorAction Continue
        throw
    }

    try {
        $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
        if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
            $tenantDisplayName = $organizationResponse.value[0].displayName
        }
        Write-RjRbLog -Message "Tenant: $tenantDisplayName" -Verbose
    }
    catch {
        Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
    }
}

#endregion Connect Part

########################################################
#region     Data Collection
########################################################

# Resolve the target user by UPN.
# The UPN is percent-encoded: guest/B2B UPNs contain '#' (e.g. user_contoso.com#EXT#@tenant.onmicrosoft.com),
# which would otherwise be parsed as a URI fragment delimiter and truncate the path segment.
Write-Output ""
Write-Output "Resolving target user..."
Write-Output "---------------------"

try {
    $targetUser = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($UserName))?`$select=id,userPrincipalName,displayName" -Method GET -ErrorAction Stop
}
catch {
    # Prefer the actual HTTP status code exposed by the exception; fall back to
    # matching the message text only if the SDK didn't surface a status code.
    $statusCode = $null
    $exceptionObj = $_.Exception
    if ($exceptionObj.PSObject.Properties['StatusCode'] -and $exceptionObj.StatusCode) {
        $statusCode = [int]$exceptionObj.StatusCode
    }
    elseif ($exceptionObj.PSObject.Properties['Response'] -and $exceptionObj.Response -and
        $exceptionObj.Response.PSObject.Properties['StatusCode']) {
        $statusCode = [int]$exceptionObj.Response.StatusCode
    }

    if ($statusCode -eq 404 -or (-not $statusCode -and $exceptionObj.Message -match "404")) {
        Write-Error "User '$UserName' not found in Entra ID. Please verify the user principal name is correct and that the account exists in this tenant." -ErrorAction Continue
        throw "User '$UserName' not found"
    }
    Write-Error "Failed to resolve user '$UserName': $($exceptionObj.Message)" -ErrorAction Continue
    throw
}

Write-Output "Resolved user: $($targetUser.displayName) ($($targetUser.userPrincipalName))"

# Calculate the lookback start date in ISO 8601 format
$startDate = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString("yyyy-MM-ddTHH:mm:ssZ")
Write-Output "Lookback period: $Days days, starting $startDate (UTC)"

# Build the OData filter for the sign-in query
$filterParts = @(
    "userId eq '$($targetUser.id)'"
    "createdDateTime ge $startDate"
)

# The signIns endpoint returns interactive sign-ins only unless signInEventTypes is filtered explicitly
if ($SignInType -eq 'Non-interactive only') {
    $filterParts += "signInEventTypes/any(t: t eq 'nonInteractiveUser')"
}
elseif ($SignInType -eq 'Interactive only') {
    $filterParts += "signInEventTypes/any(t: t eq 'interactiveUser')"
}
else {
    $filterParts += "signInEventTypes/any(t: t eq 'interactiveUser' or t eq 'nonInteractiveUser')"
}

if ($FailedSignInsOnly) {
    $filterParts += "status/errorCode ne 0"
}

$filter = $filterParts -join " and "
Write-RjRbLog -Message "Sign-in filter: $filter" -Verbose

# Retrieve sign-in records using pagination
Write-Output ""
Write-Output "Retrieving sign-in records..."
Write-Output "---------------------"
Write-Output "Note: This may take a while depending on the volume of sign-in events."

# The beta endpoint is required here, not a preference: 'signInEventTypes' and 'authenticationRequirement'
# do not exist on the v1.0 signIn resource, and v1.0 does not return non-interactive sign-ins at all.
# $select bounds the response payload to the properties Data Processing actually reads. An unprojected
# beta sign-in record is ~10 KB (mostly appliedConditionalAccessPolicies), which would accumulate to
# hundreds of MB in the sandbox on a wide query; the projection cuts that by roughly 90%.
$selectProperties = "id,createdDateTime,appDisplayName,resourceDisplayName,status,clientAppUsed,signInEventTypes,ipAddress,location,deviceDetail,conditionalAccessStatus,authenticationRequirement,correlationId"
$uri = "https://graph.microsoft.com/beta/auditLogs/signIns?`$filter=$([uri]::EscapeDataString($filter))&`$top=1000&`$select=$selectProperties"

try {
    $signIns = @(Get-GraphPagedResult -Uri $uri)
    Write-Output "Retrieved $($signIns.Count) sign-in records"
}
catch {
    # Prefer the actual HTTP status code exposed by the exception; fall back to
    # matching the message text only if the SDK didn't surface a status code.
    $statusCode = $null
    $exceptionObj = $_.Exception
    if ($exceptionObj.PSObject.Properties['StatusCode'] -and $exceptionObj.StatusCode) {
        $statusCode = [int]$exceptionObj.StatusCode
    }
    elseif ($exceptionObj.PSObject.Properties['Response'] -and $exceptionObj.Response -and
        $exceptionObj.Response.PSObject.Properties['StatusCode']) {
        $statusCode = [int]$exceptionObj.Response.StatusCode
    }

    if ($statusCode -eq 401 -or (-not $statusCode -and ($exceptionObj.Message -match "401" -or $exceptionObj.Message -like "*Unauthorized*"))) {
        Write-Error "Authentication to Microsoft Graph failed while retrieving sign-in logs. Verify the Automation Account's managed identity is still enabled and has not been removed or disabled since the last successful run." -ErrorAction Continue
        throw "Authentication to Microsoft Graph failed"
    }
    elseif ($statusCode -eq 403 -or (-not $statusCode -and ($exceptionObj.Message -match "403" -or $exceptionObj.Message -like "*Forbidden*"))) {
        Write-Error "Insufficient permissions to access sign-in logs. Ensure the managed identity has been granted the 'AuditLog.Read.All' application permission in Microsoft Graph. Some tenants additionally require 'Directory.Read.All' for the Entra reporting API." -ErrorAction Continue
        Write-Error "Note: Reading sign-in logs through the Graph API also requires the tenant to have an Entra ID P1 or P2 license, independent of the Graph permission grant. Tenants without P1/P2 receive this error even with all permissions granted." -ErrorAction Continue
        throw "Access denied: AuditLog.Read.All permission and Entra ID P1/P2 license required"
    }
    else {
        Write-Error "Failed to retrieve sign-in records: $($exceptionObj.Message)" -ErrorAction Continue
        throw
    }
}

if ($signIns.Count -eq 0) {
    Write-Output ""
    Write-Output "No sign-in records found matching the specified criteria."
}

#endregion Data Collection

########################################################
#region     Data Processing
########################################################

# Apply the client-side application name filter if one was provided.
# The user input is escaped so that wildcard metacharacters like '[' in an
# application name are matched literally instead of being parsed as a pattern.
$filteredSignIns = $signIns
if (-not [string]::IsNullOrWhiteSpace($ApplicationName)) {
    Write-RjRbLog -Message "Filtering by application: '$ApplicationName'" -Verbose
    $escapedApplicationName = [System.Management.Automation.WildcardPattern]::Escape($ApplicationName)
    $filteredSignIns = @($signIns | Where-Object { $_["appDisplayName"] -like "*$escapedApplicationName*" })
}

$processedSignIns = @()
$appSummary = @()
$failedSignIns = @()

if ($filteredSignIns.Count -gt 0) {

    # Transform sign-in records into user-friendly objects
    $processedSignIns = @($filteredSignIns | ForEach-Object {
            $status = $_["status"]
            $location = $_["location"]
            $deviceDetail = $_["deviceDetail"]

            # Convert to UTC explicitly. Casting to [datetime] alone yields Kind=Local,
            # which would silently shift the value away from the "(UTC)" column label.
            # _TimestampSort keeps a real DateTime so records with no timestamp sort last
            # instead of being pinned to the top by a string comparison against "Unknown".
            $timestampDateTime = if ($_["createdDateTime"]) {
                ([datetime]$_["createdDateTime"]).ToUniversalTime()
            }
            else {
                [datetime]::MinValue
            }
            $timestamp = if ($timestampDateTime -ne [datetime]::MinValue) {
                $timestampDateTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
            else {
                "Unknown"
            }

            $application = if ($_["appDisplayName"]) { $_["appDisplayName"] } else { "Unknown" }
            $resource = if ($_["resourceDisplayName"]) { $_["resourceDisplayName"] } else { "Unknown" }

            $statusValue = "Success"
            if ($status -and $null -ne $status["errorCode"] -and $status["errorCode"] -ne 0) {
                $statusValue = "Failure"
            }
            $errorCode = if ($status -and $null -ne $status["errorCode"]) { $status["errorCode"].ToString() } else { "" }
            $failureReason = if ($status -and $status["failureReason"]) { $status["failureReason"] } else { "" }
            $additionalDetails = if ($status -and $status["additionalDetails"]) { $status["additionalDetails"] } else { "" }

            $clientApp = if ($_["clientAppUsed"]) { $_["clientAppUsed"] } else { "Unknown" }
            $signInEventType = if ($_["signInEventTypes"] -and $_["signInEventTypes"][0]) { $_["signInEventTypes"][0] } else { "Unknown" }
            $ipAddress = if ($_["ipAddress"]) { $_["ipAddress"] } else { "n/a" }

            $locationParts = @()
            if ($location) {
                if ($location["city"]) { $locationParts += $location["city"] }
                if ($location["state"]) { $locationParts += $location["state"] }
                if ($location["countryOrRegion"]) { $locationParts += $location["countryOrRegion"] }
            }
            $locationStr = if ($locationParts.Count -gt 0) { $locationParts -join ", " } else { "Unknown" }

            $device = if ($deviceDetail -and $deviceDetail["displayName"]) { $deviceDetail["displayName"] } else { "Unknown" }
            $os = if ($deviceDetail -and $deviceDetail["operatingSystem"]) { $deviceDetail["operatingSystem"] } else { "Unknown" }
            $browser = if ($deviceDetail -and $deviceDetail["browser"]) { $deviceDetail["browser"] } else { "Unknown" }

            $conditionalAccess = if ($_["conditionalAccessStatus"]) { $_["conditionalAccessStatus"] } else { "Not Applied" }
            $authRequirement = if ($_["authenticationRequirement"]) { $_["authenticationRequirement"] } else { "Unknown" }
            $correlationId = if ($_["correlationId"]) { $_["correlationId"] } else { "" }

            [PSCustomObject]@{
                "Timestamp (UTC)"         = $timestamp
                "_TimestampSort"          = $timestampDateTime
                Application               = $application
                Resource                  = $resource
                Status                    = $statusValue
                ErrorCode                 = $errorCode
                FailureReason             = $failureReason
                AdditionalDetails         = $additionalDetails
                ClientApp                 = $clientApp
                SignInType                = $signInEventType
                IPAddress                 = $ipAddress
                Location                  = $locationStr
                Device                    = $device
                OperatingSystem           = $os
                Browser                   = $browser
                ConditionalAccess         = $conditionalAccess
                AuthenticationRequirement = $authRequirement
                CorrelationId             = $correlationId
            }
        })

    Write-RjRbLog -Message "Processed $($processedSignIns.Count) sign-in events" -Verbose

    # Build the per-application summary
    $appSummary = @($processedSignIns | Group-Object -Property Application | ForEach-Object {
            $appEvents = $_.Group
            $total = $appEvents.Count
            $successful = @($appEvents | Where-Object { $_.Status -eq "Success" }).Count
            $failed = $total - $successful
            $failureRateValue = if ($total -gt 0) { [Math]::Round(($failed / $total) * 100, 2) } else { 0 }

            $errorSummary = @()
            $failedEvents = @($appEvents | Where-Object { $_.Status -eq "Failure" })
            if ($failedEvents.Count -gt 0) {
                $errorSummary = @($failedEvents | Group-Object -Property ErrorCode | ForEach-Object {
                        $code = $_.Name
                        $codeCount = $_.Count
                        $reasonGroups = @($_.Group | Group-Object -Property FailureReason | Sort-Object -Property Count -Descending)
                        $mostCommonReason = if ($reasonGroups.Count -gt 0) { $reasonGroups[0].Name } else { "Unknown" }
                        "$code ($codeCount) - $mostCommonReason"
                    })
            }

            [PSCustomObject]@{
                Application  = $_.Name
                TotalSignIns = $total
                Successful   = $successful
                Failed       = $failed
                FailureRate  = "$failureRateValue%"
                ErrorCodes   = $errorSummary -join " | "
            }
        } | Sort-Object -Property Failed -Descending)

    Write-Output ""
    Write-Output "Sign-In Report"
    Write-Output "---------------------"
    Write-Output "User:               $($targetUser.displayName) ($($targetUser.userPrincipalName))"
    Write-Output "Lookback Window:    $Days days"
    Write-Output "Sign-In Type:       $SignInType"
    Write-Output "Failed Only:        $(if ($FailedSignInsOnly) { 'Yes' } else { 'No' })"
    if (-not [string]::IsNullOrWhiteSpace($ApplicationName)) {
        Write-Output "Application Filter: $ApplicationName"
    }
    Write-Output "Total Events:       $($processedSignIns.Count)"

    if ($appSummary.Count -gt 0) {
        Write-Output ""
        Write-Output "Sign-In Summary per Application"
        Write-Output "---------------------"
        $appSummary | Format-Table -AutoSize | Out-String -Width 512 | Write-Output
    }

    $failedSignIns = @($processedSignIns | Where-Object { $_.Status -eq "Failure" })
    if ($failedSignIns.Count -gt 0) {
        Write-Output ""
        Write-Output "Failed Sign-In Details"
        Write-Output "---------------------"

        $failedDisplayCount = [Math]::Min($failedSignIns.Count, 50)
        if ($failedDisplayCount -lt $failedSignIns.Count) {
            Write-Output "Showing the $failedDisplayCount most recent of $($failedSignIns.Count) failed sign-ins (output truncated for readability)."
            Write-Output "The complete result set is included in the exported report files - select a report delivery option (email or download link) to receive them."
            Write-Output ""
        }

        $failedSignIns | Sort-Object -Property "_TimestampSort" -Descending | Select-Object -First $failedDisplayCount | Select-Object -Property "Timestamp (UTC)", Application, ErrorCode, FailureReason, ClientApp, IPAddress | Format-Table -AutoSize | Out-String -Width 512 | Write-Output
    }
    else {
        Write-Output ""
        Write-Output "No failed sign-in events found."
    }

    if (-not $FailedSignInsOnly) {
        Write-Output ""
        Write-Output "Sign-In Details"
        Write-Output "---------------------"

        $displayCount = [Math]::Min($processedSignIns.Count, 50)
        $displayEvents = @($processedSignIns | Sort-Object -Property "_TimestampSort" -Descending | Select-Object -First $displayCount)

        if ($displayEvents.Count -lt $processedSignIns.Count) {
            Write-Output "Showing the $displayCount most recent of $($processedSignIns.Count) events (output truncated for readability)."
            Write-Output "The complete result set is included in the exported report files - select a report delivery option (email or download link) to receive them."
            Write-Output "To narrow the result set, set an application name filter, reduce the lookback period, or enable 'Show Failed Sign-Ins Only'."
            Write-Output ""
        }

        $displayEvents | Select-Object -Property "Timestamp (UTC)", Application, Resource, Status, ErrorCode, ClientApp, SignInType, Device, Location | Format-Table -AutoSize | Out-String -Width 512 | Write-Output
    }
}
else {
    if (-not [string]::IsNullOrWhiteSpace($ApplicationName) -and $signIns.Count -gt 0) {
        Write-Output ""
        Write-Output "No sign-ins found matching the application filter '$ApplicationName'."
        Write-Output ""
        Write-Output "Applications present in the retrieved data:"
        Write-Output "---------------------"
        $availableApps = @($signIns | ForEach-Object { $_["appDisplayName"] } | Sort-Object -Unique)
        $availableApps | ForEach-Object { Write-Output "  - $_" }
    }
}

#endregion Data Processing

########################################################
#region     Report File Export
########################################################

# Initialized unconditionally so the delivery regions and Cleanup are safe on every path
$reportFiles = @()
$exportDate = Get-Date -Format 'yyyyMMdd'
$tempDir = $null
$xlsxFile = $null
$fileNameSummary = $null
$brandingMailParams = $null

# Report files are only produced when a delivery method was actually requested and there is data to deliver
if (($SendEmailReport -or $CreateDownloadLink) -and $processedSignIns.Count -gt 0) {
    # Sanitize the identifier for file and blob names: guest UPNs contain '#' (e.g. #EXT#),
    # which breaks the blob upload URL and the generated SAS links.
    $userIdentifier = ($targetUser.userPrincipalName.Split('@')[0] -replace '[^A-Za-z0-9._-]', '_')

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "UserSignInReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    try {
        New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction Stop | Out-Null
        Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose
    }
    catch {
        Write-Error "Failed to create the temporary directory for report generation: $($_.Exception.Message). The Azure Automation sandbox temp directory may not be accessible. Report delivery cannot proceed." -ErrorAction Continue
        throw "Temp directory creation failed"
    }

    $xlsxFile = Join-Path $tempDir "UserSignInReport_${userIdentifier}_$exportDate.xlsx"

    Write-Output ""
    Write-Output "Report File Export"
    Write-Output "---------------------"

    if ($ReportFileFormat -ne 'XLSX only') {
        if ($appSummary.Count -gt 0) {
            $fileNameSummary = Join-Path $tempDir "SignInSummary_${userIdentifier}_$exportDate.csv"
            $appSummary | Export-Csv -Path $fileNameSummary -NoTypeInformation -Encoding UTF8
            $reportFiles += $fileNameSummary
            Write-RjRbLog -Message "Exported $($appSummary.Count) applications to: $fileNameSummary" -Verbose
        }

        if ($failedSignIns.Count -gt 0) {
            $fileNameFailed = Join-Path $tempDir "FailedSignIns_${userIdentifier}_$exportDate.csv"
            $failedSignIns | Sort-Object -Property "_TimestampSort" -Descending | Select-Object -Property "Timestamp (UTC)", Application, Resource, ErrorCode, FailureReason, AdditionalDetails, ClientApp, SignInType, IPAddress, Location, Device, OperatingSystem, Browser, ConditionalAccess, AuthenticationRequirement, CorrelationId | Export-Csv -Path $fileNameFailed -NoTypeInformation -Encoding UTF8
            $reportFiles += $fileNameFailed
            Write-RjRbLog -Message "Exported $($failedSignIns.Count) failed sign-ins to: $fileNameFailed" -Verbose
        }

        if ($processedSignIns.Count -gt 0) {
            $fileNameAll = Join-Path $tempDir "AllSignIns_${userIdentifier}_$exportDate.csv"
            $processedSignIns | Sort-Object -Property "_TimestampSort" -Descending | Select-Object -Property "Timestamp (UTC)", Application, Resource, Status, ErrorCode, FailureReason, AdditionalDetails, ClientApp, SignInType, IPAddress, Location, Device, OperatingSystem, Browser, ConditionalAccess, AuthenticationRequirement, CorrelationId | Export-Csv -Path $fileNameAll -NoTypeInformation -Encoding UTF8
            $reportFiles += $fileNameAll
            Write-RjRbLog -Message "Exported $($processedSignIns.Count) sign-in events to: $fileNameAll" -Verbose
        }
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $worksheets = [ordered]@{}

        if ($appSummary.Count -gt 0) {
            $worksheets['Application Summary'] = $appSummary | Select-Object Application, TotalSignIns, Successful, Failed, FailureRate, ErrorCodes
        }
        if ($failedSignIns.Count -gt 0) {
            $worksheets['Failed Sign-Ins'] = $failedSignIns | Sort-Object -Property "_TimestampSort" -Descending | Select-Object 'Timestamp (UTC)', Application, Resource, Status, ErrorCode, FailureReason, AdditionalDetails, ClientApp, SignInType, IPAddress, Location, Device, OperatingSystem, Browser, ConditionalAccess, AuthenticationRequirement, CorrelationId
        }
        if ($processedSignIns.Count -gt 0) {
            $worksheets['All Sign-Ins'] = $processedSignIns | Sort-Object -Property "_TimestampSort" -Descending | Select-Object 'Timestamp (UTC)', Application, Resource, Status, ErrorCode, FailureReason, AdditionalDetails, ClientApp, SignInType, IPAddress, Location, Device, OperatingSystem, Browser, ConditionalAccess, AuthenticationRequirement, CorrelationId
        }

        if ($worksheets.Count -gt 0) {
            $coverSheet = [ordered]@{
                'Title'              = 'User Sign-In Report'
                'User'               = "$($targetUser.displayName) ($($targetUser.userPrincipalName))"
                'Lookback (Days)'    = $Days
                'Sign-In Type'       = $SignInType
                'Failed Only'        = $(if ($FailedSignInsOnly) { 'Yes' } else { 'No' })
                'Application Filter' = $(if ([string]::IsNullOrWhiteSpace($ApplicationName)) { 'All' } else { $ApplicationName })
                'Total Events'       = $processedSignIns.Count
                'Total Failures'     = $failedSignIns.Count
                'Generated (UTC)'    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
                'Runbook Version'    = $Version
                'Caller'             = $CallerName
            }

            try {
                Export-RjRbXlsx -Worksheets $worksheets -Path $xlsxFile -CoverSheet $coverSheet -HighlightRules @(
                    @{ Column = 'Status'; Value = 'Failure'; Color = 'Red' }
                ) -DataBarColumns @('Failed')
            }
            catch {
                Write-Warning "Failed to generate the XLSX workbook: $($_.Exception.Message). The Excel workbook is missing from this delivery - only the CSV files (if any were generated) will be attached or uploaded. Set 'ReportFileFormat' to 'CSV only' to avoid this step entirely."
                # A partially written workbook is unusable - remove it so it is never attached or uploaded
                if (Test-Path -LiteralPath $xlsxFile) {
                    Remove-Item -LiteralPath $xlsxFile -Force -ErrorAction SilentlyContinue
                }
            }

            if (Test-Path -Path $xlsxFile) {
                $reportFiles += $xlsxFile
            }
        }
    }

    Write-Output "Report file export completed: $($reportFiles.Count) file(s) created"
}
elseif ($SendEmailReport -or $CreateDownloadLink) {
    Write-Output ""
    Write-Output "No report files were generated and no report will be delivered - no sign-in events match the criteria."
}
else {
    Write-RjRbLog -Message "Report file export skipped - no delivery method was selected" -Verbose
}

#endregion Report File Export

########################################################
#region     Upload / Download Link
########################################################

if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
    Write-Output ""
    Write-Output "Upload / Download Link"
    Write-Output "---------------------"

    try {
        # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
        # transparently connects the managed identity if no Az context is active.
        $uploadResults = Publish-RjRbFilesToStorageContainer -FilePaths $reportFiles -ContainerName $ContainerName -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -LinkExpiryDays $LinkExpiryDays -AddBlobNamePrefix $true

        foreach ($uploadResult in $uploadResults) {
            Write-Output "Download link (expires $($uploadResult.EndTime)):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }
    catch {
        # The sign-in analysis already succeeded and is visible in the output above - only the
        # optional download link failed. Report and continue so the email is still attempted.
        $uploadError = "$_"
        if ($uploadError -like "*AuthorizationPermissionMismatch*" -or $uploadError -like "*403*" -or $uploadError -like "*Forbidden*") {
            Write-Error "Could not create the download link: the managed identity is not authorized to write to storage account '$StorageAccountName'. Grant it the 'Storage Blob Data Contributor' Azure RBAC role on the storage account and run the report again. The sign-in analysis itself completed successfully and is shown above." -ErrorAction Continue
        }
        elseif ($uploadError -like "*ResourceNotFound*" -or $uploadError -like "*404*" -or $uploadError -like "*could not be found*") {
            Write-Error "Could not create the download link: storage account '$StorageAccountName' or resource group '$ResourceGroupName' was not found. Verify the RJReport.StorageAccount.ResourceGroup and RJReport.StorageAccount.StorageAccountName settings. The sign-in analysis itself completed successfully and is shown above." -ErrorAction Continue
        }
        elseif ($uploadError -like "*timeout*" -or $uploadError -like "*network*" -or $uploadError -like "*DNS*") {
            Write-Error "Could not create the download link: the storage account could not be reached, usually because of a network or firewall restriction. Verify the storage account's network rules allow access from Azure Automation. The sign-in analysis itself completed successfully and is shown above." -ErrorAction Continue
        }
        else {
            Write-Error "Could not create the download link for the report files: $uploadError. The sign-in analysis itself completed successfully and is shown above." -ErrorAction Continue
        }
    }
}
else {
    Write-Output "No download link requested or no report files were generated."
}

#endregion Upload / Download Link

########################################################
#region     Send Email Report
########################################################

if ($SendEmailReport -and $EmailTo -and $processedSignIns.Count -gt 0) {
    Write-Output ""
    Write-Output "Send Email Report"
    Write-Output "---------------------"

    $emailSubject = "User Sign-In Report - $($targetUser.userPrincipalName) - $(Get-Date -Format 'yyyy-MM-dd')"

    $topFailingApps = @($appSummary | Where-Object { $_.Failed -gt 0 } | Select-Object -First 5)
    $appTableRows = if ($topFailingApps.Count -gt 0) {
        ($topFailingApps | ForEach-Object { "| $($_.Application) | $($_.TotalSignIns) | $($_.Successful) | $($_.Failed) | $($_.FailureRate) |" }) -join "`n"
    }
    else {
        "| _No failed sign-ins_ | | | | |"
    }

    $reportBody = @"
- **User:** $($targetUser.displayName) ($($targetUser.userPrincipalName))
- **Lookback period:** $Days day(s)
- **Sign-in type:** $SignInType
- **Application filter:** $(if ([string]::IsNullOrWhiteSpace($ApplicationName)) { "None" } else { $ApplicationName })

## Summary

- **Total sign-in events analyzed:** $($processedSignIns.Count)
- **Total failed sign-ins:** $($failedSignIns.Count)

## Top Applications by Failure Count

| Application | Total | Successful | Failed | Failure Rate |
| --- | --- | --- | --- | --- |
$appTableRows
"@

    $markdownContent = @"
# User Sign-In Report

$reportBody

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Attachment file names for the reduced-set fallback bodies (the strings are built up front,
    # but each is only ever sent on a path where its file exists)
    $xlsxLeaf = if ($xlsxFile) { Split-Path -Path $xlsxFile -Leaf } else { '' }
    $summaryLeaf = if ($fileNameSummary) { Split-Path -Path $fileNameSummary -Leaf } else { '' }

    # Reduced-set body used when the full CSV & XLSX attachment set is too large - only the
    # workbook (all sign-in data and the application summary) goes out.
    $markdownFallbackXlsxOnly = @"
# User Sign-In Report

$reportBody

## Attachments

- **$xlsxLeaf**: Formatted Excel workbook with the complete sign-in data and the per-application summary

> **Note:** The CSV files were not attached because they exceed the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV files.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Reduced-set body used when the full CSV attachment set is too large - only the smallest,
    # most decision-useful artifact (the per-application summary) goes out.
    $markdownFallbackSummaryOnly = @"
# User Sign-In Report

$reportBody

## Attachments

- **$summaryLeaf**: Per-application summary CSV

> **Note:** The detailed CSV files were not attached because they exceed the email attachment size limit. Enable the download link option (CreateDownloadLink) to obtain the complete sign-in detail export.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Resolve optional tenant email branding once per run (never fails the send)
    $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

    try {
        $emailParams = @{
            EmailFrom         = $EmailFrom
            EmailTo           = $EmailTo
            Subject           = $emailSubject
            MarkdownContent   = $markdownContent
            TenantDisplayName = $tenantDisplayName
            ReportVersion     = $Version
        }

        # Send-RjReportEmail guards the attachment size itself: when the regular set exceeds the
        # email size budget (or its send attempt fails), the fallback set is sent instead.
        if ($reportFiles.Count -eq 0) {
            Send-RjReportEmail @emailParams @brandingMailParams
        }
        elseif ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFile -and (Test-Path -Path $xlsxFile)) {
            Send-RjReportEmail @emailParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFile) -FallbackMarkdownContent $markdownFallbackXlsxOnly
        }
        elseif ($ReportFileFormat -eq 'CSV only' -and $fileNameSummary -and (Test-Path -Path $fileNameSummary)) {
            Send-RjReportEmail @emailParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($fileNameSummary) -FallbackMarkdownContent $markdownFallbackSummaryOnly
        }
        else {
            # XLSX only (no smaller artifact exists to fall back to), or CSV only with no
            # per-application summary generated: send the full set with no fallback. If it is
            # oversize, the send throws and the catch below reports it without terminating the run.
            Send-RjReportEmail @emailParams @brandingMailParams -Attachments $reportFiles
        }

        Write-Output "Report email sent to $EmailTo."
    }
    catch {
        # The sign-in analysis already succeeded and is visible in the output above - the report
        # email could NOT be delivered. Report and continue so Cleanup still runs.
        $mailError = "$_"
        if ($mailError -like "*403*" -or $mailError -like "*Forbidden*" -or $mailError -like "*Mail.Send*") {
            Write-Error "The report email could not be delivered: the 'Mail.Send' application permission is missing or has not been admin-consented for the managed identity. The sign-in analysis itself completed successfully and is shown above." -ErrorAction Continue
        }
        elseif ($mailError -like "*SendAsDenied*" -or $mailError -like "*MailboxNotEnabledForRESTAPI*" -or $mailError -like "*mailbox*") {
            Write-Error "The report email could not be delivered: the sender mailbox '$EmailFrom' does not exist, is not licensed, or the managed identity may not send as this address. Verify the RJReport.EmailSender setting. The sign-in analysis itself completed successfully and is shown above." -ErrorAction Continue
        }
        elseif ($mailError -like "*recipient*" -or $mailError -like "*InvalidRecipient*") {
            Write-Error "The report email could not be delivered: the recipient address '$EmailTo' was rejected as invalid. The sign-in analysis itself completed successfully and is shown above." -ErrorAction Continue
        }
        elseif ($mailError -like "*attachment*" -or $mailError -like "*too large*" -or $mailError -like "*413*") {
            Write-Error "The report email could not be delivered: the report attachments exceed the size limit for email delivery. Use the download link option instead, or narrow the report scope with a shorter lookback period or an application filter. The sign-in analysis itself completed successfully and is shown above." -ErrorAction Continue
        }
        else {
            Write-Error "The report email could not be delivered: $mailError. The sign-in analysis itself completed successfully and is shown above." -ErrorAction Continue
        }
    }
}
elseif ($SendEmailReport -and $EmailTo) {
    Write-Output "No email will be sent as there are no matching sign-in events."
}
else {
    Write-Output "No email report requested."
}

#endregion Send Email Report

########################################################
#region     Cleanup
########################################################

# Remove the downloaded branding images, if any were used.
foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

foreach ($reportFilePath in $reportFiles) {
    if ($reportFilePath -and (Test-Path -Path $reportFilePath)) {
        try {
            Remove-Item -Path $reportFilePath -Force -ErrorAction Stop
            Write-RjRbLog -Message "Removed temporary report file: $reportFilePath" -Verbose
        }
        catch {
            Write-RjRbLog -Message "Failed to remove temporary report file '$reportFilePath': $($_.Exception.Message)" -Verbose
        }
    }
}

if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output "Done!"
#endregion Cleanup

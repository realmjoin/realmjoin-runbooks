<#
    .SYNOPSIS
    Sync users with secure MFA methods registered into an Entra ID group

    .DESCRIPTION
    This runbook synchronizes an Entra ID group with all member users that have at least one "secure" authentication method registered, based on the Entra ID authentication methods registration report. Which method groups count as secure is configurable via toggles (Passkeys/FIDO2, platform credentials, Microsoft Authenticator app, software OTP, hardware OTP, certificate-based authentication). Users that no longer have a secure method registered are removed from the group. An optional strict mode ("SecureOnly") additionally disqualifies users that have any unsecure method (phone, email, security questions) registered alongside their secure method. Admin users (holders of an Entra ID directory role, active or PIM-eligible, including members of role-assignable groups) are excluded by default ("ExcludeAdmins") - useful when the target group drives SSPR, where admins would otherwise be forced to register a second factor. An optional exclusion group keeps accounts like break glass or service accounts permanently out of the target group. Excluded users are never added and are removed if they are already members. Guest users and non-user group members are never touched.

    Optionally, a detailed report can be sent via email and/or uploaded to an Azure Storage Account (returning time-limited download links). The report contains CSV files and a formatted Excel workbook with an info cover sheet (chosen parameters and result counts), the performed changes and a per-user evaluation of all member users. Report files are only generated when email or download link is enabled.

    .PARAMETER TargetGroupId
    The Entra ID group to synchronize into. Members of this group will be managed exclusively by this runbook.

    .PARAMETER IncludePasskeys
    Count passkeys and FIDO2 security keys as secure (fido2SecurityKey, passKeyDeviceBound, passKeyDeviceBoundAuthenticator).

    .PARAMETER IncludePlatformCredentials
    Count platform credentials as secure (windowsHelloForBusiness, passKeyDeviceBoundWindowsHello, macOsSecureEnclaveKey).

    .PARAMETER IncludeMicrosoftAuthenticator
    Count the Microsoft Authenticator app as secure (microsoftAuthenticatorPush, microsoftAuthenticatorPasswordless).

    .PARAMETER IncludeSoftwareOtp
    Count software OTP / authenticator TOTP apps as secure (softwareOneTimePasscode).

    .PARAMETER IncludeHardwareOtp
    Count hardware OTP tokens as secure (hardwareOneTimePasscode).

    .PARAMETER IncludeCertificateBasedAuth
    Count certificate-based authentication as secure (certificateBasedAuthentication).

    .PARAMETER SecureOnly
    Strict mode: users that have any unsecure method registered (mobilePhone, alternateMobilePhone, officePhone, email, securityQuestion) never qualify, even if they also have a secure method. They are removed from the group if already a member.

    .PARAMETER SecureMethodsOverride
    Optional. Comma-separated list of methodsRegistered values that define the secure set. When set, ALL method group toggles are ignored. See the runbook documentation for all known values.

    .PARAMETER UnsecureMethodsOverride
    Optional. Comma-separated list of methodsRegistered values that replace the built-in unsecure list. Only evaluated in strict mode (SecureOnly).

    .PARAMETER ExcludeAdmins
    Exclude admin users: users holding an Entra ID directory role (active or PIM-eligible, including members of role-assignable groups) never qualify and are removed from the group if they are already members. Enabled by default - when the target group drives SSPR, admins would otherwise be forced to register a second factor.

    .PARAMETER ExcludeGroupId
    Optional exclusion group: transitive user members of this group (e.g. break glass or service accounts) never qualify and are removed from the group if they are already members.

    .PARAMETER WhatIfMode
    Dry run: log which users would be added or removed without changing the group.

    .PARAMETER SendEmail
    If enabled, the report is sent via email with CSV and Excel (xlsx) attachments. Disabled by default.

    .PARAMETER EmailTo
    Recipient email address(es) for the report. Can be a single address or multiple comma-separated addresses (string). Only used when SendEmail is enabled.

    .PARAMETER EmailFrom
    The sender email address. Sourced from the RJReport tenant settings.

    .PARAMETER ReportFileFormat
    Controls which report file formats are generated and delivered: "CSV only", "CSV & XLSX" (default) or "XLSX only".

    .PARAMETER CreateDownloadLink
    If enabled, the report files are uploaded to an Azure Storage Account and time-limited download links are returned. Disabled by default.

    .PARAMETER ContainerName
    Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

    .PARAMETER ResourceGroupName
    Resource group that contains the storage account. Sourced from the RJReport tenant settings.

    .PARAMETER StorageAccountName
    Storage account name used for the upload. Sourced from the RJReport tenant settings.

    .PARAMETER LinkExpiryDays
    Number of days until the generated download link expires. Sourced from the RJReport tenant settings.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "TargetGroupId": {
                "DisplayName": "Target Group (sync users with secure MFA methods into)"
            },
            "IncludePasskeys": {
                "DisplayName": "Passkeys / FIDO2 security keys count as secure"
            },
            "IncludePlatformCredentials": {
                "DisplayName": "Platform credentials (Windows Hello for Business / macOS Secure Enclave) count as secure"
            },
            "IncludeMicrosoftAuthenticator": {
                "DisplayName": "Microsoft Authenticator app (push / passwordless sign-in) counts as secure"
            },
            "IncludeSoftwareOtp": {
                "DisplayName": "Software OTP (authenticator TOTP apps) counts as secure"
            },
            "IncludeHardwareOtp": {
                "DisplayName": "Hardware OTP tokens count as secure"
            },
            "IncludeCertificateBasedAuth": {
                "DisplayName": "Certificate-based authentication counts as secure"
            },
            "SecureOnly": {
                "DisplayName": "Strict mode: users with any unsecure method (phone, email, security questions) never qualify"
            },
            "SecureMethodsOverride": {
                "DisplayName": "Expert: custom secure methods list (comma-separated, replaces ALL toggles above)",
                "Hide": true
            },
            "UnsecureMethodsOverride": {
                "DisplayName": "Expert: custom unsecure methods list (comma-separated, replaces built-in list)",
                "Hide": true
            },
            "ExcludeAdmins": {
                "DisplayName": "Exclude admin users (directory role holders, incl. PIM-eligible)"
            },
            "ExcludeGroupId": {
                "DisplayName": "Exclusion group (members are never synced into the target group)"
            },
            "WhatIfMode": {
                "DisplayName": "Dry run (log only, no changes)"
            },
            "SendEmail": {
                "DisplayName": "Send report via email?",
                "Default": false,
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - send the report via email",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": ["EmailTo", "ReportFileFormat"],
                                "Mandatory": ["EmailTo"]
                            }
                        },
                        {
                            "Display": "No - do not send an email",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": ["EmailTo", "ReportFileFormat"]
                            }
                        }
                    ],
                    "ShowValue": false
                }
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)"
            },
            "EmailFrom": {
                "Hide": true
            },
            "CreateDownloadLink": {
                "DisplayName": "Create file download links (upload report to storage)?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - upload the report and return download links",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": ["ReportFileFormat"]
                            }
                        },
                        {
                            "Display": "No - do not create download links",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": ["ReportFileFormat"]
                            }
                        }
                    ],
                    "ShowValue": false
                }
            },
            "ReportFileFormat": {
                "DisplayName": "Report file format",
                "Hide": true,
                "Select": {
                    "Options": [
                        {
                            "Display": "CSV & XLSX",
                            "ParameterValue": "CSV & XLSX"
                        },
                        {
                            "Display": "CSV only",
                            "ParameterValue": "CSV only"
                        },
                        {
                            "Display": "XLSX only",
                            "ParameterValue": "XLSX only"
                        }
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
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.0" }

# Suppress false positive from PSScriptAnalyzer - $idx is assigned in ForEach-Object -Begin and used in -Process block
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "idx")]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Target Group" } )]
    [string]$TargetGroupId,

    [bool]$IncludePasskeys = $true,
    [bool]$IncludePlatformCredentials = $true,
    [bool]$IncludeMicrosoftAuthenticator = $true,
    [bool]$IncludeSoftwareOtp = $false,
    [bool]$IncludeHardwareOtp = $false,
    [bool]$IncludeCertificateBasedAuth = $true,

    [bool]$SecureOnly = $false,

    [string]$SecureMethodsOverride = "",

    [string]$UnsecureMethodsOverride = "",

    [bool]$ExcludeAdmins = $true,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclusion group (optional)" } )]
    [string]$ExcludeGroupId = "",

    [bool]$WhatIfMode = $false,

    [bool]$SendEmail = $false,

    [Parameter(Mandatory = $false)]
    [string]$EmailTo,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ })]
    [string]$EmailFrom,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "sync-mfa-secure-users-to-group",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ })]
    [string]$ResourceGroupName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ })]
    [string]$StorageAccountName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ })]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.2.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "TargetGroupId: $TargetGroupId" -Verbose
Write-RjRbLog -Message "IncludePasskeys: $IncludePasskeys" -Verbose
Write-RjRbLog -Message "IncludePlatformCredentials: $IncludePlatformCredentials" -Verbose
Write-RjRbLog -Message "IncludeMicrosoftAuthenticator: $IncludeMicrosoftAuthenticator" -Verbose
Write-RjRbLog -Message "IncludeSoftwareOtp: $IncludeSoftwareOtp" -Verbose
Write-RjRbLog -Message "IncludeHardwareOtp: $IncludeHardwareOtp" -Verbose
Write-RjRbLog -Message "IncludeCertificateBasedAuth: $IncludeCertificateBasedAuth" -Verbose
Write-RjRbLog -Message "SecureOnly: $SecureOnly" -Verbose
Write-RjRbLog -Message "SecureMethodsOverride: $SecureMethodsOverride" -Verbose
Write-RjRbLog -Message "UnsecureMethodsOverride: $UnsecureMethodsOverride" -Verbose
Write-RjRbLog -Message "ExcludeAdmins: $ExcludeAdmins" -Verbose
Write-RjRbLog -Message "ExcludeGroupId: $ExcludeGroupId" -Verbose
Write-RjRbLog -Message "WhatIfMode: $WhatIfMode" -Verbose
Write-RjRbLog -Message "SendEmail: $SendEmail" -Verbose
if ($SendEmail) {
    Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
    Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
}
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}

#endregion

########################################################
#region     Parameter Validation
########################################################

# Method group toggles and the methodsRegistered values they cover (see companion documentation)
$methodGroups = @(
    @{ Enabled = $IncludePasskeys; Methods = @("fido2SecurityKey", "passKeyDeviceBound", "passKeyDeviceBoundAuthenticator") }
    @{ Enabled = $IncludePlatformCredentials; Methods = @("windowsHelloForBusiness", "passKeyDeviceBoundWindowsHello", "macOsSecureEnclaveKey") }
    @{ Enabled = $IncludeMicrosoftAuthenticator; Methods = @("microsoftAuthenticatorPush", "microsoftAuthenticatorPasswordless") }
    @{ Enabled = $IncludeSoftwareOtp; Methods = @("softwareOneTimePasscode") }
    @{ Enabled = $IncludeHardwareOtp; Methods = @("hardwareOneTimePasscode") }
    @{ Enabled = $IncludeCertificateBasedAuth; Methods = @("certificateBasedAuthentication") }
)
$builtInUnsecureMethods = @("mobilePhone", "alternateMobilePhone", "officePhone", "email", "securityQuestion")
$knownMethods = @($methodGroups | ForEach-Object { $_.Methods }) + $builtInUnsecureMethods + @("temporaryAccessPass")

# Determine the secure method set - a filled override replaces all toggles
if (-not [string]::IsNullOrWhiteSpace($SecureMethodsOverride)) {
    $secureMethods = @($SecureMethodsOverride -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
    Write-Output "Secure methods override is set - method group toggles are ignored."
    foreach ($method in $secureMethods) {
        if ($method -notin $knownMethods) {
            Write-Output "Warning: '$method' is not a known methodsRegistered value. It will still be evaluated (future Graph values are allowed) - please check for typos."
        }
    }
}
else {
    $secureMethods = @($methodGroups | Where-Object { $_.Enabled } | ForEach-Object { $_.Methods })
}

if ($secureMethods.Count -eq 0) {
    Write-Error "No secure methods selected. Enable at least one method group toggle or provide a custom secure methods list - an empty secure set would remove all members from the target group." -ErrorAction Continue
    throw "No secure methods selected."
}

# Determine the unsecure method set - only relevant in strict mode
$unsecureMethods = @()
if ($SecureOnly) {
    if (-not [string]::IsNullOrWhiteSpace($UnsecureMethodsOverride)) {
        $unsecureMethods = @($UnsecureMethodsOverride -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
        Write-Output "Unsecure methods override is set - the built-in unsecure list is replaced."
        foreach ($method in $unsecureMethods) {
            if ($method -notin $knownMethods) {
                Write-Output "Warning: '$method' is not a known methodsRegistered value. It will still be evaluated (future Graph values are allowed) - please check for typos."
            }
        }
    }
    else {
        $unsecureMethods = $builtInUnsecureMethods
    }

    $overlap = @($secureMethods | Where-Object { $_ -in $unsecureMethods })
    if ($overlap.Count -gt 0) {
        Write-Output "Warning: The following methods are in both the secure and the unsecure set: $($overlap -join ', '). Unsecure wins - users with such a method never qualify in strict mode."
    }
}

$secureSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$secureMethods, [System.StringComparer]::OrdinalIgnoreCase)
$unsecureSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$unsecureMethods, [System.StringComparer]::OrdinalIgnoreCase)

# Validate email configuration (only if email is requested)
if ($SendEmail) {
    if (-not $EmailTo) {
        Write-Warning -Message "A recipient email address is required when the email report is enabled. Provide EmailTo or disable SendEmail." -Verbose
        throw "Missing recipient email address (EmailTo)."
    }
    if (-not $EmailFrom) {
        Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -Verbose
        throw "This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
    }
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

#endregion

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response. Uses a generic list to stay
        efficient for large tenants (tens of thousands of items across many pages).

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query.
    #>
    param(
        [string]$Uri
    )

    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri

    do {
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        if ($response.value) {
            $allResults.AddRange([object[]]@($response.value))
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $allResults
}

function Invoke-GraphBatch {
    <#
        .SYNOPSIS
        Sends requests to the Microsoft Graph batch API in chunks of 20, with throttling retries.

        .DESCRIPTION
        The Graph $batch endpoint returns 200 for the outer call even when individual inner requests
        are throttled with status 429. Throttled inner requests are retried after the Retry-After
        interval reported by the service (up to 5 attempts). Outer 429 responses are already retried
        by the Graph SDK itself. Emits a progress line every 25 batch calls so large syncs
        (e.g. 20k users) remain observable in the job output.

        .PARAMETER Requests
        The batch request objects (id, method, url, optional headers/body).

        .PARAMETER ProgressLabel
        Label used in progress output lines, e.g. "adds" or "removes".
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Requests,

        [string]$ProgressLabel = "requests"
    )

    # Graph batch API: max 20 requests per call
    $batchSize = 20
    $maxRetries = 5
    $responses = [System.Collections.Generic.List[object]]::new()
    $batchNumber = 0

    for ($i = 0; $i -lt $Requests.Count; $i += $batchSize) {
        $chunk = @($Requests[$i..([Math]::Min($i + $batchSize - 1, $Requests.Count - 1))])
        $batchNumber++

        $pending = $chunk
        $attempt = 0
        while ($pending.Count -gt 0) {
            $batchBody = @{ requests = @($pending) }
            $batchResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/`$batch" -Method POST -Body $batchBody

            # Inner requests can be throttled individually even though the outer call succeeded
            $throttled = @($batchResult.responses | Where-Object { $_.status -eq 429 })
            $final = @($batchResult.responses | Where-Object { $_.status -ne 429 })
            if ($final.Count -gt 0) {
                $responses.AddRange([object[]]$final)
            }

            if ($throttled.Count -eq 0) {
                break
            }

            $attempt++
            if ($attempt -gt $maxRetries) {
                # Give up - the remaining throttled responses are counted as failures by the caller
                $responses.AddRange([object[]]$throttled)
                Write-RjRbLog -Message "Giving up on $($throttled.Count) request(s) still throttled after $maxRetries retries." -Verbose
                break
            }

            # Honor the longest Retry-After the service returned (fallback 10 seconds)
            $retryAfter = 10
            foreach ($response in $throttled) {
                $headerValue = $response.headers.'Retry-After' -as [int]
                if ($headerValue -and $headerValue -gt $retryAfter) {
                    $retryAfter = $headerValue
                }
            }
            Write-RjRbLog -Message "Graph throttled $($throttled.Count) request(s) (attempt $attempt/$maxRetries) - waiting $retryAfter seconds..." -Verbose
            Start-Sleep -Seconds $retryAfter

            $throttledIds = [System.Collections.Generic.HashSet[string]]::new([string[]]@($throttled | ForEach-Object { "$($_.id)" }))
            $pending = @($pending | Where-Object { $throttledIds.Contains("$($_.id)") })
        }

        # Progress heartbeat every 25 batch calls (= 500 requests) for large syncs
        if ($batchNumber % 25 -eq 0) {
            $timeStamp = ([datetime]::Now).ToString("yyyy-MM-dd HH:mm:ss")
            Write-Output "$timeStamp - Processed $([Math]::Min($i + $batchSize, $Requests.Count)) of $($Requests.Count) $ProgressLabel..."
        }
    }

    return $responses
}

function Export-RjRbXlsx {
    <#
        .SYNOPSIS
        Exports objects to an Excel workbook (.xlsx) without external module dependencies.

        .DESCRIPTION
        Writes one or more tables of PSCustomObjects as a native Excel workbook using only
        .NET (System.IO.Compression). Each worksheet gets a styled Excel table (navy header,
        zebra rows that follow re-sorting, filter dropdowns), a frozen header row, calculated
        column widths and an automatic print setup (orientation from content width, header
        row repeated per page).

        Cell values keep their type: .NET numbers become Excel numbers, DateTime values and
        ISO-8601 strings become real Excel dates (localized by the client), http/https URLs
        become clickable hyperlinks (disable with -NoHyperlink). All other strings stay text -
        values like serial numbers or IMEIs are never converted to numbers, and formula
        injection is not possible.

        NOTE: This function is planned to move into the RealmJoin.RunbookHelper module.
        Until then it is duplicated inline in the runbooks that use it.

        .PARAMETER InputObject
        The rows to export (array of objects; also accepted via pipeline). Column order
        follows the property order of the first object.

        .PARAMETER Path
        Full path of the .xlsx file to create. An existing file is overwritten.

        .PARAMETER WorksheetName
        Name of the single worksheet (default: "Report").

        .PARAMETER Worksheets
        Ordered dictionary of worksheet name -> rows for a workbook with multiple worksheets,
        e.g. ([ordered]@{ 'Summary' = $summary; 'Details' = $details }).

        .PARAMETER NoHyperlink
        Do not convert http/https URL strings into clickable hyperlinks.

        .PARAMETER HighlightRules
        Optional conditional formatting rules for status columns. Array of hashtables with
        Column (header name), Value (exact cell text, case-insensitive) and Color
        ('Green', 'Red' or 'Yellow' - the classic Excel highlight presets), e.g.
        @( @{ Column = 'InIntune'; Value = 'yes'; Color = 'Green' },
           @{ Column = 'InIntune'; Value = 'no';  Color = 'Red' } )
        Rules are applied on every worksheet that contains the named column.

        .PARAMETER CoverSheet
        Optional ordered dictionary rendered as an "Info" cover worksheet (first tab):
        a 'Title' key becomes the heading, all other keys become label/value rows, e.g.
        ([ordered]@{ Title = 'Device Report'; Tenant = 'contoso'; Generated = '2026-07-16 08:00 UTC' })

        .PARAMETER HyperlinkText
        Optional dictionary of column name -> display text for hyperlink cells, e.g.
        @{ Portal = 'Open in Intune' }. The cell shows the friendly text, the link target
        stays the full URL. Columns without a mapping keep showing the URL.

        .PARAMETER HideGridLines
        Hide the worksheet grid lines outside the table. Off by default (grid lines help
        readability); the cover sheet always hides them.

        .PARAMETER UseThousandsSeparator
        Format numeric cells with a thousands separator (#,##0 for integers, #,##0.00 for
        decimals, localized by Excel). Off by default.

        .PARAMETER DataBarColumns
        Optional list of numeric column names that get an in-cell data bar (orange,
        min-to-max gradient), e.g. @('DeviceCount'). Lets outliers stand out at a glance
        while the cells stay sortable and filterable. Columns that do not exist on a
        worksheet are skipped.

        .EXAMPLE
        PS C:\> $devices | Export-RjRbXlsx -Path report.xlsx -WorksheetName 'Devices'

        .EXAMPLE
        PS C:\> Export-RjRbXlsx -Worksheets ([ordered]@{ Summary = $sum; Details = $det }) -Path report.xlsx

        .EXAMPLE
        PS C:\> Export-RjRbXlsx -Worksheets ([ordered]@{ Devices = $devices }) -Path report.xlsx `
                    -CoverSheet ([ordered]@{ Title = 'Device Report'; Tenant = $tenantName }) `
                    -HighlightRules @( @{ Column = 'Compliant'; Value = 'no'; Color = 'Red' } ) `
                    -DataBarColumns @('DeviceCount')
    #>
    [CmdletBinding(DefaultParameterSetName = 'SingleSheet')]
    param(
        [Parameter(ParameterSetName = 'SingleSheet', ValueFromPipeline = $true)]
        [object[]]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(ParameterSetName = 'SingleSheet')]
        [string]$WorksheetName = 'Report',

        [Parameter(Mandatory = $true, ParameterSetName = 'MultiSheet')]
        [System.Collections.IDictionary]$Worksheets,

        [switch]$NoHyperlink,

        [object[]]$HighlightRules,

        [System.Collections.IDictionary]$CoverSheet,

        [System.Collections.IDictionary]$HyperlinkText,

        [switch]$HideGridLines,

        [switch]$UseThousandsSeparator,

        [object[]]$DataBarColumns
    )

    begin {
        $pipelineRows = [System.Collections.Generic.List[object]]::new()

        $invariant = [System.Globalization.CultureInfo]::InvariantCulture

        function ConvertTo-XlsxXmlText {
            param([string]$Text)
            # Strip control characters that are invalid in XML 1.0 (keep tab/LF/CR), then escape
            $sb = [System.Text.StringBuilder]::new($Text.Length)
            foreach ($ch in $Text.ToCharArray()) {
                $code = [int]$ch
                if ($code -lt 32 -and $code -ne 9 -and $code -ne 10 -and $code -ne 13) { continue }
                switch ($ch) {
                    '&' { [void]$sb.Append('&amp;') }
                    '<' { [void]$sb.Append('&lt;') }
                    '>' { [void]$sb.Append('&gt;') }
                    '"' { [void]$sb.Append('&quot;') }
                    default { [void]$sb.Append($ch) }
                }
            }
            $sb.ToString()
        }

        function ConvertTo-XlsxColumnName {
            param([int]$Index) # 1-based
            $name = ''
            while ($Index -gt 0) {
                $Index--
                $name = [char](65 + ($Index % 26)) + $name
                $Index = [int][math]::Floor($Index / 26)
            }
            $name
        }

        function Get-XlsxSheetName {
            param([string]$Name, [int]$Number, [System.Collections.Generic.HashSet[string]]$Used)
            $clean = ($Name -replace '[\[\]:*?/\\]', ' ').Trim().Trim("'")
            if (-not $clean) { $clean = "Sheet$Number" }
            if ($clean.Length -gt 31) { $clean = $clean.Substring(0, 31).Trim() }
            $candidate = $clean
            $suffix = 2
            while (-not $Used.Add($candidate)) {
                $tail = "_$suffix"
                $candidate = $clean.Substring(0, [math]::Min($clean.Length, 31 - $tail.Length)) + $tail
                $suffix++
            }
            $candidate
        }

        function Find-XlsxColumnIndex {
            param([string[]]$Headers, [string]$Name) # returns -1 when not found
            for ($i = 0; $i -lt $Headers.Count; $i++) {
                if ($Headers[$i] -eq $Name) { return $i }
            }
            return -1
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'SingleSheet' -and $null -ne $InputObject) {
            foreach ($item in $InputObject) { $pipelineRows.Add($item) }
        }
    }

    end {
        # Normalize both parameter sets into an ordered list of (Name, Rows); dictionaries become objects
        $normalizeRows = {
            param($Rows)
            @($Rows) | Where-Object { $null -ne $_ } | ForEach-Object {
                if ($_ -is [System.Collections.IDictionary]) { [pscustomobject]$_ } else { $_ }
            }
        }
        $sheetDefs = [System.Collections.Generic.List[object]]::new()
        if ($PSCmdlet.ParameterSetName -eq 'MultiSheet') {
            foreach ($key in $Worksheets.Keys) {
                $sheetDefs.Add([pscustomobject]@{ Name = [string]$key; Rows = @(& $normalizeRows $Worksheets[$key]); IsCover = $false })
            }
            if ($sheetDefs.Count -eq 0) { throw "Export-RjRbXlsx: -Worksheets must contain at least one entry." }
        }
        else {
            $sheetDefs.Add([pscustomobject]@{ Name = $WorksheetName; Rows = @(& $normalizeRows $pipelineRows); IsCover = $false })
        }
        if ($CoverSheet) {
            $sheetDefs.Insert(0, [pscustomobject]@{ Name = 'Info'; Rows = @(); IsCover = $true })
        }

        $usedSheetNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        $xmlDecl = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        $mainNs = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
        $relNs = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
        $pkgRelNs = 'http://schemas.openxmlformats.org/package/2006/relationships'
        $maxDataRows = 1048575 # xlsx row limit (1,048,576) minus header row
        $isoDateRegex = [regex]'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'

        if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
        $fileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew)
        try {
            $zip = [System.IO.Compression.ZipArchive]::new($fileStream, [System.IO.Compression.ZipArchiveMode]::Create)
            try {
                $writeEntry = {
                    param([string]$EntryName, [string]$Content)
                    $entry = $zip.CreateEntry($EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
                    $writer = [System.IO.StreamWriter]::new($entry.Open(), $utf8NoBom)
                    try { $writer.Write($Content) } finally { $writer.Dispose() }
                }

                #region Static package parts
                $contentTypes = [System.Text.StringBuilder]::new()
                [void]$contentTypes.Append("$xmlDecl<Types xmlns=""http://schemas.openxmlformats.org/package/2006/content-types"">")
                [void]$contentTypes.Append('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
                [void]$contentTypes.Append('<Default Extension="xml" ContentType="application/xml"/>')
                [void]$contentTypes.Append('<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>')
                [void]$contentTypes.Append('<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>')
                for ($s = 1; $s -le $sheetDefs.Count; $s++) {
                    [void]$contentTypes.Append("<Override PartName=""/xl/worksheets/sheet$s.xml"" ContentType=""application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml""/>")
                }
                # table overrides are appended while writing the sheets (empty sheets have no table)

                & $writeEntry '_rels/.rels' ("$xmlDecl<Relationships xmlns=""$pkgRelNs"">" +
                    "<Relationship Id=""rId1"" Type=""$relNs/officeDocument"" Target=""xl/workbook.xml""/>" +
                    '</Relationships>')

                # Workbook + workbook relationships
                $workbook = [System.Text.StringBuilder]::new()
                [void]$workbook.Append("$xmlDecl<workbook xmlns=""$mainNs"" xmlns:r=""$relNs""><sheets>")
                $workbookRels = [System.Text.StringBuilder]::new()
                [void]$workbookRels.Append("$xmlDecl<Relationships xmlns=""$pkgRelNs"">")
                $sheetNames = @()
                for ($s = 1; $s -le $sheetDefs.Count; $s++) {
                    $sheetName = Get-XlsxSheetName -Name $sheetDefs[$s - 1].Name -Number $s -Used $usedSheetNames
                    $sheetNames += $sheetName
                    [void]$workbook.Append("<sheet name=""$(ConvertTo-XlsxXmlText $sheetName)"" sheetId=""$s"" r:id=""rId$s""/>")
                    [void]$workbookRels.Append("<Relationship Id=""rId$s"" Type=""$relNs/worksheet"" Target=""worksheets/sheet$s.xml""/>")
                }
                [void]$workbook.Append('</sheets>')
                # Repeat the header row on every printed page (skipped for the cover sheet)
                $printTitles = ''
                for ($s = 1; $s -le $sheetDefs.Count; $s++) {
                    if ($sheetDefs[$s - 1].IsCover) { continue }
                    $quotedName = ConvertTo-XlsxXmlText ($sheetNames[$s - 1] -replace "'", "''")
                    $printTitles += '<definedName name="_xlnm.Print_Titles" localSheetId="' + ($s - 1) + '">&apos;' + $quotedName + '&apos;!$1:$1</definedName>'
                }
                if ($printTitles) { [void]$workbook.Append("<definedNames>$printTitles</definedNames>") }
                [void]$workbook.Append('</workbook>')
                [void]$workbookRels.Append("<Relationship Id=""rId$($sheetDefs.Count + 1)"" Type=""$relNs/styles"" Target=""styles.xml""/>")
                [void]$workbookRels.Append('</Relationships>')
                & $writeEntry 'xl/workbook.xml' $workbook.ToString()
                & $writeEntry 'xl/_rels/workbook.xml.rels' $workbookRels.ToString()

                # Styles. Fonts: 0=default, 1=hyperlink, 2=cover title, 3=cover label.
                # cellXfs: 0=default, 1=date, 2=datetime, 3=hyperlink, 4=int grouped, 5=decimal grouped,
                #          6=cover title (orange accent border), 7=cover accent line, 8=cover label
                & $writeEntry 'xl/styles.xml' ("$xmlDecl<styleSheet xmlns=""$mainNs"">" +
                    '<fonts count="4">' +
                    '<font><sz val="12"/><name val="Calibri"/><family val="2"/></font>' +
                    '<font><u/><sz val="12"/><color rgb="FF0563C1"/><name val="Calibri"/><family val="2"/></font>' +
                    '<font><b/><sz val="18"/><color rgb="FF1B2A44"/><name val="Calibri"/><family val="2"/></font>' +
                    '<font><b/><sz val="12"/><color rgb="FF595959"/><name val="Calibri"/><family val="2"/></font>' +
                    '</fonts>' +
                    '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>' +
                    '<borders count="2">' +
                    '<border><left/><right/><top/><bottom/><diagonal/></border>' +
                    '<border><left/><right/><top/><bottom style="thick"><color rgb="FFF0871E"/></bottom><diagonal/></border>' +
                    '</borders>' +
                    '<cellStyleXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0"/></cellStyleXfs>' +
                    '<cellXfs count="9">' +
                    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' +
                    '<xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>' +
                    '<xf numFmtId="22" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>' +
                    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="1" applyFont="1"/>' +
                    '<xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>' +
                    '<xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>' +
                    '<xf numFmtId="0" fontId="2" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1"/>' +
                    '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>' +
                    '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>' +
                    '</cellXfs>' +
                    '<cellStyles count="2"><cellStyle name="Normal" xfId="0" builtinId="0"/><cellStyle name="Hyperlink" xfId="1" builtinId="8"/></cellStyles>' +
                    # dxf 0-2 = classic Excel highlight presets green/red/yellow (used by -HighlightRules),
                    # dxf 3-5 = custom table style: navy header, zebra stripe, explicit white second stripe
                    # (white second stripe covers the grid lines inside the table; banding follows re-sorting)
                    '<dxfs count="6">' +
                    '<dxf><font><color rgb="FF006100"/></font><fill><patternFill><bgColor rgb="FFC6EFCE"/></patternFill></fill></dxf>' +
                    '<dxf><font><color rgb="FF9C0006"/></font><fill><patternFill><bgColor rgb="FFFFC7CE"/></patternFill></fill></dxf>' +
                    '<dxf><font><color rgb="FF9C6500"/></font><fill><patternFill><bgColor rgb="FFFFEB9C"/></patternFill></fill></dxf>' +
                    '<dxf><font><b/><color rgb="FFFFFFFF"/></font><fill><patternFill><bgColor rgb="FF1B2A44"/></patternFill></fill></dxf>' +
                    '<dxf><fill><patternFill><bgColor rgb="FFDEE4EE"/></patternFill></fill></dxf>' +
                    '<dxf><fill><patternFill><bgColor rgb="FFFFFFFF"/></patternFill></fill></dxf>' +
                    '</dxfs>' +
                    '<tableStyles count="1" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16">' +
                    '<tableStyle name="RjRbReport" pivot="0" count="3">' +
                    '<tableStyleElement type="headerRow" dxfId="3"/>' +
                    '<tableStyleElement type="firstRowStripe" dxfId="4"/>' +
                    '<tableStyleElement type="secondRowStripe" dxfId="5"/>' +
                    '</tableStyle></tableStyles>' +
                    '</styleSheet>')
                #endregion

                #region Worksheets
                for ($s = 1; $s -le $sheetDefs.Count; $s++) {
                    # First tab in RealmJoin orange, remaining tabs in neutral gray
                    $tabColorRgb = if ($s -eq 1) { 'FFF0871E' } else { 'FF7F7F7F' }

                    # Cover sheet: title + label/value rows, no table, no grid lines
                    if ($sheetDefs[$s - 1].IsCover) {
                        $coverTitle = if ($CoverSheet.Contains('Title')) { [string]$CoverSheet['Title'] } else { 'Report' }
                        $coverKeys = @($CoverSheet.Keys | Where-Object { [string]$_ -ne 'Title' })
                        $cover = [System.Text.StringBuilder]::new()
                        [void]$cover.Append("$xmlDecl<worksheet xmlns=""$mainNs"" xmlns:r=""$relNs"">")
                        [void]$cover.Append("<sheetPr><tabColor rgb=""$tabColorRgb""/></sheetPr>")
                        [void]$cover.Append("<dimension ref=""A1:C$($coverKeys.Count + 4)""/>")
                        [void]$cover.Append('<sheetViews><sheetView workbookViewId="0" showGridLines="0"/></sheetViews>')
                        # Narrow spacer column A indents the content away from the sheet edge
                        [void]$cover.Append('<cols><col min="1" max="1" width="3.6" customWidth="1"/><col min="2" max="2" width="26" customWidth="1"/><col min="3" max="3" width="48" customWidth="1"/></cols>')
                        [void]$cover.Append('<sheetData>')
                        # Title in row 3: navy heading with an orange accent line spanning both content columns
                        [void]$cover.Append("<row r=""3"" ht=""30"" customHeight=""1""><c r=""B3"" s=""6"" t=""inlineStr""><is><t>$(ConvertTo-XlsxXmlText $coverTitle)</t></is></c><c r=""C3"" s=""7""/></row>")
                        $coverRow = 4
                        foreach ($coverKey in $coverKeys) {
                            $coverRow++
                            $labelXml = ConvertTo-XlsxXmlText ([string]$coverKey)
                            $valueXml = ConvertTo-XlsxXmlText ([string]$CoverSheet[$coverKey])
                            [void]$cover.Append("<row r=""$coverRow"" ht=""20"" customHeight=""1""><c r=""B$coverRow"" s=""8"" t=""inlineStr""><is><t>$labelXml</t></is></c><c r=""C$coverRow"" t=""inlineStr""><is><t>$valueXml</t></is></c></row>")
                        }
                        [void]$cover.Append('</sheetData></worksheet>')
                        & $writeEntry "xl/worksheets/sheet$s.xml" $cover.ToString()
                        continue
                    }

                    $rows = @($sheetDefs[$s - 1].Rows | Where-Object { $null -ne $_ })
                    if ($rows.Count -gt $maxDataRows) {
                        throw "Export-RjRbXlsx: worksheet '$($sheetNames[$s - 1])' has $($rows.Count) rows - the xlsx limit is $maxDataRows data rows."
                    }

                    # Header names from the property order of the first object, deduplicated (table columns must be unique and non-empty)
                    $headers = @()
                    if ($rows.Count -gt 0) {
                        $seenHeaders = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                        $col = 0
                        foreach ($prop in $rows[0].PSObject.Properties.Name) {
                            $col++
                            $name = if ([string]::IsNullOrWhiteSpace($prop)) { "Column$col" } else { $prop }
                            $suffix = 2
                            $candidate = $name
                            while (-not $seenHeaders.Add($candidate)) { $candidate = "${name}_$suffix"; $suffix++ }
                            $headers += $candidate
                        }
                    }

                    # Empty worksheet: single info cell, no table
                    if ($headers.Count -eq 0) {
                        & $writeEntry "xl/worksheets/sheet$s.xml" ("$xmlDecl<worksheet xmlns=""$mainNs"" xmlns:r=""$relNs"">" +
                            "<sheetPr><tabColor rgb=""$tabColorRgb""/></sheetPr>" +
                            '<dimension ref="A1:A1"/><sheetViews><sheetView workbookViewId="0"/></sheetViews>' +
                            '<sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>No data available</t></is></c></row></sheetData>' +
                            '</worksheet>')
                        continue
                    }

                    [void]$contentTypes.Append("<Override PartName=""/xl/tables/table$s.xml"" ContentType=""application/vnd.openxmlformats-officedocument.spreadsheetml.table+xml""/>")

                    $colCount = $headers.Count
                    $propNames = @($rows[0].PSObject.Properties.Name)
                    $colNames = @(1..$colCount | ForEach-Object { ConvertTo-XlsxColumnName $_ })
                    $lastColName = $colNames[$colCount - 1]
                    $lastRow = $rows.Count + 1
                    $tableRef = "A1:$lastColName$lastRow"

                    # Pre-compute cell descriptors and column widths (widths from the first 1000 rows)
                    $widths = @($headers | ForEach-Object { $_.Length + 3 }) # + filter dropdown button
                    $cellMatrix = [System.Collections.Generic.List[object]]::new()
                    $hyperlinks = [System.Collections.Generic.List[object]]::new()
                    $rowIndex = 1
                    foreach ($row in $rows) {
                        $rowIndex++
                        $cells = [System.Collections.Generic.List[string]]::new()
                        for ($c = 1; $c -le $colCount; $c++) {
                            $propInfo = $row.PSObject.Properties[$propNames[$c - 1]]
                            $value = if ($propInfo) { $propInfo.Value } else { $null }
                            $cellRef = "$($colNames[$c - 1])$rowIndex"
                            $displayLength = 0
                            $cellXml = $null

                            if ($null -eq $value -or $value -is [System.DBNull]) {
                                $cells.Add('')
                                continue
                            }

                            $typeCode = if ($value -is [string]) { [System.TypeCode]::String } else { [System.Type]::GetTypeCode($value.GetType()) }

                            if ($value -is [datetime]) {
                                $style = if ($value.TimeOfDay -eq [timespan]::Zero) { 1 } else { 2 }
                                $cellXml = "<c r=""$cellRef"" s=""$style""><v>$($value.ToOADate().ToString($invariant))</v></c>"
                                $displayLength = 17
                            }
                            elseif ($value -is [bool]) {
                                $cellXml = "<c r=""$cellRef"" t=""b""><v>$(if ($value) { 1 } else { 0 })</v></c>"
                                $displayLength = 5
                            }
                            elseif ($typeCode -in @(
                                    [System.TypeCode]::Byte, [System.TypeCode]::SByte, [System.TypeCode]::Int16, [System.TypeCode]::UInt16,
                                    [System.TypeCode]::Int32, [System.TypeCode]::UInt32, [System.TypeCode]::Int64, [System.TypeCode]::UInt64,
                                    [System.TypeCode]::Single, [System.TypeCode]::Double, [System.TypeCode]::Decimal)) {
                                $numText = [string]$value.ToString($invariant)
                                if ($numText -match '^(NaN|.*Infinity)$') {
                                    $escaped = ConvertTo-XlsxXmlText $numText
                                    $cellXml = "<c r=""$cellRef"" t=""inlineStr""><is><t>$escaped</t></is></c>"
                                }
                                else {
                                    $numStyle = ''
                                    if ($UseThousandsSeparator) {
                                        $isDecimalType = $typeCode -in @([System.TypeCode]::Single, [System.TypeCode]::Double, [System.TypeCode]::Decimal)
                                        $numStyle = if ($isDecimalType) { ' s="5"' } else { ' s="4"' }
                                    }
                                    $cellXml = "<c r=""$cellRef""$numStyle><v>$numText</v></c>"
                                }
                                $displayLength = $numText.Length
                            }
                            else {
                                # Everything else is rendered as text (arrays joined, objects stringified)
                                $text = if ($value -is [string]) { $value }
                                elseif ($value -is [System.Collections.IEnumerable]) { @($value | ForEach-Object { [string]$_ }) -join '; ' }
                                else { [string]$value }

                                $parsedDate = [datetime]::MinValue
                                if ($isoDateRegex.IsMatch($text) -and [datetime]::TryParse($text, $invariant,
                                        [System.Globalization.DateTimeStyles]::AdjustToUniversal, [ref]$parsedDate)) {
                                    # ISO-8601 strings (Graph date fields) become real, sortable Excel dates
                                    $style = if ($parsedDate.TimeOfDay -eq [timespan]::Zero) { 1 } else { 2 }
                                    $cellXml = "<c r=""$cellRef"" s=""$style""><v>$($parsedDate.ToOADate().ToString($invariant))</v></c>"
                                    $displayLength = 17
                                }
                                else {
                                    $escaped = ConvertTo-XlsxXmlText $text
                                    $preserve = if ($text -match '^\s|\s$') { ' xml:space="preserve"' } else { '' }
                                    $isUrl = (-not $NoHyperlink) -and $text -match '^https?://' -and
                                        [System.Uri]::IsWellFormedUriString($text, [System.UriKind]::Absolute)
                                    if ($isUrl) {
                                        # Optional friendly display text per column; the link target stays the full URL
                                        $display = $text
                                        if ($HyperlinkText -and $HyperlinkText.Contains($propNames[$c - 1]) -and $HyperlinkText[$propNames[$c - 1]]) {
                                            $display = [string]$HyperlinkText[$propNames[$c - 1]]
                                        }
                                        $escapedDisplay = ConvertTo-XlsxXmlText $display
                                        $cellXml = "<c r=""$cellRef"" s=""3"" t=""inlineStr""><is><t>$escapedDisplay</t></is></c>"
                                        $hyperlinks.Add([pscustomobject]@{ Ref = $cellRef; Url = $text })
                                        $displayLength = $display.Length
                                    }
                                    else {
                                        $cellXml = "<c r=""$cellRef"" t=""inlineStr""><is><t$preserve>$escaped</t></is></c>"
                                        $displayLength = $text.Length
                                    }
                                }
                            }

                            $cells.Add($cellXml)
                            if ($rowIndex -le 1001 -and $displayLength -gt $widths[$c - 1]) { $widths[$c - 1] = $displayLength }
                        }
                        $cellMatrix.Add($cells)
                    }

                    # Worksheet XML (schema order: sheetPr, dimension, sheetViews, cols, sheetData,
                    # conditionalFormatting, hyperlinks, pageMargins, pageSetup, tableParts)
                    $sheet = [System.Text.StringBuilder]::new()
                    [void]$sheet.Append("$xmlDecl<worksheet xmlns=""$mainNs"" xmlns:r=""$relNs"">")
                    [void]$sheet.Append("<sheetPr><tabColor rgb=""$tabColorRgb""/><pageSetUpPr fitToPage=""1""/></sheetPr>")
                    [void]$sheet.Append("<dimension ref=""$tableRef""/>")
                    $gridLinesAttr = if ($HideGridLines) { ' showGridLines="0"' } else { '' }
                    [void]$sheet.Append("<sheetViews><sheetView workbookViewId=""0""$gridLinesAttr><pane ySplit=""1"" topLeftCell=""A2"" activePane=""bottomLeft"" state=""frozen""/></sheetView></sheetViews>")
                    [void]$sheet.Append('<cols>')
                    $totalWidth = 0
                    for ($c = 1; $c -le $colCount; $c++) {
                        $width = [math]::Min([math]::Max($widths[$c - 1] + 2, 8), 60)
                        $totalWidth += $width
                        [void]$sheet.Append("<col min=""$c"" max=""$c"" width=""$width"" customWidth=""1""/>")
                    }
                    [void]$sheet.Append('</cols><sheetData>')

                    # Header row: no explicit cell style, so the table style fully controls the header look
                    [void]$sheet.Append('<row r="1">')
                    for ($c = 1; $c -le $colCount; $c++) {
                        $escaped = ConvertTo-XlsxXmlText $headers[$c - 1]
                        [void]$sheet.Append("<c r=""$($colNames[$c - 1])1"" t=""inlineStr""><is><t>$escaped</t></is></c>")
                    }
                    [void]$sheet.Append('</row>')

                    $rowIndex = 1
                    foreach ($cells in $cellMatrix) {
                        $rowIndex++
                        [void]$sheet.Append("<row r=""$rowIndex"">")
                        foreach ($cellXml in $cells) { if ($cellXml) { [void]$sheet.Append($cellXml) } }
                        [void]$sheet.Append('</row>')
                    }
                    [void]$sheet.Append('</sheetData>')

                    # Conditional formatting: status-column highlights and in-cell data bars
                    if (($HighlightRules -or $DataBarColumns) -and $rows.Count -gt 0) {
                        $dxfIds = @{ 'green' = 0; 'red' = 1; 'yellow' = 2 }
                        $priority = 1
                        foreach ($rule in @($HighlightRules)) {
                            $colIndex = Find-XlsxColumnIndex -Headers $headers -Name ([string]$rule.Column)
                            if ($colIndex -lt 0) { continue }
                            $colorKey = ([string]$rule.Color).ToLowerInvariant()
                            if (-not $dxfIds.ContainsKey($colorKey)) {
                                Write-Warning "Export-RjRbXlsx: unknown highlight color '$($rule.Color)' - use Green, Red or Yellow. Skipping rule."
                                continue
                            }
                            $colName = $colNames[$colIndex]
                            $escapedValue = ConvertTo-XlsxXmlText ([string]$rule.Value)
                            [void]$sheet.Append("<conditionalFormatting sqref=""${colName}2:$colName$lastRow"">")
                            [void]$sheet.Append("<cfRule type=""cellIs"" dxfId=""$($dxfIds[$colorKey])"" priority=""$priority"" operator=""equal""><formula>&quot;$escapedValue&quot;</formula></cfRule>")
                            [void]$sheet.Append('</conditionalFormatting>')
                            $priority++
                        }
                        foreach ($dataBarColumn in @($DataBarColumns)) {
                            $colIndex = Find-XlsxColumnIndex -Headers $headers -Name ([string]$dataBarColumn)
                            if ($colIndex -lt 0) { continue }
                            $colName = $colNames[$colIndex]
                            [void]$sheet.Append("<conditionalFormatting sqref=""${colName}2:$colName$lastRow"">")
                            [void]$sheet.Append("<cfRule type=""dataBar"" priority=""$priority""><dataBar><cfvo type=""min""/><cfvo type=""max""/><color rgb=""FFF0871E""/></dataBar></cfRule>")
                            [void]$sheet.Append('</conditionalFormatting>')
                            $priority++
                        }
                    }

                    if ($hyperlinks.Count -gt 0) {
                        [void]$sheet.Append('<hyperlinks>')
                        $linkId = 1
                        foreach ($link in $hyperlinks) {
                            $linkId++
                            [void]$sheet.Append("<hyperlink ref=""$($link.Ref)"" r:id=""rId$linkId""/>")
                        }
                        [void]$sheet.Append('</hyperlinks>')
                    }
                    # Print setup: orientation derived from content width, scale to one page wide
                    $orientation = if ($totalWidth -gt 110) { 'landscape' } else { 'portrait' }
                    [void]$sheet.Append('<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>')
                    [void]$sheet.Append("<pageSetup orientation=""$orientation"" fitToWidth=""1"" fitToHeight=""0""/>")
                    [void]$sheet.Append('<tableParts count="1"><tablePart r:id="rId1"/></tableParts>')
                    [void]$sheet.Append('</worksheet>')
                    & $writeEntry "xl/worksheets/sheet$s.xml" $sheet.ToString()

                    # Table part: filter dropdowns; header and banding come from the custom RjRbReport style
                    $table = [System.Text.StringBuilder]::new()
                    [void]$table.Append("$xmlDecl<table xmlns=""$mainNs"" id=""$s"" name=""Table$s"" displayName=""Table$s"" ref=""$tableRef"" headerRowCount=""1"">")
                    [void]$table.Append("<autoFilter ref=""$tableRef""/><tableColumns count=""$colCount"">")
                    for ($c = 1; $c -le $colCount; $c++) {
                        [void]$table.Append("<tableColumn id=""$c"" name=""$(ConvertTo-XlsxXmlText $headers[$c - 1])""/>")
                    }
                    [void]$table.Append('</tableColumns><tableStyleInfo name="RjRbReport" showFirstColumn="0" showLastColumn="0" showRowStripes="1" showColumnStripes="0"/></table>')
                    & $writeEntry "xl/tables/table$s.xml" $table.ToString()

                    # Sheet relationships: rId1 = table, rId2+ = external hyperlink targets
                    $sheetRels = [System.Text.StringBuilder]::new()
                    [void]$sheetRels.Append("$xmlDecl<Relationships xmlns=""$pkgRelNs"">")
                    [void]$sheetRels.Append("<Relationship Id=""rId1"" Type=""$relNs/table"" Target=""../tables/table$s.xml""/>")
                    $linkId = 1
                    foreach ($link in $hyperlinks) {
                        $linkId++
                        [void]$sheetRels.Append("<Relationship Id=""rId$linkId"" Type=""$relNs/hyperlink"" Target=""$(ConvertTo-XlsxXmlText $link.Url)"" TargetMode=""External""/>")
                    }
                    [void]$sheetRels.Append('</Relationships>')
                    & $writeEntry "xl/worksheets/_rels/sheet$s.xml.rels" $sheetRels.ToString()
                }
                #endregion

                [void]$contentTypes.Append('</Types>')
                & $writeEntry '[Content_Types].xml' $contentTypes.ToString()
            }
            finally {
                $zip.Dispose()
            }
        }
        finally {
            $fileStream.Dispose()
        }

        Write-Verbose "Export-RjRbXlsx: wrote $($sheetDefs.Count) worksheet(s) to $Path"
    }
}

function Send-RjRbGuardedReportEmail {
    <#
        .SYNOPSIS
        Sends a report email via Send-RjReportEmail with an attachment size guard.

        .DESCRIPTION
        Wraps Send-RjReportEmail: when the attachments are likely to exceed the Graph sendMail
        request limit (~4 MB total; attachments count base64-encoded, +33%), the email is sent
        with a smaller fallback attachment set instead. If the send fails anyway, one retry with
        the fallback set is attempted before failing hard with an actionable error message.

        The function is content-agnostic - which files form the regular and the fallback set
        (e.g. all files vs. only the Excel workbook) is decided by the caller.

        NOTE: This logic is planned to move into Send-RjReportEmail in the
        RealmJoin.RunbookHelper module. Until then it is duplicated inline in the runbooks.

        .PARAMETER EmailFrom
        Sender address, passed through to Send-RjReportEmail.

        .PARAMETER EmailTo
        Recipient address(es), passed through to Send-RjReportEmail.

        .PARAMETER Subject
        Mail subject, passed through to Send-RjReportEmail.

        .PARAMETER MarkdownContent
        Mail body (Markdown) used when the regular attachment set is sent.

        .PARAMETER Attachments
        The regular attachment set (file paths). May be empty for a text-only mail.

        .PARAMETER FallbackAttachments
        Optional smaller attachment set used when the regular set exceeds the size budget or
        its send attempt fails. Without this parameter there is no fallback - a failed send
        throws immediately.

        .PARAMETER FallbackMarkdownContent
        Mail body (Markdown) used when the fallback attachment set is sent.

        .PARAMETER MaxAttachmentBytes
        Raw size budget for the regular attachment set (default 2.5MB - stays safely below
        the ~4 MB Graph sendMail request limit after base64 encoding and HTML body overhead).

        .PARAMETER TenantDisplayName
        Tenant name for the report footer, passed through to Send-RjReportEmail.

        .PARAMETER ReportVersion
        Runbook version for the report footer, passed through to Send-RjReportEmail.

        .PARAMETER UseNativeGraphRequest
        Passed through to Send-RjReportEmail.

        .EXAMPLE
        PS C:\> Send-RjRbGuardedReportEmail -EmailFrom $from -EmailTo $to -Subject $subject `
                    -MarkdownContent $md -Attachments ($csvFiles + $xlsxPath) `
                    -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $mdFallback `
                    -TenantDisplayName $tenant -ReportVersion $Version
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$EmailFrom,

        [Parameter(Mandatory = $true)]
        [string]$EmailTo,

        [Parameter(Mandatory = $true)]
        [string]$Subject,

        [Parameter(Mandatory = $true)]
        [string]$MarkdownContent,

        [AllowEmptyCollection()]
        [string[]]$Attachments = @(),

        [string[]]$FallbackAttachments,

        [string]$FallbackMarkdownContent,

        [long]$MaxAttachmentBytes = 2.5MB,

        [string]$TenantDisplayName,

        [string]$ReportVersion,

        [switch]$UseNativeGraphRequest
    )

    $baseParams = @{
        EmailFrom = $EmailFrom
        EmailTo   = $EmailTo
        Subject   = $Subject
    }
    if ($TenantDisplayName) { $baseParams.TenantDisplayName = $TenantDisplayName }
    if ($ReportVersion) { $baseParams.ReportVersion = $ReportVersion }
    if ($UseNativeGraphRequest) { $baseParams.UseNativeGraphRequest = $true }

    $sizeLimitHint = "If the attachments exceed the email size limit, choose a different report file format or enable the download link option (CreateDownloadLink) to deliver the files."

    $attachments = @($Attachments | Where-Object { $_ })
    $hasFallback = ($null -ne $FallbackAttachments) -and (@($FallbackAttachments | Where-Object { $_ }).Count -gt 0)

    # Graph sendMail rejects the whole request at ~4 MB; attachments count base64-encoded (+33%),
    # plus HTML body and inline header image. Above this raw budget the fallback set is sent directly.
    $useFallback = $false
    if ($hasFallback -and $attachments.Count -gt 0) {
        $totalBytes = ($attachments | ForEach-Object { (Get-Item -LiteralPath $_).Length } | Measure-Object -Sum).Sum
        if (-not $totalBytes) { $totalBytes = 0 }
        if ($totalBytes -gt $MaxAttachmentBytes) {
            $useFallback = $true
            Write-Output "The attachments total $([math]::Round($totalBytes / 1MB, 2)) MB and exceed the email attachment budget of $([math]::Round($MaxAttachmentBytes / 1MB, 2)) MB - sending the reduced attachment set instead."
        }
    }

    try {
        if ($useFallback) {
            Send-RjReportEmail @baseParams -MarkdownContent $FallbackMarkdownContent -Attachments $FallbackAttachments
            Write-Output "Email report sent successfully to: $EmailTo (reduced attachment set - the full set exceeds the email size limit)"
        }
        elseif ($attachments.Count -gt 0) {
            Send-RjReportEmail @baseParams -MarkdownContent $MarkdownContent -Attachments $attachments
            Write-Output "Email report sent successfully to: $EmailTo"
        }
        else {
            Send-RjReportEmail @baseParams -MarkdownContent $MarkdownContent
            Write-Output "Email report sent successfully to: $EmailTo"
        }
    }
    catch {
        # Safety net: retry once with the fallback set if the full set was just attempted
        if ($useFallback -or -not $hasFallback -or $attachments.Count -eq 0) {
            Write-Error "Failed to send email report: $($_.Exception.Message). $sizeLimitHint"
            throw
        }

        Write-Output "Sending the email with all attachments failed: $($_.Exception.Message)"
        Write-Output "Retrying with the reduced attachment set..."
        try {
            Send-RjReportEmail @baseParams -MarkdownContent $FallbackMarkdownContent -Attachments $FallbackAttachments
            Write-Output "Email report sent successfully to: $EmailTo (reduced attachment set - the first attempt with all attachments failed)"
        }
        catch {
            Write-Error "Failed to send email report (retry with the reduced attachment set also failed): $($_.Exception.Message). $sizeLimitHint"
            throw
        }
    }
}

#endregion

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    throw
}

if ($SendEmail -or $CreateDownloadLink) {
    # Get tenant information for the report cover sheet and email
    $tenantInfo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method Get
    $TenantDisplayName = $tenantInfo.value[0].displayName
}

if ($SendEmail) {
    # Connect RJ RunbookHelper for email reporting
    Write-Output "Graph connection for RJ RunbookHelper..."
    Connect-RjRbGraph
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

# Validate target group exists
try {
    $targetGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$TargetGroupId`?`$select=id,displayName" -Method GET -ErrorAction Stop
    Write-RjRbLog -Message "Target Group:    $($targetGroup.displayName)" -Verbose
}
catch {
    Write-Error "Target group with ID '$TargetGroupId' was not found in Entra ID. Please verify the group exists." -ErrorAction Continue
    throw "Target group '$TargetGroupId' not found."
}

# Validate the exclusion group (optional) - it must exist and must not be the target group itself
$excludeGroup = $null
if (-not [string]::IsNullOrWhiteSpace($ExcludeGroupId)) {
    if ($ExcludeGroupId -eq $TargetGroupId) {
        Write-Error "The exclusion group must not be the target group itself - all members would be removed on every run." -ErrorAction Continue
        throw "Exclusion group equals target group."
    }
    try {
        $excludeGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$ExcludeGroupId`?`$select=id,displayName" -Method GET -ErrorAction Stop
        Write-RjRbLog -Message "Exclusion Group: $($excludeGroup.displayName)" -Verbose
    }
    catch {
        Write-Error "Exclusion group with ID '$ExcludeGroupId' was not found in Entra ID. Please verify the group exists." -ErrorAction Continue
        throw "Exclusion group '$ExcludeGroupId' not found."
    }
}

Write-Output ""
Write-Output "Configuration"
Write-Output "---------------------"
Write-Output "Target Group:     $($targetGroup.displayName)"
Write-Output "Secure methods:   $($secureMethods -join ', ')"
Write-Output "Strict mode:      $SecureOnly"
if ($SecureOnly) {
    Write-Output "Unsecure methods: $($unsecureMethods -join ', ')"
}
Write-Output "Exclude admins:   $ExcludeAdmins"
Write-Output "Exclusion group:  $(if ($excludeGroup) { $excludeGroup.displayName } else { "(none)" })"
Write-Output "Mode:             $(if ($WhatIfMode) { "WhatIf (no changes will be made)" } else { "Live" })"

#endregion

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Retrieving the authentication methods registration report..."
Write-Output "---------------------"
Write-Output "Note: This may take a while depending on the number of users in your tenant."

$reportSelect = "`$select=id,userPrincipalName,userDisplayName,userType,methodsRegistered"
try {
    # $top=999 keeps the page count low in large tenants; fall back to default paging if the endpoint rejects it
    try {
        $registrationDetails = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails?`$top=999&$reportSelect")
    }
    catch {
        Write-RjRbLog -Message "Report query with `$top paging failed, retrying with default page size. Error: $($_.Exception.Message)" -Verbose
        $registrationDetails = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails?$reportSelect")
    }
}
catch {
    Write-Error "Failed to retrieve the authentication methods registration report: $($_.Exception.Message)" -ErrorAction Continue
    throw "Registration report query failed."
}

if ($registrationDetails.Count -eq 0) {
    Write-Error "The authentication methods registration report returned no entries. Please verify the tenant has an Entra ID P1/P2 license and the managed identity holds the AuditLog.Read.All permission." -ErrorAction Continue
    throw "Registration report is empty."
}

# Guests are out of scope - they are neither added nor removed
$memberRows = @($registrationDetails | Where-Object { $_.userType -eq "member" })

# Evaluate which users qualify: at least one secure method, and in strict mode no unsecure method
$desiredUsers = [System.Collections.Generic.List[object]]::new()
foreach ($row in $memberRows) {
    $methods = [string[]]@($row.methodsRegistered | Where-Object { $_ })
    if ($methods.Count -eq 0) {
        continue
    }

    $hasSecure = $secureSet.Overlaps($methods)
    $hasUnsecure = $SecureOnly -and $unsecureSet.Overlaps($methods)
    if ($hasSecure -and -not $hasUnsecure) {
        $desiredUsers.Add($row)
    }
}
$desiredUserIds = @($desiredUsers | Select-Object -ExpandProperty id)

# Methods-based evaluation before exclusions - kept for the report "Qualifies" column
$qualifyingUserIds = $desiredUserIds

# Exclusions: admin users and exclusion group members never qualify and are removed if already members
$exclusionReasons = @{}

if ($ExcludeAdmins) {
    Write-Output ""
    Write-Output "Determining admin users (directory role holders)..."

    try {
        $roleAssignments = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$select=principalId")
    }
    catch {
        Write-Error "Failed to retrieve directory role assignments: $($_.Exception.Message). Please verify the managed identity holds the RoleManagement.Read.Directory permission." -ErrorAction Continue
        throw "Directory role assignment query failed."
    }
    $adminPrincipalIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($assignment in $roleAssignments) {
        if ($assignment.principalId) { [void]$adminPrincipalIds.Add($assignment.principalId) }
    }

    # PIM-eligible assignments require Entra ID P2 - degrade to active assignments only if unavailable
    try {
        $eligibleSchedules = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/roleManagement/directory/roleEligibilitySchedules?`$select=principalId")
        foreach ($schedule in $eligibleSchedules) {
            if ($schedule.principalId) { [void]$adminPrincipalIds.Add($schedule.principalId) }
        }
    }
    catch {
        Write-Output "Warning: PIM-eligible role assignments could not be queried (requires Entra ID P2) - only active role assignments are excluded. Error: $($_.Exception.Message)"
    }

    # Resolve principal types via batched lookups: users count directly, role-assignable groups are
    # expanded to their transitive user members, other principals (service principals) are ignored
    $adminUserIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $principalIdList = @($adminPrincipalIds)
    if ($principalIdList.Count -gt 0) {
        $userProbeRequests = @($principalIdList | ForEach-Object -Begin { $idx = 1 } -Process {
                @{
                    id     = "$idx"
                    method = "GET"
                    url    = "/users/$($_)?`$select=id"
                }
                $idx++
            })
        $userProbeResponses = Invoke-GraphBatch -Requests $userProbeRequests -ProgressLabel "admin principal lookups"

        $adminGroupCandidateIds = [System.Collections.Generic.List[string]]::new()
        foreach ($response in $userProbeResponses) {
            if ($response.status -eq 200 -and $response.body.id) {
                [void]$adminUserIds.Add($response.body.id)
            }
            elseif ($response.status -eq 404) {
                $reqIdx = [int]$response.id - 1
                if ($reqIdx -ge 0 -and $reqIdx -lt $principalIdList.Count) {
                    $adminGroupCandidateIds.Add($principalIdList[$reqIdx])
                }
            }
        }

        if ($adminGroupCandidateIds.Count -gt 0) {
            $groupProbeRequests = @($adminGroupCandidateIds | ForEach-Object -Begin { $idx = 1 } -Process {
                    @{
                        id     = "$idx"
                        method = "GET"
                        url    = "/groups/$($_)?`$select=id"
                    }
                    $idx++
                })
            $groupProbeResponses = Invoke-GraphBatch -Requests $groupProbeRequests -ProgressLabel "admin group lookups"
            foreach ($response in $groupProbeResponses) {
                if ($response.status -ne 200 -or -not $response.body.id) { continue }
                $groupMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$($response.body.id)/transitiveMembers/microsoft.graph.user?`$top=999&`$select=id")
                foreach ($member in $groupMembers) { [void]$adminUserIds.Add($member.id) }
            }
        }
    }

    foreach ($adminUserId in $adminUserIds) {
        if (-not $exclusionReasons.ContainsKey($adminUserId)) { $exclusionReasons[$adminUserId] = "admin role" }
    }
    Write-Output "Admin users found:   $($adminUserIds.Count)"
}

if ($excludeGroup) {
    Write-Output ""
    Write-Output "Getting members of exclusion group '$($excludeGroup.displayName)'..."
    $excludeGroupMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$ExcludeGroupId/transitiveMembers/microsoft.graph.user?`$top=999&`$select=id")
    foreach ($member in $excludeGroupMembers) {
        if (-not $exclusionReasons.ContainsKey($member.id)) { $exclusionReasons[$member.id] = "exclusion group" }
    }
    Write-Output "Exclusion group members: $($excludeGroupMembers.Count)"
}

# Excluded users are dropped from the desired set - the regular diff then also removes
# excluded users that are already group members
$excludedQualifyingCount = 0
if ($exclusionReasons.Count -gt 0) {
    $excludedQualifyingCount = @($desiredUserIds | Where-Object { $exclusionReasons.ContainsKey($_) }).Count
    $desiredUserIds = @($desiredUserIds | Where-Object { -not $exclusionReasons.ContainsKey($_) })
}

Write-Output ""
Write-Output "Report entries:      $($registrationDetails.Count)"
Write-Output "Member users:        $($memberRows.Count) (guests are skipped)"
if ($exclusionReasons.Count -gt 0) {
    Write-Output "Excluded users:      $excludedQualifyingCount (qualifying users blocked by exclusions)"
}
Write-Output "Qualifying users:    $($desiredUserIds.Count)"

if ($desiredUserIds.Count -eq 0) {
    Write-Output ""
    Write-Output "Warning: No user qualifies with the current configuration. All current group members will be removed$(if ($WhatIfMode) { " (WhatIf - no changes will be made)" })."
}

# Get current members of the target group - user objects only via OData cast,
# so devices, service principals and nested groups are never touched
Write-Output ""
Write-Output "Getting current members of '$($targetGroup.displayName)'..."
$currentMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$TargetGroupId/members/microsoft.graph.user?`$top=999&`$select=id,userPrincipalName,userType")

# Guests are out of scope on the group side as well - existing guest members are kept
$currentUserMembers = @($currentMembers | Where-Object { $_.userType -ne "Guest" })
$currentMemberIds = @($currentUserMembers | Select-Object -ExpandProperty id)
Write-Output "Current user members: $($currentMemberIds.Count)"

# Calculate diff using HashSets — O(n) instead of O(n²)
$desiredSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$desiredUserIds, [System.StringComparer]::OrdinalIgnoreCase)
$currentSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$currentMemberIds, [System.StringComparer]::OrdinalIgnoreCase)

$toAdd = @($desiredUserIds | Where-Object { -not $currentSet.Contains($_) })
$toRemove = @($currentMemberIds | Where-Object { -not $desiredSet.Contains($_) })

Write-Output ""
Write-Output "Changes required:"
Write-Output "  Users to add:    $($toAdd.Count)"
Write-Output "  Users to remove: $($toRemove.Count)"

# Initialize counters for summary output
$addedCount = 0
$addFailedCount = 0
$removedCount = 0
$removeFailedCount = 0

if ($WhatIfMode) {
    # Dry run - report the pending changes without touching the group
    if ($toAdd.Count -gt 0) {
        $reportUpnLookup = @{}
        foreach ($row in $memberRows) { $reportUpnLookup[$row.id] = $row.userPrincipalName }
        foreach ($userId in $toAdd) {
            Write-Output "## [WhatIf] Would add '$($reportUpnLookup[$userId])'"
        }
    }
    if ($toRemove.Count -gt 0) {
        $memberUpnLookup = @{}
        foreach ($member in $currentUserMembers) { $memberUpnLookup[$member.id] = $member.userPrincipalName }
        foreach ($userId in $toRemove) {
            Write-Output "## [WhatIf] Would remove '$($memberUpnLookup[$userId])'"
        }
    }
}
else {
    # Add new members via Graph batch API (20 per batch call)
    if ($toAdd.Count -gt 0) {
        Write-RjRbLog -Message "Adding $($toAdd.Count) user(s) via batch API..." -Verbose

        $addRequests = @($toAdd | ForEach-Object -Begin { $idx = 1 } -Process {
                @{
                    id      = "$idx"
                    method  = "POST"
                    url     = "/groups/$TargetGroupId/members/`$ref"
                    headers = @{ "Content-Type" = "application/json" }
                    body    = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$_" }
                }
                $idx++
            })

        $addResponses = Invoke-GraphBatch -Requests $addRequests -ProgressLabel "adds"
        $addedCount = ($addResponses | Where-Object { $_.status -in 200, 201, 204 }).Count
        $alreadyExisted = ($addResponses | Where-Object { $_.status -eq 400 -and $_.body.error.message -like "*already exist*" }).Count
        $addFailedCount = $addResponses.Count - $addedCount - $alreadyExisted

        $addedCount += $alreadyExisted  # already-member is not an error

        Write-RjRbLog -Message "Added: $($addedCount) user(s)$(if ($addFailedCount -gt 0) { ", failed: $($addFailedCount)" })" -Verbose
        if ($addFailedCount -gt 0) {
            $addResponses | Where-Object { $_.status -notin 200, 201, 204 -and -not ($_.status -eq 400 -and $_.body.error.message -like "*already exist*") } | ForEach-Object {
                Write-RjRbLog -Message "Add failed (status $($_.status), id $($_.id)): $($_.body.error.message)" -Verbose
            }
        }
    }

    # Remove members that no longer qualify via Graph batch API (20 per batch call)
    if ($toRemove.Count -gt 0) {
        Write-RjRbLog -Message "Removing $($toRemove.Count) user(s) via batch API..." -Verbose

        # Build UPN lookup for verbose logging
        $upnLookup = @{}
        $currentUserMembers | ForEach-Object { $upnLookup[$_.id] = $_.userPrincipalName }

        $removeRequests = @($toRemove | ForEach-Object -Begin { $idx = 1 } -Process {
                @{
                    id     = "$idx"
                    method = "DELETE"
                    url    = "/groups/$TargetGroupId/members/$_/`$ref"
                }
                $idx++
            })

        $removeResponses = Invoke-GraphBatch -Requests $removeRequests -ProgressLabel "removes"
        $removedCount = ($removeResponses | Where-Object { $_.status -in 200, 204 }).Count
        $alreadyGone = ($removeResponses | Where-Object { $_.status -eq 404 }).Count
        $removeFailedCount = $removeResponses.Count - $removedCount - $alreadyGone

        $removedCount += $alreadyGone  # already-removed is not an error

        Write-RjRbLog -Message "Removed: $($removedCount) user(s)$(if ($removeFailedCount -gt 0) { ", failed: $($removeFailedCount)" })" -Verbose
        if ($removeFailedCount -gt 0) {
            $removeResponses | Where-Object { $_.status -notin 200, 204, 404 } | ForEach-Object {
                $reqIdx = [int]$_.id - 1
                $uid = if ($reqIdx -ge 0 -and $reqIdx -lt $toRemove.Count) { $toRemove[$reqIdx] } else { "unknown" }
                $upn = if ($upnLookup.ContainsKey($uid)) { $upnLookup[$uid] } else { $uid }
                Write-RjRbLog -Message "Remove failed (status $($_.status)): $upn — $($_.body.error.message)" -Verbose
            }
        }
    }
}

if ($toAdd.Count -eq 0 -and $toRemove.Count -eq 0) {
    Write-Output ""
    Write-Output "Group is already up to date. No changes needed."
}

#endregion

########################################################
#region     Report File Export (if email or download link is enabled)
########################################################

$reportFiles = @()
$xlsxPath = $null
$tempDir = $null
$fileName_Changes = "mfa-secure-users-group-sync-changes.csv"
$fileName_AllUsers = "mfa-secure-users-group-sync-all-users.csv"
$fileName_Xlsx = "mfa-secure-users-group-sync-report.xlsx"
$actionAddLabel = if ($WhatIfMode) { "Would add" } else { "Added" }
$actionRemoveLabel = if ($WhatIfMode) { "Would remove" } else { "Removed" }
$changeRows = @()

if ($SendEmail -or $CreateDownloadLink) {
    Write-Output ""
    Write-Output "Generating report files..."

    # Unsecure classification for the report columns - the active strict-mode list, or the built-in list for information
    $reportUnsecureSet = if ($unsecureSet.Count -gt 0) {
        $unsecureSet
    }
    else {
        [System.Collections.Generic.HashSet[string]]::new([string[]]$builtInUnsecureMethods, [System.StringComparer]::OrdinalIgnoreCase)
    }

    # Per-user evaluation of all member users from the registration report.
    # "Qualifies" reflects the pure methods evaluation; exclusions are shown separately,
    # the effective add/remove decision ("Action") comes from the exclusion-filtered desired set.
    $qualifiesSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$qualifyingUserIds, [System.StringComparer]::OrdinalIgnoreCase)
    $allUserRows = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $memberRows) {
        $methods = [string[]]@($row.methodsRegistered | Where-Object { $_ })
        $qualifies = $qualifiesSet.Contains($row.id)
        $isDesired = $desiredSet.Contains($row.id)
        $isMember = $currentSet.Contains($row.id)
        $action = if ($isDesired -and -not $isMember) { $actionAddLabel } elseif (-not $isDesired -and $isMember) { $actionRemoveLabel } else { "" }
        $allUserRows.Add([PSCustomObject]@{
                UserPrincipalName    = $row.userPrincipalName
                DisplayName          = $row.userDisplayName
                Qualifies            = if ($qualifies) { "yes" } else { "no" }
                ExclusionReason      = if ($exclusionReasons.ContainsKey($row.id)) { $exclusionReasons[$row.id] } else { "" }
                GroupMemberBefore    = if ($isMember) { "yes" } else { "no" }
                Action               = $action
                SecureMethods        = @($methods | Where-Object { $secureSet.Contains($_) }) -join ', '
                UnsecureMethods      = @($methods | Where-Object { $reportUnsecureSet.Contains($_) }) -join ', '
                AllMethodsRegistered = $methods -join ', '
            })
    }

    # Group members that are missing from the registration report (disabled or deleted accounts)
    $reportRowIds = [System.Collections.Generic.HashSet[string]]::new([string[]]@($memberRows | Select-Object -ExpandProperty id), [System.StringComparer]::OrdinalIgnoreCase)
    foreach ($member in $currentUserMembers) {
        if (-not $reportRowIds.Contains($member.id)) {
            $allUserRows.Add([PSCustomObject]@{
                    UserPrincipalName    = $member.userPrincipalName
                    DisplayName          = ""
                    Qualifies            = "no"
                    ExclusionReason      = if ($exclusionReasons.ContainsKey($member.id)) { $exclusionReasons[$member.id] } else { "" }
                    GroupMemberBefore    = "yes"
                    Action               = $actionRemoveLabel
                    SecureMethods        = ""
                    UnsecureMethods      = ""
                    AllMethodsRegistered = "(not in registration report - disabled or deleted account)"
                })
        }
    }

    $allUserRows = @($allUserRows | Sort-Object UserPrincipalName)
    $changeRows = @($allUserRows | Where-Object { $_.Action } | Sort-Object Action, UserPrincipalName)

    $tempDir = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "MfaSecureUsersGroupSync_$(Get-Date -Format 'yyyyMMdd_HHmmss')"))

    if ($changeRows.Count -gt 0 -and $ReportFileFormat -ne 'XLSX only') {
        $csvChangesPath = Join-Path $tempDir.FullName $fileName_Changes
        $changeRows | Export-Csv -Path $csvChangesPath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvChangesPath
        Write-Output "Exported changes to: $csvChangesPath"
    }

    if ($allUserRows.Count -gt 0 -and $ReportFileFormat -ne 'XLSX only') {
        $csvAllUsersPath = Join-Path $tempDir.FullName $fileName_AllUsers
        $allUserRows | Export-Csv -Path $csvAllUsersPath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvAllUsersPath
        Write-Output "Exported per-user evaluation to: $csvAllUsersPath"
    }

    # Excel workbook: info cover sheet (chosen parameters and result counts) + changes + per-user evaluation
    $coverSheet = [ordered]@{
        Title                      = "MFA Secure Users Group Sync"
        "Tenant"                   = $TenantDisplayName
        "Generated (UTC)"          = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm")
        "Runbook version"          = $Version
        "Mode"                     = $(if ($WhatIfMode) { "WhatIf (no changes were made)" } else { "Live" })
        "Target group"             = $targetGroup.displayName
        "Secure methods"           = ($secureMethods -join ', ')
        "Strict mode (SecureOnly)" = "$SecureOnly"
    }
    if ($SecureOnly) {
        $coverSheet["Unsecure methods"] = ($unsecureMethods -join ', ')
    }
    $coverSheet["Exclude admins"] = "$ExcludeAdmins"
    if ($excludeGroup) {
        $coverSheet["Exclusion group"] = $excludeGroup.displayName
    }
    if ([string]::IsNullOrWhiteSpace($SecureMethodsOverride)) {
        $coverSheet["Method group toggles"] = "Passkeys/FIDO2: $(if ($IncludePasskeys) { 'on' } else { 'off' }), Platform credentials: $(if ($IncludePlatformCredentials) { 'on' } else { 'off' }), Microsoft Authenticator: $(if ($IncludeMicrosoftAuthenticator) { 'on' } else { 'off' }), Software OTP: $(if ($IncludeSoftwareOtp) { 'on' } else { 'off' }), Hardware OTP: $(if ($IncludeHardwareOtp) { 'on' } else { 'off' }), Certificate-based: $(if ($IncludeCertificateBasedAuth) { 'on' } else { 'off' })"
    }
    else {
        $coverSheet["Secure methods override"] = $SecureMethodsOverride
    }
    $coverSheet["Report entries"] = "$($registrationDetails.Count)"
    $coverSheet["Member users evaluated"] = "$($memberRows.Count)"
    if ($exclusionReasons.Count -gt 0) {
        $coverSheet["Excluded users"] = "$excludedQualifyingCount"
    }
    $coverSheet["Qualifying users"] = "$($desiredUserIds.Count)"
    $coverSheet["Previous members"] = "$($currentMemberIds.Count)"
    $coverSheet[$actionAddLabel] = "$($toAdd.Count)"
    $coverSheet[$actionRemoveLabel] = "$($toRemove.Count)"

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxPath = Join-Path $tempDir.FullName $fileName_Xlsx
        Export-RjRbXlsx -Worksheets ([ordered]@{ "Changes" = $changeRows; "All Users" = $allUserRows }) -Path $xlsxPath `
            -CoverSheet $coverSheet `
            -HighlightRules @(
            @{ Column = "Action"; Value = $actionAddLabel; Color = "Green" },
            @{ Column = "Action"; Value = $actionRemoveLabel; Color = "Red" }
        )
        $reportFiles += $xlsxPath
        Write-Output "Exported Excel report to: $xlsxPath"
    }
}

#endregion

########################################################
#region     Upload / Download Link (if CreateDownloadLink is enabled)
########################################################

if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
    Write-Output ""
    Write-Output "Uploading report to storage account..."

    # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
    # transparently connects the managed identity if no Az context is active.
    $uploadResults = Publish-RjRbFilesToStorageContainer `
        -FilePaths $reportFiles `
        -ContainerName $ContainerName `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -LinkExpiryDays $LinkExpiryDays `
        -AddBlobNamePrefix $true

    foreach ($uploadResult in $uploadResults) {
        Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
        $uploadResult.SASLink | Out-String | Write-Output
    }
}

#endregion

########################################################
#region     Send Email Report (if SendEmail is enabled)
########################################################

if ($SendEmail) {
    Write-Output ""
    Write-Output "Preparing email report..."

    $modeNote = if ($WhatIfMode) { " (WhatIf - no changes were made)" } else { "" }
    $changesSummary = if ($changeRows.Count -gt 0) {
        "**$($toAdd.Count) user(s)** to be added and **$($toRemove.Count) user(s)** to be removed$modeNote."
    }
    else {
        "**No changes required** - the group is already in sync$modeNote."
    }

    $attachmentLines = @()
    if ($ReportFileFormat -ne 'XLSX only') {
        if ($changeRows.Count -gt 0) {
            $attachmentLines += "- **$($fileName_Changes)**: All performed changes with the per-user method details (CSV)"
        }
        $attachmentLines += "- **$($fileName_AllUsers)**: Evaluation of every member user - registered methods, qualification and group membership (CSV)"
    }
    if ($ReportFileFormat -ne 'CSV only') {
        $attachmentLines += "- **$($fileName_Xlsx)**: The same data as a formatted Excel workbook with an info cover sheet (chosen parameters and result counts)"
    }

    $summarySection = @"
# MFA Secure Users Group Sync Report

## Summary

$changesSummary

| | |
|---|---|
| **Target group** | $($targetGroup.displayName) |
| **Mode** | $(if ($WhatIfMode) { "WhatIf (no changes were made)" } else { "Live" }) |
| **Secure methods** | $($secureMethods -join ', ') |
| **Strict mode (SecureOnly)** | $SecureOnly |$(if ($SecureOnly) { "`n| **Unsecure methods** | $($unsecureMethods -join ', ') |" })
| **Exclude admins** | $ExcludeAdmins |$(if ($excludeGroup) { "`n| **Exclusion group** | $($excludeGroup.displayName) |" })
| **Report entries** | $($registrationDetails.Count) |
| **Member users evaluated** | $($memberRows.Count) |$(if ($exclusionReasons.Count -gt 0) { "`n| **Excluded users** | $excludedQualifyingCount |" })
| **Qualifying users** | $($desiredUserIds.Count) |
| **Previous members** | $($currentMemberIds.Count) |
| **$actionAddLabel** | $($toAdd.Count) |
| **$actionRemoveLabel** | $($toRemove.Count) |
"@

    $emailFooter = @"

---

*This email was automatically generated. Please do not reply to this email.*
"@

    $markdownContent = @"
$summarySection

## Data Files

The following files are attached to this email:

$($attachmentLines -join "`n")
$emailFooter
"@

    # Fallback content when the CSV files are not attached (size limit):
    # the Excel workbook alone carries the complete data at a fraction of the size.
    $markdownFallback = @"
$summarySection

## Data Files

- **$($fileName_Xlsx)**: Formatted Excel workbook with an info cover sheet, the performed changes and the per-user evaluation of all member users

> **Note:** The CSV files were not attached because they exceed the email attachment size limit. The Excel workbook contains the complete data ("Changes" and "All Users" worksheets). Enable the download link option (CreateDownloadLink) to obtain the raw CSV files.
$emailFooter
"@

    $emailSubject = "MFA Secure Users Group Sync$(if ($WhatIfMode) { " (WhatIf)" }) - $($toAdd.Count) to add, $($toRemove.Count) to remove"

    # Attachment size guarded: with "CSV & XLSX" the email falls back to the workbook alone
    # when the full set exceeds the size budget; otherwise a failed send throws.
    $guardParams = @{
        EmailFrom         = $EmailFrom
        EmailTo           = $EmailTo
        Subject           = $emailSubject
        MarkdownContent   = $markdownContent
        TenantDisplayName = $TenantDisplayName
        ReportVersion     = $Version
    }
    if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxPath) {
        Send-RjRbGuardedReportEmail @guardParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
    }
    else {
        Send-RjRbGuardedReportEmail @guardParams -Attachments $reportFiles
    }
}

#endregion

########################################################
#region     Cleanup
########################################################

# Cleanup temporary report files
if ($tempDir -and (Test-Path $tempDir.FullName)) {
    Remove-Item -Path $tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Write-Verbose "Cleaned up temporary files"
}

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Target Group:         $($targetGroup.displayName)"
Write-Output "Secure methods:       $($secureMethods -join ', ')"
Write-Output "Strict mode:          $SecureOnly"
if ($SecureOnly) {
    Write-Output "Unsecure methods:     $($unsecureMethods -join ', ')"
}
Write-Output "Exclude admins:       $ExcludeAdmins"
Write-Output "Exclusion group:      $(if ($excludeGroup) { $excludeGroup.displayName } else { "(none)" })"
Write-Output "Report entries:       $($registrationDetails.Count)"
Write-Output "Member users:         $($memberRows.Count)"
if ($exclusionReasons.Count -gt 0) {
    Write-Output "Excluded users:       $excludedQualifyingCount"
}
Write-Output "Qualifying users:     $($desiredUserIds.Count)"
Write-Output "Previous members:     $($currentMemberIds.Count)"
if ($WhatIfMode) {
    Write-Output "Would add:            $($toAdd.Count)"
    Write-Output "Would remove:         $($toRemove.Count)"
}
else {
    Write-Output "Added:                $addedCount$(if ($addFailedCount -gt 0) { " (failed: $addFailedCount)" })"
    Write-Output "Removed:              $removedCount$(if ($removeFailedCount -gt 0) { " (failed: $removeFailedCount)" })"
}

Disconnect-MgGraph | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion

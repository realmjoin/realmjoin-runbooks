<#
	.SYNOPSIS
	Keep a group in sync with the primary users of Intune devices

	.DESCRIPTION
	Collects the primary users of all Intune devices of the chosen platforms and keeps an Entra ID group in sync with them. Users without a matching device are removed unless removal is turned off. An include group limits which users are eligible, an exclude group blocks users. A report-only mode previews the changes by email without applying anything.

	.PARAMETER TargetGroupId
	Group that receives the primary users. Its membership is managed by this runbook alone.

	.PARAMETER Windows
	Includes the primary users of Windows devices.

	.PARAMETER MacOS
	Includes the primary users of macOS devices.

	.PARAMETER iOS
	Includes the primary users of iOS and iPadOS devices.

	.PARAMETER Android
	Includes the primary users of Android devices.

	.PARAMETER AdvancedFilter
	OData filter for the devices instead of the platform switches, for example startsWith(deviceName,'FWP-') and operatingSystem eq 'Windows'.

	.PARAMETER IncludeGroupId
	Only members of this group can be added to the target group.

	.PARAMETER ExcludeGroupId
	Members of this group are never added and are removed if present.

	.PARAMETER RemoveUsersWhenNoDeviceMatch
	Removes users from the target group when they are no longer primary user of a matching device. Turn off to only ever add.

	.PARAMETER ReportOnly
	Previews the changes without applying them. The preview goes by email, with the first 10 users per list in the body and the complete lists attached.

	.PARAMETER EmailFrom
	Sender address of the report email. Taken from the tenant setting RJReport.EmailSender.

	.PARAMETER EmailTo
	Address the preview goes to. Only used in report-only mode.

	.PARAMETER ReportFileFormat
	Attach the complete lists as CSV, as an Excel workbook, or both. Only used in report-only mode.

	.PARAMETER BrandingHeaderImageUrl
	Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty.

	.PARAMETER BrandingFooterImageUrl
	Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty.

	.PARAMETER BrandingFooterLink
	Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty.

	.PARAMETER BrandingAccentColor
	Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid.

	.PARAMETER BrandingTextColor
	Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
    RunbookCustomization: {
        "Parameters": {
            "TargetGroupId": {
                "DisplayName": "Target group"
            },
            "Windows": {
                "DisplayName": "Include Windows devices?"
            },
            "MacOS": {
                "DisplayName": "Include macOS devices?"
            },
            "iOS": {
                "DisplayName": "Include iOS devices?"
            },
            "Android": {
                "DisplayName": "Include Android devices?"
            },
            "AdvancedFilter": {
                "DisplayName": "Custom filter"
            },
            "RemoveUsersWhenNoDeviceMatch": {
                "DisplayName": "Remove users without a matching device?"
            },
            "IncludeGroupId": {
                "DisplayName": "Include users from group",
                "Hide": true
            },
            "ExcludeGroupId": {
                "DisplayName": "Exclude users from group",
                "Hide": true
            },
            "ReportOnly": {
                "DisplayName": "Report only?"
            },
            "ReportFileFormat": {
                "DisplayName": "Preview report file format",
                "Select": {
                    "Options": [
                        { "Display": "CSV & XLSX", "ParameterValue": "CSV & XLSX" },
                        { "Display": "CSV only",   "ParameterValue": "CSV only" },
                        { "Display": "XLSX only",  "ParameterValue": "XLSX only" }
                    ],
                    "ShowValue": false
                }
            },
            "EmailTo": {
                "DisplayName": "Send preview report to"
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
            "CallerName": {
                "Hide": true
            }
        },
        "ParameterList": [
            {
                "DisplayName": "Filter eligible users by group?",
                "DisplayAfter": "RemoveUsersWhenNoDeviceMatch",
                "Default": false,
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes, filter by group membership",
                            "Customization": {
                                "Hide": [],
                                "Show": ["IncludeGroupId", "ExcludeGroupId"]
                            }
                        },
                        {
                            "Display": "No, consider all primary users",
                            "Customization": {
                                "Hide": ["IncludeGroupId", "ExcludeGroupId"]
                            },
                            "ParameterValue": false
                        }
                    ]
                }
            }
        ]
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param(
    # Suppress false positive from PSScriptAnalyzer - $idx is assigned in ForEach-Object -Begin and used in -Process block
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "idx")]
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Target group" } )]
    [string]$TargetGroupId,

    [bool]$Windows = $false,
    [bool]$MacOS = $false,
    [bool]$iOS = $false,
    [bool]$Android = $false,

    [string]$AdvancedFilter = "",

    [bool]$RemoveUsersWhenNoDeviceMatch = $true,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Include users from group" } )]
    [string]$IncludeGroupId = "",

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclude users from group" } )]
    [string]$ExcludeGroupId = "",

    [bool]$ReportOnly = $false,

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
    [string]$EmailTo,
    [ValidateSet('CSV & XLSX', 'CSV only', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

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
Write-RjRbLog -Message "Windows: $Windows" -Verbose
Write-RjRbLog -Message "MacOS: $MacOS" -Verbose
Write-RjRbLog -Message "iOS: $iOS" -Verbose
Write-RjRbLog -Message "Android: $Android" -Verbose
Write-RjRbLog -Message "AdvancedFilter: $AdvancedFilter" -Verbose
Write-RjRbLog -Message "IncludeGroupId: $IncludeGroupId" -Verbose
Write-RjRbLog -Message "ExcludeGroupId: $ExcludeGroupId" -Verbose
Write-RjRbLog -Message "RemoveUsersWhenNoDeviceMatch: $RemoveUsersWhenNoDeviceMatch" -Verbose

Write-RjRbLog -Message "ReportOnly: $ReportOnly" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################
if (-not $Windows -and -not $MacOS -and -not $iOS -and -not $Android -and [string]::IsNullOrWhiteSpace($AdvancedFilter)) {
    Write-Error "At least one platform must be selected (Windows, MacOS, iOS, or Android), or provide a custom filter." -ErrorAction Continue
    throw "No platform selected."
}

# Report-only mode has nothing to send the preview to without both a recipient and a configured sender
if ($ReportOnly -and (-not $EmailTo -or -not $EmailFrom)) {
    Write-Error -Message "Report only mode requires both a recipient (EmailTo) and a configured sender address. Configure the sender in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass EmailTo when starting the runbook." -ErrorAction Continue
    throw "Report only mode has no destination for the preview email (missing EmailTo and/or RJReport.EmailSender)."
}

# A sender address is required before any mail can be sent
if ($EmailTo -and -not $EmailFrom) {
    Write-Error -Message "The sender email address is required. Configure it in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -ErrorAction Continue
    throw "Missing email sender configuration (RJReport.EmailSender)."
}
#endregion Parameter Validation

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

$tenantDisplayName = "Unknown Tenant"
if ($ReportOnly) {
    Write-Output "Graph connection for RJ RunbookHelper..."
    Connect-RjRbGraph

    Write-Output "## Retrieving tenant information..."
    try {
        $organizationResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
        if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
            $tenantDisplayName = $organizationResponse.value[0].displayName
        }
        elseif ($organizationResponse.displayName) {
            $tenantDisplayName = $organizationResponse.displayName
        }
        Write-Output "## Tenant: $($tenantDisplayName)"
    }
    catch {
        Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
    }
}
#endregion Connect Part

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

# Validate include group if specified
if ($IncludeGroupId) {
    try {
        $includeGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$IncludeGroupId`?`$select=id,displayName" -Method GET -ErrorAction Stop
        Write-RjRbLog -Message "Include Group:   $($includeGroup.displayName)" -Verbose
    }
    catch {
        Write-Error "Include group with ID '$IncludeGroupId' was not found in Entra ID." -ErrorAction Continue
        throw "Include group '$IncludeGroupId' not found."
    }
}

# Validate exclude group if specified
if ($ExcludeGroupId) {
    try {
        $excludeGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$ExcludeGroupId`?`$select=id,displayName" -Method GET -ErrorAction Stop
        Write-RjRbLog -Message "Exclude Group:   $($excludeGroup.displayName)" -Verbose
    }
    catch {
        Write-Error "Exclude group with ID '$ExcludeGroupId' was not found in Entra ID." -ErrorAction Continue
        throw "Exclude group '$ExcludeGroupId' not found."
    }
}

# Show selected platforms
$selectedPlatforms = @()
if ($Windows) { $selectedPlatforms += "Windows" }
if ($MacOS) { $selectedPlatforms += "macOS" }
if ($iOS) { $selectedPlatforms += "iOS" }
if ($Android) { $selectedPlatforms += "Android" }
Write-RjRbLog -Message "Platforms:       $($selectedPlatforms -join ', ')" -Verbose
#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################
function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query.
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
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $allResults
}

Write-Output ""
Write-Output "Collecting primary users from Intune devices..."
Write-Output "---------------------"
Write-Output "Note: This may take a while depending on the number of devices in your tenant."

# Build OData filter for selected operating systems
$osFilters = @()
if ($Windows) { $osFilters += "operatingSystem eq 'Windows'" }
if ($MacOS) { $osFilters += "operatingSystem eq 'macOS'" }
if ($iOS) { $osFilters += "operatingSystem eq 'iOS'" }
if ($Android) { $osFilters += "operatingSystem eq 'Android'" }
$osFilter = [System.Uri]::EscapeDataString("(" + ($osFilters -join " or ") + ")")

# Build Graph URI — apply OS filter; if an advanced filter is provided it replaces the OS filter entirely
$graphFilter = if (-not [string]::IsNullOrWhiteSpace($AdvancedFilter)) {
    [System.Uri]::EscapeDataString($AdvancedFilter)
} else {
    $osFilter
}

# Retrieve all managed devices
$allDevices = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=$graphFilter&`$select=id,deviceName,operatingSystem,userId")

Write-Output "Devices found:   $($allDevices.Count) (across selected platform(s))"

# Extract unique primary user IDs — skip devices without an assigned user
$desiredUserIds = @($allDevices |
    Where-Object { -not [string]::IsNullOrEmpty($_.userId) } |
    Select-Object -ExpandProperty userId |
    Sort-Object -Unique)
Write-Output "Unique primary users: $($desiredUserIds.Count)"

# Apply include scope filter — use HashSet for O(1) lookups
if ($IncludeGroupId) {
    Write-Output ""
    Write-Output "Applying include scope from '$($includeGroup.displayName)'..."
    $includeMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$IncludeGroupId/members?`$select=id")
    $includeSet = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@($includeMembers | Where-Object { $_.id } | Select-Object -ExpandProperty id),
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $desiredUserIds = @($desiredUserIds | Where-Object { $includeSet.Contains($_) })
    Write-Output "Eligible users after include filter: $($desiredUserIds.Count)"
}

# Apply exclude scope filter — use HashSet for O(1) lookups
if ($ExcludeGroupId) {
    Write-Output ""
    Write-Output "Applying exclude scope from '$($excludeGroup.displayName)'..."
    $excludeMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$ExcludeGroupId/members?`$select=id")
    $excludeSet = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@($excludeMembers | Where-Object { $_.id } | Select-Object -ExpandProperty id),
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $desiredUserIds = @($desiredUserIds | Where-Object { -not $excludeSet.Contains($_) })
    Write-Output "Eligible users after exclude filter: $($desiredUserIds.Count)"
}

# Get current members of target group (users only)
Write-Output ""
Write-Output "Getting current members of '$($targetGroup.displayName)'..."
$currentMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$TargetGroupId/members?`$select=id,userPrincipalName,displayName")

# Filter to user objects only (groups can contain non-user members)
$currentUserMembers = @($currentMembers | Where-Object { $_.userPrincipalName })
$currentMemberIds = @($currentUserMembers | Select-Object -ExpandProperty id)
Write-Output "Current user members: $($currentMemberIds.Count)"

# Calculate diff using HashSets — O(n) instead of O(n²)
$desiredSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$desiredUserIds, [System.StringComparer]::OrdinalIgnoreCase)
$currentSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$currentMemberIds, [System.StringComparer]::OrdinalIgnoreCase)

$toAdd = @($desiredUserIds  | Where-Object { -not $currentSet.Contains($_) })
$toRemove = @($currentMemberIds | Where-Object { -not $desiredSet.Contains($_) })

# Removal opt-out is applied to the diff itself, so that both the summary output and the
# report-only preview reflect what would actually happen rather than the raw difference.
if (-not $RemoveUsersWhenNoDeviceMatch) {
    Write-RjRbLog -Message "Removal is disabled. $($toRemove.Count) user(s) would have been removed but are kept in the group." -Verbose
    $toRemove = @()
}

Write-Output ""
Write-Output "Changes required:"
Write-Output "  Users to add:    $($toAdd.Count)"
Write-Output "  Users to remove: $($toRemove.Count)"

# Build a UPN lookup for both the preview mail and the removal logging below.
# Current members already carry their UPN; users to be added must be resolved from Graph,
# because user-facing output must never show bare object IDs.
$upnLookup = @{}
$displayNameLookup = @{}
$currentUserMembers | ForEach-Object {
    $upnLookup[$_.id] = $_.userPrincipalName
    $displayNameLookup[$_.id] = $_.displayName
}

#region Report Only Preview
if ($ReportOnly) {
    Write-Output ""
    Write-Output "Report-only mode: no changes will be applied."
    Write-Output "---------------------"

    # Resolve display names for the users that would be added
    if ($toAdd.Count -gt 0) {
        $addLookupRequests = @($toAdd | ForEach-Object -Begin { $idx = 1 } -Process {
                @{
                    id     = "$idx"
                    method = "GET"
                    url    = "/users/$_`?`$select=id,displayName,userPrincipalName"
                }
                $idx++
            })

        try {
            $addLookupResponses = Invoke-RjRbGraphBatch -Requests $addLookupRequests
            $addLookupResponses | Where-Object { $_.status -eq 200 -and $_.body.id } | ForEach-Object {
                $upnLookup[$_.body.id] = $_.body.userPrincipalName
                $displayNameLookup[$_.body.id] = $_.body.displayName
            }
        }
        catch {
            Write-RjRbLog -Message "Could not resolve user names for the preview, falling back to object IDs: $($_.Exception.Message)" -Verbose
        }
    }

    # Format a user ID as a readable line, falling back to the raw ID if it could not be resolved
    $formatUser = {
        param($UserId)
        if ($upnLookup.ContainsKey($UserId) -and $upnLookup[$UserId]) {
            "- $($upnLookup[$UserId]) ($UserId)"
        }
        else {
            "- $UserId"
        }
    }

    # The runbook output always lists every affected user
    $addLines = if ($toAdd.Count -gt 0) { ($toAdd | ForEach-Object { & $formatUser $_ }) -join "`n" } else { "_No users would be added._" }
    $removeLines = if ($toRemove.Count -gt 0) { ($toRemove | ForEach-Object { & $formatUser $_ }) -join "`n" } else { "_No users would be removed._" }

    foreach ($previewLine in @($addLines, $removeLines)) {
        Write-Output $previewLine
    }

    $removalNote = if (-not $RemoveUsersWhenNoDeviceMatch) {
        "`n> Removal of users without a matching device is disabled for this run, so no removals are listed.`n"
    }
    else {
        ""
    }

    if ($EmailTo) {
        # The mail body shows at most this many users per list; the complete lists travel as attached report files
        $maxUsersInMailBody = 10

        # Format a list for the mail body: the first entries only, then a pointer to the attachment
        $formatMailList = {
            param($UserIds, $EmptyText)
            if ($UserIds.Count -eq 0) { return $EmptyText }
            $shown = @($UserIds | Select-Object -First $maxUsersInMailBody)
            $lines = ($shown | ForEach-Object { & $formatUser $_ }) -join "`n"
            if ($UserIds.Count -gt $shown.Count) {
                $lines += "`n- _... and $($UserIds.Count - $shown.Count) more. The complete list is in the attached report file(s)._"
            }
            return $lines
        }

        $addLinesMail = & $formatMailList $toAdd "_No users would be added._"
        $removeLinesMail = & $formatMailList $toRemove "_No users would be removed._"

        # One row per proposed change, shared by the CSV and XLSX report files
        $previewRows = @(
            foreach ($userId in $toAdd) {
                [PSCustomObject]@{
                    Action            = "Add"
                    DisplayName       = if ($displayNameLookup[$userId]) { $displayNameLookup[$userId] } else { "" }
                    UserPrincipalName = if ($upnLookup[$userId]) { $upnLookup[$userId] } else { "" }
                    UserId            = $userId
                }
            }
            foreach ($userId in $toRemove) {
                [PSCustomObject]@{
                    Action            = "Remove"
                    DisplayName       = if ($displayNameLookup[$userId]) { $displayNameLookup[$userId] } else { "" }
                    UserPrincipalName = if ($upnLookup[$userId]) { $upnLookup[$userId] } else { "" }
                    UserId            = $userId
                }
            }
        )

        # Write the report files that carry the complete lists; they are attached to the preview mail
        $reportFiles = @()
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "GroupSyncPreview_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        if ($previewRows.Count -gt 0) {
            try {
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                $safeGroupName = $targetGroup.displayName -replace '[^\w\-]', '_'
                $fileBaseName = "GroupSyncPreview_$($safeGroupName)_$(Get-Date -Format 'yyyy-MM-dd_HH-mm')"

                if ($ReportFileFormat -ne 'XLSX only') {
                    $csvFile = Join-Path $tempDir "$fileBaseName.csv"
                    $previewRows | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
                    $reportFiles += $csvFile
                }

                if ($ReportFileFormat -ne 'CSV only') {
                    $xlsxFile = Join-Path $tempDir "$fileBaseName.xlsx"
                    $workbookCoverSheet = [ordered]@{
                        Title               = 'Group membership sync preview'
                        Generated           = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
                        Tenant              = $tenantDisplayName
                        'Target group'      = $targetGroup.displayName
                        'Devices evaluated' = $allDevices.Count
                        'Users to add'      = $toAdd.Count
                        'Users to remove'   = $toRemove.Count
                        'Report version'    = $Version
                    }
                    Export-RjRbXlsx -InputObject $previewRows -WorksheetName 'Changes' -Path $xlsxFile `
                        -CoverSheet $workbookCoverSheet `
                        -HighlightRules @(
                        @{ Column = 'Action'; Value = 'Add'; Color = 'Green' }
                        @{ Column = 'Action'; Value = 'Remove'; Color = 'Red' }
                    )
                    $reportFiles += $xlsxFile
                }

                Write-Output ""
                Write-Output "Report file(s) generated: $($reportFiles.Count) ($ReportFileFormat)"
            }
            catch {
                Write-Error "Failed to create the preview report file(s) in '$tempDir': $($_.Exception.Message). The preview email is not sent without the complete user lists. Check that the Automation sandbox has a writable temp directory and try again." -ErrorAction Continue
                throw "Creating the preview report file(s) failed."
            }
        }

        # Resolve optional tenant email branding once per run (never fails the send)
        $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

        $emailSubject = "Group Sync Preview - $($targetGroup.displayName) - $(Get-Date -Format 'yyyy-MM-dd')"

        $attachmentNote = if ($reportFiles.Count -gt 0) {
            "`nThe attached report file(s) contain the complete list of all $($previewRows.Count) proposed change(s).`n"
        }
        else {
            ""
        }

        $markdownContent = @"
## Group membership sync preview

This is a **report-only** run. No group memberships were changed.

**Target group:** $($targetGroup.displayName)
**Devices evaluated:** $($allDevices.Count)
**Primary users in scope:** $($desiredUserIds.Count)
**Current user members:** $($currentMemberIds.Count)
$removalNote$attachmentNote
### Users that would be added ($($toAdd.Count))

$addLinesMail

### Users that would be removed ($($toRemove.Count))

$removeLinesMail

---

*This email was automatically generated. Please do not reply to this email.*
"@

        try {
            $emailParams = @{
                EmailFrom         = $EmailFrom
                EmailTo           = $EmailTo
                Subject           = $emailSubject
                MarkdownContent   = $markdownContent
                TenantDisplayName = $tenantDisplayName
                ReportVersion     = $Version
            }
            if ($reportFiles.Count -gt 0) {
                $emailParams.Attachments = $reportFiles
            }
            Send-RjReportEmail @emailParams @brandingMailParams
            Write-Output ""
            Write-Output "Preview report sent to '$EmailTo'$(if ($reportFiles.Count -gt 0) { " with $($reportFiles.Count) attachment(s)" })."
        }
        catch {
            Write-Error "Failed to send the report-only preview email to '$EmailTo': $($_.Exception.Message). Verify that the sender address is a valid, licensed mailbox and that the managed identity has the Mail.Send permission." -ErrorAction Continue
            throw "Sending the preview report failed."
        }
    }

}
#endregion Report Only Preview

# Everything below applies changes, so it is skipped entirely in report-only mode.
# A guard is used rather than an early return, so that the Cleanup region still runs.
if (-not $ReportOnly) {

    # Initialize counters for summary output
    $addedCount = 0
    $addFailedCount = 0
    $removedCount = 0
    $removeFailedCount = 0

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

        $addResponses = Invoke-RjRbGraphBatch -Requests $addRequests
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

    # Remove stale members via Graph batch API (20 per batch call)
    # ($toRemove was already emptied above when RemoveUsersWhenNoDeviceMatch is disabled.)
    if ($toRemove.Count -gt 0) {
        Write-RjRbLog -Message "Removing $($toRemove.Count) user(s) via batch API..." -Verbose

        $removeRequests = @($toRemove | ForEach-Object -Begin { $idx = 1 } -Process {
                @{
                    id     = "$idx"
                    method = "DELETE"
                    url    = "/groups/$TargetGroupId/members/$_/`$ref"
                }
                $idx++
            })

        $removeResponses = Invoke-RjRbGraphBatch -Requests $removeRequests
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

    if ($toAdd.Count -eq 0 -and $toRemove.Count -eq 0) {
        Write-Output ""
        Write-Output "Group is already up to date. No changes needed."
    }

}
#endregion Main Part

########################################################
#region     Cleanup
########################################################
Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Target Group:         $($targetGroup.displayName)"
Write-Output "Platforms:            $($selectedPlatforms -join ', ')"
if ($IncludeGroupId) { Write-Output "Include Scope:        $($includeGroup.displayName)" }
if ($ExcludeGroupId) { Write-Output "Exclude Scope:        $($excludeGroup.displayName)" }
Write-Output "Devices evaluated:    $($allDevices.Count)"
Write-Output "Desired members:      $($desiredUserIds.Count)"
Write-Output "Previous members:     $($currentMemberIds.Count)"
Write-Output "Added:                $($toAdd.Count)"
Write-Output "Removed:              $($toRemove.Count)"
Write-Output "Removal enabled:      $($RemoveUsersWhenNoDeviceMatch)"

Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

if ($reportFiles) {
    foreach ($reportFilePath in $reportFiles) {
        if ($reportFilePath -and (Test-Path -LiteralPath $reportFilePath)) {
            try {
                Remove-Item -LiteralPath $reportFilePath -Force -ErrorAction Stop
                Write-RjRbLog -Message "Removed temporary report file: $reportFilePath" -Verbose
            }
            catch {
                Write-RjRbLog -Message "Failed to remove temporary report file '$reportFilePath': $($_.Exception.Message)" -Verbose
            }
        }
    }
}

if ($tempDir -and (Test-Path -LiteralPath $tempDir)) {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
    if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
        Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
    }
}

Write-Output ""
Write-Output "Done!"
#endregion Cleanup

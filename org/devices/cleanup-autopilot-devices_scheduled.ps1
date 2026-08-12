<#
	.SYNOPSIS
	Clean up orphaned and stale Windows Autopilot device registrations

	.DESCRIPTION
	This scheduled runbook performs regular maintenance of Windows Autopilot device registrations by identifying and removing orphaned devices whose serial numbers no longer match any Intune managed device, and optionally removing never-enrolled Autopilot devices that exceed a configurable age threshold. The runbook operates in WhatIf mode by default for safe reporting, and can optionally send an email summary with CSV and/or Excel (xlsx) attachments listing the devices that would be or were deleted.
	The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
	The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
	When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

	.NOTES
	Prerequisites:
	- The Azure Automation managed identity must hold these Microsoft Graph application
	  permissions: DeviceManagementManagedDevices.Read.All,
	  DeviceManagementServiceConfig.ReadWrite.All, Organization.Read.All, Device.ReadWrite.All
	  (Device.ReadWrite.All only when the "Delete Autopilot and Entra device" mode is used), and
	  Mail.Send (Mail.Send only when email reporting is enabled).
	- Grant the permissions before the first scheduled run.

	Warning - deletion is irreversible:
	- Removing an Autopilot device identity permanently deletes it from Windows Autopilot.
	- The physical device cannot re-enter Autopilot until its hardware hash is re-uploaded.
	- There is no soft-delete or recycle bin for Autopilot records.
	- Deleting the Entra (Azure AD) device object is likewise permanent; only do so for records
	  that are genuinely dead (the device will never enroll again).

	Recommended first-run procedure:
	- Run with Delete mode = "WhatIf (report only)" (the default) and review the output or emailed CSV.
	- Confirm the identified devices are genuinely orphaned or never-enrolled.
	- Switch to a deletion mode only after the candidate list has been reviewed.

	Parameter interactions:
	- DeleteMode defaults to "WhatIf (report only)"; no deletions occur in that mode.
	- "Delete Autopilot device" removes only the Autopilot identity. "Delete Autopilot and Entra
	  device" additionally removes the matching Entra (Azure AD) device object, which would
	  otherwise be left behind as a stale/dead record once the Autopilot identity is gone.
	- CleanupOrphanedDevices and CleanupNeverEnrolledDevices are independent; either or both
	  can be enabled. NeverEnrolledAgeDays applies only to the never-enrolled check.
	- GroupTagFilter, ManufacturerFilter and ModelFilter are all optional; leave a filter empty to
	  evaluate all values for that dimension. When more than one filter is set they are combined with
	  AND - a device must match every populated filter to remain in scope. GroupTagFilter matches the
	  group tag exactly (case-insensitive); ManufacturerFilter and ModelFilter match as case-insensitive
	  substrings, so "Dell" matches "Dell Inc." and "Surface" matches "Surface Laptop 3".
	- ExcludeSerialNumbers is applied after the AND filters as an exclusion: any device whose serial
	  number is in the list (exact, case-insensitive) is removed from scope regardless of the other
	  filters. Leave empty to exclude nothing.

	.PARAMETER DeleteMode
	Controls what the runbook does with the identified cleanup candidates. "WhatIf (report only)" performs no deletion and only reports the candidates (default, safe). "Delete Autopilot device" removes the Autopilot device identities. "Delete Autopilot and Entra device" removes the Autopilot identities and the matching Entra (Azure AD) device objects, which would otherwise remain as stale records.

	.PARAMETER GroupTagFilter
	Comma-separated Autopilot group tags to limit the cleanup scope. Matched exactly (case-insensitive). Leave empty to process all Autopilot devices regardless of group tag.

	.PARAMETER ManufacturerFilter
	Comma-separated device manufacturers to limit the cleanup scope. Matched as case-insensitive substrings, so "Dell" matches "Dell Inc.". Combined with the other filters using AND. Leave empty to process all manufacturers.

	.PARAMETER ModelFilter
	Comma-separated device models to limit the cleanup scope. Matched as case-insensitive substrings, so "Surface" matches "Surface Laptop 3". Combined with the other filters using AND. Leave empty to process all models.

	.PARAMETER ExcludeSerialNumbers
	Comma-separated serial numbers to exclude from the cleanup. Matched exactly (case-insensitive). Any device whose serial number is in this list is removed from scope regardless of the other filters. Leave empty to exclude nothing.

	.PARAMETER CleanupOrphanedDevices
	When enabled, removes Autopilot devices that have contacted Intune in the past but whose serial number is no longer found among Intune managed devices (the managed device record was deleted).

	.PARAMETER OrphanedLastContactedDays
	Age threshold in days for orphaned devices. An Autopilot device is only treated as orphaned when its last contact with Intune was more than this number of days ago and its serial is no longer present in Intune. This prevents removing devices that contacted Intune recently.

	.PARAMETER CleanupNeverEnrolledDevices
	When enabled, removes never-enrolled Autopilot devices (devices that never contacted Intune).

	.PARAMETER NeverEnrolledAgeDays
	Age threshold in days for never-enrolled devices. Measured on the Device creation date.

	.PARAMETER EmailTo
	Optional email recipient address for the cleanup summary report. Leave empty to only write results to the runbook log.

	.PARAMETER EmailFrom
	The sender email address for the summary report. This is configured via Runbook Customizations.

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
			"DeleteMode": {
				"DisplayName": "Deletion mode"
			},
			"GroupTagFilter": {
				"DisplayName": "Autopilot Group Tag Filter (comma-separated exact match, leave empty for all)"
			},
			"ManufacturerFilter": {
				"DisplayName": "Manufacturer Filter (comma-separated, substring match, leave empty for all)"
			},
			"ModelFilter": {
				"DisplayName": "Model Filter (comma-separated, substring match, leave empty for all)"
			},
			"ExcludeSerialNumbers": {
				"DisplayName": "Exclude Serial Numbers (comma-separated exact match, leave empty for none)"
			},
			"CleanupOrphanedDevices": {
				"DisplayName": "Clean up orphaned Autopilot devices"
			},
			"OrphanedLastContactedDays": {
				"DisplayName": "Orphaned device last-contacted threshold (days)"
			},
			"CleanupNeverEnrolledDevices": {
				"DisplayName": "Clean up never-enrolled Autopilot devices",
				"Select": {
					"Options": [
						{
							"Display": "Yes - remove aged never-enrolled devices",
							"Customization": {
								"Show": [
									"NeverEnrolledAgeDays"
								]
							},
							"ParameterValue": true
						},
						{
							"Display": "No",
							"Customization": {
								"Hide": [
									"NeverEnrolledAgeDays"
								]
							},
							"ParameterValue": false
						}
					]
				}
			},
			"NeverEnrolledAgeDays": {
				"DisplayName": "Never-enrolled device age threshold (days)",
				"Hide": true
			},
			"EmailTo": {
				"DisplayName": "Email recipient for cleanup summary (optional)"
			},
			"EmailFrom": {
				"Hide": true
			},
			"ReportFileFormat": {
				"DisplayName": "Report file format",
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
			"CreateDownloadLink": {
				"DisplayName": "Create a file download link (upload report to storage)?",
				"SelectSimple": {
					"Yes - upload report and return a download link": true,
					"No - do not create a download link": false
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.8" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param (
    [ValidateSet("WhatIf (report only)", "Delete Autopilot device", "Delete Autopilot and Entra device")]
    [string]$DeleteMode = "WhatIf (report only)",

    [string]$GroupTagFilter = "",

    [string]$ManufacturerFilter = "",

    [string]$ModelFilter = "",

    [string]$ExcludeSerialNumbers = "",

    [bool]$CleanupOrphanedDevices = $true,

    [int]$OrphanedLastContactedDays = 90,

    [bool]$CleanupNeverEnrolledDevices = $false,

    [int]$NeverEnrolledAgeDays = 90,

    [string]$EmailTo = "",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ })]
    [string]$EmailFrom,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "cleanup-autopilot-devices",

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

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "DeleteMode: $DeleteMode" -Verbose
Write-RjRbLog -Message "GroupTagFilter: $GroupTagFilter" -Verbose
Write-RjRbLog -Message "ManufacturerFilter: $ManufacturerFilter" -Verbose
Write-RjRbLog -Message "ModelFilter: $ModelFilter" -Verbose
Write-RjRbLog -Message "ExcludeSerialNumbers: $ExcludeSerialNumbers" -Verbose
Write-RjRbLog -Message "CleanupOrphanedDevices: $CleanupOrphanedDevices" -Verbose
Write-RjRbLog -Message "OrphanedLastContactedDays: $OrphanedLastContactedDays" -Verbose
Write-RjRbLog -Message "CleanupNeverEnrolledDevices: $CleanupNeverEnrolledDevices" -Verbose
Write-RjRbLog -Message "NeverEnrolledAgeDays: $NeverEnrolledAgeDays" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
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
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $_" -ErrorAction Continue
    throw
}

# Connect-RjRbGraph is required because Send-RjReportEmail (optional email path) uses it for sender auth.
try {
    Connect-RjRbGraph
}
catch {
    Write-Error "Failed to connect via Connect-RjRbGraph (required for email sender auth): $_" -ErrorAction Continue
    throw
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Preflight-Check"
Write-Output "---------------------"

# --- Check 1: Email configuration consistency (email is optional) ---
if ($EmailTo -notlike "") {
    if ($EmailFrom -like "") {
        Write-RjRbLog -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -NoDebugOnly
        Write-Output "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
        $sendEmail = $false
    }
    else {
        Write-RjRbLog -Message "Email alert will be sent from '$EmailFrom' to '$EmailTo'." -Verbose
        Write-Output "Email alert requested: '$EmailTo'"
        $sendEmail = $true
    }
}
else {
    Write-RjRbLog -Message "EmailTo is empty - no email alert will be sent." -Verbose
    $sendEmail = $false
}

# --- Check 2: A target storage account is required to create a download link ---
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

# --- Check 3: Age thresholds must be non-negative ---
if ($OrphanedLastContactedDays -lt 0) {
    Write-Error "OrphanedLastContactedDays must be 0 or greater. Submitted value: $OrphanedLastContactedDays." -ErrorAction Continue
    throw "Invalid parameter: OrphanedLastContactedDays cannot be negative."
}
if ($NeverEnrolledAgeDays -lt 0) {
    Write-Error "NeverEnrolledAgeDays must be 0 or greater. Submitted value: $NeverEnrolledAgeDays." -ErrorAction Continue
    throw "Invalid parameter: NeverEnrolledAgeDays cannot be negative."
}

# --- Check 4: At least one cleanup action enabled (advisory) ---
if (-not $CleanupOrphanedDevices -and -not $CleanupNeverEnrolledDevices) {
    Write-RjRbLog -Message "WARNING: Both CleanupOrphanedDevices and CleanupNeverEnrolledDevices are disabled. The runbook will report Autopilot device counts only - no devices will be removed." -NoDebugOnly
    Write-Output "WARNING: No cleanup action is enabled. The runbook will report counts only."
}

# --- Check 5: Parse the scope filters into trimmed, non-empty arrays ---
# Each filter is independent; an empty filter means "match all values for that dimension".
# When more than one is populated they are combined with AND (a device must match every set filter).
function ConvertTo-FilterList {
    param([string]$RawValue)
    if ($RawValue -like "") { return @() }
    return @($RawValue -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
}

$groupTagList = ConvertTo-FilterList -RawValue $GroupTagFilter
$manufacturerList = ConvertTo-FilterList -RawValue $ManufacturerFilter
$modelList = ConvertTo-FilterList -RawValue $ModelFilter
$excludeSerialList = ConvertTo-FilterList -RawValue $ExcludeSerialNumbers

# --- Resolve the deletion mode into the action flags used throughout the runbook ---
$whatIfMode = ($DeleteMode -eq "WhatIf (report only)")
$deleteEntraDevice = ($DeleteMode -eq "Delete Autopilot and Entra device")

# --- Status quo: show the effective run configuration ---
Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

if ($whatIfMode) {
    Write-Output "Deletion Mode: WhatIf - no devices will be deleted, only reported"
}
elseif ($deleteEntraDevice) {
    Write-Output "Deletion Mode: Autopilot identity + matching Entra device will be deleted"
}
else {
    Write-Output "Deletion Mode: Autopilot identity only will be deleted"
}

if ($CleanupOrphanedDevices) {
    Write-Output "Cleanup Orphaned Devices: ENABLED"
    Write-Output "Orphaned Last-Contacted Threshold: $($OrphanedLastContactedDays) day(s)"
}
else {
    Write-Output "Cleanup Orphaned Devices: DISABLED"
}

if ($CleanupNeverEnrolledDevices) {
    Write-Output "Cleanup Never-Enrolled Devices: ENABLED"
    Write-Output "Never-Enrolled Age Threshold: $($NeverEnrolledAgeDays) day(s)"
}
else {
    Write-Output "Cleanup Never-Enrolled Devices: DISABLED"
}

if ($groupTagList.Count -gt 0) {
    Write-Output "Group Tag Filter (exact): $($groupTagList -join ', ')"
}
else {
    Write-Output "Group Tag Filter: all group tags (no filter applied)"
}

if ($manufacturerList.Count -gt 0) {
    Write-Output "Manufacturer Filter (substring): $($manufacturerList -join ', ')"
}
else {
    Write-Output "Manufacturer Filter: all manufacturers (no filter applied)"
}

if ($modelList.Count -gt 0) {
    Write-Output "Model Filter (substring): $($modelList -join ', ')"
}
else {
    Write-Output "Model Filter: all models (no filter applied)"
}

if ($excludeSerialList.Count -gt 0) {
    Write-Output "Exclude Serial Numbers (exact): $($excludeSerialList -join ', ')"
}
else {
    Write-Output "Exclude Serial Numbers: none"
}

if ($groupTagList.Count -gt 0 -and ($manufacturerList.Count -gt 0 -or $modelList.Count -gt 0) -or ($manufacturerList.Count -gt 0 -and $modelList.Count -gt 0)) {
    Write-Output "(Filters are combined with AND - a device must match every populated filter.)"
}

#endregion

########################################################
#region     Function Definitions
########################################################

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
#region     Main Part
########################################################

# --- Pagination helper ---
function Get-GraphPagedResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )
    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    do {
        try {
            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        }
        catch {
            Write-Error "Paged Graph request failed at '$nextLink': $($_.Exception.Message)" -ErrorAction Continue
            throw
        }
        if ($response.value) {
            $allResults.AddRange([object[]]$response.value)
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)
    return $allResults
}

# --- Helper: is this a usable Entra deviceId (not empty / not the all-zero GUID)? ---
function Test-ValidEntraDeviceId {
    param([string]$Id)
    return (-not [string]::IsNullOrWhiteSpace($Id)) -and ($Id -ne "00000000-0000-0000-0000-000000000000")
}

# --- Retrieve all Windows Autopilot device identities ---
Write-Output ""
Write-Output "Retrieving Autopilot device identities..."
$autopilotDevices = $null
try {
    # Beta endpoint is required: remediationState / remediationStateLastModifiedDateTime
    # (used for the never-enrolled age check) do not exist on the v1.0 resource.
    $autopilotDevices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"
}
catch {
    $message = $_.Exception.Message
    if ($message -like "*403*" -or $message -like "*Forbidden*" -or $message -like "*401*" -or $message -like "*Unauthorized*") {
        Write-Error ("Access denied while retrieving Autopilot device identities. The managed identity is missing the 'DeviceManagementServiceConfig.ReadWrite.All' application permission in Microsoft Graph. Grant it via Entra ID > Enterprise Applications > the Automation account managed identity > App role assignments (Microsoft Graph, app ID 00000003-0000-0000-c000-000000000000). Changes may take a few minutes to propagate.") -ErrorAction Continue
        throw "Missing Graph permission: DeviceManagementServiceConfig.ReadWrite.All on managed identity"
    }
    Write-Error "Failed to retrieve Autopilot device identities from Microsoft Graph: $message" -ErrorAction Continue
    throw
}
Write-RjRbLog -Message "Retrieved $($autopilotDevices.Count) Autopilot device identities" -Verbose
Write-Output "Found $($autopilotDevices.Count) Autopilot device identities."

# --- Retrieve all Windows Intune managed devices ---
Write-Output "Retrieving Intune managed Windows devices..."
$intuneWindowsDevices = $null
try {
    $intuneWindowsDevices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$select=id,serialNumber,deviceName"
}
catch {
    $message = $_.Exception.Message
    if ($message -like "*403*" -or $message -like "*Forbidden*" -or $message -like "*401*" -or $message -like "*Unauthorized*") {
        Write-Error ("Access denied while retrieving Intune managed devices. The managed identity is missing the 'DeviceManagementManagedDevices.Read.All' application permission in Microsoft Graph. Grant it via Entra ID > Enterprise Applications > the Automation account managed identity > App role assignments.") -ErrorAction Continue
        throw "Missing Graph permission: DeviceManagementManagedDevices.Read.All on managed identity"
    }
    Write-Error "Failed to retrieve Intune managed devices from Microsoft Graph: $message" -ErrorAction Continue
    throw
}
Write-RjRbLog -Message "Retrieved $($intuneWindowsDevices.Count) Intune managed Windows devices" -Verbose
Write-Output "Found $($intuneWindowsDevices.Count) Intune managed Windows devices."

# --- Build a case-insensitive lookup of Intune serial numbers ---
$intuneSerialNumbers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($d in $intuneWindowsDevices) {
    if (-not [string]::IsNullOrWhiteSpace($d.serialNumber)) {
        [void]$intuneSerialNumbers.Add($d.serialNumber.Trim())
    }
}

# --- Apply scope filters (group tag / manufacturer / model), combined with AND ---
# groupTag, model and manufacturer are all returned by the collection query, so scoping can happen
# here before the per-device detail lookups. Group tag is matched exactly (case-insensitive); model
# and manufacturer are matched as case-insensitive substrings (e.g. "Dell" matches "Dell Inc.").
if ($groupTagList.Count -gt 0 -or $manufacturerList.Count -gt 0 -or $modelList.Count -gt 0) {
    $autopilotScoped = $autopilotDevices | Where-Object {
        $tag = if ($null -ne $_.groupTag) { $_.groupTag.Trim() } else { "" }
        $manufacturer = if ($null -ne $_.manufacturer) { $_.manufacturer } else { "" }
        $model = if ($null -ne $_.model) { $_.model } else { "" }

        $tagMatch = ($groupTagList.Count -eq 0) -or ($groupTagList -contains $tag)
        $manufacturerMatch = ($manufacturerList.Count -eq 0) -or ($manufacturerList | Where-Object { $manufacturer -like "*$_*" }).Count -gt 0
        $modelMatch = ($modelList.Count -eq 0) -or ($modelList | Where-Object { $model -like "*$_*" }).Count -gt 0

        $tagMatch -and $manufacturerMatch -and $modelMatch
    }
    $scopedCount = @($autopilotScoped).Count
    Write-RjRbLog -Message "Scope filters applied (AND): $scopedCount of $($autopilotDevices.Count) Autopilot devices match." -Verbose
    Write-Output "Scope filters applied: $scopedCount of $($autopilotDevices.Count) Autopilot devices in scope."
}
else {
    $autopilotScoped = $autopilotDevices
}

# --- Apply serial number exclusion (exact, case-insensitive) after the inclusion filters ---
if ($excludeSerialList.Count -gt 0) {
    $excludeSerialSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in $excludeSerialList) { [void]$excludeSerialSet.Add($s) }

    $beforeExcludeCount = @($autopilotScoped).Count
    $autopilotScoped = $autopilotScoped | Where-Object {
        $serial = if ($null -ne $_.serialNumber) { $_.serialNumber.Trim() } else { "" }
        -not $excludeSerialSet.Contains($serial)
    }
    $afterExcludeCount = @($autopilotScoped).Count
    $excludedCount = $beforeExcludeCount - $afterExcludeCount
    Write-RjRbLog -Message "Serial number exclusion applied: $excludedCount device(s) excluded; $afterExcludeCount remain in scope." -Verbose
    Write-Output "Serial number exclusion applied: $excludedCount device(s) excluded; $afterExcludeCount remain in scope."
}

# --- Classify cleanup candidates ---
# Two independent, mutually exclusive categories, separated by whether the device ever contacted Intune:
#   Orphaned      = HAS contacted Intune before, last contact older than $OrphanedLastContactedDays,
#                   and its serial is no longer present among Intune managed devices.
#   NeverEnrolled = NEVER contacted Intune (lastContactedDateTime = 0001-01-01) and aged beyond
#                   $NeverEnrolledAgeDays (measured from remediationStateLastModifiedDateTime).
$orphanedCutoff = (Get-Date).AddDays(-$OrphanedLastContactedDays)
$neverEnrolledCutoff = (Get-Date).AddDays(-$NeverEnrolledAgeDays)
$cleanupResults = [System.Collections.Generic.List[object]]::new()
$seenIds = [System.Collections.Generic.HashSet[string]]::new()

Write-Output ""
Write-Output "Classifying non-enrolled Autopilot devices (one detail lookup per device - this may take a while in large tenants)..."

foreach ($ap in $autopilotScoped) {
    # Actively enrolled devices are never cleanup candidates, regardless of serial match or age.
    if ($ap.enrollmentState -eq "enrolled") {
        continue
    }

    # IMPORTANT: the windowsAutopilotDeviceIdentities *collection* query returns lastContactedDateTime
    # (and some other computed fields) as empty/0001-01-01 even for devices that have contacted Intune.
    # Only a single-entity GET returns the accurate value. Refresh each non-enrolled device here so the
    # contact history is correct; otherwise a previously-enrolled (orphaned) device would be misread as
    # never-enrolled. This costs one Graph call per non-enrolled device.
    $apDetail = $ap
    try {
        $apDetail = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$($ap.id)" -Method GET -ErrorAction Stop
    }
    catch {
        Write-RjRbLog -Message "WARNING: Could not fetch full detail for Autopilot id $($ap.id); falling back to collection data (lastContactedDateTime may be inaccurate). Error: $($_.Exception.Message)" -NoDebugOnly
    }

    $serial = $apDetail.serialNumber

    # Determine contact history. A valid lastContactedDateTime (year > 1) means the device has
    # contacted Intune at least once. Never-contacted devices report 0001-01-01.
    $lastContact = $apDetail.lastContactedDateTime
    $lastContactDt = $null
    $lastContactDisplay = "Never"
    $hasContacted = $false
    if ($null -ne $lastContact -and "$lastContact" -ne "") {
        try {
            $lc = [DateTime]$lastContact
            if ($lc.Year -gt 1) {
                $lastContactDt = $lc
                $lastContactDisplay = $lc.ToString("yyyy-MM-dd HH:mm:ss")
                $hasContacted = $true
            }
        }
        catch {
            # Unparseable - treat as never contacted.
        }
    }

    # Orphaned: contacted before, contact is older than the threshold, serial gone from Intune.
    $serialMissingInIntune = (-not [string]::IsNullOrWhiteSpace($serial)) -and
        (-not $intuneSerialNumbers.Contains($serial.Trim()))
    $isOrphaned = $hasContacted -and $serialMissingInIntune -and ($lastContactDt -lt $orphanedCutoff)

    # Never-enrolled aging is measured from remediationStateLastModifiedDateTime, the only reliable
    # timestamp on a never-contacted Autopilot identity (lastContactedDateTime is 0001-01-01).
    # When no usable remediation timestamp exists (missing, 0001-01-01, or unparseable) the device
    # is treated as aged: a never-contacted record with no remediation activity is assumed stale.
    $remediationModified = $apDetail.remediationStateLastModifiedDateTime
    $remediationDisplay = "Unknown"
    $isAged = $true
    if ($null -ne $remediationModified -and "$remediationModified" -ne "") {
        try {
            $rm = [DateTime]$remediationModified
            if ($rm.Year -gt 1) {
                $remediationDisplay = $rm.ToString("yyyy-MM-dd HH:mm:ss")
                $isAged = $rm -lt $neverEnrolledCutoff
            }
        }
        catch {
            # Unparseable timestamp - leave $isAged = $true (treated as stale).
        }
    }
    $isNeverEnrolled = (-not $hasContacted) -and $isAged

    # Per-device decision trace (verbose). Enable verbose/debug logging on the runbook to see why a
    # specific device was or was not selected.
    Write-RjRbLog -Message ("Eval Autopilot id=$($ap.id) serial='$serial' state=$($apDetail.enrollmentState): " +
        "hasContacted=$hasContacted serialMissingInIntune=$serialMissingInIntune lastContact=$lastContactDisplay " +
        "remediation=$remediationDisplay isOrphaned=$isOrphaned isNeverEnrolled=$isNeverEnrolled") -Verbose

    $category = $null
    if ($CleanupNeverEnrolledDevices -and $isNeverEnrolled) {
        $category = "NeverEnrolled"
    }
    elseif ($CleanupOrphanedDevices -and $isOrphaned) {
        $category = "Orphaned"
    }

    if ($null -ne $category -and $seenIds.Add($ap.id)) {
        $cleanupResults.Add([PSCustomObject]@{
                SerialNumber          = $serial
                Model                 = $apDetail.model
                Manufacturer          = $apDetail.manufacturer
                GroupTag              = $apDetail.groupTag
                EnrollmentState       = $apDetail.enrollmentState
                LastContactedDateTime = $lastContactDisplay
                RemediationStateLastModified = $remediationDisplay
                AzureAdDeviceId       = $apDetail.azureActiveDirectoryDeviceId
                AutopilotId           = $ap.id
                Category              = $category
                Action                = if ($whatIfMode) { "WouldDelete" } else { "Pending" }
                EntraDeviceAction     = if (-not $deleteEntraDevice) { "Skipped (Autopilot only)" }
                                        elseif (-not (Test-ValidEntraDeviceId $apDetail.azureActiveDirectoryDeviceId)) { "No Entra device" }
                                        elseif ($whatIfMode) { "WouldDelete" }
                                        else { "Pending" }
            })
    }
}

$orphanedCount = ($cleanupResults | Where-Object { $_.Category -eq "Orphaned" }).Count
$neverEnrolledCount = ($cleanupResults | Where-Object { $_.Category -eq "NeverEnrolled" }).Count

Write-Output ""
Write-Output "Cleanup Candidates"
Write-Output "---------------------"
Write-Output "Orphaned (contacted >$OrphanedLastContactedDays day(s) ago, serial not in Intune): $orphanedCount"
Write-Output "Never-enrolled (never contacted, inactive >$NeverEnrolledAgeDays day(s)): $neverEnrolledCount"
Write-Output "Total candidates: $($cleanupResults.Count)"

foreach ($item in $cleanupResults) {
    Write-Output "  $($item.Category) | Serial: $($item.SerialNumber) | Model: $($item.Model) | Tag: $($item.GroupTag) | State: $($item.EnrollmentState) | LastContact: $($item.LastContactedDateTime)"
}

# --- Delete (or simulate) ---
$deletedCount = 0
$failedCount = 0
$wouldDeleteCount = 0
$entraDeletedCount = 0
$entraFailedCount = 0
$deleteFailedSerials = [System.Collections.Generic.List[string]]::new()

if ($cleanupResults.Count -gt 0) {
    if ($whatIfMode) {
        $wouldDeleteCount = $cleanupResults.Count
        Write-Output ""
        Write-Output "WhatIf mode is ENABLED - no devices were deleted. $wouldDeleteCount Autopilot identity/identities would be removed."
        if ($deleteEntraDevice) {
            $entraWouldDeleteCount = ($cleanupResults | Where-Object { $_.EntraDeviceAction -eq "WouldDelete" }).Count
            Write-Output "Of those, $entraWouldDeleteCount also have a matching Entra device that would be deleted."
        }
        Write-RjRbLog -Message "WhatIf mode enabled - $wouldDeleteCount Autopilot device(s) would be deleted." -Verbose
    }
    else {
        Write-Output ""
        Write-Output "Deleting $($cleanupResults.Count) Autopilot device identity/identities..."
        foreach ($candidate in $cleanupResults) {
            $deleteUri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$($candidate.AutopilotId)"
            try {
                Invoke-MgGraphRequest -Uri $deleteUri -Method DELETE -ErrorAction Stop
                $candidate.Action = "Deleted"
                $deletedCount++
                Write-RjRbLog -Message "Deleted Autopilot identity for serial '$($candidate.SerialNumber)' (ID: $($candidate.AutopilotId))." -Verbose
            }
            catch {
                $message = $_.Exception.Message
                if ($message -like "*404*" -or $message -like "*Not Found*") {
                    $candidate.Action = "Deleted"
                    $deletedCount++
                    Write-RjRbLog -Message "Autopilot identity for serial '$($candidate.SerialNumber)' was already deleted (404) - treated as removed." -Verbose
                }
                else {
                    $candidate.Action = "DeleteFailed"
                    $failedCount++
                    $deleteFailedSerials.Add($candidate.SerialNumber)
                    Write-RjRbLog -Message "WARNING: Failed to delete Autopilot identity for serial '$($candidate.SerialNumber)' (ID: $($candidate.AutopilotId)). Error: $message" -NoDebugOnly
                }
            }

            # When requested, also remove the matching Entra (Azure AD) device object. Once the
            # Autopilot identity is gone the Entra record can never re-enroll and is left behind as a
            # dead object, so it is cleaned up here. The Autopilot azureActiveDirectoryDeviceId is the
            # device's deviceId, not its directory object id, so the object id must be looked up first.
            if ($deleteEntraDevice -and (Test-ValidEntraDeviceId $candidate.AzureAdDeviceId)) {
                try {
                    $devLookup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$($candidate.AzureAdDeviceId)'&`$select=id,displayName" -Method GET -ErrorAction Stop
                    $devObj = $devLookup.value | Select-Object -First 1
                    if ($devObj -and $devObj.id) {
                        Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/devices/$($devObj.id)" -Method DELETE -ErrorAction Stop
                        $candidate.EntraDeviceAction = "Deleted"
                        $entraDeletedCount++
                        Write-RjRbLog -Message "Deleted Entra device object '$($devObj.id)' (deviceId $($candidate.AzureAdDeviceId)) for serial '$($candidate.SerialNumber)'." -Verbose
                    }
                    else {
                        $candidate.EntraDeviceAction = "No Entra device"
                        Write-RjRbLog -Message "No Entra device object found for deviceId $($candidate.AzureAdDeviceId) (serial '$($candidate.SerialNumber)') - nothing to delete." -Verbose
                    }
                }
                catch {
                    $emessage = $_.Exception.Message
                    if ($emessage -like "*404*" -or $emessage -like "*Not Found*") {
                        $candidate.EntraDeviceAction = "Deleted"
                        $entraDeletedCount++
                        Write-RjRbLog -Message "Entra device for deviceId $($candidate.AzureAdDeviceId) (serial '$($candidate.SerialNumber)') was already deleted (404) - treated as removed." -Verbose
                    }
                    else {
                        $candidate.EntraDeviceAction = "DeleteFailed"
                        $entraFailedCount++
                        Write-RjRbLog -Message "WARNING: Failed to delete Entra device for deviceId $($candidate.AzureAdDeviceId) (serial '$($candidate.SerialNumber)'). Error: $emessage" -NoDebugOnly
                    }
                }
            }

            Start-Sleep -Milliseconds 200
        }
        Write-Output "Deletion complete. Autopilot removed: $deletedCount. Autopilot failed: $failedCount."
        if ($deleteEntraDevice) {
            Write-Output "Entra devices removed: $entraDeletedCount. Entra failed: $entraFailedCount."
        }
        if ($failedCount -gt 0) {
            Write-RjRbLog -Message "WARNING: $failedCount Autopilot deletion(s) failed and require manual review. Failed serials: $($deleteFailedSerials -join ', ')." -NoDebugOnly
        }
        if ($entraFailedCount -gt 0) {
            Write-RjRbLog -Message "WARNING: $entraFailedCount Entra device deletion(s) failed and require manual review." -NoDebugOnly
        }
    }
}
else {
    Write-Output ""
    Write-Output "No Autopilot devices matched the cleanup criteria. Nothing to do."
}

# --- Reporting: CSV/XLSX export (only when needed for the email report and/or download link) ---
$tempDir = $null
$csvFilePath = $null
$xlsxFilePath = $null
$reportFiles = @()
if (($EmailTo -or $CreateDownloadLink) -and $cleanupResults.Count -gt 0) {
    $tempDir = Join-Path -Path $env:TEMP -ChildPath "AutopilotCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    if (-not (Test-Path -Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }
    $fileNameBase = "AutopilotCleanup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if ($ReportFileFormat -ne 'XLSX only') {
        $csvFilePath = Join-Path -Path $tempDir -ChildPath "$fileNameBase.csv"
        $cleanupResults | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvFilePath
        Write-RjRbLog -Message "Exported $($cleanupResults.Count) cleanup record(s) to $csvFilePath" -Verbose
    }
    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxFilePath = Join-Path -Path $tempDir -ChildPath "$fileNameBase.xlsx"
        $cleanupResults | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Autopilot Devices"
        $reportFiles += $xlsxFilePath
        Write-RjRbLog -Message "Exported $($cleanupResults.Count) cleanup record(s) to $xlsxFilePath" -Verbose
    }
}

# --- Upload / Download Link (optional) ---
if ($CreateDownloadLink) {
    Write-Output ""
    if ($reportFiles.Count -gt 0) {
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
    else {
        Write-Output "No Autopilot devices matched the cleanup criteria - skipping report upload."
    }
}

# Tenant display name for the report
$tenantDisplayName = "Unknown Tenant"
try {
    $orgInfo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method GET -ErrorAction Stop
    if ($orgInfo.value -and $orgInfo.value[0].displayName) {
        $tenantDisplayName = $orgInfo.value[0].displayName
    }
}
catch {
    Write-Warning "Failed to retrieve tenant display name: $($_.Exception.Message)"
}

$runMode = if ($whatIfMode) { "WhatIf (report only)" }
elseif ($deleteEntraDevice) { "Execution (Autopilot + Entra devices deleted)" }
else { "Execution (Autopilot devices deleted)" }

if ($CleanupNeverEnrolledDevices) {
$NeverEnrolledOut = "- Never-enrolled candidates (never contacted, inactive >$NeverEnrolledAgeDays day(s)): **$neverEnrolledCount**"
}

if ($CleanupOrphanedDevices) {
$OrphandNoSerialOut = "- Orphaned candidates (last contacted >$OrphanedLastContactedDays day(s) ago, serial not in Intune): **$orphanedCount**"
}

if ($deleteEntraDevice) {
    if ($whatIfMode) {
        $entraWouldDeleteCount = ($cleanupResults | Where-Object { $_.EntraDeviceAction -eq "WouldDelete" }).Count
        $EntraOut = "- Matching Entra device objects that would be deleted: **$entraWouldDeleteCount**"
    }
    else {
        $EntraOut = "- Entra device objects deleted: **$entraDeletedCount** (failed: **$entraFailedCount**)"
    }
}

$markdownContent = @"
# Autopilot Device Cleanup Report

**Tenant:** $tenantDisplayName
**Run mode:** $runMode
**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary

$OrphandNoSerialOut
$NeverEnrolledOut
- Total candidates: **$($cleanupResults.Count)**
- Autopilot identities deleted: **$deletedCount**
- Would delete (WhatIf): **$wouldDeleteCount**
- Failed: **$failedCount**
$EntraOut

The attached report file(s) list every candidate device with its category and the action taken.

---

*This email was automatically generated. Please do not reply to this email.*
"@

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Tenant: $tenantDisplayName"
Write-Output "Run mode: $runMode"
Write-Output "Orphaned candidates: $orphanedCount"
Write-Output "Never-enrolled candidates: $neverEnrolledCount"
Write-Output "Deleted: $deletedCount | Would delete: $wouldDeleteCount | Failed: $failedCount"
if ($deleteEntraDevice) {
    Write-Output "Entra devices deleted: $entraDeletedCount | Entra failed: $entraFailedCount"
}

if ($sendEmail -and $reportFiles.Count -gt 0) {
    $subject = "Autopilot Cleanup - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"

    $markdownFallback = @"
# Autopilot Device Cleanup Report

**Tenant:** $tenantDisplayName
**Run mode:** $runMode
**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary

- Total candidates: **$($cleanupResults.Count)**

- **$($fileNameBase).xlsx**: Formatted Excel workbook with the complete candidate list

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
    try {
        $guardParams = @{
            EmailFrom         = $EmailFrom
            EmailTo           = $EmailTo
            Subject           = $subject
            MarkdownContent   = $markdownContent
            TenantDisplayName = $tenantDisplayName
            ReportVersion     = $Version
        }
        if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFilePath) {
            Send-RjRbGuardedReportEmail @guardParams -Attachments $reportFiles -FallbackAttachments @($xlsxFilePath) -FallbackMarkdownContent $markdownFallback
        }
        else {
            Send-RjRbGuardedReportEmail @guardParams -Attachments $reportFiles
        }
        Write-RjRbLog -Message "Cleanup report email sent to '$EmailTo'." -Verbose
    }
    catch {
        Write-Error "Failed to send cleanup report email: $($_.Exception.Message)" -ErrorAction Continue
        Write-RjRbLog -Message "WARNING: Cleanup report email could not be sent to '$EmailTo'. The cleanup itself completed; review the error above." -NoDebugOnly
    }
}
elseif ($sendEmail -and $cleanupResults.Count -eq 0) {
    Write-Output "Email requested but there are no candidate devices - no report email sent."
}

#endregion

########################################################
#region     Cleanup
########################################################

# Remove the temporary report exports, if any were created.
foreach ($reportFilePath in $reportFiles) {
    if ($reportFilePath -and (Test-Path -Path $reportFilePath)) {
        Remove-Item -Path $reportFilePath -Force -ErrorAction SilentlyContinue
    }
}
if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Disconnect Microsoft Graph (tolerate an already-disconnected session).
try {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}
catch {
    # Already disconnected - nothing to do.
}

Write-Output "Done!"

#endregion

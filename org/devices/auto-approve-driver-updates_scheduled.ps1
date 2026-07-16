<#
	.SYNOPSIS
	Auto-approve new driver updates in Intune driver update policies

	.DESCRIPTION
	This scheduled runbook automatically approves pending driver updates in one or more Intune driver update policies. It can filter driver updates by display name pattern, driver class, or manufacturer. Optional email notifications can be sent after approval operations complete.
	The notification email includes CSV and/or Excel (xlsx) report files listing every driver approval action (policy, driver, version, manufacturer, driver class, release date and outcome).
	The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
	The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
	When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

	.NOTES
	Prerequisites:
	- Microsoft Graph BETA API access (driver update endpoints are in beta)
	- RJReport.EmailSender setting configured (if email notifications are used)

	Common Use Cases:
	- Test filters first: Use WhatIf parameter to preview which drivers would be approved
	- Auto-approve all drivers: Run without any filter parameters
	- Approve specific manufacturers: Use DriverManufacturer to target vendors like "Intel" or "AMD"
	- Target specific policies: Use PolicyNames or PolicyIds to scope to test policies first
	- Monitor approvals: Configure EmailTo to receive detailed reports after each run

	Parameter Interactions:
	- If no policy filter is specified, ALL driver update policies are processed
	- If no driver filter is specified, ALL pending drivers in selected policies are approved
	- PolicyNames and PolicyIds can be combined - both filters apply independently
	- Email notifications require RJReport.EmailSender setting and Connect-RjRbGraph
	- WhatIf mode simulates approvals without making changes - useful for testing filters

	.PARAMETER PolicyNames
	(Optional) Comma-separated list of driver update policy names to scope the approval (e.g., "Policy1, Policy2, Policy3"). If not specified, all policies are processed.

	.PARAMETER PolicyIds
	(Optional) Comma-separated list of driver update policy IDs to scope the approval (e.g., "id1, id2, id3"). If not specified, all policies are processed.

	.PARAMETER DriverDisplayNamePattern
	(Optional) Filter driver updates by display name pattern (supports wildcards). Only matching drivers will be approved.

	.PARAMETER DriverClass
	(Optional) Filter by driver class IDs (comma-separated). Example: "Bluetooth,Networking,Firmware" for specific driver classes.

	.PARAMETER DriverManufacturer
	(Optional) Filter by driver manufacturer name. Only drivers from the specified manufacturer will be approved.

	.PARAMETER MaximumDriverAge
	(Optional) Maximum age in days for drivers to be approved. Only drivers released within the last X days will be approved. Example: 30 to only approve drivers released in the last 30 days.

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

	.PARAMETER EmailFrom
	Sender email address for notifications. This parameter is backed by a setting and should not be modified directly.

	.PARAMETER EmailTo
	(Optional) Recipient email address for approval notifications. If not specified, no email is sent.

	.PARAMETER OnlyNeedsReview
	When enabled (default), only drivers with status "needsReview" are approved. Drivers with status "suspended" or "declined" are skipped. Disable to also re-approve suspended or declined drivers.

	.PARAMETER WhatIf
	(Optional) When enabled, simulates driver approvals without making actual changes. Shows which drivers would be approved and sends a report to EmailTo if configured.

	.PARAMETER CallerName
	Name of the user or system initiating the runbook. Used for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"PolicyNames": {
				"DisplayName": "Driver Update Policy Names",
				"Description": "(Optional) Comma-separated policy names to process (e.g., 'Policy1, Policy2'), leave empty for all policies"
			},
			"PolicyIds": {
				"DisplayName": "Driver Update Policy IDs",
				"Description": "(Optional) Comma-separated policy IDs to process (e.g., 'id1, id2'), leave empty for all policies"
			},
			"DriverDisplayNamePattern": {
				"DisplayName": "Driver Name Filter",
				"Description": "(Optional) Filter drivers by display name (supports wildcards)"
			},
			"DriverClass": {
				"DisplayName": "Driver Class Filter",
				"Description": "(Optional) Comma-separated driver class IDs (e.g., 'Bluetooth,Networking,Firmware')"
			},
			"DriverManufacturer": {
				"DisplayName": "Manufacturer Filter",
				"Description": "(Optional) Filter drivers by manufacturer name"
			},
			"MaximumDriverAge": {
				"DisplayName": "Maximum Driver Age (Days)",
				"Description": "(Optional) Only approve drivers released within the last X days (e.g., 30 = only drivers from the last 30 days)"
			},
			"EmailTo": {
				"DisplayName": "Notification Recipient",
				"Description": "(Optional) Email address to receive approval notifications"
			},
			"OnlyNeedsReview": {
				"DisplayName": "Only approve 'Needs Review' drivers",
				"Description": "When enabled (default), skip suspended and declined drivers - only approve drivers in 'needsReview' status"
			},
			"WhatIf": {
				"DisplayName": "What-If Mode (Dry Run)",
				"Description": "(Optional) Simulate approvals without making changes - useful for testing filters"
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
			},
			"EmailFrom": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.38.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param(
    [Parameter(Mandatory = $false)]
    [string]$PolicyNames,
    [Parameter(Mandatory = $false)]
    [string]$PolicyIds,
    [Parameter(Mandatory = $false)]
    [string]$DriverDisplayNamePattern,
    [Parameter(Mandatory = $false)]
    [string]$DriverClass,
    [Parameter(Mandatory = $false)]
    [string]$DriverManufacturer,
    [Parameter(Mandatory = $false)]
    [int]$MaximumDriverAge,
    [Parameter(Mandatory = $false)]
    [bool]$OnlyNeedsReview = $true,
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',
    [Parameter(Mandatory = $false)]
    [bool]$CreateDownloadLink = $false,
    [Parameter(Mandatory = $false)]
    [string]$ContainerName = "auto-approve-driver-updates",
    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ })]
    [string]$ResourceGroupName,
    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ })]
    [string]$StorageAccountName,
    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ })]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,
    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ })]
    [string]$EmailFrom,
    [Parameter(Mandatory = $false)]
    [string]$EmailTo,

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

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "PolicyNames: $PolicyNames" -Verbose
Write-RjRbLog -Message "PolicyIds: $PolicyIds" -Verbose
Write-RjRbLog -Message "DriverDisplayNamePattern: $DriverDisplayNamePattern" -Verbose
Write-RjRbLog -Message "DriverClass: $DriverClass" -Verbose
Write-RjRbLog -Message "DriverManufacturer: $DriverManufacturer" -Verbose
Write-RjRbLog -Message "MaximumDriverAge: $MaximumDriverAge" -Verbose
Write-RjRbLog -Message "OnlyNeedsReview: $OnlyNeedsReview" -Verbose
Write-RjRbLog -Message "WhatIf: $WhatIf" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
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

# Convert comma-separated strings to arrays (use separate variables to avoid typed-param coercion)
$PolicyNameList = @()
if ($PolicyNames) {
    $PolicyNameList = @($PolicyNames -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    Write-RjRbLog -Message "PolicyNames converted: $($PolicyNameList -join ', ')" -Verbose
}

$PolicyIdList = @()
if ($PolicyIds) {
    $PolicyIdList = @($PolicyIds -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    Write-RjRbLog -Message "PolicyIds converted: $($PolicyIdList -join ', ')" -Verbose
}

# Validate that at least one policy selection method is provided
if ($PolicyNameList.Count -eq 0 -and $PolicyIdList.Count -eq 0) {
    Write-RjRbLog -Message "No policy filter specified - will process all driver update policies" -Verbose
}

# Validate driver filter criteria
if (-not $DriverDisplayNamePattern -and -not $DriverClass -and -not $DriverManufacturer -and -not $MaximumDriverAge) {
    Write-RjRbLog -Message "WARNING: No driver filter specified - will approve ALL pending drivers in selected policies" -Verbose
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

Write-RjRbLog -Message "Connecting to Microsoft Graph using Managed Identity..." -Verbose

try {
    Connect-MgGraph -Identity -NoWelcome
    Write-RjRbLog -Message "Successfully connected to Microsoft Graph" -Verbose
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $_" -ErrorAction Continue
    throw
}

# Connect to RealmJoin RunbookHelper (required for Send-RjReportEmail if EmailTo is provided)
if ($EmailTo) {
    Write-RjRbLog -Message "Email notification requested - connecting to RJ RunbookHelper Graph..." -Verbose
    try {
        Connect-RjRbGraph
        Write-RjRbLog -Message "Successfully connected to RJ RunbookHelper Graph" -Verbose
    }
    catch {
        Write-Error "Failed to connect to RJ RunbookHelper Graph: $_" -ErrorAction Continue
        throw
    }
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get Driver Update Policies"
Write-Output "---------------------"

# Retrieve all driver update policies
Write-RjRbLog -Message "Retrieving Windows Driver Update Profiles from Intune..." -Verbose

try {
    $uri = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles"
    $allPolicies = @()

    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $allPolicies += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)

    Write-RjRbLog -Message "Retrieved $($allPolicies.Count) driver update policy/policies" -Verbose
}
catch {
    Write-Error "Failed to retrieve driver update policies: $_" -ErrorAction Continue
    throw
}

# Filter policies based on PolicyNames or PolicyIds if provided
$targetPolicies = $allPolicies

if ($PolicyIdList.Count -gt 0) {
    Write-RjRbLog -Message "Filtering by Policy IDs: $($PolicyIdList -join ', ')" -Verbose
    $targetPolicies = $targetPolicies | Where-Object { $PolicyIdList -contains $_.id }
}

if ($PolicyNameList.Count -gt 0) {
    Write-RjRbLog -Message "Filtering by Policy Names: $($PolicyNameList -join ', ')" -Verbose
    $targetPolicies = $targetPolicies | Where-Object { $PolicyNameList -contains $_.displayName }
}

if ($targetPolicies.Count -eq 0) {
    Write-Error "No driver update policies found matching the specified criteria." -ErrorAction Continue
    throw "No policies found to process"
}

Write-Output "Processing $($targetPolicies.Count) driver update policy/policies:"
foreach ($policy in $targetPolicies) {
    Write-Output "  - $($policy.displayName) (ID: $($policy.id))"
}

#endregion

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Process Driver Updates"
Write-Output "---------------------"

if ($WhatIf) {
    Write-Output ""
    Write-Output "*** WHAT-IF MODE ENABLED ***"
    Write-Output "No actual approvals will be made. This is a simulation only."
    Write-Output ""
    Write-RjRbLog -Message "Running in WhatIf mode - no approvals will be performed" -Verbose
}

$approvalSummary = @{
    TotalPoliciesProcessed = 0
    TotalDriversReviewed = 0
    TotalDriversApproved = 0
    FailedApprovals = 0
    Details = @()
}

# Detailed per-driver report rows (used for the CSV/XLSX report files)
$driverReportRows = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($policy in $targetPolicies) {
    Write-Output ""
    Write-Output "Processing policy: $($policy.displayName)"
    $approvalSummary.TotalPoliciesProcessed++

    $policyDetails = @{
        PolicyName = $policy.displayName
        PolicyId = $policy.id
        DriversReviewed = 0
        DriversApproved = 0
        ApprovedDrivers = @()
    }

    # Get driver updates for this policy
    try {
        $driversUri = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$($policy.id)/driverInventories"
        $allDrivers = @()

        do {
            $driverResponse = Invoke-MgGraphRequest -Method GET -Uri $driversUri
            if ($driverResponse.value) {
                $allDrivers += $driverResponse.value
            }
            $driversUri = $driverResponse.'@odata.nextLink'
        } while ($driversUri)

        Write-RjRbLog -Message "Found $($allDrivers.Count) driver(s) in policy '$($policy.displayName)'" -Verbose
        $policyDetails.DriversReviewed = $allDrivers.Count
        $approvalSummary.TotalDriversReviewed += $allDrivers.Count

        # Filter drivers based on criteria
        $driversToApprove = $allDrivers

        # Filter by display name pattern
        if ($DriverDisplayNamePattern) {
            Write-RjRbLog -Message "Filtering by display name pattern: $DriverDisplayNamePattern" -Verbose
            $driversToApprove = $driversToApprove | Where-Object { $_.name -like $DriverDisplayNamePattern }
        }

        # Filter by driver class
        if ($DriverClass) {
            $classIds = $DriverClass -split ',' | ForEach-Object { $_.Trim() }
            Write-RjRbLog -Message "Filtering by driver class IDs: $($classIds -join ', ')" -Verbose
            $driversToApprove = $driversToApprove | Where-Object { $classIds -contains $_.driverClass }
        }

        # Filter by manufacturer
        if ($DriverManufacturer) {
            Write-RjRbLog -Message "Filtering by manufacturer: $DriverManufacturer" -Verbose
            $driversToApprove = $driversToApprove | Where-Object { $_.manufacturer -like $DriverManufacturer }
        }

        # Filter by maximum driver age (release date)
        if ($MaximumDriverAge) {
            $cutoffDate = (Get-Date).AddDays(-$MaximumDriverAge)
            Write-RjRbLog -Message "Filtering by maximum driver age: $MaximumDriverAge days (released after $(Get-Date $cutoffDate -Format 'yyyy-MM-dd'))" -Verbose
            $driversToApprove = $driversToApprove | Where-Object {
                $releaseDate = $null
                if ($_.releaseDateTime) {
                    $releaseDate = [DateTime]::Parse($_.releaseDateTime)
                }
                $releaseDate -and $releaseDate -ge $cutoffDate
            }
        }

        # Filter drivers by approval status
        if ($OnlyNeedsReview) {
            $driversNeedingApproval = $driversToApprove | Where-Object { $_.approvalStatus -eq 'needsReview' }
            $skippedCount = $driversToApprove.Count - $driversNeedingApproval.Count
        }
        else {
            $driversNeedingApproval = $driversToApprove | Where-Object { $_.approvalStatus -ne 'approved' }
            $skippedCount = $driversToApprove.Count - $driversNeedingApproval.Count
        }

        Write-Output "  Drivers matching filter criteria: $($driversToApprove.Count)"
        if ($skippedCount -gt 0) {
            if ($OnlyNeedsReview) {
                Write-Output "  Skipped (not in 'needsReview' status - suspended/declined/approved): $skippedCount"
            }
            else {
                Write-Output "  Already approved (will skip): $skippedCount"
            }
            Write-Output "  Drivers to approve: $($driversNeedingApproval.Count)"
        }

        if ($driversNeedingApproval.Count -eq 0) {
            Write-Output "  No drivers to approve in this policy."
        }
        elseif ($WhatIf) {
            foreach ($driver in $driversNeedingApproval) {
                Write-Output "    [WHATIF] Would approve: $($driver.name) (v$($driver.version)) - $($driver.manufacturer)"
                Write-RjRbLog -Message "[WhatIf] Would approve driver: $($driver.name) (ID: $($driver.id))" -Verbose
                $policyDetails.DriversApproved++
                $policyDetails.ApprovedDrivers += $driver.name
                $approvalSummary.TotalDriversApproved++
                $driverReportRows.Add([PSCustomObject]@{
                    Policy       = $policy.displayName
                    DriverName   = $driver.name
                    Version      = $driver.version
                    Manufacturer = $driver.manufacturer
                    DriverClass  = $driver.driverClass
                    ReleaseDate  = $driver.releaseDateTime
                    Action       = "Would approve"
                })
            }
        }
        else {
            # Approve all matching drivers in a single bulk call
            try {
                $approvalUri = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$($policy.id)/ExecuteAction"
                $approvalBody = @{
                    actionName     = "approve"
                    driverIds      = @($driversNeedingApproval | Select-Object -ExpandProperty id)
                    deploymentDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                } | ConvertTo-Json

                $result = Invoke-MgGraphRequest -Method POST -Uri $approvalUri -Body $approvalBody -ContentType "application/json"

                $succeeded = @($result.successfulDriverIds)
                $failed    = @($result.failedDriverIds)
                $notFound  = @($result.notFoundDriverIds)

                foreach ($driver in $driversNeedingApproval) {
                    if ($succeeded -contains $driver.id) {
                        Write-Output "    [OK] Approved: $($driver.name) (v$($driver.version)) - $($driver.manufacturer)"
                        Write-RjRbLog -Message "Approved driver: $($driver.name) (ID: $($driver.id))" -Verbose
                        $policyDetails.DriversApproved++
                        $policyDetails.ApprovedDrivers += $driver.name
                        $approvalSummary.TotalDriversApproved++
                        $driverReportRows.Add([PSCustomObject]@{
                            Policy       = $policy.displayName
                            DriverName   = $driver.name
                            Version      = $driver.version
                            Manufacturer = $driver.manufacturer
                            DriverClass  = $driver.driverClass
                            ReleaseDate  = $driver.releaseDateTime
                            Action       = "Approved"
                        })
                    }
                    elseif ($failed -contains $driver.id) {
                        Write-Warning "    [FAIL] Failed to approve: $($driver.name) (ID: $($driver.id))"
                        $approvalSummary.FailedApprovals++
                        $driverReportRows.Add([PSCustomObject]@{
                            Policy       = $policy.displayName
                            DriverName   = $driver.name
                            Version      = $driver.version
                            Manufacturer = $driver.manufacturer
                            DriverClass  = $driver.driverClass
                            ReleaseDate  = $driver.releaseDateTime
                            Action       = "Failed"
                        })
                    }
                    elseif ($notFound -contains $driver.id) {
                        Write-Warning "    [NOTFOUND] Driver not found during approval: $($driver.name) (ID: $($driver.id))"
                        $approvalSummary.FailedApprovals++
                        $driverReportRows.Add([PSCustomObject]@{
                            Policy       = $policy.displayName
                            DriverName   = $driver.name
                            Version      = $driver.version
                            Manufacturer = $driver.manufacturer
                            DriverClass  = $driver.driverClass
                            ReleaseDate  = $driver.releaseDateTime
                            Action       = "Not found"
                        })
                    }
                }
            }
            catch {
                Write-Warning "Failed to approve drivers for policy '$($policy.displayName)': $_"
                Write-RjRbLog -Message "Failed to approve drivers for policy '$($policy.displayName)': $_" -Verbose
                $approvalSummary.FailedApprovals += $driversNeedingApproval.Count
                foreach ($driver in $driversNeedingApproval) {
                    $driverReportRows.Add([PSCustomObject]@{
                        Policy       = $policy.displayName
                        DriverName   = $driver.name
                        Version      = $driver.version
                        Manufacturer = $driver.manufacturer
                        DriverClass  = $driver.driverClass
                        ReleaseDate  = $driver.releaseDateTime
                        Action       = "Failed"
                    })
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to process policy '$($policy.displayName)': $_"
        Write-RjRbLog -Message "Failed to process policy '$($policy.displayName)': $_" -Verbose
    }

    $approvalSummary.Details += $policyDetails
}

Write-Output ""
Write-Output "Approval Summary"
Write-Output "---------------------"
if ($WhatIf) {
    Write-Output "Mode: WHAT-IF (Simulation - No actual changes made)"
}
Write-Output "Policies processed: $($approvalSummary.TotalPoliciesProcessed)"
Write-Output "Total drivers reviewed: $($approvalSummary.TotalDriversReviewed)"
if ($WhatIf) {
    Write-Output "Total drivers that would be approved: $($approvalSummary.TotalDriversApproved)"
}
else {
    Write-Output "Total drivers approved: $($approvalSummary.TotalDriversApproved)"
}
if ($approvalSummary.FailedApprovals -gt 0) {
    Write-Output "Failed approvals: $($approvalSummary.FailedApprovals)"
}

#endregion

########################################################
#region     Report File Export (if needed for download link or email)
########################################################

$reportFiles = @()
$xlsxPath = $null
$tempDir = $null
$fileName_Details = "driver-approvals.csv"
$fileName_DetailsXlsx = "driver-approvals.xlsx"

if (($EmailTo -or $CreateDownloadLink) -and $driverReportRows.Count -gt 0) {
    $tempDir = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "DriverApprovals_$(Get-Date -Format 'yyyyMMdd_HHmmss')"))

    if ($ReportFileFormat -ne 'XLSX only') {
        $csvPath = Join-Path $tempDir.FullName $fileName_Details
        $driverReportRows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        $reportFiles += $csvPath
        Write-Output "Exported driver approval report to: $csvPath"
    }

    if ($ReportFileFormat -ne 'CSV only') {
        $xlsxPath = Join-Path $tempDir.FullName $fileName_DetailsXlsx
        $driverReportRows | Export-RjRbXlsx -Path $xlsxPath -WorksheetName "Driver Approvals"
        $reportFiles += $xlsxPath
        Write-Output "Exported driver approval report to: $xlsxPath"
    }
}

#endregion

########################################################
#region     Upload / Download Link (if CreateDownloadLink is enabled)
########################################################

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
        Write-Output "No driver approval actions were recorded - skipping report upload."
    }
}

#endregion

########################################################
#region     Email Notification (if EmailTo is provided)
########################################################

# Send email notification if configured
if ($EmailTo) {
    Write-Output ""
    Write-Output "Sending Email Notification"
    Write-Output "---------------------"

    try {
        $tenantDisplayName = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization").value[0].displayName

        # Build email content
        if ($WhatIf) {
            $emailSubject = "Intune Driver Update Auto-Approval Report [WHAT-IF] - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"
        }
        else {
            $emailSubject = "Intune Driver Update Auto-Approval Report - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"
        }

        $emailBody = @"
# Driver Update Auto-Approval Report$(if ($WhatIf) { " [WHAT-IF MODE]" })

**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Tenant:** $tenantDisplayName
$(if ($WhatIf) { "**Mode:** WHAT-IF (Simulation - No actual changes were made)" })

## Summary

- **Policies Processed:** $($approvalSummary.TotalPoliciesProcessed)
- **Drivers Reviewed:** $($approvalSummary.TotalDriversReviewed)
- **Drivers $(if ($WhatIf) { "That Would Be " })Approved:**$($approvalSummary.TotalDriversApproved)
$(if ($approvalSummary.FailedApprovals -gt 0) { "- **Failed Approvals:** $($approvalSummary.FailedApprovals)" })

## Policy Details

"@

        foreach ($detail in $approvalSummary.Details) {
            $emailBody += @"

### $($detail.PolicyName)

- **Drivers Reviewed:** $($detail.DriversReviewed)
- **Drivers $(if ($WhatIf) { "That Would Be " })Approved:** $($detail.DriversApproved)

"@
            if ($detail.ApprovedDrivers.Count -gt 0) {
                if ($WhatIf) {
                    $emailBody += "`n**Drivers That Would Be Approved:**`n"
                }
                else {
                    $emailBody += "`n**Approved Drivers:**`n"
                }
                # Cap the per-policy driver list to keep the email readable - the full list is in the attached report
                $maxListedDrivers = 15
                foreach ($driverName in ($detail.ApprovedDrivers | Select-Object -First $maxListedDrivers)) {
                    $emailBody += "- $driverName`n"
                }
                if ($detail.ApprovedDrivers.Count -gt $maxListedDrivers -and $reportFiles.Count -gt 0) {
                    $emailBody += "- ... and $($detail.ApprovedDrivers.Count - $maxListedDrivers) more (see attached report)`n"
                }
            }
        }

        $emailBody += @"

## Filters Applied

$(if ($PolicyNameList.Count -gt 0) { "- **Policy Names:** $($PolicyNameList -join ', ')" })
$(if ($PolicyIdList.Count -gt 0) { "- **Policy IDs:** $($PolicyIdList -join ', ')" })
$(if ($DriverDisplayNamePattern) { "- **Driver Name Pattern:** $DriverDisplayNamePattern" })
$(if ($DriverClass) { "- **Driver Class:** $DriverClass" })
$(if ($DriverManufacturer) { "- **Manufacturer:** $DriverManufacturer" })
$(if ($MaximumDriverAge) { "- **Maximum Driver Age:** $MaximumDriverAge days" })
"@

        if ($reportFiles.Count -gt 0) {
            $emailBody += @"


## Report Files

The following file(s) are attached to this email:

$(if ($ReportFileFormat -ne 'XLSX only') { "- **$($fileName_Details)**: Complete list of all driver approval actions (CSV)" })
$(if ($ReportFileFormat -ne 'CSV only') { "- **$($fileName_DetailsXlsx)**: The same list as a formatted Excel workbook" })
"@
        }

        $emailBody += @"


---

*This email was automatically generated. Please do not reply to this email.*
"@

        # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
        if ($reportFiles.Count -gt 0) {
            $markdownFallback = @"
# Driver Update Auto-Approval Report$(if ($WhatIf) { " [WHAT-IF MODE]" })

**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Tenant:** $tenantDisplayName
$(if ($WhatIf) { "**Mode:** WHAT-IF (Simulation - No actual changes were made)" })

## Summary

- **Policies Processed:** $($approvalSummary.TotalPoliciesProcessed)
- **Drivers Reviewed:** $($approvalSummary.TotalDriversReviewed)
- **Drivers $(if ($WhatIf) { "That Would Be " })Approved:** $($approvalSummary.TotalDriversApproved)
$(if ($approvalSummary.FailedApprovals -gt 0) { "- **Failed Approvals:** $($approvalSummary.FailedApprovals)" })

## Report Files

- **$($fileName_DetailsXlsx)**: Formatted Excel workbook with the complete list of driver approval actions

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

            $guardParams = @{
                EmailFrom         = $EmailFrom
                EmailTo           = $EmailTo
                Subject           = $emailSubject
                MarkdownContent   = $emailBody
                TenantDisplayName = $tenantDisplayName
                ReportVersion     = $Version
            }
            if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxPath) {
                Send-RjRbGuardedReportEmail @guardParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjRbGuardedReportEmail @guardParams -Attachments $reportFiles
            }
        }
        else {
            Send-RjReportEmail `
                -EmailFrom $EmailFrom `
                -EmailTo $EmailTo `
                -Subject $emailSubject `
                -MarkdownContent $emailBody `
                -TenantDisplayName $tenantDisplayName `
                -ReportVersion $Version

            Write-Output "Email notification sent to: $EmailTo"
        }
        Write-RjRbLog -Message "Email notification sent successfully to: $EmailTo" -Verbose
    }
    catch {
        Write-Warning "Failed to send email notification: $_"
        Write-RjRbLog -Message "Failed to send email notification: $_" -Verbose
    }
}

#endregion

########################################################
#region     Cleanup
########################################################

# Cleanup temporary report files
if ($tempDir -and (Test-Path $tempDir.FullName)) {
    Remove-Item -Path $tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Write-RjRbLog -Message "Cleaned up temporary report files" -Verbose
}

Write-RjRbLog -Message "Disconnecting from Microsoft Graph..." -Verbose
Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
Write-RjRbLog -Message "Successfully disconnected from Microsoft Graph" -Verbose

Write-Output ""
Write-Output "Done!"

#endregion
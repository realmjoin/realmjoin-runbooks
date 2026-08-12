<#
	.SYNOPSIS
	Compare primary user assignments in Intune against RealmJoin for Windows managed devices

	.DESCRIPTION
	For Windows managed devices, this scheduled report compares the primary user recorded in Intune against the primary user recorded in the RealmJoin customer API. It correlates the two datasets per device, flags any device where the primary user differs, and emails the differences with CSV and/or Excel (xlsx) attachments.
	The report files can also be uploaded to an Azure Storage Account, returning time-limited download links.
	The ReportFileFormat parameter controls which file formats are generated and delivered (CSV only, CSV & XLSX, or XLSX only).
	When the CSV attachment exceeds the email size limit and "CSV & XLSX" is selected, the email falls back to the Excel workbook alone.

	.NOTES
	Prerequisites:
	- An Azure Automation Account shared credential named exactly "RJAPI" must be created manually
	  before scheduling. Set the username and password to match a RealmJoin customer API account
	  (see https://docs.realmjoin.com/dev-reference/realmjoin-api/authentication).
	- The Automation Account managed identity must have the following Graph application permissions
	  assigned: DeviceManagementManagedDevices.Read.All, Mail.Send, Organization.Read.All.
	- The RJReport.EmailSender setting must be configured with a valid sender address before the first run.
	- No email is sent when the two datasets are in sync; an empty run is not an error.

	.PARAMETER SyncThresholdDays
	Number of days to look back for the Intune last-sync filter. Only Windows devices that have synced within this many days are evaluated.

	.PARAMETER DeviceNamePrefix
	Optional device name prefix to filter the report to a specific subset of devices. Leave blank to include all devices.

	.PARAMETER IncludeMismatches
	Include devices whose primary user differs between Intune and RealmJoin in the report. Enabled by default.

	.PARAMETER IncludeMissingInRealmJoin
	Include devices that exist in Intune but have no matching device in RealmJoin in the report. Disabled by default.

	.PARAMETER IncludeMissingInIntune
	Include devices that exist in RealmJoin but have no matching Intune device in the report. Disabled by default.

	.PARAMETER IncludePrimaryUserDeleted
	Include devices whose Intune primary user has been deleted from Entra ID in the report. Intune mangles the user principal name of a deleted user by prefixing its object id, which would otherwise show up as a false Mismatch. Enabled by default.

	.PARAMETER EmailTo
	If specified, an email with the report will be sent to the provided address(es). Can be a single address or multiple comma-separated addresses.

	.PARAMETER EmailFrom
	The sender email address. This is configured via the runbook customization setting and hidden in the portal.

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

	.PARAMETER UseDeviceScope
	Enable device scope filtering to include or exclude devices based on Entra device group membership.

	.PARAMETER IncludeDeviceGroup
	Only include devices that are members of this Entra device group in the report. Requires device scope filtering to be enabled.

	.PARAMETER ExcludeDeviceGroup
	Exclude devices that are members of this Entra device group from the report. Requires device scope filtering to be enabled.

	.PARAMETER CallerName
	Caller name for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"SyncThresholdDays": {
				"DisplayName": "Intune Last Sync (days)"
			},
			"DeviceNamePrefix": {
				"DisplayName": "Device Name Prefix (optional)"
			},
			"IncludeMismatches": {
				"DisplayName": "Include Mismatches",
                "Hide": true
			},
			"IncludeMissingInRealmJoin": {
				"DisplayName": "Include Missing in RealmJoin",
                "Hide": true
			},
			"IncludeMissingInIntune": {
				"DisplayName": "Include Missing in Intune",
                "Hide": true
			},
			"IncludePrimaryUserDeleted": {
				"DisplayName": "Include Deleted Primary Users",
                "Hide": true
			},
			"UseDeviceScope": {
				"DisplayName": "Use Device Scope Filtering",
				"Hide": true
			},
			"IncludeDeviceGroup": {
				"DisplayName": "Devices to include (Group)",
				"Hide": true
			},
			"ExcludeDeviceGroup": {
				"DisplayName": "Devices to exclude (Group)",
				"Hide": true
			},
            "EmailTo": {
				"DisplayName": "Send Report To"
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
		},
		"ParameterList": [
			{
				"DisplayName": "(Optional) Enable device scope filtering to include or exclude devices based on Entra device group membership.",
				"DisplayAfter": "IncludePrimaryUserDeleted",
				"Select": {
					"Options": [
						{
							"Display": "Yes - filter by device group membership",
							"Customization": {
								"Hide": [],
								"Show": ["IncludeDeviceGroup", "ExcludeDeviceGroup"],
								"Default": {
									"UseDeviceScope": true
								}
							}
						},
						{
							"Display": "No - include all devices",
							"Customization": {
								"Hide": ["IncludeDeviceGroup", "ExcludeDeviceGroup"],
								"Default": {
									"UseDeviceScope": false
								}
							},
							"ParameterValue": false
						}
					]
				}
			}
		]
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.8" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param (
    [int]$SyncThresholdDays = 30,

    [string]$DeviceNamePrefix = "",

    [bool]$IncludeMismatches = $true,

    [bool]$IncludeMissingInRealmJoin = $false,

    [bool]$IncludeMissingInIntune = $false,

    [bool]$IncludePrimaryUserDeleted = $false,

    [bool]$UseDeviceScope = $false,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Include Devices from Group" } )]
    [string]$IncludeDeviceGroup,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclude Devices from Group" } )]
    [string]$ExcludeDeviceGroup,

    [Parameter(Mandatory = $false)]
    [string]$EmailTo,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ })]
    [string]$EmailFrom,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string]$ReportFileFormat = 'CSV & XLSX',

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "report-primary-user-mismatch",

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

$Version = "1.5.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "SyncThresholdDays: $SyncThresholdDays" -Verbose
Write-RjRbLog -Message "DeviceNamePrefix: $DeviceNamePrefix" -Verbose
Write-RjRbLog -Message "IncludeMismatches: $IncludeMismatches" -Verbose
Write-RjRbLog -Message "IncludeMissingInRealmJoin: $IncludeMissingInRealmJoin" -Verbose
Write-RjRbLog -Message "IncludeMissingInIntune: $IncludeMissingInIntune" -Verbose
Write-RjRbLog -Message "IncludePrimaryUserDeleted: $IncludePrimaryUserDeleted" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "UseDeviceScope: $UseDeviceScope" -Verbose
Write-RjRbLog -Message "IncludeDeviceGroup: $IncludeDeviceGroup" -Verbose
Write-RjRbLog -Message "ExcludeDeviceGroup: $ExcludeDeviceGroup" -Verbose
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

Write-Output ""
Write-Output "Parameter Validation"
Write-Output "---------------------"

# A configured sender address is required when an email report is requested
if ($EmailTo -and -not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -Verbose
    throw "This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
}

# Retrieve the RealmJoin API credential from the Automation Account shared credentials store.
# Reference: https://docs.realmjoin.com/dev-reference/realmjoin-api/authentication
Write-RjRbLog -Message "Retrieving Automation Account credential 'RJAPI' for RealmJoin API authentication." -Verbose
$rjApiCredential = Get-AutomationPSCredential -Name "RJAPI"

if ($null -eq $rjApiCredential) {
    Write-Error @"
The Automation Account shared credential named 'RJAPI' is missing.
See the runbook documentation https://docs.realmjoin.com/automation/runbooks/runbook-references/org/devices/report-primary-user-mismatch_scheduled for full setup instructions.

Step-by-step setup:
  1. If you do not yet have RealmJoin API credentials, request them at support@realmjoin.com
  2. In the Azure portal, open the Azure Automation Account used for runbooks
  3. Navigate to Shared Resources > Credentials
  4. Click 'Add a credential'
  5. Set the name to exactly: RJAPI
  6. Enter the RealmJoin API username and password
  7. Save and re-run this runbook
"@ -ErrorAction Continue
    throw "Automation Account credential 'RJAPI' not found. Cannot authenticate to the RealmJoin API without it."
}

Write-RjRbLog -Message "Credential 'RJAPI' retrieved successfully. API username: '$($rjApiCredential.UserName)'." -Verbose
Write-Output "RealmJoin API credential 'RJAPI' - OK"

if ($SyncThresholdDays -le 0) {
    Write-Error "The value provided for 'SyncThresholdDays' is '$SyncThresholdDays', which is not valid. SyncThresholdDays must be greater than 0." -ErrorAction Continue
    throw "SyncThresholdDays must be greater than 0. Received: '$SyncThresholdDays'."
}

Write-Output "SyncThresholdDays ($SyncThresholdDays) - OK"

if ([string]::IsNullOrWhiteSpace($EmailTo)) {
    Write-Error "The 'EmailTo' parameter is empty or contains only whitespace. A valid recipient email address is required so the report can be delivered." -ErrorAction Continue
    throw "EmailTo must be a non-empty, non-whitespace email address. Received: '$EmailTo'."
}

Write-Output "EmailTo ($EmailTo) - OK"

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

Write-Output ""
Write-Output "Parameter Validation completed successfully."

#endregion

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri

    do {
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        if ($response.value) {
            $allResults.AddRange([object[]]$response.value)
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $allResults
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
    Write-Error "Failed to connect to Microsoft Graph. Ensure the managed identity is configured correctly. Error: $_" -ErrorAction Continue
    throw
}

# Connect-RjRbGraph is required for Send-RjReportEmail email sender auth.
Write-Output "Connecting to RJ RunbookHelper Graph session (required for Send-RjReportEmail)..."
try {
    Connect-RjRbGraph -ErrorAction Stop
}
catch {
    Write-Error "Failed to establish the RJ RunbookHelper Graph session. Send-RjReportEmail will not be available. Ensure the managed identity has the Mail.Send app role assignment. Error: $_" -ErrorAction Continue
    throw
}

#endregion

########################################################
#region     Data Collection
########################################################

Write-Output ""
Write-Output "Get Intune Managed Devices"
Write-Output "---------------------"

# Build ISO8601 UTC threshold from the SyncThresholdDays parameter.
$thresholdDate = (Get-Date).AddDays(-$SyncThresholdDays)
$isoThresholdDate = $thresholdDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
Write-RjRbLog -Message "Sync threshold date (UTC): $isoThresholdDate (last $SyncThresholdDays days)" -Verbose

# Server-side $filter (OS + lastSync) and $select keep the payload small for large tenants.
# The device-name-prefix filter is applied client-side in the Data Processing region.
# managedDevice.userPrincipalName / userId IS the Intune primary user - no per-device call needed.
$baseUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
$filterQuery = "`$filter=operatingSystem eq 'Windows' and lastSyncDateTime ge $isoThresholdDate"
$selectQuery = "`$select=id,deviceName,azureADDeviceId,userId,userPrincipalName,operatingSystem,lastSyncDateTime"
$graphUri = "$baseUri`?$filterQuery&$selectQuery"

try {
    $intuneDevices = Get-GraphPagedResult -Uri $graphUri
}
catch {
    Write-Error "Failed to retrieve Intune managed devices from Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
    throw "Unable to retrieve Intune device inventory"
}

Write-Output "Retrieved $($intuneDevices.Count) Windows device(s) synced in the last $SyncThresholdDays day(s)."
Write-RjRbLog -Message "Intune devices retrieved: $($intuneDevices.Count)" -Verbose

Write-Output ""
Write-Output "Get RealmJoin Devices"
Write-Output "---------------------"

# Authenticate to the RealmJoin customer API with Basic Auth using the 'RJAPI' credential.
# Reference: https://docs.realmjoin.com/dev-reference/realmjoin-api/authentication
$rjApiUri = "https://customer-api.realmjoin.com/device/list"
$rjApiPassword = $rjApiCredential.GetNetworkCredential().Password
$rjAuthRaw = "$($rjApiCredential.UserName):$rjApiPassword"
$rjAuthHeader = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($rjAuthRaw))
$rjHeaders = @{
    Authorization = $rjAuthHeader
    Accept        = "application/json"
}

try {
    $rjResponse = Invoke-RestMethod -Uri $rjApiUri -Method GET -Headers $rjHeaders -ErrorAction Stop
}
catch {
    Write-Error "Failed to retrieve devices from the RealmJoin API ($rjApiUri): $($_.Exception.Message). Verify the 'RJAPI' credential is valid and the API is reachable." -ErrorAction Continue
    throw "Unable to retrieve RealmJoin device list"
}

# Normalize the response to a plain array (the API may return a bare array or a { value: [...] } wrapper).
if ($null -eq $rjResponse) {
    $rjDevices = @()
}
elseif ($rjResponse.PSObject -and ($rjResponse.PSObject.Properties.Name -contains 'value')) {
    $rjDevices = @($rjResponse.value)
}
else {
    $rjDevices = @($rjResponse)
}

Write-Output "Retrieved $($rjDevices.Count) device(s) from the RealmJoin API."
Write-RjRbLog -Message "RealmJoin devices retrieved: $($rjDevices.Count)" -Verbose

# Optional device scope filtering: resolve Entra device group membership up front so the
# Data Processing region can drop devices that should not affect the report. Group members of
# type #microsoft.graph.device expose their Entra Device ID via the 'deviceId' property, which
# corresponds to the managedDevice 'azureADDeviceId' / RealmJoin 'entraDeviceId'.
$includeDeviceIds = @()
$excludeDeviceIds = @()

if ($UseDeviceScope) {
    Write-Output ""
    Write-Output "Get Device Scope Groups"
    Write-Output "---------------------"

    if (-not [string]::IsNullOrEmpty($IncludeDeviceGroup)) {
        Write-Output "Retrieving members of the include device group..."
        try {
            $includeGroupUri = "https://graph.microsoft.com/v1.0/groups/$IncludeDeviceGroup/members?`$select=id,deviceId,displayName"
            $includeMembers = Get-GraphPagedResult -Uri $includeGroupUri
            $includeDeviceIds = @($includeMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' -and -not [string]::IsNullOrEmpty($_.deviceId) } | ForEach-Object { $_.deviceId.ToLower() })
            Write-Output "Include device group contains $($includeDeviceIds.Count) device(s)."
        }
        catch {
            Write-Error "Failed to retrieve members of the include device group ('$IncludeDeviceGroup'): $($_.Exception.Message)" -ErrorAction Continue
            throw "Unable to retrieve include device group membership"
        }
    }

    if (-not [string]::IsNullOrEmpty($ExcludeDeviceGroup)) {
        Write-Output "Retrieving members of the exclude device group..."
        try {
            $excludeGroupUri = "https://graph.microsoft.com/v1.0/groups/$ExcludeDeviceGroup/members?`$select=id,deviceId,displayName"
            $excludeMembers = Get-GraphPagedResult -Uri $excludeGroupUri
            $excludeDeviceIds = @($excludeMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' -and -not [string]::IsNullOrEmpty($_.deviceId) } | ForEach-Object { $_.deviceId.ToLower() })
            Write-Output "Exclude device group contains $($excludeDeviceIds.Count) device(s)."
        }
        catch {
            Write-Error "Failed to retrieve members of the exclude device group ('$ExcludeDeviceGroup'): $($_.Exception.Message)" -ErrorAction Continue
            throw "Unable to retrieve exclude device group membership"
        }
    }
}

#endregion

########################################################
#region     Data Processing
########################################################

Write-Output ""
Write-Output "Processing device data correlation..."
Write-Output "---------------------"

# Build a lookup of RealmJoin devices keyed by entraDeviceId (lowercased) for O(1) matching.
$rjDevicesByEntraId = @{}
foreach ($rjDevice in $rjDevices) {
    if (-not [string]::IsNullOrEmpty($rjDevice.entraDeviceId)) {
        $rjDevicesByEntraId[$rjDevice.entraDeviceId.ToLower()] = $rjDevice
    }
}

# Apply the DeviceNamePrefix filter (client-side, case-insensitive).
$filteredIntuneDevices = if ([string]::IsNullOrEmpty($DeviceNamePrefix)) {
    $intuneDevices
}
else {
    $intuneDevices | Where-Object { $_.deviceName -like "$DeviceNamePrefix*" }
}

Write-RjRbLog -Message "Intune devices after name-prefix filter: $($filteredIntuneDevices.Count)" -Verbose

$reportData = @()
$reportData = $filteredIntuneDevices | ForEach-Object {
    $intuneDevice = $_

    # Detect a deleted Entra primary user: when the primary user no longer exists in Entra ID,
    # Intune mangles managedDevice.userPrincipalName by prefixing the user's object id (a GUID
    # without dashes, 32 hex chars) in front of the original UPN, e.g.
    # "702fabaa7fef412ea14ed0bea71e8729heidi.kabel@contoso.com". Without special handling this
    # would surface as a false Mismatch against RealmJoin's clean, cached userName.
    $intunePrimaryUserDeleted = $false
    $intunePrimaryUser = if ([string]::IsNullOrEmpty($intuneDevice.userPrincipalName)) { "(none)" } else { $intuneDevice.userPrincipalName }
    if ($intuneDevice.userPrincipalName -match '^[0-9a-fA-F]{32}(?<upn>.+@.+)$') {
        $intunePrimaryUserDeleted = $true
        $intunePrimaryUser = $Matches['upn']
    }

    # Match against RealmJoin by entraDeviceId (Azure AD Device ID) first, then by intuneDeviceId.
    $rjDevice = $null
    if (-not [string]::IsNullOrEmpty($intuneDevice.azureADDeviceId)) {
        $rjDevice = $rjDevicesByEntraId[$intuneDevice.azureADDeviceId.ToLower()]
    }
    if (-not $rjDevice) {
        $rjDevice = $rjDevices | Where-Object { $_.intuneDeviceId -eq $intuneDevice.id } | Select-Object -First 1
    }

    $rjPrimaryUser = if ($rjDevice) { $rjDevice.users | Where-Object { $_.isPrimary -eq $true } | Select-Object -First 1 } else { $null }
    $rjPrimaryUserName = if ($rjPrimaryUser -and -not [string]::IsNullOrEmpty($rjPrimaryUser.userName)) { $rjPrimaryUser.userName } else { "(none)" }

    # A deleted Intune primary user is its own category and takes precedence: it is not a real
    # configuration drift but a cleanup candidate. Otherwise a Mismatch is only possible when
    # RealmJoin actually has a user flagged isPrimary = true; a device absent from RealmJoin (or
    # whose primary user has never logged in and therefore cannot be detected) is MissingInRealmJoin.
    if ($intunePrimaryUserDeleted) {
        $status = "PrimaryUserDeleted"
    }
    elseif ($rjPrimaryUser -and -not [string]::IsNullOrEmpty($rjPrimaryUser.userName)) {
        $status = if ($intunePrimaryUser.ToLower() -eq $rjPrimaryUserName.ToLower()) { "Match" } else { "Mismatch" }
    }
    else {
        $status = "MissingInRealmJoin"
    }

    $lastSync = if ($intuneDevice.lastSyncDateTime) { (Get-Date $intuneDevice.lastSyncDateTime).ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }

    [PSCustomObject]@{
        DeviceName           = $intuneDevice.deviceName
        AzureAdDeviceId      = $intuneDevice.azureADDeviceId
        IntuneDeviceId       = $intuneDevice.id
        IntunePrimaryUser    = $intunePrimaryUser
        RealmJoinPrimaryUser = $rjPrimaryUserName
        Status               = $status
        LastSyncDateTime     = $lastSync
    }
}

# Ensure $reportData is always an array even if 0 or 1 item.
$reportData = @($reportData)

Write-RjRbLog -Message "Processed $($reportData.Count) Intune devices for correlation analysis" -Verbose

# Surface RealmJoin devices that had no Intune counterpart (in-scope after the name filter).
$intuneEntraIds = @($filteredIntuneDevices | ForEach-Object { if (-not [string]::IsNullOrEmpty($_.azureADDeviceId)) { $_.azureADDeviceId.ToLower() } })
foreach ($orphanRj in $rjDevices) {
    if ([string]::IsNullOrEmpty($orphanRj.entraDeviceId)) { continue }
    if ($intuneEntraIds -contains $orphanRj.entraDeviceId.ToLower()) { continue }
    $rjPrimaryUser = $orphanRj.users | Where-Object { $_.isPrimary -eq $true } | Select-Object -First 1
    $rjPrimaryUserName = if ($rjPrimaryUser -and -not [string]::IsNullOrEmpty($rjPrimaryUser.userName)) { $rjPrimaryUser.userName } else { "(none)" }
    $reportData += [PSCustomObject]@{
        DeviceName           = "N/A"
        AzureAdDeviceId      = $orphanRj.entraDeviceId
        IntuneDeviceId       = $orphanRj.intuneDeviceId
        IntunePrimaryUser    = "(none)"
        RealmJoinPrimaryUser = $rjPrimaryUserName
        Status               = "MissingInIntune"
        LastSyncDateTime     = "N/A"
    }
}

# Apply optional device scope filtering by Entra device group membership. This runs after the full
# report set (including MissingInIntune orphans) is assembled so excluded devices do not affect any
# summary counts below. Devices are matched on their Entra Device ID (AzureAdDeviceId).
if ($UseDeviceScope -and (($includeDeviceIds.Count -gt 0) -or ($excludeDeviceIds.Count -gt 0))) {
    $beforeScopeCount = $reportData.Count
    $reportData = @($reportData | Where-Object {
            $deviceEntraId = if (-not [string]::IsNullOrEmpty($_.AzureAdDeviceId)) { $_.AzureAdDeviceId.ToLower() } else { $null }

            # Include filter: keep only devices that are members of the include group.
            if (($includeDeviceIds.Count -gt 0) -and (($null -eq $deviceEntraId) -or ($deviceEntraId -notin $includeDeviceIds))) {
                return $false
            }

            # Exclude filter: drop devices that are members of the exclude group.
            if (($excludeDeviceIds.Count -gt 0) -and ($null -ne $deviceEntraId) -and ($deviceEntraId -in $excludeDeviceIds)) {
                return $false
            }

            return $true
        })
    Write-RjRbLog -Message "Device scope filtering applied: $beforeScopeCount -> $($reportData.Count) device(s)" -Verbose
    Write-Output "Device scope filtering applied: $beforeScopeCount device(s) reduced to $($reportData.Count)."
}

# Build the set of difference statuses the caller asked to include in the report.
$includedStatuses = [System.Collections.Generic.List[string]]::new()
if ($IncludeMismatches) { $includedStatuses.Add("Mismatch") }
if ($IncludeMissingInRealmJoin) { $includedStatuses.Add("MissingInRealmJoin") }
if ($IncludeMissingInIntune) { $includedStatuses.Add("MissingInIntune") }
if ($IncludePrimaryUserDeleted) { $includedStatuses.Add("PrimaryUserDeleted") }

if ($includedStatuses.Count -eq 0) {
    Write-RjRbLog -Message "WARNING: No difference categories are enabled (IncludeMismatches, IncludeMissingInRealmJoin, IncludeMissingInIntune, IncludePrimaryUserDeleted are all false). No differences will be reported." -Verbose
    Write-Output "WARNING: No difference categories are enabled - the report will contain no differences."
}

Write-RjRbLog -Message "Included difference statuses: $($includedStatuses -join ', ')" -Verbose

$differences = @($reportData | Where-Object { $includedStatuses -contains $_.Status })

$totalEvaluated = $reportData.Count
$matchCount = @($reportData | Where-Object { $_.Status -eq "Match" }).Count
$mismatchCount = @($reportData | Where-Object { $_.Status -eq "Mismatch" }).Count
$missingInRjCount = @($reportData | Where-Object { $_.Status -eq "MissingInRealmJoin" }).Count
$missingInIntuneCount = @($reportData | Where-Object { $_.Status -eq "MissingInIntune" }).Count
$primaryUserDeletedCount = @($reportData | Where-Object { $_.Status -eq "PrimaryUserDeleted" }).Count

Write-RjRbLog -Message "Total evaluated: $totalEvaluated; Match: $matchCount; Mismatch: $mismatchCount; MissingInRealmJoin: $missingInRjCount; MissingInIntune: $missingInIntuneCount; PrimaryUserDeleted: $primaryUserDeletedCount" -Verbose

#endregion

########################################################
#region     Output/Export
########################################################

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Total Devices Evaluated: $totalEvaluated"
Write-Output "Matching: $matchCount"
Write-Output "Mismatches: $mismatchCount"
Write-Output "Missing in RealmJoin: $missingInRjCount"
Write-Output "Missing in Intune: $missingInIntuneCount"
Write-Output "Primary User Deleted: $primaryUserDeletedCount"

$tempDir = $null
$csvFilePath = $null
$xlsxFilePath = $null
$reportFiles = @()

# Cap the inline "Devices with Differences" listing at this many rows; the full set is always in the report files.
$maxDisplayDevices = 10
$displayDifferences = @($differences | Select-Object -First $maxDisplayDevices)

if ($differences.Count -gt 0) {
    Write-Output ""
    Write-Output "Devices with Primary User Differences"
    Write-Output "---------------------"
    $displayDifferences | Format-Table -AutoSize -Property DeviceName, AzureAdDeviceId, IntunePrimaryUser, RealmJoinPrimaryUser, Status, LastSyncDateTime
    if ($differences.Count -gt $maxDisplayDevices) {
        Write-Output "Showing the first $maxDisplayDevices of $($differences.Count) device(s) with differences. See the attached report file(s) for the complete list."
    }

    # The report files are only needed when they will be attached to an email and/or uploaded
    if ($EmailTo -or $CreateDownloadLink) {
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "Report_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

        $fileNameBase = "$(Get-Date -Format 'yyyyMMdd_HHmmss')_PrimaryUserMismatch"
        if ($ReportFileFormat -ne 'XLSX only') {
            $csvFilePath = Join-Path $tempDir "$fileNameBase.csv"
            $differences | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
            $reportFiles += $csvFilePath
            Write-RjRbLog -Message "Exported $($differences.Count) differing devices to CSV: $csvFilePath" -Verbose
            Write-Output "CSV file created: $csvFilePath"
        }
        if ($ReportFileFormat -ne 'CSV only') {
            $xlsxFilePath = Join-Path $tempDir "$fileNameBase.xlsx"
            $differences | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Primary User Mismatch"
            $reportFiles += $xlsxFilePath
            Write-RjRbLog -Message "Exported $($differences.Count) differing devices to XLSX: $xlsxFilePath" -Verbose
            Write-Output "XLSX file created: $xlsxFilePath"
        }
    }
}
else {
    Write-Output ""
    Write-Output "No primary user differences detected - Intune and RealmJoin are in sync."
    Write-Output "Email report skipped (no differences found)."
}

#endregion

########################################################
#region     Upload / Download Link (optional)
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
        Write-Output "No primary user differences detected - skipping report upload."
    }
}

#endregion

########################################################
#region     Email Report
########################################################

if (-not $EmailTo) {
    Write-RjRbLog -Message "No recipient email address provided - email report skipped" -Verbose
}
elseif ($differences.Count -gt 0) {
    try {
        $tenantInfo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
        $tenantDisplayName = $tenantInfo.value[0].displayName ?? "Tenant"
    }
    catch {
        Write-Warning "Failed to retrieve tenant display name: $_"
        $tenantDisplayName = "Tenant"
    }

    # Build the summary so it only lists the difference categories the caller enabled
    # (IncludeMismatches / IncludeMissingInRealmJoin / IncludeMissingInIntune /
    # IncludePrimaryUserDeleted). Total Devices Evaluated is always shown for context.
    $summaryLines = [System.Collections.Generic.List[string]]::new()
    $summaryLines.Add("- **Total Devices Evaluated**: $totalEvaluated")
    if ($IncludeMismatches) { $summaryLines.Add("- **Mismatches**: $mismatchCount") }
    if ($IncludeMissingInRealmJoin) { $summaryLines.Add("- **Missing in RealmJoin**: $missingInRjCount") }
    if ($IncludeMissingInIntune) { $summaryLines.Add("- **Missing in Intune**: $missingInIntuneCount") }
    if ($IncludePrimaryUserDeleted) { $summaryLines.Add("- **Primary User Deleted (Entra)**: $primaryUserDeletedCount") }
    $summaryBlock = $summaryLines -join "`n"

    $markdownContent = @"
# Primary User Mismatch Report

## Summary
$summaryBlock

## Devices with Differences
A total of $($differences.Count) device(s) differ between Intune and RealmJoin. Showing up to $maxDisplayDevices below; the full list is in the attached report file(s).

| Device Name | Entra Device ID | Intune Primary User | RealmJoin Primary User | Status | Last Sync |
|---|---|---|---|---|---|
"@

    foreach ($device in $displayDifferences) {
        $markdownContent += "`n| $($device.DeviceName) | $($device.AzureAdDeviceId) | $($device.IntunePrimaryUser) | $($device.RealmJoinPrimaryUser) | $($device.Status) | $($device.LastSyncDateTime) |"
    }

    if ($differences.Count -gt $maxDisplayDevices) {
        $markdownContent += "`n`n_Showing the first $maxDisplayDevices of $($differences.Count) device(s) with differences. See the attached report file(s) for the complete list._"
    }

    $markdownContent += "`n`nSee the attached report file(s) for full details.`n"

    $markdownContent += "`n---`n`n*This email was automatically generated. Please do not reply to this email.*`n"

    $emailSubject = "Primary User Mismatch Report - $tenantDisplayName - $(Get-Date -Format 'yyyy-MM-dd')"

    $markdownFallback = @"
# Primary User Mismatch Report

## Summary
$summaryBlock

## Devices with Differences
A total of $($differences.Count) device(s) differ between Intune and RealmJoin.

- **$($fileNameBase).xlsx**: Formatted Excel workbook with the complete list of differences

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

    # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
    try {
        $guardParams = @{
            EmailFrom         = $EmailFrom
            EmailTo           = $EmailTo
            Subject           = $emailSubject
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
        Write-RjRbLog -Message "Email report sent successfully to: $EmailTo" -Verbose
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to send email report: $($_.Exception.Message)"
    }
}
else {
    Write-RjRbLog -Message "No differences found - email report skipped" -Verbose
}

#endregion

########################################################
#region     Cleanup
########################################################

if ($tempDir -and (Test-Path -Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-RjRbLog -Message "Removed temporary export directory: $tempDir" -Verbose
}

# Connect-RjRbGraph session is managed internally by RealmJoin.RunbookHelper - no explicit disconnect needed.
Disconnect-MgGraph | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion

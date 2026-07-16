<#
    .SYNOPSIS
    Ensure a security group's members are owners of mapped Teams and their shared channels.

    .DESCRIPTION
    Teams Shared Channels do not inherit ownership from their parent team. This scheduled runbook closes
    that gap: for each team named in a mapping, it ensures the members of a mapped security group are owners
    of the team and of every shared channel the team hosts. The team-name-to-owner-group mapping is
    maintained centrally as a RealmJoin org setting. The runbook is add-only - existing owners and members
    are never removed - so newly created shared channels are simply picked up on the next run. It can
    optionally email a report and/or upload the report files as a download link. The ReportFileFormat
    parameter controls which report file formats are generated and delivered (CSV only, CSV & XLSX, or
    XLSX only). When the CSV attachments exceed the email size limit and "CSV & XLSX" is selected, the
    email falls back to the Excel workbook alone. See the accompanying documentation for the mapping
    rules and configuration.

    .PARAMETER TeamOwnerGroupMapping
    Mapping of an exact team display name to an owner security group object id, e.g.
    [{ "TeamName": "EXT Service A", "OwnerGroupId": "00000000-0000-0000-0000-000000000000" }].
    Hidden parameter, bound to the org Setting "SharedChannelOwners.Mapping". The RealmJoin portal injects
    that value; the runbook accepts it either as the deserialized object/array (structured sub-settings) or
    as a JSON string and normalizes both.

    .PARAMETER IncludeTeamOwners
    When enabled (default), the owner-group members are also ensured as owners and members of the parent
    team itself (M365 group owners/members). Team membership is also the prerequisite for channel ownership.

    .PARAMETER WhatIfMode
    When enabled, the runbook only logs the changes it would make without writing anything.

    .PARAMETER SendEmailReport
    When enabled, a RealmJoin-branded email report is sent via Send-RjReportEmail after the run. The body
    contains run statistics; the report files (per-team summary and per-change detail) are attached in the
    selected report file format(s).

    .PARAMETER EmailTo
    Recipient email address(es) for the report (comma-separated). Only used when SendEmailReport is enabled.

    .PARAMETER EmailFrom
    Sender mailbox for the report. Bound to the org Setting "RJReport.EmailSender".

    .PARAMETER ReportFileFormat
    Controls which report file formats are generated and delivered: "CSV only", "CSV & XLSX" (default) or "XLSX only".

    .PARAMETER CreateDownloadLink
    When enabled, the report file(s) are uploaded to a storage account and time-limited download links are
    returned (and included in the email report if that is also enabled). Default off.

    .PARAMETER ContainerName
    Storage container used for the upload. Configured per runbook (not a global RJReport setting).

    .PARAMETER ResourceGroupName
    Resource group that contains the storage account. Bound to "RJReport.StorageAccount.ResourceGroup".

    .PARAMETER StorageAccountName
    Storage account used for the upload. Bound to "RJReport.StorageAccount.StorageAccountName".

    .PARAMETER LinkExpiryDays
    Days until the generated download link expires. Bound to "RJReport.StorageAccount.LinkExpiryDays".

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .NOTES
    Configure the mapping once centrally (Runbook Customization -> Settings) as a structured sub-setting under
    "SharedChannelOwners.Mapping". Each entry names a team by its exact display name. The hidden
    TeamOwnerGroupMapping parameter is injected from it at runtime.
    {
        "Settings": {
            "SharedChannelOwners": {
                "Mapping": [
                    { "TeamName": "EXT Service A", "OwnerGroupId": "11111111-1111-1111-1111-111111111111" },
                    { "TeamName": "EXT Service B", "OwnerGroupId": "22222222-2222-2222-2222-222222222222" }
                ]
            }
        }
    }

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "TeamOwnerGroupMapping": {
                "Hide": true
            },
            "IncludeTeamOwners": {
                "DisplayName": "Also make them owners of the parent team"
            },
            "WhatIfMode": {
                "DisplayName": "Dry run (log only, no changes)"
            },
            "SendEmailReport": {
                "DisplayName": "Send email report",
                "Select": {
                    "Options": [
                        {
                            "Display": "No",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": [
                                    "EmailTo",
                                    "ReportFileFormat"
                                ]
                            }
                        },
                        {
                            "Display": "Yes",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": [
                                    "EmailTo",
                                    "ReportFileFormat"
                                ]
                            }
                        }
                    ]
                }
            },
            "EmailTo": {
                "DisplayName": "Send report to (email address(es))"
            },
            "EmailFrom": {
                "Hide": true
            },
            "CreateDownloadLink": {
                "DisplayName": "Create a report download link (upload report to storage)",
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - upload report and return a download link",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": [
                                    "ReportFileFormat"
                                ]
                            }
                        },
                        {
                            "Display": "No - do not create a download link",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": [
                                    "ReportFileFormat"
                                ]
                            }
                        }
                    ]
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
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.38.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.0" }

param(
    # Hidden, sourced from the org Setting "SharedChannelOwners.Mapping". May arrive as a structured
    # object/array (sub-settings) or as a JSON string - both are normalized below.
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "SharedChannelOwners.Mapping" } )]
    [object] $TeamOwnerGroupMapping = "[]",

    [bool] $IncludeTeamOwners = $true,

    [bool] $WhatIfMode = $false,

    # Enables the email report; when on, EmailTo becomes visible in the portal.
    [bool] $SendEmailReport = $false,

    [string] $EmailTo,

    # Sender mailbox, sourced from the org Setting "RJReport.EmailSender".
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string] $EmailFrom,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'CSV & XLSX',

    # Enables uploading the report file(s) to a storage account and returning a download link.
    [bool] $CreateDownloadLink = $false,

    [string] $ContainerName = "shared-channel-owners",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     Function declaration
##
########################################################

function ConvertTo-MappingArray {
    # Normalizes the injected setting into an array of { TeamName, OwnerGroupId } objects.
    # The RealmJoin portal may inject the setting as already-deserialized objects (structured
    # sub-settings) or as a JSON string - handle both, plus a hashtable variant.
    param(
        $Raw
    )

    if ($null -eq $Raw) {
        return @()
    }

    if ($Raw -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Raw)) {
            return @()
        }
        return @($Raw | ConvertFrom-Json)
    }

    # Already structured (PSCustomObject[], hashtable[], single object, ...)
    return @($Raw)
}

function Get-GraphPagedResult {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri
    )

    $results = @()
    $nextLink = $Uri
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink
        if ($response.value) {
            $results += $response.value
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $results
}

function Get-GroupTransitiveUser {
    param(
        [Parameter(Mandatory = $true)]
        [string] $GroupId
    )

    $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId/transitiveMembers/microsoft.graph.user`?`$select=id,displayName,userPrincipalName,userType"
    return Get-GraphPagedResult -Uri $uri
}


function Add-ChannelOwner {
    param(
        [Parameter(Mandatory = $true)] [string] $TeamId,
        [Parameter(Mandatory = $true)] [string] $ChannelId,
        [Parameter(Mandatory = $true)] [string] $UserId,
        [Parameter(Mandatory = $true)] [string] $UserUpn,
        # Hashtable: userId -> @{ MembershipId = ...; Roles = @(...) }
        [Parameter(Mandatory = $true)] [hashtable] $ExistingMembers,
        [bool] $DryRun = $false
    )

    $membersUri = "https://graph.microsoft.com/v1.0/teams/$TeamId/channels/$ChannelId/members"

    $existing = $ExistingMembers[$UserId]
    if ($existing -and ($existing.Roles -contains "owner")) {
        return "skip"
    }

    if ($existing) {
        # Already a member, promote to owner via PATCH
        if ($DryRun) {
            "##   [WhatIf] Would promote '$UserUpn' to owner"
            return "promote"
        }
        $patchUri = "$membersUri/$([uri]::EscapeDataString($existing.MembershipId))"
        $patchBody = @{
            "@odata.type" = "#microsoft.graph.aadUserConversationMember"
            roles         = @("owner")
        }
        Invoke-MgGraphRequest -Method PATCH -Uri $patchUri -Body $patchBody -ContentType "application/json" | Out-Null
        return "promote"
    }

    # Not a member yet - add directly as owner
    if ($DryRun) {
        "##   [WhatIf] Would add '$UserUpn' as owner"
        return "add"
    }

    $addBody = @{
        "@odata.type"     = "#microsoft.graph.aadUserConversationMember"
        roles             = @("owner")
        "user@odata.bind" = "https://graph.microsoft.com/v1.0/users('$UserId')"
    }
    try {
        Invoke-MgGraphRequest -Method POST -Uri $membersUri -Body $addBody -ContentType "application/json" | Out-Null
        return "add"
    }
    catch {
        # Fallback: replication lag / team-membership prerequisite. Add as plain member first, then promote.
        Write-RjRbLog -Message "Direct owner-add for '$UserUpn' failed, trying member-then-promote. Error: $_" -Verbose
        $memberBody = @{
            "@odata.type"     = "#microsoft.graph.aadUserConversationMember"
            roles             = @()
            "user@odata.bind" = "https://graph.microsoft.com/v1.0/users('$UserId')"
        }
        $created = Invoke-MgGraphRequest -Method POST -Uri $membersUri -Body $memberBody -ContentType "application/json"
        if ($created.id) {
            $patchUri = "$membersUri/$([uri]::EscapeDataString($created.id))"
            $patchBody = @{
                "@odata.type" = "#microsoft.graph.aadUserConversationMember"
                roles         = @("owner")
            }
            Invoke-MgGraphRequest -Method PATCH -Uri $patchUri -Body $patchBody -ContentType "application/json" | Out-Null
        }
        return "add"
    }
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
#region     RJ Log Part
##
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "IncludeTeamOwners: $IncludeTeamOwners" -Verbose
Write-RjRbLog -Message "WhatIfMode: $WhatIfMode" -Verbose
Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
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
Write-RjRbLog -Message "TeamOwnerGroupMapping (raw type): $($TeamOwnerGroupMapping.GetType().Name)" -Verbose

#endregion

########################################################
#region     Connect Part
##
########################################################

Write-Output "Initiate MGGraph Session..."
try {
    $VerbosePreference = "SilentlyContinue"
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    $VerbosePreference = "Continue"
}
catch {
    Write-Error "MGGraph Connect failed - stopping script"
    throw ("Graph connection failed")
}

#endregion

########################################################
#region     Main Part
##
########################################################

# Normalize and validate the mapping (accepts structured sub-settings or a JSON string)
try {
    $mapping = ConvertTo-MappingArray -Raw $TeamOwnerGroupMapping
}
catch {
    "## Invalid SharedChannelOwners.Mapping setting - expected an array of { TeamName, OwnerGroupId }."
    "## See this runbook's source (.NOTES) for the expected format."
    throw ("Invalid mapping")
}

if (-not $mapping -or $mapping.Count -eq 0) {
    "## No mapping configured. Set the org Setting 'SharedChannelOwners.Mapping'."
    "## See this runbook's source (.EXAMPLE) for the expected format."
    throw ("Empty mapping")
}

if ($WhatIfMode) {
    "## WhatIf mode is ON - no changes will be written."
    ""
}

$mode = if ($WhatIfMode) { "WhatIf" } else { "Live" }

# Validate report configuration early (fail fast before doing the work)
if ($SendEmailReport) {
    if (-not $EmailTo) {
        "## SendEmailReport is enabled but no EmailTo was provided."
        throw ("EmailTo missing")
    }
    if (-not $EmailFrom) {
        "## SendEmailReport is enabled but no sender is configured (org Setting 'RJReport.EmailSender')."
        throw ("EmailFrom missing")
    }
}
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    "## CreateDownloadLink is enabled but no target storage account is configured."
    "## Configure the RJReport.StorageAccount.* settings or pass ResourceGroupName and StorageAccountName."
    throw ("Storage account configuration missing")
}

# Build normalized mapping entries (trimmed team names), skipping invalid ones
$mappingEntries = @()
foreach ($entry in $mapping) {
    $teamName = ([string]$entry.TeamName).Trim()
    $ownerGroupId = [string]$entry.OwnerGroupId
    if (-not $teamName -or -not $ownerGroupId) {
        "## Skipping invalid mapping entry (missing TeamName or OwnerGroupId)."
        continue
    }
    $mappingEntries += [PSCustomObject]@{ TeamName = $teamName; OwnerGroupId = $ownerGroupId }
}

if ($mappingEntries.Count -eq 0) {
    "## No valid mapping entries."
    throw ("No valid mapping entries")
}

"## Configured mappings (exact team name -> owner group):"
foreach ($me in $mappingEntries) {
    "##   '$($me.TeamName)' -> owner group '$($me.OwnerGroupId)'"
}

# Resolve each mapping entry to the team(s) with that exact display name. (displayName is not guaranteed
# unique, so a name may resolve to 0, 1 or more teams.)
$resolvedMappings = @()
foreach ($me in $mappingEntries) {
    $filter = "displayName eq '$($me.TeamName.Replace("'", "''"))'"
    $groupsUri = "https://graph.microsoft.com/v1.0/groups`?`$filter=$([uri]::EscapeDataString($filter))&`$select=id,displayName,resourceProvisioningOptions,visibility"
    $teams = @(Get-GraphPagedResult -Uri $groupsUri | Where-Object { $_.resourceProvisioningOptions -contains "Team" })
    $resolvedMappings += [PSCustomObject]@{ Entry = $me; Teams = $teams }
}

# In WhatIf mode, show up-front which teams would be processed (and which configured names were not found)
if ($WhatIfMode) {
    "## Teams that WOULD be processed:"
    $wouldProcess = $false
    foreach ($r in $resolvedMappings) {
        foreach ($team in ($r.Teams | Sort-Object displayName)) {
            $wouldProcess = $true
            "##   - '$($team.displayName)' [visibility: $($team.visibility)] -> owner group '$($r.Entry.OwnerGroupId)'"
        }
    }
    if (-not $wouldProcess) {
        "##   (none)"
    }
    $notFoundNames = @($resolvedMappings | Where-Object { $_.Teams.Count -eq 0 } | ForEach-Object { $_.Entry.TeamName })
    if ($notFoundNames.Count -gt 0) {
        "## Configured team names not found:"
        foreach ($name in ($notFoundNames | Sort-Object)) {
            "##   - '$name'"
        }
    }
    ""
}

# Aggregate counters
$totalOwnersAdded = 0
$totalPromoted = 0
$totalChannels = 0
$totalTeams = 0
$totalTeamOwnersAdded = 0
$totalTeamMembersAdded = 0

# Report data (filled regardless; only emitted when SendEmailReport is on)
$teamReportRows = @()
$actionRows = @()

# Cache resolved owner users per owner group (avoid re-querying the same group)
$ownerUsersCache = @{}

# Flatten resolved mappings to (team, owner-group) pairs; record configured names that matched no team
$teamsToProcess = @()
foreach ($r in $resolvedMappings) {
    if ($r.Teams.Count -eq 0) {
        "## Team '$($r.Entry.TeamName)' not found."
        $teamReportRows += [PSCustomObject]@{
            Team                  = $r.Entry.TeamName
            TeamId                = ""
            Visibility            = ""
            MatchedTeamName       = $r.Entry.TeamName
            OwnerGroupId          = $r.Entry.OwnerGroupId
            OwnerUserCount        = 0
            SharedChannels        = 0
            TeamMembersAdded      = 0
            TeamOwnersAdded       = 0
            ChannelOwnersAdded    = 0
            ChannelOwnersPromoted = 0
            Status                = "Team not found"
            Mode                  = $mode
        }
        continue
    }
    foreach ($team in $r.Teams) {
        $teamsToProcess += [PSCustomObject]@{ Team = $team; Entry = $r.Entry }
    }
}

foreach ($item in $teamsToProcess) {
    $team = $item.Team
    $me = $item.Entry
    $teamId = $team.id

    "## Team '$($team.displayName)' ($teamId) -> owner group '$($me.OwnerGroupId)'"
    $totalTeams++

    # Resolve desired owners (transitive users of the owner group), excluding guests; cached per group
    if (-not $ownerUsersCache.ContainsKey($me.OwnerGroupId)) {
        $ownerUsersCache[$me.OwnerGroupId] = @(Get-GroupTransitiveUser -GroupId $me.OwnerGroupId | Where-Object { $_.userType -ne "Guest" })
        Write-RjRbLog -Message "Resolved $($ownerUsersCache[$me.OwnerGroupId].Count) owner user(s) for group '$($me.OwnerGroupId)'." -Verbose
    }
    $ownerUsers = $ownerUsersCache[$me.OwnerGroupId]
    if ($ownerUsers.Count -eq 0) {
        "##   Owner group '$($me.OwnerGroupId)' has no (non-guest) user members - skipping team."
        $teamReportRows += [PSCustomObject]@{
            Team                  = $team.displayName
            TeamId                = $teamId
            Visibility            = $team.visibility
            MatchedTeamName       = $me.TeamName
            OwnerGroupId          = $me.OwnerGroupId
            OwnerUserCount        = 0
            SharedChannels        = 0
            TeamMembersAdded      = 0
            TeamOwnersAdded       = 0
            ChannelOwnersAdded    = 0
            ChannelOwnersPromoted = 0
            Status                = "Skipped (owner group empty)"
            Mode                  = $mode
        }
        continue
    }

    # Per-team report counters
    $teamMembersAddedThis = 0
    $teamOwnersAddedThis = 0
    $channelOwnersAddedThis = 0
    $channelPromotedThis = 0
    $teamChannelsThis = 0

    # (Optional) ensure owner-group users are owners and members of the parent team
    if ($IncludeTeamOwners) {
        $existingOwnerIds = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$teamId/owners`?`$select=id" | ForEach-Object { $_.id })
        $existingMemberIds = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$teamId/members`?`$select=id" | ForEach-Object { $_.id })

        foreach ($u in $ownerUsers) {
            # Team membership is the prerequisite for channel ownership - ensure it first
            if ($existingMemberIds -notcontains $u.id) {
                if ($WhatIfMode) {
                    "##     [WhatIf] Would add '$($u.userPrincipalName)' as team member"
                    $teamMembersAddedThis++
                    $totalTeamMembersAdded++
                    $actionRows += [PSCustomObject]@{ Team = $team.displayName; TeamId = $teamId; Scope = "Team"; Channel = ""; UserUpn = $u.userPrincipalName; UserId = $u.id; Action = "Add member"; Mode = $mode }
                }
                else {
                    $refBody = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($u.id)" }
                    try {
                        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$teamId/members/`$ref" -Body $refBody -ContentType "application/json" | Out-Null
                        $teamMembersAddedThis++
                        $totalTeamMembersAdded++
                        $actionRows += [PSCustomObject]@{ Team = $team.displayName; TeamId = $teamId; Scope = "Team"; Channel = ""; UserUpn = $u.userPrincipalName; UserId = $u.id; Action = "Add member"; Mode = $mode }
                    }
                    catch {
                        Write-RjRbLog -Message "Could not add '$($u.userPrincipalName)' as team member: $_" -Verbose
                    }
                }
            }
            if ($existingOwnerIds -notcontains $u.id) {
                if ($WhatIfMode) {
                    "##     [WhatIf] Would add '$($u.userPrincipalName)' as team owner"
                    $teamOwnersAddedThis++
                    $totalTeamOwnersAdded++
                    $actionRows += [PSCustomObject]@{ Team = $team.displayName; TeamId = $teamId; Scope = "Team"; Channel = ""; UserUpn = $u.userPrincipalName; UserId = $u.id; Action = "Add owner"; Mode = $mode }
                }
                else {
                    $refBody = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($u.id)" }
                    try {
                        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$teamId/owners/`$ref" -Body $refBody -ContentType "application/json" | Out-Null
                        $teamOwnersAddedThis++
                        $totalTeamOwnersAdded++
                        $actionRows += [PSCustomObject]@{ Team = $team.displayName; TeamId = $teamId; Scope = "Team"; Channel = ""; UserUpn = $u.userPrincipalName; UserId = $u.id; Action = "Add owner"; Mode = $mode }
                    }
                    catch {
                        Write-RjRbLog -Message "Could not add '$($u.userPrincipalName)' as team owner: $_" -Verbose
                    }
                }
            }
        }
    }

    # Hosted shared channels of this team
    $channelFilter = "membershipType eq 'shared'"
    $channelsUri = "https://graph.microsoft.com/v1.0/teams/$teamId/channels`?`$filter=$([uri]::EscapeDataString($channelFilter))"
    $sharedChannels = @(Get-GraphPagedResult -Uri $channelsUri)

    if ($sharedChannels.Count -eq 0) {
        "##     No shared channels."
    }
    else {
        foreach ($channel in $sharedChannels) {
            $channelId = $channel.id
            $totalChannels++
            $teamChannelsThis++
            "##     Shared channel '$($channel.displayName)'"

            # Index current channel members by userId
            $existingMembers = @{}
            $channelMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/teams/$teamId/channels/$channelId/members")
            foreach ($m in $channelMembers) {
                if ($m.userId) {
                    $existingMembers[$m.userId] = @{
                        MembershipId = $m.id
                        Roles        = @($m.roles)
                    }
                }
            }

            foreach ($u in $ownerUsers) {
                try {
                    $action = Add-ChannelOwner -TeamId $teamId -ChannelId $channelId -UserId $u.id -UserUpn $u.userPrincipalName -ExistingMembers $existingMembers -DryRun $WhatIfMode
                    switch ($action) {
                        "add" {
                            $totalOwnersAdded++
                            $channelOwnersAddedThis++
                            $actionRows += [PSCustomObject]@{ Team = $team.displayName; TeamId = $teamId; Scope = "Channel"; Channel = $channel.displayName; UserUpn = $u.userPrincipalName; UserId = $u.id; Action = "Add owner"; Mode = $mode }
                            if (-not $WhatIfMode) { "##       + Added owner '$($u.userPrincipalName)'" }
                        }
                        "promote" {
                            $totalPromoted++
                            $channelPromotedThis++
                            $actionRows += [PSCustomObject]@{ Team = $team.displayName; TeamId = $teamId; Scope = "Channel"; Channel = $channel.displayName; UserUpn = $u.userPrincipalName; UserId = $u.id; Action = "Promote to owner"; Mode = $mode }
                            if (-not $WhatIfMode) { "##       ~ Promoted '$($u.userPrincipalName)' to owner" }
                        }
                    }
                }
                catch {
                    "##       ! Failed to ensure owner '$($u.userPrincipalName)': $($_.Exception.Message)"
                    Write-RjRbLog -Message "Failed owner sync for '$($u.userPrincipalName)' in channel '$channelId': $_" -Verbose
                }
            }
        }
    }

    # Record per-team report row
    $teamReportRows += [PSCustomObject]@{
        Team                  = $team.displayName
        TeamId                = $teamId
        Visibility            = $team.visibility
        MatchedTeamName       = $me.TeamName
        OwnerGroupId          = $me.OwnerGroupId
        OwnerUserCount        = $ownerUsers.Count
        SharedChannels        = $teamChannelsThis
        TeamMembersAdded      = $teamMembersAddedThis
        TeamOwnersAdded       = $teamOwnersAddedThis
        ChannelOwnersAdded    = $channelOwnersAddedThis
        ChannelOwnersPromoted = $channelPromotedThis
        Status                = "Processed"
        Mode                  = $mode
    }
}

""
"## Done. Teams processed: $totalTeams | Shared channels processed: $totalChannels | Team owners added: $totalTeamOwnersAdded | Team members added: $totalTeamMembersAdded | Channel owners added: $totalOwnersAdded | Promoted to owner: $totalPromoted"
if ($WhatIfMode) {
    "## (WhatIf mode - counts reflect what WOULD have been changed.)"
}

#endregion

########################################################
#region     Report (email and/or download link)
##
########################################################

if ($SendEmailReport -or $CreateDownloadLink) {
    Write-Output ""
    Write-Output "## Preparing report..."

    # Tenant display name for the report footer/subject
    $tenantDisplayName = ""
    try {
        $org = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName"
        $tenantDisplayName = @($org.value).displayName | Select-Object -First 1
    }
    catch {
        Write-RjRbLog -Message "Could not resolve tenant display name: $_" -Verbose
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $basePath = (Get-Location).Path

    # Sort once so the CSV and XLSX exports use identical data
    $teamReportRows = @($teamReportRows | Sort-Object Team)
    $actionRows = @($actionRows | Sort-Object Team, Scope, Channel, UserUpn)

    $reportFiles = @()
    $xlsxPath = $null

    if ($ReportFileFormat -ne 'XLSX only') {
        # CSV 1: per-team summary
        $teamsCsvPath = Join-Path -Path $basePath -ChildPath "${timestamp}_SharedChannelOwners_Teams.csv"
        if ($teamReportRows.Count -gt 0) {
            $teamReportRows | Export-Csv -Path $teamsCsvPath -NoTypeInformation -Encoding UTF8
        }
        else {
            # Always produce a (header-only) file so the attachment/upload is present
            "" | Select-Object @{N = "Team"; E = { $_ } } | Where-Object { $false } | Export-Csv -Path $teamsCsvPath -NoTypeInformation -Encoding UTF8
        }
        $reportFiles += $teamsCsvPath

        # CSV 2: per-change detail
        $actionsCsvPath = Join-Path -Path $basePath -ChildPath "${timestamp}_SharedChannelOwners_Changes.csv"
        if ($actionRows.Count -gt 0) {
            $actionRows | Export-Csv -Path $actionsCsvPath -NoTypeInformation -Encoding UTF8
        }
        else {
            "" | Select-Object @{N = "Team"; E = { $_ } } | Where-Object { $false } | Export-Csv -Path $actionsCsvPath -NoTypeInformation -Encoding UTF8
        }
        $reportFiles += $actionsCsvPath
    }

    if ($ReportFileFormat -ne 'CSV only') {
        # XLSX: both datasets in a single Excel workbook (one worksheet per dataset) with an "Info" cover sheet.
        # Export-RjRbXlsx handles empty datasets itself (writes a "No data available" sheet).
        $xlsxPath = Join-Path -Path $basePath -ChildPath "${timestamp}_SharedChannelOwners_Report.xlsx"
        $workbookCoverSheet = [ordered]@{
            Title             = 'Shared Channel Owner Sync'
            Generated         = "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
            'Runbook Version' = $Version
            Mode              = $mode
            'Team rows'       = ($teamReportRows | Measure-Object).Count
            'Change rows'     = ($actionRows | Measure-Object).Count
        }
        Export-RjRbXlsx -Worksheets ([ordered]@{ 'Teams' = $teamReportRows; 'Changes' = $actionRows }) -Path $xlsxPath -CoverSheet $workbookCoverSheet
        $reportFiles += $xlsxPath
    }

    # Upload + download link (optional)
    $downloadLinks = @()
    if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
        Write-Output "## Uploading report to storage account..."
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
            $downloadLinks += [PSCustomObject]@{
                FileName = $uploadResult.BlobName
                SASLink  = $uploadResult.SASLink
                Expiry   = $uploadResult.EndTime
            }
            Write-Output "## Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }

    # Email report (optional)
    if ($SendEmailReport) {
        Write-Output "## Preparing email report for '$EmailTo'..."

        # Per-mapping team counts for the body
        $mappingSummaryLines = foreach ($me in $mappingEntries) {
            $cnt = @($teamReportRows | Where-Object { $_.MatchedTeamName -eq $me.TeamName -and $_.Status -eq "Processed" }).Count
            "| ``$($me.TeamName)`` | $($me.OwnerGroupId) | $cnt |"
        }

        $modeNote = if ($WhatIfMode) { "**WhatIf / dry run** - the figures below reflect changes that *would* have been made; nothing was written." } else { "Live run - the figures below reflect changes that were applied." }

        # Optional download-link section (when CreateDownloadLink produced links)
        $downloadSection = ""
        if ($downloadLinks.Count -gt 0) {
            $linkLines = foreach ($dl in $downloadLinks) {
                "- [$($dl.FileName)]($($dl.SASLink)) (expires $($dl.Expiry))"
            }
            $downloadSection = @"

## Download links

$($linkLines -join "`n")
"@
        }

        $markdownContent = @"
# Shared Channel Owner Sync

$modeNote

## Summary

| Metric | Value |
|---|---|
| Mode | $mode |
| Teams processed | $totalTeams |
| Shared channels processed | $totalChannels |
| Team owners added | $totalTeamOwnersAdded |
| Team members added | $totalTeamMembersAdded |
| Channel owners added | $totalOwnersAdded |
| Channel owners promoted | $totalPromoted |

## Mappings

| Team name | Owner group | Teams processed |
|---|---|---|
$($mappingSummaryLines -join "`n")
$downloadSection
## Attachments

$(if ($ReportFileFormat -ne 'XLSX only') { "- **$([IO.Path]::GetFileName($teamsCsvPath))** - one row per processed team (visibility, matched prefix, owner group, channel count, owners/members added/promoted)." })
$(if ($ReportFileFormat -ne 'XLSX only') { "- **$([IO.Path]::GetFileName($actionsCsvPath))** - one row per individual change (team/channel scope, user, action)." })
$(if ($ReportFileFormat -ne 'CSV only') { "- **$([IO.Path]::GetFileName($xlsxPath))** - both datasets as a formatted Excel workbook (Teams and Changes worksheets)." })

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $markdownFallback = @"
# Shared Channel Owner Sync

$modeNote

## Summary

| Metric | Value |
|---|---|
| Mode | $mode |
| Teams processed | $totalTeams |
| Shared channels processed | $totalChannels |
| Team owners added | $totalTeamOwnersAdded |
| Team members added | $totalTeamMembersAdded |
| Channel owners added | $totalOwnersAdded |
| Channel owners promoted | $totalPromoted |

## Attachments

- **$([IO.Path]::GetFileName($xlsxPath))** - both datasets as a formatted Excel workbook (Teams and Changes worksheets).

> **Note:** The CSV files were not attached because they exceed the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV files.

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $emailSubject = "Shared Channel Owner Sync - $totalTeams team(s), $totalChannels channel(s)$(if ($WhatIfMode) { ' [WhatIf]' }) - $tenantDisplayName".Trim()

        # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSVs are too large)
        Write-Output "Sending report to '$EmailTo'..."
        try {
            $guardParams = @{
                EmailFrom         = $EmailFrom
                EmailTo           = $EmailTo
                Subject           = $emailSubject
                MarkdownContent   = $markdownContent
                TenantDisplayName = $tenantDisplayName
                ReportVersion     = $Version
            }
            $guardParams.UseNativeGraphRequest = $true
            if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxPath) {
                Send-RjRbGuardedReportEmail @guardParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjRbGuardedReportEmail @guardParams -Attachments $reportFiles
            }
            Write-RjRbLog -Message "Email report sent to: $EmailTo" -Verbose
        }
        catch {
            Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
            throw
        }
    }
}

#endregion

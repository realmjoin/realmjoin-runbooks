<#
.SYNOPSIS
    Generate and email a comprehensive App Registration report

.DESCRIPTION
    This runbook generates a report of all Entra ID Application Registrations and deleted Application Registrations,
    exports them to CSV files, and sends them via email.

.PARAMETER EmailTo
    The recipient email address for the report. Must be a valid email format!

.PARAMETER EmailFrom
    The sender email address (optional, will use default if not specified)

.PARAMETER IncludeDeletedApps
    Whether to include deleted application registrations in the report (default: true)

.PARAMETER CallerName
    Internal parameter for tracking purposes

.INPUTS
    RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address"
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.30.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")]
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

$Version = "1.0.0"
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
if (-not $EmailTo -or -not $EmailFrom) {
    Write-RjRbLog -Message "Email addresses are required." -Verbose
    throw "Email addresses are required."
}

if ($IncludeDeletedApps -notin $true, $false) {
    Write-RjRbLog -Message "Invalid value for IncludeDeletedApps. Please specify true or false." -Verbose
    throw "Invalid value for IncludeDeletedApps. Please specify true or false."
}

########################################################
#region     Email Function Definitions
########################################################

function Send-RjReportEmail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EmailFrom,

        [Parameter(Mandatory = $true)]
        [string]$EmailTo,

        [Parameter(Mandatory = $true)]
        [string]$Subject,

        [Parameter(Mandatory = $true)]
        [string]$MarkdownContent,

        [string[]]$Attachments = @(),

        [string]$TenantDisplayName = "Your Organization",

        [string]$ReportVersion
    )

    # Convert Markdown to HTML (inlined conversion - function removed as it's used only here)
    $html = $MarkdownContent

    # Headers (process in order from most specific to least specific)
    $html = $html -replace '(?m)^##### (.+)$', '<h5>$1</h5>'
    $html = $html -replace '(?m)^#### (.+)$', '<h4>$1</h4>'
    $html = $html -replace '(?m)^### (.+)$', '<h3>$1</h3>'
    $html = $html -replace '(?m)^## (.+)$', '<h2>$1</h2>'
    $html = $html -replace '(?m)^# (.+)$', '<h1>$1</h1>'

    # Bold and Italic
    $html = $html -replace '\*\*(.+?)\*\*', '<strong>$1</strong>'
    $html = $html -replace '\*(.+?)\*', '<em>$1</em>'

    # Code blocks and inline code
    $html = $html -replace '(?s)```(.+?)```', '<pre><code>$1</code></pre>'
    $html = $html -replace '`(.+?)`', '<code>$1</code>'

    # Tables
    $lines = $html -split "`n"
    $inTable = $false
    $processedLines = @()

    for ($i = 0; $i -lt (($(($lines) | Measure-Object).Count)); $i++) {
        $line = $lines[$i]

        if ($line -match '^\|.*\|$') {
            if (-not $inTable) {
                $processedLines += '<table>'
                $inTable = $true
                # Check if next line is separator
                if ($i + 1 -lt (($(($lines) | Measure-Object).Count)) -and $lines[$i + 1] -match '^\|[-\s\|]+\|$') {
                    # This is a header row
                    $cells = ($line -replace '^\|', '' -replace '\|$', '').Split('|') | ForEach-Object { $_.Trim() }
                    $processedLines += '<thead><tr>'
                    foreach ($cell in $cells) {
                        $processedLines += "<th>$cell</th>"
                    }
                    $processedLines += '</tr></thead><tbody>'
                    $i++ # Skip separator line
                    continue
                }
            }

            # Regular table row
            $cells = ($line -replace '^\|', '' -replace '\|$', '').Split('|') | ForEach-Object { $_.Trim() }
            $processedLines += '<tr>'
            foreach ($cell in $cells) {
                $processedLines += "<td>$cell</td>"
            }
            $processedLines += '</tr>'
        }
        else {
            if ($inTable) {
                $processedLines += '</tbody></table>'
                $inTable = $false
            }
            $processedLines += $line
        }
    }

    if ($inTable) {
        $processedLines += '</tbody></table>'
    }

    $html = $processedLines -join "`n"

    # Lists (simple)
    $html = $html -replace '(?m)^- (.+)$', '<li>$1</li>'
    $html = $html -replace '(?m)^(\d+)\. (.+)$', '<li>$2</li>'

    # Wrap consecutive <li> tags in <ul> or <ol>
    $html = $html -replace '((?:<li>.*?</li>\s*)+)', "<ul>`n`$1</ul>"
    # This is a simplification; it doesn't distinguish between ordered and unordered lists based on original markdown.

    # Paragraphs: Wrap remaining lines that are not part of other elements in <p> tags.
    $blocks = $html -split "(?=<h[1-6]>|<ul>|<ol>|<table>|<pre>|<blockquote>)"
    $html = ""
    foreach ($block in $blocks) {
        if ($block.Trim() -eq "") { continue }

        if ($block -match "^<(h[1-6]|ul|ol|table|pre|blockquote)") {
            $html += $block
        }
        else {
            # Wrap lines in paragraphs
            $lines = $block.Trim() -split '\r?\n'
            foreach ($line in $lines) {
                if ($line.Trim() -ne "") {
                    $html += "<p>$line</p>"
                }
            }
        }
    }

    $htmlContent = $html

    $plainBase64Logo_light = "PHN2ZyBpZD0iUmVhbG1qb2luIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxOTEgNTUiPjxkZWZzPjxzdHlsZT4uY2xzLTF7ZmlsbDojM2YzZjNmO30uY2xzLTJ7ZmlsbDojZjg4NDJjO30uY2xzLTN7ZmlsbDojZmZmO308L3N0eWxlPjwvZGVmcz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik00OS43Nyw0Mi40NmEuMzcuMzcsMCwwLDEtLjEyLS4yOVYyMy40N2ExLDEsMCwwLDEsLjMxLS43NCwxLDEsMCwwLDEsLjc0LS4zMWg1YTUuODYsNS44NiwwLDAsMSw1LjExLDIuOTIsNS43Nyw1Ljc3LDAsMCwxLC43OCwyLjk0QTUuNjQsNS42NCwwLDAsMSw2MC4zLDMyYTUuNzQsNS43NCwwLDAsMS0zLjM3LDJsNC44Miw3Ljc3YS41Mi41MiwwLDAsMSwuMDguMjkuNDkuNDksMCwwLDEtLjE2LjM4LjU2LjU2LDAsMCwxLS4zOS4xNEg1OS44YS40Ni40NiwwLDAsMS0uNDMtLjI2bC01LjA4LTguMjFINTJ2OC4wNmEuNC40LDAsMCwxLS4xMS4yOS40MS40MSwwLDAsMS0uMy4xMkg1MC4wNkEuMzguMzgsMCwwLDEsNDkuNzcsNDIuNDZabTUuOC0xMC41OGEzLjUyLDMuNTIsMCwwLDAsMi41OS0xLDMuNCwzLjQsMCwwLDAsMS0yLjU1LDMuNTMsMy41MywwLDAsMC0xLTIuNjIsMy40OSwzLjQ5LDAsMCwwLTIuNTktMUg1MnY3LjIyWiIvPjxwYXRoIGNsYXNzPSJjbHMtMSIgZD0iTTY2LjkxLDQxLjc0YTYuMTIsNi4xMiwwLDAsMS0yLjI5LTIuMzEsNi4yNCw2LjI0LDAsMCwxLS44NC0zLjE3VjMyLjExYTYuMjQsNi4yNCwwLDAsMSwuODQtMy4xNyw2LjIzLDYuMjMsMCwwLDEsNS40NS0zLjE1LDYuMiw2LjIsMCwwLDEsMy4xNi44NCw2LjEyLDYuMTIsMCwwLDEsMi4yOSwyLjMxLDYuMjQsNi4yNCwwLDAsMSwuODQsMy4xN3YyYTEsMSwwLDAsMS0uMy43NCwxLDEsMCwwLDEtLjc0LjMxSDY2VjM2LjRhNCw0LDAsMCwwLC41MywyQTQsNCwwLDAsMCw2OCwzOS45YTQsNCwwLDAsMCwyLC41M2g0LjJhLjM3LjM3LDAsMCwxLC4yOS4xMi4zOC4zOCwwLDAsMSwuMTIuMjl2MS4zM2EuNDEuNDEsMCwwLDEtLjQxLjQxaC00LjJBNi4xOCw2LjE4LDAsMCwxLDY2LjkxLDQxLjc0Wk03NC4xLDMzVjMyYTMuOTMsMy45MywwLDAsMC0uNTQtMiwzLjg5LDMuODksMCwwLDAtMS40Ni0xLjQ3LDQsNCwwLDAsMC01LjUzLDEuNDdBNCw0LDAsMCwwLDY2LDMyVjMzWiIvPjxwYXRoIGNsYXNzPSJjbHMtMSIgZD0iTTc5LjQ2LDQxLjdhNC41Nyw0LjU3LDAsMCwxLS4xMy02LjQ5LDYuMjcsNi4yNywwLDAsMSwzLjYxLTEuNTZsMy43Ny0uNTJhMS44NSwxLjg1LDAsMCwwLDEuMjItLjU3LDIsMiwwLDAsMCwuMzgtMS4yOVYzMWEyLjcxLDIuNzEsMCwwLDAtMS4wOS0yLjI1LDQuMjQsNC4yNCwwLDAsMC0yLjcxLS44NSw0LjYsNC42LDAsMCwwLTIuMjIuNSwzLjg5LDMuODksMCwwLDAtMS40OSwxLjQxLjY5LjY5LDAsMCwxLS41OC4zOC42Ni42NiwwLDAsMS0uMzgtLjE1bC0uNzgtLjUyYS42NS42NSwwLDAsMS0uMjYtLjQ5Ljc1Ljc1LDAsMCwxLC4wOC0uMjksNiw2LDAsMCwxLDIuMzEtMi4xOSw2Ljg3LDYuODcsMCwwLDEsMy4zOC0uOCw3LjE2LDcuMTYsMCwwLDEsMy4xLjY1LDQuOTEsNC45MSwwLDAsMSwyLjEsMS44NEE1LjA3LDUuMDcsMCwwLDEsOTAuNTEsMzFWNDIuMTdhLjM5LjM5LDAsMCwxLS40LjQxSDg4Ljg5YS4zOC4zOCwwLDAsMS0uMjktLjEyLjM3LjM3LDAsMCwxLS4xMi0uMjl2LTJhNi4zOSw2LjM5LDAsMCwxLTIuMywyLDYuNTIsNi41MiwwLDAsMS0zLjA2Ljc0QTUuMzIsNS4zMiwwLDAsMSw3OS40Niw0MS43Wm02LjQ3LTEuNTNhNS4zOSw1LjM5LDAsMCwwLDEuODEtMS45QTQuNDYsNC40NiwwLDAsMCw4OC40LDM2VjM0Ljg0bC00LjQ3LjYxLS44MS4xMWMtMS45My4yOS0yLjksMS4yLTIuOSwyLjczYTIuMzYsMi4zNiwwLDAsMCwuODcsMS45MSwzLjM3LDMuMzcsMCwwLDAsMi4yNi43M0E0LjU3LDQuNTcsMCwwLDAsODUuOTMsNDAuMTdaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNOTUuNTIsNDIuMjhhMSwxLDAsMCwxLS4zMS0uNzRWMjIuNzFoLTIuN2EuMzkuMzksMCwwLDEtLjI5LS4xMS40NC40NCwwLDAsMS0uMTEtLjI5VjIxYS4zOS4zOSwwLDAsMSwuMTEtLjI4LjQuNCwwLDAsMSwuMjktLjEyaDMuOTJhMSwxLDAsMCwxLC43NC4zLDEsMSwwLDAsMSwuMy43NFY0MC40M2gzLjA4YS40LjQsMCwwLDEsLjI5LjEyLjQyLjQyLDAsMCwxLC4xMS4yOXYxLjMzYS4zOS4zOSwwLDAsMS0uNC40MUg5Ni4yNkExLDEsMCwwLDEsOTUuNTIsNDIuMjhaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMTAzLjM5LDQyLjQ2YS4zNy4zNywwLDAsMS0uMTItLjI5VjI2LjU3YS40LjQsMCwwLDEsLjEyLS4yOS40Mi40MiwwLDAsMSwuMjktLjExaDEuNDVhLjQyLjQyLDAsMCwxLC4yOS4xMS4zOS4zOSwwLDAsMSwuMTEuMjl2MS41N2E0LjY3LDQuNjcsMCwwLDEsMS44NS0xLjc2LDUuNDgsNS40OCwwLDAsMSwyLjUzLS41OSw1LjgxLDUuODEsMCwwLDEsMy4xOC44NUE0Ljc3LDQuNzcsMCwwLDEsMTE1LDI5YTQuNzEsNC43MSwwLDAsMSwxLjg4LTIuMzUsNS4zLDUuMywwLDAsMSwyLjktLjgxLDUuNDEsNS40MSwwLDAsMSw0LDEuNTEsNS4zMSw1LjMxLDAsMCwxLDEuNTIsNFY0Mi4xN2EuMzkuMzksMCwwLDEtLjQuNDFoLTEuNDVhLjQxLjQxLDAsMCwxLS40MS0uNDFWMzEuNzNhMy44LDMuOCwwLDAsMC0xLTIuODIsMy41NCwzLjU0LDAsMCwwLTIuNjMtMSwzLjY3LDMuNjcsMCwwLDAtMi45MSwxLjI3LDUuMTcsNS4xNywwLDAsMC0xLjEyLDMuNTF2OS40NWEuMzkuMzksMCwwLDEtLjQuNDFoLTEuNDVhLjQxLjQxLDAsMCwxLS40MS0uNDFWMzEuNzFhMy44MywzLjgzLDAsMCwwLTEtMi44MywzLjUzLDMuNTMsMCwwLDAtMi42Mi0xLDMuNywzLjcsMCwwLDAtMi45MiwxLjI3LDUuMTcsNS4xNywwLDAsMC0xLjEyLDMuNTF2OS40OGEuMzYuMzYsMCwwLDEtLjExLjI5LjM4LjM4LDAsMCwxLS4yOS4xMmgtMS40NUEuMzguMzgsMCwwLDEsMTAzLjM5LDQyLjQ2WiIvPjxwYXRoIGNsYXNzPSJjbHMtMSIgZD0iTTEyNy4zMSw0Mi40NmEuNDMuNDMsMCwwLDEtLjExLS4zMVY0MC44MWEuMzkuMzksMCwwLDEsLjQzLS40M2gxLjcxYTIuMiwyLjIsMCwwLDAsMS42NC0uNjQsMi4zNCwyLjM0LDAsMCwwLC42My0xLjcxVjIyLjgzYS4zOC4zOCwwLDAsMSwuMTEtLjI5LjQuNCwwLDAsMSwuMjktLjEyaDEuNTdhLjQuNCwwLDAsMSwuMjkuMTIuNDIuNDIsMCwwLDEsLjExLjI5VjM4LjA2YTUsNSwwLDAsMS0uNTIsMi4yNkE0LDQsMCwwLDEsMTMyLDQyYTQuMjcsNC4yNywwLDAsMS0yLjMyLjYxaC0yQS40NC40NCwwLDAsMSwxMjcuMzEsNDIuNDZaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMTQwLDQyLjEyYTYuMTksNi4xOSwwLDAsMS0yLjI5LTIuMzEsNi4yOCw2LjI4LDAsMCwxLS44NC0zLjE4VjMyLjExYTYuMyw2LjMsMCwxLDEsMTIuNTksMHY0LjUyYTYuMjgsNi4yOCwwLDAsMS0uODQsMy4xOEE2LjMyLDYuMzIsMCwwLDEsMTQwLDQyLjEyWm01LjItMS44NWEzLjkzLDMuOTMsMCwwLDAsMS40Ni0xLjQ2LDQsNCwwLDAsMCwuNTQtMlYzMmEzLjkzLDMuOTMsMCwwLDAtLjU0LTIsNCw0LDAsMCwwLTEuNDYtMS40Nyw0LDQsMCwwLDAtMi0uNTMsMy45MiwzLjkyLDAsMCwwLTIsLjUzLDQsNCwwLDAsMC0xLjQ3LDEuNDcsMy45MiwzLjkyLDAsMCwwLS41MywydjQuODFhNCw0LDAsMCwwLC41MywyLDMuODksMy44OSwwLDAsMCwxLjQ3LDEuNDYsMy45MywzLjkzLDAsMCwwLDIsLjU0QTQsNCwwLDAsMCwxNDUuMjEsNDAuMjdaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMTU0LjM1LDQyLjI4YTEsMSwwLDAsMS0uMy0uNzRWMjguMzFoLTNhLjM4LjM4LDAsMCwxLS40LS40VjI2LjU3YS4zOC4zOCwwLDAsMSwuNC0uNGg0LjI0YTEsMSwwLDAsMSwuNzQuMywxLDEsMCwwLDEsLjMuNzRWNDAuNDNoM2EuNDEuNDEsMCwwLDEsLjQxLjQxdjEuMzNhLjM3LjM3LDAsMCwxLS4xMi4yOS4zOC4zOCwwLDAsMS0uMjkuMTJoLTQuMjFBMSwxLDAsMCwxLDE1NC4zNSw0Mi4yOFptLS4xNS0xOC40OWEuNC40LDAsMCwxLS4xMi0uMjlWMjFhLjM2LjM2LDAsMCwxLC4xMi0uMjguMzcuMzcsMCwwLDEsLjI5LS4xMmgxLjM5YS40LjQsMCwwLDEsLjI5LjEyLjM5LjM5LDAsMCwxLC4xMS4yOFYyMy41YS40NC40NCwwLDAsMS0uMTEuMjkuMzkuMzksMCwwLDEtLjI5LjExaC0xLjM5QS4zNi4zNiwwLDAsMSwxNTQuMiwyMy43OVoiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik0xNjIuMjksNDIuNDRhLjQuNCwwLDAsMS0uMTItLjI5VjI2LjU3YS4zOS4zOSwwLDAsMSwuNDEtLjRIMTY0YS4zOC4zOCwwLDAsMSwuNC40djEuNmE1LDUsMCwwLDEsMi0xLjgsNS44Nyw1Ljg3LDAsMCwxLDIuNzEtLjYxLDUuNDIsNS40MiwwLDAsMSw0LDEuNTEsNS4zNSw1LjM1LDAsMCwxLDEuNTIsNFY0Mi4xNWEuMzguMzgsMCwwLDEtLjQuNGgtMS40NWEuMzkuMzksMCwwLDEtLjQxLS40VjMxLjY4YTMuODMsMy44MywwLDAsMC0xLTIuODMsMy41NCwzLjU0LDAsMCwwLTIuNjMtMSw0LjA4LDQuMDgsMCwwLDAtMy4xMywxLjI3LDUsNSwwLDAsMC0xLjE5LDMuNTF2OS40OWEuMzguMzgsMCwwLDEtLjQuNGgtMS40NUEuNC40LDAsMCwxLDE2Mi4yOSw0Mi40NFoiLz48cG9seWdvbiBjbGFzcz0iY2xzLTIiIHBvaW50cz0iNi43NiAxIDM2LjI0IDE1IDQxIDQ2IDIgMzkgNi43NiAxIi8+PHBhdGggY2xhc3M9ImNscy0zIiBkPSJNNC40MSw0Mi44OGEuNzQuNzQsMCwwLDEtLjIzLS41N1YxNy41N2ExLjYxLDEuNjEsMCwwLDEsMS42My0xLjYzaDcuMTFBOC40OSw4LjQ5LDAsMCwxLDE3LjE3LDE3YTguMjksOC4yOSwwLDAsMSwzLjA4LDMsOC4xMiw4LjEyLDAsMCwxLS40OSw5QTguMjEsOC4yMSwwLDAsMSwxNS41LDMybDYuMzEsOS43N2ExLjA3LDEuMDcsMCwwLDEsLjE1LjUzLjc1Ljc1LDAsMCwxLS4yNC41Ny45Mi45MiwwLDAsMS0uNjMuMjNIMThhMS4xMiwxLjEyLDAsMCwxLTEtLjUzbC02LjMtMTAuMTVIOC44MXY5Ljg4YS43Ny43NywwLDAsMS0uMjIuNTcuODEuODEsMCwwLDEtLjU3LjIzSDVBLjc4Ljc4LDAsMCwxLDQuNDEsNDIuODhabTguMjgtMTQuODJBNCw0LDAsMCwwLDE1LjU2LDI3YTMuNjcsMy42NywwLDAsMCwxLjEyLTIuNzYsMy43NywzLjc3LDAsMCwwLTEuMTItMi44MSwzLjk0LDMuOTQsMCwwLDAtMi44Ny0xLjFIOC44MXY3Ljc1WiIvPjxwYXRoIGNsYXNzPSJjbHMtMyIgZD0iTTIzLjQ0LDQyLjg4YS43Ny43NywwLDAsMS0uMjItLjU3VjM5LjU0YS43Ny43NywwLDAsMSwuNzktLjhoMi44MmEyLDIsMCwwLDAsMS41LS41OSwyLjMsMi4zLDAsMCwwLC41NS0xLjYyVjE2Ljc0YS43OS43OSwwLDAsMSwuOC0uOGgzYS43Ny43NywwLDAsMSwuNzkuOFYzNi41M2E3LDcsMCwwLDEtLjgxLDMuMzcsNi4wOCw2LjA4LDAsMCwxLTIuMjYsMi4zNSw2LjM0LDYuMzQsMCwwLDEtMy4yNy44NkgyNEEuODEuODEsMCwwLDEsMjMuNDQsNDIuODhaIi8+PC9zdmc+"

    $plainBase64Logo_dark = "PHN2ZyBpZD0iTGF5ZXJfMSIgZGF0YS1uYW1lPSJMYXllciAxIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxOTEiIGhlaWdodD0iNDcuOSI+PGRlZnM+PHN0eWxlPi5jbHMtMXtmaWxsOiNmZmY7fS5jbHMtMntmaWxsOiNmODg0MmM7fTwvc3R5bGU+PC9kZWZzPjxwYXRoIGNsYXNzPSJjbHMtMSIgZD0iTTQ4LjgyLDQyLjc1YS40NC40NCwwLDAsMS0uMTEtLjI5VjIzLjc1QTEsMSwwLDAsMSw0OSwyM2ExLDEsMCwwLDEsLjc0LS4zaDVhNS44Miw1LjgyLDAsMCwxLDUuODgsNS44Niw1LjYsNS42LDAsMCwxLTEuMzMsMy43MSw1Ljc1LDUuNzUsMCwwLDEtMy4zNiwybDQuODEsNy43N2EuNDguNDgsMCwwLDEsLjA5LjI5LjUxLjUxLDAsMCwxLS4xNi4zOC41NS41NSwwLDAsMS0uMzkuMTRINTguODZhLjQ2LjQ2LDAsMCwxLS40NC0uMjZsLTUuMDctOC4ySDUxLjA4djguMDZhLjM5LjM5LDAsMCwxLS4xMS4yOS4zOC4zOCwwLDAsMS0uMjkuMTFINDkuMTFBLjM5LjM5LDAsMCwxLDQ4LjgyLDQyLjc1Wm01LjgtMTAuNTlhMy41NCwzLjU0LDAsMCwwLDIuNi0xLDMuNDcsMy40NywwLDAsMCwxLTIuNTUsMy41OSwzLjU5LDAsMCwwLTEtMi42MywzLjU1LDMuNTUsMCwwLDAtMi42LTFINTEuMDh2Ny4yMloiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik02Niw0MmE2LjE2LDYuMTYsMCwwLDEtMi4yOS0yLjMsNi4zLDYuMywwLDAsMS0uODQtMy4xOFYzMi40YTYuMyw2LjMsMCwwLDEsLjg0LTMuMThBNi4zLDYuMywwLDAsMSw3NS40MiwzMi40djJhMSwxLDAsMCwxLS4zMS43NCwxLDEsMCwwLDEtLjc0LjNINjUuMDl2MS4yOGE0LDQsMCwwLDAsLjU0LDIsMy45MywzLjkzLDAsMCwwLDEuNDYsMS40Niw0LDQsMCwwLDAsMiwuNTRoNC4yMWEuMzguMzgsMCwwLDEsLjQuNHYxLjM0YS40NC40NCwwLDAsMS0uMTEuMjkuMzkuMzksMCwwLDEtLjI5LjExSDY5LjEyQTYuMiw2LjIsMCwwLDEsNjYsNDJabTcuMTktOC43VjMyLjI1YTQuMDcsNC4wNywwLDAsMC0uNTMtMiwzLjg5LDMuODksMCwwLDAtMS40Ny0xLjQ2LDQuMDksNC4wOSwwLDAsMC00LjA2LDAsMy44NiwzLjg2LDAsMCwwLTEuNDYsMS40Niw0LDQsMCwwLDAtLjU0LDJ2MS4wN1oiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik03OC41Miw0MmE0LjU1LDQuNTUsMCwwLDEtLjEzLTYuNDhBNi4zMSw2LjMxLDAsMCwxLDgyLDMzLjkzbDMuNzctLjUyQTEuODcsMS44NywwLDAsMCw4NywzMi44NWEyLDIsMCwwLDAsLjM3LTEuMjl2LS4yNGEyLjcyLDIuNzIsMCwwLDAtMS4wOC0yLjI0LDQuMjcsNC4yNywwLDAsMC0yLjcyLS44Niw0LjU0LDQuNTQsMCwwLDAtMi4yMS41MSwzLjg5LDMuODksMCwwLDAtMS41LDEuNC42Ni42NiwwLDAsMS0uNTguMzguNjkuNjksMCwwLDEtLjM3LS4xNGwtLjc5LS41M2EuNTYuNTYsMCwwLDEtLjE3LS43OCw2LDYsMCwwLDEsMi4zLTIuMTksNy42LDcuNiwwLDAsMSw2LjQ5LS4xNCw0Ljg0LDQuODQsMCwwLDEsMi4xLDEuODQsNS4xMiw1LjEyLDAsMCwxLC43NCwyLjc1VjQyLjQ2YS40LjQsMCwwLDEtLjEyLjI5LjM4LjM4LDAsMCwxLS4yOS4xMUg4Ny45NGEuMzkuMzksMCwwLDEtLjI5LS4xMS40NC40NCwwLDAsMS0uMTEtLjI5di0yYTYuMyw2LjMsMCwwLDEtMi4zMSwyLDYuNDEsNi40MSwwLDAsMS0zLjA2Ljc0QTUuMjksNS4yOSwwLDAsMSw3OC41Miw0MlpNODUsNDAuNDZhNS41Nyw1LjU3LDAsMCwwLDEuODEtMS45LDQuNTgsNC41OCwwLDAsMCwuNjUtMi4yNVYzNS4xMkw4MywzNS43M2wtLjgxLjEyYy0xLjkzLjI5LTIuOSwxLjItMi45LDIuNzJhMi4zOCwyLjM4LDAsMCwwLC44NywxLjkyLDMuNDQsMy40NCwwLDAsMCwyLjI2LjcyQTQuNjksNC42OSwwLDAsMCw4NSw0MC40NloiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik05NC41Nyw0Mi41NmExLDEsMCwwLDEtLjMtLjc0VjIzaC0yLjdhLjM4LjM4LDAsMCwxLS4yOS0uMTIuMzcuMzcsMCwwLDEtLjEyLS4yOVYyMS4yNmEuNDEuNDEsMCwwLDEsLjQxLS40MWgzLjkxYTEsMSwwLDAsMSwuNzQuMzEsMSwxLDAsMCwxLC4zMS43NFY0MC43Mkg5OS42YS40Mi40MiwwLDAsMSwuMjkuMTEuNC40LDAsMCwxLC4xMi4yOXYxLjM0YS40LjQsMCwwLDEtLjEyLjI5LjM4LjM4LDAsMCwxLS4yOS4xMUg5NS4zMUExLDEsMCwwLDEsOTQuNTcsNDIuNTZaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMTAyLjQ0LDQyLjc1YS40NC40NCwwLDAsMS0uMTEtLjI5VjI2Ljg2YS4zOS4zOSwwLDAsMSwuNC0uNDFoMS40NWEuMzguMzgsMCwwLDEsLjI5LjEyLjM3LjM3LDAsMCwxLC4xMi4yOXYxLjU2YTQuNTUsNC41NSwwLDAsMSwxLjg0LTEuNzUsNS4zOCw1LjM4LDAsMCwxLDIuNTQtLjYsNS43OCw1Ljc4LDAsMCwxLDMuMTcuODYsNC43OSw0Ljc5LDAsMCwxLDEuOTMsMi4zM0E0Ljg3LDQuODcsMCwwLDEsMTE2LDI2LjkxYTUuMjgsNS4yOCwwLDAsMSwyLjktLjgxLDUuNDIsNS40MiwwLDAsMSw0LDEuNTEsNS4zMyw1LjMzLDAsMCwxLDEuNTMsNFY0Mi40NmEuNC40LDAsMCwxLS4xMi4yOS4zOC4zOCwwLDAsMS0uMjkuMTFoLTEuNDVhLjM4LjM4LDAsMCwxLS4yOS0uMTEuNC40LDAsMCwxLS4xMi0uMjlWMzJhMy44MywzLjgzLDAsMCwwLTEtMi44MywzLjUzLDMuNTMsMCwwLDAtMi42Mi0xLDMuNzEsMy43MSwwLDAsMC0yLjkyLDEuMjgsNS4xNiw1LjE2LDAsMCwwLTEuMTEsMy41djkuNDZhLjQuNCwwLDAsMS0uMTIuMjkuMzguMzgsMCwwLDEtLjI5LjExaC0xLjQ1YS4zOC4zOCwwLDAsMS0uNC0uNFYzMmEzLjgzLDMuODMsMCwwLDAtMS0yLjgzLDMuNTYsMy41NiwwLDAsMC0yLjYyLTEsMy42OCwzLjY4LDAsMCwwLTIuOTEsMS4yOEE1LjEyLDUuMTIsMCwwLDAsMTA0LjU5LDMzdjkuNDhhLjQuNCwwLDAsMS0uMTIuMjkuMzguMzgsMCwwLDEtLjI5LjExaC0xLjQ1QS4zOS4zOSwwLDAsMSwxMDIuNDQsNDIuNzVaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMTI2LjM3LDQyLjc1YS40NC40NCwwLDAsMS0uMTItLjMyVjQxLjFhLjQxLjQxLDAsMCwxLC40NC0uNDRoMS43MUEyLjE5LDIuMTksMCwwLDAsMTMwLDQwYTIuMzUsMi4zNSwwLDAsMCwuNjItMS43MVYyMy4xMmEuMzkuMzksMCwwLDEsLjQtLjQxaDEuNTdhLjM4LjM4LDAsMCwxLC4yOS4xMi4zNy4zNywwLDAsMSwuMTIuMjlWMzguMzRhNS4wNyw1LjA3LDAsMCwxLS41MiwyLjI2QTQuMSw0LjEsMCwwLDEsMTMxLDQyLjI2YTQuMzgsNC4zOCwwLDAsMS0yLjMyLjZoLTJBLjQuNCwwLDAsMSwxMjYuMzcsNDIuNzVaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMTM5LjA3LDQyLjRhNi4xNiw2LjE2LDAsMCwxLTIuMjktMi4zLDYuMyw2LjMsMCwwLDEtLjg0LTMuMThWMzIuNGE2LjMsNi4zLDAsMCwxLC44NC0zLjE4LDYuMjgsNi4yOCwwLDAsMSwxMC45LDAsNi4zLDYuMywwLDAsMSwuODQsMy4xOHY0LjUyYTYuMyw2LjMsMCwwLDEtLjg0LDMuMTgsNi4zMiw2LjMyLDAsMCwxLTguNjEsMi4zWm01LjE5LTEuODRhNCw0LDAsMCwwLDEuNDctMS40Niw0LjA4LDQuMDgsMCwwLDAsLjUzLTJWMzIuMjVhNC4wNyw0LjA3LDAsMCwwLS41My0yLDMuODksMy44OSwwLDAsMC0xLjQ3LTEuNDYsNC4wOSw0LjA5LDAsMCwwLTQuMDYsMCwzLjc5LDMuNzksMCwwLDAtMS40NiwxLjQ2LDQsNCwwLDAsMC0uNTQsMnY0LjgxYTQsNCwwLDAsMCwuNTQsMiwzLjkzLDMuOTMsMCwwLDAsMS40NiwxLjQ2LDQuMDksNC4wOSwwLDAsMCw0LjA2LDBaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMTUzLjQxLDQyLjU2YTEsMSwwLDAsMS0uMzEtLjc0VjI4LjZoLTNhLjQxLjQxLDAsMCwxLS40MS0uNDFWMjYuODZhLjM3LjM3LDAsMCwxLC4xMi0uMjkuMzguMzgsMCwwLDEsLjI5LS4xMmg0LjIzYTEsMSwwLDAsMSwuNzQuMzEsMSwxLDAsMCwxLC4zMS43M1Y0MC43MmgzYS4zOS4zOSwwLDAsMSwuNDEuNHYxLjM0YS40LjQsMCwwLDEtLjEyLjI5LjM2LjM2LDAsMCwxLS4yOS4xMWgtNC4yQTEsMSwwLDAsMSwxNTMuNDEsNDIuNTZabS0uMTYtMTguNDlhLjM3LjM3LDAsMCwxLS4xMi0uMjlWMjEuMjZhLjQxLjQxLDAsMCwxLC40MS0uNDFoMS4zOWEuNDEuNDEsMCwwLDEsLjQxLjQxdjIuNTJhLjM3LjM3LDAsMCwxLS4xMi4yOS4zOC4zOCwwLDAsMS0uMjkuMTJoLTEuMzlBLjM4LjM4LDAsMCwxLDE1My4yNSwyNC4wN1oiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik0xNjEuMzQsNDIuNzJhLjM4LjM4LDAsMCwxLS4xMS0uMjlWMjYuODZhLjM2LjM2LDAsMCwxLC4xMS0uMjkuNC40LDAsMCwxLC4yOS0uMTJoMS40NWEuMzguMzgsMCwwLDEsLjI5LjEyLjM3LjM3LDAsMCwxLC4xMi4yOXYxLjU5YTUsNSwwLDAsMSwxLjk1LTEuOCw2LDYsMCwwLDEsMi43Mi0uNjEsNS40Miw1LjQyLDAsMCwxLDQsMS41MSw1LjM0LDUuMzQsMCwwLDEsMS41Myw0djEwLjlhLjQxLjQxLDAsMCwxLS40MS40MWgtMS40NWEuNDEuNDEsMCwwLDEtLjQxLS40MVYzMmEzLjgzLDMuODMsMCwwLDAtMS0yLjgzLDMuNTcsMy41NywwLDAsMC0yLjYyLTEsNC4wNyw0LjA3LDAsMCwwLTMuMTMsMS4yOEE0LjkxLDQuOTEsMCwwLDAsMTYzLjQ5LDMzdjkuNDhhLjQxLjQxLDAsMCwxLS40MS40MWgtMS40NUEuNC40LDAsMCwxLDE2MS4zNCw0Mi43MloiLz48cG9seWdvbiBjbGFzcz0iY2xzLTIiIHBvaW50cz0iNS44MSAxLjI4IDM1LjMgMTUuMjkgNDAuMDUgNDYuMjggMS4wNSAzOS4yOCA1LjgxIDEuMjgiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik0zLjQ2LDQzLjE2YS43OC43OCwwLDAsMS0uMjMtLjU3VjE3Ljg2YTEuNTUsMS41NSwwLDAsMSwuNDgtMS4xNiwxLjU1LDEuNTUsMCwwLDEsMS4xNi0uNDhIMTJhOC41LDguNSwwLDAsMSw0LjI2LDEuMSw4LjM5LDguMzksMCwwLDEsMy4wOCwzLDguMDgsOC4wOCwwLDAsMS0uNSw5LDguMyw4LjMsMCwwLDEtNC4yNSwyLjk1bDYuMyw5Ljc2YTEsMSwwLDAsMSwuMTYuNTMuNzYuNzYsMCwwLDEtLjI1LjU3Ljg2Ljg2LDAsMCwxLS42My4yM0gxN2ExLjEsMS4xLDAsMCwxLTEtLjUzTDkuNzMsMzIuNzFINy44N3Y5Ljg4YS43OC43OCwwLDAsMS0uMjMuNTcuNzQuNzQsMCwwLDEtLjU3LjIzSDRBLjc0Ljc0LDAsMCwxLDMuNDYsNDMuMTZabTguMjgtMTQuODJhNCw0LDAsMCwwLDIuODctMS4wOCwzLjY1LDMuNjUsMCwwLDAsMS4xMi0yLjc1LDMuNzksMy43OSwwLDAsMC0xLjEyLTIuODIsMy45MiwzLjkyLDAsMCwwLTIuODctMS4xSDcuODd2Ny43NVoiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik0yMi41LDQzLjE2YS43OC43OCwwLDAsMS0uMjMtLjU3VjM5LjgyYS43OS43OSwwLDAsMSwuOC0uOGgyLjgxYTEuOTQsMS45NCwwLDAsMCwxLjUtLjU5LDIuMjUsMi4yNSwwLDAsMCwuNTUtMS42MVYxN2EuNzkuNzksMCwwLDEsLjgtLjhoM2EuNzkuNzksMCwwLDEsLjguOHYxOS44YTYuODUsNi44NSwwLDAsMS0uODIsMy4zNiw2LDYsMCwwLDEtMi4yNiwyLjM2LDYuMjgsNi4yOCwwLDAsMS0zLjI3Ljg1SDIzLjA3QS43NC43NCwwLDAsMSwyMi41LDQzLjE2WiIvPjwvc3ZnPg=="

    # Create data URIs for both logos
    $base64RJLogoLight = "data:image/svg+xml;base64,$($plainBase64Logo_light)"
    $base64RJLogoDark = "data:image/svg+xml;base64,$($plainBase64Logo_dark)"

    # Create RealmJoin-branded HTML email template
    $htmlBody = @"
<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="color-scheme" content="light">
    <meta name="supported-color-schemes" content="light">
    <title>$Subject</title>
    <!--[if !mso]><!-->
    <style>
        :root {
            --rj-orange: #f8842c;
            --rj-midnight: #011e33;
            --rj-light-gray: #f8f9fa;
            --rj-white: #ffffff;
            --rj-text-color: #333;
            --rj-border-color: #e1e5e9;
        }

        /* Light mode specific rules - default and explicit */
        .header {
            background: linear-gradient(135deg, #1e40af 0%, #3b82f6 100%) !important;
        }

        .header .title {
            color: rgba(255, 255, 255, 0.95) !important;
        }

        .content th {
            background: linear-gradient(135deg, #f8842c 0%, #e67c28 100%) !important;
            color: #ffffff !important;
        }

        @media (prefers-color-scheme: light) {
            .header {
                background: linear-gradient(135deg, #1e40af 0%, #3b82f6 100%) !important;
            }
            .header .title {
                color: rgba(255, 255, 255, 0.95) !important;
            }
            .content th {
                background: linear-gradient(135deg, #f8842c 0%, #e67c28 100%) !important;
                color: #ffffff !important;
            }
        }

        @media (prefers-color-scheme: dark) {
            body {
                background-color: #1a1a1a !important;
            }
            .email-container, .content {
                background-color: #2d2d2d !important;
                color: #e5e5e5 !important;
            }
            .header {
                background: linear-gradient(135deg, #011e33 0%, #1a365d 100%) !important;
            }
            .footer {
                background: linear-gradient(135deg, #1a365d 0%, #011e33 100%) !important;
            }
            h1, h2, h3, p, span, strong, div, li {
                color: #e5e5e5 !important;
            }
            .tenant-info {
                background: linear-gradient(135deg, #2d2d2d 0%, #3a3a3a 100%) !important;
                border: 1px solid #4a4a4a !important;
                border-left-color: #f8842c !important;
            }
            .content table {
                background-color: #3a3a3a !important;
            }
            .content th {
                background: #011e33 !important;
                background: linear-gradient(135deg, #011e33 0%, #1a365d 100%) !important;
                color: #ffffff !important;
            }
            .content td {
                border-bottom-color: #4a4a4a !important;
            }
            .content tr:nth-child(even) {
                background-color: #404040 !important;
            }
            @media (prefers-color-scheme: dark) {
                .attachments {
                    background: linear-gradient(135deg, #2d2d2d 0%, #3a3a3a 100%) !important;
                    border: 1px solid #4a4a4a !important;
                    border-left-color: #f8842c !important;
                }
                .attachment-list li {
                    background-color: #2d2d2d !important;
                    border-color: #4a4a4a !important;
                }
            }
            .content code, .content pre {
                background-color: #404040 !important;
                color: #e5e5e5 !important;
            }
            .content blockquote {
                background-color: #3a3a3a !important;
            }
        }
    </style>
    <!--<![endif]-->
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #374151;
            background-color: #f9fafb;
            padding: 20px;
            margin: 0;
        }

        .email-container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: #ffffff;
            border-radius: 12px;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
            overflow: hidden;
        }

        .header {
            background: var(--rj-light-gray);
            color: #374151;
            padding: 40px 48px 32px;
            text-align: center;
            position: relative;
        }

        .header::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 100" fill="white" opacity="0.03"><path d="M0,0 C300,50 700,50 1000,0 L1000,100 L0,100 Z"/></svg>') no-repeat center bottom;
            background-size: cover;
        }

        .header .logo-container {
            position: relative;
            z-index: 1;
            margin-bottom: 12px;
            max-width: 150px;
            width: 150px !important;
            margin-left: auto;
            margin-right: auto;
        }

        .logo-light,
        .logo-dark {
            max-width: 150px;
            width: 150px !important;
            height: auto;
            display: block;
            margin: 0 auto;
        }

        /* Mobile-specific logo sizing */
        @media (max-width: 768px) {
            .header .logo-container {
                max-width: 140px !important;
                width: 140px !important;
            }
            .logo-light,
            .logo-dark {
                max-width: 140px !important;
                width: 140px !important;
            }
        }

        /* Desktop logo sizing */
        @media (min-width: 769px) {
            .header .logo-container {
                max-width: 180px !important;
                width: 180px !important;
            }
            .logo-light,
            .logo-dark {
                max-width: 180px !important;
            }
        }

        /* Show light logo by default (for light mode) */
        .logo-light {
            display: block;
        }

        .logo-dark {
            display: none;
        }

        /* Switch to dark logo in dark mode */
        @media (prefers-color-scheme: dark) {
            .logo-light {
                display: none;
            }

            .logo-dark {
                display: block;
            }
        }

        .header .title {
            position: relative;
            z-index: 1;
            font-size: 18px;
            font-weight: 400;
            margin: 0;
            opacity: 0.9;
            color: #374151 !important;
            text-shadow: none;
        }

        .content {
            padding: 48px 48px;
            background-color: #ffffff;
        }

        .tenant-info {
            background: linear-gradient(135deg, #eff6ff 0%, #f0f9ff 100%);
            border: 1px solid #e0e7ff;
            border-left: 4px solid #f8842c;
            padding: 20px 24px;
            margin-bottom: 32px;
            border-radius: 8px;
            font-size: 14px;
        }

        .tenant-info strong {
            color: #011e33;
            font-weight: 600;
        }

        .content h1 {
            color: #111827;
            border-bottom: 2px solid #e5e7eb;
            padding-bottom: 12px;
            margin-bottom: 20px;
            font-size: 28px;
            font-weight: 600;
            letter-spacing: -0.025em;
        }

        .content h2 {
            color: #374151;
            margin-top: 28px;
            margin-bottom: 12px;
            font-size: 22px;
            font-weight: 600;
        }

        .content h3 {
            color: #4b5563;
            margin-top: 20px;
            margin-bottom: 8px;
            font-size: 18px;
            font-weight: 600;
        }

        .content p {
            margin-bottom: 12px;
            color: #374151;
            line-height: 1.7;
        }

        .content ul, .content ol {
            margin-left: 24px;
            margin-bottom: 12px;
            color: #374151;
        }

        .content li {
            margin-bottom: 4px;
            line-height: 1.6;
        }

        .content table {
            width: 100%;
            border-collapse: collapse;
            margin: 32px 0;
            background-color: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
        }

        .content th {
            background: linear-gradient(135deg, #f8842c 0%, #e67c28 100%) !important;
            color: #ffffff !important;
            padding: 18px 24px;
            text-align: left;
            font-weight: 600;
            font-size: 15px;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }

        .content td {
            padding: 18px 24px;
            border-bottom: 1px solid #f3f4f6;
            font-size: 15px;
        }

        .content tr:nth-child(even) {
            background-color: #f9fafb;
        }

        .content code {
            background-color: #f3f4f6;
            padding: 2px 8px;
            border-radius: 4px;
            font-family: 'SF Mono', Monaco, 'Consolas', 'Liberation Mono', 'Courier New', monospace;
            font-size: 0.875em;
            color: #374151;
            border: 1px solid #e5e7eb;
        }

        .content pre {
            background-color: #f3f4f6;
            padding: 20px;
            border-radius: 8px;
            overflow-x: auto;
            margin: 20px 0;
            border: 1px solid #e5e7eb;
            font-family: 'SF Mono', Monaco, 'Consolas', 'Liberation Mono', 'Courier New', monospace;
        }

        .content blockquote {
            border-left: 4px solid #3b82f6;
            background: linear-gradient(135deg, #eff6ff 0%, #f0f9ff 100%);
            padding: 20px 24px;
            margin: 24px 0;
            border-radius: 0 8px 8px 0;
            font-style: italic;
            color: #374151;
        }

        .attachments {
            background: linear-gradient(135deg, #eff6ff 0%, #f0f9ff 100%);
            border: 1px solid #e0e7ff;
            border-left: 4px solid #f8842c;
            border-radius: 8px;
            padding: 20px 24px;
            margin-top: 16px;
        }

        .attachments h3 {
            color: #011e33;
            margin-top: 0;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            font-size: 14px;
            font-weight: 600;
        }

        .attachments h3:before {
            content: "📎";
            margin-right: 10px;
            font-size: 16px;
        }

        .attachment-list {
            list-style: none;
            margin: 0 0 16px 0;
            padding: 0;
        }

        .attachment-list li {
            background-color: white;
            border: 1px solid #e0e7ff;
            border-radius: 6px;
            padding: 8px 12px;
            margin-bottom: 3px;
            display: flex;
            align-items: center;
            font-size: 14px;
        }

        .attachments p {
            margin-bottom: 0;
            font-size: 14px;
        }        .footer {
            background: linear-gradient(135deg, #1f2937 0%, #111827 100%);
            color: #f9fafb;
            padding: 40px 48px;
            text-align: center;
            position: relative;
        }

        .footer::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 100" fill="white" opacity="0.02"><path d="M0,100 C300,50 700,50 1000,100 L1000,0 L0,0 Z"/></svg>') no-repeat center top;
            background-size: cover;
        }

        .footer .logo-container {
            position: relative;
            z-index: 1;
            margin-bottom: 16px;
            max-width: 130px;
            width: 130px !important;
            margin-left: auto;
            margin-right: auto;
        }

        .footer .logo-light,
        .footer .logo-dark {
            max-width: 130px;
            width: 130px !important;
            height: auto;
            opacity: 0.9;
            display: block;
            margin: 0 auto;
        }

        /* Mobile-specific footer logo sizing */
        @media (max-width: 768px) {
            .footer .logo-container {
                max-width: 120px !important;
                width: 120px !important;
            }
            .footer .logo-light,
            .footer .logo-dark {
                max-width: 120px !important;
                width: 120px !important;
            }
        }

        /* Desktop footer logo sizing */
        @media (min-width: 769px) {
            .footer .logo-container {
                max-width: 160px !important;
                width: 160px !important;
            }
            .footer .logo-light,
            .footer .logo-dark {
                max-width: 160px !important;
            }
        }

        /* Show light logo by default (for light mode) */
        .footer .logo-light {
            display: block;
        }

        .footer .logo-dark {
            display: none;
        }

        /* Switch to dark logo in dark mode */
        @media (prefers-color-scheme: dark) {
            .footer .logo-light {
                display: none;
            }

            .footer .logo-dark {
                display: block;
            }
        }

        .footer .tagline {
            position: relative;
            z-index: 1;
            font-size: 14px;
            opacity: 0.8;
            margin-bottom: 20px;
            color: var(--rj-text-color);
        }

        @media (prefers-color-scheme: dark) {
            .footer .tagline {
                color: var(--rj-light-gray) !important;
            }
        }

        .footer .links {
            position: relative;
            z-index: 1;
            margin-top: 24px;
            font-size: 13px;
            opacity: 0.7;
        }

        .footer .links a {
            color: #60a5fa;
            text-decoration: none;
            margin: 0 12px;
        }

        @media (max-width: 768px) {
            body {
                padding: 10px;
            }

            .email-container {
                margin: 0;
                border-radius: 8px;
                max-width: 100%;
            }

            .header, .content, .footer {
                padding: 24px 20px;
            }

            .logo-light,
            .logo-dark {
                max-width: 90px !important;
            }

            .footer .logo-light,
            .footer .logo-dark {
                max-width: 80px !important;
            }

            .header .title {
                font-size: 16px !important;
                font-weight: 400 !important;
                opacity: 0.85 !important;
                margin-bottom: 8px !important;
            }

            .content h1 {
                font-size: 24px;
            }

            .content h2 {
                font-size: 20px;
            }

            .content table {
                font-size: 13px;
            }

            .content th, .content td {
                padding: 12px 8px;
            }

            .tenant-info {
                padding: 16px 20px;
                font-size: 13px;
            }

            .attachments {
                padding: 16px 20px;
                font-size: 13px;
            }

            .attachments h3 {
                font-size: 13px;
            }

            .attachments p {
                font-size: 13px;
            }
        }

        @media (min-width: 769px) and (max-width: 1024px) {
            .email-container {
                max-width: 900px;
            }

            .header, .content, .footer {
                padding: 36px;
            }

            .logo-light,
            .logo-dark {
                max-width: 130px;
            }

            .footer .logo-light,
            .footer .logo-dark {
                max-width: 110px;
            }
        }

        @media (min-width: 1025px) {
            .logo-light,
            .logo-dark {
                max-width: 160px;
            }

            .footer .logo-light,
            .footer .logo-dark {
                max-width: 130px;
            }
        }

        /* Force RealmJoin Orange for table headers with highest specificity */
        .content th,
        .email-container .content table th,
        table .content th {
            background: #f8842c !important;
            background: linear-gradient(135deg, #f8842c 0%, #e67c28 100%) !important;
            color: #ffffff !important;
        }
    </style>
</head>
<body>
    <!--[if mso]>
    <v:background xmlns:v="urn:schemas-microsoft-com:vml" fill="t">
        <v:fill type="tile" color="#f5f5f5"/>
    </v:background>
    <![endif]-->
    <div class="email-container">
        <div class="header">
            <div class="logo-container">
                <img class="logo-light" alt="RealmJoin logo for light mode" src="$($base64RJLogoLight)" />
                <img class="logo-dark" alt="RealmJoin logo for dark mode" src="$($base64RJLogoDark)" />
            </div>
            <div class="title">Insights on Demand</div>
        </div>

        <div class="content">

            $htmlContent

            $(if (($(($Attachments) | Measure-Object).Count) -gt 0) {
                @"

            <div class="attachments">
                <h3>Attached Files</h3>
                <ul class="attachment-list">
                    $(($Attachments | ForEach-Object { "<li>$(Split-Path $_ -Leaf)</li>" }) -join "`n                    ")
                </ul>
                <p><strong>Note:</strong> The attachments contain additional information from the generated report and can be used for more in-depth analysis.</p>
            </div>
            <br />
"@
            })

            <div class="tenant-info">
                <strong>Tenant:</strong> $($TenantDisplayName)<br>
                <strong>Generated:</strong> $([System.Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'; Get-Date -Format "dddd, MMMM d, yyyy hh:mm") <br>
                <strong>Report Version:</strong> $($ReportVersion)
            </div>
        </div>

        <div class="footer">
            <div class="logo-container">
                <img class="logo-light" alt="RealmJoin logo for light mode" src="$($base64RJLogoLight)" />
                <img class="logo-dark" alt="RealmJoin logo for dark mode" src="$($base64RJLogoDark)" />
            </div>
            <div class="tagline">Companion to Intune – Application Lifecycle & Management Automation Platform</div>
            <div class="links">
                <a href="https://www.realmjoin.com">www.realmjoin.com</a> |
                <a href="https://docs.realmjoin.com">Documentation</a>
            </div>
        </div>
    </div>
</body>
</html>
"@

    try {
        # Send email using Microsoft Graph
        Write-RjRbLog -Message "Sending email to: $EmailTo" -Verbose

        # Prepare attachments
        $emailAttachments = @()
        foreach ($file in $Attachments) {
            if (Test-Path $file) {
                $contentBytes = [IO.File]::ReadAllBytes($file)
                $content = [Convert]::ToBase64String($contentBytes)
                $emailAttachments += @{
                    "@odata.type"  = "#microsoft.graph.fileAttachment"
                    "name"         = (Split-Path $file -Leaf)
                    "contentType"  = "text/csv"
                    "contentBytes" = $content
                }
            }
            else {
                Write-RjRbLog -Message "Attachment file not found: $file" -Verbose
            }
        }

        $message = @{
            subject      = $Subject
            body         = @{
                contentType = "HTML"
                content     = $htmlBody
            }
            toRecipients = @(
                @{
                    emailAddress = @{
                        address = $EmailTo
                    }
                }
            )
        }

        if ($emailAttachments.Count -gt 0) {
            $message.attachments = $emailAttachments
        }

        # Send via Graph API using native Microsoft Graph
        $body = @{ message = $message; saveToSentItems = $true } | ConvertTo-Json -Depth 10
        $Uri = "https://graph.microsoft.com/v1.0/users/$($EmailFrom)/sendMail"
        Invoke-MgGraphRequest -Uri $Uri -Method POST -Body $body -ContentType "application/json" -ErrorAction Stop

        Write-RjRbLog -Message "Email sent successfully" -Verbose
    }
    catch {
        Write-RjRbLog -Message "Failed to send email: $($_.Exception.Message)" -ErrorAction Stop
    }
}

#endregion

########################################################
#region     Connect and Initialize
########################################################

Write-RjRbLog -Message "Connecting to Microsoft Graph..." -Verbose
Connect-MgGraph

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
    Write-RjRbLog -Message "Could not retrieve tenant information" -ErrorAction Stop
}

$tenantDisplayName = $tenant.displayName
$tenantId = $tenant.id

Write-RjRbLog -Message "Tenant: $tenantDisplayName ($tenantId)" -Verbose

# Create temporary directory for CSV files
$tempDir = Join-Path (Get-Location).Path "AppRegReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

#endregion

########################################################
#region     Get App Registrations
########################################################

Write-RjRbLog -Message "Retrieving all App Registrations..." -Verbose

# Function to get all pages from Graph API
function Get-AllGraphPages {
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

        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $allResults
}

$allAppRegs = Get-AllGraphPages -Uri "https://graph.microsoft.com/v1.0/applications"
Write-RjRbLog -Message "Found $((($(($allAppRegs) | Measure-Object).Count))) App Registrations" -Verbose

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
    Write-RjRbLog -Message "Retrieving deleted App Registrations..." -Verbose

    try {
        $deletedAppRegs = Get-AllGraphPages -Uri "https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.application"
        Write-RjRbLog -Message "Found $((($(($deletedAppRegs) | Measure-Object).Count))) deleted App Registrations" -Verbose

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
Write-RjRbLog -Message "Exported active App Registrations to: $activeAppRegCsv" -Verbose

# Export deleted App Registrations (if any)
if ((($(($deletedAppRegResults) | Measure-Object).Count) -gt 0)) {
    $deletedAppRegCsv = Join-Path $tempDir "AppRegistrations_Deleted.csv"
    $deletedAppRegResults | Export-Csv -Path $deletedAppRegCsv -NoTypeInformation -Encoding UTF8
    $csvFiles += $deletedAppRegCsv
    Write-RjRbLog -Message "Exported deleted App Registrations to: $deletedAppRegCsv" -Verbose
}

#endregion

########################################################
#region     Prepare Email Content
########################################################

# Generate statistics
$activeAppsWithSecrets = (($(($appRegResults | Where-Object { $_.HasSecrets }) | Measure-Object).Count))
$activeAppsWithCerts = (($(($appRegResults | Where-Object { $_.HasCertificates }) | Measure-Object).Count))
$enabledApps = ($appRegResults | Where-Object { $_.AccountEnabled }).Count

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

Write-RjRbLog -Message "Preparing to send email report..." -Verbose

# Set default sender if not provided
if ([string]::IsNullOrWhiteSpace($EmailFrom)) {
    $EmailFrom = "reports@$($tenant.verifiedDomains | Where-Object { $_.isDefault } | Select-Object -ExpandProperty name)"
    Write-RjRbLog -Message "Using default sender: $($EmailFrom)" -Verbose
}

$emailSubject = "App Registration Report - $($tenantDisplayName) - $(Get-Date -Format 'yyyy-MM-dd')"

try {
    Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -Attachments $csvFiles -TenantDisplayName $tenantDisplayName

    Write-RjRbLog -Message "Email report sent successfully to: $($EmailTo)" -Verbose
    Write-Output "✅ App Registration report generated and sent successfully"
    Write-Output "📧 Recipient: $($EmailTo)"
    Write-Output "📊 Active Apps: $($appRegResults.Count)"
    Write-Output "🗑️ Deleted Apps: $($deletedAppRegResults.Count)"
}
catch {
    Write-RjRbLog -Message "Failed to send email report: $($_.Exception.Message)" -ErrorAction Stop
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
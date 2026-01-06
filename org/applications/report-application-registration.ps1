<#
.SYNOPSIS
    Generate and email a comprehensive Application Registration report

.DESCRIPTION
    This runbook generates a report of all Entra ID Application Registrations and deleted Application Registrations,
    exports them to CSV files, and sends them via email.

.PARAMETER EmailTo
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

.PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.34.0" }

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

$Version = "1.0.1"
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

function ConvertFrom-MarkdownToHtml {
    <#
        .SYNOPSIS
        Converts Markdown text to HTML with support for common Markdown syntax.

        .DESCRIPTION
        Lightweight Markdown to HTML converter supporting headers, lists, tables, code blocks,
        links, images, bold, italic, blockquotes, and horizontal rules.

        .PARAMETER MarkdownText
        The Markdown text to convert to HTML.

        .EXAMPLE
        PS C:\> ConvertFrom-MarkdownToHtml -MarkdownText "# Hello World`n`nThis is **bold** text."

        .OUTPUTS
        System.String. Returns HTML string.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$MarkdownText
    )

    # Input validation
    if ([string]::IsNullOrEmpty($MarkdownText)) {
        return ""
    }

    $MarkdownText = $MarkdownText.Trim()
    $html = $MarkdownText

    # Normalize line endings to \n only (remove \r)
    $html = $html -replace "`r`n", "`n"
    $html = $html -replace "`r", "`n"

    # Escape Markdown characters first
    $html = $html -replace '\\(.)', '§ESCAPED§$1§ESCAPED§'

    # Extract and protect code blocks before processing other markdown elements
    # This prevents headers and other markdown syntax inside code blocks from being transformed
    # Store code blocks in an array and replace them with placeholders
    $codeBlocks = @()
    $codeBlockIndex = 0

    # Extract code blocks with language support (handles both ``` and malformed ` variants)
    # Note: Some markdown content may have malformed code blocks with single backtick instead of triple backticks
    # (e.g., `powershell instead of ```powershell). This regex handles both cases by matching 1-3 backticks
    # at the start of a line (with optional indentation).
    $html = $html -replace '(?sm)^\s*`{1,3}(\w+)?\r?\n(.+?)^\s*`{1,3}\s*$', {
        $language = $_.Groups[1].Value
        $code = $_.Groups[2].Value -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '\\`', '`'

        $htmlBlock = if ($language) {
            "<pre><code class=`"language-$language`">$code</code></pre>"
        }
        else {
            "<pre><code>$code</code></pre>"
        }

        $placeholder = "§CODEBLOCK§$codeBlockIndex§"
        $codeBlocks += $htmlBlock
        $script:codeBlockIndex++
        return $placeholder
    }

    # Extract and protect inline code before processing other markdown
    $inlineCodeBlocks = @()
    $inlineCodeIndex = 0
    $html = $html -replace '`([^`]+)`', {
        $code = $_.Groups[1].Value -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '\\`', '`'
        $htmlInline = "<code>$code</code>"

        $placeholder = "§INLINECODE§$inlineCodeIndex§"
        $inlineCodeBlocks += $htmlInline
        $script:inlineCodeIndex++
        return $placeholder
    }

    # Horizontal rules
    $html = $html -replace '(?m)^(-{3,}|\*{3,}|_{3,})$', '<hr />'

    # Headers (all 6 levels) - now safe from code block interference
    # Also supports headers without space after # (e.g., #Header instead of # Header)
    $html = $html -replace '(?m)^######\s*(.+)$', '<h6>$1</h6>'
    $html = $html -replace '(?m)^#####\s*(.+)$', '<h5>$1</h5>'
    $html = $html -replace '(?m)^####\s*(.+)$', '<h4>$1</h4>'
    $html = $html -replace '(?m)^###\s*(.+)$', '<h3>$1</h3>'
    $html = $html -replace '(?m)^##\s*(.+)$', '<h2>$1</h2>'
    $html = $html -replace '(?m)^#\s*(.+)$', '<h1>$1</h1>'

    # Bold and Italic (limit to single line to prevent backtracking)
    $html = $html -replace '\*\*([^\n\r*]+)\*\*', '<strong>$1</strong>'
    $html = $html -replace '\*([^\n\r*]+)\*', '<em>$1</em>'
    $html = $html -replace '~~([^\n\r~]+)~~', '<del>$1</del>'

    # Links and Images
    $html = $html -replace '!\[([^\]]*)\]\(([^)]+)\)', '<img src="$2" alt="$1"/>'
    $html = $html -replace '\[([^\]]+)\]\(([^)]+)\)', '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>'

    # Helper functions
    function Pop-Stack {
        param([ref]$Stack)
        if ($Stack.Value.Count -gt 0) {
            if ($Stack.Value.Count -eq 1) {
                $Stack.Value = @()  # Ensure it's an array
            }
            else {
                $Stack.Value = @($Stack.Value[0..($Stack.Value.Count - 2)])  # Ensure it's an array
            }
        }
    }

    function Update-ListNesting {
        param(
            [int]$TargetLevel,
            [ref]$ListStack,
            [ref]$ProcessedLines,
            [string]$ListType
        )

        $currentLevel = $ListStack.Value.Count

        if ($TargetLevel -gt $currentLevel) {
            for ($n = $currentLevel; $n -lt $TargetLevel; $n++) {
                $ProcessedLines.Value += "<$ListType>"
                $ListStack.Value += $ListType
            }
        }
        elseif ($TargetLevel -lt $currentLevel) {
            for ($n = $currentLevel; $n -gt $TargetLevel; $n--) {
                $closeType = $ListStack.Value[-1]
                $ProcessedLines.Value += "</$closeType>"
                Pop-Stack -Stack $ListStack
            }
        }
    }

    function Close-AllList {
        param(
            [ref]$ListStack,
            [ref]$ProcessedLines,
            [ref]$InUnorderedList,
            [ref]$InOrderedList
        )

        while ($ListStack.Value.Count -gt 0) {
            $listType = $ListStack.Value[-1]
            $closeTag = "</$listType>"
            $ProcessedLines.Value += $closeTag
            Pop-Stack -Stack $ListStack
        }
        $InUnorderedList.Value = $false
        $InOrderedList.Value = $false
    }

    # Single-pass line processing
    $lines = $html -split "`n"
    $processedLines = @()
    $lineCount = $lines.Count

    $inTable = $false
    $inUnorderedList = $false
    $inOrderedList = $false
    $inBlockquote = $false
    $tableAlignments = @()
    $listStack = @()

    for ($i = 0; $i -lt $lineCount; $i++) {
        $line = $lines[$i]

        # Blockquote processing
        if ($line -match '^>\s*(.*)$') {
            if ($inTable) { $processedLines += '</tbody></table></div>'; $inTable = $false; $tableAlignments = @() }
            Close-AllList -ListStack ([ref]$listStack) -ProcessedLines ([ref]$processedLines) -InUnorderedList ([ref]$inUnorderedList) -InOrderedList ([ref]$inOrderedList)

            $content = $Matches[1]
            if (-not $inBlockquote) {
                $processedLines += '<blockquote>'
                $inBlockquote = $true
            }
            if ($content.Trim() -ne '') {
                $processedLines += $content
            }
        }
        # Table processing
        elseif ($line -match '^\|.*\|$') {
            if ($inBlockquote) { $processedLines += '</blockquote>'; $inBlockquote = $false }
            Close-AllList -ListStack ([ref]$listStack) -ProcessedLines ([ref]$processedLines) -InUnorderedList ([ref]$inUnorderedList) -InOrderedList ([ref]$inOrderedList)

            if (-not $inTable) {
                $processedLines += '<div class="table-wrapper">'
                $processedLines += '<table class="table table-striped">'
                $inTable = $true

                # Check for separator line with alignment
                if (($i + 1) -lt $lineCount -and $lines[$i + 1] -match '^\|[-:\s\|]+\|$') {
                    $separatorLine = $lines[$i + 1]
                    $alignmentCells = ($separatorLine -replace '^\|', '' -replace '\|$', '').Split('|')
                    $tableAlignments = @()
                    foreach ($alignCell in $alignmentCells) {
                        $alignCell = $alignCell.Trim()
                        if ($alignCell -match '^:.*:$') { $tableAlignments += 'center' }
                        elseif ($alignCell -match ':$') { $tableAlignments += 'right' }
                        elseif ($alignCell -match '^:') { $tableAlignments += 'left' }
                        else { $tableAlignments += '' }
                    }

                    # Process header row
                    $tempLine = $line -replace '\\\|', '§PIPE§'
                    $cells = ($tempLine -replace '^\|', '' -replace '\|$', '').Split('|')
                    if ($cells.Count -gt 0) {
                        $processedLines += '<thead><tr>'
                        for ($j = 0; $j -lt $cells.Count; $j++) {
                            $cleanCell = $cells[$j].Trim() -replace '§PIPE§', '|'
                            if ([string]::IsNullOrWhiteSpace($cleanCell)) { $cleanCell = '&nbsp;' }
                            $alignClass = if ($j -lt $tableAlignments.Count -and $tableAlignments[$j]) { " class=`"text-$($tableAlignments[$j])`"" } else { "" }
                            $processedLines += "<th$alignClass>$cleanCell</th>"
                        }
                        $processedLines += '</tr></thead><tbody>'
                        $i++
                        continue
                    }
                }
            }

            # Regular table row
            $tempLine = $line -replace '\\\|', '§PIPE§'
            $cells = ($tempLine -replace '^\|', '' -replace '\|$', '').Split('|')
            if ($cells.Count -gt 0) {
                $processedLines += '<tr>'
                for ($j = 0; $j -lt $cells.Count; $j++) {
                    $cleanCell = $cells[$j].Trim() -replace '§PIPE§', '|'
                    if ([string]::IsNullOrWhiteSpace($cleanCell)) { $cleanCell = '&nbsp;' }
                    $alignClass = if ($j -lt $tableAlignments.Count -and $tableAlignments[$j]) { " class=`"text-$($tableAlignments[$j])`"" } else { "" }
                    $processedLines += "<td$alignClass>$cleanCell</td>"
                }
                $processedLines += '</tr>'
            }
        }
        # Unordered List processing
        elseif ($line -match '^(\s*)- (.+)$') {
            if ($inBlockquote) { $processedLines += '</blockquote>'; $inBlockquote = $false }
            if ($inTable) { $processedLines += '</tbody></table></div>'; $inTable = $false; $tableAlignments = @() }
            if ($inOrderedList) { $processedLines += '</ol>'; $inOrderedList = $false }

            $indentation = $Matches[1].Length
            $content = $Matches[2]
            $nestLevel = [Math]::Floor($indentation / 2)

            # Open first list if needed
            if (-not $inUnorderedList) {
                $processedLines += '<ul>'
                $inUnorderedList = $true
                $listStack += 'ul'
            }

            # Handle nesting (nestLevel+1 because nestLevel is 0-based, only update if different)
            $targetLevel = $nestLevel + 1
            if ($targetLevel -ne $listStack.Count) {
                Update-ListNesting -TargetLevel $targetLevel -ListStack ([ref]$listStack) -ProcessedLines ([ref]$processedLines) -ListType 'ul'
            }

            $processedLines += "<li>$content</li>"
        }
        # Ordered List processing
        elseif ($line -match '^(\s*)(\d+)\. (.+)$') {
            if ($inBlockquote) { $processedLines += '</blockquote>'; $inBlockquote = $false }
            if ($inTable) { $processedLines += '</tbody></table></div>'; $inTable = $false; $tableAlignments = @() }
            if ($inUnorderedList) { $processedLines += '</ul>'; $inUnorderedList = $false }

            $indentation = $Matches[1].Length
            $content = $Matches[3]
            $nestLevel = [Math]::Floor($indentation / 2)

            # Open first list if needed
            if (-not $inOrderedList) {
                $processedLines += '<ol>'
                $inOrderedList = $true
                $listStack += 'ol'
            }

            # Handle nesting (nestLevel+1 because nestLevel is 0-based, only update if different)
            $targetLevel = $nestLevel + 1
            if ($targetLevel -ne $listStack.Count) {
                Update-ListNesting -TargetLevel $targetLevel -ListStack ([ref]$listStack) -ProcessedLines ([ref]$processedLines) -ListType 'ol'
            }

            $processedLines += "<li>$content</li>"
        }
        # Other lines
        else {
            if ($inBlockquote) { $processedLines += '</blockquote>'; $inBlockquote = $false }
            if ($inTable) { $processedLines += '</tbody></table></div>'; $inTable = $false; $tableAlignments = @() }

            $isHeader = $line -match '^<h[1-6]>'
            $isEmptyLine = [string]::IsNullOrWhiteSpace($line)
            $nextLineIsList = $false
            $nextLineIsHeader = $false

            if ($isEmptyLine -and ($i + 1) -lt $lineCount) {
                for ($j = $i + 1; $j -lt $lineCount; $j++) {
                    $nextLine = $lines[$j]
                    if (-not [string]::IsNullOrWhiteSpace($nextLine)) {
                        $nextLineIsList = ($nextLine -match '^(\s*)- (.+)$') -or ($nextLine -match '^(\s*)(\d+)\. (.+)$')
                        $nextLineIsHeader = ($nextLine -match '^<h[1-6]>')
                        break
                    }
                }
            }

            if ($listStack.Count -gt 0 -and ($isHeader -or ($isEmptyLine -and -not $nextLineIsList -and -not $nextLineIsHeader))) {
                Close-AllList -ListStack ([ref]$listStack) -ProcessedLines ([ref]$processedLines) -InUnorderedList ([ref]$inUnorderedList) -InOrderedList ([ref]$inOrderedList)
            }

            if (-not $isEmptyLine -or $listStack.Count -eq 0) {
                $processedLines += $line
            }
        }
    }

    # Close remaining open structures
    if ($inBlockquote) { $processedLines += '</blockquote>' }
    if ($inTable) { $processedLines += '</tbody></table></div>' }
    Close-AllList -ListStack ([ref]$listStack) -ProcessedLines ([ref]$processedLines) -InUnorderedList ([ref]$inUnorderedList) -InOrderedList ([ref]$inOrderedList)

    $html = $processedLines -join "`n"

    # Paragraph processing
    $blocks = $html -split "`n`n+"

    $result = @()
    foreach ($block in $blocks) {
        $block = $block.Trim()
        if ($block -eq "") { continue }

        # Check if block starts with an HTML element tag (opening or closing)
        if ($block -match "^<(h[1-6]|ul|ol|table|pre|blockquote|hr)[\s>]" -or
            $block -match "^</(h[1-6]|ul|ol|table|pre|blockquote)>") {
            $result += $block
        }
        # Check if it contains HTML list elements - if so, don't wrap
        elseif ($block -match "<(h[1-6]|ul|ol|li|table|thead|tbody|tr|td|th|pre|code|blockquote|hr|/ul|/ol)[\s>]") {
            $result += $block
        }
        else {
            $lines = $block -split "`n"
            $nonEmptyLines = $lines | Where-Object { $_.Trim() -ne "" }
            if ($nonEmptyLines.Count -gt 0) {
                $paragraphContent = $nonEmptyLines -join '<br>'
                $result += "<p>$paragraphContent</p>"
            }
        }
    }

    $html = $result -join "`n`n"

    # Final safety escaping
    $html = $html -replace '&(?![a-zA-Z]{2,8};)(?!#[0-9]{1,7};)(?!#x[0-9a-fA-F]{1,6};)', '&amp;'

    # Restore escaped Markdown characters
    $html = $html -replace '§ESCAPED§(.{1})§ESCAPED§', '$1'

    # Restore inline code blocks from placeholders
    for ($i = 0; $i -lt $inlineCodeBlocks.Count; $i++) {
        $html = $html -replace "§INLINECODE§$i§", $inlineCodeBlocks[$i]
    }

    # Restore code blocks from placeholders
    for ($i = 0; $i -lt $codeBlocks.Count; $i++) {
        $html = $html -replace "§CODEBLOCK§$i§", $codeBlocks[$i]
    }

    return $html
}

function Get-RjReportEmailBody {
    <#
        .SYNOPSIS
        Builds the RealmJoin-branded HTML email body used for report delivery.

        .DESCRIPTION
        Assembles the static HTML template, injects the converted Markdown content, and renders
        optional attachment metadata as well as tenant information into the footer section.

        .PARAMETER Subject
        Subject of the email, used for the HTML <title> element.

        .PARAMETER HtmlContent
        HTML fragment generated from Markdown that will be embedded in the email body.

        .PARAMETER Attachments
        Optional list of attachment file paths to surface in the "Attached Files" section.

        .PARAMETER TenantDisplayName
        Optional tenant display name shown in the tenant information box.

        .PARAMETER ReportVersion
        Optional report version string rendered in the tenant information box.

        .OUTPUTS
        System.String. Returns the composed HTML email body.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Subject,

        [Parameter(Mandatory = $true)]
        [string]$HtmlContent,

        [string[]]$Attachments = @(),

        [string]$TenantDisplayName,

        [string]$ReportVersion
    )

    if (-not $Attachments) {
        $Attachments = @()
    }

    $plainBase64Logo_dark = "PHN2ZyBpZD0iTGF5ZXJfMSIgZGF0YS1uYW1lPSJMYXllciAxIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxOTEiIGhlaWdodD0iNDcuOSI+PGRlZnM+PHN0eWxlPi5jbHMtMXtmaWxsOiNmZmY7fS5jbHMtMntmaWxsOiNmODg0MmM7fTwvc3R5bGU+PC9kZWZzPjxwYXRoIGNsYXNzPSJjbHMtMSIgZD0iTTQ4LjgyLDQyLjc1YS40NC40NCwwLDAsMS0uMTEtLjI5VjIzLjc1QTEsMSwwLDAsMSw0OSwyM2ExLDEsMCwwLDEsLjc0LS4zaDVhNS44Miw1LjgyLDAsMCwxLDUuODgsNS44Niw1LjYsNS42LDAsMCwxLTEuMzMsMy43MSw1Ljc1LDUuNzUsMCwwLDEtMy4zNiwybDQuODEsNy43N2EuNDguNDgsMCwwLDEsLjA5LjI5LjUxLjUxLDAsMCwxLS4xNi4zOC41NS41NSwwLDAsMS0uMzkuMTRINTguODZhLjQ2LjQ2LDAsMCwxLS40NC0uMjZsLTUuMDctOC4ySDUxLjA4djguMDZhLjM5LjM5LDAsMCwxLS4xMS4yOS4zOC4zOCwwLDAsMS0uMjkuMTFINDkuMTFBLjM5LjM5LDAsMCwxLDQ4LjgyLDQyLjc1Wm01LjgtMTAuNTlhMy41NCwzLjU0LDAsMCwwLDIuNi0xLDMuNDcsMy40NywwLDAsMCwxLTIuNTUsMy41OSwzLjU5LDAsMCwwLTEtMi42MywzLjU1LDMuNTUsMCwwLDAtMi42LTFINTEuMDh2Ny4yMloiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik02Niw0MmE2LjE2LDYuMTYsMCwwLDEtMi4yOS0yLjMsNi4zLDYuMywwLDAsMS0uODQtMy4xOFYzMi40YTYuMyw2LjMsMCwwLDEsLjg0LTMuMThBNi4zLDYuMywwLDAsMSw3NS40MiwzMi40djJhMSwxLDAsMCwxLS4zMS43NCwxLDEsMCwwLDEtLjc0LjNINjUuMDl2MS4yOGE0LDQsMCwwLDAsLjU0LDIsMy45MywzLjkzLDAsMCwwLDEuNDYsMS40Niw0LDQsMCwwLDAsMiwuNTRoNC4yMWEuMzguMzgsMCwwLDEsLjQuNHYxLjM0YS40NC40NCwwLDAsMS0uMTEuMjkuMzkuMzksMCwwLDEtLjI5LjExSDY5LjEyQTYuMiw2LjIsMCwwLDEsNjYsNDJabTcuMTktOC43VjMyLjI1YTQuMDcsNC4wNywwLDAsMC0uNTMtMiwzLjg5LDMuODksMCwwLDAtMS40Ny0xLjQ2LDQuMDksNC4wOSwwLDAsMC00LjA2LDAsMy44NiwzLjg2LDAsMCwwLTEuNDYsMS40Niw0LDQsMCwwLDAtLjU0LDJ2MS4wN1oiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik03OC41Miw0MmE0LjU1LDQuNTUsMCwwLDEtLjEzLTYuNDhBNi4zMSw2LjMxLDAsMCwxLDgyLDMzLjkzbDMuNzctLjUyQTEuODcsMS44NywwLDAsMCw4NywzMi44NWEyLDIsMCwwLDAsLjM3LTEuMjl2LS4yNGEyLjcyLDIuNzIsMCwwLDAtMS4wOC0yLjI0LDQuMjcsNC4yNywwLDAsMC0yLjcyLS44Niw0LjU0LDQuNTQsMCwwLDAtMi4yMS41MSwzLjg5LDMuODksMCwwLDAtMS41LDEuNC42Ni42NiwwLDAsMS0uNTguMzguNjkuNjksMCwwLDEtLjM3LS4xNGwtLjc5LS41M2EuNTYuNTYsMCwwLDEtLjE3LS43OCw2LDYsMCwwLDEsMi4zLTIuMTksNy42LDcuNiwwLDAsMSw2LjQ5LS4xNCw0Ljg0LDQuODQsMCwwLDEsMi4xLDEuODQsNS4xMiw1LjEyLDAsMCwxLC43NCwyLjc1VjQyLjQ2YS40LjQsMCwwLDEtLjEyLjI5LjM4LjM4LDAsMCwxLS4yOS4xMUg4Ny45NGEuMzkuMzksMCwwLDEtLjI5LS4xMS40NC40NCwwLDAsMS0uMTEtLjI5di0yYTYuMyw2LjMsMCwwLDEtMi4zMSwyLDYuNDEsNi40MSwwLDAsMS0zLjA2Ljc0QTUuMjksNS4yOSwwLDAsMSw3OC41Miw0MlpNODUsNDAuNDZhNS41Nyw1LjU3LDAsMCwwLDEuODEtMS45LDQuNTgsNC41OCwwLDAsMCwuNjUtMi4yNVYzNS4xMkw4MywzNS43M2wtLjgxLjEyYy0xLjkzLjI5LTIuOSwxLjItMi45LDIuNzJhMi4zOCwyLjM4LDAsMCwwLC44NywxLjkyLDMuNDQsMy40NCwwLDAsMCwyLjI2LjcyQTQuNjksNC42OSwwLDAsMCw4NSw0MC40NloiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik05NC41Nyw0Mi41NmExLDEsMCwwLDEtLjMtLjc0VjIzaC0yLjdhLjM4LjM4LDAsMCwxLS4yOS0uMTIuMzcuMzcsMCwwLDEtLjEyLS4yOVYyMS4yNmEuNDEuNDEsMCwwLDEsLjQxLS40MWgzLjkxYTEsMSwwLDAsMSwuNzQuMzEsMSwxLDAsMCwxLC4zMS43NFY0MC43Mkg5OS42YS40Mi40MiwwLDAsMSwuMjkuMTEuNC40LDAsMCwxLC4xMi4yOXYxLjM0YS40LjQsMCwwLDEtLjEyLjI5LjM4LjM4LDAsMCwxLS4yOS4xMUg5NS4zMUExLDEsMCwwLDEsOTQuNTcsNDIuNTZaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMTAyLjQ0LDQyLjc1YS40NC40NCwwLDAsMS0uMTEtLjI5VjI2Ljg2YS4zOS4zOSwwLDAsMSwuNC0uNDFoMS40NWEuMzguMzgsMCwwLDEsLjI5LjEyLjM3LjM3LDAsMCwxLC4xMi4yOXYxLjU2YTQuNTUsNC41NSwwLDAsMSwxLjg0LTEuNzUsNS4zOCw1LjM4LDAsMCwxLDIuNTQtLjYsNS43OCw1Ljc4LDAsMCwxLDMuMTcuODYsNC43OSw0Ljc5LDAsMCwxLDEuOTMsMi4zM0E0Ljg3LDQuODcsMCwwLDEsMTE2LDI2LjkxYTUuMjgsNS4yOCwwLDAsMSwyLjktLjgxLDUuNDIsNS40MiwwLDAsMSw0LDEuNTEsNS4zMyw1LjMzLDAsMCwxLDEuNTMsNFY0Mi40NmEuNC40LDAsMCwxLS4xMi4yOS4zOC4zOCwwLDAsMS0uMjkuMTFoLTEuNDVhLjM4LjM4LDAsMCwxLS4yOS0uMTEuNC40LDAsMCwxLS4xMi0uMjlWMzJhMy44MywzLjgzLDAsMCwwLTEtMi44MywzLjUzLDMuNTMsMCwwLDAtMi42Mi0xLDMuNzEsMy43MSwwLDAsMC0yLjkyLDEuMjgsNS4xNiw1LjE2LDAsMCwwLTEuMTEsMy41djkuNDZhLjQuNCwwLDAsMS0uMTIuMjkuMzguMzgsMCwwLDEtLjI5LjExaC0xLjQ1YS4zOC4zOCwwLDAsMS0uNC0uNFYzMmEzLjgzLDMuODMsMCwwLDAtMS0yLjgzLDMuNTYsMy41NiwwLDAsMC0yLjYyLTEsMy42OCwzLjY4LDAsMCwwLTIuOTEsMS4yOEE1LjEyLDUuMTIsMCwwLDAsMTA0LjU5LDMzdjkuNDhhLjQuNCwwLDAsMS0uMTIuMjkuMzguMzgsMCwwLDEtLjI5LjExaC0xLjQ1QS4zOS4zOSwwLDAsMSwxMDIuNDQsNDIuNzVaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMTI2LjM3LDQyLjc1YS40NC40NCwwLDAsMS0uMTItLjMyVjQxLjFhLjQxLjQxLDAsMCwxLC40NC0uNDRoMS43MUEyLjE5LDIuMTksMCwwLDAsMTMwLDQwYTIuMzUsMi4zNSwwLDAsMCwuNjItMS43MVYyMy4xMmEuMzkuMzksMCwwLDEsLjQtLjQxaDEuNTdhLjM4LjM4LDAsMCwxLC4yOS4xMi4zNy4zNywwLDAsMSwuMTIuMjlWMzguMzRhNS4wNyw1LjA3LDAsMCwxLS41MiwyLjI2QTQuMSw0LjEsMCwwLDEsMTMxLDQyLjI2YTQuMzgsNC4zOCwwLDAsMS0yLjMyLjZoLTJBLjQuNCwwLDAsMSwxMjYuMzcsNDIuNzVaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMTM5LjA3LDQyLjRhNi4xNiw2LjE2LDAsMCwxLTIuMjktMi4zLDYuMyw2LjMsMCwwLDEtLjg0LTMuMThWMzIuNGE2LjMsNi4zLDAsMCwxLC44NC0zLjE4LDYuMjgsNi4yOCwwLDAsMSwxMC45LDAsNi4zLDYuMywwLDAsMSwuODQsMy4xOHY0LjUyYTYuMyw2LjMsMCwwLDEtLjg0LDMuMTgsNi4zMiw2LjMyLDAsMCwxLTguNjEsMi4zWm01LjE5LTEuODRhNCw0LDAsMCwwLDEuNDctMS40Niw0LjA4LDQuMDgsMCwwLDAsLjUzLTJWMzIuMjVhNC4wNyw0LjA3LDAsMCwwLS41My0yLDMuODksMy44OSwwLDAsMC0xLjQ3LTEuNDYsNC4wOSw0LjA5LDAsMCwwLTQuMDYsMCwzLjc5LDMuNzksMCwwLDAtMS40NiwxLjQ2LDQsNCwwLDAsMC0uNTQsMnY0LjgxYTQsNCwwLDAsMCwuNTQsMiwzLjkzLDMuOTMsMCwwLDAsMS40NiwxLjQ2LDQuMDksNC4wOSwwLDAsMCw0LjA2LDBaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMTUzLjQxLDQyLjU2YTEsMSwwLDAsMS0uMzEtLjc0VjI4LjZoLTNhLjQxLjQxLDAsMCwxLS40MS0uNDFWMjYuODZhLjM3LjM3LDAsMCwxLC4xMi0uMjkuMzguMzgsMCwwLDEsLjI5LS4xMmg0LjIzYTEsMSwwLDAsMSwuNzQuMzEsMSwxLDAsMCwxLC4zMS43M1Y0MC43MmgzYS4zOS4zOSwwLDAsMSwuNDEuNHYxLjM0YS40LjQsMCwwLDEtLjEyLjI5LjM2LjM2LDAsMCwxLS4yOS4xMWgtNC4yQTEsMSwwLDAsMSwxNTMuNDEsNDIuNTZabS0uMTYtMTguNDlhLjM3LjM3LDAsMCwxLS4xMi0uMjlWMjEuMjZhLjQxLjQxLDAsMCwxLC40MS0uNDFoMS4zOWEuNDEuNDEsMCwwLDEsLjQxLjQxdjIuNTJhLjM3LjM3LDAsMCwxLS4xMi4yOS4zOC4zOCwwLDAsMS0uMjkuMTJoLTEuMzlBLjM4LjM4LDAsMCwxLDE1My4yNSwyNC4wN1oiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik0xNjEuMzQsNDIuNzJhLjM4LjM4LDAsMCwxLS4xMS0uMjlWMjYuODZhLjM2LjM2LDAsMCwxLC4xMS0uMjkuNC40LDAsMCwxLC4yOS0uMTJoMS40NWEuMzguMzgsMCwwLDEsLjI5LjEyLjM3LjM3LDAsMCwxLC4xMi4yOXYxLjU5YTUsNSwwLDAsMSwxLjk1LTEuOCw2LDYsMCwwLDEsMi43Mi0uNjEsNS40Miw1LjQyLDAsMCwxLDQsMS41MSw1LjM0LDUuMzQsMCwwLDEsMS41Myw0djEwLjlhLjQxLjQxLDAsMCwxLS40MS40MWgtMS40NWEuNDEuNDEsMCwwLDEtLjQxLS40MVYzMmEzLjgzLDMuODMsMCwwLDAtMS0yLjgzLDMuNTcsMy41NywwLDAsMC0yLjYyLTEsNC4wNyw0LjA3LDAsMCwwLTMuMTMsMS4yOEE0LjkxLDQuOTEsMCwwLDAsMTYzLjQ5LDMzdjkuNDhhLjQxLjQxLDAsMCwxLS40MS40MWgtMS40NUEuNC40LDAsMCwxLDE2MS4zNCw0Mi43MloiLz48cG9seWdvbiBjbGFzcz0iY2xzLTIiIHBvaW50cz0iNS44MSAxLjI4IDM1LjMgMTUuMjkgNDAuMDUgNDYuMjggMS4wNSAzOS4yOCA1LjgxIDEuMjgiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik0zLjQ2LDQzLjE2YS43OC43OCwwLDAsMS0uMjMtLjU3VjE3Ljg2YTEuNTUsMS41NSwwLDAsMSwuNDgtMS4xNiwxLjU1LDEuNTUsMCwwLDEsMS4xNi0uNDhIMTJhOC41LDguNSwwLDAsMSw0LjI2LDEuMSw4LjM5LDguMzksMCwwLDEsMy4wOCwzLDguMDgsOC4wOCwwLDAsMS0uNSw5LDguMyw4LjMsMCwwLDEtNC4yNSwyLjk1bDYuMyw5Ljc2YTEsMSwwLDAsMSwuMTYuNTMuNzYuNzYsMCwwLDEtLjI1LjU3Ljg2Ljg2LDAsMCwxLS42My4yM0gxN2ExLjEsMS4xLDAsMCwxLTEtLjUzTDkuNzMsMzIuNzFINy44N3Y5Ljg4YS43OC43OCwwLDAsMS0uMjMuNTcuNzQuNzQsMCwwLDEtLjU3LjIzSDRBLjc0Ljc0LDAsMCwxLDMuNDYsNDMuMTZabTguMjgtMTQuODJhNCw0LDAsMCwwLDIuODctMS4wOCwzLjY1LDMuNjUsMCwwLDAsMS4xMi0yLjc1LDMuNzksMy43OSwwLDAsMC0xLjEyLTIuODIsMy45MiwzLjkyLDAsMCwwLTIuODctMS4xSDcuODd2Ny43NVoiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik0yMi41LDQzLjE2YS43OC43OCwwLDAsMS0uMjMtLjU3VjM5LjgyYS43OS43OSwwLDAsMSwuOC0uOGgyLjgxYTEuOTQsMS45NCwwLDAsMCwxLjUtLjU5LDIuMjUsMi4yNSwwLDAsMCwuNTUtMS42MVYxN2EuNzkuNzksMCwwLDEsLjgtLjhoM2EuNzkuNzksMCwwLDEsLjguOHYxOS44YTYuODUsNi44NSwwLDAsMS0uODIsMy4zNiw2LDYsMCwwLDEtMi4yNiwyLjM2LDYuMjgsNi4yOCwwLDAsMS0zLjI3Ljg1SDIzLjA3QS43NC43NCwwLDAsMSwyMi41LDQzLjE2WiIvPjwvc3ZnPg=="
    $base64RJLogoDark = "data:image/svg+xml;base64,$($plainBase64Logo_dark)"

    $plainBase64Header = "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"

    return @"
<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="color-scheme" content="light">
    <meta name="supported-color-schemes" content="light">
    <title>$Subject</title>
    <!--[if !mso]><!-->
    <link href="https://fonts.googleapis.com/css2?family=Miriam+Libre:wght@400;700&display=swap" rel="stylesheet">
    <!--<![endif]-->
    <!-- Base styles for ALL clients (including Dark Mode for modern clients) -->
<style type="text/css">
    /* === RESET & BASICS === */
    * { margin: 0; padding: 0; box-sizing: border-box; }

    body {
        font-family: 'Miriam Libre', -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
        line-height: 1.6;
        color: #011e33;
        background-color: #e8ebed;
        padding: 20px;
    }

    /* === CONTAINER === */
    .email-container {
        max-width: 750px;
        margin: 0 auto;
        background-color: #ffffff;
        border-radius: 12px;
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        overflow: hidden;
    }

    /* === HEADER === */
    .header {
        background: url('data:image/png;base64,$($plainBase64Header)') no-repeat center top;
        background-size: contain;
        width: 100%;
        padding-top: 26.67%;
        display: block;
        position: relative;
    }

    /* === CONTENT === */
    .content {
        padding: 48px;
        background-color: #ffffff;
    }

    .tenant-info {
        background: #e8ebed;
        border: 1px solid #e0e7ff;
        border-left: 4px solid #f8842c;
        padding: 10px 20px;
        margin-top: 32px;
        border-radius: 8px;
        font-size: 14px;
    }

    .tenant-info strong {
        color: #011e33;
        font-weight: 600;
    }

    .content h1 {
        color: #111827;
        border-bottom: 2px solid #111827;
        padding-bottom: 12px;
        margin-bottom: 15px;
        font-size: 26px;
        line-height: 1.4;
        font-weight: 800;
    }

    .content h2 {
        color: #111827;
        margin-top: 42px;
        margin-bottom: 15px;
        font-size: 22px;
        line-height: 1.4;
        font-weight: 800;
    }

    .content h3 {
        color: #111827;
        margin-top: 27px;
        margin-bottom: 15px;
        font-size: 18px;
        line-height: 1.4;
        font-weight: 800;
    }

    .content h4,
    .content h5 {
        color: #111827;
        margin-top: 15px;
        margin-bottom: 15px;
        font-size: 16px;
        line-height: 1.4;
        font-weight: 800;
    }

    .content p {
        color: #111827;
        font-size: 16px;
        line-height: 1.4;
        margin-bottom: 15px;
    }

    .content ul {
        margin-top: 15px;
        margin-left: 0;
        margin-bottom: 12px;
        list-style-type: disc;
        padding-left: 20px;
    }

    .content ol {
        margin-top: 15px;
        margin-left: 0;
        margin-bottom: 12px;
        list-style-type: decimal;
        padding-left: 20px;
    }

    .content li {
        margin-top: 4px;
        margin-left: 0;
        color: #011e33;
        line-height: 1.5;
        margin-bottom: 4px;
        padding-left: 8px;
    }

    /* === TABLES === */
    .table-wrapper {
        overflow-x: auto;
        -webkit-overflow-scrolling: touch;
        margin: 15px 0;
    }

    .content table {
        width: 100%;
        border-collapse: collapse;
        margin: 0;
        background-color: white;
        border-radius: 8px;
        overflow: hidden;
        box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
    }

    .content th {
        background: #f8842c !important;
        color: #ffffff !important;
        padding: 8px 16px;
        text-align: left;
        font-weight: 600;
        font-size: 14px;
        text-transform: uppercase;
    }

    .content td {
        padding: 8px 16px;
        border-bottom: 1px solid #e8ebed;
        font-size: 14px;
        color: #2D3748;
    }

    .content tr:nth-child(even) {
        background-color: #e8ebed;
    }

    .content blockquote {
        border-left: 4px solid #3b82f6;
        background: #e8ebed;
        padding: 20px 24px;
        margin-top: 15px;
        margin-bottom: 15px;
        border-radius: 0 8px 8px 0;
        font-style: italic;
        color: #374151;
    }

    /* Fix spacing after blockquote */
    .content blockquote + p {
        margin-top: 15px !important;
    }

    /* === CODE === */
    .content code {
        background-color: #e8ebed;
        padding: 2px 8px;
        border-radius: 4px;
        font-family: 'SF Mono', Monaco, 'Consolas', monospace;
        font-size: 0.875em;
        color: #011e33;
        border: 1px solid #e5e7eb;
    }

    .content pre {
        background-color: #e8ebed;
        padding: 20px;
        border-radius: 8px;
        overflow-x: auto;
        margin: 20px 0;
        border: 1px solid #e5e7eb;
        font-family: 'SF Mono', Monaco, 'Consolas', monospace;
    }

    /* === HR (Horizontal Rule) === */
    .content hr {
        border: none;
        border-top: 2px solid #e5e7eb;
        margin: 24px 0;
    }

    /* === STRONG & EM === */
    .content strong {
        font-weight: 600;
        color: #111827;
    }

    .content em {
        font-style: italic;
        color: #374151;
    }

    /* === LINKS === */
    .content a {
        color: #3b82f6;
        text-decoration: underline;
    }

    .content a:hover {
        color: #2563eb;
    }

    /* === ATTACHMENTS === */
    .attachments {
        background: #e8ebed;
        border: 1px solid #e0e7ff;
        border-left: 4px solid #f8842c;
        border-radius: 8px;
        padding: 10px 20px;
        margin-top: 10px;
    }

    .attachments h3 {
        color: #011e33;
        margin-top: 0;
        font-size: 14px;
        font-weight: 600;
    }

    .attachment-list {
        margin: 0 0 16px 0;
        padding: 0;
    }

    .attachment-item {
        background-color: white;
        border: 1px solid #e0e7ff;
        border-radius: 6px;
        padding: 8px 12px;
        margin-bottom: 3px;
        font-size: 14px;
    }

    .attachments p {
        margin-bottom: 0;
        font-size: 14px;
    }

    /* === FOOTER === */
    .footer {
        background: #011e33;
        color: #3f3f3f;
        padding: 40px 48px;
        text-align: center;
    }

    .footer .logo-container {
        margin-bottom: 16px;
        max-width: 130px;
        margin-left: auto;
        margin-right: auto;
    }

    .footer .logo-dark {
        max-width: 130px;
        width: 130px !important;
        height: auto;
        opacity: 0.9;
        display: block;
        margin: 0 auto;
    }

    .footer .tagline {
        font-size: 14px;
        opacity: 0.8;
        margin-bottom: 10px;
        color: #ffffff;
    }

    .footer .links {
        font-size: 13px;
        opacity: 0.7;
    }

    .footer .links a {
        color: #60a5fa;
        text-decoration: none;
        margin: 0 12px;
    }

        @media (max-width: 768px) {
        body { padding: 10px; }
        .email-container {
            max-width: 100%;
            border-radius: 8px;
        }
        .content, .footer { padding: 24px 20px; }
        .footer .logo-dark { max-width: 120px !important; }
        .content h1 { font-size: 22px; line-height: 1.4; }
        .content h2 { font-size: 18px; line-height: 1.4; }
        .content h3 { font-size: 16px; line-height: 1.4; }
        .content h4, .content h5 { font-size: 16px; line-height: 1.4; }
        .content p { font-size: 16px; line-height: 1.4; }
        .table-wrapper { margin: 15px 0; }
        .content table { font-size: 13px; min-width: 500px; }
        .content th, .content td { padding: 6px 8px; }
        .tenant-info, .attachments { padding: 16px 20px; font-size: 13px; }
    }

    /* === TABLET === */
    @media (min-width: 769px) and (max-width: 1024px) {
        .email-container { max-width: 750px; }
        .content, .footer { padding: 36px; }
        .footer .logo-dark { max-width: 160px; }
    }

    /* === DESKTOP === */
    @media (min-width: 1025px) {
        .email-container { max-width: 750px; }
        .footer .logo-dark { max-width: 160px; }
    }

    /* === DARK MODE (New Outlook, modern clients) === */
    @media (prefers-color-scheme: dark) {
        body { background-color: #1a1a1a !important; }

        .email-container, .content {
            background-color: #2d2d2d !important;
            color: #e5e5e5 !important;
        }

        .header {
            /* Keep Light Mode header graphic in Dark Mode */
            background: url('data:image/png;base64,$($plainBase64Header)') no-repeat center center !important;
            background-size: cover !important;
        }

        h1, h2, h3, p, span, strong, div, li, td, blockquote {
            color: #e5e5e5 !important;
        }

        h1 {
            border-bottom: 2px solid #e5e5e5 !important;
        }

        .tenant-info {
            background: linear-gradient(135deg, #2d2d2d 0%, #3a3a3a 100%) !important;
            border: 1px solid #4a4a4a !important;
            border-left-color: #f8842c !important;
        }

        .content table {
            background-color: #3a3a3a !important;
        }

        .content td {
            border-bottom-color: #4a4a4a !important;
        }

        .content th {
            background: #f8842c !important;
            color: #ffffff !important;
        }

        .content tr:nth-child(even) {
            background-color: #404040 !important;
        }

        .attachments {
            background: linear-gradient(135deg, #2d2d2d 0%, #3a3a3a 100%) !important;
            border: 1px solid #4a4a4a !important;
            border-left-color: #f8842c !important;
        }

        .attachment-item {
            background-color: #2d2d2d !important;
            border-color: #4a4a4a !important;
        }

        .content code, .content pre {
            background-color: #404040 !important;
            color: #e5e5e5 !important;
            border-color: #4a4a4a !important;
        }

        .content blockquote {
            background: linear-gradient(135deg, #2d2d2d 0%, #3a3a3a 100%) !important;
            border-left-color: #f8842c !important;
        }
    }
</style>

<!-- Outlook Classic Fixes (only for MSO) -->
<!--[if mso]>
<style type="text/css">
    /* Force Light Mode for Outlook Classic */
    body { background-color: #f3f5f6; }
    .email-container { background-color: #ffffff; }
    .header { background-color: #f8f9fa; }
    .footer { background-color: #f8f9fa; }
    .content { background-color: #ffffff; }

    /* MSO Table Fixes */
    table { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }

    /* MSO Line Height Fix */
    .content p, .content li { mso-line-height-rule: exactly; }

    /* MSO List Fixes - Use standard specificity */
    .content ul {
        list-style-type: disc;
        margin-left: 0;
        padding-left: 20px;
    }
    .content ol {
        list-style-type: decimal;
        margin-left: 0;
        padding-left: 20px;
    }
    .content li {
        margin-left: 0;
        padding-left: 8px;
    }

    /* Logo Display for Classic */
    .footer .logo-dark { display: block !important; }
</style>
<![endif]-->
</head>
<body>
    <!--[if mso]>
    <v:background xmlns:v="urn:schemas-microsoft-com:vml" fill="t">
        <v:fill type="tile" color="#f5f5f5"/>
    </v:background>
    <![endif]-->
    <div class="email-container">
        <div class="header">
        </div>

        <div class="content">

            $($HtmlContent)

            <div class="tenant-info">
                <strong>Tenant:</strong> $($TenantDisplayName)<br>
                <strong>Generated:</strong> $([System.Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'; Get-Date -Format "dddd, MMMM d, yyyy HH:mm") <br>
                <strong>Report Version:</strong> $($ReportVersion)
            </div>

            $(if (($(($Attachments) | Measure-Object).Count) -gt 0) {
            @"

            <div class="attachments">
                <h3>Attached Files</h3>
                <div class="attachment-list">
                    $(($Attachments | ForEach-Object { "<div class='attachment-item'>$(Split-Path $_ -Leaf)</div>" }) -join "`n                    ")
                </div>
                <p><strong>Note:</strong> The attachments contain additional information from the generated report and can be used for more in-depth analysis.</p>
            </div>
"@
            })
        </div>

        <div class="footer">
            <div class="logo-container">
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
}

function Send-RjReportEmail {
    <#
        .SYNOPSIS
        Sends a RealmJoin-branded HTML email (converted from Markdown) via Microsoft Graph.

        .DESCRIPTION
        Send-RjReportEmail builds an HTML email from Markdown content, inlines a RealmJoin-styled HTML template (including light/dark logos), attaches optional files, and sends the message using the Microsoft Graph API (Invoke-MgGraphRequest).

        .PARAMETER EmailFrom
        The sender user id (user principal name or id) used for the Graph /users/{id}/sendMail call.

        .PARAMETER EmailTo
        Recipient email address(es). Can be a single address or multiple comma-separated addresses (string).
        The function sends individual emails to each recipient for privacy reasons.
        Whitespace and empty entries are automatically removed.

        .PARAMETER Subject
        Subject line for the email message.

        .PARAMETER MarkdownContent
        Report content in Markdown format. The function performs a lightweight conversion of Markdown
        to HTML and places the result into the themed HTML template used for the email body.

        .PARAMETER Attachments
        Optional array of file paths to include as attachments. Files that exist will be read,
        base64-encoded and included as file attachments. Missing files are logged and skipped.

        .PARAMETER TenantDisplayName
        Optional display name for the tenant/organization that will be shown in the email footer
        and tenant info box.

        .PARAMETER ReportVersion
        Optional string describing the report version. Will be shown in the tenant-info block.

        .EXAMPLE
        PS C:\> Send-RjReportEmail -EmailFrom "reports@contoso.com" -EmailTo "alice@contoso.com" -Subject "Weekly Report" -MarkdownContent "# Hello`nReport body..."

        .EXAMPLE
        PS C:\> Send-RjReportEmail -EmailFrom "reports@contoso.com" -EmailTo "alice@contoso.com, bob@contoso.com, team@contoso.com" -Subject "Inventory" -MarkdownContent (Get-Content .\report.md -Raw) -Attachments @('C:\temp\report.csv') -TenantDisplayName 'Contoso Ltd' -ReportVersion 'v1.2.3'

        .INPUTS
        None. All parameters are provided as arguments; this function does not accept pipeline input.

        .OUTPUTS
        None. The function sends email and writes verbose/log messages. On failure it throws an exception.

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

        [string[]]$Attachments = @(),

        [string]$TenantDisplayName,

        [string]$ReportVersion
    )

    # Parse and clean email addresses from EmailTo parameter
    # Split by comma, trim whitespace, remove empty entries
    $emailRecipients = $EmailTo -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

    if (($emailRecipients | Measure-Object).Count -eq 0) {
        throw "No valid email recipients found in EmailTo parameter."
    }

    Write-RjRbLog -Message "Parsed $($emailRecipients.Count) recipient(s) from EmailTo parameter" -Verbose

    # Convert Markdown to HTML using helper function
    $htmlContent = ConvertFrom-MarkdownToHtml -MarkdownText $MarkdownContent

    Write-RjRbLog -Message "Successfully converted Markdown content to HTML" -Verbose

    # Prepare email parameters
    $emailAttachments = @()
    $validatedAttachments = @()
    foreach ($file in $Attachments) {
        if (Test-Path $file) {
            $contentBytes = [IO.File]::ReadAllBytes($file)
            $content = [Convert]::ToBase64String($contentBytes)
            $mimeType = Get-MimeTypeFromExtension -FilePath $file
            $emailAttachments += @{
                "@odata.type"  = "#microsoft.graph.fileAttachment"
                "name"         = (Split-Path $file -Leaf)
                "contentType"  = $mimeType
                "contentBytes" = $content
            }
            $validatedAttachments += $file
            Write-RjRbLog -Message "Added attachment: $(Split-Path $file -Leaf) (MIME type: $mimeType)" -Verbose
        }
        else {
            Write-RjRbLog -Message "Attachment file not found: $file" -Verbose
        }
    }

    $htmlBody = Get-RjReportEmailBody -Subject $Subject -HtmlContent $htmlContent -Attachments $validatedAttachments -TenantDisplayName $TenantDisplayName -ReportVersion $ReportVersion

    # Send individual emails to each recipient for privacy
    $successfulSends = 0
    $failedSends = 0
    $failedRecipients = @()

    foreach ($recipient in $emailRecipients) {
        try {
            Write-RjRbLog -Message "Sending email to: $recipient" -Verbose

            $message = @{
                subject      = $Subject
                body         = @{
                    contentType = "HTML"
                    content     = $htmlBody
                }
                toRecipients = @(
                    @{
                        emailAddress = @{
                            address = $recipient
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

            Write-RjRbLog -Message "Email sent successfully to $recipient" -Verbose
            $successfulSends++
        }
        catch {
            $failedSends++
            $failedRecipients += $recipient
            Write-RjRbLog -Message "Failed to send email to ${recipient}: $($_.Exception.Message)" -Verbose
            Write-Error "Failed to send email to ${recipient}: $($_.Exception.Message)" -ErrorAction Continue
        }
    }

    # Summary logging
    Write-RjRbLog -Message "Email sending completed: $successfulSends successful, $failedSends failed out of $($emailRecipients.Count) total recipient(s)" -Verbose

    if ($failedSends -gt 0) {
        $failedList = $failedRecipients -join ", "
        Write-RjRbLog -Message "Failed recipients: $failedList" -Verbose

        if ($successfulSends -eq 0) {
            throw "Failed to send email to all recipients: $failedList"
        }
        else {
            Write-Warning "Some emails failed to send. Failed recipients: $failedList"
        }
    }
}

function Get-MimeTypeFromExtension {
    <#
        .SYNOPSIS
        Returns the MIME type for a given file extension.

        .DESCRIPTION
        Maps common file extensions used for tenant data exports to their appropriate MIME types.
        Supports CSV, Excel, JSON, XML, TXT, and other common formats.

        .PARAMETER FilePath
        The file path to determine the MIME type for.

        .EXAMPLE
        PS C:\> Get-MimeTypeFromExtension -FilePath "C:\temp\report.csv"
        Returns: text/csv

        .EXAMPLE
        PS C:\> Get-MimeTypeFromExtension -FilePath "C:\temp\data.xlsx"
        Returns: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet

        .OUTPUTS
        System.String. Returns the MIME type string.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()

    $mimeTypes = @{
        '.csv'  = 'text/csv'
        '.txt'  = 'text/plain'
        '.json' = 'application/json'
        '.xml'  = 'application/xml'
        '.xlsx' = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        '.xls'  = 'application/vnd.ms-excel'
        '.pdf'  = 'application/pdf'
        '.zip'  = 'application/zip'
        '.html' = 'text/html'
        '.htm'  = 'text/html'
        '.log'  = 'text/plain'
        '.md'   = 'text/markdown'
    }

    if ($mimeTypes.ContainsKey($extension)) {
        return $mimeTypes[$extension]
    }
    else {
        # Default to binary stream for unknown types
        return 'application/octet-stream'
    }
}

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
<#
    .SYNOPSIS
    Scheduled report of stale devices based on last activity date and platform.

    .DESCRIPTION
    Identifies and lists devices that haven't been active for a specified number of days.
    Automatically sends a report via email.

    .PARAMETER Days
    Number of days without activity to be considered stale.

    .PARAMETER Windows
    Include Windows devices in the results.

    .PARAMETER MacOS
    Include macOS devices in the results.

    .PARAMETER iOS
    Include iOS devices in the results.

    .PARAMETER Android
    Include Android devices in the results.

    .PARAMETER EmailTo
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Days": {
                "DisplayName": "Days Without Activity",
            },
            "Windows": {
                "DisplayName": "Include Windows Devices"
            },
            "MacOS": {
                "DisplayName": "Include macOS Devices"
            },
            "iOS": {
                "DisplayName": "Include iOS Devices"
            },
            "Android": {
                "DisplayName": "Include Android Devices"
            },
            "CallerName": {
                "Hide": true
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)"
            },
            "EmailFrom": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.30.0" }

param(
    [int] $Days = 30,
    [bool] $Windows = $true,
    [bool] $MacOS = $true,
    [bool] $iOS = $true,
    [bool] $Android = $true,
    [Parameter(Mandatory = $true)]
    [string] $EmailTo,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "Days: $Days" -Verbose
Write-RjRbLog -Message "Windows: $Windows" -Verbose
Write-RjRbLog -Message "MacOS: $MacOS" -Verbose
Write-RjRbLog -Message "iOS: $iOS" -Verbose
Write-RjRbLog -Message "Android: $Android" -Verbose

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

    # Horizontal rules
    $html = $html -replace '(?m)^(-{3,}|\*{3,}|_{3,})$', '<hr />'

    # Headers (all 6 levels)
    $html = $html -replace '(?m)^###### (.+)$', '<h6>$1</h6>'
    $html = $html -replace '(?m)^##### (.+)$', '<h5>$1</h5>'
    $html = $html -replace '(?m)^#### (.+)$', '<h4>$1</h4>'
    $html = $html -replace '(?m)^### (.+)$', '<h3>$1</h3>'
    $html = $html -replace '(?m)^## (.+)$', '<h2>$1</h2>'
    $html = $html -replace '(?m)^# (.+)$', '<h1>$1</h1>'

    # Code blocks with language support
    $html = $html -replace '(?s)```(\w+)?\r?\n(.+?)```', {
        param($match)
        $language = $match.Groups[1].Value
        $code = $match.Groups[2].Value -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '\\`', '`'
        if ($language) {
            "<pre><code class=`"language-$language`">$code</code></pre>"
        }
        else {
            "<pre><code>$code</code></pre>"
        }
    }

    # Inline code
    $html = $html -replace '`([^`]+)`', {
        param($match)
        $code = $match.Groups[1].Value -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '\\`', '`'
        "<code>$code</code>"
    }

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

    function Close-AllLists {
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
            if ($inTable) { $processedLines += '</tbody></table>'; $inTable = $false; $tableAlignments = @() }
            Close-AllLists -ListStack ([ref]$listStack) -ProcessedLines ([ref]$processedLines) -InUnorderedList ([ref]$inUnorderedList) -InOrderedList ([ref]$inOrderedList)

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
            Close-AllLists -ListStack ([ref]$listStack) -ProcessedLines ([ref]$processedLines) -InUnorderedList ([ref]$inUnorderedList) -InOrderedList ([ref]$inOrderedList)

            if (-not $inTable) {
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
            if ($inTable) { $processedLines += '</tbody></table>'; $inTable = $false; $tableAlignments = @() }
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
            if ($inTable) { $processedLines += '</tbody></table>'; $inTable = $false; $tableAlignments = @() }
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
            if ($inTable) { $processedLines += '</tbody></table>'; $inTable = $false; $tableAlignments = @() }

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
                Close-AllLists -ListStack ([ref]$listStack) -ProcessedLines ([ref]$processedLines) -InUnorderedList ([ref]$inUnorderedList) -InOrderedList ([ref]$inOrderedList)
            }

            if (-not $isEmptyLine -or $listStack.Count -eq 0) {
                $processedLines += $line
            }
        }
    }

    # Close remaining open structures
    if ($inBlockquote) { $processedLines += '</blockquote>' }
    if ($inTable) { $processedLines += '</tbody></table>' }
    Close-AllLists -ListStack ([ref]$listStack) -ProcessedLines ([ref]$processedLines) -InUnorderedList ([ref]$inUnorderedList) -InOrderedList ([ref]$inOrderedList)

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

    return @"
<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="color-scheme" content="light">
    <meta name="supported-color-schemes" content="light">
    <title>$Subject</title>
    <!-- Base styles for ALL clients (including Dark Mode for modern clients) -->
<style type="text/css">
    /* === RESET & BASICS === */
    * { margin: 0; padding: 0; box-sizing: border-box; }

    body {
        font-family: "Miriam Libre",sans-serif;
        line-height: 1.6;
        color: #011e33;
        background-color: #e8ebed;
        padding: 20px;
    }

    /* === CONTAINER === */
    .email-container {
        max-width: 1200px;
        margin: 0 auto;
        background-color: #ffffff;
        border-radius: 12px;
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        overflow: hidden;
    }

    /* === HEADER === */
    .header {
        background: #011e33;
        color: #3f3f3f;
        padding: 40px 48px 32px;
        text-align: center;
    }

    .header .logo-container {
        margin-bottom: 12px;
        max-width: 400px;
        margin-left: auto;
        margin-right: auto;
    }

    .logo-dark {
        max-width: 400px;
        width: 400px !important;
        height: auto;
        display: block;
        margin: 0 auto;
    }

    .header .title {
        font-size: 18px;
        font-weight: 400;
        margin: 0;
        opacity: 0.9;
        color: #ffffff;
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
        margin-bottom: 13px;
        font-size: 28px;
        font-weight: 800;
    }

    .content h2 {
        color: #111827;
        margin-top: 30px;
        margin-bottom: 10px;
        font-size: 22px;
        font-weight: 800;
    }

    .content h3 {
        color: #111827;
        margin-top: 10px;
        margin-bottom: 8px;
        font-size: 18px;
        font-weight: 800;
    }

    .content p {
        color: #111827;
        line-height: 1.5;
        margin-bottom: 12px;
    }

    .content ul, .content ol {
        margin-left: 24px;
        margin-bottom: 12px;
    }

    .content li {
        color: #011e33;
        line-height: 1.5;
        margin-bottom: 4px;
    }

    /* === TABLES === */
    .content table {
        width: 100%;
        border-collapse: collapse;
        margin-top: 32px;
        margin-bottom: 20px;
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
    }

    .content tr:nth-child(even) {
        background-color: #e8ebed;
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

    .content blockquote {
        border-left: 4px solid #3b82f6;
        background: #e8ebed;
        padding: 20px 24px;
        margin: 24px 0;
        border-radius: 0 8px 8px 0;
        font-style: italic;
        color: #374151;
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
        list-style: none;
        margin: 0 0 16px 0;
        padding: 0;
        margin-left: 0 !important;
        padding-left: 0 !important;
    }

    .attachment-list li {
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
        .email-container { border-radius: 8px; }
        .header, .content, .footer { padding: 24px 20px; }
        .logo-dark { max-width: 300px !important; width: 300px !important; }
        .footer .logo-dark { max-width: 120px !important; }
        .header .title { font-size: 16px !important; }
        .content h1 { font-size: 24px; }
        .content h2 { font-size: 20px; }
        .content table { font-size: 13px; }
        .content th, .content td { padding: 6px 8px; }
        .tenant-info, .attachments { padding: 16px 20px; font-size: 13px; }
    }

    /* === TABLET === */
    @media (min-width: 769px) and (max-width: 1024px) {
        .email-container { max-width: 900px; }
        .header, .content, .footer { padding: 36px; }
        .logo-dark { max-width: 350px !important; width: 350px !important; }
        .footer .logo-dark { max-width: 160px; }
    }

    /* === DESKTOP === */
    @media (min-width: 1025px) {
        .logo-dark { max-width: 400px !important; width: 400px !important; }
        .footer .logo-dark { max-width: 160px; }
    }

    /* === DARK MODE (New Outlook, modern clients) === */
    @media (prefers-color-scheme: dark) {
        body { background-color: #1a1a1a !important; }

        .email-container, .content {
            background-color: #2d2d2d !important;
            color: #e5e5e5 !important;
        }

        .header, .footer {
            background: #2d2d2d !important;
        }

        .header .title, .footer .tagline {
            color: #e5e5e5 !important;
        }

        .logo-dark { display: block; }
        .footer .logo-dark { display: block; }

        h1, h2, h3, p, span, strong, div, li {
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

        .attachment-list li {
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

    /* Logo Display for Classic */
    .logo-dark { display: block !important; }
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
            <div class="logo-container">
                <img class="logo-dark" alt="RealmJoin logo for dark mode" src="$($base64RJLogoDark)" />
            </div>
            <div class="title">Insights on Demand</div>
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
                <ul class="attachment-list">
                    $(($Attachments | ForEach-Object { "<li>$(Split-Path $_ -Leaf)</li>" }) -join "`n                    ")
                </ul>
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

function Get-AllGraphPages {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Get-AllGraphPages takes an initial Microsoft Graph API URI and retrieves all items across
        multiple pages by following the @odata.nextLink property in the response. It aggregates
        all items into a single array and returns it.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/applications".

        .EXAMPLE
        PS C:\> $allApps = Get-AllGraphPages -Uri "https://graph.microsoft.com/v1.0/applications"
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

# Connect to Microsoft Graph
Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop

# Get tenant information
Write-Output "## Retrieving tenant information..."
$tenantDisplayName = "Unknown Tenant"
try {
    $organizationUri = "https://graph.microsoft.com/v1.0/organization?`$select=displayName"
    $organizationResponse = Invoke-MgGraphRequest -Uri $organizationUri -Method GET -ErrorAction Stop

    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
        Write-Output "## Tenant: $($tenantDisplayName)"
    }
    elseif ($organizationResponse.displayName) {
        $tenantDisplayName = $organizationResponse.displayName
        Write-Output "## Tenant: $($tenantDisplayName)"
    }
}
catch {
    Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
}
Write-Output ""

# Calculate the date threshold for stale devices
$beforeDate = (Get-Date).AddDays(-$Days) | Get-Date -Format "yyyy-MM-dd"

# Prepare filter for the Graph API query
$filter = "lastSyncDateTime le $($beforeDate)T00:00:00Z"

# Define the properties to select
$selectProperties = @(
    'deviceName'
    'lastSyncDateTime'
    'enrolledDateTime'
    'userPrincipalName'
    'id'
    'serialNumber'
    'manufacturer'
    'model'
    'operatingSystem'
    'osVersion'
    'complianceState'
)
$selectString = ($selectProperties -join ',')

# Get all stale devices
Write-Output "## Listing devices not active for at least $($Days) days"
Write-Output ""

$encodedFilter = [System.Uri]::EscapeDataString($filter)
$devicesUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=$selectString&`$filter=$encodedFilter"
$devices = Get-AllGraphPages -Uri $devicesUri

# Filter devices by platform based on user selection
$filteredDevices = @()

foreach ($device in $devices) {
    $include = $false

    # Check if the device's platform matches any of the selected platforms
    if ($Windows -and $device.operatingSystem -eq "Windows") {
        $include = $true
    }
    elseif ($MacOS -and $device.operatingSystem -eq "macOS") {
        $include = $true
    }
    elseif ($iOS -and $device.operatingSystem -eq "iOS") {
        $include = $true
    }
    elseif ($Android -and $device.operatingSystem -eq "Android") {
        $include = $true
    }

    if ($include) {
        # Try to get additional user information
        if ($device.userPrincipalName) {
            try {
                $encodedUserPrincipalName = [System.Uri]::EscapeDataString($device.userPrincipalName)
                $userUri = "https://graph.microsoft.com/v1.0/users/{0}?`$select=displayName,city,usageLocation" -f $encodedUserPrincipalName
                $userInfo = Invoke-MgGraphRequest -Uri $userUri -Method GET -ErrorAction SilentlyContinue

                if ($userInfo) {
                    $device | Add-Member -Name "userDisplayName" -Value $userInfo.displayName -MemberType "NoteProperty" -Force
                    $device | Add-Member -Name "userLocation" -Value "$($userInfo.city), $($userInfo.usageLocation)" -MemberType "NoteProperty" -Force
                }
            }
            catch {
                Write-RjRbLog -Message "Could not retrieve user info for $($device.userPrincipalName): $($_.Exception.Message)" -Verbose
            }
        }

        $filteredDevices += $device
    }
}

# Display summary counts
Write-Output "## Summary of stale devices for $($tenantDisplayName):"
Write-Output "Total devices: $($filteredDevices.Count)"

if ($Windows) {
    $windowsCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Windows" }).Count
    Write-Output "Windows devices: $($windowsCount)"
}

if ($MacOS) {
    $macOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "macOS" }).Count
    Write-Output "macOS devices: $($macOSCount)"
}

if ($iOS) {
    $iOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "iOS" }).Count
    Write-Output "iOS devices: $($iOSCount)"
}

if ($Android) {
    $androidCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Android" }).Count
    Write-Output "Android devices: $($androidCount)"
}

Write-Output ""
Write-Output "## Detailed list of stale devices:"
Write-Output ""

# Display the filtered devices
$filteredDevices | Sort-Object -Property lastSyncDateTime | Format-Table -AutoSize -Property @{
    name       = "LastSync";
    expression = { Get-Date $_.lastSyncDateTime -Format yyyy-MM-dd }
}, @{
    name       = "DeviceName";
    expression = { if ($_.deviceName.Length -gt 15) { $_.deviceName.substring(0, 14) + ".." } else { $_.deviceName } }
}, @{
    name       = "DeviceID";
    expression = { if ($_.id.Length -gt 15) { $_.id.substring(0, 14) + ".." } else { $_.id } }
}, @{
    name       = "SerialNumber";
    expression = { if ($_.serialNumber.Length -gt 15) { $_.serialNumber.substring(0, 14) + ".." } else { $_.serialNumber } }
}, @{
    name       = "PrimaryUser";
    expression = { if ($_.userPrincipalName.Length -gt 20) { $_.userPrincipalName.substring(0, 19) + ".." } else { $_.userPrincipalName } }
}

# Create Markdown content for email
Write-Output ""
Write-Output "## Preparing email report to send to $($EmailTo)"

# Prepare additional metadata for the report body
$selectedPlatforms = @()
if ($Windows) { $selectedPlatforms += 'Windows' }
if ($MacOS) { $selectedPlatforms += 'macOS' }
if ($iOS) { $selectedPlatforms += 'iOS' }
if ($Android) { $selectedPlatforms += 'Android' }
$platformSummary = if ($selectedPlatforms.Count -gt 0) { $selectedPlatforms -join ', ' } else { 'No specific platforms selected' }
$totalDevicesEvaluated = ($devices | Measure-Object).Count

if ($filteredDevices.Count -gt 10) {
    $filteredDevices_moreThan10 = $true
}
# Build Markdown content
$markdownContent = if ($filteredDevices.Count -eq 0) {
    @"
# Stale Devices Report

Great news — no managed devices matched the stale device criteria (last sync on or before **$($beforeDate)**) for the selected platforms.

## What We Checked

- Inactivity threshold: **$($Days) days**
- Platforms evaluated: $($platformSummary)
- Devices evaluated: $($totalDevicesEvaluated)

## Recommendations

- Continue to monitor this report regularly to spot newly idle devices early
- Keep lifecycle policies and retirement procedures current
- Ensure device owners stay informed about required check-ins
"@
}
else {
    @"
# Stale Devices Report

This report shows devices that have not been active for at least **$($Days) days**.

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Stale Devices** | $($filteredDevices.Count) |
$(if ($Windows) {
    $windowsCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Windows" }).Count
    "| **Windows Devices** | $($windowsCount) |"
})
$(if ($MacOS) {
    $macOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "macOS" }).Count
    "| **macOS Devices** | $($macOSCount) |"
})
$(if ($iOS) {
    $iOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "iOS" }).Count
    "| **iOS Devices** | $($iOSCount) |"
})
$(if ($Android) {
    $androidCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Android" }).Count
    "| **Android Devices** | $($androidCount) |"
})

$(if ($filteredDevices_moreThan10) {
    "## Top 10 Stale Devices (by Last Sync Date)"
    ""
    "This table lists the top 10 devices that have been inactive the longest, based on the current defined days ($($Days) days) threshold."
    ""
} else {
    "## Stale Devices"
    ""
    "This table lists all devices that have been inactive for at least $($Days) days, based on the current defined days threshold."
    ""
})


$(if ($filteredDevices.Count -gt 0) {
    $sortedDevices = $filteredDevices | Sort-Object -Property lastSyncDateTime

    # Create markdown table
    $table = @"
| Last Sync | Device Name | Operating System | Serial Number | Primary User |
|-----------|-------------|------------------|---------------|--------------|
"@

    foreach ($device in $sortedDevices) {
        $lastSync = Get-Date $device.lastSyncDateTime -Format yyyy-MM-dd
        $deviceName = $device.deviceName
        $os = $device.operatingSystem
        $serialNumber = $device.serialNumber
        $user = $device.userPrincipalName

        $table += "`n| $($lastSync) | $($deviceName) | $($os) | $($serialNumber) | $($user) |"
    }

    $table
} else {
    "No stale devices found matching the selected criteria."
})

## Recommendations

### Review and Action

Please review the listed devices and take appropriate action:
- Contact device owners to verify device status
- Consider retiring devices that are no longer in use
- Update device records if devices have been decommissioned
- Ensure compliance with your organization's device lifecycle policy

### Device Lifecycle Management

Regularly reviewing stale devices helps:
- Maintain accurate device inventory
- Reduce security risks from unmanaged devices
- Optimize license utilization
- Ensure compliance with organizational policies

## Attachments

The .csv-file attached to this email contains the full list of stale devices for further analysis.

"@
}

# Create CSV file in current location
$csvFilePath = Join-Path -Path $PSScriptRoot -ChildPath "StaleDevicesReport_$($tenantDisplayName)_$($Days)Days.csv"
$filteredDevices | Export-Csv -Path $csvFilePath -NoTypeInformation
$attachments = @($csvFilePath)
Write-RjRbLog -Message "Exported stale devices to CSV: $($csvFilePath)" -Verbose

# Send email report
$emailSubject = "Stale Devices Report - $($tenantDisplayName) - $($Days) days"

Write-Output "Sending report to '$($EmailTo)'..."
try {
    Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version -Attachments $attachments

    Write-RjRbLog -Message "Email report sent successfully to: $($EmailTo)" -Verbose
    Write-Output "✅ Stale devices report generated and sent successfully"
    Write-Output "📧 Recipient: $($EmailTo)"
    Write-Output "📊 Total Stale Devices: $($filteredDevices.Count)"
    Write-Output "⏱️ Inactive for: $Days days"
}
catch {
    Write-Output "Error sending email: $_"
    Write-RjRbLog -Message "Error sending email: $_" -Verbose
    throw "Failed to send email report: $($_.Exception.Message)"
}
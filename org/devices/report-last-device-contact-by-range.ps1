<#
.SYNOPSIS
    Reports devices with last contact within a specified date range.

.DESCRIPTION
    This Runbook retrieves a list of devices from Intune, filtered by their last device contact time (lastSyncDateTime).
    As a dropdown for the date range, you can select from 0-30 days, 30-90 days, 90-180 days, 180-365 days, or 365+ days.

    The output includes the device name, last sync date, Intune device ID, and user principal name.

    Optionally, the report can be sent via email with a CSV attachment containing additional details (Entra ID Device ID, User ID).

.PARAMETER dateRange
    Date range for filtering devices based on their last contact time.

.PARAMETER systemType
    The operating system type of the devices to filter.

.PARAMETER EmailTo
    If specified, an email with the report will be sent to the provided address(es).
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

.PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization

.PARAMETER CallerName
    Internal parameter for tracking purposes

.INPUTS
RunbookCustomization: {
    "Parameters": {
        "dateRange": {
            "DisplayName": "Select Last Device Contact Range (days)",
            "Description": "Filter devices based on their last contact time.",
            "Required": true,
            "SelectSimple": {
                "0-30 days": "0-30",
                "30-90 days": "30-90",
                "90-180 days": "90-180",
                "180-365 days": "180-365",
                "365 days and more": "365+"
            }
        },
        "systemType": {
            "DisplayName": "Select System Type",
            "Description": "Filter devices based on their operating system.",
            "Required": true,
            "SelectSimple": {
                "All": "all",
                "Windows": "Windows",
                "MacOS": "macOS",
                "Linux": "Linux"
            }
        },
        "EmailTo": {
            "DisplayName": "Recipient Email Address(es)"
        },
        "EmailFrom": {
            "Hide": true
        },
        "CallerName": {
            "Hide": true
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.30.0" }

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("0-30", "30-90", "90-180", "180-365", "365+")]
    [string]$dateRange,

    [Parameter(Mandatory = $true)]
    [ValidateSet("all", "Windows", "macOS", "Linux")]
    [string]$systemType = "Windows",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom,

    [Parameter(Mandatory = $false)]
    [string]$EmailTo,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
##
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "DateRange: $dateRange" -Verbose
Write-RjRbLog -Message "SystemType: $systemType" -Verbose
if ($EmailTo) {
    Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
    Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
}

#endregion

########################################################
#region     Parameter Validation
########################################################

# Validate Email Addresses (only if email is requested)
if ($EmailTo) {
    if (-not $EmailFrom) {
        Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/blob/master/docs/org/applications/report-app-registration.md" -Verbose
        throw "This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/blob/master/docs/org/applications/report-app-registration.md"
        exit
    }
}

#endregion

####################################################################
#region Function Definitions
####################################################################

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
        margin-top: 32px 0;
        margin-bottom: 20px 0;
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
            background: #f8842c, 12 !important;
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
            background-color: linear-gradient(135deg, #2d2d2d 0%, #3a3a3a 100%) !important;
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


####################################################################
#region Connect to Microsoft Graph
####################################################################

try {
    Write-Verbose "Connecting to Microsoft Graph..."
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    Write-Verbose "Successfully connected to Microsoft Graph."
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    throw
}

#endregion

####################################################################
#region Retrieve Windows Devices by Last Device Contact Date Range
####################################################################

#region Prepare parameters and filters
$now = Get-Date
$startDate = $null
$endDate = $null

switch ($dateRange) {
    "0-30" {
        $startDate = $now.AddDays(-30)
        $endDate = $now
    }
    "30-90" {
        $startDate = $now.AddDays(-90)
        $endDate = $now.AddDays(-30)
    }
    "90-180" {
        $startDate = $now.AddDays(-180)
        $endDate = $now.AddDays(-90)
    }
    "180-365" {
        $startDate = $now.AddDays(-365)
        $endDate = $now.AddDays(-180)
    }
    "365+" {
        # For "365+", $startDate remains $null, meaning no lower bound on age.
        # We will filter for devices with contact date *older than or equal to* 365 days ago.
        $endDate = $now.AddDays(-365)
    }
}

$dateFilter = ""

if ($dateRange -eq "365+") {
    $endDateISO = $endDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $dateFilter = "lastSyncDateTime le $($endDateISO)"
    Write-Verbose "Filtering for devices with last contact on or before $($endDateISO)."
}
else {
    $startDateISO = $startDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endDateISO = $endDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $dateFilter = "lastSyncDateTime ge $($startDateISO) and lastSyncDateTime le $($endDateISO)"
    Write-Verbose "Filtering for devices with last contact between $($startDateISO) and $($endDateISO)."
}

# Base URI for Microsoft Graph API to fetch managed devices
$baseURI = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter='


# Prepare the filter query based on the system type and date range
if ($systemType -ne 'all') {
    $baseFilter = "operatingSystem eq '$($systemType)'"
    $filterQuery = "$($baseFilter) and $($dateFilter)"
}
else {
    $filterQuery = $dateFilter
}

#$filterQuery = "operatingSystem eq 'macOS'"

$selectQuery = '&$select='
$selectProperties = "id,azureADDeviceId,lastSyncDateTime,deviceName,userId,userDisplayName,userPrincipalName,operatingSystem"
$selectProperties_Array = $selectProperties -split ',' | ForEach-Object { $_.Trim() }

$fullURI = $baseURI + $filterQuery + $selectQuery + $selectProperties

#endregion

#region Fetch Devices

$allDevices = @()
$currentURI = $fullURI

try {
    Write-Verbose "Retrieving devices from Microsoft Graph with initial filter: $($filterQuery)"
    Write-Verbose "Fetching data from URI: $($currentURI)"
    $allDevices = (Get-AllGraphPages -Uri $currentURI -ErrorAction Stop) | Select-Object -Property $selectProperties_Array
    if ($($allDevices | Measure-Object).Count -gt 0) {
        Write-Output "Retrieved devices using the current filter: $(($allDevices | Measure-Object).Count)"
    }
}
catch {
    Write-Error "Failed to retrieve devices: $($_.Exception.Message)"
    # If an error occurs, $devices might be partially populated or null.
    # Depending on requirements, you might want to clear $devices or handle it.
    # For now, we'll let it be as is and throw the exception.
    throw
}

#endregion
#endregion

######################################################################
#region Output Devices
######################################################################

#Prettify the property names for better readability
$outputDevices = $allDevices | ForEach-Object {
    [PSCustomObject]@{
        DeviceName        = $_.deviceName
        LastSyncDateTime  = $_.lastSyncDateTime
        IntuneDeviceId    = $_.id
        EntraIdDeviceId   = $_.azureADDeviceId
        UserDisplayName   = $_.userDisplayName
        UserPrincipalName = $_.userPrincipalName
        UserId            = $_.userId
    }
}

Write-Verbose "Resulting devices: $(($outputDevices | Measure-Object).Count)"

# Console output
if ($(($outputDevices | Measure-Object).Count) -eq 0) {
    Write-Output "No devices found matching the specified date range."
}
else {
    Write-Output "Found $(($outputDevices | Measure-Object).Count) devices matching the criteria."
    # Reduced properties in the output to optimize readability
    $outputDevices | Select-Object DeviceName, LastSyncDateTime, IntuneDeviceId, UserPrincipalName | Format-Table
}

#endregion

######################################################################
#region Send Email Report (if requested)
######################################################################

if ($EmailTo) {
    Write-Output ""
    Write-Output "Preparing email report..."

    # Get tenant information
    try {
        $tenant = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method GET
        if ($tenant.value -and (($(($tenant.value) | Measure-Object).Count) -gt 0)) {
            $tenant = $tenant.value[0]
        }
        $tenantDisplayName = $tenant.displayName
        $tenantId = $tenant.id
        Write-RjRbLog -Message "Tenant: $tenantDisplayName ($tenantId)" -Verbose
    }
    catch {
        Write-RjRbLog -Message "Warning: Could not retrieve tenant information: $($_.Exception.Message)" -Verbose
        $tenantDisplayName = ""
    }

    # Prepare date range description
    $dateRangeDescription = switch ($dateRange) {
        "0-30" { "0-30 days ago" }
        "30-90" { "30-90 days ago" }
        "90-180" { "90-180 days ago" }
        "180-365" { "180-365 days ago" }
        "365+" { "more than 365 days ago" }
    }

    # Check if any devices were found
    $deviceCount = ($outputDevices | Measure-Object).Count
    $csvFiles = @()

    if ($deviceCount -eq 0) {
        # No devices found - send email without attachments
        Write-RjRbLog -Message "No devices found in the specified date range - sending notification email" -Verbose

        $markdownContent = @"
# Device Last Contact Report

## Summary

✅ **No devices found** with last contact in the specified date range.

## Report Parameters

| Parameter | Value |
|-----------|-------|
| **Date Range** | $($dateRangeDescription) |
| **System Type** | $($systemType) |
| **Devices Found** | 0 |
| **Report Date** | $(Get-Date -Format 'yyyy-MM-dd HH:mm') |

## Analysis

This result indicates:
- No devices match the selected criteria ($($systemType), $($dateRangeDescription))
- All devices may be checking in more frequently (if looking at older date ranges)
- Or no devices exist in this category

## Recommendations

### Next Steps

$(if ($dateRange -eq "365+" -or $dateRange -eq "180-365") {
@"
✅ **Good News for Old Devices:**
- No stale devices detected in this time range
- Device management appears healthy
- Continue regular monitoring
"@
} else {
@"
📊 **Recent Activity Check:**
- Consider checking other date ranges
- Verify system type filter is correct
- Review overall device inventory
"@
})

### Suggested Actions

1. **Verify Search Criteria:**
   - Confirm the date range and system type are correct
   - Try different date ranges to compare results
   - Check if devices exist for the selected system type

2. **Regular Monitoring:**
   - Schedule periodic reports with different time ranges
   - Track device activity trends over time
   - Set up alerts for unusual patterns
"@

        $emailSubject = "Device Last Contact Report - No Devices Found - $($systemType) ($($dateRangeDescription)) - $(Get-Date -Format 'yyyy-MM-dd')"

    }
    else {
        # Devices found - create CSV file and send detailed report
        Write-RjRbLog -Message "Found $($deviceCount) devices - preparing detailed report" -Verbose

        # Create temporary directory for CSV files
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "DeviceContactReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

        # Export to CSV
        $csvFile = Join-Path $tempDir "DeviceContactReport_$($systemType)_$($dateRange)days.csv"
        $outputDevices | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        Write-Verbose "Exported device data to: $csvFile"
        $csvFiles += $csvFile

        # Create markdown content for email with detailed findings
        $markdownContent = @"
# Device Last Contact Report

This report provides an overview of devices with their last contact within the specified date range.

## Report Parameters

| Parameter | Value |
|-----------|-------|
| **Date Range** | $($dateRangeDescription) |
| **System Type** | $($systemType) |
| **Total Devices Found** | $($deviceCount) |

## Summary

$(if ($deviceCount -eq 0) {
"No devices were found matching the specified criteria."
} else {
@"
This report contains **$($deviceCount) devices** that last contacted Intune within the specified timeframe.

### Device Statistics by Operating System

$(
    $osByType = $outputDevices | Group-Object OperatingSystem | Sort-Object Count -Descending
    $osByType | ForEach-Object {
        "- **$($_.Name)**: $($_.Count) device(s)"
    }
)

### Top 10 Devices (by Last Sync)

| Device Name | Last Sync | Operating System | User |
|-------------|-----------|------------------|------|
$(
    $outputDevices | Sort-Object LastSyncDateTime -Descending | Select-Object -First 10 | ForEach-Object {
        $lastSync = if ($_.LastSyncDateTime) {
            [DateTime]::Parse($_.LastSyncDateTime).ToString("yyyy-MM-dd HH:mm")
        } else {
            "N/A"
        }
        "| $($_.DeviceName) | $($lastSync) | $($_.OperatingSystem) | $($_.UserPrincipalName) |"
    }
)
"@
})

## Data Export Information

The attached CSV file contains detailed information including:
- Device Name and Intune Device ID
- Last Sync Date and Time
- Entra ID Device ID
- User Display Name and User Principal Name
- Operating System
- User ID

## Recommendations

$(if ($dateRange -eq "365+") {
@"
### ⚠️ Devices Not Seen for Over a Year

These devices have not contacted Intune for over 365 days. Consider:
- Reviewing if these devices are still in use
- Checking if users need assistance reconnecting
- Evaluating for device retirement or cleanup
"@
} elseif ($dateRange -eq "180-365") {
@"
### 🔍 Devices Not Seen for 6-12 Months

These devices haven't checked in for 180-365 days. You may want to:
- Contact device users to verify device status
- Check for potential connectivity or policy issues
- Consider device health evaluation
"@
} else {
@"
### ✅ Recent Device Activity

These devices have contacted Intune recently. This indicates:
- Active device management
- Proper connectivity to Intune services
- Regular policy and app updates
"@
})
"@

        $emailSubject = "Device Last Contact Report - $systemType ($($dateRangeDescription)) - $(Get-Date -Format 'yyyy-MM-dd')"
    }

    # Send email (with or without attachments depending on findings)
    try {
        if ($deviceCount -eq 0) {
            Send-RjReportEmail `
                -EmailFrom $EmailFrom `
                -EmailTo $EmailTo `
                -Subject $emailSubject `
                -MarkdownContent $markdownContent `
                -Attachments $csvFiles `
                -TenantDisplayName $tenantDisplayName `
                -ReportVersion $Version
        }
        else {
            Send-RjReportEmail `
                -EmailFrom $EmailFrom `
                -EmailTo $EmailTo `
                -Subject $emailSubject `
                -MarkdownContent $markdownContent `
                -TenantDisplayName $tenantDisplayName `
                -ReportVersion $Version
        }


        Write-RjRbLog -Message "Email report sent successfully to: $($EmailTo)" -Verbose
        Write-Output "✅ Device contact report generated and sent successfully"
        Write-Output "📧 Recipient: $($EmailTo)"
        if ($deviceCount -gt 0) {
            Write-Output "📊 Devices reported: $deviceCount"
        }
        else {
            Write-Output "✅ No devices found in specified date range"
        }
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to send email report: $($_.Exception.Message)"
    }
    finally {
        # Clean up temporary files (only if they were created)
        if ($deviceCount -gt 0) {
            try {
                if (Test-Path $tempDir) {
                    Remove-Item -Path $tempDir -Recurse -Force
                    Write-RjRbLog -Message "Cleaned up temporary directory: $($tempDir)" -Verbose
                }
            }
            catch {
                Write-RjRbLog -Message "Warning: Could not clean up temporary directory: $($_.Exception.Message)" -Verbose
            }
        }
    }
}

#endregion

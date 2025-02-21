param(
    [string]$outfile = "RunbookDescriptions.md"
)

function Get-MarkdownHelp {
    param(
        [string]$runbookPath = "C:\Users\johndoe\Documents\runbook.ps1"
    )

    $pwd = (Get-Location).Path

    $runbookHelp = Get-Help $runbookPath -Full -ErrorAction SilentlyContinue


    $runbookPathShort = $runbookHelp.Name -replace "^$pwd[\\/]*", "" -replace "\.ps1$", ""
    $TextInfo = (Get-Culture).TextInfo
    $runbookDisplayName = $runbookPathShort -replace "[\\/]", ' \ ' | ForEach-Object { $TextInfo.ToTitleCase($_) }
    $runbookDisplayName = $runbookDisplayName -replace "([a-zA-Z0-9])-([a-zA-Z0-9])", '$1 $2'

    "# $runbookDisplayName"
    #"## Synopsis"
    "## " + $runbookHelp.Synopsis
    ""
    "## Description"
    $runbookHelp.Description.Text
    ""
    # "# Parameters"
    # $runbookHelp.Parameters
    # ""
    "## Permissions (Notes)"
    '```'
    $runbookHelp.alertSet.alert.Text
    '```'
    ""
}

"" > $outfile

Get-ChildItem -Recurse -Include "*.ps1" -Exclude $MyInvocation.MyCommand.Name | ForEach-Object {
    Get-MarkdownHelp -runbookPath $_.FullName >> $outfile
}

<#
	.SYNOPSIS
	Validates changed PowerShell runbooks in a pull request

	.DESCRIPTION
	This script identifies PowerShell runbooks (*.ps1) that were added or modified in a pull request compared to a base reference and validates them. It runs PSScriptAnalyzer for severity Error and then validates the comment-based help using Get-Help. The help validation requires a synopsis, a description, and a non-empty description for every declared parameter.

	.PARAMETER BaseRef
	The git reference to diff against, for example the pull request base SHA.

	.PARAMETER HeadRef
	The git reference that contains the changes to validate, for example the pull request head SHA.
#>

param (
	[Parameter(Mandatory = $true)]
	[string]$BaseRef,

	[Parameter(Mandatory = $true)]
	[string]$HeadRef
)

Set-StrictMode -Version Latest

############################################################
#region Functions
#
############################################################

function Write-GitHubError {
	<#
		.SYNOPSIS
		Emits a GitHub Actions error annotation
	#>
	param(
		[Parameter(Mandatory = $true)]
		[string]$Message,

		[Parameter(Mandatory = $false)]
		[string]$FilePath
	)

	if ($FilePath) {
		Write-Output "::error file=$FilePath,title=Runbook validation failed::$Message"
		return
	}

	Write-Output "::error title=Runbook validation failed::$Message"
}

function Write-WrappedText {
	<#
		.SYNOPSIS
		Writes long text with simple word-wrapping
	#>
	param(
		[Parameter(Mandatory = $true)]
		[string]$Text,

		[Parameter(Mandatory = $false)]
		[int]$Width = 140,

		[Parameter(Mandatory = $false)]
		[string]$Indent = "  "
	)

	$splitLines = $Text -split "`r`n|`n|`r"
	foreach ($rawLine in $splitLines) {
		$line = ($rawLine ?? '').TrimEnd()
		if (-not $line) {
			Write-Output ""
			continue
		}

		$remaining = $line
		while ($remaining.Length -gt $Width) {
			$breakAt = $remaining.LastIndexOf(' ', $Width)
			if ($breakAt -lt 20) {
				$breakAt = $Width
			}
			Write-Output ($Indent + $remaining.Substring(0, $breakAt).TrimEnd())
			$remaining = $remaining.Substring($breakAt).TrimStart()
		}

		if ($remaining) {
			Write-Output ($Indent + $remaining)
		}
	}
}

function Convert-HelpTextToString {
	<#
		.SYNOPSIS
		Normalizes Get-Help text objects into a single string
	#>
	param(
		[Parameter(Mandatory = $false)]
		$HelpText
	)

	if ($null -eq $HelpText) {
		return ''
	}

	if ($HelpText -is [string]) {
		return $HelpText
	}

	if ($HelpText -is [System.Array]) {
		return (($HelpText | ForEach-Object { Convert-HelpTextToString -HelpText $_ }) -join ' ')
	}

	if ($HelpText.PSObject -and $HelpText.PSObject.Properties.Match('Text').Count -gt 0) {
		return (Convert-HelpTextToString -HelpText $HelpText.Text)
	}

	return [string]$HelpText
}

function Get-DeclaredParameterNames {
	<#
		.SYNOPSIS
		Returns parameter names declared in a script's param() block
	#>
	param(
		[Parameter(Mandatory = $true)]
		[string]$FilePath
	)

	$tokens = $null
	$errors = $null
	$ast = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$tokens, [ref]$errors)

	if ($errors -and $errors.Count -gt 0) {
		$first = $errors | Select-Object -First 1
		throw "PowerShell parse error: $($first.Message)"
	}

	if (-not $ast.ParamBlock) {
		return @()
	}

	return @(
		$ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }
	)
}

function Get-ChangedPs1Files {
	<#
		.SYNOPSIS
		Gets added/modified/renamed .ps1 files between two git refs
	#>
	param(
		[Parameter(Mandatory = $true)]
		[string]$Base,

		[Parameter(Mandatory = $true)]
		[string]$Head
	)

	$diffArgs = @(
		'diff',
		'--name-only',
		'--diff-filter=AMR',
		"$Base..$Head",
		'--',
		'*.ps1'
	)

	$names = & git @diffArgs 2>&1
	if ($LASTEXITCODE -ne 0) {
		throw "git diff failed. Args='$($diffArgs -join ' ')'. Output: $($names | Out-String)"
	}

	$changed = @(
		$names | ForEach-Object { $_.Trim() } | Where-Object { $_ }
	)

	return @(
		$changed
		| ForEach-Object { $_ -replace '\\', '/' }
		| Where-Object { -not $_.ToLowerInvariant().StartsWith('.github/') }
	)
}

function Assert-PSScriptAnalyzerSeverityError {
	<#
		.SYNOPSIS
		Runs PSScriptAnalyzer and fails if it reports severity Error
	#>
	param(
		[Parameter(Mandatory = $true)]
		[string]$RunbookPath
	)

	if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
		throw "PSScriptAnalyzer module is not available on the runner."
	}

	try {
		$ErrorRules = Get-ScriptAnalyzerRule -Severity Error
		$results = Invoke-ScriptAnalyzer -Path $RunbookPath -IncludeRule $ErrorRules
	}
	catch {
		throw "PSScriptAnalyzer failed to analyze '$RunbookPath'. Error: $($_.Exception.Message)"
	}

	if ($results -and $results.Count -gt 0) {
		$messages = $results | ForEach-Object {
			$line = if ($_.Line) { "Line $($_.Line)" } else { "" }
			"[$($_.Severity)] $($_.RuleName) $($line): $($_.Message)"
		}

		throw ("PSScriptAnalyzer findings:`n" + ($messages -join "`n"))
	}
}

function Assert-HelpIsComplete {
	<#
		.SYNOPSIS
		Validates comment-based help via Get-Help
	#>
	param(
		[Parameter(Mandatory = $true)]
		[string]$RunbookPath,

		[Parameter(Mandatory = $true)]
		[string]$RunbookRelativePath
	)

	$helpTarget = $RunbookRelativePath -replace '\\', '/'
	if (-not $helpTarget.StartsWith('./')) {
		$helpTarget = "./$helpTarget"
	}

	try {
		$help = Get-Help -Full $helpTarget -ErrorAction Stop
	}
	catch {
		throw "Get-Help failed to read comment-based help for '$helpTarget'. Error: $($_.Exception.Message)"
	}

	$synopsis = (Convert-HelpTextToString -HelpText $help.Synopsis).Trim()
	if (-not $synopsis) {
		throw "Missing or empty help synopsis (.SYNOPSIS)."
	}

	$description = (Convert-HelpTextToString -HelpText $help.Description.Text).Trim()
	if (-not $description) {
		throw "Missing or empty help description (.DESCRIPTION)."
	}

	$normalize = {
		param([string]$s)
		return (($s ?? '') -replace '\s+', ' ').Trim().ToLowerInvariant()
	}

	if ((& $normalize $synopsis) -eq (& $normalize $description)) {
		throw "Synopsis and Description must not be identical. Make .DESCRIPTION more detailed than .SYNOPSIS."
	}

	$declaredParams = Get-DeclaredParameterNames -FilePath $RunbookPath
	if ($declaredParams.Count -eq 0) {
		return
	}

	$helpParamMap = @{}
	if ($help.Parameters -and $help.Parameters.Parameter) {
		foreach ($hp in $help.Parameters.Parameter) {
			if ($hp -and $hp.Name) {
				$helpParamMap[$hp.Name.ToString().ToLowerInvariant()] = $hp
			}
		}
	}

	foreach ($p in $declaredParams) {
		$key = $p.ToLowerInvariant()
		if (-not $helpParamMap.ContainsKey($key)) {
			throw "Missing help parameter documentation (.PARAMETER) for '$p'."
		}

		$hp = $helpParamMap[$key]
		$paramDesc = (Convert-HelpTextToString -HelpText $hp.Description).Trim()
		if (-not $paramDesc) {
			throw "Empty help parameter description for '$p'."
		}
	}
}

#endregion Functions

############################################################
#region Main Logic
#
############################################################

try {
	$changedPs1 = @(Get-ChangedPs1Files -Base $BaseRef -Head $HeadRef)
	if ($changedPs1.Count -eq 0) {
		Write-Output "No changed runbooks (*.ps1) detected. Skipping validation."
		exit 0
	}

	$successList = @()
	$failureList = @()

	foreach ($relPath in $changedPs1) {
		$path = Join-Path (Get-Location).Path $relPath

		Write-Output "::group::Validate runbook: $relPath"
		try {
			if (-not (Test-Path -LiteralPath $path)) {
				throw "Changed file '$relPath' was not found in the working tree."
			}
			Assert-PSScriptAnalyzerSeverityError -RunbookPath $path
			Assert-HelpIsComplete -RunbookPath $path -RunbookRelativePath $relPath

			$successList += $relPath
			Write-Output "OK: $relPath"
		}
		catch {
			$message = $($_.Exception.Message)
			$failureList += [PSCustomObject]@{ Runbook = $relPath; Message = $message }
			Write-Output "FAILED: $relPath"
			Write-WrappedText -Text $message -Width 140 -Indent "  "
			Write-GitHubError -Message $message -FilePath $relPath
		}
		Write-Output "::endgroup::"
	}

	Write-Output ""
	Write-Output "Validation summary"
	Write-Output "------------------"
	Write-Output ("Total runbooks validated: {0}" -f $changedPs1.Count)
	Write-Output ("Succeeded: {0}" -f $successList.Count)
	Write-Output ("Failed: {0}" -f $failureList.Count)

	if ($successList.Count -gt 0) {
		Write-Output ""
		Write-Output ("Runbooks without errors ({0})" -f $successList.Count)
		Write-Output "--------------------------"
		foreach ($rb in ($successList | Sort-Object)) {
			Write-Output ("- {0}" -f $rb)
		}
	}

	if ($failureList.Count -gt 0) {
		Write-Output ""
		Write-Output ("Runbooks with errors ({0})" -f $failureList.Count)
		Write-Output "---------------------"
		foreach ($f in $failureList) {
			Write-Output ("- {0}" -f $f.Runbook)
		}

		Write-Output ""
		Write-Output "Error details"
		Write-Output "-------------"
		foreach ($f in $failureList) {
			Write-Output ""
			Write-Output $f.Runbook
			Write-Output ("-" * [Math]::Min(120, [Math]::Max(3, $f.Runbook.Length)))
			Write-WrappedText -Text $f.Message -Width 140 -Indent "  "
		}
	}

	if ($failureList.Count -gt 0) {
		Write-Output ""
		Write-Output ("Runbook validation failed for {0} file(s)." -f $failureList.Count)
		exit 1
	}

	Write-Output ""
	Write-Output ("Runbook validation passed for {0} file(s)." -f $changedPs1.Count)
	exit 0
}
catch {
	$message = "Validator failed unexpectedly. Error: $($_.Exception.Message)"
	Write-Output $message
	Write-GitHubError -Message $message
	exit 1
}

#endregion Main Logic

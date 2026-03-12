<#
	.SYNOPSIS
	Validates that each runbook has a companion permissions JSON

	.DESCRIPTION
	This script recursively scans one or more runbook root folders for PowerShell runbooks (*.ps1) and verifies that each runbook has a companion permissions JSON file in the same directory. A companion file must be named <runbook>.permissions.json. If a file named <runbook>.permission.json exists instead, it is reported as an error to ease troubleshooting. The script prints a clear summary and exits with code 1 when any runbook is missing its companion permissions JSON or has the wrong filename.

	.PARAMETER IncludedScope
	One or more root folders that contain runbooks, for example @('device','group','org','user'). Each scope is scanned recursively.

	.PARAMETER ChangedFiles
	Optional list of runbook files to validate directly. If provided, only these files are checked.
#>

param (
	[Parameter(Mandatory = $true)]
	[string[]]$IncludedScope,

	[Parameter(Mandatory = $false)]
	[string[]]$ChangedFiles
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
		Write-Output "::error file=$FilePath,title=Permissions JSON validation failed::$Message"
		return
	}

	Write-Output "::error title=Permissions JSON validation failed::$Message"
}

function Get-RunbookFiles {
	<#
		.SYNOPSIS
		Finds all runbook .ps1 files in the included scopes
	#>
	param(
		[Parameter(Mandatory = $true)]
		[string[]]$Scopes
	)

	$all = @()
	foreach ($scope in $Scopes) {
		if (-not $scope) {
			continue
		}

		$scopePath = Join-Path (Get-Location).Path $scope
		if (-not (Test-Path -LiteralPath $scopePath)) {
			continue
		}

		$all += Get-ChildItem -LiteralPath $scopePath -Recurse -File -Filter '*.ps1' -ErrorAction Stop
	}

	# Exclude non-runbook scripts if they are inside scopes for some reason
	return @(
		$all
		| Where-Object { $_.FullName -notmatch '[\\/](\.github|docs)[\\/]' }
		| Sort-Object FullName
	)
}

function Get-RunbookFilesFromChangedFiles {
	<#
		.SYNOPSIS
		Builds runbook file objects from explicit changed file paths
	#>
	param(
		[Parameter(Mandatory = $true)]
		[string[]]$Files
	)

	$resolved = @()
	foreach ($file in $Files) {
		$rel = ($file ?? '').Trim()
		if (-not $rel) {
			continue
		}

		$normalized = ($rel -replace '\\', '/')
		if (-not $normalized.EndsWith('.ps1', [System.StringComparison]::OrdinalIgnoreCase)) {
			continue
		}

		if ($normalized.ToLowerInvariant().StartsWith('.github/')) {
			continue
		}

		$full = Join-Path (Get-Location).Path $normalized
		if (-not (Test-Path -LiteralPath $full)) {
			continue
		}

		$resolved += Get-Item -LiteralPath $full -ErrorAction Stop
	}

	return @($resolved | Sort-Object FullName -Unique)
}

function Test-IsInIncludedScope {
	<#
		.SYNOPSIS
		Checks whether a relative path is within one of the included scopes
	#>
	param(
		[Parameter(Mandatory = $true)]
		[string]$RelativePath,

		[Parameter(Mandatory = $true)]
		[string[]]$Scopes
	)

	$normalizedPath = ($RelativePath -replace '\\', '/').TrimStart('./')
	foreach ($scope in $Scopes) {
		$scopePrefix = (($scope ?? '').Trim() -replace '\\', '/').Trim('/')
		if (-not $scopePrefix) {
			continue
		}

		if ($normalizedPath.StartsWith("$scopePrefix/", [System.StringComparison]::OrdinalIgnoreCase)) {
			return $true
		}
	}

	return $false
}

function Get-RunbookBaseKeysFromChangedFiles {
	<#
		.SYNOPSIS
		Builds unique runbook base keys from changed .ps1/.permissions.json paths
	#>
	param(
		[Parameter(Mandatory = $true)]
		[string[]]$Files,

		[Parameter(Mandatory = $true)]
		[string[]]$Scopes
	)

	$keys = @()
	foreach ($file in $Files) {
		$rel = ($file ?? '').Trim()
		if (-not $rel) {
			continue
		}

		$normalized = ($rel -replace '\\', '/').TrimStart('./')
		if ($normalized.ToLowerInvariant().StartsWith('.github/') -or $normalized.ToLowerInvariant().StartsWith('docs/')) {
			continue
		}

		if (-not (Test-IsInIncludedScope -RelativePath $normalized -Scopes $Scopes)) {
			continue
		}

		$lower = $normalized.ToLowerInvariant()
		if ($lower.EndsWith('.ps1')) {
			$keys += $normalized.Substring(0, $normalized.Length - 4)
			continue
		}

		if ($lower.EndsWith('.permissions.json')) {
			$keys += $normalized.Substring(0, $normalized.Length - '.permissions.json'.Length)
			continue
		}

		if ($lower.EndsWith('.permission.json')) {
			$keys += $normalized.Substring(0, $normalized.Length - '.permission.json'.Length)
			continue
		}
	}

	return @(
		$keys
		| Where-Object { $_ }
		| Sort-Object -Unique
	)
}

function Get-CompanionPermissionsCandidates {
	<#
		.SYNOPSIS
		Builds the expected permissions JSON file paths for a runbook
	#>
	param(
		[Parameter(Mandatory = $true)]
		[string]$RunbookPath
	)

	$dir = Split-Path -Parent $RunbookPath
	$base = [System.IO.Path]::GetFileNameWithoutExtension($RunbookPath)
	return @(
		(Join-Path $dir "$base.permissions.json"),
		(Join-Path $dir "$base.permission.json")
	)
}

function Get-RelativePath {
	<#
		.SYNOPSIS
		Returns a workspace-relative, forward-slash path for GitHub annotations
	#>
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path
	)

	$full = (Resolve-Path -LiteralPath $Path).Path
	$root = (Resolve-Path -LiteralPath (Get-Location).Path).Path
	$rel = $full.Substring($root.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
	return ($rel -replace '\\', '/')
}

#endregion Functions

############################################################
#region Main Logic
#
############################################################

try {
	$missing = @()
	$wrongName = @()
	$orphanPermissions = @()
	$checkedCount = 0

	if ($ChangedFiles -and $ChangedFiles.Count -gt 0) {
		$baseKeys = @(Get-RunbookBaseKeysFromChangedFiles -Files $ChangedFiles -Scopes $IncludedScope)
		if ($baseKeys.Count -eq 0) {
			Write-Output "No changed runbook or permissions JSON files in included scopes. Skipping permissions JSON validation."
			exit 0
		}

		foreach ($key in $baseKeys) {
			$rbRel = "$key.ps1"
			$expectedPreferred = "$key.permissions.json"
			$expectedAlt = "$key.permission.json"

			$rbFull = Join-Path (Get-Location).Path $rbRel
			$preferredFull = Join-Path (Get-Location).Path $expectedPreferred
			$altFull = Join-Path (Get-Location).Path $expectedAlt

			$hasRunbook = Test-Path -LiteralPath $rbFull
			$hasPreferred = Test-Path -LiteralPath $preferredFull
			$hasAlt = Test-Path -LiteralPath $altFull
			$checkedCount++

			if ($hasRunbook -and $hasPreferred) {
				continue
			}

			if ($hasRunbook -and $hasAlt -and -not $hasPreferred) {
				$msg = "Found '$expectedAlt' but expected '$expectedPreferred'. Rename the file to use the required '.permissions.json' suffix."
				$wrongName += [PSCustomObject]@{ Runbook = $rbRel; Message = $msg; File = $expectedAlt }
				Write-Output "::group::Wrong permissions JSON filename: $rbRel"
				Write-Output "FAILED: $rbRel"
				Write-GitHubError -Message $msg -FilePath $expectedAlt
				Write-Output "::endgroup::"
				continue
			}

			if ($hasRunbook -and -not $hasPreferred -and -not $hasAlt) {
				$msg = "Missing companion permissions JSON. Expected '$expectedPreferred'."
				$missing += [PSCustomObject]@{ Runbook = $rbRel; Message = $msg }
				Write-Output "::group::Missing permissions JSON: $rbRel"
				Write-Output "FAILED: $rbRel"
				Write-GitHubError -Message $msg -FilePath $rbRel
				Write-Output "::endgroup::"
				continue
			}

			if ((-not $hasRunbook) -and ($hasPreferred -or $hasAlt)) {
				$existingJson = if ($hasPreferred) { $expectedPreferred } else { $expectedAlt }
				$msg = "Permissions JSON '$existingJson' exists but companion runbook '$rbRel' is missing. Remove the JSON or restore the runbook."
				$orphanPermissions += [PSCustomObject]@{ Runbook = $rbRel; Message = $msg; File = $existingJson }
				Write-Output "::group::Orphan permissions JSON: $existingJson"
				Write-Output "FAILED: $existingJson"
				Write-GitHubError -Message $msg -FilePath $existingJson
				Write-Output "::endgroup::"
			}
		}
	}
	else {
		$runbooks = @(Get-RunbookFiles -Scopes $IncludedScope)
		if ($runbooks.Count -eq 0) {
			Write-Output "No runbooks (*.ps1) found in included scopes. Skipping permissions JSON validation."
			exit 0
		}

		$checkedCount = $runbooks.Count
		foreach ($rb in $runbooks) {
			$rbRel = Get-RelativePath -Path $rb.FullName

			$dirRel = (Split-Path -Parent $rbRel) -replace '\\', '/'
			$base = [System.IO.Path]::GetFileNameWithoutExtension($rbRel)
			$expectedPreferred = if ($dirRel) { "$dirRel/$base.permissions.json" } else { "$base.permissions.json" }
			$expectedAlt = if ($dirRel) { "$dirRel/$base.permission.json" } else { "$base.permission.json" }

			$preferredFull = Join-Path (Split-Path -Parent $rb.FullName) "$base.permissions.json"
			$altFull = Join-Path (Split-Path -Parent $rb.FullName) "$base.permission.json"
			$hasPreferred = Test-Path -LiteralPath $preferredFull
			$hasAlt = Test-Path -LiteralPath $altFull

			if ($hasPreferred) {
				continue
			}

			if ($hasAlt) {
				$msg = "Found '$expectedAlt' but expected '$expectedPreferred'. Rename the file to use the required '.permissions.json' suffix."
				$wrongName += [PSCustomObject]@{ Runbook = $rbRel; Message = $msg; File = $expectedAlt }
				Write-Output "::group::Wrong permissions JSON filename: $rbRel"
				Write-Output "FAILED: $rbRel"
				Write-GitHubError -Message $msg -FilePath $expectedAlt
				Write-Output "::endgroup::"
				continue
			}

			$msg = "Missing companion permissions JSON. Expected '$expectedPreferred'."
			$missing += [PSCustomObject]@{ Runbook = $rbRel; Message = $msg }
			Write-Output "::group::Missing permissions JSON: $rbRel"
			Write-Output "FAILED: $rbRel"
			Write-GitHubError -Message $msg -FilePath $rbRel
			Write-Output "::endgroup::"
		}
	}

	Write-Output ""
	Write-Output "Permissions JSON validation summary"
	Write-Output "----------------------------------"
	Write-Output ("Total runbooks scanned: {0}" -f $checkedCount)
	Write-Output ("Missing permissions JSON: {0}" -f $missing.Count)
	Write-Output ("Wrong permissions JSON filename: {0}" -f $wrongName.Count)
	Write-Output ("Permissions JSON without runbook: {0}" -f $orphanPermissions.Count)

	if ($missing.Count -gt 0) {
		Write-Output ""
		Write-Output "Missing permissions JSON (details)"
		Write-Output "---------------------------------"
		foreach ($m in $missing) {
			Write-Output ""
			Write-Output $m.Runbook
			Write-Output ("-" * [Math]::Min(120, [Math]::Max(3, $m.Runbook.Length)))
			Write-Output ("  " + $m.Message)
		}
	}

	if ($wrongName.Count -gt 0) {
		Write-Output ""
		Write-Output "Wrong permissions JSON filename (details)"
		Write-Output "----------------------------------------"
		foreach ($w in $wrongName) {
			Write-Output ""
			Write-Output $w.Runbook
			Write-Output ("-" * [Math]::Min(120, [Math]::Max(3, $w.Runbook.Length)))
			Write-Output ("  " + $w.Message)
		}
	}

	if ($orphanPermissions.Count -gt 0) {
		Write-Output ""
		Write-Output "Permissions JSON without runbook (details)"
		Write-Output "------------------------------------------"
		foreach ($o in $orphanPermissions) {
			Write-Output ""
			Write-Output $o.File
			Write-Output ("-" * [Math]::Min(120, [Math]::Max(3, $o.File.Length)))
			Write-Output ("  " + $o.Message)
		}
	}

	if (($missing.Count -gt 0) -or ($wrongName.Count -gt 0) -or ($orphanPermissions.Count -gt 0)) {
		Write-Output ""
		Write-Output ("Permissions JSON validation failed for {0} runbook(s)." -f ($missing.Count + $wrongName.Count + $orphanPermissions.Count))
		exit 1
	}

	Write-Output ""
	Write-Output "Permissions JSON validation passed."
	exit 0
}
catch {
	$message = "Permissions JSON validator failed unexpectedly. Error: $($_.Exception.Message)"
	Write-Output $message
	Write-GitHubError -Message $message
	exit 1
}

#endregion Main Logic

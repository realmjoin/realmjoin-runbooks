<#
	.SYNOPSIS
	Sync Apple Enrollment Program Tokens and VPP Tokens with Intune

	.DESCRIPTION
	This runbook triggers synchronization of Apple tokens in Microsoft Intune. It can sync Apple Enrollment Program (ADE) tokens, Volume Purchase Program (VPP) tokens, or both. The sync ensures that Intune has the latest information from Apple Business Manager regarding device enrollments and app licenses.

	.PARAMETER SyncType
	Select which token type(s) to synchronize with Apple Business Manager.

	.PARAMETER CallerName
	Automated parameter for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"SyncType": {
				"Hide": false,
				"Default": "Both",
				"DisplayName": "Sync Type",
				"SelectSimple": {
					"Sync both Enrollment and VPP tokens" : "Both",
					"Sync Enrollment Program tokens only" : "EnrollmentTokens",
					"Sync VPP tokens only" : "VPPTokens"
				}
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5"}
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1"}

param(
	[Parameter(Mandatory = $true)]
	[ValidateSet("Both", "EnrollmentTokens", "VPPTokens")]
	[string]$SyncType = "Both",

	# CallerName is tracked purely for auditing purposes
	[Parameter(Mandatory = $true)]
	[string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "SyncType: $SyncType" -Verbose
#endregion

########################################################
#region     Connect Part
########################################################
try {
	Write-Output ""
	Write-Output "Connecting to Microsoft Graph..."
	Write-Output "---------------------"
	Connect-MgGraph -Identity -NoWelcome
	Write-Output "Successfully connected to Microsoft Graph."
} catch {
	Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
	throw
}
#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################
Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

$SyncEnrollment = $false
$SyncVPP = $false

switch ($SyncType) {
	"Both" {
		$SyncEnrollment = $true
		$SyncVPP = $true
		Write-Output "Will sync both Enrollment Program tokens and VPP tokens"
	}
	"EnrollmentTokens" {
		$SyncEnrollment = $true
		Write-Output "Will sync Enrollment Program tokens only"
	}
	"VPPTokens" {
		$SyncVPP = $true
		Write-Output "Will sync VPP tokens only"
	}
}

# Get current token status
if ($SyncEnrollment) {
	Write-Output ""
	Write-Output "Retrieving Enrollment Program tokens..."
	try {
		$enrollmentTokens = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings" -ErrorAction Stop
		$enrollmentTokenList = $enrollmentTokens.value

		if ($enrollmentTokenList.Count -gt 0) {
			Write-Output "Found $($enrollmentTokenList.Count) Enrollment Program token(s)"
			foreach ($token in $enrollmentTokenList) {
				$tokenName = $token.tokenName ? $token.tokenName : "Unnamed Token"
				$lastSync = $token.lastSuccessfulSyncDateTime ? $token.lastSuccessfulSyncDateTime : "Never"
				Write-Output "  - $tokenName (Last sync: $lastSync)"
			}
		} else {
			Write-Output "WARNING: No Enrollment Program tokens found in Intune"
			$SyncEnrollment = $false
		}
	} catch {
		Write-Error "Failed to retrieve Enrollment Program tokens: $($_.Exception.Message)" -ErrorAction Continue
		throw
	}
}

if ($SyncVPP) {
	Write-Output ""
	Write-Output "Retrieving VPP tokens..."
	try {
		$vppTokens = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/vppTokens" -ErrorAction Stop
		$vppTokenList = $vppTokens.value

		if ($vppTokenList.Count -gt 0) {
			Write-Output "Found $($vppTokenList.Count) VPP token(s)"
			foreach ($token in $vppTokenList) {
				$tokenName = $token.displayName ? $token.displayName : "Unnamed Token"
				$lastSync = $token.lastSyncDateTime ? $token.lastSyncDateTime : "Never"
				Write-Output "  - $tokenName (Last sync: $lastSync)"
			}
		} else {
			Write-Output "WARNING: No VPP tokens found in Intune"
			$SyncVPP = $false
		}
	} catch {
		Write-Error "Failed to retrieve VPP tokens: $($_.Exception.Message)" -ErrorAction Continue
		throw
	}
}

# Check if we have any tokens to sync
if (-not $SyncEnrollment -and -not $SyncVPP) {
	Write-Error "No tokens available to sync. Please configure Apple tokens in Intune first." -ErrorAction Continue
	throw "No tokens available to sync"
}
#endregion

########################################################
#region     Main Part
########################################################
Write-Output ""
Write-Output "Starting Token Sync"
Write-Output "---------------------"

$syncResults = @{
	EnrollmentSuccess = 0
	EnrollmentFailed = 0
	VPPSuccess = 0
	VPPFailed = 0
}

# Sync Enrollment Program tokens
if ($SyncEnrollment) {
	Write-Output ""
	Write-Output "Syncing Enrollment Program tokens..."

	foreach ($token in $enrollmentTokenList) {
		$tokenId = $token.id
		$tokenName = $token.tokenName ? $token.tokenName : "Unnamed Token"

		try {
			Write-Output "  Syncing: $tokenName..."
			$syncUri = "https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings/$tokenId/syncWithAppleDeviceEnrollmentProgram"
			Invoke-MgGraphRequest -Method POST -Uri $syncUri -ErrorAction Stop
			Write-Output "  ✓ Successfully triggered sync for $tokenName"
			$syncResults.EnrollmentSuccess++
		} catch {
			Write-Output "  ✗ Failed to sync $tokenName : $($_.Exception.Message)"
			$syncResults.EnrollmentFailed++
		}
	}
}

# Sync VPP tokens
if ($SyncVPP) {
	Write-Output ""
	Write-Output "Syncing VPP tokens..."

	foreach ($token in $vppTokenList) {
		$tokenId = $token.id
		$tokenName = $token.displayName ? $token.displayName : "Unnamed Token"

		try {
			Write-Output "  Syncing: $tokenName..."
			$syncUri = "https://graph.microsoft.com/v1.0/deviceAppManagement/vppTokens/$tokenId/syncLicenses"
			Invoke-MgGraphRequest -Method POST -Uri $syncUri -ErrorAction Stop
			Write-Output "  ✓ Successfully triggered sync for $tokenName"
			$syncResults.VPPSuccess++
		} catch {
			Write-Output "  ✗ Failed to sync $tokenName : $($_.Exception.Message)"
			$syncResults.VPPFailed++
		}
	}
}

# Display summary
Write-Output ""
Write-Output "Sync Summary"
Write-Output "---------------------"
if ($SyncEnrollment) {
	Write-Output "Enrollment Program Tokens:"
	Write-Output "  Successful: $($syncResults.EnrollmentSuccess)"
	Write-Output "  Failed: $($syncResults.EnrollmentFailed)"
}
if ($SyncVPP) {
	Write-Output "VPP Tokens:"
	Write-Output "  Successful: $($syncResults.VPPSuccess)"
	Write-Output "  Failed: $($syncResults.VPPFailed)"
}

$totalFailed = $syncResults.EnrollmentFailed + $syncResults.VPPFailed
if ($totalFailed -gt 0) {
	Write-Error "$totalFailed token sync(s) failed. Check the output above for details." -ErrorAction Continue
	throw "Token sync completed with errors"
}
#endregion

########################################################
#region     Cleanup
########################################################
Disconnect-MgGraph | Out-Null

Write-Output ""
Write-Output "Done!"
#endregion

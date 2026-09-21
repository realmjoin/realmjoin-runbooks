<#
	.SYNOPSIS
	Set the profile photo of this user from a URL

	.DESCRIPTION
	Downloads a JPEG image from the given URL and sets it as the profile photo of this user. The photo shows up in Microsoft 365 apps such as Teams and Outlook. An existing photo is replaced.

	.PARAMETER UserName
	User principal name of the user the runbook acts on. Set by the portal from the selected user.

	.PARAMETER PhotoURI
	Web address of a JPEG image the runbook can download.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"UserName": {
				"Hide": true
			},
			"CallerName": {
				"Hide": true
			},
			"PhotoURI": {
				"DisplayName": "Photo URL"
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [string]$PhotoURI = "",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

"## Trying to update user photo of '$UserName' from URL:"
"## $PhotoURI"

$ErrorActionPreference = "Stop"

Connect-RjRbGraph

# "Find the user object $UserName"
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName" -ErrorAction SilentlyContinue
if (-not $targetUser) {
    throw ("User '$UserName' not found.")
}

# "Download the photo from URI $PhotoURI"
try {
    # "ImageByteArray" is broken in PS5, so will use a file.
    #$photo = (Invoke-WebRequest -Uri $PhotoURI -UseBasicParsing).Content
    Invoke-WebRequest -Uri $PhotoURI -OutFile ($env:TEMP + "\photo.jpg") | Out-Null
}
catch {
    $_
    throw ("Photo download from '$PhotoURI' failed.")
}

# "Set profile picture for user"
# "ImageByteArray" is broken in PS5, so will use a file.
try {
    Invoke-RjRbRestMethodGraph -resource "/users/$($targetUser.id)/photo/`$value" -inFile ($env:TEMP + "\photo.jpg") -Method Put -ContentType "image/jpeg"
}
catch {
    "## Can't update user photo in Exchange. Maybe the user has no mailbox?"
    ""
    "## Make sure, you have the following Graph API permission:"
    "## - User.ReadWrite.All (API)"
    ""
    $_
    throw "Setting photo failed."
}

"## Updating profile photo for '$UserName' succeded."

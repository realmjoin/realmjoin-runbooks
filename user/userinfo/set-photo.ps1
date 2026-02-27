<#
	.SYNOPSIS
	Set the profile photo for a user

	.DESCRIPTION
	Downloads a JPEG image from a URL and uploads it as the user's profile photo. This is useful to set or update user avatars in Microsoft 365.

	.PARAMETER UserName
	User principal name of the target user.

	.PARAMETER PhotoURI
	URL to a JPEG image that will be used as the profile photo.

	.PARAMETER CallerName
	Caller name is tracked purely for auditing purposes.

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
				"DisplayName": "Photo Source URL:"
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

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

$Version = "1.0.1"
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

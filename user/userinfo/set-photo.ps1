<#
  .SYNOPSIS
  Set / update the photo / avatar picture of a user.

  .DESCRIPTION
  Set / update the photo / avatar picture of a user.

  .PARAMETER PhotoURI
  Needs to be a JPEG

  .NOTES
  Permissions:
 - MS Graph (API): User.ReadWrite.All

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

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    # If you need a demo-picture: https://www.gravatar.com/avatar/205e460b479e2e5b48aec07710c08d50 (taken from https://en.gravatar.com/site/implement/images/)
    [Parameter(Mandatory = $true)]
    [string]$PhotoURI = "",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

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

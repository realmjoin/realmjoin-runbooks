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
            }
        }
    }
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    # If you need a demo-picture: https://www.gravatar.com/avatar/205e460b479e2e5b48aec07710c08d50 (taken from https://en.gravatar.com/site/implement/images/)
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -DisplayName "Source URL" } )]
    [string]$PhotoURI = ""
)

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

$ErrorActionPreference = "Stop"

Connect-RjRbGraph

# "Find the user object $UserName"
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName" -ErrorAction SilentlyContinue
if (-not $targetUser) {
    throw ("User $UserName not found.")
}

# "Download the photo from URI $PhotoURI"
try {
    # "ImageByteArray" is broken in PS5, so will use a file.
    #$photo = (Invoke-WebRequest -Uri $PhotoURI -UseBasicParsing).Content
    Invoke-WebRequest -Uri $PhotoURI -OutFile ($env:TEMP + "\photo.jpg") | Out-Null
}
catch {
    Write-Error $_
    throw ("Photo download from $PhotoURI failed.")
}

# "Set profile picture for user"
# "ImageByteArray" is broken in PS5, so will use a file.
try {
    Invoke-RjRbRestMethodGraph -resource "/users/$($targetUser.id)/photo" -inFile ($env:TEMP + "\photo.jpg") -Method Put -ContentType "image/jpeg"
} catch {
    Write-Error $_
    throw "Setting photo failed."
}

"## Updating profile photo for $UserName succeded."

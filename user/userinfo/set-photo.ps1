# Permissions:
# - AzureAD Role: User administrator

#Requires -Module AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

<#
  .SYNOPSIS
  Set / update the photo / avatar picture of a user.

  .DESCRIPTION
  Set / update the photo / avatar picture of a user.

  .PARAMETER PhotoURI
  Source needs to be a JPEG

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

Connect-RjRbAzureAD

# Bug in AzureAD Module when using ErrorAction
$ErrorActionPreference = "SilentlyContinue"

# "Find the user object $UserName"
$targetUser = Get-AzureADUser -ObjectId $UserName 
if (-not $targetUser) {
    throw ("User $UserName not found.")
}

# Bug in AzureAD Module when using ErrorAction
$ErrorActionPreference = "Stop"

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
# Set-AzureADUserThumbnailPhoto -ImageByteArray $photo -ObjectId $targetUser.ObjectId 
try {
    Set-AzureADUserThumbnailPhoto -FilePath ($env:TEMP + "\photo.jpg") -ObjectId $targetUser.ObjectId | Out-Null
} catch {
    Write-Error $_
    Disconnect-AzureAD -Confirm:$false | Out-Null
    throw "Setting photo failed."
}

# "Sign out from AzureAD"
Disconnect-AzureAD -Confirm:$false | Out-Null

"Updating profile photo for $UserName succeded."
